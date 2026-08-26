/*
=========================
Keyboard OSD
=========================
Keyboard OSD is a lightweight Windows utility that displays keyboard input and
 shortcut combinations on screen in real time.
It is designed for presentations, tutorials, screen recordings,
 and live demonstrations where visible keystrokes make the workflow easier to follow.
=========================
26/08/2026
Mesut Akcan
=========================
mesutakcan.blogspot.com
youtube.com/mesutakcan
=========================
Detailed information, source code, compiled binaries, and more are available on GitHub:
https://github.com/mesutakcan/Keyboard-OSD
=========================
TODO:
* Allow key name customization
*/

#Requires AutoHotkey v2
#SingleInstance Force
;@Ahk2Exe-SetDescription Keyboard OSD
;@Ahk2Exe-SetFileVersion 1.6
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetMainIcon app_icon.ico
;@Ahk2Exe-AddResource app_icon_pause.ico, 207

A_ScriptName := "Keyboard OSD"

#Include "lib.ahk"
#Include "commonDialog.ahk"
#Include "GroupBox.ahk"
#Include "settings-gui.ahk"

AppVer := "1.6"

if !A_IsCompiled {
	MAINICON := A_ScriptDir "\app_icon.ico"
	PAUSEICON := A_ScriptDir "\app_icon_pause.ico"
	Try TraySetIcon(MAINICON, , true)
}

global WM_OSD_HIDE := 0x5555
OnMessage(WM_OSD_HIDE, OnExternalHide)

OnExternalHide(wParam, lParam, msg, hwnd) {
	HideOSDInstant()
}

IniFile := A_ScriptDir "\settings.ini"

global ExcludedKeyList := LoadExcludedKeys()
global HotkeyToggleStr := ReadIni("TogglePause", "!F12", , "Hotkeys")
global HotkeyHideStr := ReadIni("HideOSD", "!Delete", , "Hotkeys")
global PauseMenuItemName := "Pause OSD`t" FormatComboDisplay(HotkeyToggleStr)
global HideMenuItemName := "Hide OSD`t" FormatComboDisplay(HotkeyHideStr)

global SystemExcludedKeyList := []
for str in [HotkeyToggleStr, HotkeyHideStr] {
	parsed := ""
	try parsed := ParseKeyCombo(str)
	if (parsed != "")
		SystemExcludedKeyList.Push(parsed)
}

SetupTrayMenu()

OnExit(ClearMeasureTextWidthCache)
OnExit(ShutdownGdiplus)
OnExit(ClearBadgeCache)
InitGdiplus()

global TextMeasureFontCache := Map()
global CachedMaxWidth := 0
global TextMeasureFontHDC := 0

global SPECIAL_OUTER_RADIUS := 8
global SpecialBadgeCache := Map()

class OSDState {
	LastKey := ""
	DownVKs := Map()
	DownMods := Map()
	Lines := []
	PendingMod := ""
	PendingComposeTap := ""
	PendingDismiss := 0
	TypingBuf := ""
}

class OSDSettings {
	State := OSDState()
	TextColor := ReadIni("TextColor", "FFFFFF", , "Appearance")
	BgColor := ReadIni("BgColor", "EC3700", , "Appearance")
	BgAlpha := ReadIni("BgAlpha", 200, true, "Appearance")
	FontSize := ReadIni("FontSize", 20, true, "Appearance")
	FontName := ReadIni("FontName", "Segoe UI", , "Appearance")
	FontBold := ReadIni("FontBold", 1, true, "Appearance")
	FontItalic := ReadIni("FontItalic", 0, true, "Appearance")
	TextPadX := ReadIni("TextPadX", 8, true, "Appearance")
	TextPadY := ReadIni("TextPadY", 5, true, "Appearance")
	TextYNudge := ReadIni("TextYNudge", 0, true, "Appearance")
	CornerRadius := 1

	Width := ReadIni("Width", 350, true, "Layout")
	AutoWidth := ReadIni("AutoWidth", 1, true, "Layout")
	WordWrap := ReadIni("WordWrap", 1, true, "Layout")
	MaxLines := ReadIni("MaxLines", 5, true, "Layout")
	Position := ReadIni("Position", "BottomLeft", , "Layout")
	MarginX := ReadIni("MarginX", 20, true, "Layout")
	MarginY := ReadIni("MarginY", 30, true, "Layout")
	LineGap := ReadIni("LineGap", 2, true, "Layout")

	HistFontName := ReadIni("HistFontName", "Segoe UI", , "History")
	HistFontSize := ReadIni("HistFontSize", 15, true, "History")
	HistFontBold := ReadIni("HistFontBold", 1, true, "History")
	HistFontItalic := ReadIni("HistFontItalic", 0, true, "History")
	HistTextPadX := ReadIni("HistTextPadX", 8, true, "History")
	HistTextPadY := ReadIni("HistTextPadY", 5, true, "History")
	HistTextYNudge := ReadIni("HistTextYNudge", 0, true, "History")
	HistAlpha := ReadIni("HistAlpha", 150, true, "History")
	HistTextColor := ReadIni("HistTextColor", "FFFFFF", , "History")
	HistBgColor := ReadIni("HistBgColor", "AAAAAA", , "History")

	SpecialFontName := ReadIni("SpecialFontName", "Segoe UI", , "Special")
	SpecialFontSize := ReadIni("SpecialFontSize", 20, true, "Special")
	SpecialFontBold := ReadIni("SpecialFontBold", 1, true, "Special")
	SpecialFontItalic := ReadIni("SpecialFontItalic", 0, true, "Special")
	SpecialBgColor := ReadIni("SpecialBgColor", "FFFFFF", , "Special")
	SpecialTextColor := ReadIni("SpecialTextColor", "000000", , "Special")
	SpecialBorderColor := ReadIni("SpecialBorderColor", "000000", , "Special")
	SpecialAlpha := ReadIni("SpecialAlpha", 175, true, "Special")
	SpecialBorderWidth := ReadIni("SpecialBorderWidth", 3, true, "Special")
	SpecialTextPadX := ReadIni("SpecialTextPadX", 1, true, "Special")
	SpecialTextPadY := ReadIni("SpecialTextPadY", 1, true, "Special")
	SpecialTextYNudge := ReadIni("SpecialTextYNudge", -5, true, "Special")
	SpecialKeepStyleInHistory := ReadIni("SpecialKeepStyleInHistory", 0, true, "Special")

	DisplayTime := ReadIni("DisplayTime", 4000, true, "Timing")
	DismissDelay := ReadIni("DismissDelay", 3000, true, "Timing")
	ModifierDelay := ReadIni("ModifierDelay", 150, true, "Timing")

	FilterFunctionKeys := ReadIni("FilterFunctionKeys", 0, true, "Filters")
	FilterNumpad := ReadIni("FilterNumpad", 0, true, "Filters")
	FilterLetters := ReadIni("FilterLetters", 0, true, "Filters")
	FilterDigits := ReadIni("FilterDigits", 0, true, "Filters")
	FilterArrows := ReadIni("FilterArrows", 0, true, "Filters")
	FilterNavKeys := ReadIni("FilterNavKeys", 0, true, "Filters")
	FilterModifiers := ReadIni("FilterModifiers", 0, true, "Filters")
	FilterModifierMode := ReadIni("FilterModifierMode", "Alone", , "Filters")
	FilterCustomList := ReadIni("FilterCustomList", 1, true, "Filters")
	FilterOtherLetters := ReadIni("FilterOtherLetters", 0, true, "Filters")
	FilterOtherLettersChars := ReadIni("FilterOtherLettersChars", "", , "Filters")
}

global osd := OSDSettings()

class OSDLine {
	BaseText := ""
	Text := ""
	CreatedAt := 0
	ActiveSince := 0
	Count := 1
	IsSpecial := false

	__New(text, isSpecial := false) {
		this.BaseText := text
		this.Text := text
		this.CreatedAt := A_TickCount
		this.ActiveSince := A_TickCount
		this.IsSpecial := isSpecial
	}

	Age() {
		return A_TickCount - this.CreatedAt
	}

	ActiveAge() {
		return A_TickCount - this.ActiveSince
	}

	IsExpired(timeout) {
		return this.Age() >= timeout
	}

	IsActiveExpired(timeout) {
		return this.ActiveAge() >= timeout
	}

	Increment() {
		this.Count++
		this.Text := this.BaseText " ×" this.Count
		this.CreatedAt := A_TickCount
		this.ActiveSince := A_TickCount
	}

	ReplaceText(text) {
		this.BaseText := text
		this.Text := text
		this.Count := 1
		this.CreatedAt := A_TickCount
		this.ActiveSince := A_TickCount
	}
}

global CHAR_WIDTH_RATIO := 0.55
osd.LineHeight := MeasureTextHeight(osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + osd.TextPadY * 2
osd.HistLineHeight := MeasureTextHeight(osd.HistFontName, osd.HistFontSize, osd.HistFontBold, osd.HistFontItalic) + osd.HistTextPadY * 2
osd.MaxTyping := Max(10, Floor((osd.Width - osd.TextPadX * 2) / (osd.FontSize * CHAR_WIDTH_RATIO)))
global RowWins := []
global RowLabels := []
global RowPics := []
global RowReady := []
global FadingStates := []
global FadeTimers := []
global FadeAlphas := []
global FadeTargets := []
global activeOptions := "s" osd.FontSize
	. " " (osd.FontBold ? "Bold" : "norm")
	. (osd.FontItalic ? " Italic" : "")

global histOptions := "s" osd.HistFontSize
	. " " (osd.HistFontBold ? "Bold" : "norm")
	. (osd.HistFontItalic ? " Italic" : "")

global specialOptions := "s" osd.SpecialFontSize
	. " " (osd.SpecialFontBold ? "Bold" : "norm")
	. (osd.SpecialFontItalic ? " Italic" : "")

loop osd.MaxLines {
	w := Gui("+AlwaysOnTop -Caption +ToolWindow")
	w.BackColor := osd.BgColor
    
	pic := w.AddPicture("x0 y0 w1 h1 Hidden")
	lbl := w.AddText("x0 y0 w" osd.Width " h" osd.LineHeight " c" osd.TextColor " Center", "")
	lbl.SetFont(activeOptions, osd.FontName)
	RowWins.Push(w)
	RowLabels.Push(lbl)
	RowPics.Push(pic)
	RowReady.Push(false)
	FadingStates.Push(false)
	FadeTimers.Push(0)
	FadeAlphas.Push(255)
	FadeTargets.Push(255)
}

TogglePause(ItemName, *) {
	global osd
	Pause(-1)
	if (A_IsPaused) {
		A_TrayMenu.Check(ItemName)
		HideOSDInstant()
	} else {
		A_TrayMenu.Uncheck(ItemName)
		osd.State.DownVKs := Map()
		osd.State.DownMods := Map()

		Loop 255 {
			vk := A_Index
			if (vk >= 1 && vk <= 7)
				continue
			if (DllCall("GetAsyncKeyState", "UShort", vk, "Short") & 0x8000) {
				if (vk = 0x10 || vk = 0xA0 || vk = 0xA1)
					osd.State.DownMods[0x10] := "Shift"
				else if (vk = 0x11 || vk = 0xA2 || vk = 0xA3)
					osd.State.DownMods[0x11] := "Ctrl"
				else if (vk = 0x12 || vk = 0xA4 || vk = 0xA5)
					osd.State.DownMods[0x12] := "Alt"
				else if (vk = 0x5B || vk = 0x5C)
					osd.State.DownMods[0x5B] := "Win"
				else
					osd.State.DownVKs[vk] := true
			}
		}

		ResetOSDState()
	}
	if (!A_IsCompiled)
		Try TraySetIcon(A_IsPaused ? PAUSEICON : MAINICON, , true)
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

KeyWatcher() {
	global osd

	static modMap := Map(
		0x10, "Shift", 0xA0, "Shift", 0xA1, "Shift",
		0x11, "Ctrl", 0xA2, "Ctrl", 0xA3, "Ctrl",
		0x12, "Alt", 0xA4, "Alt", 0xA5, "Alt",
		0x5B, "Win", 0x5C, "Win"
	)

	tickShift := DllCall("GetAsyncKeyState", "UShort", 0x10, "Short") & 0x8000
	tickLCtrl := DllCall("GetAsyncKeyState", "UShort", 0xA2, "Short") & 0x8000
	tickRAlt := DllCall("GetAsyncKeyState", "UShort", 0xA5, "Short") & 0x8000
	tickCtrl := DllCall("GetAsyncKeyState", "UShort", 0x11, "Short") & 0x8000
	tickAlt := DllCall("GetAsyncKeyState", "UShort", 0x12, "Short") & 0x8000
	tickLWin := DllCall("GetAsyncKeyState", "UShort", 0x5B, "Short") & 0x8000
	tickRWin := DllCall("GetAsyncKeyState", "UShort", 0x5C, "Short") & 0x8000
	tickIsAltGr := (tickLCtrl && tickRAlt)

	stillMods := Map()
	newModAdded := false
	for vk, name in modMap {
		isDown := DllCall("GetAsyncKeyState", "UShort", vk, "Short") & 0x8000

		if isDown {
			canonVK := (vk = 0xA0 || vk = 0xA1) ? 0x10
				: (vk = 0xA2 || vk = 0xA3) ? 0x11
				: (vk = 0xA4 || vk = 0xA5) ? 0x12
				: (vk = 0x5C) ? 0x5B
				: vk
			stillMods[canonVK] := name

			if !osd.State.DownMods.Has(canonVK)
				newModAdded := true
		}
	}
	osd.State.DownMods := stillMods

	combinedMod := ""
	if (tickIsAltGr) {
		combinedMod := "AltGr"
	} else {
		if stillMods.Has(0x11)
			combinedMod .= (combinedMod = "" ? "" : " + ") "Ctrl"
		if stillMods.Has(0x10)
			combinedMod .= (combinedMod = "" ? "" : " + ") "Shift"
		if stillMods.Has(0x12)
			combinedMod .= (combinedMod = "" ? "" : " + ") "Alt"
		if stillMods.Has(0x5B)
			combinedMod .= (combinedMod = "" ? "" : " + ") "Win"
	}

	stillDown := Map()
	newKeys := []

	Loop 255 {
		vk := A_Index

		if (vk >= 1 && vk <= 7)
			continue

		if (vk = 0x10 || vk = 0x11 || vk = 0x12
			|| vk = 0x5B || vk = 0x5C
			|| (vk >= 0xA0 && vk <= 0xA5))
			continue

		if !(DllCall("GetAsyncKeyState", "UShort", vk, "Short") & 0x8000)
			continue

		key := GetKeyName(Format("vk{:02X}", vk))

		if (key = "")
			continue

		stillDown[vk] := true

		if !osd.State.DownVKs.Has(vk)
			newKeys.Push([vk, key, tickShift, tickCtrl, tickAlt, tickIsAltGr, (tickLWin || tickRWin)])
	}

	osd.State.DownVKs := stillDown

	if (newKeys.Length > 0) {
		SetTimer(CommitPendingMod, 0)
		osd.State.PendingMod := ""
		osd.State.PendingComposeTap := ""
	}

	if (newModAdded && combinedMod != "" && stillDown.Count = 0) {
		isComposeOnly := true
		for tok in StrSplit(combinedMod, " + ") {
			if !(tok = "Shift" || tok = "AltGr") {
				isComposeOnly := false
				break
			}
		}

		if (isComposeOnly && osd.State.TypingBuf != "") {
			SetTimer(CommitPendingMod, 0)
			osd.State.PendingMod := ""
			osd.State.PendingComposeTap := combinedMod
		} else {
			SetTimer(CommitPendingMod, 0)
			osd.State.PendingMod := combinedMod
			SetTimer(CommitPendingMod, -osd.ModifierDelay)
		}
	}

	if (stillMods.Count = 0 && osd.State.PendingComposeTap != "") {
		tapLabel := osd.State.PendingComposeTap
		osd.State.PendingComposeTap := ""

		if !IsModifierTapExcluded() {
			FlushTyping()

			if (tapLabel = osd.State.LastKey && osd.State.Lines.Length > 0) {
				osd.State.Lines[osd.State.Lines.Length].Increment()
			} else {
				osd.State.LastKey := tapLabel
				PushLine(tapLabel, true)
			}
			RenderOSD()
		}
	}
	for info in newKeys
		HandleKeyPress(info[1], info[2], info[3], info[4], info[5], info[6], info[7])
}

BuildModLabel(hasCtrl, hasShift, hasAlt, hasWin, isAltGr) {
	if isAltGr
		return "AltGr"
	label := ""
	if (hasCtrl && !isAltGr)
		label .= (label = "" ? "" : " + ") "Ctrl"
	if hasShift
		label .= (label = "" ? "" : " + ") "Shift"
	if (hasAlt && !isAltGr)
		label .= (label = "" ? "" : " + ") "Alt"
	if hasWin
		label .= (label = "" ? "" : " + ") "Win"
	return label
}

CommitPendingMod() {
	global osd
	if (osd.State.PendingMod = "")
		return

	name := osd.State.PendingMod
	osd.State.PendingMod := ""

        
	if (Trim(name) = "")
		return

	if IsModifierTapExcluded()
		return

	if !IsOSDVisible()
		ResetOSDState()

	FlushTyping()

	if (name = osd.State.LastKey && osd.State.Lines.Length > 0) {
		osd.State.Lines[osd.State.Lines.Length].Increment()
	} else if (osd.State.Lines.Length > 0 && osd.State.Lines[osd.State.Lines.Length].IsSpecial
		&& osd.State.LastKey != "" && TokensSubsetOf(osd.State.LastKey, name)) {
		osd.State.Lines[osd.State.Lines.Length].ReplaceText(name)
		osd.State.LastKey := name
	} else {
		osd.State.LastKey := name
		PushLine(name, true)
	}
	RenderOSD()
}

HandleKeyPress(foundVK, foundKey, hasShift, hasCtrl, hasAlt, isAltGr, hasWin) {
	global osd

	if IsKeyExcluded(hasCtrl, hasShift, hasAlt, hasWin, isAltGr, foundKey, foundVK) {
		modLabel := BuildModLabel(hasCtrl, hasShift, hasAlt, hasWin, isAltGr)
		if (modLabel != "" && osd.State.LastKey = modLabel && osd.State.Lines.Length > 0
			&& osd.State.Lines[osd.State.Lines.Length].IsSpecial) {
			osd.State.Lines.Pop()
			osd.State.LastKey := ""
			RenderOSD()
		}
		return
	}

	if !IsOSDVisible()
		ResetOSDState()

	modList := []
	if (hasCtrl && !isAltGr)
		modList.Push("Ctrl")
	if hasShift
		modList.Push("Shift")
	if (hasAlt && !isAltGr)
		modList.Push("Alt")
	if hasWin
		modList.Push("Win")

	hasMods := (modList.Length > 0)
	isSpace := (foundKey = "Space")

	if (foundVK = 0x08 && !hasMods && osd.State.TypingBuf != "") {
		osd.State.TypingBuf := SubStr(osd.State.TypingBuf, 1, StrLen(osd.State.TypingBuf) - 1)
		RenderOSD(osd.State.TypingBuf)
		SetTimer(FlushTypingTimeout, -osd.DisplayTime)
		osd.State.LastKey := ""
		return
	}

	typedChar := ""
	isTyping := false
	if (!hasMods || (modList.Length = 1 && hasShift) || isAltGr)
		isTyping := IsTypingVK(foundVK, &typedChar)

	if isSpace && !hasMods && osd.State.TypingBuf != "" {
		isTyping := true
		typedChar := " "
	}

	if isTyping {
		if (osd.State.TypingBuf == "" && osd.State.Lines.Length > 0) {
			lastLine := osd.State.Lines[osd.State.Lines.Length]
			isPureMod := true
			for tok in StrSplit(lastLine.BaseText, " + ") {
				if !(tok = "Ctrl" || tok = "Shift" || tok = "Alt" || tok = "Win" || tok = "AltGr") {
					isPureMod := false
					break
				}
			}
			if (lastLine.IsSpecial && isPureMod)
				osd.State.Lines.RemoveAt(osd.State.Lines.Length)
			else {
				lastLine.CreatedAt := A_TickCount
				lastLine.ActiveSince := A_TickCount
			}
		}

		maxW := CachedMaxWidth > 0 ? CachedMaxWidth : Min(osd.Width, Round(GetActiveMonitorBounds()["w"] * 0.75))
		candidate := osd.State.TypingBuf . typedChar
		tw := MeasureTextWidth(candidate, osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + osd.TextPadX * 2

		if (tw > maxW || StrLen(candidate) > osd.MaxTyping) {
			if osd.WordWrap {
				WrapTypingBuffer(typedChar)
			} else {
				FlushTyping()
				osd.State.TypingBuf := typedChar
			}
		} else {
			osd.State.TypingBuf := candidate
		}
		RenderOSD(osd.State.TypingBuf)
		SetTimer(FlushTypingTimeout, -osd.DisplayTime)
		osd.State.LastKey := ""
		return
	}

	FlushTyping()

	if isAltGr
		modList := ["AltGr"]

	modOnlyLabel := ""
	for item in modList
		modOnlyLabel .= (modOnlyLabel = "" ? "" : " + ") item

	modList.Push(foundKey)
	label := ""
	for item in modList
		label .= (label = "" ? "" : " + ") item

	if (label = osd.State.LastKey && osd.State.Lines.Length > 0) {
		osd.State.Lines[osd.State.Lines.Length].Increment()
	} else if (modOnlyLabel != "" && osd.State.Lines.Length > 0
		&& osd.State.Lines[osd.State.Lines.Length].IsSpecial
		&& osd.State.LastKey != "" && TokensSubsetOf(osd.State.LastKey, modOnlyLabel)) {
		osd.State.Lines[osd.State.Lines.Length].ReplaceText(label)
		osd.State.LastKey := label
	} else {
		osd.State.LastKey := label
		PushLine(label, true)
	}
	RenderOSD()
}

SetupTrayMenu() {
	A_TrayMenu.Delete()
	A_TrayMenu.Add("About", ShowAbout)
	A_TrayMenu.Add("GitHub Repository", (*) => Run("https://github.com/mesutakcan/Keyboard-OSD"))
	A_TrayMenu.Add()
	A_TrayMenu.Add("Settings", (*) => ShowSettingsGui())
	A_TrayMenu.Add("Reload", (*) => Reload())
	A_TrayMenu.Add(PauseMenuItemName, TogglePause)
	A_TrayMenu.Add(HideMenuItemName, (*) => HideOSDInstant())
	A_TrayMenu.Add()
	A_TrayMenu.Add("Exit", (*) => ExitApp())
}

try Hotkey(HotkeyToggleStr, (*) => TogglePause(PauseMenuItemName))
try Hotkey(HotkeyHideStr, (*) => HideOSDInstant())

SetTimer(KeyWatcher, 16)