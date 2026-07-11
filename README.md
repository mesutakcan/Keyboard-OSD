# Keyboard OSD

[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey_v2-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-GPL-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.4-brightgreen.svg)](https://github.com/mesutakcan/Keyboard-OSD/releases)

![GitHub stars](https://img.shields.io/github/stars/mesutakcan/Keyboard-OSD?style=social)
![GitHub forks](https://img.shields.io/github/forks/mesutakcan/Keyboard-OSD?style=social)
![GitHub issues](https://img.shields.io/github/issues/mesutakcan/Keyboard-OSD)
[![Downloads](https://img.shields.io/github/downloads/mesutakcan/Keyboard-OSD/total)](https://github.com/mesutakcan/Keyboard-OSD/releases)

Keyboard OSD is a lightweight Windows utility that displays keyboard input and shortcut combinations on screen in real time. It is designed for presentations, tutorials, screen recordings, and live demonstrations where visible keystrokes make the workflow easier to follow.

![Keyboard OSD demo](docs/ss_keyboard_osd.gif)

## Features

- Shows typed text, special keys, and shortcut combinations as an on-screen display.
- Shortcut and modifier key presses are displayed as styled badge overlays with a rounded border, distinct fill color, and configurable transparency — visually separating them from typed text.
- Groups repeated key presses with a counter.
- Keeps recent key history on multiple OSD lines, each with its own expiry timer.
- Supports optional word wrapping for typed text.
- Handles Backspace naturally while typing by removing the last visible character.
- Supports common modifiers such as Ctrl, Shift, Alt, Win, and AltGr.
- Uses a click-through overlay so the OSD does not block the active window.
- Automatically positions the OSD on the monitor that contains the active window.
- Includes a settings window for colors, font, size, transparency, position, margins, padding, line spacing, and display timing.
- Saves settings to `settings.ini` using separate sections for Appearance, Layout, History, Special, and Timing.
- Icons are embedded in the executable — no external icon files needed for the compiled version.
- OSD lines fade out smoothly using independent non-blocking per-row timers.
- Rounded window corners via the DWM API.
- History lines have their own separate font size, text color, background color, and transparency.
- Pause and resume the OSD with **`Ctrl+Shift+F8`** or from the tray menu.

## Requirements

- Windows
- For the compiled release: no AutoHotkey installation is required.
- For running from source: [AutoHotkey v2](https://www.autohotkey.com/) is required.

## Files

| File | Description |
|---|---|
| `keyboard-osd.ahk` | Main script — key watcher, OSD rendering, state management, tray menu |
| `lib.ahk` | Helper library — text measurement (GDI), badge rendering (GDI+), monitor detection, fade animation, window helpers, INI read |
| `settings-gui.ahk` | Settings window with tabbed layout and live preview |
| `commonDialog.ahk` | Windows standard Font (ChooseFontW) and Color (ChooseColorW) dialog wrappers |
| `settings.ini` | User settings (auto-created on first save) |
| `app_icon.ico` | Tray icon — active state (source version only) |
| `app_icon_pause.ico` | Tray icon — paused state (source version only) |

## Usage

### Download the compiled version

1. Open the [Releases](https://github.com/mesutakcan/Keyboard-OSD/releases) page.
2. Download the latest `.exe` file.
3. Run the executable.
4. Press keys or shortcuts to see them on screen.

> **Note:** The compiled executable contains all required icons internally. You can move it anywhere without worrying about missing icon files.

### Run from source

1. Install AutoHotkey v2.
2. Download or clone this repository.
3. Run `keyboard-osd.ahk`.
4. Press keys or shortcuts to see them on screen.

The application runs in the system tray. Right-click the tray icon to open:

- `About` — show application and author information
- `GitHub Repository` — open the project page
- `Settings` — edit the OSD appearance and behavior
- `Reload` — reload the script
- `Pause OSD` — pause or resume the OSD
- `Exit` — close the application

You can also toggle pause with the keyboard shortcut **`Ctrl+Shift+F8`**.

## Settings

All options can be changed from the tabbed settings window. Changes are saved to `settings.ini` and the script reloads automatically to apply them.

![Settings window](docs/ss_settings.gif)

### Appearance
- Text and background colors (Windows color picker)
- Background transparency (alpha)
- Font family, size, bold, italic, underline, strikeout (Windows font picker)
- Rounded window corners (on/off)

### Layout
- Auto width or fixed maximum width
- Word wrap for typed text
- Maximum visible lines
- Line gap between rows
- OSD position: TopLeft, TopCenter, TopRight, BottomLeft, BottomCenter, BottomRight
- Margin X / Margin Y from the screen edge
- Padding X, Padding Y Top, Padding Y Bottom inside each row

### History
- History line font size
- History text and background colors
- History background transparency

### Special
Controls the appearance of shortcut and modifier key badges (e.g. `Ctrl+C`, `Shift`, `Escape`, `Tab`):

- Border color, fill color, text color
- Badge transparency (alpha)
- Border width
- Text padding inside the badge
- Text Y nudge (fine-tune vertical text position)

### Timing
- Display duration (ms) — how long the active line stays on screen
- Dismiss delay (ms) — how long each history line stays before fading out
- Modifier delay (ms) — how long to wait before showing a lone modifier key press


## Notes

- The script requires AutoHotkey v2 and will not run on AutoHotkey v1.
- The OSD follows the active monitor's work area, excluding the taskbar.
- Line height is calculated automatically from the actual GDI font metrics; it is not a manual setting.
- Badge bitmaps for special keys are rendered using GDI+ and cached for performance.
- Some keyboard behavior may depend on the active keyboard layout.
- When running the compiled version, icons are embedded in the executable (main icon via `SetMainIcon`, pause icon as Resource ID 207). When running from source, `app_icon.ico` and `app_icon_pause.ico` must be present in the script directory.
- Font and text width measurement use the Windows GDI API for pixel-accurate results.

## History

### Version 1.4 (2026-07-11)

**New:**
- Shortcut and modifier key presses are now rendered as styled badge overlays using GDI+ instead of plain text rows. Each badge has a configurable rounded border, fill color, text color, and transparency.
- New `[Special]` INI section with seven settings: `SpecialBgColor`, `SpecialTextColor`, `SpecialBorderColor`, `SpecialAlpha`, `SpecialBorderWidth`, `SpecialTextPad`, `SpecialTextYNudge`.
- New "Special" tab in the settings window with live preview of the badge appearance.
- `OSDLine` now carries an `IsSpecial` flag that controls whether a row is drawn as a badge or as a regular OSD line.
- `MakeRoundedBadgeBitmap` — GDI+ function that draws a rounded-corner badge with a filled interior and border, returned as an HBITMAP.
- `RenderPreviewBadge` — pixel-level software renderer used in the settings preview for both active, history, and special badge previews.
- `BlendHexColor` — alpha-blends a foreground hex color over a background for use in font preview labels.
- `HexToARGB` — converts an RGB hex string to a GDI+ ARGB integer.
- `_InRoundRect` — sub-pixel rounded rectangle hit test used by `RenderPreviewBadge`.
- `SpecialBadgeCache` — badges are cached by size so GDI+ bitmaps are not recreated on every render.
- GDI+ is now initialized at startup (`InitGdiplus`) and cleaned up on exit (`ShutdownGdiplus`).
- Each OSD row now also has a `Picture` control (`RowPics`) that holds the badge bitmap when a special row is active.

**Fixes:**
- Settings window: controls inside each tab were positioned too close to the tab's top edge; all tab content now starts with more top spacing.
- Special tab preview now shows a two-key combo sample (`Ctrl + PgDn`) instead of a single key, matching the spacing format used by real badge labels.

---

### Version 1.3 (2026-07-02)

**Architecture:**
- Refactored into `OSDSettings` and `OSDState` classes for cleaner state management.
- Extracted all helper functions into a dedicated `lib.ahk` file.
- INI file reorganized into four named sections: `[Appearance]`, `[Layout]`, `[History]`, `[Timing]`.

**New:**
- Each OSD line is now an `OSDLine` object with its own `CreatedAt` timestamp, repeat counter, and `IsExpired()` check — active line and history lines expire independently.
- Non-blocking per-row fade system using `FadingStates` / `FadeTimers` arrays.
- `CheckExpiredLines` timer replaces the `StartDismiss` / `DismissNext` chain.
- `FlushTypingTimeout` — typed text is automatically committed after `DisplayTime` ms of inactivity.
- `MeasureTextHeight` — line height is now calculated from real GDI font metrics.
- Pause/resume keyboard shortcut `Ctrl+Shift+F8`.
- Settings GUI switched from GroupBox layout to a tabbed layout.
- Added `PaddingX`, `PaddingYTop`, `PaddingYBottom` layout settings.

**Fixes:**
- Fade no longer blocks the key watcher thread.

---

### Version 1.2 (2026-06-28)

**New:**
- OSD windows now fade out smoothly when dismissed instead of disappearing instantly.

---

### Version 1.1 (2026-06-26)

**New:**
- Icons are now embedded directly into the compiled executable.
- Improved portability — the `.exe` file now works standalone without requiring external icon files.

**Fixes:**
- Fixed tray icon not displaying correctly in compiled executable.
- Fixed pause icon switching when script is paused.

---

### Version 1.0 (2026-06-24)

- Initial release.
- Real-time keyboard input display.
- Support for shortcuts and modifier keys.
- Customizable appearance and behavior.
- Settings window with live preview.

## License

This project is licensed under the GPL 3.0 License. For more information, see the `LICENSE` file.

## Contributing

Contributions are welcome! If you'd like to add features, fix bugs, or improve the code, feel free to open a pull request.

## Contact

**Author**: Mesut Akcan\
**Email**: <makcan@gmail.com>\
**Blog**: [mesutakcan.blogspot.com](http://mesutakcan.blogspot.com)\
**YouTube**: [youtube.com/mesutakcan](http://youtube.com/mesutakcan)\
**GitHub**: [mesutakcan](http://github.com/mesutakcan)
