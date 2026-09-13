#Requires AutoHotkey v2

GetMeasureFont(fontName, fontSize, bold := true, italic := false) {
	global TextMeasureFontCache, TextMeasureFontHDC
	if !TextMeasureFontHDC
		TextMeasureFontHDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")

	cacheKey := fontName "|" fontSize "|" bold "|" italic
	if !TextMeasureFontCache.Has(cacheKey) {
		lf := Buffer(92, 0)
		NumPut("Int", -Round(fontSize * A_ScreenDPI / 72), lf, 0)
		NumPut("Int", bold ? 700 : 400, lf, 16)
		NumPut("UChar", italic ? 1 : 0, lf, 20)
		NumPut("UChar", 0, lf, 23)
		StrPut(fontName, lf.Ptr + 28, 32, "UTF-16")
		TextMeasureFontCache[cacheKey] := DllCall("CreateFontIndirectW", "Ptr", lf, "Ptr")
	}

	return { hDC: TextMeasureFontHDC, hFont: TextMeasureFontCache[cacheKey] }
}

MeasureTextWidthGdip(text, fontName, fontSize, bold := true, italic := false) {
	global GdipFontCache
	pBitmap := 0, pGraphics := 0, pFormat := 0
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 1, "Int", 1, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
	DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
	fontObj := GetGdipFont(fontName, fontSize, bold, italic)
	DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &pFormat)
	DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", pFormat, "Int", 0)
	DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", pFormat, "Int", 0)
	DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", pFormat, "Int", 0x1000 | 0x4000 | 0x800)
	rect := Buffer(16, 0)
	NumPut("Float", 0, rect, 0)
	NumPut("Float", 0, rect, 4)
	NumPut("Float", 10000, rect, 8)
	NumPut("Float", 1000, rect, 12)
	measured := Gdip_MeasureString(pGraphics, text, fontObj.font, pFormat, &rect)
	parts := StrSplit(measured, "|")
	width := (parts.Length >= 3) ? Ceil(Number(parts[3])) : 0
	DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", pFormat)
	DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
	DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)
	return width
}

HistTextScale() {
	global osd
	return osd.FontSize > 0 ? osd.HistFontSize / osd.FontSize : 1
}

HistBadgeScale() {
	global osd
	specialLh := MeasureTextHeight(osd.SpecialFontName, osd.SpecialFontSize, osd.SpecialFontBold, osd.SpecialFontItalic)
		+ 2 * (osd.SpecialBorderWidth + osd.SpecialTextPadY)
	return specialLh > 0 ? osd.HistLineHeight / specialLh : 1
}

MeasureSpecialBadgeWidth(text, isHistory := false) {
	global osd
	if (isHistory) {
		scale := HistBadgeScale()
		histBorderW := osd.SpecialBorderWidth = 0 ? 0 : Max(1, Round(osd.SpecialBorderWidth * scale))
		return MeasureTextWidthGdip(text, osd.SpecialFontName, osd.SpecialFontSize * scale, osd.SpecialFontBold, osd.SpecialFontItalic)
			+ 2 * (Max(0, Round(osd.SpecialTextPadX * scale)) + histBorderW)
	}
	return MeasureTextWidthGdip(text, osd.SpecialFontName, osd.SpecialFontSize, osd.SpecialFontBold, osd.SpecialFontItalic)
		+ 2 * (osd.SpecialTextPadX + osd.SpecialBorderWidth)
}

SpecialRowWidth(segments, isHistory := false) {
	global osd
	gap := isHistory ? Round(osd.SpecialGap * HistBadgeScale()) : osd.SpecialGap
	total := 0
	for i, seg in segments {
		total += MeasureSpecialBadgeWidth(seg.Text, isHistory)
		if (i > 1)
			total += gap
	}
	return total
}

MeasureTextHeight(fontName, fontSize, bold := true, italic := false) {
	fontData := GetMeasureFont(fontName, fontSize, bold, italic)
	hOld := DllCall("SelectObject", "Ptr", fontData.hDC, "Ptr", fontData.hFont, "Ptr")
	size := Buffer(8, 0)
	testText := "WgqyÂ|"
	DllCall("GetTextExtentPoint32W", "Ptr", fontData.hDC, "Str", testText, "Int", StrLen(testText), "Ptr", size)
	DllCall("SelectObject", "Ptr", fontData.hDC, "Ptr", hOld)
	return NumGet(size, 4, "Int")
}

GetGdipFont(fontName, fontSize, bold, italic) {
	global GdipFontCache
	key := fontName "|" fontSize "|" bold "|" italic
	if !GdipFontCache.Has(key) {
		pFamily := 0, pFont := 0
		DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", fontName, "Ptr", 0, "Ptr*", &pFamily)
		style := (bold ? 1 : 0) | (italic ? 2 : 0)
		emSizePx := fontSize * A_ScreenDPI / 72
		DllCall("gdiplus\GdipCreateFont", "Ptr", pFamily, "Float", emSizePx, "Int", style, "Int", 2, "Ptr*", &pFont)
		GdipFontCache[key] := { family: pFamily, font: pFont }
	}
	return GdipFontCache[key]
}

IsFontAvailable(fontName) {
	pFamily := 0
	status := DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", fontName, "Ptr", 0, "Ptr*", &pFamily)
	if (status != 0 || !pFamily)
		return false
	DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", pFamily)
	return true
}

ClearGdipFontCache(*) {
	global GdipFontCache
	for , entry in GdipFontCache {
		DllCall("gdiplus\GdipDeleteFont", "Ptr", entry.font)
		DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", entry.family)
	}
	GdipFontCache.Clear()
}

ClearMeasureTextWidthCache(*) {
	global TextMeasureFontCache, TextMeasureFontHDC
	for , hFont in TextMeasureFontCache {
		if hFont
			DllCall("DeleteObject", "Ptr", hFont)
	}
	TextMeasureFontCache.Clear()

	if TextMeasureFontHDC {
		DllCall("DeleteDC", "Ptr", TextMeasureFontHDC)
		TextMeasureFontHDC := 0
	}
}

GetActiveMonitorBounds() {
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

CalcStackBase(mon, totalH, winW := 0) {
	global osd
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
		case "Center":
			return [mX + (mW - winW) // 2, mY + (mH - totalH) // 2]
		default:
			return [mX + mW - winW - osd.MarginX,
				mY + mH - osd.MarginY - totalH]
	}
}

InitWin(idx) {
	global RowReady
	RowReady[idx] := true
}

global GdipToken := 0

InitGdiplus() {
	global GdipToken
	if GdipToken
		return
	si := Buffer(24, 0)
	NumPut("UInt", 1, si, 0)
	DllCall("gdiplus\GdiplusStartup", "Ptr*", &GdipToken, "Ptr", si, "Ptr", 0)
}

ShutdownGdiplus(*) {
	global GdipToken
	if GdipToken {
		try DllCall("gdiplus\GdiplusShutdown", "Ptr", GdipToken)
		GdipToken := 0
	}
}

ClearBadgeCache(*) {
	global RowBitmaps
	for winIdx, hBmp in RowBitmaps
		if hBmp
			DllCall("DeleteObject", "Ptr", hBmp)
	RowBitmaps.Clear()
}

_SafeHex(hex) {
	clean := RegExReplace(hex, "[^0-9A-Fa-f]")
	if (StrLen(clean) > 6)
		clean := SubStr(clean, 1, 6)
	loop 6 - StrLen(clean)
		clean := "0" clean
	return StrUpper(clean)
}

AddRoundedRectPath(pPath, x, y, w, h, d) {
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x + w - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x + w - d, "Float", y + h - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x, "Float", y + h - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
	DllCall("gdiplus\GdipClosePathFigure", "Ptr", pPath)
}

FillRoundedRect(pGraphics, x, y, w, h, d, argbColor) {
	pPath := 0, pBrush := 0
	DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pPath)
	AddRoundedRectPath(pPath, x, y, w, h, d)
	DllCall("gdiplus\GdipCreateSolidFill", "UInt", argbColor, "Ptr*", &pBrush)
	DllCall("gdiplus\GdipFillPath", "Ptr", pGraphics, "Ptr", pBrush, "Ptr", pPath)
	DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
	DllCall("gdiplus\GdipDeletePath", "Ptr", pPath)
}
UpdateLayeredBitmap(hwnd, hBitmap, x, y, w, h, alpha := 255) {
	if (!hBitmap)
		return
	hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
	old := DllCall("SelectObject", "Ptr", hdc, "Ptr", hBitmap, "Ptr")
	if (w <= 0 || h <= 0)
		UpdateLayeredWindow(hwnd, hdc, , , , , alpha)
	else
		UpdateLayeredWindow(hwnd, hdc, x, y, w, h, alpha)
	DllCall("SelectObject", "Ptr", hdc, "Ptr", old, "Ptr")
	DllCall("DeleteDC", "Ptr", hdc)
}

MakeCombinedSpecialBadgeBitmap(segments, h, totalW, isHistory := false) {
	global osd, SPECIAL_OUTER_RADIUS

	pBitmap := 0, pGraphics := 0
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", totalW, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
	DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
	DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
	DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", pGraphics, "Int", 4)
	DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00000000)

	argbBorder := HexToARGB(osd.SpecialBorderColor, 255)
	argbBg := HexToARGB(osd.SpecialBgColor, 255)
	textColor := osd.SpecialTextColor

	fontName := osd.SpecialFontName
	scale := isHistory ? HistBadgeScale() : 1
	fontSize := osd.SpecialFontSize * scale
	fontBold := osd.SpecialFontBold
	fontItalic := osd.SpecialFontItalic
	borderW := isHistory ? (osd.SpecialBorderWidth = 0 ? 0 : Max(1, Round(osd.SpecialBorderWidth * scale))) : osd.SpecialBorderWidth
	gap := isHistory ? Round(osd.SpecialGap * scale) : osd.SpecialGap
	textYNudge := osd.SpecialTextYNudge * scale

	fontObj := GetGdipFont(fontName, fontSize, fontBold, fontItalic)
	pFont := fontObj.font

	pFormat := 0, pTextBrush := 0
	static sharedFormat := 0
	if (!sharedFormat) {
		DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &sharedFormat)
		DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", sharedFormat, "Int", 1)
		DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", sharedFormat, "Int", 1)
	}
	pFormat := sharedFormat
	DllCall("gdiplus\GdipCreateSolidFill", "UInt", HexToARGB(textColor, 255), "Ptr*", &pTextBrush)

	x := 0
	for seg in segments {
		w := MeasureSpecialBadgeWidth(seg.Text, isHistory)
		outerRadius := Min(Round(SPECIAL_OUTER_RADIUS * scale), Floor(Min(w, h) / 2))
		innerW := Max(0, w - 2 * borderW)
		innerH := Max(0, h - 2 * borderW)
		innerRadius := Min(Max(0, outerRadius - borderW), Floor(Min(innerW, innerH) / 2))

		if (borderW > 0)
			FillRoundedRect(pGraphics, x, 0, w, h, outerRadius * 2, argbBorder)
		if (innerW > 0 && innerH > 0)
			FillRoundedRect(pGraphics, x + borderW, borderW, innerW, innerH, innerRadius * 2, argbBg)

		rect := Buffer(16, 0)
		NumPut("Float", x, rect, 0)
		NumPut("Float", textYNudge, rect, 4)
		NumPut("Float", w, rect, 8)
		NumPut("Float", h, rect, 12)
		DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "WStr", seg.Text, "Int", -1,
			"Ptr", pFont, "Ptr", rect, "Ptr", pFormat, "Ptr", pTextBrush)

		x += w + gap
	}

	DllCall("gdiplus\GdipDeleteBrush", "Ptr", pTextBrush)

	hBmp := Gdip_CreateARGBHBITMAPFromBitmap(&pBitmap)

	DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
	DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

	return hBmp
}

MakeTextRowBitmap(text, h, w, isActive, padX, padY) {
	global osd, SPECIAL_OUTER_RADIUS

	pBitmap := 0, pGraphics := 0
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
	DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
	DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)
	DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", pGraphics, "Int", 4)
	DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00000000)

	bgHex := isActive ? osd.BgColor : osd.HistBgColor
	radius := Min(SPECIAL_OUTER_RADIUS, Floor(Min(w, h) / 2))
	FillRoundedRect(pGraphics, 0, 0, w, h, radius * 2, HexToARGB(bgHex, 255))

	fontName := osd.FontName
	fontSize := isActive ? osd.FontSize : osd.HistFontSize
	fontBold := osd.FontBold
	fontItalic := osd.FontItalic
	textHex := isActive ? osd.TextColor : osd.HistTextColor

	fontObj := GetGdipFont(fontName, fontSize, fontBold, fontItalic)
	pFont := fontObj.font

	pFormat := 0, pTextBrush := 0
	static sharedFormat := 0
	if (!sharedFormat) {
		DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &sharedFormat)
		DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", sharedFormat, "Int", 0)
		DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", sharedFormat, "Int", 0)
		DllCall("gdiplus\GdipSetStringFormatFlags", "Ptr", sharedFormat, "Int", 0x1000 | 0x4000)
	}
	pFormat := sharedFormat
	DllCall("gdiplus\GdipCreateSolidFill", "UInt", HexToARGB(textHex, 255), "Ptr*", &pTextBrush)

	rect := Buffer(16, 0)
	NumPut("Float", padX, rect, 0)
	NumPut("Float", padY, rect, 4)
	NumPut("Float", w - padX, rect, 8)
	NumPut("Float", h - 2 * padY, rect, 12)
	DllCall("gdiplus\GdipDrawString", "Ptr", pGraphics, "WStr", text, "Int", -1,
		"Ptr", pFont, "Ptr", rect, "Ptr", pFormat, "Ptr", pTextBrush)

	DllCall("gdiplus\GdipDeleteBrush", "Ptr", pTextBrush)

	hBmp := Gdip_CreateARGBHBITMAPFromBitmap(&pBitmap)

	DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
	DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

	return hBmp
}

HexToARGB(hex, alpha := 255) {
	hex := _SafeHex(RegExReplace(hex, "[^0-9A-Fa-f]"))
	rr := Integer("0x" SubStr(hex, 1, 2))
	gg := Integer("0x" SubStr(hex, 3, 2))
	bb := Integer("0x" SubStr(hex, 5, 2))
	return ((alpha & 0xFF) << 24) | (rr << 16) | (gg << 8) | bb
}

HideOSDInstant() {
	global RowWins, osd
	CancelAllFades()
	SetTimer(CheckExpiredLines, 0)
	CancelPendingModTimer()

	loop osd.MaxLines
		RowWins[A_Index].Hide()

	ResetOSDState()
}

RenderOSD(extraLine := "", forceRedraw := false) {
	global RowWins, RowReady, osd, CachedMaxWidth, FadingStates, FadeAlphas, CHAR_WIDTH_RATIO, RowBitmaps

	static lastMonW := 0
	static lastOsdWidth := 0
	mon := GetActiveMonitorBounds()

	if (mon["w"] != lastMonW || osd.Width != lastOsdWidth) {
		lastMonW := mon["w"]
		lastOsdWidth := osd.Width
		CachedMaxWidth := Min(osd.Width, Round(mon["w"] * 0.75))
	}
	OSD_MaxWidth := CachedMaxWidth

	if (osd.State.Lines.Length > 0 || extraLine != "")
		SetTimer(CheckExpiredLines, 100)

	allLines := []
	allSpecial := []
	allSegments := []
	for ln in osd.State.Lines {
		allLines.Push(ln.DisplayText())
		allSpecial.Push(ln.IsSpecial)
		allSegments.Push(ln.Segments)
	}
	if (extraLine != "") {
		allLines.Push(extraLine)
		allSpecial.Push(false)
		allSegments.Push("")
	}

	if (allLines.Length = 0) {
		osd.State.LastKey := ""
		osd.State.TypingBuf := ""

		loop osd.MaxLines {
			if (!FadingStates[A_Index])
				RowWins[A_Index].Hide()
		}
		return
	}

	start := Max(1, allLines.Length - osd.MaxLines + 1)
	visLines := []
	visSpecial := []
	visSegments := []
	loop (allLines.Length - start + 1) {
		visLines.Push(allLines[start + A_Index - 1])
		visSpecial.Push(allSpecial[start + A_Index - 1])
		visSegments.Push(allSegments[start + A_Index - 1])
	}

	total := visLines.Length
	activeIdx := total

	specialLh := MeasureTextHeight(osd.SpecialFontName, osd.SpecialFontSize, osd.SpecialFontBold, osd.SpecialFontItalic)
		+ 2 * (osd.SpecialBorderWidth + osd.SpecialTextPadY)
	histBadgeLh := osd.HistLineHeight

	IsPlaceholderIdx(i) => (visLines[i] = "" && !visSpecial[i])

	rowHeights := []
	loop total {
		li := A_Index
		if (IsPlaceholderIdx(li)) {
			rowHeights.Push(osd.LineHeight)
			continue
		}
		isAct := (li = activeIdx)
		isSpecHist := !isAct && visSpecial[li]
		rowHeights.Push(isAct && visSpecial[li] ? specialLh : (isSpecHist ? histBadgeLh : (isAct ? osd.LineHeight : osd.HistLineHeight)))
	}

	totalH := 0
	loop total {
		if (rowHeights[A_Index] = 0)
			continue
		if (totalH > 0)
			totalH += osd.LineGap
		totalH += rowHeights[A_Index]
	}

	widths := []

	if (!osd.AutoWidth) {
		defaultW := Min(osd.Width, OSD_MaxWidth)
		loop total
			widths.Push(defaultW)
	} else {
		loop total {
			idx := A_Index
			if (IsPlaceholderIdx(idx)) {
				widths.Push(0)
				continue
			}
			isAct := (idx = activeIdx)
			isSpecHist := !isAct && visSpecial[idx]
			isSpec := (isAct && visSpecial[idx]) || isSpecHist
			if (isSpec) {
				widths.Push(SpecialRowWidth(visSegments[idx], isSpecHist))
				continue
			}
			if (isAct)
				fs := osd.FontSize, pad := osd.TextPadX
			else
				fs := osd.HistFontSize, pad := Round(osd.TextPadX * HistTextScale())
			tw := MeasureTextWidthGdip(visLines[idx], osd.FontName, fs, osd.FontBold, osd.FontItalic)
			tw += pad * 2 + 1
			widths.Push(Min(tw, OSD_MaxWidth))
		}
	}

	if (osd.AutoWidth)
		osd.MaxTyping := Max(10, Floor((OSD_MaxWidth - osd.TextPadX * 2) / (osd.FontSize * CHAR_WIDTH_RATIO)))

	baseY := CalcStackBase(mon, totalH)[2]

	EnsureWindowCapacity(total)

	yOffset := 0
	winIdx := 1

	loop total {
		idx := A_Index
		if (IsPlaceholderIdx(idx))
			continue

		while (winIdx <= osd.MaxLines && FadingStates[winIdx])
			winIdx++
		if (winIdx > osd.MaxLines)
			break

		isActive := (idx = activeIdx)
		isSpecial := isActive && visSpecial[idx]
		isSpecialHist := !isActive && visSpecial[idx]
		isSpecialBadge := isSpecial || isSpecialHist
		lh := rowHeights[idx]
		alpha := isSpecial ? osd.SpecialAlpha : (isActive ? osd.BgAlpha : osd.HistAlpha)

		w := RowWins[winIdx]

		static lastGeom := Map()
		static lastAlpha := Map()
		static lastContent := Map()

		rowW := widths[idx]
		rowBaseX := CalcStackBase(mon, totalH, rowW)[1]
		rowY := baseY + yOffset
		geomKey := rowBaseX "," rowY "," rowW "," lh

		contentKey := isSpecialBadge ? (isSpecialHist ? "history|" : "active|") : (isActive ? "text|" : "hist|")
		if (isSpecialBadge) {
			for seg in visSegments[idx]
				contentKey .= seg.Text "|" seg.Count ";"
		} else {
			contentKey .= visLines[idx]
		}

		geomChanged := forceRedraw || (!lastGeom.Has(winIdx) || lastGeom[winIdx] != geomKey)
		contentChanged := forceRedraw || (!lastContent.Has(winIdx) || lastContent[winIdx] != contentKey)
		visible := DllCall("IsWindowVisible", "Ptr", w.Hwnd)

		if (contentChanged || geomChanged) {
			hBmp := isSpecialBadge
				? MakeCombinedSpecialBadgeBitmap(visSegments[idx], lh, rowW, isSpecialHist)
				: MakeTextRowBitmap(visLines[idx], lh, rowW, isActive, isActive ? osd.TextPadX : Round(osd.TextPadX * HistTextScale()), isActive ? osd.TextPadY : Round(osd.TextPadY * HistTextScale()))
			if (RowBitmaps.Has(winIdx) && RowBitmaps[winIdx])
				DllCall("DeleteObject", "Ptr", RowBitmaps[winIdx])
			RowBitmaps[winIdx] := hBmp
		}
		if !visible
			w.Show("NA x" rowBaseX " y" rowY " w" rowW " h" lh)
		if (contentChanged || geomChanged || !visible || !lastAlpha.Has(winIdx) || lastAlpha[winIdx] != alpha)
			UpdateLayeredBitmap(w.Hwnd, RowBitmaps[winIdx], rowBaseX, rowY, rowW, lh, alpha)

		lastGeom[winIdx] := geomKey
		lastContent[winIdx] := contentKey
		lastAlpha[winIdx] := alpha
		FadeAlphas[winIdx] := alpha

		if !RowReady[winIdx]
			InitWin(winIdx)

		yOffset += lh + osd.LineGap
		winIdx++
	}

	loop (osd.MaxLines - winIdx + 1) {
		i := winIdx + A_Index - 1
		if (!FadingStates[i])
			RowWins[i].Hide()
	}
}

PushLine(line, isSpecial := false) {
	global osd

	if (Trim(line) = "")
		return

	osd.State.Lines.Push(OSDLine(line, isSpecial))
	while (osd.State.Lines.Length > osd.MaxLines)
		osd.State.Lines.RemoveAt(1)
	SetTimer(CheckExpiredLines, 100)
}

PushEmptyActivePlaceholder() {
	global osd
	osd.State.Lines.Push(OSDLine("", false))
	while (osd.State.Lines.Length > osd.MaxLines)
		osd.State.Lines.RemoveAt(1)
}

PruneTrailingPlaceholder() {
	global osd
	if (osd.State.Lines.Length > 0) {
		last := osd.State.Lines[osd.State.Lines.Length]
		if (last.DisplayText() = "" && !last.IsSpecial)
			osd.State.Lines.Pop()
	}
}

ScheduleTypingTimeout() {
	global osd
	if osd.State.TypingTimer
		SetTimer(osd.State.TypingTimer, 0)
	osd.State.TypingSerial += 1
	serial := osd.State.TypingSerial
	osd.State.TypingTimer := FlushTypingTimeout.Bind(serial)
	SetTimer(osd.State.TypingTimer, -osd.DisplayTime)
}

FlushTyping(isTimeout := false) {
	global osd
	if osd.State.TypingTimer
		SetTimer(osd.State.TypingTimer, 0)
	osd.State.TypingTimer := 0

	if (osd.State.TypingBuf = "")
		return

	line := osd.State.TypingBuf
	osd.State.TypingBuf := ""
	osd.State.LastKey := ""

	if (isTimeout) {
		FadeLastVisibleRow()
		PromoteNextActiveLine()
		RenderOSD()
		return
	}

	PushLine(line)
	RenderOSD()
}

FlushTypingTimeout(serial) {
	global osd
	if (serial != osd.State.TypingSerial)
		return
	osd.State.TypingTimer := 0
	FlushTyping(true)
}

WrapTypingBuffer(nextText) {
	global osd
	candidate := osd.State.TypingBuf . nextText
	breakAt := FindLastWordBreak(candidate)
	if (breakAt > 1) {
		line := RTrim(SubStr(candidate, 1, breakAt - 1))
		rest := LTrim(SubStr(candidate, breakAt + 1))
		if (line != "")
			PushLine(line)
		osd.State.TypingBuf := rest
		return
	}
	FlushTyping()
	osd.State.TypingBuf := nextText
}

StartFade(winIdx) {
	global RowWins, FadingStates, FadeTimers
	if (FadingStates[winIdx])
		return
	if (!DllCall("IsWindowVisible", "Ptr", RowWins[winIdx].Hwnd))
		return

	FadingStates[winIdx] := true
	FadeTimers[winIdx] := FadeStep.Bind(winIdx)
	SetTimer(FadeTimers[winIdx], 16)
}

FadeStep(winIdx) {
	global RowWins, FadingStates, FadeTimers, FadeAlphas, RowBitmaps
	if (!FadingStates[winIdx])
		return
	FadeAlphas[winIdx] -= 8

	if (FadeAlphas[winIdx] <= 0) {
		SetTimer(FadeTimers[winIdx], 0)
		FadeTimers[winIdx] := 0
		RowWins[winIdx].Hide()
		FadingStates[winIdx] := false
		return
	}
	UpdateLayeredBitmap(RowWins[winIdx].Hwnd, RowBitmaps[winIdx], 0, 0, 0, 0, FadeAlphas[winIdx])
}

CancelAllFades() {
	global RowWins, FadingStates, FadeTimers

	loop osd.MaxLines {
		idx := A_Index
		if (FadingStates[idx]) {
			SetTimer(FadeTimers[idx], 0)
			FadeTimers[idx] := 0
			RowWins[idx].Hide()
			FadingStates[idx] := false
		}
	}
}

EnsureWindowCapacity(neededCount) {
	global RowWins, FadingStates, FadeTimers

	freeCount := 0
	loop osd.MaxLines
		if !FadingStates[A_Index]
			freeCount++

	shortfall := neededCount - freeCount
	if (shortfall <= 0)
		return

	loop osd.MaxLines {
		if (shortfall <= 0)
			break
		idx := A_Index
		if (FadingStates[idx]) {
			SetTimer(FadeTimers[idx], 0)
			FadeTimers[idx] := 0
			RowWins[idx].Hide()
			FadingStates[idx] := false
			shortfall--
		}
	}
}

CheckExpiredLines() {
	global osd, RowWins, FadingStates

	if (osd.State.Lines.Length = 0) {
		SetTimer(CheckExpiredLines, 0)
		return
	}

	visibleCount := osd.State.Lines.Length
	lastLine := osd.State.Lines[visibleCount]
	lastIsPlaceholder := (lastLine.DisplayText() = "" && !lastLine.IsSpecial)
	lastIsActive := (osd.State.TypingBuf = "") && !lastIsPlaceholder

	if (lastIsActive) {
		if (lastLine.IsActiveExpired(osd.DisplayTime)) {
			FadeLastVisibleRow()
			osd.State.Lines.RemoveAt(visibleCount)
			PromoteNextActiveLine()
		RenderOSD()
		return
		}
	}

	historyCount := lastIsActive ? visibleCount - 1 : visibleCount
	loop historyCount {
		idx := A_Index
		ln := osd.State.Lines[idx]
		if (ln.DisplayText() = "" && !ln.IsSpecial)
			continue
		if (ln.IsExpired(osd.DismissDelay)) {
			FadeFirstVisibleRow()
			osd.State.Lines.RemoveAt(idx)
		RenderOSD(osd.State.TypingBuf)
		return
		}
	}
}

PromoteNextActiveLine() {
	global osd
	if (osd.State.Lines.Length > 0) {
		promoted := osd.State.Lines[osd.State.Lines.Length]
		promoted.CreatedAt := A_TickCount
		promoted.ActiveSince := A_TickCount
	}
}

FadeFirstVisibleRow() {
	global RowWins, FadingStates
	loop RowWins.Length {
		i := A_Index
		if (DllCall("IsWindowVisible", "Ptr", RowWins[i].Hwnd) && !FadingStates[i]) {
			StartFade(i)
			return
		}
	}
}

FadeLastVisibleRow() {
	global RowWins, FadingStates
	loop RowWins.Length {
		i := RowWins.Length - A_Index + 1
		if (DllCall("IsWindowVisible", "Ptr", RowWins[i].Hwnd) && !FadingStates[i]) {
			StartFade(i)
			return
		}
	}
}

ResetOSDState() {
	global osd
	CancelAllFades()
	SetTimer(CheckExpiredLines, 0)
	if osd.State.TypingTimer
		SetTimer(osd.State.TypingTimer, 0)
	osd.State.TypingTimer := 0
	osd.State.TypingSerial += 1
	CancelPendingModTimer()
	osd.State.LastKey := ""
	osd.State.Lines := []
	osd.State.TypingBuf := ""
	osd.State.PendingMod := ""
	osd.State.PendingModSerial++
	osd.State.PendingComposeTap := ""
}

IsOSDVisible() {
	global RowWins
	loop RowWins.Length {
		if DllCall("IsWindowVisible", "Ptr", RowWins[A_Index].Hwnd)
			return true
	}
	return false
}