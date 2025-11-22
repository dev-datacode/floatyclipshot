# FloatyClipshot - Manual Testing Guide

## 🚀 How to Test Your Enhanced Floating Screenshot App

### **Build & Run**
1. In Xcode, press `⌘R` to build and run
2. The app should launch with a **larger** floating camera button

### **Basic Functionality Tests**

#### ✅ **Test 1: Enhanced Floating Button Appearance**
- **Expected**: **Larger** black circular button with filled camera icon (80px vs 56px)
- **Expected**: Button should be draggable around the screen
- **Expected**: Button stays on top of other windows
- **Expected**: More prominent appearance for easier clicking

#### ✅ **Test 2: Menu Functionality**
- **Action**: Click the floating button
- **Expected**: Menu appears with these options:
  - "Capture Full Screen to Clipboard"
  - "Capture Region to Clipboard" 
  - **NEW**: "Recent Clipboard (Paste Memory)" (when you have clipboard history)
  - "Quit"

#### ✅ **Test 3: Clipboard Screenshots**
1. **Full Screen to Clipboard**:
   - Click button → "Capture Full Screen to Clipboard"
   - Open any app (like TextEdit) and paste (⌘V)
   - **Expected**: Full screenshot appears

2. **Region to Clipboard**:
   - Click button → "Capture Region to Clipboard"
   - Drag to select a region of the screen
   - Open any app and paste (⌘V)
   - **Expected**: Selected region appears

#### ✅ **Test 4: NEW - Clipboard Memory Feature** 🆕
1. **Take multiple screenshots**:
   - Take 2-3 screenshots (full screen or region)
   - Click the floating button
   - **Expected**: "Recent Clipboard (Paste Memory)" submenu appears

2. **Access clipboard history**:
   - Click "Recent Clipboard (Paste Memory)"
   - **Expected**: See list of recent items with timestamps
   - **Expected**: Screenshots show as "📷 Screenshot [time]"
   - **Expected**: Text items show as "📝 [preview]"

3. **Restore previous items**:
   - Click on any item in the history
   - Go to another app and paste (⌘V)
   - **Expected**: The selected item is restored to clipboard

4. **Clear history**:
   - In clipboard memory submenu, click "Clear History"
   - **Expected**: History is cleared

#### ✅ **Test 5: Simulator/Emulator Screenshots** 🎯
Perfect for your main use case!

1. **Open iOS Simulator or Android Emulator**
2. **Position the floating button** where it won't interfere
3. **Take region screenshots** of specific parts of the simulator
4. **Use clipboard memory** to switch between different screenshots
5. **Paste into documentation, bug reports, etc.**

#### ✅ **Test 6: Multi-Space Behavior**
- Switch to different Spaces/Desktops
- **Expected**: Larger floating button appears on all spaces
- Try with full-screen apps
- **Expected**: Button still accessible and more visible

#### ✅ **Test 7: Quit Functionality**
- Click button → "Quit" (or press ⌘Q while menu is open)
- **Expected**: App closes completely

### **Troubleshooting**

#### 🚨 **If screenshots don't work**:
- Check System Preferences → Security & Privacy → Privacy → Screen Recording
- Make sure your app has permission to record the screen

#### 🚨 **If clipboard memory doesn't work**:
- The app monitors clipboard changes every 0.5 seconds
- Try taking a screenshot and wait a moment before checking the menu

#### 🚨 **If button doesn't appear**:
- Check Console app for error messages
- Make sure screencapture is at `/usr/sbin/screencapture` (run `which screencapture` in Terminal)

### **Success Criteria** ✅
- [ ] **Larger** floating button appears and is draggable
- [ ] Menu opens when clicked
- [ ] Clipboard captures work and can be pasted
- [ ] **NEW**: Clipboard memory shows recent items
- [ ] **NEW**: Can restore previous clipboard items
- [ ] **NEW**: Perfect for simulator/emulator screenshots
- [ ] Button works across all Spaces
- [ ] App can be quit cleanly
- [ ] No crashes or error dialogs

### **Simulator/Emulator Workflow** 🎯
Your ideal workflow:
1. **Open simulator/emulator**
2. **Take multiple region screenshots** of different states
3. **Access clipboard memory** to switch between screenshots
4. **Paste the right screenshot** into documentation/reports
5. **Clear history** when done with a session

---

**Your enhanced app is ready when all these tests pass!** 🎉