#!/bin/bash

echo "Testing NotedCore build..."

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project NotedCore.xcodeproj -scheme NotedCore

# Build for simulator
echo "Building for iOS Simulator..."
xcodebuild -project NotedCore.xcodeproj \
    -scheme NotedCore \
    -destination 'platform=iOS Simulator,id=1246CF7A-38EA-460D-AE57-E7155B891D0D' \
    -configuration Debug \
    build 2>&1 | tee build_output.txt

# Check if build succeeded
if grep -q "BUILD SUCCEEDED" build_output.txt; then
    echo "✅ Build succeeded!"
    echo "You can now run the app in Xcode"
else
    echo "❌ Build failed. Check build_output.txt for details"
    echo "Most recent errors:"
    grep "error:" build_output.txt | tail -10
fi