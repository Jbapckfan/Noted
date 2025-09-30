#!/bin/bash
echo "Building Watch app..."
xcodebuild -project NotedCore.xcodeproj \
  -scheme "NotedWatch Watch App" \
  -sdk watchos \
  -configuration Debug \
  -derivedDataPath build_watch \
  CODE_SIGNING_ALLOWED=NO \
  2>&1 | tail -20

echo ""
echo "Watch app needs to be installed through Xcode directly"
echo "Or rebuild the iPhone app to embed the Watch app"
