#!/bin/bash

# Force install to iPhone when Xcode is being difficult
set -e

echo "🔧 Forcing iPhone installation..."

# Kill Xcode to reset its state
echo "📱 Resetting Xcode state..."
killall Xcode 2>/dev/null || true
sleep 2

# Clear derived data
echo "🗑️ Clearing build cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/NotedCore-*

# Device ID for your iPhone
DEVICE_ID="00008140-001A21E82253001C"

echo "🏗️ Building NotedCore for iPhone..."

# Build specifically for iOS
xcodebuild \
    -project NotedCore.xcodeproj \
    -target NotedCore \
    -configuration Debug \
    -sdk iphoneos \
    -arch arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    AD_HOC_CODE_SIGNING_ALLOWED=YES \
    DEVELOPMENT_TEAM="" \
    -derivedDataPath ./build_iphone

echo "✅ Build complete"

# Find the app
APP_PATH="./build_iphone/Build/Products/Debug-iphoneos/NotedCore.app"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at expected location"
    echo "Looking for app..."
    find ./build_iphone -name "*.app" -type d
    exit 1
fi

echo "📦 Found app at: $APP_PATH"

# Install using ios-deploy (alternative method)
if command -v ios-deploy &> /dev/null; then
    echo "📲 Installing with ios-deploy..."
    ios-deploy --id "$DEVICE_ID" --bundle "$APP_PATH"
else
    echo "📲 Installing with devicectl..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"
fi

echo "✅ Installation complete!"
echo ""
echo "🎯 Now opening Xcode with the correct configuration..."

# Create a workspace settings file to force iOS target
mkdir -p NotedCore.xcodeproj/project.xcworkspace/xcuserdata/$(whoami)/
cat > NotedCore.xcodeproj/project.xcworkspace/xcuserdata/$(whoami)/WorkspaceSettings.xcsettings << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>BuildLocationStyle</key>
    <string>UseAppPreferences</string>
    <key>CustomBuildLocationType</key>
    <string>RelativeToDerivedData</string>
    <key>DerivedDataLocationStyle</key>
    <string>Default</string>
    <key>ShowSharedSchemesAutomaticallyEnabled</key>
    <true/>
</dict>
</plist>
EOF

# Open Xcode with the project
open -a Xcode NotedCore.xcodeproj

echo ""
echo "📱 In Xcode:"
echo "1. Wait for it to fully load"
echo "2. Click Product menu → Scheme → Edit Scheme"
echo "3. In the 'Run' section, set 'Destination' to 'Any iOS Device'"
echo "4. Close the scheme editor"
echo "5. Your iPhone should now appear in the device list"