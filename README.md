# Keyboard OSD

[![AutoHotkey](https://img.shields.io/badge/Language-AutoHotkey_v2-green.svg)](https://www.autohotkey.com/)
[![Platform](https://img.shields.io/badge/Platform-Windows-blue.svg)](https://www.microsoft.com/windows)
[![License](https://img.shields.io/badge/License-GPL-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.5-brightgreen.svg)](https://github.com/mesutakcan/Keyboard-OSD/releases)

![GitHub stars](https://img.shields.io/github/stars/mesutakcan/Keyboard-OSD?style=social)
![GitHub forks](https://img.shields.io/github/forks/mesutakcan/Keyboard-OSD?style=social)
![GitHub issues](https://img.shields.io/github/issues/mesutakcan/Keyboard-OSD)
[![Downloads](https://img.shields.io/github/downloads/mesutakcan/Keyboard-OSD/total)](https://github.com/mesutakcan/Keyboard-OSD/releases)

Keyboard OSD is a lightweight Windows utility that displays keyboard input and shortcut combinations on screen in real time. It is designed for presentations, tutorials, screen recordings, and live demonstrations where visible keystrokes make the workflow easier to follow.

![Keyboard OSD demo](docs/ss_keyboard_osd.gif)

## Features

- Shows your typed text and shortcut combinations on screen in real time.
- Shortcuts and modifier keys (like <kbd>Ctrl+C</kbd> or <kbd>Shift</kbd>) appear as eye-catching badges, clearly separated from regular typed text.
- Repeated key presses are grouped together with a counter instead of cluttering the screen.
- Keeps a short history of recent keys, with each line fading out on its own timer.
- Optional word wrap for longer typed text, and natural Backspace handling while typing.
- Works with common modifiers: Ctrl, Shift, Alt, Win, and AltGr.
- Click-through overlay — it never gets in the way of the window you're working in.
- Automatically follows the active window to the correct monitor.
- Fully customizable from a settings window: colors, fonts, size, transparency, position, margins, padding, and timing — all with a live preview.
- Smooth fade-out animations and optional rounded corners.
- History lines can have their own font size, colors, and transparency, separate from the active line.
- Pause and resume anytime with **<kbd>Ctrl+Shift+F8</kbd>** or from the tray menu.
- Compiled version is a single portable `.exe` — no separate icon files or installation needed.

## Requirements

- Windows
- For the compiled release: no AutoHotkey installation is required.
- For running from source: [AutoHotkey v2](https://www.autohotkey.com/) is required.

## Files

| File | Description |
|---|---|
| `keyboard-osd.ahk` | Main script — handles the tray menu and displays your keystrokes on screen |
| `lib.ahk` | Supporting code for rendering and window behavior |
| `settings-gui.ahk` | The settings window, with live preview |
| `commonDialog.ahk` | Windows font and color picker windows |
| `settings.ini` | Your saved settings (created automatically the first time you save) |
| `app_icon.ico` | Tray icon shown while the OSD is active (source version only) |
| `app_icon_pause.ico` | Tray icon shown while the OSD is paused (source version only) |

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

You can also toggle pause with the keyboard shortcut **<kbd>Ctrl+Shift+F8</kbd>**.

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
Controls the appearance of shortcut and modifier key badges (e.g. <kbd>Ctrl+C</kbd>, <kbd>Shift</kbd>, <kbd>Escape</kbd>, <kbd>Tab</kbd>):

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

- Running from source requires AutoHotkey v2; it will not work with the older AutoHotkey v1.
- The OSD automatically appears on whichever monitor your active window is on, and stays clear of the taskbar.
- Row height adjusts automatically to your chosen font, so text is never cropped or oddly spaced.
- Shortcut and modifier badges are cached for smooth performance, even with frequent key presses.
- Keystroke display may vary slightly depending on your active keyboard layout.
- The compiled `.exe` has all icons built in, so it works standalone. When running from source, keep `app_icon.ico` and `app_icon_pause.ico` in the same folder as the script.
- Text is measured precisely so it always fits and aligns cleanly on screen.

## History

### Version 1.5 (2026-07-15)

**New:**
- The Windows (<kbd>Win</kbd>)  key can now be shown on its own as a badge, just like <kbd>Ctrl</kbd>, <kbd>Shift</kbd>, and <kbd>Alt</kbd>.
- Improved <kbd>AltGr</kbd> and <kbd>Shift</kbd> handling: when a key combination produces a character, that character now appears in the typed text as expected. When it doesn't produce a character, the badge shows the key combination itself (e.g. <kbd>AltGr + K</kbd>).
- Holding down multiple modifier keys in sequence now updates the badge smoothly to show the full combination, instead of showing a separate badge for each stage.

**Fixes:**
- A lone modifier badge (e.g. just "Shift") no longer lingers on screen after you start typing.

---

### Version 1.4 (2026-07-11)

**New:**
- Shortcut and modifier key presses now appear as styled badges with a rounded border, fill color, and their own transparency — making them instantly stand out from regular typed text.
- Added a new **Special** tab in the settings window to customize badge colors, border, padding, and text position, with a live preview.
- Smoother performance when pressing shortcuts frequently.

---

### Version 1.3 (2026-07-02)

**New:**
- Active line and history lines now disappear independently, each on its own timer, for more natural timing.
- Row fade-outs are smoother and no longer interrupt typing while they play.
- Typed text is now automatically finalized after a short pause, instead of waiting indefinitely.
- Row height is now calculated automatically from your chosen font, so text always fits cleanly.
- Added a pause/resume keyboard shortcut: <kbd>Ctrl+Shift+F8</kbd>.
- Settings window redesigned with a cleaner tabbed layout.
- Added fine-grained padding controls for each row (left/right, top, bottom).

**Fixes:**
- Fade animations no longer cause typing to lag or stutter.

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
