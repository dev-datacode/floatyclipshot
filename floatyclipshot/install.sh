#!/bin/bash

# FloatyClipshot Installer Script
# Version 2.0 - Production Ready with Code Signing

APP_NAME="floatyclipshot"
PROJECT_NAME="floatyclipshot"
SCHEME_NAME="floatyclipshot"
BUILD_DIR="/tmp/floatyclipshot_build_output"
INSTALL_DIR="/Applications"

echo "🚀 Starting FloatyClipshot Installer..."
echo "   Version: 2.0 (Production Build)"

# 1. Kill running instance
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "🛑 Killing running instance..."
    pkill -x "$APP_NAME"
    sleep 1
fi

# 2. Build the project
echo "🔨 Building project..."
# Navigate to project root if script is run from inside
if [ -d "floatyclipshot.xcodeproj" ]; then
    PROJECT_PATH="floatyclipshot.xcodeproj"
elif [ -d "../floatyclipshot.xcodeproj" ]; then
    PROJECT_PATH="../floatyclipshot.xcodeproj"
elif [ -d "floatyclipshot/floatyclipshot.xcodeproj" ]; then
    PROJECT_PATH="floatyclipshot/floatyclipshot.xcodeproj"
else
    echo "❌ Error: Could not find floatyclipshot.xcodeproj"
    exit 1
fi

# Clean build directory
rm -rf "$BUILD_DIR"

# Clean extended attributes to prevent signing errors
xattr -cr .

# Build with automatic signing (let Xcode handle it)
# For distribution, configure proper signing in Xcode project settings
echo "🔐 Building with automatic signing..."

xcodebuild -project "$PROJECT_PATH" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           -derivedDataPath "$BUILD_DIR" \
           CODE_SIGN_STYLE=Automatic \
           build > /tmp/floatyclipshot_build.log 2>&1

if [ $? -ne 0 ]; then
    echo "❌ Build Failed! Check /tmp/floatyclipshot_build.log for details."
    tail -20 /tmp/floatyclipshot_build.log
    exit 1
fi

echo "✅ Build successful!"

# 3. Install
APP_SOURCE="$BUILD_DIR/Build/Products/Release/$APP_NAME.app"

if [ ! -d "$APP_SOURCE" ]; then
    echo "❌ Error: App bundle not found at $APP_SOURCE"
    exit 1
fi

echo "📦 Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$APP_SOURCE" "$INSTALL_DIR/"

# 4. Verify code signature
echo "🔐 Verifying code signature..."
if codesign --verify --deep --strict "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null; then
    echo "   ✅ App is properly signed"
    SIGN_STATUS=$(codesign -dv "$INSTALL_DIR/$APP_NAME.app" 2>&1 | grep "Authority" | head -1)
    echo "   $SIGN_STATUS"
else
    echo "   ⚠️  App is unsigned or ad-hoc signed"
    echo "   Users may need to right-click → Open on first launch"
fi

# 5. Launch
echo "🚀 Launching app..."
open "$INSTALL_DIR/$APP_NAME.app"

echo "
🎉 Installation Complete!

📋 Version: 2.0 (Production Build)
🔐 Encryption: Enabled by default
⚡ Performance: Optimized (100ms clipboard detection)

👉 Usage:
1. Open your terminal (Terminal, iTerm2, Cursor, VS Code).
2. Go to your project directory.
3. Press Cmd+Shift+B to capture and paste the screenshot path.

⚠️  Note: If the hotkey doesn't work:
    Go to System Settings > Privacy & Security > Accessibility
    Toggle 'floatyclipshot' OFF and ON again.
"
