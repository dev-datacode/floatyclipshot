# FloatyClipshot

A macOS screenshot utility designed for developers who need instant, friction-free screenshots during mobile/web development.

## Features

- **One-click screenshot capture** via a floating, always-on-top, draggable button.
- **Window-targeted captures**: Select any window once, then every click captures that window.
- **Multi-desktop support**: Target windows on any Space/desktop.
- **Smart Terminal Integration**: 
    - Detects if you are working in **Terminal, iTerm2, VS Code, or Cursor**.
    - Saves screenshots to your **current project directory** (under `FloatyClipshot/tmp/`).
    - **Automatically pastes the file path** into your CLI.
- **Customizable Hotkeys**: 
    - `Cmd+Shift+F8` (Default): Instant capture to clipboard.
    - `Cmd+Shift+B` (Default): Capture & Paste Path (Smart Mode).
- **Privacy & Permissions**: Built-in status checks and guidance for macOS permissions.

## Quick Start

### 1. Install
The easiest way to build and install the app is using the included script:

```bash
./install.sh
```

This script will:
1. Build the app using Xcode.
2. Install it to `/Applications`.
3. Sign it with your local Apple Development certificate (preserving permissions across updates).
4. Launch the app.

### 2. Grant Permissions
On first launch, you must grant permissions for the app to function:
- **Screen Recording**: To capture window contents.
- **Accessibility**: To auto-paste file paths.

If permissions are missing, the floating button will show a **red warning badge** (⚠️). 
Right-click the button and select **"⚠️ Fix Permissions"** to open the setup guide.

### 3. Usage

**Standard Capture (Clipboard):**
- Click the floating button.
- OR press `Cmd + Shift + F8`.
- Result: Image is copied to clipboard.

**CLI / IDE Mode (File Path):**
- Open your terminal (Terminal, iTerm2, VS Code, Cursor).
- Navigate to your project folder.
- Press **`Cmd + Shift + B`**.
- Result: 
    1. Screenshot is saved to `./FloatyClipshot/tmp/Screenshot-...png`.
    2. **Full file path** is pasted into your terminal prompt.
    3. Ready to send to CLI tools like `claude`, `gemini`, etc.

## Troubleshooting

**"Nothing happens when I press the hotkey"**
1. Check for the red ⚠️ badge on the floating button.
2. Go to **System Settings > Privacy & Security > Accessibility**.
3. Toggle `floatyclipshot` **OFF** and **ON** again (macOS sometimes requires this after an update).

**Build Fails**
- Ensure you have Xcode installed.
- Run `xattr -cr .` in the project directory to clean file attributes if signing fails.

## License

MIT License