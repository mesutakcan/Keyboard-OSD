/*
=========================
Keyboard OSD
=========================
Keyboard OSD is a lightweight Windows utility that displays keyboard input and
 shortcut combinations on screen in real time.
It is designed for presentations, tutorials, screen recordings,
 and live demonstrations where visible keystrokes make the workflow easier to follow.
=========================
13/09/2026
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
;@Ahk2Exe-SetFileVersion 1.8
;@Ahk2Exe-SetCopyright ©2026 Mesut Akcan
;@Ahk2Exe-SetMainIcon app_icon.ico
;@Ahk2Exe-AddResource app_icon_pause.ico, 207

A_ScriptName := "Keyboard OSD"

#Include "gdip.ahk"
#Include "render.ahk"
#Include "keyfilter.ahk"
#Include "commonDialog.ahk"
#Include "GroupBox.ahk"
#Include "hotkeyplus.ahk"
#Include "settings-gui.ahk"

AppVer := "1.8"

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
global HotkeyToggleStr := ReadIni("TogglePause", "^+F12", , "Hotkeys")
global HotkeyHideStr := ReadIni("HideOSD", "^+F9", , "Hotkeys")
global PauseMenuItemName := "Pause OSD	" FormatComboDisplay(HotkeyToggleStr)
global HideMenuItemName := "Hide OSD	" FormatComboDisplay(HotkeyHideStr)

global PendingReload := false

global SystemExcludedKeyList := []
for str in [HotkeyToggleStr, HotkeyHideStr] {
	parsed := ""
	try parsed := ParseKeyCombo(str)
	if (parsed != "")
		SystemExcludedKeyList.Push(parsed)
}

SetupTrayMenu()

OnExit(ClearMeasureTextWidthCache)
OnExit(ClearGdipFontCache)
OnExit(ShutdownGdiplus)
OnExit(ClearBadgeCache)
InitGdiplus()

global TextMeasureFontCache := Map()
global GdipFontCache := Map()
global CachedMaxWidth := 0
global TextMeasureFontHDC := 0

global SPECIAL_OUTER_RADIUS := 8
global RowBitmaps := Map()
class OSDState {
	LastKey := ""
	DownVKs := Map()
	DownMods := Map()
	Lines := []
	PendingMod := ""
	PendingModSerial := 0
	PendingModTimer := 0
	PendingComposeTap := ""
	TypingBuf := ""
	TypingSerial := 0
	TypingTimer := 0
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

	Width := ReadIni("Width", 350, true, "Layout")
	AutoWidth := ReadIni("AutoWidth", 1, true, "Layout")
	WordWrap := ReadIni("WordWrap", 1, true, "Layout")
	MaxLines := ReadIni("MaxLines", 5, true, "Layout")
	Position := ReadIni("Position", "BottomLeft", , "Layout")
	MarginX := ReadIni("MarginX", 20, true, "Layout")
	MarginY := ReadIni("MarginY", 30, true, "Layout")
	LineGap := ReadIni("LineGap", 2, true, "Layout")

	HistFontSize := ReadIni("HistFontSize", 15, true, "History")
	HistAlpha := ReadIni("HistAlpha", 150, true, "History")
	HistTextColor := ReadIni("HistTextColor", "FFFFFF", , "History")
	HistBgColor := ReadIni("HistBgColor", "AAAAAA", , "History")

	SpecialFontName := ReadIni("SpecialFontName", "Segoe UI", , "Special")
	SpecialFontSize := ReadIni("SpecialFontSize", 20, true, "Special")
	SpecialFontBold := ReadIni("SpecialFontBold", 1, true, "Special")
	SpecialFontItalic := ReadIni("SpecialFontItalic", 0, true, "Special")
	SpecialBgColor := ReadIni("SpecialBgColor", "FFFFFF", , "Special")
	SpecialTextColor := ReadIni("SpecialTextColor", "000000", , "Special")
	SpecialBorderColor := ReadIni("SpecialBorderColor", "383838", , "Special")
	SpecialAlpha := ReadIni("SpecialAlpha", 175, true, "Special")
	SpecialBorderWidth := ReadIni("SpecialBorderWidth", 3, true, "Special")
	SpecialTextPadX := ReadIni("SpecialTextPadX", 1, true, "Special")
	SpecialTextPadY := ReadIni("SpecialTextPadY", 1, true, "Special")
	SpecialTextYNudge := ReadIni("SpecialTextYNudge", 0, true, "Special")
	CombineSpecialKeys := ReadIni("CombineSpecialKeys", 1, true, "Special")
	SpecialGap := ReadIni("SpecialGap", 3, true, "Special")

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
	FilterCustomList := ReadIni("FilterCustomList", 0, true, "Filters")
	FilterOtherLetters := ReadIni("FilterOtherLetters", 0, true, "Filters")
	FilterOtherLettersChars := ReadIni("FilterOtherLettersChars", "", , "Filters")
}

global osd := OSDSettings()

class OSDLine {
	Segments := []
	CreatedAt := 0
	ActiveSince := 0
	IsSpecial := false

	__New(text, isSpecial := false) {
		this.Segments := [{ Text: text, Count: 1 }]
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

	Last() {
		return this.Segments[this.Segments.Length]
	}

	Touch() {
		this.CreatedAt := A_TickCount
		this.ActiveSince := A_TickCount
	}

	Increment() {
		seg := this.Last()
		seg.Count++
		seg.Text := RegExReplace(seg.Text, " ×\d+$", "") " ×" seg.Count
		this.Touch()
	}

	ReplaceText(text) {
		seg := this.Last()
		seg.Text := text
		seg.Count := 1
		this.Touch()
	}

	AddSegment(text) {
		this.Segments.Push({ Text: text, Count: 1 })
		this.Touch()
	}

	DisplayText() {
		if (this.Segments.Length = 1)
			return this.Segments[1].Text
		joined := ""
		for seg in this.Segments
			joined .= (joined = "" ? "" : " ") seg.Text
		return joined
	}
}

global CHAR_WIDTH_RATIO := 0.55
osd.LineHeight := MeasureTextHeight(osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + osd.TextPadY * 2
osd.HistLineHeight := MeasureTextHeight(osd.FontName, osd.HistFontSize, osd.FontBold, osd.FontItalic) + Round(osd.TextPadY * HistTextScale()) * 2
osd.MaxTyping := Max(10, Floor((osd.Width - osd.TextPadX * 2) / (osd.FontSize * CHAR_WIDTH_RATIO)))
global RowWins := []
global RowReady := []
global FadingStates := []
global FadeTimers := []
global FadeAlphas := []

loop osd.MaxLines {
	w := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x80000")
	RowWins.Push(w)
	RowReady.Push(false)
	FadingStates.Push(false)
	FadeTimers.Push(0)
	FadeAlphas.Push(255)
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
			if IsReservedVK(vk)
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

; VK codes Windows never actually sends for a real key press (unassigned,
; reserved, or OEM-internal ranges). Shared by KeyWatcher and TogglePause so
; both scan the same set of real, physical keys.
IsReservedVK(vk) {
	return (vk >= 1 && vk <= 7)
		|| (vk >= 0x0A && vk <= 0x0B)
		|| (vk >= 0x0E && vk <= 0x0F)
		|| (vk >= 0x3A && vk <= 0x40)
		|| (vk >= 0x88 && vk <= 0x8F)
		|| (vk >= 0x97 && vk <= 0x9F)
		|| (vk >= 0xD8 && vk <= 0xDA)
		|| (vk >= 0xF6 && vk <= 0xFE)
		|| vk = 0x5E || vk = 0xE0 || vk = 0xE8
}

; Known limitation (accepted, not a bug to chase): this polls key state every 16ms
; rather than using a WH_KEYBOARD_LL hook. An extremely fast press-release-press of
; the SAME key can land entirely between two polls and be missed, since only the
; "is it down right now" state is sampled, not each individual down/up event. A real
; hook would catch every event but is a bigger architectural change - deliberately
; not pursued here.
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

		if IsReservedVK(vk)
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
		CancelPendingModTimer()
		osd.State.PendingMod := ""
		osd.State.PendingModSerial++
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
			CancelPendingModTimer()
			osd.State.PendingMod := ""
			osd.State.PendingModSerial++
			osd.State.PendingComposeTap := combinedMod
		} else {
			CancelPendingModTimer()
			osd.State.PendingModSerial++
			serial := osd.State.PendingModSerial
			osd.State.PendingMod := combinedMod
			osd.State.PendingModTimer := CommitPendingMod.Bind(serial)
			SetTimer(osd.State.PendingModTimer, -osd.ModifierDelay)
		}
	}

	if (stillMods.Count = 0 && osd.State.PendingComposeTap != "") {
		tapLabel := osd.State.PendingComposeTap
		osd.State.PendingComposeTap := ""

		if !IsModifierTapExcluded() {
			FlushTyping()

			CommitSpecialKey(tapLabel)
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

CancelPendingModTimer() {
	global osd
	if (osd.State.PendingModTimer) {
		SetTimer(osd.State.PendingModTimer, 0)
		osd.State.PendingModTimer := 0
	}
}

CommitPendingMod(serial := 0) {
	global osd
	if (osd.State.PendingMod = "")
		return
	if (serial != 0 && serial != osd.State.PendingModSerial)
		return

	name := osd.State.PendingMod
	osd.State.PendingMod := ""
	osd.State.PendingModTimer := 0
	osd.State.PendingModSerial++


	if (Trim(name) = "")
		return

	if IsModifierTapExcluded()
		return

	if (!IsOSDVisible() && osd.State.Lines.Length = 0 && osd.State.TypingBuf = "")
		ResetOSDState()

	FlushTyping()
	CommitSpecialKey(name, name)
	RenderOSD()
}

CommitSpecialKey(label, subsetCheckLabel := "") {
	global osd
	lines := osd.State.Lines

	if (label = osd.State.LastKey && lines.Length > 0) {
		lines[lines.Length].Increment()
		EnforceRowWidth()
		return
	}

	if (subsetCheckLabel != "" && lines.Length > 0 && lines[lines.Length].IsSpecial
		&& osd.State.LastKey != "" && TokensSubsetOf(osd.State.LastKey, subsetCheckLabel)) {
		lines[lines.Length].ReplaceText(label)
		osd.State.LastKey := label
		EnforceRowWidth()
		return
	}

	osd.State.LastKey := label
	AddSpecialLine(label)
}

EnforceRowWidth() {
	global osd
	lines := osd.State.Lines
	if (lines.Length = 0)
		return

	active := lines[lines.Length]
	if (!active.IsSpecial || active.Segments.Length <= 1)
		return
	if (SpecialRowWidth(active.Segments) <= CurrentMaxWidth())
		return

	overflow := active.Segments.Pop()
	newLine := OSDLine(overflow.Text, true)
	newLine.Segments[1].Count := overflow.Count
	lines.Push(newLine)
}

CurrentMaxWidth() {
	global osd, CachedMaxWidth
	return CachedMaxWidth > 0 ? CachedMaxWidth : Min(osd.Width, Round(GetActiveMonitorBounds()["w"] * 0.75))
}

AddSpecialLine(label) {
	global osd
	lines := osd.State.Lines

	if (osd.CombineSpecialKeys && lines.Length > 0 && lines[lines.Length].IsSpecial) {
		active := lines[lines.Length]
		if (SpecialRowWidth(active.Segments) + osd.SpecialGap + MeasureSpecialBadgeWidth(label) <= CurrentMaxWidth()) {
			active.AddSegment(label)
			return
		}
	}

	PushLine(label, true)
}

HandleKeyPress(foundVK, foundKey, hasShift, hasCtrl, hasAlt, isAltGr, hasWin) {
	global osd
	PruneTrailingPlaceholder()

	if IsKeyExcluded(hasCtrl, hasShift, hasAlt, hasWin, isAltGr, foundKey, foundVK) {
		modLabel := BuildModLabel(hasCtrl, hasShift, hasAlt, hasWin, isAltGr)
		if (modLabel != "" && osd.State.LastKey = modLabel && osd.State.Lines.Length > 0
			&& osd.State.Lines[osd.State.Lines.Length].IsSpecial) {
			activeLine := osd.State.Lines[osd.State.Lines.Length]
			activeLine.Segments.Pop()
			if (activeLine.Segments.Length = 0)
				osd.State.Lines.Pop()
			osd.State.LastKey := ""
			RenderOSD()
		}
		return
	}

	if (!IsOSDVisible() && osd.State.Lines.Length = 0 && osd.State.TypingBuf = "")
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
		ScheduleTypingTimeout()
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
			if (lastLine.IsSpecial && IsPureModifierLabel(lastLine.Last().Text)) {
				lastLine.Segments.Pop()
				if (lastLine.Segments.Length = 0)
					osd.State.Lines.RemoveAt(osd.State.Lines.Length)
			}
		}

		maxW := CurrentMaxWidth()
		candidate := osd.State.TypingBuf . typedChar
		tw := MeasureTextWidthGdip(candidate, osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + osd.TextPadX * 2

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
		ScheduleTypingTimeout()
		osd.State.LastKey := ""
		return
	}

	if (foundKey = "Enter" && !hasMods && osd.State.TypingBuf != "") {
		FlushTyping()
		PushEmptyActivePlaceholder()
		RenderOSD()
		return
	}

	FlushTyping()

	if isAltGr
		modList := ["AltGr"]

	modOnlyLabel := ""
	for item in modList
		modOnlyLabel .= (modOnlyLabel = "" ? "" : " + ") item

	displayKey := HotkeyPlus.BeautifyKeyName(foundKey)
	if (!hasShift && RegExMatch(displayKey, "^[A-Z]$"))
		displayKey := StrLower(displayKey)
	modList.Push(displayKey)
	label := ""
	for item in modList
		label .= (label = "" ? "" : " + ") item

	CommitSpecialKey(label, modOnlyLabel)
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