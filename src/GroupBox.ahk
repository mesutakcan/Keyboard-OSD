/*
    GroupBox.ahk - A VB/VBA-style container GroupBox for AutoHotkey v2

    Native AHK GroupBox controls are purely visual: moving the frame
    does not move the controls placed inside it. This class wraps a
    GroupBox and tracks every control added to it, so the whole group
    behaves as a single container - moving, hiding, enabling, or
    destroying the group affects it and all of its contents together.

    Version: 1.0.0
    Date:    2026-07-26
    Author:  Mesut Akcan
    GitHub:  https://github.com/mesutakcan/GroupBox
*/

#Requires AutoHotkey v2.0

class GroupBox {

	__New(gui, x, y, w, h, title := "", opts := "") {
		this._gui := gui
		this._x := x
		this._y := y
		this._w := w
		this._h := h
		this._title := title
		this._controls := []
		this._destroyed := false
		this._box := gui.AddGroupBox("x" x " y" y " w" w " h" h " " opts, title)
		this._visible := this._box.Visible
		this._enabled := this._box.Enabled
	}

	Add(ctrl, relX := unset, relY := unset) {
		this._CheckAlive()
		if IsSet(relX) != IsSet(relY)
			throw ValueError("relX and relY must both be given or both omitted", -1)
		if IsSet(relX) {
			ctrl.Move(this._x + relX, this._y + relY)
			rx := relX
			ry := relY
		} else {
			ctrl.GetPos(&cx, &cy)
			rx := cx - this._x
			ry := cy - this._y
		}
		this._controls.Push({ ctrl: ctrl, relX: rx, relY: ry })
		if !this._visible
			ctrl.Visible := false
		if !this._enabled
			ctrl.Enabled := false
		return ctrl
	}

	GetPos(&x, &y, &w, &h) {
		x := this._x
		y := this._y
		w := this._w
		h := this._h
	}

	Move(newX, newY, newW := unset, newH := unset) {
		this._CheckAlive()
		w := IsSet(newW) ? newW : this._w
		h := IsSet(newH) ? newH : this._h
		this._box.Move(newX, newY, w, h)
		for entry in this._controls
			entry.ctrl.Move(newX + entry.relX, newY + entry.relY)
		this._x := newX
		this._y := newY
		this._w := w
		this._h := h
		this.Redraw()
	}

	Show() {
		this._CheckAlive()
		this._box.Visible := true
		for entry in this._controls
			entry.ctrl.Visible := true
		this._visible := true
	}

	Hide() {
		this._CheckAlive()
		this._box.Visible := false
		for entry in this._controls
			entry.ctrl.Visible := false
		this._visible := false
	}

	Enable() {
		this._CheckAlive()
		this._box.Enabled := true
		for entry in this._controls
			entry.ctrl.Enabled := true
		this._enabled := true
	}

	Disable() {
		this._CheckAlive()
		this._box.Enabled := false
		for entry in this._controls
			entry.ctrl.Enabled := false
		this._enabled := false
	}

	SetTitle(newTitle) {
		this._CheckAlive()
		this._title := newTitle
		this._box.Text := newTitle
	}

	Destroy() {
		if this._destroyed
			return
		for entry in this._controls
			DllCall("DestroyWindow", "ptr", entry.ctrl.Hwnd)
		this._controls := []
		DllCall("DestroyWindow", "ptr", this._box.Hwnd)
		this._destroyed := true
	}

	Remove(ctrl) {
		this._CheckAlive()
		for i, entry in this._controls {
			if entry.ctrl = ctrl {
				this._controls.RemoveAt(i)
				return true
			}
		}
		return false
	}

	Redraw() {
		if !this._visible || this._destroyed
			return
		static RDW_INVALIDATE := 0x0001
		static RDW_ERASE := 0x0004
		static RDW_ALLCHILDREN := 0x0080
		static RDW_UPDATENOW := 0x0100
		flags := RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW
		DllCall("RedrawWindow", "ptr", this._gui.Hwnd, "ptr", 0, "ptr", 0, "uint", flags)
	}

	_CheckAlive() {
		if this._destroyed
			throw Error("This GroupBox has already been destroyed.", -1)
	}

	X => this._x
	Y => this._y
	W => this._w
	H => this._h
	Title => this._title
	Visible => this._visible
	Enabled => this._enabled
	Count => this._controls.Length
}