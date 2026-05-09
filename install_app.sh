#!/bin/bash

# 1. Build the release binary
echo "Building Orchard..."
swift build -c release

# 2. Create the App bundle folders
echo "Creating App Bundle..."
mkdir -p build/Orchard.app/Contents/MacOS
mkdir -p build/Orchard.app/Contents/Resources

# 3. Copy the compiled binary
cp $(swift build -c release --show-bin-path)/orchard build/Orchard.app/Contents/MacOS/orchard

# 4. Copy the Info.plist
cp Info.plist build/Orchard.app/Contents/

# 5. Move to Applications folder
echo "Moving Orchard.app to ~/Applications/"
mkdir -p ~/Applications
cp -R build/Orchard.app ~/Applications/

echo "✅ Orchard installed to ~/Applications/Orchard.app!"
echo "Note: If you have an AppIcon.icns, place it in build/Orchard.app/Contents/Resources/AppIcon.icns"
