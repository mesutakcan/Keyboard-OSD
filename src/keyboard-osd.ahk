/*
=========================
Keyboard OSD
v1.0
=========================
Keyboard OSD is a lightweight Windows utility that displays keyboard input and
 shortcut combinations on screen in real time.
It is designed for presentations, tutorials, screen recordings,
 and live demonstrations where visible keystrokes make the workflow easier to follow.
=========================
24/06/2026
Mesut Akcan
=========================
mesutakcan.blogspot.com
youtube.com/mesutakcan
=========================
Detailed information, source code, compiled binaries, and more are available on GitHub:
https://github.com/mesutakcan/Keyboard-OSD
=========================
*/

#Requires AutoHotkey v2
#SingleInstance Force

; ========================================
; COMPILER DIRECTIVES
; ========================================
;@Ahk2Exe-SetDescription Keyboard OSD
;@Ahk2Exe-SetFileVersion 1.0
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetMainIcon app_icon.ico

#Include "commonDialog.ahk"
#Include "settings-gui.ahk"

MAINICON := A_ScriptDir "\app_icon.ico"
PAUSEICON := A_ScriptDir "\app_icon_pause.ico"

Try TraySetIcon(MAINICON, , true)

AppVer := "1.0"

; SETTINGS
IniFile := A_ScriptDir "\settings.ini"
SetupTrayMenu()

osd := {
	TextColor: ReadIni("TextColor", "FFFFFF"),
	BgColor: ReadIni("BgColor", "EC3700"),
	BgAlpha: ReadIni("BgAlpha", 200, true),
	FontSize: ReadIni("FontSize", 20, true),
	FontName: ReadIni("FontName", "Segoe UI"),
	FontBold: ReadIni("FontBold", 1, true),
	FontItalic: ReadIni("FontItalic", 0, true),
	FontUnderline: ReadIni("FontUnderline", 0, true),
	FontStrikeout: ReadIni("FontStrikeout", 0, true),
	DisplayTime: ReadIni("DisplayTime", 3000, true),
	Width: ReadIni("Width", 100, true),
	AutoWidth: ReadIni("AutoWidth", 1, true),
	WordWrap: ReadIni("WordWrap", 1, true),
	LineHeight: ReadIni("LineHeight", 38, true),
	MaxLines: ReadIni("MaxLines", 5, true),
	Position: ReadIni("Position", "BottomLeft"),
	MarginX: ReadIni("MarginX", 20, true),
	MarginY: ReadIni("MarginY", 30, true),
	LineGap: ReadIni("LineGap", 2, true),
	CornerRadius: ReadIni("CornerRadius", 1, true),
	DismissDelay: ReadIni("DismissDelay", 500, true),
	HistFontSize: ReadIni("HistFontSize", 15, true),
	HistAlpha: ReadIni("HistAlpha", 150, true),
	HistTextColor: ReadIni("HistTextColor", "FFFFFF"),
	HistBgColor: ReadIni("HistBgColor", "AAAAAA"),
	ModifierDelay: ReadIni("ModifierDelay", 150, true)
}

; Global State
global LastKey := "" ; Last key or combination displayed (for repeat detection)
global RepeatCount := 0 ; Number of times the last key or combination has been repeated
global DownVKs := Map() ; currently-held "main" keys (vk -> true)

; Automatically calculated values (do not modify manually)
CHAR_WIDTH_RATIO := 0.55 ; Average character width ratio
osd.MaxTyping := Max(10, Floor((osd.Width - 16) / (osd.FontSize * CHAR_WIDTH_RATIO))) ; Maximum number of characters that can fit in the OSD width
osd.HistLineHeight := Round(osd.HistFontSize * 1.5) + 4 ; Height of historical lines based on font size
global DownMods := Map() ; currently-held modifier VKs (vk -> name)
global PendingMod := "" ; modifier name waiting to be committed
global Lines := [] ; Array of lines currently displayed in the OSD
global TypingBuf := "" ; Buffer for typing characters before they are pushed as a line

; Separate Gui window for each line. index 1..osd.MaxLines
global RowWins := [] ; Gui objects
global RowLabels := [] ; Text controls
global RowReady := [] ; Tracks if click-through/transparency is initialized
global TextMeasureFontCache := Map()

; ======================
; Create Row Windows
; ======================
; The font options string is used to set the font for each label.
; It includes the font size, weight (bold or normal), style (italic), underline, and strikeout options.
global activeOptions := "s" osd.FontSize
	. " " (osd.FontBold ? "Bold" : "norm")
	. (osd.FontItalic ? " Italic" : "")
	. (osd.FontUnderline ? " Underline" : "")
	. (osd.FontStrikeout ? " Strike" : "")

global histOptions := "s" osd.HistFontSize
	. " " (osd.FontBold ? "Bold" : "norm")
	. (osd.FontItalic ? " Italic" : "")
	. (osd.FontUnderline ? " Underline" : "")
	. (osd.FontStrikeout ? " Strike" : "")

; Create the row windows and labels for the OSD. Each row is a separate GUI window with a text label.
loop osd.MaxLines {
	w := Gui("+AlwaysOnTop -Caption +ToolWindow") ; No border, no title bar, always on top
	w.BackColor := osd.BgColor ; Set the background color of the window
	lbl := w.AddText("x0 y0 w" osd.Width " h" osd.LineHeight ; Set the position and size of the text label
		" c" osd.TextColor " Center", "")
	lbl.SetFont(activeOptions, osd.FontName) ; Set the font for the label using the active font options
	RowWins.Push(w) ; Add the window to the RowWins array
	RowLabels.Push(lbl) ; Add the label to the RowLabels array
	RowReady.Push(false) ; Mark the row as not ready for click-through and transparency
}

; DWM corner rounding and shadow removal
ApplyDWMCorners(hwnd) {
	; Corner rounding. DWMWA_WINDOW_CORNER_PREFERENCE = 33
	; 2 = DWMWCP_ROUND, 1 = DWMWCP_DONOTROUND
	pref := Buffer(4, 0)
	NumPut("Int", osd.CornerRadius ? 2 : 1, pref)
	DllCall("dwmapi\DwmSetWindowAttribute",
		"Ptr", hwnd,
		"UInt", 33,
		"Ptr", pref,
		"UInt", 4)

	; Disable shadow. DWMWA_NCRENDERING_POLICY = 2, DWMNCRP_DISABLED = 1
	ncr := Buffer(4, 0)
	NumPut("Int", 1, ncr)
	DllCall("dwmapi\DwmSetWindowAttribute",
		"Ptr", hwnd,
		"UInt", 2,
		"Ptr", ncr,
		"UInt", 4)
}

; Initialize a row window for the first time
InitWin(idx, alpha) {
	hwnd := RowWins[idx].Hwnd
	; Enable click-through
	curStyle := WinGetExStyle(hwnd)
	WinSetExStyle(curStyle | 0x20, hwnd) ; WS_EX_TRANSPARENT
	; Remove CS_DROPSHADOW (0x20000) class style to prevent window shadows
	curClass := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr")
	if (curClass & 0x20000)
		DllCall("SetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr", curClass & ~0x20000)
	; Set Transparency
	WinSetTransparent(alpha, hwnd)
	; Apply DWM corners and shadow policy
	ApplyDWMCorners(hwnd)
	RowReady[idx] := true
}

; VK → actual Unicode character
; Keyboard state is built manually via GetAsyncKeyState to avoid
; thread-local GetKeyboardState returning stale data, and to prevent
; ToUnicodeEx from affecting the active window's input queue
VKtoChar(vk) {
	static kbState := Buffer(256, 0)
	static outBuf := Buffer(8, 0)
	static modVKs := [0x10, 0x11, 0x12,  ; Shift, Ctrl, Alt
		0xA0, 0xA1,   ; LShift, RShift
		0xA2, 0xA3,   ; LCtrl, RCtrl
		0xA4, 0xA5,   ; LAlt, RAlt
		0x14, 0x90, 0x91]  ; CapsLock, NumLock, ScrollLock

	; Build keyboard state manually from async (hardware) state.
	; This avoids GetKeyboardState returning stale modifier bits
	; when called from a timer thread, and avoids any interaction
	; with the foreground window's input queue.
	DllCall("kernel32\RtlZeroMemory", "Ptr", kbState.Ptr, "UPtr", kbState.Size)
	DllCall("kernel32\RtlZeroMemory", "Ptr", outBuf.Ptr, "UPtr", outBuf.Size)

	; Set modifier bits directly from async key state
	for m in modVKs {
		if (DllCall("GetAsyncKeyState", "UShort", m, "Short") & 0x8000)
			NumPut("UChar", 0x80, kbState, m)
	}

	; CapsLock / NumLock / ScrollLock toggle state
	for m in [0x14, 0x90, 0x91] {
		if (DllCall("GetKeyState", "UShort", m, "Short") & 0x0001)
			NumPut("UChar", NumGet(kbState, m, "UChar") | 0x01, kbState, m)
	}

	hkl := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
	scanCode := DllCall("MapVirtualKeyEx", "UInt", vk, "UInt", 0, "Ptr", hkl, "UInt")
	; wFlags = 4: prevents ToUnicodeEx from changing keyboard state
	ret := DllCall("ToUnicodeEx",
		"UInt", vk, "UInt", scanCode,
		"Ptr", kbState, "Ptr", outBuf,
		"Int", 4, "UInt", 4, "Ptr", hkl, "Int")
	return (ret > 0) ? StrGet(outBuf, ret, "UTF-16") : ""
}

; Is it a typing character?
IsTypingVK(vk, &outChar) {
	static excludeVK := Map(
		0x08, 1, 0x09, 1, 0x0D, 1, 0x1B, 1, 0x20, 1,
		0x21, 1, 0x22, 1, 0x23, 1, 0x24, 1,
		0x25, 1, 0x26, 1, 0x27, 1, 0x28, 1,
		0x2C, 1, 0x2D, 1, 0x2E, 1,
		0x5B, 1, 0x5C, 1,
		0x70, 1, 0x71, 1, 0x72, 1, 0x73, 1,
		0x74, 1, 0x75, 1, 0x76, 1, 0x77, 1,
		0x78, 1, 0x79, 1, 0x7A, 1, 0x7B, 1,
		0x7C, 1, 0x7D, 1, 0x7E, 1, 0x7F, 1,
		0x80, 1, 0x81, 1, 0x82, 1, 0x83, 1,
		0x90, 1, 0x91, 1, 0x14, 1,
		0xA0, 1, 0xA1, 1, 0xA2, 1, 0xA3, 1, 0xA4, 1, 0xA5, 1
	)
	if excludeVK.Has(vk) {
		outChar := ""
		return false
	}
	ch := VKtoChar(vk)

	; Exclude control characters (ASCII < 0x20) and empty results
	if (ch = "" || Ord(SubStr(ch, 1, 1)) < 0x20) {
		outChar := ""
		return false
	}
	outChar := ch
	return true
}

; Get the work area of the monitor where the active (foreground) window is located
; Returns: Map with {x, y, w, h} (excluding taskbar)
GetActiveMonitorBounds() {
	; Prefer foreground window for keyboard-driven OSD; fallback to primary monitor
	try hwnd := WinGetID("A")
	catch
		hwnd := 0
	if (hwnd) {
		try WinGetPos(&wx, &wy, , , hwnd)
		catch
			hwnd := 0
	}
	if (hwnd) {
		monCount := MonitorGetCount()
		loop monCount {
			MonitorGet(A_Index, &mL, &mT, &mR, &mB)
			if (wx >= mL && wx < mR && wy >= mT && wy < mB) {
				MonitorGetWorkArea(A_Index, &wL, &wT, &wR, &wB)
				return Map("x", wL, "y", wT, "w", wR - wL, "h", wB - wT)
			}
		}
	}
	MonitorGetWorkArea(MonitorGetPrimary(), &wL, &wT, &wR, &wB)
	return Map("x", wL, "y", wT, "w", wR - wL, "h", wB - wT)
}

TogglePause(ItemName, *) {
	Pause(-1)
	if A_IsPaused {
		A_TrayMenu.Check(ItemName)
		Try TraySetIcon(PAUSEICON, , true)
	} else {
		A_TrayMenu.Uncheck(ItemName)
		Try TraySetIcon(MAINICON, , true)
	}
}

ShowAbout(*) {
	MsgBox(
		"Keyboard OSD v" AppVer "`n`n"
		"Keyboard OSD displays keyboard input and shortcut combinations on screen in real time.`n`n"
		. "©2026 Mesut Akcan`n"
		. "mesutakcan.blogspot.com`n"
		. "youtube.com/mesutakcan`n"
		. "github.com/mesutakcan/Keyboard-OSD",
		"About Keyboard OSD",
		"IconI"
	)
}

; Calculate stack position
CalcStackBase(mon, totalH, winW := 0) {
	global osd
	; If winW is not provided, use osd.Width. Otherwise, use the provided width.
	if (winW = 0)
		winW := osd.Width
	mX := mon["x"]
	mY := mon["y"]
	mW := mon["w"]
	mH := mon["h"]
	switch osd.Position {
		case "BottomRight":
			return [mX + mW - winW - osd.MarginX,
				mY + mH - osd.MarginY - totalH]
		case "BottomLeft":
			return [mX + osd.MarginX,
				mY + mH - osd.MarginY - totalH]
		case "BottomCenter":
			return [mX + (mW - winW) // 2,
				mY + mH - osd.MarginY - totalH]
		case "TopRight":
			return [mX + mW - winW - osd.MarginX, mY + osd.MarginY]
		case "TopLeft":
			return [mX + osd.MarginX, mY + osd.MarginY]
		case "TopCenter":
			return [mX + (mW - winW) // 2, mY + osd.MarginY]
		default:
			return [mX + mW - winW - osd.MarginX,
				mY + mH - osd.MarginY - totalH]
	}
}

; OSD render. each row is an independent window
RenderOSD(extraLine := "") {
	global RowWins, RowLabels, RowReady, osd, Lines

	; Active monitor bounds. MaxWidth is capped by the settings "Max width" value.
	static lastMonW := 0
	static cachedMaxWidth := 0
	mon := GetActiveMonitorBounds()

	; If monitor width has changed, recalculate cachedMaxWidth
	if (mon["w"] != lastMonW) {
		lastMonW := mon["w"]
		cachedMaxWidth := Min(osd.Width, Round(mon["w"] * 0.75))
	}
	OSD_MaxWidth := cachedMaxWidth

	; Cancel ongoing sequential hiding
	SetTimer(StartDismiss, 0)
	SetTimer(DismissNext, 0)

	; Compile lines to display
	allLines := []
	for ln in Lines
		allLines.Push(ln)
	if (extraLine != "")
		allLines.Push(extraLine)

	; If no lines to display, hide all windows and return
	if (allLines.Length = 0) {
		loop osd.MaxLines
			RowWins[A_Index].Hide()
		return
	}

	; Take last osd.MaxLines lines
	start := Max(1, allLines.Length - osd.MaxLines + 1)
	visLines := []
	loop (allLines.Length - start + 1)
		visLines.Push(allLines[start + A_Index - 1])

	total := visLines.Length
	activeIdx := total ; latest line = active line

	; Stack total height
	totalH := 0
	loop total {
		totalH += (A_Index = activeIdx) ? osd.LineHeight : osd.HistLineHeight
		if (A_Index < total)
			totalH += osd.LineGap
	}

	; Compute per-line widths (either fixed Max width or auto per-content)
	widths := []

	; If AutoWidth is disabled, all lines use the same width (capped by OSD_MaxWidth).
	if (!osd.AutoWidth) {
		defaultW := Min(osd.Width, OSD_MaxWidth)
		loop total
			widths.Push(defaultW)
	} else {
		loop total {
			idx := A_Index
			fs := (idx = activeIdx) ? osd.FontSize : osd.HistFontSize
			tw := MeasureTextWidth(visLines[idx], osd.FontName, fs, osd.FontBold, osd.FontItalic)
			tw += 16 ; inner padding
			widths.Push(Min(tw, OSD_MaxWidth))
		}
	}

	; If AutoWidth is used, update MaxTyping based on the allowed maximum width,
	; not the current content width.
	if (osd.AutoWidth)
		osd.MaxTyping := Max(10, Floor((OSD_MaxWidth - 16) / (osd.FontSize * CHAR_WIDTH_RATIO)))

	; baseY is common; horizontal X depends on each row's width
	baseY := CalcStackBase(mon, totalH)[2]

	yOffset := 0
	loop total {
		idx := A_Index
		isActive := (idx = activeIdx)
		lh := isActive ? osd.LineHeight : osd.HistLineHeight
		fs := isActive ? osd.FontSize : osd.HistFontSize
		alpha := isActive ? osd.BgAlpha : osd.HistAlpha
		clr := isActive ? osd.TextColor : osd.HistTextColor
		bgClr := isActive ? osd.BgColor : osd.HistBgColor

		w := RowWins[idx]
		lbl := RowLabels[idx]

		w.BackColor := bgClr

		; Update only if font options changed (for performance)
		opts := isActive ? activeOptions : histOptions
		static lastOpts := Map()

		; If the font options for this row have changed since last render, update the label's font.
		if !lastOpts.Has(idx) || lastOpts[idx] != opts {
			lbl.SetFont(opts, osd.FontName)
			lastOpts[idx] := opts
		}

		lbl.Opt("c" clr)
		rowW := widths[idx]
		lbl.Move(0, 0, rowW, lh)
		lbl.Text := visLines[idx]

		; only X depends on row width. avoid recalculating Y
		rowBaseX := CalcStackBase(mon, totalH, rowW)[1]

		w.Show("NA x" (rowBaseX) " y" (baseY + yOffset) " w" rowW " h" lh)

		; Initialize click-through and transparency on first show
		if !RowReady[idx]
			InitWin(idx, alpha)
		else
			WinSetTransparent(alpha, w.Hwnd)

		yOffset += lh + osd.LineGap
	}

	; Hide unused windows
	if (total < osd.MaxLines) {
		loop (osd.MaxLines - total)
			RowWins[total + A_Index].Hide()
	}

	SetTimer(StartDismiss, 0)
	SetTimer(StartDismiss, -osd.DisplayTime)
}

; Measure text width using GDI (pixels)
MeasureTextWidth(text, fontName, fontSize, bold := true, italic := false) {
	global TextMeasureFontCache
	static hDC := 0
	; Create a compatible DC for text measurement if not already created
	if !hDC
		hDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")

	cacheKey := fontName "|" fontSize "|" bold "|" italic
	; Create and cache GDI font object if not already cached
	if !TextMeasureFontCache.Has(cacheKey) {
		lf := Buffer(92, 0)
		NumPut("Int", -Round(fontSize * A_ScreenDPI / 72), lf, 0) ; lfHeight
		NumPut("Int", bold ? 700 : 400, lf, 16) ; lfWeight
		NumPut("UChar", italic ? 1 : 0, lf, 20) ; lfItalic
		NumPut("UChar", 0, lf, 23) ; lfCharSet = DEFAULT_CHARSET
		StrPut(fontName, lf.Ptr + 28, 32, "UTF-16")
		TextMeasureFontCache[cacheKey] := DllCall("CreateFontIndirectW", "Ptr", lf, "Ptr")
	}

	hOld := DllCall("SelectObject", "Ptr", hDC, "Ptr", TextMeasureFontCache[cacheKey], "Ptr")
	size := Buffer(8, 0)
	DllCall("GetTextExtentPoint32W",
		"Ptr", hDC,
		"Str", text,
		"Int", StrLen(text),
		"Ptr", size)
	DllCall("SelectObject", "Ptr", hDC, "Ptr", hOld)
	return NumGet(size, 0, "Int")
}

ClearMeasureTextWidthCache() {
	global TextMeasureFontCache
	for , hFont in TextMeasureFontCache {
		; Delete GDI font objects to prevent resource leaks
		if hFont
			DllCall("DeleteObject", "Ptr", hFont)
	}
	TextMeasureFontCache.Clear()
}

; Helpers
PushLine(line) {
	global Lines, osd
	Lines.Push(line)
	; Trim to max lines
	while (Lines.Length > osd.MaxLines)
		Lines.RemoveAt(1)
}

FlushTyping() {
	global TypingBuf, LastKey, RepeatCount

	; If there is any typing buffer, push it as a line and reset the buffer and state.
	if (TypingBuf != "") {
		PushLine(TypingBuf)
		TypingBuf := ""
		LastKey := ""
		RepeatCount := 0
	}
}

FindLastWordBreak(text) {
	lastBreak := 0
	loop StrLen(text) {
		ch := SubStr(text, A_Index, 1)

		; Only consider space and tab as word breaks for simplicity
		if (ch = " " || ch = A_Tab)
			lastBreak := A_Index
	}
	return lastBreak
}

WrapTypingBuffer(nextText) {
	global TypingBuf
	candidate := TypingBuf . nextText
	breakAt := FindLastWordBreak(candidate)
	; If a word break is found, split the candidate at that point and push the first part as a line.
	if (breakAt > 1) {
		line := RTrim(SubStr(candidate, 1, breakAt - 1))
		rest := LTrim(SubStr(candidate, breakAt + 1))

		; If the line is not empty, push it to the Lines array.
		if (line != "")
			PushLine(line)

		TypingBuf := rest
		return
	}

	FlushTyping()
	TypingBuf := nextText
}

; ============================================================
; Sequential Dismissal. from top line downwards
;
; StartDismiss - triggered after osd.DisplayTime
; DismissNext - dismisses one line every osd.DismissDelay
; HideOSD - resets state when all lines are hidden
; ============================================================
StartDismiss() {
	global RowWins, osd
	anyVisible := false
	loop osd.MaxLines {
		; Check if any row window is visible. If so, start sequential dismissal.
		if DllCall("IsWindowVisible", "Ptr", RowWins[A_Index].Hwnd) {
			anyVisible := true
			break
		}
	}
	anyVisible ? DismissNext() : HideOSD()
}

DismissNext() {
	global RowWins, osd

	; Collect visible windows (index order = top to bottom)
	visible := []

	loop osd.MaxLines {
		if DllCall("IsWindowVisible", "Ptr", RowWins[A_Index].Hwnd)
			visible.Push(A_Index)
	}

	if (visible.Length = 0) {
		HideOSD()
		return
	}

	RowWins[visible[1]].Hide() ; hide the top one

	if (visible.Length = 1)
		HideOSD()
	else
		SetTimer(DismissNext, -osd.DismissDelay)
}

HideOSD() {
	global RowWins, osd
	global LastKey, RepeatCount, Lines, TypingBuf, PendingMod
	SetTimer(StartDismiss, 0)
	SetTimer(DismissNext, 0)
	SetTimer(CommitPendingMod, 0)

	; Reset state
	loop osd.MaxLines
		RowWins[A_Index].Hide()

	LastKey := ""
	RepeatCount := 0
	Lines := []
	TypingBuf := ""
	PendingMod := ""
}

; Key Watcher (runs every 16ms) Tracks every currently-held key in a Map,
; so a second key pressed while a first is still down is no longer missed.
; Modifier state is captured at the moment the key is first detected as down,
; so HandleKeyPress always sees the correct modifiers. Lone modifier presses
; (Ctrl/Shift/Alt alone) are shown after osd.ModifierDelay ms.
KeyWatcher() {
	global DownVKs, DownMods, PendingMod

	; VK → display name for the three modifier groups
	static modMap := Map(
		0x10, "Shift", 0xA0, "Shift", 0xA1, "Shift",
		0x11, "Ctrl", 0xA2, "Ctrl", 0xA3, "Ctrl",
		0x12, "Alt", 0xA4, "Alt", 0xA5, "Alt"
	)

	; Snapshot modifier state once for this tick
	tickShift := DllCall("GetAsyncKeyState", "UShort", 0x10, "Short") & 0x8000
	tickLCtrl := DllCall("GetAsyncKeyState", "UShort", 0xA2, "Short") & 0x8000
	tickRAlt := DllCall("GetAsyncKeyState", "UShort", 0xA5, "Short") & 0x8000
	tickCtrl := DllCall("GetAsyncKeyState", "UShort", 0x11, "Short") & 0x8000
	tickAlt := DllCall("GetAsyncKeyState", "UShort", 0x12, "Short") & 0x8000
	tickLWin := DllCall("GetAsyncKeyState", "UShort", 0x5B, "Short") & 0x8000
	tickRWin := DllCall("GetAsyncKeyState", "UShort", 0x5C, "Short") & 0x8000
	tickIsAltGr := (tickLCtrl && tickRAlt)

	; Track modifier key presses
	stillMods := Map()
	newModName := "" ; first newly pressed modifier this tick (if any)
	for vk, name in modMap {
		isDown := DllCall("GetAsyncKeyState", "UShort", vk, "Short") & 0x8000

		; Only handle newly pressed modifiers (not already in DownMods)
		if isDown {
			; Normalise to canonical VK to avoid double-counting L/R variants
			canonVK := (vk = 0xA0 || vk = 0xA1) ? 0x10
				: (vk = 0xA2 || vk = 0xA3) ? 0x11
				: (vk = 0xA4 || vk = 0xA5) ? 0x12
				: vk
			stillMods[canonVK] := name

			; Only the first newly pressed modifier is tracked for lone-modifier display.
			if (!DownMods.Has(canonVK) && newModName = "")
				newModName := name
		}
	}
	DownMods := stillMods

	; Track main key presses
	stillDown := Map()
	newKeys := []

	Loop 255 {
		vk := A_Index

		; Skip mouse buttons (0x01-0x07) and modifiers (handled above)
		if (vk >= 1 && vk <= 7)
			continue

		; Skip modifier keys (0x10-0x12, 0xA0-0xA5) and Win keys (0x5B, 0x5C)
		if (vk = 0x10 || vk = 0x11 || vk = 0x12
			|| vk = 0x5B || vk = 0x5C
			|| (vk >= 0xA0 && vk <= 0xA5))
			continue

		; Skip mouse buttons (0x01-0x07) and modifiers (handled above)
		if !(DllCall("GetAsyncKeyState", "UShort", vk, "Short") & 0x8000)
			continue

		key := GetKeyName(Format("vk{:02X}", vk))

		; Skip keys that have no name (e.g., dead keys, OEM keys without a name)
		if (key = "")
			continue

		stillDown[vk] := true

		; Only handle newly pressed keys (not already in DownVKs)
		if !DownVKs.Has(vk)
			newKeys.Push([vk, key, tickShift, tickCtrl, tickAlt, tickIsAltGr, (tickLWin || tickRWin)])
	}

	DownVKs := stillDown

	; If a main key arrived, cancel pending lone-modifier display
	if (newKeys.Length > 0) {
		SetTimer(CommitPendingMod, 0)
		PendingMod := ""
	}

	; If a new modifier appeared and no main key is down, schedule lone display
	if (newModName != "" && stillDown.Count = 0 && !tickIsAltGr) {
		SetTimer(CommitPendingMod, 0)
		PendingMod := newModName
		SetTimer(CommitPendingMod, -osd.ModifierDelay)
	}
	; Handle all newly pressed main keys
	for info in newKeys
		HandleKeyPress(info[1], info[2], info[3], info[4], info[5], info[6], info[7])
}

; Fires after osd.ModifierDelay if no main key interrupted
; Commits the pending lone modifier name to the OSD
CommitPendingMod() {
	global PendingMod, LastKey, RepeatCount, Lines
	if (PendingMod = "")
		return

	name := PendingMod
	PendingMod := ""
	FlushTyping()

	; Handle repeated presses of the same key or combination
	if (name = LastKey) {
		RepeatCount++
		if (Lines.Length > 0)
			Lines[Lines.Length] := name . " ×" . (RepeatCount + 1)
	} else {
		LastKey := name
		RepeatCount := 0
		PushLine(name)
	}
	RenderOSD()
}

; Handles a single "newly pressed" event.
; Modifier state is passed in from KeyWatcher (captured at the moment
; the key was first detected as down) so we never read stale values
HandleKeyPress(foundVK, foundKey, hasShift, hasCtrl, hasAlt, isAltGr, hasWin) {
	global LastKey, RepeatCount, TypingBuf, osd, Lines

	; Build modifier list from captured state
	modList := []
	; AltGr is a special case: it is LCtrl+RAlt, but we want to show it as "AltGr" instead of "Ctrl + Alt"
	if (hasCtrl && !isAltGr)
		modList.Push("Ctrl")

	; Shift is a special case: it is only shown when combined with other keys
	if hasShift
		modList.Push("Shift")

	; Alt is a special case: it is only shown when combined with other keys, except for AltGr
	if (hasAlt && !isAltGr)
		modList.Push("Alt")

	; Win is a special case: it is only shown when combined with other keys
	if hasWin
		modList.Push("Win")

	hasMods := (modList.Length > 0)
	isSpace := (foundKey = "Space")

	; Handle Backspace in typing mode: remove last char from buffer, but only if no modifiers are held
	if (foundVK = 0x08 && !hasMods && TypingBuf != "") {
		TypingBuf := SubStr(TypingBuf, 1, StrLen(TypingBuf) - 1)
		RenderOSD(TypingBuf)
		LastKey := ""
		RepeatCount := 0
		return
	}

	typedChar := ""
	isTyping := false
	; Typing mode: no mods, or only Shift, or AltGr (which carries LCtrl+RAlt)
	if (!hasMods || (modList.Length = 1 && hasShift) || isAltGr)
		isTyping := IsTypingVK(foundVK, &typedChar)

	; Space continues typing only when there is already typed text.
	; Otherwise it falls through to special-key repeat handling as "Space".
	if isSpace && !hasMods && TypingBuf != "" {
		isTyping := true
		typedChar := " "
	}

	; TYPING MODE
	; If the key is a typing character, append to the typing buffer and render it.
	if isTyping {
		; Dynamic width-aware typing buffer: flush when typed text exceeds max allowed width
		mon := GetActiveMonitorBounds()
		maxW := Min(osd.Width, Round(mon["w"] * 0.75))
		candidate := TypingBuf . typedChar
		tw := MeasureTextWidth(candidate, osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + 16
		; If the candidate text exceeds the maximum width or max typing length, wrap or flush
		if (tw > maxW || StrLen(candidate) > osd.MaxTyping) {
			; If word wrap is enabled, wrap the buffer; otherwise, flush and start a new line
			if osd.WordWrap {
				WrapTypingBuffer(typedChar)
			} else {
				FlushTyping()
				TypingBuf := typedChar
			}
		} else {
			TypingBuf := candidate
		}
		RenderOSD(TypingBuf)
		LastKey := ""
		RepeatCount := 0
		return
	}

	; SPECIAL KEY / COMBINATION MODE
	; If the key is not a typing character, flush any existing typing buffer and display the key combination.
	FlushTyping()

	; For AltGr combos that didn't produce a typed char, show as "AltGr + key"
	if isAltGr
		modList := ["AltGr"]

	modList.Push(foundKey)
	label := ""
	for item in modList
		label .= (label = "" ? "" : " + ") item

	; Handle repeated presses of the same key or combination
	if (label = LastKey) {
		RepeatCount++
		if (Lines.Length > 0)
			Lines[Lines.Length] := label . " ×" . (RepeatCount + 1)
	} else {
		LastKey := label
		RepeatCount := 0
		PushLine(label)
	}

	RenderOSD()
}

ReadIni(Key, Def, asInt := false) {
	Val := IniRead(IniFile, "OSD", Key, Def)
	return asInt ? Number(Val) : Val
}

SetupTrayMenu() {
	A_TrayMenu.Delete()
	A_TrayMenu.Add("About", ShowAbout)
	A_TrayMenu.Add("GitHub Repository", (*) => Run("https://github.com/mesutakcan/Keyboard-OSD"))
	A_TrayMenu.Add()
	A_TrayMenu.Add("Settings", (*) => ShowSettingsGui())
	A_TrayMenu.Add("Reload", (*) => Reload())
	A_TrayMenu.Add("Pause OSD", TogglePause)
	A_TrayMenu.Add()
	A_TrayMenu.Add("Exit", (*) => ExitApp())
}

SetTimer(KeyWatcher, 16)
