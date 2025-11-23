# FloatyClipshot

A macOS screenshot utility designed for developers who need instant, friction-free screenshots during mobile/web development.

## Features

- **One-click screenshot capture** via a floating, always-on-top, draggable button
- **Window-targeted captures** - Select any window once, then every click captures that window
- **Multi-desktop support** - Target windows on any Space/desktop
- **Smart terminal detection** - Automatically saves file path for terminals instead of image
- **Customizable global keyboard shortcuts** - Default ⌘⇧F8 for capture, ⌘⇧F10 for paste
- **Settings persistence** - Window selection and hotkey preferences saved across app restarts
- **Instant clipboard** - Screenshots go directly to clipboard for immediate pasting
- **Clipboard history** - Last 10 items with window context
- **Visual feedback** - Button turns green when window is targeted

## Requirements

- macOS 11.0 or later
- Screen Recording permission (System Preferences → Security & Privacy → Screen Recording)
- Accessibility permission for auto-paste (System Preferences → Security & Privacy → Accessibility)

## Installation

### For Users

**Option 1: Homebrew Cask (Recommended)**
```bash
brew tap hooshyar/floatyclipshot
brew install --cask floatyclipshot
```

**Option 2: Direct Download**
1. Download the latest release from [Releases](https://github.com/hooshyar/floatyclipshot/releases/latest)
2. Unzip and drag `floatyclipshot.app` to `/Applications`
3. Right-click the app and select "Open" (first time only)

### For Developers

1. Clone this repository
2. Open `floatyclipshot.xcodeproj` in Xcode
3. Build and run (⌘R)

**For distribution:** See [DISTRIBUTION.md](../DISTRIBUTION.md)

## Usage

### Initial Setup
1. Launch FloatyClipshot → Floating button appears
2. Drag the button to your preferred location
3. Right-click → Choose window target (optional)
4. Enable hotkeys in context menu (optional)

### Capturing Screenshots

**Button Click:**
- Click the floating button → Instant screenshot to clipboard

**Keyboard Shortcut:**
- Press ⌘⇧F8 → Instant screenshot to clipboard

**Terminal Apps:**
- When clicking from Terminal/iTerm2, screenshots are saved to Desktop
- File path is copied to clipboard
- Paste with ⌘V to insert path into terminal

### Window Targeting
- Right-click button → "Choose Window Target"
- Select any window from the list (even on other desktops!)
- Button turns green with scope icon
- All captures now target that window

## Supported Terminal Apps

FloatyClipshot automatically detects and provides file paths for:
- Terminal.app
- iTerm2
- Alacritty
- Kitty
- Hyper
- Warp
- WezTerm
- Terminus

## Build from Source

```bash
# Clone the repository
git clone https://github.com/hooshyar/floatyclipshot.git
cd floatyclipshot

# Build with Xcode
xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release build

# Or open in Xcode
open floatyclipshot.xcodeproj
```

## License

MIT License - See LICENSE file for details

## Author

Hooshyar (hooshyar@gmail.com)
