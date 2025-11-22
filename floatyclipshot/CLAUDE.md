# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**FloatyClipshot** is a macOS screenshot utility designed for developers who need instant, friction-free screenshots during mobile/web development. It provides:
- **One-click screenshot capture** via a floating, always-on-top, draggable button
- **Window-targeted captures** - Select any window once, then every click captures that window
- **Customizable global keyboard shortcut** - Default ⌘⇧F8, fully editable to any key combination
- **Settings persistence** - Window selection and hotkey preferences saved across app restarts
- **Instant clipboard** - Screenshots go directly to clipboard for immediate pasting in IDE/docs
- Clipboard history management (last 10 items with window context)
- Visual feedback (button turns green when window is targeted)
- Optional file-based saving to Desktop

## Build and Run

### Basic Commands
```bash
# Build and run in Xcode
⌘R in Xcode

# Build from command line
xcodebuild -project ../floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Debug build

# Clean build
xcodebuild -project ../floatyclipshot.xcodeproj -scheme floatyclipshot clean
```

### Project Structure
- **Project file**: `../floatyclipshot.xcodeproj`
- **Source files location**: `floatyclipshot/` directory (current working directory)
- **Target**: floatyclipshot
- **Build configurations**: Debug, Release

### Required Permissions
The app requires **Screen Recording** permission in System Preferences → Security & Privacy → Privacy → Screen Recording to capture screenshots.

## Architecture

### Core Components

**1. floatyclipshotApp.swift** (Main Entry Point)
- SwiftUI App with AppDelegate pattern
- Creates borderless, floating NSWindow (80x80 pixels)
- Window configuration: `.floating` level, `.canJoinAllSpaces`, `.fullScreenAuxiliary`
- Hosts `FloatingButtonView` as the main UI

**2. FloatingButtonView.swift** (UI Layer - One-Click Workflow)
- SwiftUI Button with circular appearance (80pt diameter)
- **Primary Action (Left-click)**: Instant screenshot capture to clipboard
- **Context Menu (Right-click)**: Configuration options
- **Dynamic visual feedback**:
  - Black/camera icon: Full screen mode
  - Green/scope icon: Window targeted (ready to capture)
  - Button scale animation on capture
- Tooltip shows what will be captured on click
- Auto-refreshes window list when context menu opens

**3. WindowManager.swift** (Window Selection & Listing)
- Singleton ObservableObject managing window targeting
- Uses `CGWindowListCopyWindowInfo` to list all capturable windows
- Filters out system UI and small windows (< 100x100px)
- Published properties:
  - `selectedWindow: WindowInfo?`: Currently targeted window
  - `availableWindows: [WindowInfo]`: List of capturable windows
- Methods:
  - `refreshWindowList()`: Updates list of available windows
  - `selectWindow()`: Target a specific window for capture
  - `clearSelection()`: Return to full-screen mode
- Window filtering: Excludes own app, sorts by owner name

**4. ScreenshotManager.swift** (Screenshot Logic)
- Singleton class managing macOS `screencapture` tool (`/usr/sbin/screencapture`)
- **Window-aware capture**: Checks `WindowManager.shared.selectedWindow` and uses `-l<windowID>` flag
- Methods:
  - `captureFullScreen()`: Captures selected window OR full screen to clipboard
  - `captureRegion()`: Interactive region selection (OR full window if targeted)
  - `captureFullScreenToFile()`: Save to Desktop
  - `captureRegionToFile()`: Save region to Desktop
- Async completion handling to trigger clipboard monitoring
- Error handling with NSAlert for failures

**5. ClipboardManager.swift** (Clipboard Monitoring)
- Singleton ObservableObject managing clipboard history
- Polls NSPasteboard every 0.5 seconds for changes
- Stores last 10 clipboard items with window context
- Each `ClipboardItem` includes:
  - Image/text data
  - Timestamp
  - Window context (name of window that was captured)
- Methods:
  - `pasteItem()`: Restores historical clipboard item
  - `clearHistory()`: Clears clipboard history
- Deduplicates consecutive identical items

**6. HotkeyManager.swift** (Global Keyboard Shortcuts)
- Singleton ObservableObject managing global hotkey registration
- Uses Carbon API (`RegisterEventHotKey`) for system-wide hotkey capture
- Default hotkey: Command+Shift+F8 (fully customizable)
- Published properties:
  - `isEnabled: Bool`: Toggle hotkey on/off
  - `keyCode: UInt32`: Key code for the hotkey (default: F8)
  - `modifiers: UInt32`: Modifier keys (default: Cmd+Shift)
- Methods:
  - `registerHotkey()`: Registers global hotkey with system
  - `unregisterHotkey()`: Removes hotkey registration
  - `updateHotkey()`: Changes hotkey to new key combination
  - `hotkeyDisplayString`: Returns formatted string (e.g., "⌘ ⇧ F8")
- Automatically triggers screenshot capture when hotkey is pressed
- **Persistence**: Loads saved hotkey settings on app launch

**7. HotkeyRecorderView.swift** (Hotkey Customization UI)
- SwiftUI sheet for recording custom keyboard shortcuts
- Interactive key capture using custom NSView
- Real-time display of pressed key combination
- Validation: Requires at least one modifier key (⌘, ⇧, ⌥, or ⌃)
- Supports all standard keys: F1-F12, A-Z, 0-9, special keys
- Cancel/Clear/Save actions
- Format: Shows visual symbols (⌘ ⇧ F8) while recording

**8. SettingsManager.swift** (Persistence Layer)
- Singleton class managing UserDefaults persistence
- **Hotkey Settings**:
  - `hotkeyEnabled`: Whether global hotkey is active
  - `hotkeyKeyCode`: Key code (default: 100 = F8)
  - `hotkeyModifiers`: Modifier flags (default: Cmd+Shift)
- **Window Selection**:
  - `selectedWindowID`: ID of last selected window
  - `selectedWindowName`: Name of selected window
  - `selectedWindowOwner`: Owner app name
- **Button Position**:
  - `buttonPosition`: Last position of floating button (future use)
- Methods:
  - `saveHotkeySettings()`: Persist hotkey configuration
  - `saveSelectedWindow()`: Persist window selection
  - `loadHotkeySettings()`: Restore hotkey on launch
  - `loadSelectedWindow()`: Restore window selection on launch
- All settings persist across app restarts

### Data Flow

**Setup Flow (One-Time)**:
1. **App Launch** → AppDelegate creates floating window → FloatingButtonView rendered
2. **Right-click button** → Context menu opens → WindowManager refreshes window list
3. **User selects window** → WindowManager stores selection → Button turns green with scope icon

**Capture Flow (Every Click)**:
1. **User clicks button** → `performQuickCapture()` triggers
2. **Visual feedback** → Button scale animation (0.1s)
3. **Capture executed** → ScreenshotManager checks selected window → Runs screencapture with `-l<windowID>` OR full screen
4. **Clipboard updates** → Screenshot data copied to clipboard
5. **History tracking** → ClipboardManager detects change → Creates ClipboardItem with window context → Adds to history
6. **User pastes** → ⌘V in IDE/docs → Screenshot appears instantly

### Key Design Patterns

- **Singleton pattern**: Both managers use `static let shared`
- **ObservableObject/Published**: ClipboardManager publishes state to SwiftUI
- **Timer-based polling**: Both clipboard monitoring and simulator detection use scheduled timers
- **AppKit + SwiftUI hybrid**: Uses NSWindow for floating window, NSHostingView to embed SwiftUI

## Common Tasks

### Modifying Screenshot Behavior
Edit `ScreenshotManager.swift`. The `screencapture` tool arguments:
- `-x`: No sound
- `-c`: Copy to clipboard
- `-i`: Interactive selection
- `-l<windowID>`: Capture specific window by ID
- Path argument: Save to file instead of clipboard

### Adjusting Floating Button Appearance
Edit `FloatingButtonView.swift`:
- Button size: `.frame(width:height:)` on Circle (line 25)
- Colors: `buttonColor` computed property (line 141)
- Icons: `buttonIcon` computed property (line 149)
- Tooltip text: `tooltipText` computed property (line 157)
- Animation: `showCaptureAnimation` state and `.scaleEffect()` modifier (lines 15, 27)

### Changing One-Click Behavior
Edit `FloatingButtonView.swift` → `performQuickCapture()` method (line 83):
- Current: Captures targeted window OR full screen
- To add custom behavior: Modify before `ScreenshotManager.shared.captureFullScreen()` call

### Modifying Window Filtering Logic
Edit `WindowManager.swift` → `refreshWindowList()` method (line 38):
- Current filters: Excludes own app, windows < 100x100px
- Add custom filters: Modify the logic that builds the `windows` array
- Exclude by name: Add conditions to `if ownerName.contains(...)`

### Changing Clipboard History Size
Edit `ClipboardManager.swift`: Modify `maxHistoryCount` property (currently 10)

### Adjusting Polling Intervals
Edit `ClipboardManager.swift`:
- Clipboard monitoring: `Timer.scheduledTimer(withTimeInterval: 0.5, ...)` (line 78)

### Customizing Hotkey Behavior
Edit `HotkeyRecorderView.swift`:
- **Add new keys**: Update `keyCodeToString()` method with additional key code mappings
- **Change validation**: Modify `saveHotkey()` to adjust modifier requirements
- **UI customization**: Modify the recording area appearance and feedback

### Managing Settings Persistence
Edit `SettingsManager.swift`:
- **Add new settings**: Add property keys to `Keys` enum, create getter/setter computed properties
- **Change defaults**: Modify default values in property getters
- **Reset functionality**: Use `resetAllSettings()` method or remove specific keys

### Debugging Settings
```swift
// Print current settings
let settings = SettingsManager.shared
print("Hotkey enabled: \(settings.hotkeyEnabled)")
print("Key code: \(settings.hotkeyKeyCode)")
print("Window ID: \(settings.selectedWindowID ?? 0)")

// Clear all settings for testing
SettingsManager.shared.resetAllSettings()
```

## Developer Workflow (Primary Use Case)

The app is designed for **zero-friction screenshot capture** during development. Typical workflow:

### Initial Setup (Once per session):
1. Launch FloatyClipshot → Floating button appears (drag it to your preferred location)
2. Open your target app (iOS Simulator, Android Emulator, browser, design tool, etc.)
3. **Right-click** floating button → Choose your target window from the list
4. Button turns **green** with scope icon → Ready to capture
5. (Optional) Enable "Global Hotkey" in the context menu for keyboard shortcuts

### Actual Usage (Repeated):
1. See something in your app you want to document?
2. **Option A**: **Click** the floating button → Instant screenshot to clipboard
3. **Option B**: Press **⌘⇧F8** (from anywhere) → Instant screenshot to clipboard
4. **⌘V** in your IDE, Notion, Slack, etc. → Done!

### Advanced Features:
- **Change target**: Right-click → Select different window
- **Full screen mode**: Right-click → Select "Full Screen (All Displays)"
- **Customize hotkey**: Right-click → "Change Hotkey..." → Press your desired key combination (must include modifier)
- **Clipboard history**: Right-click → Recent Clipboard → Select any previous capture
- **Save to file**: Right-click → Save to Desktop (if you need a file instead of clipboard)
- **Settings persistence**: Your window selection and hotkey settings are automatically saved and restored on app restart

### Why This Works:
- **No context switching** - Button stays on top of all windows, or use keyboard shortcut
- **No file management** - Direct to clipboard, no saving/finding/deleting files
- **Window targeting** - Capture exactly what you need, every time
- **One-click operation** - After setup, every capture is a single click or keypress
- **Draggable button** - Position it wherever is most convenient for your workflow
- **Global hotkey** - Capture from anywhere without moving your mouse

See TESTING_GUIDE.md for detailed manual testing procedures.

## Important Notes

- The app uses borderless window with `.floating` level to stay on top
- Window is movable by dragging the button itself (`isMovableByWindowBackground = true`)
- Simulator detection runs on background queue to avoid blocking UI
- ClipboardItem uses UUID for Identifiable conformance, not content hashing
- The app has no traditional menu bar presence, only the floating button
