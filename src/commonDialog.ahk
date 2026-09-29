#Requires AutoHotkey v2.0
/*
==============================================================================
CommonDialog.ahk
Windows Standard Common Dialog Wrappers for AutoHotkey v2
==============================================================================
Description: Clean, robust, 32-bit & 64-bit compatible AutoHotkey v2 wrappers
for Windows Common Dialogs:
	- FontDialog      (ChooseFontW)
	- ColorDialog     (ChooseColorW)
==============================================================================
Author:      Mesut Akcan
Version:     1.0.0 (2026.09.14)
Repository:  https://github.com/mesutakcan/CommonDialog-ahk
==============================================================================
*/

class FontDialog {

	static Choose(hwndOwner, &fontName, &fontSize, &bold, &italic, &underline, &strikeout, &color, &charSet := 1, effects := true) {
		static LOGFONT_SIZE := 92
		static CF_SIZE_32 := 64
		static CF_SIZE_64 := 104
		CF_SIZE := A_PtrSize = 8 ? CF_SIZE_64 : CF_SIZE_32

		LF := Buffer(LOGFONT_SIZE, 0)
		CF := Buffer(CF_SIZE, 0)

		if (fontSize > 0)
			NumPut("Int", -Round(fontSize * A_ScreenDPI / 72), LF, 0)
		NumPut("Int", bold ? 700 : 400, LF, 16)
		NumPut("UChar", italic ? 1 : 0, LF, 20)
		NumPut("UChar", underline ? 1 : 0, LF, 21)
		NumPut("UChar", strikeout ? 1 : 0, LF, 22)
		NumPut("UChar", charSet, LF, 23)
		if (fontName != "")
			StrPut(fontName, LF.Ptr + 28, 32, "UTF-16")

		NumPut("UInt", CF_SIZE, CF, 0)
		NumPut("Ptr", hwndOwner, CF, A_PtrSize)
		NumPut("Ptr", LF.Ptr, CF, A_PtrSize * 3)
		flags := 0x41 | (effects ? 0x100 : 0)
		NumPut("UInt", flags, CF, A_PtrSize * 4 + 4)

		initColorBGR := 0
		if (color != "") {
			colorInt := IsInteger(color) ? color : Integer("0x" color)
			initColorBGR := ColorDialog._RGBtoBGR(colorInt)
		}
		NumPut("UInt", initColorBGR, CF, A_PtrSize * 4 + 8)

		if !DllCall("comdlg32\ChooseFontW", "Ptr", CF.Ptr)
			return false

		iPointSize := NumGet(CF, A_PtrSize * 4, "Int")
		if (iPointSize > 0)
			fontSize := Max(6, Min(200, Round(iPointSize / 10)))
		else {
			h := NumGet(LF, 0, "Int")
			fontSize := Max(6, Min(200, Abs(Round(h * 72 / A_ScreenDPI))))
		}

		fontName := StrGet(LF.Ptr + 28, 32, "UTF-16")
		bold := (NumGet(LF, 16, "Int") >= 700)
		italic := (NumGet(LF, 20, "UChar") != 0)
		underline := (NumGet(LF, 21, "UChar") != 0)
		strikeout := (NumGet(LF, 22, "UChar") != 0)
		charSet := NumGet(LF, 23, "UChar")

		colorBGR := NumGet(CF, A_PtrSize * 4 + 8, "UInt")
		colorRGB := ColorDialog._RGBtoBGR(colorBGR)
		color := Format("{:06X}", colorRGB)

		return true
	}
}

class ColorDialog {

	static Choose(initColor := 0, hwndOwner := 0, &custColors := "", fullOpen := true) {
		static p := A_PtrSize
		flags := fullOpen ? 0x3 : 0x1

		if (!IsObject(custColors))
			custColors := []
		while (custColors.Length < 16)
			custColors.Push(0)
		if (custColors.Length > 16)
			throw Error("custColors: maximum 16 entries allowed.")

		CUSTOM := Buffer(16 * 4, 0)
		loop 16
			NumPut("UInt", ColorDialog._RGBtoBGR(custColors[A_Index]), CUSTOM, (A_Index - 1) * 4)

		CC := Buffer((p = 4) ? 36 : 72, 0)
		NumPut("UInt", CC.Size, CC, 0)
		NumPut("UPtr", hwndOwner, CC, p)
		NumPut("UInt", ColorDialog._RGBtoBGR(initColor), CC, 3 * p)
		NumPut("UPtr", CUSTOM.Ptr, CC, 4 * p)
		NumPut("UInt", flags, CC, 5 * p)

		if !DllCall("comdlg32\ChooseColorW", "UPtr", CC.Ptr, "UInt")
			return -1

		custColors := []
		loop 16
			custColors.Push(ColorDialog._RGBtoBGR(NumGet(CUSTOM, (A_Index - 1) * 4, "UInt")))

		return ColorDialog._RGBtoBGR(NumGet(CC, 3 * p, "UInt"))
	}

	static _RGBtoBGR(c) {
		return ((c & 0xFF) << 16) | (c & 0xFF00) | ((c >> 16) & 0xFF)
	}
}