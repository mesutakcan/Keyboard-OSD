; Global variables initialized in main script
global IniFile
global osd

ShowSettingsGui() {
	SettingsGui := Gui("+AlwaysOnTop", "Keyboard OSD Settings")
	SettingsGui.SetFont("s9", "Segoe UI")
	SettingsGui.OnEvent("Escape", (*) => SettingsGui.Destroy())

	; Load font properties (non-control)
	fontVals := Map()
	for prop in ["FontSize", "FontBold", "FontItalic", "FontUnderline", "FontStrikeout"] {
		val := IniRead(IniFile, "OSD", prop, "")
		fontVals[prop] := Number(val = "" ? osd.%prop% : val)
	}
	fontSizeVal := fontVals["FontSize"]
	fontBoldVal := fontVals["FontBold"]
	fontItalicVal := fontVals["FontItalic"]
	fontUnderlineVal := fontVals["FontUnderline"]
	fontStrikeoutVal := fontVals["FontStrikeout"]

	; GroupBox layout constants
	rowH := 28   ; row height
	sliderH := 30   ; slider height
	gbPadTop := 22   ; GroupBox title top padding
	gbPadBot := 10   ; GroupBox title bottom padding
	gbX := 8  ; GroupBox left margin
	gbW := 290 ; GroupBox width
	margin := 10 ; vertical margin between GroupBoxes

	; 1) APPEARANCE
	gbH1 := gbPadTop + rowH * 3 + sliderH + 10 + 40 + 5 + rowH - 8 ; GroupBox 1 height
	yStart := 10 ; Starting y position for first GroupBox
	SettingsGui.Add("GroupBox", "x" gbX " y" yStart " w" gbW " h" gbH1, "Appearance")

	cy := yStart + gbPadTop ; y position for first row
	AddColorSetting("Text Color", "TextColor", cy, "font")
	AddColorSetting("Background Color", "BgColor", "", "font")
	AddSliderSetting("Background Alpha", "BgAlpha", "", 0, 255, "font")

	; Font Name. edit + "..." button
	SettingsGui.Add("Text", "x20 y+10 w130", "Font Name:")
	fontNameVal := IniRead(IniFile, "OSD", "FontName", "")
	if (fontNameVal = "")
		fontNameVal := osd.FontName
	fontNameEdit := SettingsGui.Add("Edit", "x155 yp-3 w95 vFontName +ReadOnly", fontNameVal)
	btnFont := SettingsGui.Add("Button", "x+4 yp w30 h22", "...")
	btnFont.OnEvent("Click", _PickFont)

	; Font Preview. Picture (bg bitmap) + overlaid BackgroundTrans Text
	fontPreviewPic := SettingsGui.Add("Picture", "x20 y+10 w265 h40 +Border", "")
	fontPreviewCtrl := SettingsGui.Add("Text", "x20 yp w265 h40 BackgroundTrans +Center +0x200", "Sample Text")

	; OSD Corners
	SettingsGui.Add("Text", "x20 y+5 w130", "OSD Corners:")
	iniVal := IniRead(IniFile, "OSD", "CornerRadius", "")
	cornerVal := (iniVal != "") ? iniVal : osd.CornerRadius
	chkCorners := SettingsGui.Add("Checkbox", "x155 yp vCornerRadius" (cornerVal != 0 ? " Checked" : ""), "Round")
	chkCorners.OnEvent("Click", (*) => _UpdateFontPreview())

	; 2) LAYOUT
	; Rows: AutoWidth, WordWrap, Max width, LineHeight, MaxLines, LineGap, Position, MarginX, MarginY
	gbH2 := gbPadTop + rowH * 8 + gbPadBot
	yStart += gbH1 + margin
	SettingsGui.Add("GroupBox", "x" gbX " y" yStart " w" gbW " h" gbH2, "Layout")

	cy := yStart + gbPadTop
	; Auto width checkbox (if enabled, Max width will be used as an upper bound)
	iniVal := IniRead(IniFile, "OSD", "WordWrap", "")
	wrapVal := (iniVal != "") ? Number(iniVal) : osd.WordWrap
	chkWordWrap := SettingsGui.Add("Checkbox", "x20 y" cy " vWordWrap" (wrapVal ? " Checked" : ""), "Word wrap")

	iniVal := IniRead(IniFile, "OSD", "AutoWidth", "")
	autoVal := (iniVal != "") ? Number(iniVal) : osd.AutoWidth
	chkAuto := SettingsGui.Add("Checkbox", "x155 yp w120 vAutoWidth" (autoVal ? " Checked" : ""), "Auto width")

	AddIntSetting("Max width", "Width", cy + 30, 50, 500)
	AddIntSetting("Line Height", "LineHeight", "", 10, 100)
	AddIntSetting("Max Lines", "MaxLines", "", 1, 10)
	AddIntSetting("Line Gap", "LineGap", "", 0, 20)

	SettingsGui.Add("Text", "x20 y+10 w130", "Position:")
	posVal := IniRead(IniFile, "OSD", "Position", osd.Position)
	posList := ["TopLeft", "TopCenter", "TopRight", "BottomLeft", "BottomCenter", "BottomRight"]
	choice := 0
	for i, v in posList
		if (v = posVal)
			choice := i
	SettingsGui.Add("DropDownList", "x155 yp-3 w130 vPosition Choose" (choice || 4), posList)

	AddIntSetting("Margin X", "MarginX", "", 0, 200)
	AddIntSetting("Margin Y", "MarginY", "", 0, 200)

	; 3) HISTORY LINES
	; Rows: HistFontSize, HistTextColor, HistBgColor, HistAlpha(slider), preview(35)
	gbH3 := gbPadTop + rowH * 3 + sliderH + 45 + gbPadBot
	yStart += gbH2 + margin
	SettingsGui.Add("GroupBox", "x" gbX " y" yStart " w" gbW " h" gbH3, "History Lines")

	cy := yStart + gbPadTop
	histFsSetting := AddIntSetting("Font Size", "HistFontSize", cy, 8, 72)
	histFsSetting.OnEvent("Change", (*) => _UpdateHistPreview())
	AddColorSetting("Text Color", "HistTextColor", "", "hist")
	AddColorSetting("Background Color", "HistBgColor", "", "hist")
	AddSliderSetting("Background Alpha", "HistAlpha", "", 0, 255, "hist")

	; Hist Preview. Picture (bg bitmap) + overlaid BackgroundTrans Text
	histPreviewPic := SettingsGui.Add("Picture", "x20 y+10 w265 h35 +Border", "")
	histPreviewCtrl := SettingsGui.Add("Text", "x20 yp w265 h35 BackgroundTrans +Center +0x200", "Sample History Text")

	; 4) TIMING
	; Rows: DisplayTime, DismissDelay, ModifierDelay
	gbH4 := gbPadTop + rowH * 3 + gbPadBot
	yStart += gbH3 + margin
	SettingsGui.Add("GroupBox", "x" gbX " y" yStart " w" gbW " h" gbH4, "Timing")

	cy := yStart + gbPadTop
	AddIntSetting("Display Time (ms)", "DisplayTime", cy, 100, 10000)
	AddIntSetting("Dismiss Delay (ms)", "DismissDelay", "", 50, 1000)
	AddIntSetting("Modifier Delay (ms)", "ModifierDelay", "", 50, 1000)

	yStart += gbH4 + margin
	btnSave := SettingsGui.Add("Button", "Default x60 y" yStart " w80", "Save")
	btnSave.OnEvent("Click", SaveSettings)

	btnCancel := SettingsGui.Add("Button", "x+20 yp w80", "Cancel")
	btnCancel.OnEvent("Click", (*) => SettingsGui.Destroy())

	_UpdateFontPreview()
	_UpdateHistPreview()
	SettingsGui.Show()

	_PickFont(*) {
		fName := fontNameEdit.Value
		fSize := fontSizeVal
		bold := fontBoldVal
		italic := fontItalicVal
		underline := fontUnderlineVal
		strikeout := fontStrikeoutVal

		textColorEdit := SettingsGui["TextColor"]
		fColor := textColorEdit.Value

		; Use the FontDialog class to show the font selection dialog.
		; The selected font properties will be returned in the variables passed by reference.
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

	; Helper functions to add settings controls to the GUI
	AddIntSetting(label, key, yPos := "", min := 0, max := 9999) {
		global IniFile, osd
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+10"
		SettingsGui.Add("Text", opt " w130", label ":")
		iniVal := Trim(IniRead(IniFile, "OSD", key, ""))
		val := (iniVal != "") ? Number(iniVal) : osd.%key%
		editCtrl := SettingsGui.Add("Edit", "x155 yp-3 w110 v" key " Number")
		SettingsGui.Add("UpDown", "x+0 y-1 w20 Range" min "-" max " AltSubmit", val)
		editCtrl.Value := val
		return editCtrl
	}

	; Helper function to add a slider setting to the GUI
	AddSliderSetting(label, key, yPos := "", min := 0, max := 255, previewTarget := "both") {
		global IniFile, osd
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+8"
		SettingsGui.Add("Text", opt " w130 h22", label ":")
		iniVal := Trim(IniRead(IniFile, "OSD", key, ""))
		val := (iniVal != "") ? Number(iniVal) : osd.%key%
		sliderCtrl := SettingsGui.Add("Slider", "x155 yp w100 h22 v" key " Range" min "-" max " TickInterval50 AltSubmit", val)
		textCtrl := SettingsGui.Add("Text", "x+5 yp w30 h22 v" key "Value", val)
		sliderCtrl.OnEvent("Change", (ctrl, *) => (textCtrl.Text := ctrl.Value, _UpdateTargetPreview(previewTarget)))
		return sliderCtrl
	}

	; Helper function to add a color setting to the GUI
	AddColorSetting(label, key, yPos := "", previewTarget := "both") {
		global IniFile, osd
		opt := (yPos != "") ? "x20 y" yPos : "x20 y+10"
		SettingsGui.Add("Text", opt " w130", label ":")
		val := IniRead(IniFile, "OSD", key, osd.%key%)
		editCtrl := SettingsGui.Add("Edit", "x155 yp-3 w75 v" key, val)
		preview := SettingsGui.Add("Text", "x+5 yp w22 h22 +Border Background" val)
		btnColor := SettingsGui.Add("Button", "x+4 yp w30 h22", "...")
		editCtrl.PreviewCtrl := preview
		editCtrl.OnEvent("Change", (ctrl, *) => _OnColorChange(ctrl, preview, previewTarget))
		preview.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd, previewTarget))
		btnColor.OnEvent("Click", (ctrl, *) => _PickColor(editCtrl, preview, SettingsGui.Hwnd, previewTarget))
		return editCtrl
	}

	; Shared helper: validates and sanitizes hex color input, updates preview, and refreshes font/hist previews.
	_OnColorChange(edit, preview, previewTarget := "both") {
		val := edit.Value
		upper := StrUpper(val)
		sanitized := RegExReplace(upper, "[^0-9A-F]")
		; Limit to 6 characters
		if (StrLen(sanitized) > 6) {
			sanitized := SubStr(sanitized, 1, 6)
		}
		; If the sanitized value differs from the current value, update the edit control and maintain cursor position.
		if (val !== sanitized) {
			sel := DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x00B0, "Ptr", 0, "Ptr", 0, "Ptr")
			start := sel & 0xFFFF
			edit.Value := sanitized
			newStart := Min(start, StrLen(sanitized))
			DllCall("SendMessage", "Ptr", edit.Hwnd, "UInt", 0x00B1, "Ptr", newStart, "Ptr", newStart)
		}
		_UpdateColorPreview(edit, preview)
		_UpdateTargetPreview(previewTarget)
	}

	_UpdateTargetPreview(previewTarget := "both") {
		if (previewTarget = "font" || previewTarget = "both")
			_UpdateFontPreview()
		if (previewTarget = "hist" || previewTarget = "both")
			_UpdateHistPreview()
	}

	; Shared helper: fills a Picture control with a solid color+alpha HBITMAP
	_MakePreviewBitmap(picCtrl, bgHex, alphaVal, pw, ph) {
		; Free old bitmap stored on the control (if any)
		if (picCtrl.HasProp("_hBmp") && picCtrl._hBmp != 0) {
			DllCall("DeleteObject", "Ptr", picCtrl._hBmp)
			picCtrl._hBmp := 0
		}

		; Create a 32-bit DIBSection and write pixels directly.
		bi := Buffer(40, 0) ; BITMAPINFOHEADER
		NumPut("UInt", 40, bi, 0)
		NumPut("Int", pw, bi, 4)
		; Use negative height for top-down DIB
		NumPut("Int", -ph, bi, 8)
		NumPut("UShort", 1, bi, 12)
		NumPut("UShort", 32, bi, 14)
		NumPut("UInt", 0, bi, 16)
		hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
		pBits := 0
		hBmp := DllCall("gdi32.dll\CreateDIBSection", "Ptr", hdc, "Ptr", bi, "UInt", 0, "PtrP", pBits, "Ptr", 0, "UInt", 0, "Ptr")
		bgHex := (StrLen(bgHex) = 6 && RegExMatch(bgHex, "^[0-9A-F]{6}$")) ? bgHex : "E0E0E0"
		rr := Integer("0x" SubStr(bgHex, 1, 2))
		gg := Integer("0x" SubStr(bgHex, 3, 2))
		bb := Integer("0x" SubStr(bgHex, 5, 2))
		aa := Number(alphaVal)

		; If fully transparent requested, don't set a bitmap (static controls won't respect per-pixel alpha).
		if (aa = 0) {
			if (hBmp)
				DllCall("DeleteObject", "Ptr", hBmp)
			picCtrl._hBmp := 0
			picCtrl.Value := "" ; clear HBITMAP
			; Use a solid fallback background behind transparent text.
			picCtrl.Opt("Background" bgHex)
			picCtrl.Redraw()
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
			return
		}

		; Fill the DIBSection with the pre-multiplied color.
		if (hBmp && pBits) {
			; Pre-multiply alpha over a neutral backdrop for preview since static controls ignore per-pixel alpha.
			af := aa / 255
			outR := Round(af * rr + (1 - af) * 0xE0)
			outG := Round(af * gg + (1 - af) * 0xE0)
			outB := Round(af * bb + (1 - af) * 0xE0)
			pixel := outB | (outG << 8) | (outR << 16) | (0xFF << 24)
			DllCall("ntdll\RtlFillMemoryUlong", "Ptr", pBits, "UPtr", pw * ph * 4, "UInt", pixel)
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
			picCtrl._hBmp := hBmp
			picCtrl.Value := "HBITMAP:" hBmp
		} else {
			; Fallback to legacy CreateBitmap + SetBitmapBits
			if (hBmp)
				DllCall("DeleteObject", "Ptr", hBmp)
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
			hBmp := DllCall("CreateBitmap", "Int", pw, "Int", ph, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")
			pBuf := Buffer(pw * ph * 4)
			pPtr := pBuf.Ptr
			af := aa / 255
			outR := Round(af * rr + (1 - af) * 0xE0)
			outG := Round(af * gg + (1 - af) * 0xE0)
			outB := Round(af * bb + (1 - af) * 0xE0)
			pixel := outB | (outG << 8) | (outR << 16) | (0xFF << 24)
			Loop ph {
				rowBase := (A_Index - 1) * pw * 4
				Loop pw {
					off := rowBase + (A_Index - 1) * 4
					NumPut("UInt", pixel, pPtr, off)
				}
			}
			DllCall("SetBitmapBits", "Ptr", hBmp, "UInt", pw * ph * 4, "Ptr", pPtr)
			picCtrl._hBmp := hBmp
			picCtrl.Value := "HBITMAP:" hBmp
		}
	}

	; Updates the font preview Picture control with the current font settings and background color/alpha.
	_UpdateFontPreview() {
		if !IsSet(fontPreviewPic)
			return
		_MakePreviewBitmap(fontPreviewPic,
			SettingsGui["BgColor"].Value,
			SettingsGui["BgAlpha"].Value,
			265, 40)

		opts := "s" fontSizeVal
			. " " (fontBoldVal ? "Bold" : "norm")
			. (fontItalicVal ? " Italic" : "")
			. (fontUnderlineVal ? " Underline" : "")
			. (fontStrikeoutVal ? " Strike" : "")
			. " c" SettingsGui["TextColor"].Value

		fontPreviewCtrl.SetFont(opts, fontNameEdit.Value)
		fontPreviewCtrl.Redraw()
	}

	; Updates the history preview Picture control with the current history font settings and background color/alpha.
	_UpdateHistPreview() {
		if !IsSet(histPreviewPic)
			return
		_MakePreviewBitmap(histPreviewPic,
			SettingsGui["HistBgColor"].Value,
			SettingsGui["HistAlpha"].Value,
			265, 35)

		histFsVal := SettingsGui["HistFontSize"].Value
		opts := "s" histFsVal
			. " " (fontBoldVal ? "Bold" : "norm")
			. (fontItalicVal ? " Italic" : "")
			. " c" SettingsGui["HistTextColor"].Value

		histPreviewCtrl.SetFont(opts, fontNameEdit.Value)
		histPreviewCtrl.Redraw()
	}

	; Validates the hex color input and updates the preview control's background color.
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

	; Opens a color picker dialog and updates the edit control and preview with the selected color.
	_PickColor(edit, preview, ownerHwnd, previewTarget := "both") {
		static custColors := []
		hex := Trim(edit.Value)
		initColor := (StrLen(hex) = 6 && RegExMatch(hex, "i)^[0-9A-F]{6}$")) ? Integer("0x" hex) : 0
		if ((result := ColorDialog.Choose(initColor, ownerHwnd, &custColors)) != -1) {
			edit.Value := Format("{:06X}", result & 0xFFFFFF)
			_UpdateColorPreview(edit, preview)
			_UpdateTargetPreview(previewTarget)
		}
	}

	; Saves all settings to the INI file and reloads the script to apply changes.
	SaveSettings(*) {
		results := SettingsGui.Submit()
		for key, value in results.OwnProps()
			IniWrite(value, IniFile, "OSD", key)

		IniWrite(fontSizeVal, IniFile, "OSD", "FontSize")
		IniWrite(fontBoldVal, IniFile, "OSD", "FontBold")
		IniWrite(fontItalicVal, IniFile, "OSD", "FontItalic")
		IniWrite(fontUnderlineVal, IniFile, "OSD", "FontUnderline")
		IniWrite(fontStrikeoutVal, IniFile, "OSD", "FontStrikeout")

		ClearMeasureTextWidthCache()
		MsgBox("Settings saved. The script will now reload to apply changes.", "Reload Script", "IconI")
		Reload()
	}
}
