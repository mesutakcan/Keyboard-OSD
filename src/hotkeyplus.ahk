#Requires AutoHotkey v2.0

/*
HotkeyPlus - Enhanced Hotkey Control for AutoHotkey v2
------------------------------------------------------
Author: Mesut Akcan
Version: 1.0.0 (2026-09-02)
License: MIT
Project: https://github.com/mesutakcan/hotkeyplus-ahk
Blog:    https://mesutakcan.blogspot.com
Youtube: https://www.youtube.com/mesutakcan

Overcomes all limitations of the standard msctls_hotkey32 control:
- Supports Escape, Pause, PrintScreen, Tab, Enter, Space, Backspace, Delete, etc.
- Full support for Windows Key (#) combinations.
- Optional support for Mouse buttons (MButton, XButton1, XButton2, WheelUp, WheelDown).
- Live modifier key preview while holding modifiers (e.g. Ctrl + ...).
- Built-in clear button ([✕]) and right-click context menu.
- 100% compatible with standard AHK v2 Gui workflows.

Example Usage:
	MyGui := Gui()
	hk := MyGui.AddHotkeyPlus("w220 vMyHotkey", "^!Escape")
	hk.OnEvent("Change", (ctrl, val) => MsgBox("New hotkey: " . val))
	MyGui.Show()
*/

; Extend Gui prototype to enable MyGui.AddHotkeyPlus(...) directly
Gui.Prototype.AddHotkeyPlus := (guiObj, options := "", defaultValue := "") => HotkeyPlus(guiObj, options, defaultValue)

class HotkeyPlus {
	; Windows Message Constants
	static WM_DESTROY := 0x0002
	static WM_NCDESTROY := 0x0082
	static WM_SETFOCUS := 0x0007
	static WM_KILLFOCUS := 0x0008
	static WM_GETDLGCODE := 0x0087
	static WM_CHAR := 0x0102
	static WM_SYSCHAR := 0x0106
	static WM_RBUTTONUP := 0x0205
	static WM_MBUTTONDOWN := 0x0207
	static WM_CONTEXTMENU := 0x007B
	static WM_MOUSEWHEEL := 0x020A
	static WM_XBUTTONDOWN := 0x020B
	static DLGC_WANTALLKEYS := 0x0004

	; Private Fields
	_gui := ""
	_editCtrl := ""
	_clearBtn := ""
	_subclassCb := 0
	_inputHook := ""

	_value := ""
	_defaultValue := ""
	_placeholder := "Press a key..."
	_isListening := false
	_allowWin := true
	_allowMouse := true
	_noClearBtn := false
	_changeCallbacks := []
	_focusCallbacks := []
	_loseFocusCallbacks := []
	_name := ""

	/**
	 * Creates a new HotkeyPlus control instance.
	 * @param guiObj Parent Gui object
	 * @param options Options string (x, y, w, h, vName, NoClear, NoWin, NoMouse, etc.)
	 * @param defaultValue Initial hotkey string (e.g. "^!Escape")
	 */
	__New(guiObj, options := "", defaultValue := "") {
		this._gui := guiObj
		this._defaultValue := defaultValue
		this._value := defaultValue

		; Parse options
		parsed := this._ParseOptions(options)
		this._name := parsed.name
		this._allowWin := !parsed.noWin
		this._allowMouse := !parsed.noMouse
		this._noClearBtn := parsed.noClear

		; Compute dimensions
		editW := parsed.w
		btnW := 26
		spacing := 4

		if (!this._noClearBtn && editW > (btnW + spacing + 30)) {
			editW := editW - btnW - spacing
		} else if (this._noClearBtn) {
			btnW := 0
		}

		; Edit Control Options
		editOpt := "ReadOnly -Multi -Wrap " . parsed.posStr . " w" . editW . " h" . parsed.h
		if (parsed.otherOpt != "")
			editOpt .= " " . parsed.otherOpt

		; Create Edit control
		this._editCtrl := guiObj.Add("Edit", editOpt)

		; Create Clear Button ([✕])
		if (!this._noClearBtn) {
			btnOpt := "yp hp w" . btnW . " x+" . spacing
			this._clearBtn := guiObj.Add("Button", btnOpt, "✕")
			this._clearBtn.OnEvent("Click", (*) => this.Clear())
			this._clearBtn.ToolTip := "Clear Hotkey"
		}

		; Set initial display text
		this._UpdateDisplayText()

		; Attach subclass window procedure
		this._subclassCb := CallbackCreate(ObjBindMethod(this, "_SubclassProc"), , 6)
		DllCall("comctl32\SetWindowSubclass",
			"ptr", this._editCtrl.Hwnd,
			"ptr", this._subclassCb,
			"uptr", this._editCtrl.Hwnd,
			"uptr", 0
		)

		; Clean up subclassing when Gui closes
		guiObj.OnEvent("Close", (*) => this._Cleanup())
	}

	; =========================================================================
	; Properties
	; =========================================================================

	/**
	 * Hotkey value in standard AHK format (e.g. "^!Escape", "#+Pause", "F12")
	 */
	Value {
		get => this._value
		set {
			this._value := value
			this._UpdateDisplayText()
			this._TriggerEvent(this._changeCallbacks, this._value)
		}
	}

	/**
	 * Human-readable hotkey representation (e.g. "Ctrl + Alt + Escape")
	 */
	Text => HotkeyPlus.FormatKeyToText(this._value)

	/**
	 * Placeholder text displayed when listening for keystrokes
	 */
	Placeholder {
		get => this._placeholder
		set => this._placeholder := value
	}

	/**
	 * HWND handle of the Edit control
	 */
	Hwnd => this._editCtrl.Hwnd

	/**
	 * Underlying Edit control object
	 */
	EditCtrl => this._editCtrl

	/**
	 * Underlying Clear button object (if enabled)
	 */
	ClearBtn => this._clearBtn

	/**
	 * Whether the control is enabled
	 */
	Enabled {
		get => this._editCtrl.Enabled
		set {
			this._editCtrl.Enabled := value
			if (this._clearBtn)
				this._clearBtn.Enabled := value
		}
	}

	/**
	 * Whether the control is visible
	 */
	Visible {
		get => this._editCtrl.Visible
		set {
			this._editCtrl.Visible := value
			if (this._clearBtn)
				this._clearBtn.Visible := value
		}
	}

	/**
	 * Whether the control currently has input focus
	 */
	Focused => (DllCall("user32\GetFocus", "ptr") == this._editCtrl.Hwnd)

	/**
	 * Parent Gui object
	 */
	Gui => this._gui

	/**
	 * Associated variable name (from vOption)
	 */
	Name => this._name

	/**
	 * Whether Windows key (#) combinations are allowed
	 */
	AllowWin {
		get => this._allowWin
		set => this._allowWin := value
	}

	/**
	 * Whether Mouse buttons are allowed as hotkeys
	 */
	AllowMouse {
		get => this._allowMouse
		set => this._allowMouse := value
	}

	; =========================================================================
	; Methods
	; =========================================================================

	/**
	 * Focuses the control and activates key listening mode.
	 */
	Focus() {
		this._editCtrl.Focus()
	}

	/**
	 * Clears the hotkey value.
	 */
	Clear() {
		this._StopListening()
		this.Value := ""
	}

	/**
	 * Resets the hotkey to its default initial value.
	 */
	Reset() {
		this._StopListening()
		this.Value := this._defaultValue
	}

	/**
	 * Registers an event listener ("Change", "Focus", "LoseFocus").
	 */
	OnEvent(eventName, callback) {
		switch StrLower(eventName) {
			case "change":
				this._changeCallbacks.Push(callback)
			case "focus":
				this._focusCallbacks.Push(callback)
			case "losefocus":
				this._loseFocusCallbacks.Push(callback)
			default:
				throw ValueError("Unknown event type: " . eventName, -1)
		}
	}

	; =========================================================================
	; Key Listening & Input Capture
	; =========================================================================

	/**
	 * Starts listening mode for incoming keystrokes.
	 */
	_StartListening() {
		if (this._isListening)
			return

		this._isListening := true
		this._editCtrl.Value := "[ " . this._placeholder . " ]"

		; Create InputHook without "V" so keys do not leak to background GUI controls
		this._inputHook := InputHook()
		this._inputHook.NotifyNonText := true
		this._inputHook.KeyOpt("{All}", "+N +S")

		this._inputHook.OnKeyDown := ObjBindMethod(this, "_OnHookKeyDown")
		this._inputHook.OnKeyUp := ObjBindMethod(this, "_OnHookKeyUp")
		this._inputHook.Start()

		this._TriggerEvent(this._focusCallbacks)
	}

	/**
	 * Stops listening mode.
	 */
	_StopListening() {
		if (!this._isListening)
			return

		this._isListening := false
		if (this._inputHook) {
			this._inputHook.Stop()
			this._inputHook := ""
		}
		this._UpdateDisplayText()
		this._TriggerEvent(this._loseFocusCallbacks)
	}

	/**
	 * KeyDown handler from InputHook
	 */
	_OnHookKeyDown(ih, vk, sc) {
		if (!this._isListening)
			return

		; Check if pressed key is a modifier (Ctrl, Alt, Shift, Win)
		if (this._IsModifierKey(vk)) {
			this._UpdateModifierPreview()
			return
		}

		; Resolve primary key name
		keyName := this._ResolveKeyName(vk, sc)
		if (keyName == "")
			return

		; Retrieve current modifier states
		isCtrl := GetKeyState("Ctrl", "P")
		isAlt := GetKeyState("Alt", "P")
		isShift := GetKeyState("Shift", "P")
		isWin := (this._allowWin && (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")))

		; Construct AHK hotkey string
		hotkeyStr := (isWin ? "#" : "")
			. (isCtrl ? "^" : "")
			. (isAlt ? "!" : "")
			. (isShift ? "+" : "")
			. keyName

		; Save value and finish listening
		this._StopListening()
		this.Value := hotkeyStr

		; Shift focus away safely
		if (this._clearBtn)
			this._clearBtn.Focus()
		else
			DllCall("user32\SetFocus", "ptr", this._gui.Hwnd)
	}

	/**
	 * KeyUp handler from InputHook
	 */
	_OnHookKeyUp(ih, vk, sc) {
		if (!this._isListening)
			return

		; Update modifier preview when modifier release occurs
		if (this._IsModifierKey(vk)) {
			this._UpdateModifierPreview()
		}
	}

	/**
	 * Updates live modifier preview while modifiers are held down (e.g. "Ctrl + Alt + ...")
	 */
	_UpdateModifierPreview() {
		if (!this._isListening)
			return

		isCtrl := GetKeyState("Ctrl", "P")
		isAlt := GetKeyState("Alt", "P")
		isShift := GetKeyState("Shift", "P")
		isWin := (this._allowWin && (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")))

		mods := ""
		if (isWin)
			mods .= "Win + "
		if (isCtrl)
			mods .= "Ctrl + "
		if (isAlt)
			mods .= "Alt + "
		if (isShift)
			mods .= "Shift + "

		newText := (mods != "") ? "[ " . mods . "... ]" : "[ " . this._placeholder . " ]"
		if (this._editCtrl.Value != newText)
			this._editCtrl.Value := newText
	}

	/**
	 * Resolves clean, standardized key names from VK and SC codes
	 */
	_ResolveKeyName(vk, sc) {
		; Direct VK-based mappings for special keys
		static vkMap := Map(
			0x1B, "Escape",
			0x13, "Pause",
			0x2C, "PrintScreen",
			0x09, "Tab",
			0x0D, "Enter",
			0x20, "Space",
			0x08, "Backspace",
			0x2E, "Delete",
			0x2D, "Insert",
			0x24, "Home",
			0x23, "End",
			0x21, "PgUp",
			0x22, "PgDn",
			0x25, "Left",
			0x26, "Up",
			0x27, "Right",
			0x28, "Down",
			0x14, "CapsLock",
			0x90, "NumLock",
			0x91, "ScrollLock",
			0x5D, "AppsKey"
		)

		if (vkMap.Has(vk))
			return vkMap[vk]

		; Function keys: F1 - F24
		if (vk >= 0x70 && vk <= 0x87)
			return "F" . (vk - 0x6F)

		; Numpad keys
		static numpadMap := Map(
			0x60, "Numpad0", 0x61, "Numpad1", 0x62, "Numpad2", 0x63, "Numpad3", 0x64, "Numpad4",
			0x65, "Numpad5", 0x66, "Numpad6", 0x67, "Numpad7", 0x68, "Numpad8", 0x69, "Numpad9",
			0x6A, "NumpadMult", 0x6B, "NumpadAdd", 0x6D, "NumpadSub", 0x6E, "NumpadDot", 0x6F, "NumpadDiv"
		)
		if (numpadMap.Has(vk))
			return numpadMap[vk]

		; General AHK key name resolution
		keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
		if (keyName != "")
			return keyName

		return Format("vk{:x}", vk)
	}

	/**
	 * Checks if a given Virtual Key code corresponds to a modifier key
	 */
	_IsModifierKey(vk) {
		; Control, Shift, Alt, Win key codes
		return (vk == 0x11 || vk == 0xA2 || vk == 0xA3 ; Control, LControl, RControl
			|| vk == 0x10 || vk == 0xA0 || vk == 0xA1 ; Shift, LShift, RShift
			|| vk == 0x12 || vk == 0xA4 || vk == 0xA5 ; Menu/Alt, LAlt, RAlt
			|| vk == 0x5B || vk == 0x5C)              ; LWin, RWin
	}

	/**
	 * Updates the visible text in the Edit control
	 */
	_UpdateDisplayText() {
		if (this._value == "") {
			this._editCtrl.Value := ""
		} else {
			this._editCtrl.Value := HotkeyPlus.FormatKeyToText(this._value)
		}
	}

	; =========================================================================
	; Win32 Subclass Procedure
	; =========================================================================

	_SubclassProc(hWnd, uMsg, wParam, lParam, uIdSubclass, dwRefData) {
		; 0. Window destruction: cleanly detach subclass and release callback
		if (uMsg == HotkeyPlus.WM_NCDESTROY) {
			this._Cleanup(hWnd, uIdSubclass)
			return DllCall("comctl32\DefSubclassProc",
				"ptr", hWnd, "uint", uMsg, "uptr", wParam, "ptr", lParam, "ptr")
		}

		; 1. Prevent Dialog Manager from intercepting Tab, Enter, Escape
		if (uMsg == HotkeyPlus.WM_GETDLGCODE) {
			return HotkeyPlus.DLGC_WANTALLKEYS
		}

		; 2. Focus gained: start listening
		if (uMsg == HotkeyPlus.WM_SETFOCUS) {
			this._StartListening()
			return 0
		}

		; 3. Focus lost: stop listening
		if (uMsg == HotkeyPlus.WM_KILLFOCUS) {
			this._StopListening()
			return 0
		}

		; 4. Suppress default typing characters and beep (WM_CHAR / WM_SYSCHAR)
		if (uMsg == HotkeyPlus.WM_CHAR || uMsg == HotkeyPlus.WM_SYSCHAR) {
			return 0
		}

		; 5. Right-click context menu: Clear and Reset
		if (uMsg == HotkeyPlus.WM_CONTEXTMENU) {
			this._ShowContextMenu()
			return 0
		}

		; 6. Mouse buttons (when AllowMouse is enabled)
		if (this._allowMouse && this._isListening) {
			if (uMsg == HotkeyPlus.WM_MBUTTONDOWN) {
				this._ApplyMouseHotkey("MButton")
				return 0
			} else if (uMsg == HotkeyPlus.WM_XBUTTONDOWN) {
				xBtn := ((wParam >> 16) & 0xFFFF) == 1 ? "XButton1" : "XButton2"
				this._ApplyMouseHotkey(xBtn)
				return 0
			} else if (uMsg == HotkeyPlus.WM_MOUSEWHEEL) {
				delta := (wParam >> 16) & 0xFFFF
				wheel := (delta >= 0x8000) ? "WheelDown" : "WheelUp"
				this._ApplyMouseHotkey(wheel)
				return 0
			}
		}

		return DllCall("comctl32\DefSubclassProc",
			"ptr", hWnd, "uint", uMsg, "uptr", wParam, "ptr", lParam, "ptr")
	}

	/**
	 * Combines active modifiers with mouse button and assigns as hotkey
	 */
	_ApplyMouseHotkey(btnName) {
		isCtrl := GetKeyState("Ctrl", "P")
		isAlt := GetKeyState("Alt", "P")
		isShift := GetKeyState("Shift", "P")
		isWin := (this._allowWin && (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")))

		hotkeyStr := (isWin ? "#" : "")
			. (isCtrl ? "^" : "")
			. (isAlt ? "!" : "")
			. (isShift ? "+" : "")
			. btnName

		this._StopListening()
		this.Value := hotkeyStr
		if (this._clearBtn)
			this._clearBtn.Focus()
		else
			DllCall("user32\SetFocus", "ptr", this._gui.Hwnd)
	}

	/**
	 * Shows the right-click context menu
	 */
	_ShowContextMenu() {
		m := Menu()
		m.Add("Clear Hotkey", (*) => this.Clear())
		m.Add("Reset to Default", (*) => this.Reset())
		m.Show()
	}

	; =========================================================================
	; Helpers
	; =========================================================================

	/**
	 * Invokes event callbacks safely
	 */
	_TriggerEvent(callbacks, args*) {
		for cb in callbacks {
			try {
				cb(this, args*)
			}
		}
	}

	/**
	 * Parses options string (w, h, x, y, vName, NoClear, NoWin, NoMouse, etc.)
	 */
	_ParseOptions(optStr) {
		res := {
			w: 180,
			h: 24,
			posStr: "",
			otherOpt: "",
			name: "",
			noClear: false,
			noWin: false,
			noMouse: false
		}

		tokens := StrSplit(optStr, [" ", "`t"])
		posTokens := []
		otherTokens := []

		for token in tokens {
			if (token == "")
				continue

			lower := StrLower(token)
			if (lower == "noclear") {
				res.noClear := true
			} else if (lower == "nowin") {
				res.noWin := true
			} else if (lower == "nomouse") {
				res.noMouse := true
			} else if (RegExMatch(token, "i)^w(\d+)$", &m)) {
				res.w := Integer(m[1])
			} else if (RegExMatch(token, "i)^h(\d+)$", &m)) {
				res.h := Integer(m[1])
			} else if (RegExMatch(token, "i)^v([a-zA-Z0-9_#@$?\[\]]+)$", &m)) {
				res.name := m[1]
			} else if (RegExMatch(token, "i)^[xy][+-]?\d+")) {
				posTokens.Push(token)
			} else {
				otherTokens.Push(token)
			}
		}

		res.posStr := ""
		for p in posTokens
			res.posStr .= p . " "
		res.posStr := RTrim(res.posStr)

		res.otherOpt := ""
		for o in otherTokens
			res.otherOpt .= o . " "
		res.otherOpt := RTrim(res.otherOpt)

		return res
	}

	/**
	 * Removes subclassing and stops active InputHooks
	 */
	_Cleanup(hWnd := 0, uIdSubclass := 0) {
		if (this._subclassCb) {
			cb := this._subclassCb
			this._subclassCb := 0
			targetHwnd := hWnd ? hWnd : (this._editCtrl ? this._editCtrl.Hwnd : 0)
			subId := uIdSubclass ? uIdSubclass : targetHwnd
			if (targetHwnd) {
				DllCall("comctl32\RemoveWindowSubclass",
					"ptr", targetHwnd,
					"ptr", cb,
					"uptr", subId
				)
			}
			CallbackFree(cb)
		}
		if (this._isListening)
			this._StopListening()
		else if (this._inputHook) {
			this._inputHook.Stop()
			this._inputHook := ""
		}
	}

	/**
	 * Converts an AHK hotkey string into a human-readable format (e.g. "^!Escape" -> "Ctrl + Alt + Escape")
	 */
	static FormatKeyToText(ahkKey) {
		if (ahkKey == "")
			return "None"

		mods := ""
		pos := 1
		len := StrLen(ahkKey)

		while (pos <= len) {
			ch := SubStr(ahkKey, pos, 1)
			if (ch == "#")
				mods .= "Win + "
			else if (ch == "^")
				mods .= "Ctrl + "
			else if (ch == "!")
				mods .= "Alt + "
			else if (ch == "+")
				mods .= "Shift + "
			else if (ch == "~" || ch == "*") {
				; Skip pass-through and wildcard prefixes in display
			} else
				break
			pos++
		}

		mainKey := SubStr(ahkKey, pos)
		mainKey := HotkeyPlus.BeautifyKeyName(mainKey)
		return mods . mainKey
	}

	/**
	 * Beautifies key names for clean human presentation
	 */
	static BeautifyKeyName(key) {
		if (key == "")
			return ""

		static prettyMap := Map(
			"esc", "Escape",
			"escape", "Escape",
			"bs", "Backspace",
			"backspace", "Backspace",
			"del", "Delete",
			"delete", "Delete",
			"ins", "Insert",
			"insert", "Insert",
			"prntscrn", "PrintScreen",
			"printscreen", "PrintScreen",
			"pause", "Pause",
			"space", "Space",
			"tab", "Tab",
			"enter", "Enter",
			"return", "Enter",
			"up", "Up",
			"down", "Down",
			"left", "Left",
			"right", "Right",
			"pgup", "Page Up",
			"pgdn", "Page Down",
			"home", "Home",
			"end", "End",
			"appskey", "AppsKey",
			"capslock", "CapsLock",
			"numlock", "NumLock",
			"scrolllock", "ScrollLock",
			"numpad0", "Numpad 0",
			"numpad1", "Numpad 1",
			"numpad2", "Numpad 2",
			"numpad3", "Numpad 3",
			"numpad4", "Numpad 4",
			"numpad5", "Numpad 5",
			"numpad6", "Numpad 6",
			"numpad7", "Numpad 7",
			"numpad8", "Numpad 8",
			"numpad9", "Numpad 9",
			"numpaddot", "Numpad .",
			"numpaddiv", "Numpad /",
			"numpadmult", "Numpad *",
			"numpadadd", "Numpad +",
			"numpadsub", "Numpad -",
			"numpadenter", "Numpad Enter",
			"mbutton", "Middle Button (MButton)",
			"xbutton1", "Back Button (XButton1)",
			"xbutton2", "Forward Button (XButton2)",
			"wheelup", "Wheel Up",
			"wheeldown", "Wheel Down"
		)

		lower := StrLower(key)
		if prettyMap.Has(lower)
			return prettyMap[lower]

		if (StrLen(key) == 1)
			return StrUpper(key)

		return key
	}
}