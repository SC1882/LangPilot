# Privacy

LangPilot processes keyboard events locally to detect text entered with the wrong keyboard layout
and to offer spelling corrections. It does not transmit typed text, learned word pairs, analytics,
or personal data to any server.

LangPilot ignores macOS secure text fields and can be disabled for selected applications in Settings.
Its learned word pairs and preferences are stored locally in macOS UserDefaults.

The application requires Accessibility and Input Monitoring permissions solely to provide its
system-wide typing features.

## macOS permissions

- **Accessibility** is used to detect the currently focused text field, position suggestion UI near
  the cursor, and apply accepted corrections.
- **Input Monitoring** is used to observe keyboard input system-wide for layout detection and
  shortcuts.
- **Launch at Login** is optional and can be enabled or disabled in Settings.

## Local data

LangPilot stores learned word pairs, rejected corrections, and preferences locally using macOS
UserDefaults for the `local.langpilot.app` bundle. The current learning key is `learning.v1`.

Full typed phrases, passwords, and text field contents are not stored.

You can view learned word pairs and reset all learning in **Settings → Learning**. Export is not
implemented yet.

## Password and secure fields

When macOS marks the focused field as a secure text field, LangPilot skips correction, spelling
suggestions, and learning for that field.

## Compatibility notes

LangPilot should work in many standard macOS text fields, browsers, and Electron apps. Behavior may
vary in apps that use custom text input, terminal-style input, protected input, virtual machines,
remote desktops, or games. Apps can be excluded in **Settings → Privacy**.
