# 🎯 Enhanced Multi-Simulator Detection - How It Works

## 🤔 **Your Question: "How does it know which one is which?"**

Great question! When **both** iOS Simulator and Android Emulator are running simultaneously, the app now uses intelligent detection to determine which one is **primary/active**.

## 🧠 **Smart Detection Logic**

### **1. Individual Detection First**
```swift
// Step 1: Detect what's running
let iosRunning = isIOSSimulatorRunning()      // Checks for Simulator.app, SimulatorKit
let androidRunning = isAndroidEmulatorRunning() // Checks for qemu+android, emulator-*
```

### **2. Single Simulator (Simple Case)**
- **Only iOS running** → Button turns **🔵 Blue** with iPhone icon
- **Only Android running** → Button turns **🟢 Green** with phone icon
- **Neither running** → Button stays **⚫ Black** with camera icon

### **3. Both Simulators (Smart Detection)**
When both are detected, the app determines the **"primary"** one using:

#### **Strategy 1: Frontmost Application Detection**
```swift
// Uses AppleScript to check which app is currently focused
osascript -e "tell application \"System Events\" to get name of first application process whose frontmost is true"

// If result contains:
"Simulator" → iOS Simulator is primary ✅
"qemu" or "emulator" or "Android" → Android Emulator is primary ✅
```

#### **Strategy 2: Fallback Preference**
- If neither simulator is frontmost (e.g., you're focused on Xcode)
- **Defaults to iOS Simulator** as primary

## 🎨 **Visual Feedback for Multiple Simulators**

### **Button Colors:**
| State | Color | Icon | Meaning |
|-------|-------|------|---------|
| **Both Running** | 🟣 **Purple** | `apps.iphone` | Multiple simulators active |
| **iOS Primary** | 🔵 **Blue** | `iphone` | iOS Simulator is primary |
| **Android Primary** | 🟢 **Green** | `smartphone` | Android Emulator is primary |

### **Menu Display:**
```
🔄 Both Simulators Active
Primary: 📱 iOS
─────────────
Capture Full Screen to Clipboard
Capture Region to Clipboard
...
```

## 🎯 **How This Helps Your Workflow**

### **Scenario: Cross-Platform Testing**
1. **Start iOS Simulator** → Button: 🔵 Blue
2. **Start Android Emulator** → Button: 🟣 Purple (both active)
3. **Click on iOS Simulator window** → Primary switches to iOS
4. **Take screenshot** → Labeled as "📷 📱 iOS Screenshot"
5. **Click on Android Emulator** → Primary switches to Android  
6. **Take screenshot** → Labeled as "📷 🤖 Android Screenshot"

### **Smart Context Switching**
- **Screenshots automatically tagged** with the currently active simulator
- **Visual confirmation** of which platform you're capturing
- **No manual switching** required - follows your window focus!

## 🔧 **Technical Implementation**

### **Process Detection Patterns**:
```swift
// iOS Simulator Detection
- "Simulator.app" (main app)
- "SimulatorKit" (framework)  
- "com.apple.iphonesimulator" (bundle ID)

// Android Emulator Detection
- "qemu" + ("android" || "emulator") (QEMU virtualization)
- "emulator-*" (emulator process names)
- "Android Emulator" (app name)
- "qemu-system" (system emulator)
```

### **Update Frequency**:
- **Simulator detection**: Every 3 seconds (lightweight)
- **Clipboard monitoring**: Every 0.5 seconds (responsive)
- **Window focus detection**: On-demand when both are running

## 🎉 **Benefits**

### **✅ Intelligent Priority**
- Always knows which simulator you're actively using
- No confusion about screenshot context
- Visual confirmation through button color/icon

### **✅ Comprehensive Detection**  
- Works with any iOS Simulator version
- Supports various Android emulator configurations
- Handles edge cases gracefully

### **✅ Zero Manual Work**
- Automatically switches based on your focus
- Screenshots tagged with correct platform
- Clear visual feedback at all times

## 🧪 **Testing the Multi-Simulator Detection**

1. **Start both simulators** → Button should turn 🟣 Purple
2. **Menu should show "🔄 Both Simulators Active"**
3. **Click on iOS Simulator** → Primary should switch to iOS
4. **Click on Android Emulator** → Primary should switch to Android  
5. **Take screenshots** → Should be tagged with correct platform

**Your FloatyClipshot now handles complex multi-platform development workflows perfectly!** 🎯

## 💡 **Pro Tip**
The **Purple button** is your visual cue that you have multiple development environments ready - perfect for cross-platform testing and comparison screenshots!