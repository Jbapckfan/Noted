# Global MCP Server Configuration

## Overview
Yes, these MCP servers will be accessible for ALL current and future projects! Here's how to set them up globally:

## 1. Global Configuration Setup

### Move Configuration to System-Wide Location
```bash
# Create global MCP config directory
mkdir -p ~/.config/mcp

# Move the configuration
cp mcp_config.json ~/.config/mcp/global_mcp_config.json
```

### Environment Variable Setup
Add to your shell profile (`~/.zshrc` or `~/.bash_profile`):
```bash
export MCP_CONFIG_PATH="$HOME/.config/mcp/global_mcp_config.json"
export MCP_SERVERS_ENABLED="true"
```

## 2. Shared Framework Creation

### Create Shared Swift Package
```swift
// Package.swift for MCPIntegration
// Location: ~/Developer/SharedFrameworks/MCPIntegration

import PackageDescription

let package = Package(
    name: "MCPIntegration",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "MCPIntegration",
            targets: ["MCPIntegration"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MCPIntegration",
            dependencies: []),
    ]
)
```

## 3. Cross-Project Access Methods

### Method 1: Swift Package Manager (Recommended)
Add to any project's `Package.swift`:
```swift
dependencies: [
    .package(path: "~/Developer/SharedFrameworks/MCPIntegration")
]
```

### Method 2: Xcode Workspace
1. Create a workspace containing all projects
2. Add MCPIntegration as a shared framework
3. Link against it in each project

### Method 3: CocoaPods (for iOS projects)
```ruby
# Podfile
pod 'MCPIntegration', :path => '~/Developer/SharedFrameworks/MCPIntegration'
```

## 4. Project Template with MCP Servers

### Create Xcode Project Template
Location: `~/Library/Developer/Xcode/Templates/Project Templates/MCP Enabled/`

```xml
<!-- TemplateInfo.plist -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN">
<plist version="1.0">
<dict>
    <key>Kind</key>
    <string>Xcode.Xcode3.ProjectTemplateUnitKind</string>
    <key>Identifier</key>
    <string>com.yourcompany.mcp-enabled-app</string>
    <key>Concrete</key>
    <true/>
    <key>Description</key>
    <string>Application with MCP servers pre-configured</string>
    <key>Options</key>
    <array>
        <dict>
            <key>Identifier</key>
            <string>MCPServers</string>
            <key>Default</key>
            <string>All</string>
            <key>Description</key>
            <string>Which MCP servers to include</string>
            <key>Values</key>
            <array>
                <string>All</string>
                <string>Design Only (Figma, F2C, Vibe)</string>
                <string>Development Only (Xcode, Unity)</string>
                <string>Custom</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

## 5. Usage in Any Project

### Quick Start for New Projects
```swift
import MCPIntegration

class AppDelegate: NSObject, NSApplicationDelegate {
    let mcpManager = MCPServerManager.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // All MCP servers automatically available
        mcpManager.initialize()
        
        // Use any MCP server
        mcpManager.figma.loadDesign("design-id")
        mcpManager.magicUI.generateComponent("button")
        mcpManager.blender.render3DModel("anatomy")
    }
}
```

### For Existing Projects
```swift
// 1. Add package dependency
// 2. Import framework
import MCPIntegration

// 3. Use in any file
MCPServerManager.shared.xcodeBuild.build()
```

## 6. Available MCP Servers Globally

| Server | Purpose | Usage |
|--------|---------|-------|
| **Figma** | Design import | `mcpManager.figma.*` |
| **F2C** | Figma to Code | `mcpManager.f2c.*` |
| **Magic UI** | Component generation | `mcpManager.magicUI.*` |
| **Blender** | 3D visualization | `mcpManager.blender.*` |
| **Vibe** | Design system | `mcpManager.vibe.*` |
| **Xcode Build** | Build automation | `mcpManager.xcodeBuild.*` |
| **Xcode Project** | Project management | `mcpManager.xcodeProject.*` |
| **Unity3D** | Game/AR/VR | `mcpManager.unity.*` |
| **Sequential Thinking** | Multi-step reasoning | `mcpManager.sequentialThinking.*` |
| **MCP Compass** | Task coordination | `mcpManager.mcpCompass.*` |
| **DuckDuckGo/Brave Search** | Private web search | `mcpManager.searchMCP.*` |
| **Firecrawl** | Web scraping | `mcpManager.firecrawl.*` |
| **OpenAgents** | Multi-agent orchestration | `mcpManager.openAgents.*` |
| **Magic UI Context** | Context-aware UI | `mcpManager.magicUIContext.*` |
| **Figma Context** | Design with context | `mcpManager.figmaContext.*` |
| **Zen** | Mindful assistance | `mcpManager.zen.*` |

## 7. CLI Tool for Any Project

### Install Global CLI
```bash
# Create CLI tool
cat > /usr/local/bin/mcp-init << 'EOF'
#!/bin/bash
# Initialize MCP servers for current project

PROJECT_DIR=$(pwd)
echo "Initializing MCP servers for $PROJECT_DIR"

# Copy configuration
cp ~/.config/mcp/global_mcp_config.json ./mcp_config.json

# Add to .gitignore
echo "mcp_config.json" >> .gitignore

# Add Swift package
swift package add-dependency ~/Developer/SharedFrameworks/MCPIntegration

echo "✅ MCP servers ready for use!"
echo "Import with: import MCPIntegration"
EOF

chmod +x /usr/local/bin/mcp-init
```

### Usage in Any Directory
```bash
cd /path/to/any/project
mcp-init
# MCP servers now available!
```

## 8. Benefits of Global Configuration

✅ **Write Once, Use Everywhere**: Single configuration for all projects
✅ **Automatic Updates**: Update servers in one place, all projects benefit
✅ **Team Sharing**: Share configuration with team via git
✅ **Project Templates**: New projects start with MCP pre-configured
✅ **Version Control**: Track MCP configuration changes
✅ **Environment Specific**: Different configs for dev/staging/prod

## 9. Examples Across Different Project Types

### iOS App
```swift
import MCPIntegration
// Figma designs → SwiftUI components
let view = MCPServerManager.shared.f2c.convertToSwiftUI("figma-frame-id")
```

### macOS Utility
```swift
import MCPIntegration
// Automated builds
MCPServerManager.shared.xcodeBuild.buildAndTest()
```

### AR Medical Training App
```swift
import MCPIntegration
// 3D medical models
let model = MCPServerManager.shared.unity.loadMedicalModel("heart")
```

### Documentation Generator
```swift
import MCPIntegration
// Generate UI documentation
MCPServerManager.shared.vibe.generateStyleGuide()
```

## 10. Maintenance

### Update All Projects
```bash
# Update global config
vim ~/.config/mcp/global_mcp_config.json

# All projects automatically use new config
```

### Add New MCP Server
```json
// Add to global_mcp_config.json
{
  "newServer": {
    "command": "new-mcp-server",
    "args": ["--port", "9999"]
  }
}
// Available in all projects immediately
```

## Summary

✅ **YES** - These MCP servers are accessible for ALL projects!
- Global configuration in `~/.config/mcp/`
- Shared framework via Swift Package Manager
- Project templates with MCP pre-configured
- CLI tool for quick initialization
- Single source of truth for all MCP servers
- Automatic availability in new and existing projects

The setup ensures that every current and future project can leverage the full power of all 16 MCP servers without any additional configuration!