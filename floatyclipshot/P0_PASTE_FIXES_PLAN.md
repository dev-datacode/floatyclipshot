# P0 Fixes Plan: Capture & Paste Feature

## Executive Summary
Fixing 4 critical bugs identified in code review to make the feature production-ready.

**Estimated Time:** 2-3 hours
**Risk Level:** Medium (touching core functionality)
**Testing Required:** Extensive (permission denial, timing edge cases)

---

## Fix #1: Accessibility Permission Check
**File:** ScreenshotManager.swift
**Severity:** CRITICAL
**Lines Affected:** 58-82

### Current State
```swift
private func simulatePaste() {
    let cmdDown = CGEvent(...)
    cmdDown?.post(tap: .cghidEventTap)  // Silently fails without permission
}
```

### Fix Implementation
1. Add permission check method:
```swift
private func checkAccessibilityPermission() -> Bool {
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
    return AXIsProcessTrusted()
}
```

2. Check before posting events:
```swift
guard checkAccessibilityPermission() else {
    showAccessibilityPermissionAlert()
    return
}
```

3. Show helpful alert with steps:
```swift
private func showAccessibilityPermissionAlert() {
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = """
    Auto-paste requires Accessibility permission.

    Steps:
    1. Open System Preferences > Security & Privacy
    2. Click Privacy tab > Accessibility
    3. Click the lock to make changes
    4. Enable FloatyClipshot

    Or use ⌘⇧F8 to capture without auto-paste.
    """
    alert.addButton(withTitle: "Open System Preferences")
    alert.addButton(withTitle: "Cancel")

    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}
```

### Testing
- [ ] Test with permission denied (fresh install)
- [ ] Test with permission granted
- [ ] Verify alert shows correct steps
- [ ] Verify "Open System Preferences" button works
- [ ] Test fallback to regular capture

---

## Fix #2: Alert Deadlock in Hotkey Registration
**File:** HotkeyManager.swift
**Severity:** CRITICAL
**Lines Affected:** 228-239

### Current State
```swift
DispatchQueue.main.async { [weak self] in
    let alert = NSAlert()
    alert.runModal()  // ❌ Deadlock if app in background
}
```

### Fix Implementation
Apply the SAME fix we used in P0 for ClipboardManager:

```swift
DispatchQueue.main.async { [weak self] in
    guard let self = self else { return }

    if NSApplication.shared.isActive {
        // App in foreground - safe to show modal
        let alert = NSAlert()
        alert.messageText = "Paste Hotkey Registration Failed"
        alert.informativeText = "Could not register \(self.pasteHotkeyDisplayString). This hotkey may be in use by another application."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    } else {
        // App in background - use notification
        let notification = NSUserNotification()
        notification.title = "Paste Hotkey Registration Failed"
        notification.informativeText = "Could not register \(self.pasteHotkeyDisplayString)"
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }

    self.pasteHotkeyEnabled = false
}
```

### Testing
- [ ] Trigger hotkey conflict while app in background
- [ ] Verify notification shows (no freeze)
- [ ] Trigger hotkey conflict while app in foreground
- [ ] Verify alert shows normally
- [ ] Verify hotkey gets disabled in both cases

---

## Fix #3: CGEvent Error Handling
**File:** ScreenshotManager.swift
**Severity:** CRITICAL
**Lines Affected:** 58-82

### Current State
```swift
let cmdDown = CGEvent(...)
cmdDown?.post(...)  // Silently fails if nil
print("✅ Auto-pasted screenshot")  // Lies about success
```

### Fix Implementation
```swift
private func simulatePaste() -> Bool {
    // Check permission first
    guard checkAccessibilityPermission() else {
        showAccessibilityPermissionAlert()
        return false
    }

    // Create all events with error checking
    guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true),
          let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
          let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false),
          let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false) else {
        print("⚠️ Failed to create CGEvents for auto-paste")
        showPasteFailureNotification("Failed to create keyboard events. Please paste manually with ⌘V.")
        return false
    }

    // Set modifiers
    cmdDown.flags = .maskCommand
    vDown.flags = .maskCommand
    vUp.flags = .maskCommand

    // Post events
    cmdDown.post(tap: .cghidEventTap)
    vDown.post(tap: .cghidEventTap)
    vUp.post(tap: .cghidEventTap)
    cmdUp.post(tap: .cghidEventTap)

    print("✅ Auto-paste events posted")
    return true
}

private func showPasteFailureNotification(_ message: String) {
    DispatchQueue.main.async {
        if NSApplication.shared.isActive {
            let alert = NSAlert()
            alert.messageText = "Auto-Paste Failed"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        } else {
            let notification = NSUserNotification()
            notification.title = "Auto-Paste Failed"
            notification.informativeText = message
            notification.soundName = NSUserNotificationDefaultSoundName
            NSUserNotificationCenter.default.deliver(notification)
        }
    }
}
```

### Testing
- [ ] Simulate CGEvent creation failure (if possible)
- [ ] Verify error notification shows
- [ ] Verify user can paste manually
- [ ] Test with permission denied (should trigger alert)
- [ ] Test with permission granted (should succeed)

---

## Fix #4: Replace Fixed Delay with Clipboard Polling
**File:** ScreenshotManager.swift
**Severity:** HIGH
**Lines Affected:** 50-55

### Current State
```swift
runScreencapture(arguments: arguments) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        self.simulatePaste()  // ❌ Assumes clipboard ready
    }
}
```

### Fix Implementation
```swift
func captureAndPaste() {
    var arguments = ["-x", "-c"]

    // Window targeting (existing code)
    if let window = WindowManager.shared.selectedWindow {
        if WindowManager.shared.isWindowValid(window) {
            arguments.insert("-l\(window.id)", at: 0)
        } else {
            WindowManager.shared.clearSelection()
            showWindowClosedAlert()
        }
    }

    // Capture current pasteboard state
    let pasteboard = NSPasteboard.general
    let initialChangeCount = pasteboard.changeCount

    runScreencapture(arguments: arguments) {
        // Poll clipboard until it changes or timeout
        self.waitForClipboardUpdate(
            initialChangeCount: initialChangeCount,
            timeout: 2.0,
            completion: { success in
                if success {
                    // Clipboard updated, safe to paste
                    DispatchQueue.main.async {
                        let pasteSuccess = self.simulatePaste()
                        if pasteSuccess {
                            print("✅ Screenshot captured and pasted")
                        }
                    }
                } else {
                    // Timeout - clipboard didn't update
                    DispatchQueue.main.async {
                        self.showPasteFailureNotification(
                            "Screenshot capture timed out. Image may be in clipboard - try pasting with ⌘V."
                        )
                    }
                }
            }
        )
    }
}

private func waitForClipboardUpdate(
    initialChangeCount: Int,
    timeout: TimeInterval,
    completion: @escaping (Bool) -> Void
) {
    let startTime = Date()
    let pollInterval: TimeInterval = 0.05  // Check every 50ms

    func poll() {
        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        // Check if clipboard updated
        if currentChangeCount > initialChangeCount {
            print("✅ Clipboard updated after \(Date().timeIntervalSince(startTime))s")
            completion(true)
            return
        }

        // Check timeout
        if Date().timeIntervalSince(startTime) >= timeout {
            print("⚠️ Clipboard polling timeout after \(timeout)s")
            completion(false)
            return
        }

        // Continue polling
        DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
            poll()
        }
    }

    // Start polling
    DispatchQueue.main.asyncAfter(deadline: .now() + pollInterval) {
        poll()
    }
}
```

### Benefits
- ✅ Works with large screenshots (waits as long as needed, up to 2s)
- ✅ No wasted time on fast systems (polls every 50ms)
- ✅ Verifies clipboard actually updated
- ✅ Clear timeout handling with user notification

### Testing
- [ ] Test with small screenshots (should be fast, <100ms)
- [ ] Test with large 4K screenshots (may take 500ms+)
- [ ] Test with very slow system
- [ ] Test timeout scenario (kill screencapture process)
- [ ] Verify no false timeouts on normal operation

---

## Additional Improvements (While We're Here)

### Extract Constants
```swift
private enum KeyCodes {
    static let command: UInt16 = 0x37
    static let v: UInt16 = 0x09
}

private enum Timing {
    static let clipboardPollInterval: TimeInterval = 0.05
    static let clipboardTimeout: TimeInterval = 2.0
}
```

### Add Cancellation Support
```swift
private var pendingPasteOperation: DispatchWorkItem?

func captureAndPaste() {
    // Cancel any pending paste
    pendingPasteOperation?.cancel()

    // Create cancellable work item
    let pasteWork = DispatchWorkItem {
        self.simulatePaste()
    }
    pendingPasteOperation = pasteWork

    // ... rest of implementation
}
```

---

## Testing Strategy

### Unit Testing (Manual)
1. **Permission Scenarios:**
   - [ ] Fresh install (no permission)
   - [ ] Permission denied
   - [ ] Permission granted
   - [ ] Permission revoked after grant

2. **Timing Scenarios:**
   - [ ] Small screenshot (100KB)
   - [ ] Large screenshot (10MB, 4K)
   - [ ] Very large screenshot (50MB, 8K)
   - [ ] Slow system (2012 MacBook)

3. **Edge Cases:**
   - [ ] Rapid hotkey presses (3x in 1 second)
   - [ ] App in background during capture
   - [ ] Hotkey conflict with other app
   - [ ] Clipboard full (many items)
   - [ ] Target app doesn't accept images

4. **Error Scenarios:**
   - [ ] screencapture process crash
   - [ ] CGEvent creation failure
   - [ ] Pasteboard access denied
   - [ ] Target window closed mid-capture

### Integration Testing
- [ ] Capture → Paste to Claude Code chat
- [ ] Capture → Paste to Slack
- [ ] Capture → Paste to Notes.app
- [ ] Capture → Paste to TextEdit
- [ ] Capture → Paste to Terminal (verify safe)

---

## Rollback Plan

If fixes introduce regressions:
1. Revert commit: `git revert HEAD`
2. Disable paste hotkey by default in SettingsManager
3. Add "Experimental" flag to UI
4. Document known issues

---

## Success Criteria

**Before Merge:**
- [ ] All P0 fixes implemented
- [ ] Zero silent failures
- [ ] Clear error messages for all failure modes
- [ ] Manual testing completed (all scenarios)
- [ ] No new bugs introduced
- [ ] Build succeeds (0 errors, acceptable warnings)

**After Merge:**
- [ ] Feature works with permission granted
- [ ] Clear guidance when permission denied
- [ ] No app freezes under any condition
- [ ] Accurate success/failure feedback
- [ ] Works on slow systems (verified)

---

## Timeline

**Phase 1:** Fix #1 + #2 (Alert issues) - 1 hour
**Phase 2:** Fix #3 (Error handling) - 30 minutes
**Phase 3:** Fix #4 (Clipboard polling) - 1 hour
**Phase 4:** Testing - 30 minutes
**Phase 5:** Documentation - 15 minutes

**Total:** ~3 hours 15 minutes

---

## Next Steps

1. ✅ Read this plan carefully
2. Implement Fix #1 (Accessibility permission)
3. Test Fix #1 thoroughly
4. Implement Fix #2 (Alert deadlock)
5. Test Fix #2 thoroughly
6. Implement Fix #3 (CGEvent errors)
7. Test Fix #3 thoroughly
8. Implement Fix #4 (Clipboard polling)
9. Test Fix #4 thoroughly
10. Full integration testing
11. Document all changes
12. Commit with detailed message
