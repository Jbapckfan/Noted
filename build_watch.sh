#!/bin/bash

# Create app bundle structure
mkdir -p WatchTestApp.app

# Create minimal Info.plist
cat > WatchTestApp.app/Info.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>WatchTestApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.noted.watchtest</string>
    <key>CFBundleName</key>
    <string>NotedCore</string>
    <key>CFBundleDisplayName</key>
    <string>NotedCore</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>MinimumOSVersion</key>
    <string>10.0</string>
    <key>UIDeviceFamily</key>
    <array>
        <integer>4</integer>
    </array>
    <key>WKWatchKitApp</key>
    <true/>
</dict>
</plist>
EOF

# Copy executable
cp WatchTestApp WatchTestApp.app/

# Install to simulator
xcrun simctl install "E90662B4-9B55-44D5-945B-B11EEB44413D" WatchTestApp.app

echo "Watch app installed. Launching..."
xcrun simctl launch "E90662B4-9B55-44D5-945B-B11EEB44413D" com.noted.watchtest