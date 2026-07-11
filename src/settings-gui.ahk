global IniFile
global osd

global sectionMap := Map()
sectionMap["TextColor"] := "Appearance"
sectionMap["BgColor"] := "Appearance"
sectionMap["BgAlpha"] := "Appearance"
sectionMap["FontName"] := "Appearance"
sectionMap["FontSize"] := "Appearance"
sectionMap["FontBold"] := "Appearance"
sectionMap["FontItalic"] := "Appearance"
sectionMap["FontUnderline"] := "Appearance"
sectionMap["FontStrikeout"] := "Appearance"
sectionMap["CornerRadius"] := "Appearance"

sectionMap["Width"] := "Layout"
sectionMap["AutoWidth"] := "Layout"
sectionMap["MaxLines"] := "Layout"
sectionMap["LineGap"] := "Layout"
sectionMap["WordWrap"] := "Layout"
sectionMap["Position"] := "Layout"
sectionMap["MarginX"] := "Layout"
sectionMap["MarginY"] := "Layout"
sectionMap["PaddingX"] := "Layout"
sectionMap["PaddingYTop"] := "Layout"
sectionMap["PaddingYBottom"] := "Layout"

sectionMap["HistFontSize"] := "History"
sectionMap["HistTextColor"] := "History"
sectionMap["HistBgColor"] := "History"
sectionMap["HistAlpha"] := "History"

sectionMap["DisplayTime"] := "Timing"
sectionMap["DismissDelay"] := "Timing"
sectionMap["ModifierDelay"] := "Timing"

sectionMap["SpecialBgColor"] := "Special"
sectionMap["SpecialTextColor"] := "Special"
sectionMap["SpecialBorderColor"] := "Special"
sectionMap["SpecialAlpha"] := "Special"
sectionMap["SpecialBorderWidth"] := "Special"
sectionMap["SpecialTextPad"] := "Special"
sectionMap["SpecialTextYNudge"] := "Special"

ShowSettingsGui() {
	SettingsGui := Gui("+AlwaysOnTop", "Keyboard OSD Settings")
	SettingsGui.SetFont("s9", "Segoe UI")

	fontSizeVal := Number(osd.FontSize)
	fontBoldVal := Number(osd.FontBold)
	fontItalicVal := Number(osd.FontItalic)
	fontUnderlineVal := Number(osd.FontUnderline)
	fontStrikeoutVal := Number(osd.FontStrikeout)

	tabX := 8
	tabY := 8
	tabW := 318
	tabH := 335
	cy0 := 48

	tabCtrl := SettingsGui.Add("Tab", "x" tabX " y" tabY " w" tabW " h" tabH,
		["Appearance", "Layout", "History", "Special", "Timing"])

	tabCtrl.UseTab(1)

	AddColorSetting("Text Color", "TextColor", cy0)
	AddColorSetting("Background Color", "BgColor")
	AddSliderSetting("Background Alpha", "BgAlpha", "", 1, 255)

	SettingsGui.Add("Text", "x20 y+10 w130", "Font:")
	fontNameVal := osd.FontName
	fontNameEdit := SettingsGui.Add("Edit", "x155 yp-3 w120 vFontName -Multi", fontNameVal)
	btnFont := SettingsGui.Add("Button", "x+4 yp w30 h22", "...")
	btnFont.OnEvent("Click", _PickFont)

	fontPreviewPic := SettingsGui.Add("Picture", "x20 y+10 w290 h40", "")
	fontPreviewCtrl := SettingsGui.Add("Text", "x20 yp w290 h40 BackgroundTrans +Center +0x200", "Sample Text")

	SettingsGui.Add("Text", "x20 y+8 w130", "OSD Corners:")
	cornerVal := osd.CornerRadius
	chkCorners := SettingsGui.Add("Checkbox", "x155 yp-3 vCornerRadius" (cornerVal != 0 ? " Checked" : ""), "Round")
	chkCorners.OnEvent("Click", (*) => _UpdateFontPreview())

	tabCtrl.UseTab(2)

	autoVal := Number(osd.AutoWidth)
	SettingsGui.Add("Checkbox", "x20 y" cy0 " vAutoWidth" (autoVal ? " Checked" : ""), "Auto width")

	wordWrapVal := Number(osd.WordWrap)
	SettingsGui.Add("Checkbox", "x+50 yp vWordWrap" (wordWrapVal ? " Checked" : ""), "Word wrap")

	AddIntSetting("Max width", "Width", "", 50, 500)
	AddIntSetting("Max Lines", "MaxLines", "", 1, 10)
	AddIntSetting("Line Gap", "LineGap", "", 0, 20)

	SettingsGui.Add("Text", "x20 y+10 w130", "Position:")
	posVal := osd.Position
	posList := ["TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight"]
	choice := 0
	for i, v in posList
		if (v = posVal)
			choice := i
	SettingsGui.Add("DropDownList", "x155 yp-3 w130 vPosition Choose" (choice || 4), posList)

	AddIntSetting("Margin X", "MarginX", "", 0, 200)
	AddIntSetting("Margin Y", "MarginY", "", 0, 200)
	AddIntSetting("Padding X", "PaddingX", "", 0, 50)
	AddIntSetting("Padding Y (Top)", "PaddingYTop", "", 0, 50)
	AddIntSetting("Padding Y (Bottom)", "PaddingYBottom", "", 0, 50)

	tabCtrl.UseTab(3)

	histFsSetting := AddIntSetting("Font Size", "HistFontSize", cy0, 8, 72)
	histFsSetting.OnEvent("Change", (*) => _UpdateHistPreview())
	AddColorSetting("Text Color", "HistTextColor")
	AddColorSetting("Background Color", "HistBgColor")
	AddSliderSetting("Background Alpha", "HistAlpha", "", 1, 255)

	histPreviewPic := SettingsGui.Add("Picture", "x20 y+10 w270 h35", "")
	histPreviewCtrl := SettingsGui.Add("Text", "x20 yp  w270 h35 BackgroundTrans +Center +0x200", "Sample History Text")

	tabCtrl.UseTab(4)

	AddColorSetting("Border Color", "SpecialBorderColor", cy0)
	AddColorSetting("Fill Color", "SpecialBgColor")
	AddColorSetting("Text Color", "SpecialTextColor")
	AddSliderSetting("Alpha", "SpecialAlpha", "", 1, 255)
	borderWidthCtrl := AddIntSetting("Border Width", "SpecialBorderWidth", "", 1, 20)
	borderWidthCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())
	textPadCtrl := AddIntSetting("Text Padding", "SpecialTextPad", "", 0, 30)
	textPadCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())
	textNudgeCtrl := AddIntSetting("Text Y Nudge", "SpecialTextYNudge", "", -20, 20)
	textNudgeCtrl.OnEvent("Change", (*) => _UpdateSpecialPreview())

	specialPreviewPic := SettingsGui.Add("Picture", "x20 y+10 w200 h50", "")
	specialPreviewPic.GetPos(&specialPreviewX, &specialPreviewY)
	specialPreviewCtrl := SettingsGui.Add("Text", "x" specialPreviewX " y" specialPreviewY " w200 h50 BackgroundTrans +Center +0x200", "Ctrl + PgDn")

	tabCtrl.UseTab(5)

	AddIntSetting("Display Time (ms)", "DisplayTime", cy0, 100, 10000)
	AddIntSetting("Dismiss Delay (ms)", "DismissDelay", "", 50, 1000)
	AddIntSetting("Modifier Delay (ms)", "ModifierDelay", "", 50, 1000)

	tabCtrl.UseTab()
	yBtns := tabY + tabH + 10
	btnSave := SettingsGui.Add("Button", "Default x60 y" yBtns " w80", "Save")
	btnSave.OnEvent("Click", SaveSettings)
	btnCancel := SettingsGui.Add("Button", "x+20 yp w80", "Cancel")
	btnCancel.OnEvent("Click", (*) => SettingsGui.Destroy())

	_UpdateFontPreview()
	_UpdateHistPreview()
	_UpdateSpecialPreview()
	SettingsGui.Show()

	_PickFont(*) {
		fName := Trim(fontNameEdit.Value)
		fSize := fontSizeVal
		bold := fontBoldVal
		italic := fontItalicVal
		underline := fontUnderlineVal
		strikeout := fontStrikeoutVal

		textColorEdit := SettingsGui["TextColor"]
		fColor := textColorEdit.Value

		if FontDialog.Choose(SettingsGui.Hwnd, &fName, &fSize, &bold, &italic, &underline, &strikeout, &fColor) {
			fontNameEdit.Value := fName
			fontSizeVal := fSize
			fontBoldVal := bold ? 1 : 0
			fontItalicVal := italic ? 1 : 0
			fontUnderlineVal := underline ? 1 : 0
			fontStrikeoutVal := strikeout ? 1 : 0

			textColorEdit.Value := fColor
			_UpdateColorPreview(textColorEdit, textColorEdit.PreviewCtrl)
			_UpdateFontPreview()
		}
	}

	AddIntSetting(label, key, yPos := "", min := 0, max := 9999) {
		global osd, sectionMap
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+10"
		SettingsGui.Add("Text", opt " w130", label ":")
		val := Number(osd.%key%)
		editCtrl := SettingsGui.Add("Edit", "x155 yp-3 w110 v" key " Number")
		SettingsGui.Add("UpDown", "x+0 y-1 w20 Range" min "-" max " AltSubmit", val)
		editCtrl.Value := val
		return editCtrl
	}

	AddSliderSetting(label, key, yPos := "", min := 0, max := 255) {
		global osd, sectionMap
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+8"
		SettingsGui.Add("Text", opt " w130 h22", label ":")
		val := Number(osd.%key%)
		sliderCtrl := SettingsGui.Add("Slider", "x150 yp w130 h22 v" key " Range" min "-" max " TickInterval50 AltSubmit", val)
		textCtrl := SettingsGui.Add("Text", "x+5  yp w30  h22 v" key "Value", val)
		sliderCtrl.OnEvent("Change", (ctrl, *) => (textCtrl.Text := ctrl.Value, _UpdateFontPreview(), _UpdateHistPreview(), _UpdateSpecialPreview()))
		return sliderCtrl
	}

	AddColorSetting(label, key, yPos := "") {
		global osd, sectionMap
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+10"
		SettingsGui.Add("Text", opt " w130", label ":")
		val := osd.%key%
		editCtrl := SettingsGui.Add("Edit", "x155 yp-3 w90 v" key, val)
		preview := SettingsGui.Add("Text", "x+5  yp  w22 h22 +Border Background" val)
		btnColor := SettingsGui.Add("Button", "x+4  yp  w30 h22", "...")
		editCtrl.PreviewCtrl := preview
		editCtrl.OnEvent("Change", (ctrl, *) => _OnColorChange(ctrl, preview))
		preview.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd))
		btnColor.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd))
		return editCtrl
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
		bgHex := SettingsGui["BgColor"].Value
		alphaVal := SettingsGui["BgAlpha"].Value
		RenderPreviewBadge(fontPreviewPic, 270, 40, bgHex, alphaVal)
		fontPreviewPic.Redraw()

		opts := "s" fontSizeVal
			. " " (fontBoldVal ? "Bold" : "norm")
			. (fontItalicVal ? " Italic" : "")
			. (fontUnderlineVal ? " Underline" : "")
			. (fontStrikeoutVal ? " Strike" : "")
			. " c" BlendHexColor(SettingsGui["TextColor"].Value, "FFFFFF", alphaVal)

		fontPreviewCtrl.SetFont(opts, fontNameEdit.Value)
		fontPreviewCtrl.Redraw()
	}

	_UpdateHistPreview() {
		if !IsSet(histPreviewPic)
			return
		bgHex := SettingsGui["HistBgColor"].Value
		alphaVal := SettingsGui["HistAlpha"].Value
		RenderPreviewBadge(histPreviewPic, 270, 35, bgHex, alphaVal)
		histPreviewPic.Redraw()

		histFsVal := SettingsGui["HistFontSize"].Value
		opts := "s" histFsVal
			. " " (fontBoldVal ? "Bold" : "norm")
			. (fontItalicVal ? " Italic" : "")
			. " c" BlendHexColor(SettingsGui["HistTextColor"].Value, "FFFFFF", alphaVal)

		histPreviewCtrl.SetFont(opts, fontNameEdit.Value)
		histPreviewCtrl.Redraw()
	}

	_UpdateSpecialPreview() {
		if !IsSet(specialPreviewPic)
			return

		borderW := Number(SettingsGui["SpecialBorderWidth"].Value)
		textPad := Number(SettingsGui["SpecialTextPad"].Value)
		alphaVal := SettingsGui["SpecialAlpha"].Value
		sampleText := "Ctrl + PgDn"

		textH := MeasureTextHeight(fontNameEdit.Value, fontSizeVal, fontBoldVal, fontItalicVal)
		textW := MeasureTextWidth(sampleText, fontNameEdit.Value, fontSizeVal, fontBoldVal, fontItalicVal)
		pw := textW + 2 * (borderW + textPad) + 20
		ph := textH + 2 * (borderW + textPad)

		specialPreviewPic.Move(specialPreviewX, specialPreviewY, pw, ph)
		RenderPreviewBadge(specialPreviewPic, pw, ph,
			SettingsGui["SpecialBgColor"].Value, alphaVal,
			SettingsGui["SpecialBorderColor"].Value, borderW, SPECIAL_OUTER_RADIUS)
		specialPreviewPic.Redraw()

		nudge := Number(SettingsGui["SpecialTextYNudge"].Value)
		opts := "s" fontSizeVal
			. " " (fontBoldVal ? "Bold" : "norm")
			. " c" BlendHexColor(SettingsGui["SpecialTextColor"].Value, "FFFFFF", alphaVal)

		specialPreviewCtrl.SetFont(opts, fontNameEdit.Value)
		specialPreviewCtrl.Move(specialPreviewX, specialPreviewY + nudge, pw, ph - nudge)
		specialPreviewCtrl.Redraw()
	}

	_UpdateColorPreview(edit, preview) {
		hex := StrUpper(Trim(edit.Value))
		if (StrLen(hex) = 6 && RegExMatch(hex, "^[0-9A-F]{6}$")) {
			preview.Opt("Background" hex)
			preview.Redraw()
		} else {
			preview.Opt("BackgroundE0E0E0")
			preview.Redraw()
		}
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
		results := SettingsGui.Submit()
		for key, value in results.OwnProps() {
			section := sectionMap.Has(key) ? sectionMap[key] : "Appearance"
			IniWrite(value, IniFile, section, key)
		}

		IniWrite(fontSizeVal, IniFile, "Appearance", "FontSize")
		IniWrite(fontBoldVal, IniFile, "Appearance", "FontBold")
		IniWrite(fontItalicVal, IniFile, "Appearance", "FontItalic")
		IniWrite(fontUnderlineVal, IniFile, "Appearance", "FontUnderline")
		IniWrite(fontStrikeoutVal, IniFile, "Appearance", "FontStrikeout")

		MsgBox("Settings saved. The script will now reload to apply changes.", "Reload Script", "IconI")
		ClearMeasureTextWidthCache()
		Reload()
	}
}