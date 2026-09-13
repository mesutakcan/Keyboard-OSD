; Trimmed version of https://github.com/buliasz/AHKv2-Gdip
; Only keeps what Keyboard OSD uses: layered window updates, GDI+ text
; measuring, and converting a GDI+ bitmap into a Windows HBITMAP.

#Requires AutoHotKey v2.0

CreateRect(&Rect, x, y, w, h)
{
	Rect := Buffer(16)
	NumPut("UInt", x, "UInt", y, "UInt", w, "UInt", h, Rect)
}

WinGetRect(hwnd, &x := "", &y := "", &w := "", &h := "") {
	CreateRect(&winRect, 0, 0, 0, 0)
	DllCall("GetWindowRect", "Ptr", hwnd, "Ptr", winRect)
	x := NumGet(winRect, 0, "UInt")
	y := NumGet(winRect, 4, "UInt")
	w := NumGet(winRect, 8, "UInt") - x
	h := NumGet(winRect, 12, "UInt") - y
}

UpdateLayeredWindow(hwnd, hdc, x := "", y := "", w := "", h := "", Alpha := 255)
{
	if ((x != "") && (y != "")) {
		pt := Buffer(8)
		NumPut("UInt", x, "UInt", y, pt)
	}

	if (w = "") || (h = "") {
		WinGetRect(hwnd, , , &w, &h)
	}

	return DllCall("UpdateLayeredWindow"
		, "UPtr", hwnd
		, "UPtr", 0
		, "UPtr", ((x = "") && (y = "")) ? 0 : pt.Ptr
		, "Int64*", w | h << 32
		, "UPtr", hdc
		, "Int64*", 0
		, "UInt", 0
		, "UInt*", Alpha << 16 | 1 << 24
		, "UInt", 2)
}

Gdip_MeasureString(pGraphics, sString, hFont, hFormat, &RectF)
{
	RC := Buffer(16)
	DllCall("gdiplus\GdipMeasureString"
		, "UPtr", pGraphics
		, "UPtr", StrPtr(sString)
		, "Int", -1
		, "UPtr", hFont
		, "UPtr", RectF.Ptr
		, "UPtr", hFormat
		, "UPtr", RC.Ptr
		, "uint*", &Chars := 0
		, "uint*", &Lines := 0)

	return RC.Ptr ? NumGet(RC, 0, "Float") "|" NumGet(RC, 4, "Float") "|" NumGet(RC, 8, "Float") "|" NumGet(RC, 12, "Float") "|" Chars "|" Lines : 0
}

Gdip_CreateARGBHBITMAPFromBitmap(&pBitmap) {
	DllCall("gdiplus\GdipGetImageWidth", "ptr", pBitmap, "uint*", &width := 0)
	DllCall("gdiplus\GdipGetImageHeight", "ptr", pBitmap, "uint*", &height := 0)

	hdc := DllCall("CreateCompatibleDC", "ptr", 0, "ptr")
	bi := Buffer(40, 0)
	NumPut(
		"UInt", 40,
		"UInt", width,
		"Int", -height,
		"ushort", 1,
		"ushort", 32,
		bi)
	hbm := DllCall("CreateDIBSection", "ptr", hdc, "ptr", bi.Ptr, "UInt", 0, "ptr*", &pBits := 0, "ptr", 0, "UInt", 0, "ptr")
	obm := DllCall("SelectObject", "ptr", hdc, "ptr", hbm, "ptr")

	Rect := Buffer(16, 0)
	NumPut(
		"UInt", width,
		"UInt", height,
		Rect, 8)
	BitmapData := Buffer(16 + 2 * A_PtrSize, 0)
	NumPut(
		"UInt", width,
		"UInt", height,
		"Int", 4 * width,
		"Int", 0xE200B,
		"ptr", pBits,
		BitmapData)
	DllCall("gdiplus\GdipBitmapLockBits"
		, "ptr", pBitmap
		, "ptr", Rect.Ptr
		, "UInt", 5
		, "Int", 0xE200B
		, "ptr", BitmapData.Ptr)
	DllCall("gdiplus\GdipBitmapUnlockBits", "ptr", pBitmap, "ptr", BitmapData.Ptr)

	DllCall("SelectObject", "ptr", hdc, "ptr", obm)
	DllCall("DeleteDC", "ptr", hdc)

	return hbm
}