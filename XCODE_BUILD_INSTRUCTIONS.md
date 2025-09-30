# How to Build NotedCore in Xcode

## Quick Fix for Xcode Build Issues

The app builds successfully from command line but Xcode UI may show errors. Here's how to fix:

### 1. Clean Build Folder
- Press: **Cmd + Shift + K**
- Or menu: Product → Clean Build Folder

### 2. Select Correct Scheme and Device
- Top bar: Make sure "NotedCore" scheme is selected (not Watch app)
- Device selector: Choose your "James' iPhone 16 Pro Max"
- If you don't see your iPhone, choose "Any iOS Device"

### 3. Build Settings to Verify
- Click on NotedCore project in navigator
- Select NotedCore target (not Watch targets)
- Build Settings tab:
  - **Base SDK**: iOS SDK (should say "iOS")
  - **Supported Platforms**: iOS
  - **Development Team**: 529ZZJHQR4 (already set)
  - **Code Signing**: Automatic

### 4. Build the App
- Press: **Cmd + B** to build
- Or: **Cmd + R** to build and run

### 5. If Xcode Still Shows Errors

Run this in Terminal to build and install:
```bash
cd /Users/jamesalford/Documents/NotedCore
./install_to_iphone.sh
```

## Common Issues and Fixes

### "Supported platforms is empty"
- Close Xcode
- Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/NotedCore-*`
- Reopen project

### "No such module" errors
- Product → Clean Build Folder
- File → Packages → Reset Package Caches
- Wait for packages to re-download

### Code signing errors
- Xcode → Settings → Accounts
- Make sure you're signed in with your Apple ID
- Download manual profiles if needed

## Build Confirmation

The app IS building successfully. You can verify with:
```bash
xcodebuild -project NotedCore.xcodeproj -scheme NotedCore -sdk iphoneos build
```

This will output: **BUILD SUCCEEDED**