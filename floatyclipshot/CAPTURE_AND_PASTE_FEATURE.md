# Capture & Paste Feature

## Overview

FloatyClipshot now supports **two independent global keyboard shortcuts**:

1. **Capture Hotkey** (Default: ⌘⇧F8) - Takes screenshot to clipboard only
2. **Capture & Paste Hotkey** (Default: ⌘⇧F10) - Takes screenshot AND auto-pastes it

## Use Case

The auto-paste feature is designed for rapid screenshot sharing during development workflows:

**Example Workflow:**
1. You're chatting with Claude Code about an iOS app bug
2. You see the issue in the iOS Simulator
3. Press **⌘⇧F10** (Capture & Paste)
4. Screenshot is instantly captured AND pasted into the chat
5. No need to manually ⌘V

## How It Works

### Architecture

**1. HotkeyManager** (HotkeyManager.swift)
- Now manages TWO global hotkeys independently
- Each hotkey has its own:
  - Enabled state (`isEnabled`, `pasteHotkeyEnabled`)
  - Key code (`keyCode`, `pasteKeyCode`)
  - Modifier keys (`modifiers`, `pasteModifiers`)
  - Event handler registration

**2. ScreenshotManager** (ScreenshotManager.swift)
- New method: `captureAndPaste()`
- Captures screenshot to clipboard (same as regular capture)
- Waits 0.2 seconds for clipboard to update
- Simulates ⌘V keypress using CGEvent API:
  ```swift
  // Command down → V down → V up → Command up
  cmdDown?.post(tap: .cghidEventTap)
  vDown?.post(tap: .cghidEventTap)
  vUp?.post(tap: .cghidEventTap)
  cmdUp?.post(tap: .cghidEventTap)
  ```

**3. SettingsManager** (SettingsManager.swift)
- Persists both hotkey configurations separately
- New properties:
  - `pasteHotkeyEnabled`
  - `pasteHotkeyKeyCode` (default: 109 = F10)
  - `pasteHotkeyModifiers` (default: Cmd+Shift)
- Settings survive app restarts

**4. UI Updates** (FloatingButtonView.swift, PasteHotkeyRecorderView.swift)
- Context menu now shows both hotkeys
- Separate "Change Hotkey" buttons for each
- Each hotkey can be enabled/disabled independently
- PasteHotkeyRecorderView: Dedicated UI for customizing paste hotkey

## User Guide

### Enabling the Feature

1. **Right-click** the floating button
2. Toggle **"Capture & Paste Hotkey"** to ON
3. Default hotkey is **⌘⇧F10**

### Customizing the Hotkey

1. Right-click the floating button
2. Click **"Change Paste Hotkey..."**
3. Click in the recording area
4. Press your desired key combination (must include a modifier: ⌘, ⇧, ⌥, or ⌃)
5. Click **"Save"**

### Using the Feature

**Option 1: Keyboard Shortcut**
- Press **⌘⇧F10** (or your custom hotkey) from anywhere
- Screenshot is captured from the targeted window (or full screen)
- Screenshot is automatically pasted into the active application

**Option 2: Manual Trigger**
- Currently only available via keyboard shortcut
- Future: Could add button action

### Window Targeting

The paste hotkey respects your window selection:
- If you've selected a specific window (e.g., iOS Simulator): Captures that window
- If no window selected: Captures full screen

## Technical Details

### Key Virtual Codes
- F8: 100
- F10: 109
- V: 0x09
- Command: 0x37

### CGEvent Paste Simulation
The auto-paste uses macOS's Quartz Event Services to synthesize keyboard events:
- Creates four separate CGEvents (Command down, V down, V up, Command up)
- Posts to `CGHIDEventTap` (global event stream)
- Works across all applications

### Timing
- Screenshot capture: Immediate
- Clipboard update wait: 0.2 seconds
- Paste simulation: Immediate after wait

### Hotkey Registration
- Uses Carbon API (`RegisterEventHotKey`)
- Each hotkey has unique ID (capture: 1, paste: 2)
- Event handlers differentiate by checking `EventHotKeyID.id`

## Files Modified

1. **HotkeyManager.swift**
   - Added paste hotkey properties and registration logic
   - New methods: `registerPasteHotkey()`, `unregisterPasteHotkey()`, `updatePasteHotkey()`
   - New display property: `pasteHotkeyDisplayString`

2. **ScreenshotManager.swift**
   - New method: `captureAndPaste()`
   - New private method: `simulatePaste()`
   - Import: `CoreGraphics`

3. **SettingsManager.swift**
   - New keys: `pasteHotkeyEnabled`, `pasteHotkeyKeyCode`, `pasteHotkeyModifiers`
   - New properties for paste hotkey
   - New methods: `savePasteHotkeySettings()`, `loadPasteHotkeySettings()`

4. **FloatingButtonView.swift**
   - Added `@State var showPasteHotkeyRecorder`
   - New context menu items for paste hotkey
   - New sheet for `PasteHotkeyRecorderView`

5. **PasteHotkeyRecorderView.swift** (NEW)
   - Dedicated UI for recording paste hotkey
   - Similar to HotkeyRecorderView but targets `pasteKeyCode`

## Known Limitations

1. **Requires Accessibility Permissions**
   - CGEvent paste simulation requires Accessibility access
   - User must grant permission in System Preferences

2. **Active Application Receives Paste**
   - Paste goes to whatever application has focus
   - User should ensure correct application is active before triggering

3. **No Visual Feedback for Auto-Paste**
   - Button animation shows for capture only
   - No indication that paste was triggered

## Future Enhancements

1. **Paste Confirmation Notification**
   - Show notification when auto-paste completes
   - Indicate target application

2. **Smart Application Detection**
   - Detect if chat/editor is active
   - Only auto-paste if appropriate target detected

3. **Paste Delay Configuration**
   - Allow user to adjust the 0.2s delay
   - Some applications may need more/less time

4. **Multiple Paste Targets**
   - Support pasting to specific applications
   - Queue paste for when target becomes active

## Testing Checklist

- [ ] Enable paste hotkey in context menu
- [ ] Press ⌘⇧F10 with chat window active
- [ ] Verify screenshot appears in chat
- [ ] Customize hotkey to different combination
- [ ] Verify custom hotkey works
- [ ] Disable paste hotkey, verify it stops working
- [ ] Re-enable, verify it works again
- [ ] Restart app, verify settings persist
- [ ] Test with different target windows (Simulator, browser, etc.)
- [ ] Test with full screen mode (no window selected)
- [ ] Test with multiple modifiers (⌘⌥F10, etc.)
- [ ] Verify regular capture hotkey (⌘⇧F8) still works independently

## Build Status

✅ **BUILD SUCCEEDED** (0 errors, 10 deprecation warnings)

The deprecation warnings are for NSUserNotification API (macOS 11.0+) and are unrelated to this feature.
