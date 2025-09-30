#!/bin/bash

echo "🔧 Fixing NotedCore build issues..."

# 1. Kill any existing build processes
echo "Stopping any running builds..."
killall xcodebuild 2>/dev/null || true

# 2. Clean DerivedData
echo "Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/NotedCore-*

# 3. Clean SPM cache
echo "Cleaning Swift Package Manager cache..."
rm -rf .swiftpm
rm -rf ~/Library/Caches/org.swift.swiftpm

# 4. Remove Package.resolved to force fresh resolution
echo "Removing Package.resolved..."
rm -f NotedCore.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# 5. Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project NotedCore.xcodeproj -scheme NotedCore -quiet

# 6. Resolve packages
echo "Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project NotedCore.xcodeproj -scheme NotedCore

# 7. Build the project
echo "Building NotedCore..."
xcodebuild -project NotedCore.xcodeproj \
           -scheme NotedCore \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           build

echo "✅ Build process complete!"