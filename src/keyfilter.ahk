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

IsPureModifierLabel(label) {
	for tok in StrSplit(label, " + ") {
		if !(tok = "Ctrl" || tok = "Shift" || tok = "Alt" || tok = "Win" || tok = "AltGr")
			return false
	}
	return true
}

ReadIni(Key, Def, asInt := false, Section := "Appearance") {
	Val := IniRead(IniFile, Section, Key, Def)
	return asInt ? Number(Val) : Val
}

ParseKeyCombo(raw) {
	entry := Trim(raw)
	if (entry = "")
		return ""

	mods := Map("Ctrl", false, "Shift", false, "Alt", false, "Win", false, "AltGr", false)

	if (entry = "AltGr") {
		mods["AltGr"] := true
		entry := ""
	} else if (SubStr(entry, 1, 6) = "AltGr+") {
		mods["AltGr"] := true
		entry := SubStr(entry, 7)
	} else {
		loop {
			ch := SubStr(entry, 1, 1)
			if (ch = "^")
				mods["Ctrl"] := true
			else if (ch = "+")
				mods["Shift"] := true
			else if (ch = "!")
				mods["Alt"] := true
			else if (ch = "#")
				mods["Win"] := true
			else
				break
			entry := SubStr(entry, 2)
		}
	}

	if (entry = "")
		return ""

	return { mods: mods, key: entry }
}

LoadExcludedKeys() {
	list := []
	section := ""
	try section := IniRead(IniFile, "ExcludedKeys")
	if (section = "")
		return list

	for line in StrSplit(section, "`n", "`r") {
		line := Trim(line)
		if (line = "")
			continue
		eq := InStr(line, "=")
		val := eq ? SubStr(line, eq + 1) : line
		combo := ParseKeyCombo(val)
		if (combo != "")
			list.Push(combo)
	}
	return list
}

IsKeyExcluded(hasCtrl, hasShift, hasAlt, hasWin, isAltGr, keyName, foundVK := 0) {
	global ExcludedKeyList, SystemExcludedKeyList, osd
	hasShift := !!hasShift
	hasWin := !!hasWin
	curCtrl := hasCtrl && !isAltGr
	curAlt := hasAlt && !isAltGr
	hasAnyMod := (curCtrl || hasShift || curAlt || hasWin || isAltGr)

	if (osd.FilterModifiers && osd.FilterModifierMode = "Group" && hasAnyMod)
		return true

	if IsKeyExcludedByCategory(keyName, foundVK)
		return true

	if IsKeyInList(SystemExcludedKeyList, isAltGr, curCtrl, hasShift, curAlt, hasWin, keyName)
		return true

	if (osd.FilterCustomList && IsKeyInList(ExcludedKeyList, isAltGr, curCtrl, hasShift, curAlt, hasWin, keyName))
		return true

	return false
}

IsKeyInList(list, isAltGr, curCtrl, hasShift, curAlt, hasWin, keyName) {
	for combo in list {
		if (StrLower(combo.key) != StrLower(keyName))
			continue
		m := combo.mods
		if (m["AltGr"] != isAltGr)
			continue
		if (m["Ctrl"] != curCtrl)
			continue
		if (m["Shift"] != hasShift)
			continue
		if (m["Alt"] != curAlt)
			continue
		if (m["Win"] != hasWin)
			continue
		return true
	}
	return false
}

IsKeyExcludedByCategory(keyName, foundVK := 0) {
	global osd

	if (osd.FilterFunctionKeys && RegExMatch(keyName, "^F(1[0-9]|2[0-4]|[1-9])$"))
		return true

	if (osd.FilterNumpad && (SubStr(keyName, 1, 6) = "Numpad" || keyName = "NumLock"))
		return true

	if (osd.FilterLetters && foundVK >= 0x41 && foundVK <= 0x5A)
		return true

	if (osd.FilterOtherLetters && osd.FilterOtherLettersChars != "" && StrLen(keyName) = 1
		&& InStr(osd.FilterOtherLettersChars, keyName, true))
		return true

	if (osd.FilterDigits && RegExMatch(keyName, "^[0-9]$"))
		return true

	if (osd.FilterArrows && (keyName = "Up" || keyName = "Down" || keyName = "Left" || keyName = "Right"))
		return true

	if (osd.FilterNavKeys && (keyName = "Home" || keyName = "End" || keyName = "PgUp" || keyName = "PgDn"
		|| keyName = "Insert" || keyName = "Ins" || keyName = "Delete"))
		return true

	return false
}

IsModifierTapExcluded() {
	global osd
	return (osd.FilterModifiers && osd.FilterModifierMode = "Alone")
}

TokensSubsetOf(subLabel, fullLabel) {
	fullParts := StrSplit(fullLabel, " + ")
	for tok in StrSplit(subLabel, " + ") {
		found := false
		for f in fullParts {
			if (f = tok) {
				found := true
				break
			}
		}
		if !found
			return false
	}
	return true
}

FindLastWordBreak(text) {
	lastBreak := 0
	loop StrLen(text) {
		ch := SubStr(text, A_Index, 1)
		if (ch = " " || ch = A_Tab)
			lastBreak := A_Index
	}
	return lastBreak
}
