#!/bin/bash

# Build just the iOS app target
echo "Building NotedCore iOS app..."
xcodebuild -project NotedCore.xcodeproj \
           -target NotedCore \
           -sdk iphonesimulator \
           -configuration Debug \
           -derivedDataPath build \
           ONLY_ACTIVE_ARCH=YES \
           EXCLUDED_ARCHS="" \
           2>&1 | grep -E "(BUILD|SUCCEEDED|FAILED|error:)" | tail -20

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "Build completed, installing app..."
    
    # Find the app bundle
    APP_PATH=$(find build/Build/Products -name "NotedCore.app" -type d | head -1)
    
    if [ -n "$APP_PATH" ]; then
        # Install and launch
        DEVICE_ID="6EC407E4-CC64-4388-8C5C-1EB81D4C463E"
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"
        xcrun simctl launch "$DEVICE_ID" com.jamesalford.NotedCore
        echo "App launched on simulator!"
    else
        echo "Could not find app bundle"
    fi
else
    echo "Build failed"
fi
