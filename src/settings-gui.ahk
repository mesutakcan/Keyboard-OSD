global IniFile
global osd

global DEFAULT_SAMPLE_TEXT := "QOL-IW_Â|tl,yg;mn.09"

global sectionMap := Map()
sectionMap["TextColor"] := "Appearance"
sectionMap["BgColor"] := "Appearance"
sectionMap["BgAlpha"] := "Appearance"
sectionMap["FontName"] := "Appearance"
sectionMap["FontSize"] := "Appearance"
sectionMap["FontBold"] := "Appearance"
sectionMap["FontItalic"] := "Appearance"
sectionMap["TextPadX"] := "Appearance"
sectionMap["TextPadY"] := "Appearance"
sectionMap["TextYNudge"] := "Appearance"

sectionMap["Width"] := "Layout"
sectionMap["AutoWidth"] := "Layout"
sectionMap["MaxLines"] := "Layout"
sectionMap["LineGap"] := "Layout"
sectionMap["WordWrap"] := "Layout"
sectionMap["Position"] := "Layout"
sectionMap["MarginX"] := "Layout"
sectionMap["MarginY"] := "Layout"

sectionMap["HistTextColor"] := "History"
sectionMap["HistBgColor"] := "History"
sectionMap["HistAlpha"] := "History"
sectionMap["HistTextPadX"] := "History"
sectionMap["HistTextPadY"] := "History"
sectionMap["HistTextYNudge"] := "History"

sectionMap["DisplayTime"] := "Timing"
sectionMap["DismissDelay"] := "Timing"
sectionMap["ModifierDelay"] := "Timing"

sectionMap["FilterFunctionKeys"] := "Filters"
sectionMap["FilterNumpad"] := "Filters"
sectionMap["FilterLetters"] := "Filters"
sectionMap["FilterOtherLetters"] := "Filters"
sectionMap["FilterOtherLettersChars"] := "Filters"
sectionMap["FilterDigits"] := "Filters"
sectionMap["FilterArrows"] := "Filters"
sectionMap["FilterNavKeys"] := "Filters"
sectionMap["FilterModifiers"] := "Filters"
sectionMap["FilterCustomList"] := "Filters"

sectionMap["SpecialBgColor"] := "Special"
sectionMap["SpecialTextColor"] := "Special"
sectionMap["SpecialBorderColor"] := "Special"
sectionMap["SpecialAlpha"] := "Special"
sectionMap["SpecialBorderWidth"] := "Special"
sectionMap["SpecialTextPadX"] := "Special"
sectionMap["SpecialTextPadY"] := "Special"
sectionMap["SpecialTextYNudge"] := "Special"
sectionMap["SpecialKeepStyleInHistory"] := "Special"

ShowSettingsGui() {
	global HotkeyToggleStr, HotkeyHideStr
	HideOSDInstant()
	SetTimer(KeyWatcher, 0)
	try Hotkey(HotkeyToggleStr, "Off")
	try Hotkey(HotkeyHideStr, "Off")

	ExcludedEntries := LoadExcludedKeyEntries()

	SettingsGui := Gui("+AlwaysOnTop", "Keyboard OSD Settings")
	SettingsGui.BackColor := "F0F0F0"
	SettingsGui.SetFont("s9", "Segoe UI")

	appearanceFont := { name: osd.FontName, size: Number(osd.FontSize), bold: Number(osd.FontBold), italic: Number(osd.FontItalic) }
	histFont := { name: osd.HistFontName, size: Number(osd.HistFontSize), bold: Number(osd.HistFontBold), italic: Number(osd.HistFontItalic) }
	specialFont := { name: osd.SpecialFontName, size: Number(osd.SpecialFontSize), bold: Number(osd.SpecialFontBold), italic: Number(osd.SpecialFontItalic) }

	treeX := 8
	treeY := 8
	treeW := 110
	treeH := 480

	panelX := treeX + treeW + 10
	panelY := 8
	panelW := 330
	panelH := 480

	PX := panelX + 12
	VX := PX + 135
	cy0 := 32

	nav := SettingsGui.Add("TreeView", "x" treeX " y" treeY " w" treeW " h" treeH)

	bgColor := SettingsGui.BackColor
	if (bgColor != "") {
		r := Integer("0x" SubStr(bgColor, 1, 2))
		g := Integer("0x" SubStr(bgColor, 3, 2))
		b := Integer("0x" SubStr(bgColor, 5, 2))
		DllCall("SendMessage", "Ptr", nav.Hwnd, "UInt", 0x111D, "Ptr", 0, "Ptr", (b << 16) | (g << 8) | r)
	}

	pageAppearance := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Appearance")
	pageLayout := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Layout")
	pageHistory := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "History")
	pageSpecial := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Special")
	pageTiming := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Timing")
	pageFilters := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Filters")
	pageHotkeys := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Hotkeys")

	pages := [pageAppearance, pageLayout, pageHistory, pageSpecial, pageTiming, pageFilters, pageHotkeys]

	nodeAppearance := nav.Add("Appearance")
	nodeLayout := nav.Add("Layout")
	nodeHistory := nav.Add("History")
	nodeSpecial := nav.Add("Special")
	nodeTiming := nav.Add("Timing")
	nodeFilters := nav.Add("Filters")
	nodeHotkeys := nav.Add("Hotkeys")

	nodeToPage := Map()
	nodeToPage[nodeAppearance] := pageAppearance
	nodeToPage[nodeLayout] := pageLayout
	nodeToPage[nodeHistory] := pageHistory
	nodeToPage[nodeSpecial] := pageSpecial
	nodeToPage[nodeTiming] := pageTiming
	nodeToPage[nodeFilters] := pageFilters
	nodeToPage[nodeHotkeys] := pageHotkeys

	; --- Hotkeys ---
	pageHotkeys.Add(SettingsGui.Add("Text", "x" PX " y" cy0 " w130", "Pause OSD:"))
	hkPause := SettingsGui.AddHotkeyPlus("x" VX " yp-3 w150 NoMouse", HotkeyToggleStr)
	pageHotkeys.Add(hkPause.EditCtrl)
	if hkPause.ClearBtn
		pageHotkeys.Add(hkPause.ClearBtn)

	pageHotkeys.Add(SettingsGui.Add("Text", "x" PX " y+12 w130", "Hide OSD:"))
	hkHide := SettingsGui.AddHotkeyPlus("x" VX " yp-3 w150 NoMouse", HotkeyHideStr)
	pageHotkeys.Add(hkHide.EditCtrl)
	if hkHide.ClearBtn
		pageHotkeys.Add(hkHide.ClearBtn)

	; --- Appearance ---
	fontNameEdit := AddFontRow(pageAppearance, appearanceFont, cy0, (*) => _UpdateFontPreview(), "TextColor")

	AddColorSetting(pageAppearance, "Text Color", "TextColor")
	AddColorSetting(pageAppearance, "Background Color", "BgColor")
	AddSliderSetting(pageAppearance, "Background Alpha", "BgAlpha", "", 1, 255)
	apprPadXCtrl := AddIntSetting(pageAppearance, "Horizontal Padding", "TextPadX", "", 0, 30)
	apprPadXCtrl.OnEvent("Change", (*) => _UpdateFontPreview())
	apprPadYCtrl := AddIntSetting(pageAppearance, "Vertical Padding", "TextPadY", "", 0, 30)
	apprPadYCtrl.OnEvent("Change", (*) => _UpdateFontPreview())
	apprTextNudgeCtrl := AddIntSetting(pageAppearance, "Text Y Nudge", "TextYNudge", "", -20, 20)
	apprTextNudgeCtrl.OnEvent("Change", (*) => _UpdateFontPreview())

	apprSampleEdit := AddSampleTextRow(pageAppearance, "", DEFAULT_SAMPLE_TEXT, (*) => _UpdateFontPreview())

	fontPreviewPic := SettingsGui.Add("Picture", "x" PX " y+10 w290 h40", "")
	pageAppearance.Add(fontPreviewPic)
	fontPreviewPic.GetPos(&fontPreviewX, &fontPreviewY)
	fontPreviewCtrl := SettingsGui.Add("Text", "x" fontPreviewX " y" fontPreviewY " w290 h40 BackgroundTrans +Center +0x200", "Sample Text")
	pageAppearance.Add(fontPreviewCtrl)

	; --- Layout ---
	autoVal := Number(osd.AutoWidth)
	chkAutoWidth := SettingsGui.Add("Checkbox", "x" PX " y" cy0 " vAutoWidth" (autoVal ? " Checked" : ""), "Auto width")
	pageLayout.Add(chkAutoWidth)

	wordWrapVal := Number(osd.WordWrap)
	chkWordWrap := SettingsGui.Add("Checkbox", "x+50 yp vWordWrap" (wordWrapVal ? " Checked" : ""), "Word wrap")
	pageLayout.Add(chkWordWrap)

	AddIntSetting(pageLayout, "Max width", "Width", "", 50, 500)
	AddIntSetting(pageLayout, "Max Lines", "MaxLines", "", 1, 10)
	AddIntSetting(pageLayout, "Line Gap", "LineGap", "", 0, 20)

	pageLayout.Add(SettingsGui.Add("Text", "x" PX " y+10 w130", "Position:"))
	posVal := osd.Position
	posList := ["TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight"]
	choice := 0
	for i, v in posList
		if (v = posVal)
			choice := i
	posDropdown := SettingsGui.Add("DropDownList", "x" VX " yp-3 w110 vPosition Choose" (choice || 4), posList)
	pageLayout.Add(posDropdown)

	AddIntSetting(pageLayout, "Margin X", "MarginX", "", 0, 200)
	AddIntSetting(pageLayout, "Margin Y", "MarginY", "", 0, 200)

	; --- History ---
	AddFontRow(pageHistory, histFont, cy0, (*) => _UpdateHistPreview())

	AddColorSetting(pageHistory, "Text Color", "HistTextColor")
	AddColorSetting(pageHistory, "Background Color", "HistBgColor")
	AddSliderSetting(pageHistory, "Background Alpha", "HistAlpha", "", 1, 255)
	histPadXCtrl := AddIntSetting(pageHistory, "Horizontal Padding", "HistTextPadX", "", 0, 30)
	histPadXCtrl.OnEvent("Change", (*) => _UpdateHistPreview())
	histPadYCtrl := AddIntSetting(pageHistory, "Vertical Padding", "HistTextPadY", "", 0, 30)
	histPadYCtrl.OnEvent("Change", (*) => _UpdateHistPreview())
	histTextNudgeCtrl := AddIntSetting(pageHistory, "Text Y Nudge", "HistTextYNudge", "", -20, 20)
	histTextNudgeCtrl.OnEvent("Change", (*) => _UpdateHistPreview())

	histSampleEdit := AddSampleTextRow(pageHistory, "", DEFAULT_SAMPLE_TEXT, (*) => _UpdateHistPreview())

	histPreviewPic := SettingsGui.Add("Picture", "x" PX " y+10 w270 h35", "")
	pageHistory.Add(histPreviewPic)
	histPreviewPic.GetPos(&histPreviewX, &histPreviewY)
	histPreviewCtrl := SettingsGui.Add("Text", "x" histPreviewX " y" histPreviewY " w270 h35 BackgroundTrans +Center +0x200", "Sample History Text")
	pageHistory.Add(histPreviewCtrl)

	; --- Special ---
	AddFontRow(pageSpecial, specialFont, cy0, (*) => _UpdateSpecialPreview())

	AddColorSetting(pageSpecial, "Border Color", "SpecialBorderColor")
	AddColorSetting(pageSpecial, "Fill Color", "SpecialBgColor")
	AddColorSetting(pageSpecial, "Text Color", "SpecialTextColor")
	AddSliderSetting(pageSpecial, "Background Alpha", "SpecialAlpha", "", 1, 255)
	borderWidthCtrl := AddIntSetting(pageSpecial, "Border Width", "SpecialBorderWidth", "", 1, 20)
	borderWidthCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())
	specialPadXCtrl := AddIntSetting(pageSpecial, "Horizontal Padding", "SpecialTextPadX", "", 0, 30)
	specialPadXCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())
	specialPadYCtrl := AddIntSetting(pageSpecial, "Vertical Padding", "SpecialTextPadY", "", 0, 30)
	specialPadYCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())
	textNudgeCtrl := AddIntSetting(pageSpecial, "Text Y Nudge", "SpecialTextYNudge", "", -20, 20)
	textNudgeCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())

	keepStyleVal := Number(osd.SpecialKeepStyleInHistory)
	chkKeepStyle := SettingsGui.Add("Checkbox", "x" PX " y+12 vSpecialKeepStyleInHistory" (keepStyleVal ? " Checked" : ""),
		"Keep style in history")
	pageSpecial.Add(chkKeepStyle)

	specialPreviewPic := SettingsGui.Add("Picture", "x" PX " y+10 w200 h50", "")
	pageSpecial.Add(specialPreviewPic)
	specialPreviewPic.GetPos(&specialPreviewX, &specialPreviewY)
	specialPreviewCtrl := SettingsGui.Add("Text", "x" specialPreviewX " y" specialPreviewY " w200 h50 BackgroundTrans +Center +0x200", "Ctrl + PgDn")
	pageSpecial.Add(specialPreviewCtrl)

	; --- Timing ---
	AddIntSetting(pageTiming, "Display Time (ms)", "DisplayTime", cy0, 100, 10000)
	AddIntSetting(pageTiming, "Dismiss Delay (ms)", "DismissDelay", "", 50, 1000)
	AddIntSetting(pageTiming, "Modifier Delay (ms)", "ModifierDelay", "", 50, 1000)

	; --- Filters ---
	chkFunctionKeys := SettingsGui.Add("Checkbox", "x" PX " y" cy0 " vFilterFunctionKeys"
		(Number(osd.FilterFunctionKeys) ? " Checked" : ""), "Function keys (F1-F24)")
	pageFilters.Add(chkFunctionKeys)
	chkNumpad := SettingsGui.Add("Checkbox", "x" PX " y+6 vFilterNumpad"
		(Number(osd.FilterNumpad) ? " Checked" : ""), "Numpad")
	pageFilters.Add(chkNumpad)
	chkLetters := SettingsGui.Add("Checkbox", "x" PX " y+6 vFilterLetters"
		(Number(osd.FilterLetters) ? " Checked" : ""), "English letters (A-Z)")
	pageFilters.Add(chkLetters)

	chkOtherLetters := SettingsGui.Add("Checkbox", "x" (PX + 20) " y+6 vFilterOtherLetters"
		(Number(osd.FilterOtherLetters) ? " Checked" : ""), "Other letters")
	pageFilters.Add(chkOtherLetters)
	edtOtherLetters := SettingsGui.Add("Edit", "x+8 yp-3 w150 vFilterOtherLettersChars", osd.FilterOtherLettersChars)
	pageFilters.Add(edtOtherLetters)
	chkDigits := SettingsGui.Add("Checkbox", "x" PX " y+6 vFilterDigits"
		(Number(osd.FilterDigits) ? " Checked" : ""), "Digits (0-9)")
	pageFilters.Add(chkDigits)
	chkArrows := SettingsGui.Add("Checkbox", "x" PX " y+6 vFilterArrows"
		(Number(osd.FilterArrows) ? " Checked" : ""), "Arrow keys")
	pageFilters.Add(chkArrows)
	chkNavKeys := SettingsGui.Add("Checkbox", "x" PX " y+6 vFilterNavKeys"
		(Number(osd.FilterNavKeys) ? " Checked" : ""), "Navigation (Home/End/PgUp/PgDn/Ins/Del)")
	pageFilters.Add(chkNavKeys)

	modifiersOn := Number(osd.FilterModifiers)
	chkModifiers := SettingsGui.Add("Checkbox", "x" PX " y+8 vFilterModifiers" (modifiersOn ? " Checked" : ""), "Modifiers")
	pageFilters.Add(chkModifiers)
	radioAlone := SettingsGui.Add("Radio", "x" (PX + 20) " y+4" (!modifiersOn ? " Disabled" : ""), "Alone (Ctrl, Shift, Alt, Win)")
	pageFilters.Add(radioAlone)
	radioGroup := SettingsGui.Add("Radio", "x" (PX + 20) " y+4" (!modifiersOn ? " Disabled" : ""), "In combo (e.g. Ctrl+1)")
	pageFilters.Add(radioGroup)
	if (osd.FilterModifierMode = "Group")
		radioGroup.Value := 1
	else
		radioAlone.Value := 1
	chkModifiers.OnEvent("Click", _ToggleModifierRadios)

	chkCustomList := SettingsGui.Add("Checkbox", "x" PX " y+10 vFilterCustomList"
		(Number(osd.FilterCustomList) ? " Checked" : ""), "Custom exclusions:")
	pageFilters.Add(chkCustomList)
	hkCombo := SettingsGui.AddHotkeyPlus("x" PX " y+6 w180 NoMouse")
	pageFilters.Add(hkCombo.EditCtrl)
	if hkCombo.ClearBtn
		pageFilters.Add(hkCombo.ClearBtn)
	btnAddExcl := SettingsGui.Add("Button", "x+8 yp w70", "Add")
	pageFilters.Add(btnAddExcl)
	btnAddExcl.OnEvent("Click", _AddExcludedKey)

	lstExcluded := SettingsGui.Add("ListBox", "x" PX " y+8 w290 h150")
	pageFilters.Add(lstExcluded)
	for entry in ExcludedEntries
		lstExcluded.Add([entry.display])

	btnRemoveExcl := SettingsGui.Add("Button", "x" PX " y+6 w80", "Remove")
	pageFilters.Add(btnRemoveExcl)
	btnRemoveExcl.OnEvent("Click", _RemoveExcludedKey)

	yBtns := panelY + panelH + 10
	btnSave := SettingsGui.Add("Button", "Default x" PX " y" yBtns " w80", "Save")
	btnSave.OnEvent("Click", SaveSettings)
	_CloseSettingsGui(*) {
		try Hotkey(HotkeyToggleStr, "On")
		try Hotkey(HotkeyHideStr, "On")
		SetTimer(KeyWatcher, 16)
		SettingsGui.Destroy()
	}

	btnCancel := SettingsGui.Add("Button", "x+20 yp w80", "Cancel")
	btnCancel.OnEvent("Click", _CloseSettingsGui)
	SettingsGui.OnEvent("Close", _CloseSettingsGui)

	_UpdateFontPreview()
	_UpdateHistPreview()
	_UpdateSpecialPreview()

	nav.OnEvent("ItemSelect", (ctrl, item) => (nodeToPage.Has(item) ? _ActivatePage(nodeToPage[item]) : 0))
	nav.Modify(nodeAppearance, "Select")
	_ActivatePage(pageAppearance)

	SettingsGui.Show()

	_ActivatePage(target) {
		for pg in pages
			(pg = target) ? pg.Show() : pg.Hide()
	}

	AddFontRow(page, profile, yPos, updatePreview, colorKey := "") {
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+10"
		page.Add(SettingsGui.Add("Text", opt " w130", "Font:"))
		edit := SettingsGui.Add("Edit", "x" VX " yp-3 w120 -Multi", profile.name)
		page.Add(edit)
		btn := SettingsGui.Add("Button", "x+4 yp w30 h22", "...")
		page.Add(btn)
		edit.OnEvent("Change", (ctrl, *) => (profile.name := ctrl.Value, updatePreview()))
		btn.OnEvent("Click", (*) => _PickFontFor(profile, edit, updatePreview, colorKey))
		return edit
	}

	AddSampleTextRow(page, yPos, defaultText, updatePreview) {
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+10"
		page.Add(SettingsGui.Add("Text", opt " w130", "Sample Text:"))
		edit := SettingsGui.Add("Edit", "x" VX " yp-3 w155 -Multi", defaultText)
		page.Add(edit)
		edit.OnEvent("Change", (*) => updatePreview())
		return edit
	}

	_PickFontFor(profile, edit, updatePreview, colorKey := "") {
		fName := profile.name
		fSize := profile.size
		bold := profile.bold
		italic := profile.italic
		unused1 := 0
		unused2 := 0
		colorEdit := (colorKey != "") ? SettingsGui[colorKey] : ""
		fColor := (colorEdit != "") ? colorEdit.Value : "000000"
		showEffects := (colorKey != "")

		if FontDialog.Choose(SettingsGui.Hwnd, &fName, &fSize, &bold, &italic, &unused1, &unused2, &fColor, , showEffects) {
			profile.name := fName
			profile.size := fSize
			profile.bold := bold ? 1 : 0
			profile.italic := italic ? 1 : 0
			edit.Value := fName

			if (colorEdit != "") {
				colorEdit.Value := fColor
				_UpdateColorPreview(colorEdit, colorEdit.PreviewCtrl)
			}
			updatePreview()
		}
	}

	AddIntSetting(page, label, key, yPos := "", minVal := 0, maxVal := 9999) {
		global osd, sectionMap
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+10"
		page.Add(SettingsGui.Add("Text", opt " w130", label ":"))
		val := Number(osd.%key%)
		numOpt := (minVal >= 0) ? " Number" : ""
		editCtrl := SettingsGui.Add("Edit", "x" VX " yp-3 w110 v" key numOpt)
		page.Add(editCtrl)
		updCtrl := SettingsGui.Add("UpDown", "x+0 y-1 w20 Range" minVal "-" maxVal " AltSubmit", val)
		page.Add(updCtrl)
		editCtrl.Value := val
		if (minVal < 0)
			editCtrl.OnEvent("Change", _SanitizeSignedInt.Bind(updCtrl, minVal, maxVal))
		return editCtrl
	}

	_SanitizeSignedInt(updCtrl, minVal, maxVal, ctrl, *) {
		raw := ctrl.Value
		if (raw = "" || raw = "-")
			return
		clean := RegExReplace(raw, "[^\d\-]")
		if (StrLen(clean) > 1)
			clean := SubStr(clean, 1, 1) . StrReplace(SubStr(clean, 2), "-", "")
		if (clean = "" || clean = "-")
			return
		n := Max(minVal, Min(maxVal, Integer(clean)))
		if (raw != String(n)) {
			start := StrLen(raw)
			ctrl.Value := n
			DllCall("SendMessage", "Ptr", ctrl.Hwnd, "UInt", 0x00B1, "Ptr", start, "Ptr", start)
		}
		updCtrl.Value := n
	}

	AddSliderSetting(page, label, key, yPos := "", min := 0, max := 255) {
		global osd, sectionMap
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+8"
		page.Add(SettingsGui.Add("Text", opt " w130 h22", label ":"))
		val := Number(osd.%key%)
		sliderCtrl := SettingsGui.Add("Slider", "x" (PX + 130) " yp w130 h22 v" key " Range" min "-" max " TickInterval50 AltSubmit", val)
		page.Add(sliderCtrl)
		textCtrl := SettingsGui.Add("Text", "x+5  yp w30  h22 v" key "Value", val)
		page.Add(textCtrl)
		sliderCtrl.OnEvent("Change", (ctrl, *) => (textCtrl.Text := ctrl.Value, _UpdateFontPreview(), _UpdateHistPreview(), _UpdateSpecialPreview()))
		return sliderCtrl
	}

	AddColorSetting(page, label, key, yPos := "") {
		global osd, sectionMap
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+10"
		page.Add(SettingsGui.Add("Text", opt " w130", label ":"))
		val := osd.%key%
		editCtrl := SettingsGui.Add("Edit", "x" VX " yp-3 w90 v" key, val)
		page.Add(editCtrl)
		preview := SettingsGui.Add("Text", "x+5  yp  w22 h22 +Border Background" val)
		page.Add(preview)
		btnColor := SettingsGui.Add("Button", "x+4  yp  w30 h22", "...")
		page.Add(btnColor)
		editCtrl.PreviewCtrl := preview
		editCtrl.OnEvent("Change", (ctrl, *) => _OnColorChange(ctrl, preview))
		editCtrl.OnEvent("LoseFocus", (ctrl, *) => _PadColorHex(ctrl, preview))
		preview.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd))
		btnColor.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd))
		return editCtrl
	}

	_PadColorHex(edit, preview) {
		clean := RegExReplace(edit.Value, "[^0-9A-Fa-f]")
		if (clean = "" || StrLen(clean) = 6)
			return
		if (StrLen(clean) > 6)
			clean := SubStr(clean, 1, 6)
		loop 6 - StrLen(clean)
			clean := "0" clean
		edit.Value := StrUpper(clean)
		_UpdateColorPreview(edit, preview)
		_UpdateFontPreview()
		_UpdateHistPreview()
		_UpdateSpecialPreview()
	}

	_OnColorChange(edit, preview) {
		val := edit.Value
		upper := StrUpper(val)
		sanitized := RegExReplace(upper, "[^0-9A-F]")
		if (StrLen(sanitized) > 6)
			sanitized := SubStr(sanitized, 1, 6)
		if (val !== sanitized) {
			sel := DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "Ptr")
			start := sel & 0xFFFF
			edit.Value := sanitized
			newStart := Min(start, StrLen(sanitized))
			DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x00B1, "Ptr", newStart, "Ptr", newStart)
		}
		_UpdateColorPreview(edit, preview)
		_UpdateFontPreview()
		_UpdateHistPreview()
		_UpdateSpecialPreview()
	}

	_UpdateFontPreview() {
		if !IsSet(fontPreviewPic)
			return
		sampleText := apprSampleEdit.Value
		padX := SettingsGui["TextPadX"].Value
		padY := SettingsGui["TextPadY"].Value
		textH := MeasureTextHeight(appearanceFont.name, appearanceFont.size, appearanceFont.bold, appearanceFont.italic)
		textW := MeasureTextWidth(sampleText, appearanceFont.name, appearanceFont.size, appearanceFont.bold, appearanceFont.italic)
		pw := textW + padX * 2
		ph := textH + padY * 2

		bgHex := SettingsGui["BgColor"].Value
		alphaVal := SettingsGui["BgAlpha"].Value
		radius := SPECIAL_OUTER_RADIUS

		fontPreviewPic.Move(fontPreviewX, fontPreviewY, pw, ph)
		RenderPreviewBadge(fontPreviewPic, pw, ph, bgHex, alphaVal, , , radius)
		fontPreviewPic.Redraw()

		nudge := _SafeNudge(SettingsGui["TextYNudge"].Value)
		opts := "s" appearanceFont.size
			. " " (appearanceFont.bold ? "Bold" : "norm")
			. (appearanceFont.italic ? " Italic" : "")
			. " c" BlendHexColor(SettingsGui["TextColor"].Value, "FFFFFF", alphaVal)

		fontPreviewCtrl.Move(fontPreviewX, fontPreviewY + nudge, pw, ph - nudge)
		fontPreviewCtrl.Text := sampleText
		fontPreviewCtrl.SetFont(opts, appearanceFont.name)
		fontPreviewCtrl.Redraw()
	}

	_UpdateHistPreview() {
		if !IsSet(histPreviewPic)
			return
		sampleText := histSampleEdit.Value
		padX := SettingsGui["HistTextPadX"].Value
		padY := SettingsGui["HistTextPadY"].Value
		textH := MeasureTextHeight(histFont.name, histFont.size, histFont.bold, histFont.italic)
		textW := MeasureTextWidth(sampleText, histFont.name, histFont.size, histFont.bold, histFont.italic)
		pw := textW + padX * 2
		ph := textH + padY * 2

		bgHex := SettingsGui["HistBgColor"].Value
		alphaVal := SettingsGui["HistAlpha"].Value
		radius := SPECIAL_OUTER_RADIUS

		histPreviewPic.Move(histPreviewX, histPreviewY, pw, ph)
		RenderPreviewBadge(histPreviewPic, pw, ph, bgHex, alphaVal, , , radius)
		histPreviewPic.Redraw()

		nudge := _SafeNudge(SettingsGui["HistTextYNudge"].Value)
		opts := "s" histFont.size
			. " " (histFont.bold ? "Bold" : "norm")
			. (histFont.italic ? " Italic" : "")
			. " c" BlendHexColor(SettingsGui["HistTextColor"].Value, "FFFFFF", alphaVal)

		histPreviewCtrl.Move(histPreviewX, histPreviewY + nudge, pw, ph - nudge)
		histPreviewCtrl.Text := sampleText
		histPreviewCtrl.SetFont(opts, histFont.name)
		histPreviewCtrl.Redraw()
	}

	_UpdateSpecialPreview() {
		if !IsSet(specialPreviewPic)
			return

		borderW := Number(SettingsGui["SpecialBorderWidth"].Value)
		padX := Number(SettingsGui["SpecialTextPadX"].Value)
		padY := Number(SettingsGui["SpecialTextPadY"].Value)
		alphaVal := SettingsGui["SpecialAlpha"].Value
		sampleText := "Ctrl + PgDn"

		textH := MeasureTextHeight(specialFont.name, specialFont.size, specialFont.bold, specialFont.italic)
		textW := MeasureTextWidth(sampleText, specialFont.name, specialFont.size, specialFont.bold, specialFont.italic)
		pw := textW + 2 * (borderW + padX)
		ph := textH + 2 * (borderW + padY)

		specialPreviewPic.Move(specialPreviewX, specialPreviewY, pw, ph)
		RenderPreviewBadge(specialPreviewPic, pw, ph,
			SettingsGui["SpecialBgColor"].Value, alphaVal,
			SettingsGui["SpecialBorderColor"].Value, borderW, SPECIAL_OUTER_RADIUS)
		specialPreviewPic.Redraw()

		nudge := _SafeNudge(SettingsGui["SpecialTextYNudge"].Value)
		opts := "s" specialFont.size
			. " " (specialFont.bold ? "Bold" : "norm")
			. " c" BlendHexColor(SettingsGui["SpecialTextColor"].Value, "FFFFFF", alphaVal)

		specialPreviewCtrl.SetFont(opts, specialFont.name)
		specialPreviewCtrl.Move(specialPreviewX, specialPreviewY + nudge, pw, ph - nudge)
		specialPreviewCtrl.Redraw()
	}

	_UpdateColorPreview(edit, preview) {
		clean := RegExReplace(StrUpper(Trim(edit.Value)), "[^0-9A-F]")
		if (clean = "") {
			preview.Opt("BackgroundE0E0E0")
		} else {
			if (StrLen(clean) > 6)
				clean := SubStr(clean, 1, 6)
			loop 6 - StrLen(clean)
				clean := "0" clean
			preview.Opt("Background" clean)
		}
		preview.Redraw()
	}

	_PickColor(edit, preview, ownerHwnd) {
		static custColors := []
		hex := Trim(edit.Value)
		initColor := (StrLen(hex) = 6 && RegExMatch(hex, "i)^[0-9A-F]{6}$")) ? Integer("0x" hex) : 0
		if ((result := ColorDialog.Choose(initColor, ownerHwnd, &custColors)) != -1) {
			edit.Value := Format("{:06X}", result & 0xFFFFFF)
			_UpdateColorPreview(edit, preview)
			_UpdateFontPreview()
			_UpdateHistPreview()
			_UpdateSpecialPreview()
		}
	}

	SaveSettings(*) {
		global HotkeyToggleStr, HotkeyHideStr
		results := SettingsGui.Submit()
		for key, value in results.OwnProps() {
			section := sectionMap.Has(key) ? sectionMap[key] : "Appearance"
			IniWrite(value, IniFile, section, key)
		}

		IniWrite(appearanceFont.name, IniFile, "Appearance", "FontName")
		IniWrite(appearanceFont.size, IniFile, "Appearance", "FontSize")
		IniWrite(appearanceFont.bold, IniFile, "Appearance", "FontBold")
		IniWrite(appearanceFont.italic, IniFile, "Appearance", "FontItalic")

		IniWrite(histFont.name, IniFile, "History", "HistFontName")
		IniWrite(histFont.size, IniFile, "History", "HistFontSize")
		IniWrite(histFont.bold, IniFile, "History", "HistFontBold")
		IniWrite(histFont.italic, IniFile, "History", "HistFontItalic")

		IniWrite(specialFont.name, IniFile, "Special", "SpecialFontName")
		IniWrite(specialFont.size, IniFile, "Special", "SpecialFontSize")
		IniWrite(specialFont.bold, IniFile, "Special", "SpecialFontBold")
		IniWrite(specialFont.italic, IniFile, "Special", "SpecialFontItalic")

		IniWrite(radioGroup.Value ? "Group" : "Alone", IniFile, "Filters", "FilterModifierMode")
		SaveExcludedKeyEntries(ExcludedEntries)

		newPauseHotkey := (hkPause.Value != "") ? hkPause.Value : HotkeyToggleStr
		IniWrite(newPauseHotkey, IniFile, "Hotkeys", "TogglePause")

		newHideHotkey := (hkHide.Value != "") ? hkHide.Value : HotkeyHideStr
		IniWrite(newHideHotkey, IniFile, "Hotkeys", "HideOSD")

		MsgBox("Settings saved. The script will now reload to apply changes.", "Reload Script", "IconI")
		ClearMeasureTextWidthCache()
		Reload()
	}

	_ToggleModifierRadios(*) {
		enabled := chkModifiers.Value
		radioAlone.Enabled := enabled
		radioGroup.Enabled := enabled
	}

	_AddExcludedKey(*) {
		raw := hkCombo.Value
		if (raw = "")
			return

		for entry in ExcludedEntries
			if (entry.raw = raw)
				return

		display := FormatComboDisplay(raw)
		ExcludedEntries.Push({ raw: raw, display: display })
		lstExcluded.Add([display])
		hkCombo.Clear()
	}

	_RemoveExcludedKey(*) {
		idx := lstExcluded.Value
		if (idx = 0)
			return
		ExcludedEntries.RemoveAt(idx)
		lstExcluded.Delete(idx)
	}
}

LoadExcludedKeyEntries() {
	global IniFile
	entries := []
	section := ""
	try section := IniRead(IniFile, "ExcludedKeys")
	if (section = "")
		return entries

	for line in StrSplit(section, "`n", "`r") {
		line := Trim(line)
		if (line = "")
			continue
		eq := InStr(line, "=")
		raw := eq ? SubStr(line, eq + 1) : line
		raw := Trim(raw)
		if (raw = "")
			continue
		entries.Push({ raw: raw, display: FormatComboDisplay(raw) })
	}
	return entries
}

SaveExcludedKeyEntries(entries) {
	global IniFile
	try IniDelete(IniFile, "ExcludedKeys")
	i := 0
	for entry in entries {
		i += 1
		IniWrite(entry.raw, IniFile, "ExcludedKeys", "Key" i)
	}
}

FormatComboDisplay(raw) {
	if (raw = "")
		return ""
	if (raw = "AltGr")
		return "AltGr"
	if (SubStr(raw, 1, 6) = "AltGr+")
		return "AltGr + " . HotkeyPlus.BeautifyKeyName(SubStr(raw, 7))
	return HotkeyPlus.FormatKeyToText(raw)
}

_SafeNudge(val) {
	val := Trim(val)
	if (val = "" || val = "-" || val = "+")
		return 0
	try return Integer(val)
	return 0
}