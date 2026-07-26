# LangPilot

**Smart typing across languages.**

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

## Build

```bash
chmod +x build-app.sh
./build-app.sh
open dist/LangPilot.app
```

Requires Xcode 26 or newer.

- `⌥⌘L` — исправить последнее слово вручную.
- `⌥⌘Z` — отменить последнюю замену.
- Меню `ЯA` — включить или приостановить автоматическую коррекцию.
- **Звук при переключении** в меню `ЯA` — включить или выключить короткий сигнал смены раскладки.
- **Запускать вместе с macOS** — управляет системным Login Item; при первом запуске включается автоматически.
- **Орфография** — варианты показываются возле текстового курсора; `Tab` принимает вариант, `Esc` скрывает его, `⌥⌘S` остаётся глобальной командой.
  Подсказка видна 8 секунд и умеет безопасно исправить предыдущее слово, даже если ввод уже продолжился.

Автоматически исправляются только слова с высокой уверенностью; остальные можно обучить вручную.

## Самообучение

Дважды исправленное вручную слово запоминается и дальше исправляется автоматически. Отмена через `⌥⌘Z`
обучает приложение больше не выполнять эту замену. Модель хранит локально только пары слов и счётчики —
полные фразы и содержимое приложений не записываются.
