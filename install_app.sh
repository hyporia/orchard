#!/bin/bash
set -e

ASSETS="Sources/orchard/Assets.xcassets/AppIcon.appiconset"
ICONSET="build/AppIcon.iconset"
BUNDLE="build/Orchard.app"

# 1. Build the release binary
echo "Building Orchard..."
swift build -c release

# 2. Create the App bundle folders
echo "Creating App Bundle..."
mkdir -p "$BUNDLE/Contents/MacOS"
mkdir -p "$BUNDLE/Contents/Resources"

# 3. Copy the compiled binary
cp "$(swift build -c release --show-bin-path)/orchard" "$BUNDLE/Contents/MacOS/orchard"

# 4. Copy the Info.plist
cp Info.plist "$BUNDLE/Contents/"

# 5. Build AppIcon.icns from the asset catalog
echo "Generating AppIcon.icns..."
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

cp "$ASSETS/icon_16x16.png"    "$ICONSET/icon_16x16.png"
cp "$ASSETS/icon_16x16@2x.png" "$ICONSET/icon_16x16@2x.png"
cp "$ASSETS/icon_32x32.png"    "$ICONSET/icon_32x32.png"
cp "$ASSETS/icon_32x32@2x.png" "$ICONSET/icon_32x32@2x.png"
cp "$ASSETS/icon_128x128.png"    "$ICONSET/icon_128x128.png"
cp "$ASSETS/icon_128x128@2x.png" "$ICONSET/icon_128x128@2x.png"
cp "$ASSETS/icon_256x256.png"    "$ICONSET/icon_256x256.png"
cp "$ASSETS/icon_256x256@2x.png" "$ICONSET/icon_256x256@2x.png"
cp "$ASSETS/icon_512x512.png"    "$ICONSET/icon_512x512.png"
cp "$ASSETS/icon.png"            "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$BUNDLE/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

# 6. Install to ~/Applications
echo "Moving Orchard.app to ~/Applications/"
mkdir -p ~/Applications
rm -rf ~/Applications/Orchard.app
cp -R "$BUNDLE" ~/Applications/Orchard.app

echo "Done. Orchard installed to ~/Applications/Orchard.app"
