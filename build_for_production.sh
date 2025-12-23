#!/bin/bash

# FloatyClipshot Production Build Script
# Version 2.0 - Production Ready with Code Signing
# This script builds the app in Release configuration with proper signing

set -e  # Exit on error

APP_NAME="floatyclipshot"
PROJECT_NAME="floatyclipshot.xcodeproj"
SCHEME_NAME="floatyclipshot"

echo "🔨 Building FloatyClipshot for production..."
echo "   Version: 2.0 (Production Build)"
echo ""

# Clean extended attributes to prevent signing errors
echo "🧹 Cleaning extended attributes..."
xattr -cr . 2>/dev/null || true

# Clean previous builds
echo ""
echo "🧹 Cleaning previous builds..."
xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME_NAME" -configuration Release clean 2>/dev/null || true

# Build the app with automatic signing
echo ""
echo "🔐 Building with automatic signing..."
echo "🏗️  Building Release configuration..."
xcodebuild -project "$PROJECT_NAME" \
           -scheme "$SCHEME_NAME" \
           -configuration Release \
           CODE_SIGN_STYLE=Automatic \
           build

# Find the built app
BUILD_DIR=$(xcodebuild -project "$PROJECT_NAME" -scheme "$SCHEME_NAME" -configuration Release -showBuildSettings 2>/dev/null | grep " BUILD_DIR" | sed 's/[ ]*BUILD_DIR = //')
APP_PATH="$BUILD_DIR/Release/$APP_NAME.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built app not found at $APP_PATH"
    exit 1
fi

echo ""
echo "✅ Build successful!"
echo "📦 App location: $APP_PATH"

# Verify code signature
echo ""
echo "🔐 Verifying code signature..."
if codesign --verify --deep --strict "$APP_PATH" 2>/dev/null; then
    echo "   ✅ App is properly signed"
    SIGN_STATUS=$(codesign -dv "$APP_PATH" 2>&1 | grep "Authority" | head -1)
    echo "   $SIGN_STATUS"
else
    echo "   ⚠️  App is unsigned or ad-hoc signed"
    echo "   Users may need to right-click → Open on first launch"
fi

# Ask user if they want to install to /Applications
echo ""
read -p "📲 Install to /Applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Kill the app if it's running
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1

    # Remove old version if exists
    if [ -d "/Applications/$APP_NAME.app" ]; then
        echo "🗑️  Removing old version..."
        rm -rf "/Applications/$APP_NAME.app"
    fi

    # Copy new version
    echo "📋 Copying to /Applications..."
    cp -R "$APP_PATH" /Applications/

    echo "✅ Installation complete!"

    # Ask if they want to launch it
    read -p "🚀 Launch FloatyClipshot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open "/Applications/$APP_NAME.app"
        echo "✨ FloatyClipshot is now running!"
    fi
else
    echo "📍 App ready at: $APP_PATH"
    echo "   You can manually copy it to /Applications or anywhere else"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Production Build Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Encryption: Enabled by default"
echo "⚡ Performance: Optimized (100ms clipboard detection)"
echo "🛡️  Security: Sensitive data auto-purge (60 min default)"
echo ""
echo "⚠️  Note: If the hotkey doesn't work:"
echo "    Go to System Settings > Privacy & Security > Accessibility"
echo "    Toggle 'floatyclipshot' OFF and ON again."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
