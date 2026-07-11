#Requires AutoHotkey v2

VKtoChar(vk) {
	static kbState := Buffer(256, 0)
	static outBuf := Buffer(8, 0)
	static modVKs := [0x10, 0x11, 0x12,
		0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5,
		0x14, 0x90, 0x91]

	DllCall("kernel32\RtlZeroMemory", "Ptr", kbState.Ptr, "UPtr", kbState.Size)
	DllCall("kernel32\RtlZeroMemory", "Ptr", outBuf.Ptr, "UPtr", outBuf.Size)

	for m in modVKs {
		if (DllCall("GetAsyncKeyState", "UShort", m, "Short") & 0x8000)
			NumPut("UChar", 0x80, kbState, m)
	}

	for m in [0x14, 0x90, 0x91] {
		if (DllCall("GetKeyState", "UShort", m, "Short") & 0x0001)
			NumPut("UChar", NumGet(kbState, m, "UChar") | 0x01, kbState, m)
	}
	hkl := DllCall("GetKeyboardLayout", "UInt", 0, "Ptr")
	scanCode := DllCall("MapVirtualKeyEx", "UInt", vk, "UInt", 0, "Ptr", hkl, "UInt")
	ret := DllCall("ToUnicodeEx",
		"UInt", vk, "UInt", scanCode,
		"Ptr", kbState, "Ptr", outBuf,
		"Int", 4, "UInt", 4, "Ptr", hkl, "Int")
	return (ret > 0) ? StrGet(outBuf, ret, "UTF-16") : ""
}

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

	if (ch = "" || Ord(SubStr(ch, 1, 1)) < 0x20) {
		outChar := ""
		return false
	}

	outChar := ch
	return true
}

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

MeasureTextWidth(text, fontName, fontSize, bold := true, italic := false) {
	fontData := GetMeasureFont(fontName, fontSize, bold, italic)
	hOld := DllCall("SelectObject", "Ptr", fontData.hDC, "Ptr", fontData.hFont, "Ptr")
	size := Buffer(8, 0)
	DllCall("GetTextExtentPoint32W", "Ptr", fontData.hDC, "Str", text, "Int", StrLen(text), "Ptr", size)
	DllCall("SelectObject", "Ptr", fontData.hDC, "Ptr", hOld)
	return NumGet(size, 0, "Int")
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
		default:
			return [mX + mW - winW - osd.MarginX,
				mY + mH - osd.MarginY - totalH]
	}
}

ApplyDWMCorners(hwnd) {
	pref := Buffer(4, 0)
	NumPut("Int", osd.CornerRadius ? 2 : 1, pref)
	DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 33, "Ptr", pref, "UInt", 4)

	ncr := Buffer(4, 0)
	NumPut("Int", 1, ncr)
	DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 2, "Ptr", ncr, "UInt", 4)
}

InitWin(idx, alpha) {
	hwnd := RowWins[idx].Hwnd
	curStyle := WinGetExStyle(hwnd)
	WinSetExStyle(curStyle | 0x20, hwnd)
	curClass := DllCall("GetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr")
	if (curClass & 0x20000)
		DllCall("SetClassLongPtr", "Ptr", hwnd, "Int", -26, "Ptr", curClass & ~0x20000)
	WinSetTransparent(alpha, hwnd)
	ApplyDWMCorners(hwnd)
	RowReady[idx] := true
}

FadeOutWin(guiObj, duration := 250) {
	hwnd := guiObj.Hwnd
	if !DllCall("IsWindowVisible", "Ptr", hwnd)
		return

	if (guiObj.HasProp("Fading") && guiObj.Fading)
		return

	guiObj.Fading := true
	origAlpha := 0
	DllCall("GetLayeredWindowAttributes", "Ptr", hwnd, "Ptr", 0, "UChar*", &origAlpha, "Ptr", 0)
	if (origAlpha = 0)
		origAlpha := 255

	steps := 10
	stepMs := Max(1, Round(duration / steps))
	currentStep := 0

	FadeTick() {
		if (!guiObj.HasProp("Fading") || !guiObj.Fading) {
			SetTimer(, 0)
			return
		}

		currentStep++
		if (currentStep <= steps) {
			newAlpha := Round(origAlpha * (steps - currentStep) / steps)
			WinSetTransparent(newAlpha, hwnd)
		} else {
			SetTimer(, 0)
			guiObj.Hide()
			WinSetTransparent(origAlpha, hwnd)
			guiObj.Fading := false
		}
	}

	SetTimer(FadeTick, stepMs)
}

ReadIni(Key, Def, asInt := false, Section := "Appearance") {
	Val := IniRead(IniFile, Section, Key, Def)
	return asInt ? Number(Val) : Val
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

_InRoundRect(px, py, left, top, right, bottom, r) {
	if (px < left || px > right || py < top || py > bottom)
		return false
	if (r <= 0)
		return true
	cx := Max(left + r, Min(px, right - r))
	cy := Max(top + r, Min(py, bottom - r))
	dx := px - cx, dy := py - cy
	return (dx * dx + dy * dy) <= r * r
}

RenderPreviewBadge(picCtrl, w, h, fillHex, alpha, borderHex := "", borderWidth := 0, radius := 0) {
	if (picCtrl.HasProp("_hBmp") && picCtrl._hBmp != 0)
		DllCall("DeleteObject", "Ptr", picCtrl._hBmp)

	fr := Integer("0x" SubStr(fillHex, 1, 2)), fg := Integer("0x" SubStr(fillHex, 3, 2)), fb := Integer("0x" SubStr(fillHex, 5, 2))
	hasBorder := (borderWidth > 0 && borderHex != "")
	if hasBorder
		br := Integer("0x" SubStr(borderHex, 1, 2)), bg := Integer("0x" SubStr(borderHex, 3, 2)), bb := Integer("0x" SubStr(borderHex, 5, 2))
	aa := Number(alpha) & 0xFF
	innerR := Max(0, radius - borderWidth)
	ss := (radius > 0) ? 3 : 1

	hBmp := DllCall("CreateBitmap", "Int", w, "Int", h, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")
	pBuf := Buffer(w * h * 4)
	pPtr := pBuf.Ptr

	Loop h {
		py := A_Index - 1
		rowBase := py * w * 4
		Loop w {
			px := A_Index - 1
			off := rowBase + px * 4
			outerHit := 0, innerHit := 0
			Loop ss {
				sy := py + (A_Index - 0.5) / ss
				Loop ss {
					sx := px + (A_Index - 0.5) / ss
					if _InRoundRect(sx, sy, 0, 0, w - 1, h - 1, radius)
						outerHit++
					if hasBorder && _InRoundRect(sx, sy, borderWidth, borderWidth, w - 1 - borderWidth, h - 1 - borderWidth, innerR)
						innerHit++
				}
			}
			total := ss * ss
			outerCov := outerHit / total
			if (outerCov = 0) {
				NumPut("UChar", 0, pPtr, off + 3)
				continue
			}
			innerCov := hasBorder ? innerHit / total : 1

			rr := hasBorder ? Round(fr * innerCov + br * (1 - innerCov)) : fr
			gg := hasBorder ? Round(fg * innerCov + bg * (1 - innerCov)) : fg
			bbv := hasBorder ? Round(fb * innerCov + bb * (1 - innerCov)) : fb

			NumPut("UChar", bbv, pPtr, off)
			NumPut("UChar", gg, pPtr, off + 1)
			NumPut("UChar", rr, pPtr, off + 2)
			NumPut("UChar", Round(aa * outerCov), pPtr, off + 3)
		}
	}
	DllCall("SetBitmapBits", "Ptr", hBmp, "UInt", w * h * 4, "Ptr", pPtr)
	picCtrl._hBmp := hBmp
	picCtrl.Value := "HBITMAP:*" hBmp
}


BlendHexColor(fgHex, bgHex, alpha) {
	a := Number(alpha) / 255
	fr := Integer("0x" SubStr(fgHex, 1, 2)), fg := Integer("0x" SubStr(fgHex, 3, 2)), fb := Integer("0x" SubStr(fgHex, 5, 2))
	br := Integer("0x" SubStr(bgHex, 1, 2)), bgc := Integer("0x" SubStr(bgHex, 3, 2)), bb := Integer("0x" SubStr(bgHex, 5, 2))
	rr := Round(fr * a + br * (1 - a))
	gg := Round(fg * a + bgc * (1 - a))
	bb2 := Round(fb * a + bb * (1 - a))
	return Format("{:02X}{:02X}{:02X}", rr, gg, bb2)
}

MakeRoundedBadgeBitmap(w, h, borderHex, bgHex, borderWidth, outerRadius) {
	pBitmap := 0, pGraphics := 0, pPath := 0, pBrush := 0
	DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &pBitmap)
	DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pBitmap, "Ptr*", &pGraphics)
	DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 4)

	argbBorder := HexToARGB(borderHex)
	argbBg := HexToARGB(bgHex)

	DllCall("gdiplus\GdipGraphicsClear", "Ptr", pGraphics, "UInt", argbBorder)

	x := borderWidth, y := borderWidth
	iw := w - 2 * borderWidth - 1, ih := h - 2 * borderWidth - 1
	d := Max(0, outerRadius - borderWidth) * 2

	DllCall("gdiplus\GdipCreatePath", "Int", 0, "Ptr*", &pPath)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x, "Float", y, "Float", d, "Float", d, "Float", 180, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x + iw - d, "Float", y, "Float", d, "Float", d, "Float", 270, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x + iw - d, "Float", y + ih - d, "Float", d, "Float", d, "Float", 0, "Float", 90)
	DllCall("gdiplus\GdipAddPathArc", "Ptr", pPath, "Float", x, "Float", y + ih - d, "Float", d, "Float", d, "Float", 90, "Float", 90)
	DllCall("gdiplus\GdipClosePathFigure", "Ptr", pPath)

	DllCall("gdiplus\GdipCreateSolidFill", "UInt", argbBg, "Ptr*", &pBrush)
	DllCall("gdiplus\GdipFillPath", "Ptr", pGraphics, "Ptr", pBrush, "Ptr", pPath)

	DllCall("gdiplus\GdipDeleteBrush", "Ptr", pBrush)
	DllCall("gdiplus\GdipDeletePath", "Ptr", pPath)

	hBmp := 0
	DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", pBitmap, "Ptr*", &hBmp, "UInt", 0xFFFFFF)

	DllCall("gdiplus\GdipDeleteGraphics", "Ptr", pGraphics)
	DllCall("gdiplus\GdipDisposeImage", "Ptr", pBitmap)

	return hBmp
}

HexToARGB(hex) {
	hex := RegExReplace(hex, "[^0-9A-Fa-f]")
	rr := Integer("0x" SubStr(hex, 1, 2))
	gg := Integer("0x" SubStr(hex, 3, 2))
	bb := Integer("0x" SubStr(hex, 5, 2))
	return 0xFF000000 | (rr << 16) | (gg << 8) | bb
}