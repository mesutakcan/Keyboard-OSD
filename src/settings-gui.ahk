global IniFile
global osd

global DEFAULT_SAMPLE_TEXT := "ÂÜg,Wjp;|Il1-_oO0.9wmn"

ShowSettingsGui() {
	global HotkeyToggleStr, HotkeyHideStr, PendingReload
	HideOSDInstant()
	SetTimer(KeyWatcher, 0)
	try Hotkey(HotkeyToggleStr, "Off")
	try Hotkey(HotkeyHideStr, "Off")

	if PendingReload {
		if (MsgBox("Saved settings haven't been applied yet.`nRestart the program now?",
			"Pending Settings", "YesNo Icon!") = "Yes") {
			PendingReload := false
			ClearMeasureTextWidthCache()
			Reload()
			return
		}
	}

	ExcludedEntries := LoadExcludedKeyEntries()

	SettingsGui := Gui("+AlwaysOnTop", "Keyboard OSD Settings")
	SettingsGui.Opt("+OwnDialogs")
	SettingsGui.BackColor := "F0F0F0"
	SettingsGui.SetFont("s9", "Segoe UI")

	appearanceFont := { name: osd.FontName, size: Number(osd.FontSize), bold: Number(osd.FontBold), italic: Number(osd.FontItalic) }
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

	pageAppearance := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Appearance")
	pageLayout := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Layout")
	pageHistory := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "History")
	pageSpecial := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Special")
	pageTiming := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Timing")
	pageFilters := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Filters")
	pageHotkeys := GroupBox(SettingsGui, panelX, panelY, panelW, panelH, "Hotkeys")

	pages := [pageAppearance, pageLayout, pageHistory, pageSpecial, pageTiming, pageFilters, pageHotkeys]

	nodeLayout := nav.Add("Layout")
	nodeAppearance := nav.Add("Appearance")
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
	posList := ["TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight", "Center"]
	choice := 0
	for i, v in posList
		if (v = posVal)
			choice := i
	posDropdown := SettingsGui.Add("DropDownList", "x" VX " yp-3 w110 vPosition Choose" (choice || 4), posList)
	pageLayout.Add(posDropdown)

	AddIntSetting(pageLayout, "Margin X", "MarginX", "", 0, 200)
	AddIntSetting(pageLayout, "Margin Y", "MarginY", "", 0, 200)

	; --- Appearance ---
	fontNameEdit := AddFontRow(pageAppearance, appearanceFont, cy0, (*) => (histFontNameLabel.Text := appearanceFont.name), "TextColor")

	AddColorSetting(pageAppearance, "Text Color", "TextColor")
	AddColorSetting(pageAppearance, "Background Color", "BgColor")
	AddSliderSetting(pageAppearance, "Background Alpha", "BgAlpha", "", 1, 255)
	AddIntSetting(pageAppearance, "Horizontal Padding", "TextPadX", "", 0, 30)
	AddIntSetting(pageAppearance, "Vertical Padding", "TextPadY", "", 0, 30)

	apprSampleEdit := AddSampleTextRow(pageAppearance, "", DEFAULT_SAMPLE_TEXT, (*) => 0)

	btnPreviewAppearance := SettingsGui.Add("Button", "x" PX " y+14 w100", "Preview")
	pageAppearance.Add(btnPreviewAppearance)
	btnPreviewAppearance.OnEvent("Click", (*) => _PreviewAppearance())

	; --- History ---
	pageHistory.Add(SettingsGui.Add("Text", "x" PX " y" cy0 " w130", "Font name:"))
	histFontNameLabel := SettingsGui.Add("Text", "x" VX " yp w150", appearanceFont.name)
	pageHistory.Add(histFontNameLabel)

	AddFloatSetting(pageHistory, "Font Size", "HistFontSize")

	AddColorSetting(pageHistory, "Text Color", "HistTextColor")
	AddColorSetting(pageHistory, "Background Color", "HistBgColor")
	AddSliderSetting(pageHistory, "Background Alpha", "HistAlpha", "", 1, 255)

	histSampleEdit := AddSampleTextRow(pageHistory, "", DEFAULT_SAMPLE_TEXT, (*) => 0)

	btnPreviewHistory := SettingsGui.Add("Button", "x" PX " y+14 w100", "Preview")
	pageHistory.Add(btnPreviewHistory)
	btnPreviewHistory.OnEvent("Click", (*) => _PreviewHistory())

	; --- Special ---
	specialFontNameEdit := AddFontRow(pageSpecial, specialFont, cy0, (*) => 0)

	AddColorSetting(pageSpecial, "Border Color", "SpecialBorderColor")
	AddColorSetting(pageSpecial, "Fill Color", "SpecialBgColor")
	AddColorSetting(pageSpecial, "Text Color", "SpecialTextColor")
	AddSliderSetting(pageSpecial, "Background Alpha", "SpecialAlpha", "", 1, 255)
	AddIntSetting(pageSpecial, "Border Width", "SpecialBorderWidth", "", 0, 20)
	AddIntSetting(pageSpecial, "Horizontal Padding", "SpecialTextPadX", "", 0, 30)
	AddIntSetting(pageSpecial, "Vertical Padding", "SpecialTextPadY", "", 0, 30)
	AddIntSetting(pageSpecial, "Text Y Nudge", "SpecialTextYNudge", "", -20, 20)

	combineVal := Number(osd.CombineSpecialKeys)
	chkCombine := SettingsGui.Add("Checkbox", "x" PX " y+12 vCombineSpecialKeys" (combineVal ? " Checked" : ""),
		"Combine special keys")
	pageSpecial.Add(chkCombine)

	AddIntSetting(pageSpecial, "Gap Between Keys", "SpecialGap", "", 0, 60)

	btnPreviewSpecial := SettingsGui.Add("Button", "x" PX " y+14 w100", "Preview")
	pageSpecial.Add(btnPreviewSpecial)
	btnPreviewSpecial.OnEvent("Click", (*) => _PreviewSpecial())

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

	btnResetDefaults := SettingsGui.Add("Button", "xm yp+50 w110", "Reset to Defaults")
	btnResetDefaults.OnEvent("Click", _ResetToDefaults)
	btnSaveProfile := SettingsGui.Add("Button", "x+5 yp w95", "Save Profile...")
	btnSaveProfile.OnEvent("Click", _SaveProfileAs)
	btnLoadProfile := SettingsGui.Add("Button", "x+5 yp w95", "Load Profile...")
	btnLoadProfile.OnEvent("Click", _LoadProfile)

	btnSave := SettingsGui.Add("Button", "Default x+5 yp w60", "OK")
	btnSave.OnEvent("Click", SaveSettings)
	_CloseSettingsGui(*) {
		try Hotkey(HotkeyToggleStr, "On")
		try Hotkey(HotkeyHideStr, "On")
		SetTimer(KeyWatcher, 16)
		HideOSDInstant()
		SettingsGui.Destroy()
	}

	btnCancel := SettingsGui.Add("Button", "x+5 yp w60", "Cancel")
	btnCancel.OnEvent("Click", _CloseSettingsGui)
	SettingsGui.OnEvent("Close", _CloseSettingsGui)

	nav.OnEvent("ItemSelect", (ctrl, item) => (nodeToPage.Has(item) ? _ActivatePage(nodeToPage[item]) : 0))
	nav.Modify(nodeLayout, "Select")
	_ActivatePage(pageLayout)

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
			_WarnIfFontMissing(fName)
			updatePreview()
		}
	}

	AddIntSetting(page, label, key, yPos := "", minVal := 0, maxVal := 9999) {
		global osd
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

	AddFloatSetting(page, label, key, yPos := "", minVal := 0.1) {
		global osd
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+10"
		page.Add(SettingsGui.Add("Text", opt " w130", label ":"))
		val := Number(osd.%key%)
		editCtrl := SettingsGui.Add("Edit", "x" VX " yp-3 w110 v" key, val)
		page.Add(editCtrl)
		editCtrl.OnEvent("LoseFocus", _SanitizeFloat.Bind(minVal))
		return editCtrl
	}

	_SanitizeFloat(minVal, ctrl, *) {
		clean := RegExReplace(ctrl.Value, "[^\d.]")
		n := clean = "" ? minVal : Max(minVal, Number(clean))
		ctrl.Value := n
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
		global osd
		opt := (yPos != "") ? "x" PX " y" yPos : "x" PX " y+8"
		page.Add(SettingsGui.Add("Text", opt " w130 h22", label ":"))
		val := Number(osd.%key%)
		sliderCtrl := SettingsGui.Add("Slider", "x" (PX + 130) " yp w130 h22 v" key " Range" min "-" max " TickInterval50 AltSubmit", val)
		page.Add(sliderCtrl)
		textCtrl := SettingsGui.Add("Text", "x+5  yp w30  h22 v" key "Value", val)
		page.Add(textCtrl)
		sliderCtrl.OnEvent("Change", (ctrl, *) => (textCtrl.Text := ctrl.Value))
		return sliderCtrl
	}

	AddColorSetting(page, label, key, yPos := "") {
		global osd
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
	}

	_ApplyLayoutOverrides() {
		saved := {
			Position: osd.Position, MarginX: osd.MarginX, MarginY: osd.MarginY,
			Width: osd.Width, AutoWidth: osd.AutoWidth, MaxLines: osd.MaxLines,
			LineGap: osd.LineGap, WordWrap: osd.WordWrap
		}
		osd.Position := SettingsGui["Position"].Text
		osd.MarginX := Number(SettingsGui["MarginX"].Value)
		osd.MarginY := Number(SettingsGui["MarginY"].Value)
		osd.Width := Number(SettingsGui["Width"].Value)
		osd.AutoWidth := SettingsGui["AutoWidth"].Value
		osd.MaxLines := Number(SettingsGui["MaxLines"].Value)
		osd.LineGap := Number(SettingsGui["LineGap"].Value)
		osd.WordWrap := SettingsGui["WordWrap"].Value
		return saved
	}

	_RestoreLayoutOverrides(saved) {
		osd.Position := saved.Position
		osd.MarginX := saved.MarginX
		osd.MarginY := saved.MarginY
		osd.Width := saved.Width
		osd.AutoWidth := saved.AutoWidth
		osd.MaxLines := saved.MaxLines
		osd.LineGap := saved.LineGap
		osd.WordWrap := saved.WordWrap
	}

	_WarnIfFontMissing(fontName) {
		if IsFontAvailable(fontName)
			return false
		SettingsGui.Opt("+OwnDialogs")
		MsgBox("Font '" fontName "' cannot be drawn (likely an old bitmap font or a typo). Text using it will not appear.`nPlease change the font.", "Font not usable", "Iconx")
		return true
	}

	_RunPreview(osdKeys, applyFn, drawFn) {
		saved := Map()
		for key in osdKeys
			saved[key] := osd.%key%

		savedLayout := _ApplyLayoutOverrides()
		applyFn()

		HideOSDInstant()
		drawFn()
		RenderOSD(, true)

		for key in osdKeys
			osd.%key% := saved[key]
		_RestoreLayoutOverrides(savedLayout)
	}

	_ApplyAppearancePreviewValues() {
		osd.FontName := appearanceFont.name
		osd.FontSize := appearanceFont.size
		osd.FontBold := appearanceFont.bold
		osd.FontItalic := appearanceFont.italic
		osd.BgColor := SettingsGui["BgColor"].Value
		osd.BgAlpha := Integer(SettingsGui["BgAlpha"].Value)
		osd.TextColor := SettingsGui["TextColor"].Value
		osd.TextPadX := Number(SettingsGui["TextPadX"].Value)
		osd.TextPadY := Number(SettingsGui["TextPadY"].Value)
		osd.LineHeight := MeasureTextHeight(osd.FontName, osd.FontSize, osd.FontBold, osd.FontItalic) + osd.TextPadY * 2
	}

	_PreviewAppearance() {
		sampleText := apprSampleEdit.Value
		if (sampleText = "")
			return
		if _WarnIfFontMissing(appearanceFont.name)
			return

		_RunPreview(["FontName", "FontSize", "FontBold", "FontItalic",
			"BgColor", "BgAlpha", "TextColor", "TextPadX", "TextPadY", "LineHeight"],
			_ApplyAppearancePreviewValues,
			() => PushLine(sampleText))
	}

	_ApplyHistoryPreviewValues() {
		osd.FontName := appearanceFont.name
		osd.FontBold := appearanceFont.bold
		osd.FontItalic := appearanceFont.italic
		osd.HistFontSize := Number(SettingsGui["HistFontSize"].Value)
		osd.HistBgColor := SettingsGui["HistBgColor"].Value
		osd.HistAlpha := Integer(SettingsGui["HistAlpha"].Value)
		osd.HistTextColor := SettingsGui["HistTextColor"].Value
		osd.HistLineHeight := MeasureTextHeight(osd.FontName, osd.HistFontSize, osd.FontBold, osd.FontItalic) + Round(osd.TextPadY * HistTextScale()) * 2
	}

	_DrawHistoryPreviewLine(sampleText) {
		PushLine(sampleText)
		PushEmptyActivePlaceholder()
	}

	_PreviewHistory() {
		sampleText := histSampleEdit.Value
		if (sampleText = "")
			return
		if _WarnIfFontMissing(appearanceFont.name)
			return

		_RunPreview(["FontName", "FontBold", "FontItalic",
			"HistFontSize", "HistBgColor", "HistAlpha", "HistTextColor", "HistLineHeight"],
			_ApplyHistoryPreviewValues,
			() => _DrawHistoryPreviewLine(sampleText))
	}

	_ApplySpecialPreviewValues() {
		osd.SpecialFontName := specialFont.name
		osd.SpecialFontSize := specialFont.size
		osd.SpecialFontBold := specialFont.bold
		osd.SpecialFontItalic := specialFont.italic
		osd.SpecialBgColor := SettingsGui["SpecialBgColor"].Value
		osd.SpecialAlpha := Integer(SettingsGui["SpecialAlpha"].Value)
		osd.SpecialTextColor := SettingsGui["SpecialTextColor"].Value
		osd.SpecialBorderColor := SettingsGui["SpecialBorderColor"].Value
		osd.SpecialBorderWidth := Number(SettingsGui["SpecialBorderWidth"].Value)
		osd.SpecialTextPadX := Number(SettingsGui["SpecialTextPadX"].Value)
		osd.SpecialTextPadY := Number(SettingsGui["SpecialTextPadY"].Value)
		osd.SpecialGap := Number(SettingsGui["SpecialGap"].Value)
		osd.SpecialTextYNudge := _SafeNudge(SettingsGui["SpecialTextYNudge"].Value)
	}

	_DrawSpecialPreviewLine() {
		PushLine("Ctrl", true)
		osd.State.Lines[osd.State.Lines.Length].AddSegment("PgDn")
	}

	_PreviewSpecial() {
		if _WarnIfFontMissing(specialFont.name)
			return

		_RunPreview(["SpecialFontName", "SpecialFontSize", "SpecialFontBold", "SpecialFontItalic",
			"SpecialBgColor", "SpecialAlpha", "SpecialTextColor", "SpecialBorderColor",
			"SpecialBorderWidth", "SpecialTextPadX", "SpecialTextPadY", "SpecialGap", "SpecialTextYNudge"],
			_ApplySpecialPreviewValues,
			_DrawSpecialPreviewLine)
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
		}
	}

	_FieldSectionMap() {
		sections := Map()
		for f in _SettingsFieldTable()
			sections[f.key] := f.section
		return sections
	}

	_WriteSettingsToFile(path) {
		fieldSections := _FieldSectionMap()
		results := SettingsGui.Submit(false)
		for key, value in results.OwnProps() {
			if (key = "Position")
				value := SettingsGui["Position"].Text
			section := fieldSections.Has(key) ? fieldSections[key] : "Appearance"
			IniWrite(value, path, section, key)
		}

		IniWrite(appearanceFont.name, path, "Appearance", "FontName")
		IniWrite(appearanceFont.size, path, "Appearance", "FontSize")
		IniWrite(appearanceFont.bold, path, "Appearance", "FontBold")
		IniWrite(appearanceFont.italic, path, "Appearance", "FontItalic")

		IniWrite(specialFont.name, path, "Special", "SpecialFontName")
		IniWrite(specialFont.size, path, "Special", "SpecialFontSize")
		IniWrite(specialFont.bold, path, "Special", "SpecialFontBold")
		IniWrite(specialFont.italic, path, "Special", "SpecialFontItalic")

		IniWrite(radioGroup.Value ? "Group" : "Alone", path, "Filters", "FilterModifierMode")
		SaveExcludedKeyEntries(ExcludedEntries, path)

		newPauseHotkey := (hkPause.Value != "") ? hkPause.Value : HotkeyToggleStr
		IniWrite(newPauseHotkey, path, "Hotkeys", "TogglePause")

		newHideHotkey := (hkHide.Value != "") ? hkHide.Value : HotkeyHideStr
		IniWrite(newHideHotkey, path, "Hotkeys", "HideOSD")
	}

	SaveSettings(*) {
		global HotkeyToggleStr, HotkeyHideStr, PendingReload
		if (_WarnIfFontMissing(appearanceFont.name) || _WarnIfFontMissing(specialFont.name))
			return
		_WriteSettingsToFile(IniFile)
		SettingsGui.Hide()
		SettingsGui.Opt("+OwnDialogs")

		if (MsgBox("Settings saved.`nThe program needs to restart for changes to take effect.`nRestart now?",
			"Settings Saved", "YesNo Icon!") = "Yes") {
			PendingReload := false
			ClearMeasureTextWidthCache()
			Reload()
		} else {
			PendingReload := true
			_CloseSettingsGui()
		}
	}

	_SettingsFieldTable() {
		return [
			{ key: "TextColor", section: "Appearance", def: "FFFFFF" },
			{ key: "BgColor", section: "Appearance", def: "EC3700" },
			{ key: "BgAlpha", section: "Appearance", def: 200, numeric: true },
			{ key: "TextPadX", section: "Appearance", def: 8, numeric: true },
			{ key: "TextPadY", section: "Appearance", def: 5, numeric: true },

			{ key: "AutoWidth", section: "Layout", def: 1, numeric: true },
			{ key: "WordWrap", section: "Layout", def: 1, numeric: true },
			{ key: "Width", section: "Layout", def: 350, numeric: true },
			{ key: "MaxLines", section: "Layout", def: 5, numeric: true },
			{ key: "LineGap", section: "Layout", def: 2, numeric: true },
			{ key: "Position", section: "Layout", def: "BottomLeft" },
			{ key: "MarginX", section: "Layout", def: 20, numeric: true },
			{ key: "MarginY", section: "Layout", def: 30, numeric: true },

			{ key: "HistTextColor", section: "History", def: "FFFFFF" },
			{ key: "HistBgColor", section: "History", def: "AAAAAA" },
			{ key: "HistAlpha", section: "History", def: 150, numeric: true },
			{ key: "HistFontSize", section: "History", def: 15, numeric: true },

			{ key: "SpecialBorderColor", section: "Special", def: "383838" },
			{ key: "SpecialBgColor", section: "Special", def: "FFFFFF" },
			{ key: "SpecialTextColor", section: "Special", def: "000000" },
			{ key: "SpecialAlpha", section: "Special", def: 175, numeric: true },
			{ key: "SpecialBorderWidth", section: "Special", def: 3, numeric: true },
			{ key: "SpecialTextPadX", section: "Special", def: 1, numeric: true },
			{ key: "SpecialTextPadY", section: "Special", def: 1, numeric: true },
			{ key: "SpecialTextYNudge", section: "Special", def: 0, numeric: true },
			{ key: "CombineSpecialKeys", section: "Special", def: 1, numeric: true },
			{ key: "SpecialGap", section: "Special", def: 3, numeric: true },

			{ key: "DisplayTime", section: "Timing", def: 4000, numeric: true },
			{ key: "DismissDelay", section: "Timing", def: 3000, numeric: true },
			{ key: "ModifierDelay", section: "Timing", def: 150, numeric: true },

			{ key: "FilterFunctionKeys", section: "Filters", def: 0, numeric: true },
			{ key: "FilterNumpad", section: "Filters", def: 0, numeric: true },
			{ key: "FilterLetters", section: "Filters", def: 0, numeric: true },
			{ key: "FilterDigits", section: "Filters", def: 0, numeric: true },
			{ key: "FilterArrows", section: "Filters", def: 0, numeric: true },
			{ key: "FilterNavKeys", section: "Filters", def: 0, numeric: true },
			{ key: "FilterModifiers", section: "Filters", def: 0, numeric: true },
			{ key: "FilterCustomList", section: "Filters", def: 0, numeric: true },
			{ key: "FilterOtherLetters", section: "Filters", def: 0, numeric: true },
			{ key: "FilterOtherLettersChars", section: "Filters", def: "" }
		]
	}

	_DefaultFontProfile(size) {
		return { name: "Segoe UI", size: size, bold: 1, italic: 0 }
	}

	_DefaultSettingsBundle() {
		values := Map()
		for f in _SettingsFieldTable()
			values[f.key] := f.def
		values["FilterModifierMode"] := "Alone"
		values["_AppearanceFont"] := _DefaultFontProfile(20)
		values["_SpecialFont"] := _DefaultFontProfile(20)
		values["TogglePause"] := "^+F12"
		values["HideOSD"] := "^+F9"
		values["_ExcludedEntries"] := []
		return values
	}

	_ReadSettingsBundleFromFile(path) {
		values := Map()
		for f in _SettingsFieldTable() {
			raw := IniRead(path, f.section, f.key, f.def)
			values[f.key] := f.HasOwnProp("numeric") ? Number(raw) : raw
		}
		values["FilterModifierMode"] := IniRead(path, "Filters", "FilterModifierMode", "Alone")
		values["_AppearanceFont"] := {
			name: IniRead(path, "Appearance", "FontName", "Segoe UI"),
			size: Number(IniRead(path, "Appearance", "FontSize", 20)),
			bold: Number(IniRead(path, "Appearance", "FontBold", 1)),
			italic: Number(IniRead(path, "Appearance", "FontItalic", 0))
		}
		values["_SpecialFont"] := {
			name: IniRead(path, "Special", "SpecialFontName", "Segoe UI"),
			size: Number(IniRead(path, "Special", "SpecialFontSize", 20)),
			bold: Number(IniRead(path, "Special", "SpecialFontBold", 1)),
			italic: Number(IniRead(path, "Special", "SpecialFontItalic", 0))
		}
		values["TogglePause"] := IniRead(path, "Hotkeys", "TogglePause", "^+F12")
		values["HideOSD"] := IniRead(path, "Hotkeys", "HideOSD", "^+F9")
		values["_ExcludedEntries"] := LoadExcludedKeyEntries(path)
		return values
	}

	_ApplySimpleField(key, value) {
		ctrl := SettingsGui[key]
		if (key = "Position" || ctrl.Type = "DropDownList")
			ctrl.Text := value
		else if (ctrl.Type = "Slider")
			ctrl.Value := Max(1, Min(255, Number(value)))
		else if (ctrl.Type = "Checkbox")
			ctrl.Value := value ? 1 : 0
		else
			ctrl.Value := String(value)
		if (ctrl.Type = "Slider")
			SettingsGui[key "Value"].Text := ctrl.Value
		if (ctrl.HasOwnProp("PreviewCtrl"))
			_UpdateColorPreview(ctrl, ctrl.PreviewCtrl)
	}

	_ApplySettingsBundle(values) {
		for f in _SettingsFieldTable()
			if values.Has(f.key)
				_ApplySimpleField(f.key, values[f.key])

		_ToggleModifierRadios()
		if (values.Has("FilterModifierMode") && values["FilterModifierMode"] = "Group")
			radioGroup.Value := 1
		else
			radioAlone.Value := 1

		if values.Has("_AppearanceFont") {
			f := values["_AppearanceFont"]
			appearanceFont.name := f.name, appearanceFont.size := f.size
			appearanceFont.bold := f.bold, appearanceFont.italic := f.italic
			fontNameEdit.Value := f.name
			histFontNameLabel.Text := f.name
		}
		if values.Has("_SpecialFont") {
			f := values["_SpecialFont"]
			specialFont.name := f.name, specialFont.size := f.size
			specialFont.bold := f.bold, specialFont.italic := f.italic
			specialFontNameEdit.Value := f.name
		}

		if values.Has("TogglePause")
			hkPause.Value := values["TogglePause"]
		if values.Has("HideOSD")
			hkHide.Value := values["HideOSD"]

		if values.Has("_ExcludedEntries") {
			ExcludedEntries := values["_ExcludedEntries"]
			lstExcluded.Delete()
			for entry in ExcludedEntries
				lstExcluded.Add([entry.display])
		}
	}

	_ProfilesDir() {
		dir := A_ScriptDir "\profiles"
		if !DirExist(dir)
			DirCreate(dir)
		return dir
	}

	_SaveProfileAs(*) {
		if (_WarnIfFontMissing(appearanceFont.name) || _WarnIfFontMissing(specialFont.name))
			return
		SettingsGui.Opt("+OwnDialogs")
		selected := FileSelect("S16", _ProfilesDir() "\profile.ini", "Save Profile", "Settings (*.ini)")
		if (selected = "")
			return
		if !RegExMatch(selected, "i)\.ini$")
			selected .= ".ini"
		_WriteSettingsToFile(selected)
		SettingsGui.Opt("+OwnDialogs")
		MsgBox("Profile saved to:`n" selected, "Keyboard OSD", "IconI")
	}

	_LoadProfile(*) {
		SettingsGui.Opt("+OwnDialogs")
		selected := FileSelect(1, _ProfilesDir(), "Load Profile", "Settings (*.ini)")
		if (selected = "")
			return
		_ApplySettingsBundle(_ReadSettingsBundleFromFile(selected))
		SettingsGui.Opt("+OwnDialogs")
		MsgBox("Profile loaded into the form. Click OK to apply it.", "Keyboard OSD", "IconI")
	}

	_ResetToDefaults(*) {
		SettingsGui.Opt("+OwnDialogs")
		if (MsgBox("Reset all settings to their defaults?`nThis only changes the form - nothing is applied until you click OK.",
			"Reset to Defaults", "YesNo Icon!") != "Yes")
			return
		_ApplySettingsBundle(_DefaultSettingsBundle())
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

LoadExcludedKeyEntries(path := "") {
	global IniFile
	if (path = "")
		path := IniFile
	entries := []
	section := ""
	try section := IniRead(path, "ExcludedKeys")
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

SaveExcludedKeyEntries(entries, path := "") {
	global IniFile
	if (path = "")
		path := IniFile
	try IniDelete(path, "ExcludedKeys")
	i := 0
	for entry in entries {
		i += 1
		IniWrite(entry.raw, path, "ExcludedKeys", "Key" i)
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