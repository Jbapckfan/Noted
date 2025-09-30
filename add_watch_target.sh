#!/bin/bash

# Create Watch App directory structure
mkdir -p "NotedWatch Watch App"

# Open Xcode to add the Watch target
echo "Opening Xcode to add Watch app target..."
echo ""
echo "MANUAL STEPS REQUIRED:"
echo "1. In Xcode, go to File > New > Target"
echo "2. Select watchOS > App"
echo "3. Name it 'NotedWatch Watch App'"
echo "4. Set Bundle Identifier: com.noted.NotedCore.watchkitapp"
echo "5. Make sure 'Include Notification Scene' is unchecked"
echo "6. Click Finish"
echo ""
echo "The Watch app code is ready in 'NotedWatch Watch App/NotedWatchApp.swift'"

open NotedCore.xcodeproj