#!/bin/bash

# Install to iPhone script for NotedCore
set -e

echo "📱 Installing NotedCore to iPhone..."

# Device ID for James' iPhone 16 Pro Max
DEVICE_ID="00008140-001A21E82253001C"

echo "🔧 Building for iPhone..."

# Build for iOS device with proper signing
xcodebuild \
    -project NotedCore.xcodeproj \
    -scheme NotedCore \
    -configuration Debug \
    -destination "id=$DEVICE_ID" \
    -derivedDataPath build \
    DEVELOPMENT_TEAM=529ZZJHQR4 \
    -allowProvisioningUpdates \
    build

echo "✅ Build complete"

# Install the app
echo "📲 Installing app to device..."

# Find the app bundle - look for the iOS build, not simulator
APP_PATH="build/Build/Products/Debug-iphoneos/NotedCore.app"

# Verify the app exists
if [ ! -d "$APP_PATH" ]; then
    # Fallback to finding it
    APP_PATH=$(find build/Build/Products -name "NotedCore.app" -type d | grep -v simulator | head -n 1)
fi

if [ -z "$APP_PATH" ]; then
    echo "❌ Could not find app bundle"
    exit 1
fi

echo "📦 Found app at: $APP_PATH"

# Install using devicectl
xcrun devicectl device install app \
    --device "$DEVICE_ID" \
    "$APP_PATH"

echo "🚀 Launching app..."
xcrun devicectl device process launch \
    --device "$DEVICE_ID" \
    --start-stopped com.jamesalford.NotedCore

echo "✅ NotedCore installed and launched on your iPhone!"
echo "📱 Check your phone to see the app running"