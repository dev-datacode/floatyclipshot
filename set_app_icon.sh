#!/bin/bash

# FloatyClipshot - Set App Icon Script
# Converts an image to all required macOS icon sizes

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <image_file>"
    echo "Example: $0 ~/Desktop/icon.png"
    exit 1
fi

INPUT_IMAGE="$1"

if [ ! -f "$INPUT_IMAGE" ]; then
    echo "❌ Error: Image file not found: $INPUT_IMAGE"
    exit 1
fi

ICONSET_DIR="floatyclipshot/Assets.xcassets/AppIcon.appiconset"

echo "🎨 Converting image to macOS app icon..."
echo "📁 Source: $INPUT_IMAGE"
echo "📂 Destination: $ICONSET_DIR"

# Create temporary directory for icon generation
TEMP_DIR=$(mktemp -d)
echo "🔧 Using temp directory: $TEMP_DIR"

# Generate all required sizes using sips (macOS built-in tool)
echo ""
echo "🔄 Generating icon sizes..."

# 16x16
sips -z 16 16 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_16x16.png" > /dev/null 2>&1
echo "  ✅ 16x16"

# 32x32 (16x16@2x)
sips -z 32 32 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_16x16@2x.png" > /dev/null 2>&1
echo "  ✅ 32x32 (16@2x)"

# 32x32
sips -z 32 32 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_32x32.png" > /dev/null 2>&1
echo "  ✅ 32x32"

# 64x64 (32x32@2x)
sips -z 64 64 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_32x32@2x.png" > /dev/null 2>&1
echo "  ✅ 64x64 (32@2x)"

# 128x128
sips -z 128 128 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_128x128.png" > /dev/null 2>&1
echo "  ✅ 128x128"

# 256x256 (128x128@2x)
sips -z 256 256 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_128x128@2x.png" > /dev/null 2>&1
echo "  ✅ 256x256 (128@2x)"

# 256x256
sips -z 256 256 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_256x256.png" > /dev/null 2>&1
echo "  ✅ 256x256"

# 512x512 (256x256@2x)
sips -z 512 512 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_256x256@2x.png" > /dev/null 2>&1
echo "  ✅ 512x512 (256@2x)"

# 512x512
sips -z 512 512 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_512x512.png" > /dev/null 2>&1
echo "  ✅ 512x512"

# 1024x1024 (512x512@2x)
sips -z 1024 1024 "$INPUT_IMAGE" --out "$TEMP_DIR/icon_512x512@2x.png" > /dev/null 2>&1
echo "  ✅ 1024x1024 (512@2x)"

echo ""
echo "📝 Updating AppIcon.appiconset..."

# Copy all icons to the iconset directory
cp "$TEMP_DIR"/*.png "$ICONSET_DIR/"

# Create Contents.json with all image references
cat > "$ICONSET_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo "✅ App icon updated successfully!"
echo ""
echo "📦 Next steps:"
echo "   1. Rebuild the app: ./build_for_production.sh"
echo "   2. Or run from Xcode to see the new icon"
echo ""
echo "🎉 Done!"
