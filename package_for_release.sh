#!/bin/bash

# FloatyClipshot Release Packaging Script
# Creates a distributable ZIP file for GitHub Releases and Homebrew Cask

set -e  # Exit on error

VERSION=${1:-"1.0.0"}  # Default version if not provided
APP_NAME="floatyclipshot"
RELEASE_DIR="release"

echo "📦 Packaging FloatyClipshot v$VERSION for release..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release clean

# Build the app in Release mode
echo "🏗️  Building Release configuration..."
xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release build

# Find the built app
BUILD_DIR=$(xcodebuild -project floatyclipshot.xcodeproj -scheme floatyclipshot -configuration Release -showBuildSettings | grep " BUILD_DIR" | sed 's/[ ]*BUILD_DIR = //')
APP_PATH="$BUILD_DIR/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "✅ Build successful!"

# Create release directory
mkdir -p "$RELEASE_DIR"

# Create ZIP archive (preferred for Homebrew Cask)
ZIP_NAME="${APP_NAME}-${VERSION}.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"

echo "📦 Creating ZIP archive..."
cd "$BUILD_DIR/Release"
zip -r -q "$OLDPWD/$ZIP_PATH" "${APP_NAME}.app"
cd "$OLDPWD"

# Calculate SHA256 for Homebrew Cask
SHA256=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "✅ Release package created successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Package: $ZIP_PATH"
echo "🔢 Version: $VERSION"
echo "🔐 SHA256:  $SHA256"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "1. Create a GitHub Release with tag v$VERSION"
echo "2. Upload $ZIP_PATH to the release"
echo "3. Update Homebrew Cask with the new SHA256 (above)"
echo ""
echo "GitHub Release URL will be:"
echo "https://github.com/hooshyar/floatyclipshot/releases/download/v$VERSION/$ZIP_NAME"
echo ""
