# FloatyClipshot

A floating screenshot utility for macOS developers. Capture screenshots with a single click and auto-paste file paths directly into your terminal or IDE.

![macOS](https://img.shields.io/badge/macOS-11.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Floating Button** - Always-on-top capture button, drag anywhere on screen
- **Smart Terminal Integration** - Detects Terminal, iTerm2, VS Code, Cursor and saves screenshots to your current project directory
- **Auto-Paste** - Automatically pastes the screenshot file path after capture
- **Clipboard History** - Browse and manage your clipboard history with encryption
- **Global Hotkeys** - Customizable keyboard shortcuts for quick capture
- **Window Tagging** - Organize captures by window/project

## Installation

### Homebrew (Recommended)

```bash
brew tap dev-datacode/floatyclipshot
brew install --cask floatyclipshot
```

### Manual Installation

1. Download the latest release from [GitHub Releases](https://github.com/dev-datacode/floatyclipshot/releases)
2. Unzip and drag `floatyclipshot.app` to `/Applications`
3. **If macOS says the app is "damaged"**, run:
   ```bash
   xattr -cr /Applications/floatyclipshot.app
   ```
4. Right-click → Open (first launch only, to bypass Gatekeeper)

### Build from Source

```bash
git clone https://github.com/dev-datacode/floatyclipshot.git
cd floatyclipshot
./build_for_production.sh
```

## Usage

1. Launch FloatyClipshot - a floating button appears on screen
2. Open your terminal and navigate to your project directory
3. Click the floating button or press `Cmd+Shift+B`
4. Screenshot is saved to `./FloatyClipshot/tmp/` and path is auto-pasted

### Hotkeys

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+F8` | Capture screenshot |
| `Cmd+Shift+B` | Capture and paste path |

### Right-Click Menu

- **Capture** - Take a screenshot
- **Clipboard History** - View clipboard history
- **Settings** - Configure hotkeys and preferences
- **Quit** - Exit the app

## Permissions Required

FloatyClipshot requires the following macOS permissions:

1. **Screen Recording** - For capturing screenshots
   - System Settings → Privacy & Security → Screen Recording

2. **Accessibility** - For auto-paste functionality
   - System Settings → Privacy & Security → Accessibility

## Security

- **Encryption at Rest** - All clipboard data is encrypted using AES-256-GCM
- **Keychain Storage** - Encryption keys stored securely in macOS Keychain
- **Sensitive Data Detection** - Automatically detects and flags passwords, API keys, credit cards
- **Auto-Purge** - Sensitive items auto-deleted after configurable timeout (default: 60 min)

## Requirements

- macOS 11.0 (Big Sur) or later
- Screen Recording permission
- Accessibility permission (for auto-paste)

## Development

### Project Structure

```
floatyclipshot/
├── floatyclipshot/           # Main app source
│   ├── Managers/             # Core managers (singleton pattern)
│   │   ├── ScreenshotManager.swift
│   │   ├── ClipboardManager.swift
│   │   ├── HotkeyManager.swift
│   │   ├── EncryptionManager.swift
│   │   └── SettingsManager.swift
│   └── Views/                # SwiftUI views
├── floatyclipshotTests/      # Unit tests
├── build_for_production.sh   # Production build script
└── .github/workflows/        # CI/CD
```

### Running Tests

```bash
xcodebuild -scheme floatyclipshotTests test -destination 'platform=macOS'
```

### Building

```bash
# Debug build
xcodebuild -scheme floatyclipshot -configuration Debug build

# Release build with code signing
./build_for_production.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built with SwiftUI and AppKit
- Uses CryptoKit for encryption
- Carbon Event Manager for global hotkeys
