#!/bin/bash

echo "🚀 NotedCore Launch & Test Script"
echo "=================================="

# Kill any existing app instance
echo "📱 Terminating existing app..."
xcrun simctl terminate booted com.jamesalford.NotedCore 2>/dev/null || true

# Build the app
echo "🔨 Building app..."
xcodebuild -scheme NotedCore \
    -sdk iphonesimulator \
    -configuration Debug \
    -quiet \
    build

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Install on simulator
echo "📲 Installing on simulator..."
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/NotedCore-*/Build/Products/Debug-iphonesimulator -name "NotedCore.app" | head -1)
xcrun simctl install booted "$APP_PATH"

# Grant permissions proactively
echo "🔓 Granting permissions..."
xcrun simctl privacy booted grant microphone com.jamesalford.NotedCore || true
xcrun simctl privacy booted grant speech-recognition com.jamesalford.NotedCore 2>/dev/null || true

# Launch the app
echo "🎯 Launching NotedCore..."
xcrun simctl launch booted com.jamesalford.NotedCore

echo ""
echo "✅ App launched successfully!"
echo ""
echo "📋 Testing Checklist:"
echo "  1. ✅ App should be running on simulator"
echo "  2. 🎤 Tap the microphone button to start recording"
echo "  3. 🔔 You should see a permission dialog (if first time)"
echo "  4. ✅ Grant microphone permission"
echo "  5. 🗣️ Speak clearly into your Mac's microphone"
echo "  6. 📝 Transcription should appear in real-time"
echo ""
echo "🔍 Debug Info:"
echo "  - Check Xcode console for debug output"
echo "  - Look for '🎤 Processing audio buffer' messages"
echo "  - Look for '✅ Got transcription text' messages"
echo "  - CoreAppState.transcriptionText is now connected to UI"
echo ""
echo "🚨 If no transcription appears:"
echo "  1. Check Xcode console for error messages"
echo "  2. Ensure microphone permission was granted"
echo "  3. Try speaking louder/clearer"
echo "  4. Check that WhisperKit model is loading"