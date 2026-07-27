# LangPilot

**Smart typing across languages.**

[![GitHub stars](https://img.shields.io/github/stars/SC1882/LangPilot?style=for-the-badge&label=Stars&color=blue)](https://github.com/SC1882/LangPilot/stargazers)

[Download LangPilot](https://github.com/SC1882/LangPilot/releases/latest) · [Support the project](https://buymeacoffee.com/sc_lab)

LangPilot is a free, open-source macOS menu-bar utility that fixes text entered with the wrong
keyboard layout and offers local spelling suggestions. It currently supports Russian, English,
and German.

![LangPilot settings on macOS](https://github.com/SC1882/LangPilot/releases/download/v2.0.0-beta.2/langpilot-settings-compact.jpg)

- Automatic keyboard-layout detection and correction
- Local spelling suggestions with Tab to accept and Esc to dismiss
- Personal learning from manual corrections and undo actions
- Secure-field protection and per-application exclusions
- Launch at login and native macOS settings
- No accounts, analytics, network requests, or uploaded text

Copyright © 2026 [SC1882](https://github.com/SC1882). Licensed under GPL-3.0-only.

If LangPilot makes your daily typing easier, you can support its development:

[![Buy Me a Coffee](https://img.shields.io/badge/Buy_Me_a_Coffee-Support_LangPilot-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=000000)](https://buymeacoffee.com/sc_lab)

## Installation

Download the latest DMG from [GitHub Releases](https://github.com/SC1882/LangPilot/releases), drag LangPilot to Applications, then open it using
**Control-click → Open**. Because this independent build is not Apple-notarized, macOS may show a
Gatekeeper warning. Grant Accessibility and Input Monitoring access when requested.

## Privacy and permissions

LangPilot is designed as a local-only typing helper. It does not use accounts, analytics, network
requests, cloud processing, or uploaded text.

macOS may ask for these permissions:

- **Accessibility** — lets LangPilot detect the focused text field, place suggestions near the text
  cursor, and apply accepted corrections.
- **Input Monitoring** — lets LangPilot observe keyboard input system-wide so it can detect wrong
  keyboard-layout text and trigger shortcuts.
- **Launch at Login** — optional; controlled from LangPilot settings.

Password and secure fields are ignored. When macOS reports the focused field as a secure text field,
LangPilot skips detection, correction, spelling suggestions, and learning for that field.

Learned word pairs, rejected corrections, and settings are stored locally in macOS UserDefaults for
the app bundle (`local.langpilot.app`). The learning data uses the `learning.v1` key and normally
lives inside your user Library preferences. Full typed phrases are not stored.

You can view learned word pairs or reset all learning from **Settings → Learning**. Export is not
implemented yet; for now, reset is the supported data-control action.

## Compatibility

LangPilot should work in many standard macOS text fields, browsers, and Electron apps. Some apps may
behave differently if they use custom text rendering, protected input, remote desktops, virtual
machines, games, or terminal-style input. If an app does not work well with LangPilot, add it to
**Settings → Privacy → Excluded applications**.

## Build

```bash
chmod +x build-app.sh
./build-app.sh
open dist/LangPilot.app
```

Requires Xcode 26 or newer.

## Shortcuts and learning

- `⌥⌘L` — manually fix the last word.
- `⌥⌘Z` — undo the last replacement.
- Menu-bar `ЯA` icon — enable or pause automatic correction.
- Sound notification — optional short sound when the keyboard layout changes.
- Spelling suggestions appear near the text cursor; `Tab` accepts a suggestion and `Esc` dismisses it.

Automatic corrections are applied only when confidence is high. Manual corrections can teach
LangPilot your vocabulary over time. If you undo a replacement with `⌥⌘Z`, LangPilot learns to avoid
that replacement in the future.
