# Installation Guide for NotedCore

## Prerequisites

### System Requirements
- **macOS**: 13.0 (Ventura) or later for development
- **Xcode**: 15.0 or later
- **iOS Device/Simulator**: iOS 16.0 or later
- **Storage**: 2GB free space (for app and AI models)
- **RAM**: 4GB minimum (8GB recommended for development)

### Development Tools
- Git
- Swift Package Manager (included with Xcode)
- CocoaPods (optional, for additional dependencies)

## Step 1: Clone the Repository

```bash
# Clone the repository
git clone https://github.com/yourusername/NotedCore.git
cd NotedCore

# Or if you have an existing fork
git clone https://github.com/[your-username]/NotedCore.git
cd NotedCore
```

## Step 2: Open in Xcode

```bash
# Open the project
open NotedCore.xcodeproj

# Or use Xcode directly
# File → Open → Navigate to NotedCore.xcodeproj
```

## Step 3: Configure Swift Packages

The project uses Swift Package Manager for dependencies. Xcode should automatically resolve them, but if needed:

1. In Xcode: **File → Packages → Resolve Package Versions**
2. Or from command line:
```bash
xcodebuild -resolvePackageDependencies
```

### Required Packages
- **WhisperKit**: On-device speech recognition
- **MLX Swift**: Machine learning framework
- **Swift Argument Parser**: Command-line interface support
- **Swift Collections**: Advanced data structures

## Step 4: Download AI Models

The app requires WhisperKit models for transcription:

```bash
# Models will be downloaded automatically on first run
# Or manually download:
cd NotedCore
./Scripts/download_models.sh
```

### Model Options
- **base.en**: Smallest, fastest (39M parameters)
- **small.en**: Balanced performance (74M parameters) - RECOMMENDED
- **medium.en**: Higher accuracy (244M parameters)

## Step 5: Configure Build Settings

### Select Target Device
1. In Xcode, select your target device from the scheme selector
2. Choose between:
   - Your connected iOS device
   - iOS Simulator (iPhone 14 Pro or later recommended)

### Build Configuration
1. Select **NotedCore** scheme
2. Choose configuration:
   - **Debug**: For development and testing
   - **Release**: For production builds

## Step 6: Build and Run

### From Xcode
1. Select your target device
2. Click the **Run** button (▶️) or press `Cmd+R`
3. Wait for build to complete

### From Command Line
```bash
# Build for iOS Simulator
xcodebuild -project NotedCore.xcodeproj \
           -scheme NotedCore \
           -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
           build

# Build for device (requires provisioning profile)
xcodebuild -project NotedCore.xcodeproj \
           -scheme NotedCore \
           -destination 'platform=iOS,name=Your Device Name' \
           build
```

## Step 7: First Run Setup

### Permissions
On first launch, the app will request:
1. **Microphone Access**: Required for audio recording
2. **Speech Recognition**: For backup transcription
3. **Notifications** (optional): For session reminders

### Initial Configuration
1. Launch the app
2. Grant required permissions
3. The app will download required models (first time only)
4. You're ready to use NotedCore!

## Troubleshooting

### Common Issues

#### Build Errors
```bash
# Clean build folder
rm -rf ~/Library/Developer/Xcode/DerivedData
# Or in Xcode: Product → Clean Build Folder (Shift+Cmd+K)
```

#### Package Resolution Issues
```bash
# Reset package cache
rm -rf ~/Library/Caches/org.swift.swiftpm
# Then re-resolve packages in Xcode
```

#### Simulator Issues
```bash
# Reset simulator
xcrun simctl erase all
# Or in Simulator: Device → Erase All Content and Settings
```

#### Model Download Issues
- Ensure you have a stable internet connection
- Check available storage (needs ~500MB)
- Try manual download from WhisperKit repository

### Platform-Specific Issues

#### iOS 16 Compatibility
If targeting iOS 16.0, some features may need adjustment:
```swift
// In DocumentationQualityService.swift
// Change from iOS 17 syntax:
.onChange(of: value) { oldValue, newValue in }
// To iOS 16 syntax:
.onChange(of: value) { newValue in }
```

#### macOS Build (Currently iOS-only)
The app is optimized for iOS. While it can build for macOS with Catalyst, full support requires additional configuration.

## Optional: MCP Server Integration

For enhanced AI capabilities, install Model Context Protocol servers:

```bash
# Install MCP servers
npm install -g @modelcontextprotocol/server-filesystem
npm install -g @modelcontextprotocol/server-memory
npm install -g incubyte-sqlite-mcp-server

# Configure in Claude Desktop (if using)
# See MCP_CONFIGURATION.md for details
```

## Verification

### Run Tests
```bash
# Run unit tests
xcodebuild test -scheme NotedCore -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Run UI tests
xcodebuild test -scheme NotedCoreUITests -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### Check Build
1. App launches without crashes
2. Microphone permission dialog appears
3. Recording button responds to taps
4. Transcription appears when speaking

## Next Steps

- Read the [User Guide](USER_GUIDE.md) to learn how to use NotedCore
- Check [DEVELOPMENT.md](DEVELOPMENT.md) for development guidelines
- Review [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md) for system design

## Support

If you encounter issues:
1. Check the [Troubleshooting](#troubleshooting) section
2. Search existing [GitHub Issues](https://github.com/yourusername/NotedCore/issues)
3. Create a new issue with:
   - Xcode version
   - iOS version
   - Error messages
   - Steps to reproduce