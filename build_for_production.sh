#!/bin/bash

# FloatyClipshot Production Build Script
# This script builds the app in Release configuration and copies it to Applications

set -e  # Exit on error

echo "🔨 Building FloatyClipshot for production..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release clean

# Build the app
echo "🏗️  Building Release configuration..."
xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release build

# Find the built app
BUILD_DIR=$(xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release -showBuildSettings | grep " BUILD_DIR" | sed 's/[ ]*BUILD_DIR = //')
APP_PATH="$BUILD_DIR/Release/floatyclipshot.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "✅ Build successful!"
echo "📦 App location: $APP_PATH"

# Ask user if they want to install to /Applications
read -p "📲 Install to /Applications? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Kill the app if it's running
    killall floatyclipshot 2>/dev/null || true

    # Remove old version if exists
    if [ -d "/Applications/floatyclipshot.app" ]; then
        echo "🗑️  Removing old version..."
        rm -rf /Applications/floatyclipshot.app
    fi

    # Copy new version
    echo "📋 Copying to /Applications..."
    cp -R "$APP_PATH" /Applications/

    echo "✅ Installation complete!"
    echo "🚀 You can now launch FloatyClipshot from /Applications"

    # Ask if they want to launch it
    read -p "🚀 Launch FloatyClipshot now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        open /Applications/floatyclipshot.app
        echo "✨ FloatyClipshot is now running!"
    fi
else
    echo "📍 App ready at: $APP_PATH"
    echo "   You can manually copy it to /Applications or anywhere else"
fi
