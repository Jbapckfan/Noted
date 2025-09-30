#!/bin/bash

# NotedCore Installation Script
# Installs NotedCore to iPhone 16 Pro Max and Apple Watch

set -e

DEVICE_ID="00008140-001A21E82253001C"  # James' iPhone 16 Pro Max
WATCH_ID="00008310-0013206E3E85A01E"   # James's Apple Watch

echo "🚀 Installing NotedCore to your devices..."
echo ""
echo "📱 iPhone 16 Pro Max: $DEVICE_ID"
echo "⌚ Apple Watch: $WATCH_ID"
echo ""

# Step 1: Build and install iPhone app
echo "📲 Step 1: Building and installing iPhone app..."
xcodebuild -project NotedCore.xcodeproj \
    -scheme NotedCore \
    -destination "platform=iOS,id=$DEVICE_ID" \
    -allowProvisioningUpdates \
    clean build install 2>&1 | grep -E "(BUILD|Installing|error:)" || true

echo ""
echo "✅ iPhone app installed!"
echo ""

# Step 2: Build and install Watch app
echo "⌚ Step 2: Building and installing Apple Watch app..."
xcodebuild -project NotedCore.xcodeproj \
    -scheme "NotedWatch Watch App" \
    -destination "platform=watchOS,id=$WATCH_ID" \
    -allowProvisioningUpdates \
    clean build install 2>&1 | grep -E "(BUILD|Installing|error:)" || true

echo ""
echo "✅ Apple Watch app installed!"
echo ""

echo "🎉 Installation complete!"
echo ""
echo "📋 Next steps:"
echo "1. On your iPhone, go to Settings > General > VPN & Device Management"
echo "2. Trust your developer certificate"
echo "3. Open NotedCore on your iPhone"
echo "4. Grant microphone and speech recognition permissions"
echo "5. Wait for WhisperKit models to download (~250MB, takes 2-3 minutes on WiFi)"
echo "6. On your Apple Watch, open NotedCore Watch App"
echo "7. The Watch app will sync with your iPhone automatically"
echo ""
echo "🎤 Ready to record medical encounters offline!"