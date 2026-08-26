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

    /**
     * Creates a new GroupBox container.
     * @param {Gui} gui - The Gui object this group belongs to.
     * @param {Integer} x - Left position of the frame.
     * @param {Integer} y - Top position of the frame.
     * @param {Integer} w - Width of the frame.
     * @param {Integer} h - Height of the frame.
     * @param {String} title - Caption text shown on the frame.
     * @param {String} opts - Additional GuiControl options appended
     *   to the GroupBox (e.g. font or style options).
     */
    __New(gui, x, y, w, h, title := "", opts := "") {
        this._gui      := gui
        this._x        := x
        this._y        := y
        this._w        := w
        this._h        := h
        this._title    := title
        this._controls := []
        this._destroyed := false

        this._box := gui.AddGroupBox("x" x " y" y " w" w " h" h " " opts, title)

        ; If opts included native options like +Hidden or +Disabled,
        ; read the resulting state back instead of assuming defaults.
        this._visible := this._box.Visible
        this._enabled := this._box.Enabled
    }

    /**
     * Attaches a control to the group so it moves, shows/hides,
     * enables/disables, and gets destroyed together with the group.
     * If the group is currently hidden or disabled, the control is
     * immediately hidden or disabled to match.
     * @param {Gui.Control} ctrl - A control already created via
     *   gui.AddXxx().
     * @param {Integer} [relX] - Position relative to the group's
     *   top-left corner. Omit together with relY to keep the
     *   control's current position and have the offset inferred
     *   from it instead.
     * @param {Integer} [relY] - See relX.
     * @returns {Gui.Control} The same control, for chaining.
     * @throws {ValueError} If only one of relX/relY is given.
     * @throws {Error} If the group has already been destroyed.
     */
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

    /**
     * Retrieves the group's current position and size.
     * @param {VarRef} x - Receives the X position.
     * @param {VarRef} y - Receives the Y position.
     * @param {VarRef} w - Receives the width.
     * @param {VarRef} h - Receives the height.
     */
    GetPos(&x, &y, &w, &h) {
        x := this._x
        y := this._y
        w := this._w
        h := this._h
    }

    /**
     * Moves the frame and every attached control, preserving each
     * control's relative offset. Width/height may be changed at the
     * same time.
     * @param {Integer} newX - New left position.
     * @param {Integer} newY - New top position.
     * @param {Integer} [newW] - New width. Defaults to the current width.
     * @param {Integer} [newH] - New height. Defaults to the current height.
     * @throws {Error} If the group has already been destroyed.
     */
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

    /** Shows the frame and every attached control. */
    Show() {
        this._CheckAlive()
        this._box.Visible := true
        for entry in this._controls
            entry.ctrl.Visible := true
        this._visible := true
    }

    /** Hides the frame and every attached control. */
    Hide() {
        this._CheckAlive()
        this._box.Visible := false
        for entry in this._controls
            entry.ctrl.Visible := false
        this._visible := false
    }

    /** Enables the frame and every attached control. */
    Enable() {
        this._CheckAlive()
        this._box.Enabled := true
        for entry in this._controls
            entry.ctrl.Enabled := true
        this._enabled := true
    }

    /** Disables the frame and every attached control. */
    Disable() {
        this._CheckAlive()
        this._box.Enabled := false
        for entry in this._controls
            entry.ctrl.Enabled := false
        this._enabled := false
    }

    /**
     * Changes the frame's caption.
     * @param {String} newTitle - The new caption text.
     * @throws {Error} If the group has already been destroyed.
     */
    SetTitle(newTitle) {
        this._CheckAlive()
        this._title := newTitle
        this._box.Text := newTitle
    }

    /**
     * Destroys the frame and every attached control, removing them
     * from the window. Calling it again on an already-destroyed
     * group is a harmless no-op.
     */
    Destroy() {
        if this._destroyed
            return
        for entry in this._controls
            DllCall("DestroyWindow", "ptr", entry.ctrl.Hwnd)
        this._controls := []
        DllCall("DestroyWindow", "ptr", this._box.Hwnd)
        this._destroyed := true
    }

    /**
     * Detaches a control from the group without destroying it. The
     * control remains on the window but no longer follows Move(),
     * Show()/Hide(), Enable()/Disable(), or Destroy().
     * @param {Gui.Control} ctrl - The control to detach.
     * @returns {Boolean} true if the control was found and detached.
     * @throws {Error} If the group has already been destroyed.
     */
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

    /**
     * Forces a repaint of the frame and every attached control by
     * redrawing the parent Gui window. Called automatically at the
     * end of Move(); call it manually if a control's appearance
     * needs refreshing without changing its position. Does nothing
     * while the group is hidden or already destroyed.
     */
    Redraw() {
        if !this._visible || this._destroyed
            return
        static RDW_INVALIDATE  := 0x0001
        static RDW_ERASE       := 0x0004
        static RDW_ALLCHILDREN := 0x0080
        static RDW_UPDATENOW   := 0x0100
        flags := RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW
        DllCall("RedrawWindow", "ptr", this._gui.Hwnd, "ptr", 0, "ptr", 0, "uint", flags)
    }

    ; Throws a clear error instead of letting a destroyed control's
    ; underlying window produce a cryptic native failure.
    _CheckAlive() {
        if this._destroyed
            throw Error("This GroupBox has already been destroyed.", -1)
    }

    /** @property {Integer} X - Current left position. */
    X       => this._x
    /** @property {Integer} Y - Current top position. */
    Y       => this._y
    /** @property {Integer} W - Current width. */
    W       => this._w
    /** @property {Integer} H - Current height. */
    H       => this._h
    /** @property {String} Title - Current caption text. */
    Title   => this._title
    /** @property {Boolean} Visible - Whether the group is currently shown. */
    Visible => this._visible
    /** @property {Boolean} Enabled - Whether the group is currently enabled. */
    Enabled => this._enabled
    /** @property {Integer} Count - Number of controls currently attached. */
    Count   => this._controls.Length
}
