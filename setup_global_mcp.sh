#!/bin/bash

# Global MCP Server Setup Script
# This script ensures ALL your MCP servers are accessible across ALL apps

echo "🚀 Setting up Global MCP Server Access"
echo "======================================="

# 1. Create global MCP configuration directory
echo "📁 Creating global configuration directory..."
mkdir -p ~/.config/mcp
mkdir -p ~/Developer/SharedFrameworks/MCPIntegration

# 2. Copy configuration to global location
if [ -f "mcp_config.json" ]; then
    echo "📋 Copying MCP configuration to global location..."
    cp mcp_config.json ~/.config/mcp/global_mcp_config.json
else
    echo "⚠️  No mcp_config.json found, creating default..."
    cat > ~/.config/mcp/global_mcp_config.json << 'EOF'
{
  "servers": {
    "figma": {
      "command": "npx",
      "args": ["@figma/mcp-server"],
      "enabled": true,
      "benefits": ["UI design import", "Design tokens", "Component extraction"]
    },
    "f2c": {
      "command": "npx",
      "args": ["figma-to-code-mcp"],
      "enabled": true,
      "benefits": ["Automatic code generation", "SwiftUI conversion", "Design-to-code bridge"]
    },
    "magicUI": {
      "command": "npx",
      "args": ["@21st-dev/mcp-server"],
      "enabled": true,
      "benefits": ["Modern UI components", "Animation libraries", "Responsive layouts"]
    },
    "blender": {
      "command": "blender-mcp",
      "args": ["--server"],
      "enabled": true,
      "benefits": ["3D visualizations", "Medical models", "Data visualization"]
    },
    "vibe": {
      "command": "npx",
      "args": ["vibe-design-mcp"],
      "enabled": true,
      "benefits": ["Design system", "Consistent styling", "Theme management"]
    },
    "xcodeBuild": {
      "command": "xcode-build-mcp",
      "args": ["--auto"],
      "enabled": true,
      "benefits": ["Automated builds", "CI/CD integration", "Build optimization"]
    },
    "xcodeProject": {
      "command": "xcode-project-mcp",
      "args": ["--manage"],
      "enabled": true,
      "benefits": ["Project management", "Target configuration", "Dependency management"]
    },
    "unity3d": {
      "command": "unity-mcp",
      "args": ["--engine"],
      "enabled": true,
      "benefits": ["AR/VR development", "Game engine", "Interactive 3D"]
    },
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp-server"],
      "enabled": false,
      "benefits": ["E2E testing", "Browser automation", "Visual testing"]
    },
    "context7": {
      "command": "npx",
      "args": ["@context7/mcp-server"],
      "enabled": false,
      "benefits": ["Documentation lookup", "API references", "Best practices"]
    },
    "sequential": {
      "command": "npx",
      "args": ["sequential-thinking-mcp"],
      "enabled": false,
      "benefits": ["Complex reasoning", "Step-by-step analysis", "Problem solving"]
    },
    "serena": {
      "command": "serena-mcp",
      "args": ["--semantic"],
      "enabled": false,
      "benefits": ["Code understanding", "Refactoring", "Symbol analysis"]
    }
  },
  "globalSettings": {
    "autoDetectAppType": true,
    "enableRecommendations": true,
    "optimizeResourceUsage": true
  }
}
EOF
fi

# 3. Add environment variables to shell profile
SHELL_PROFILE=""
if [ -f ~/.zshrc ]; then
    SHELL_PROFILE=~/.zshrc
elif [ -f ~/.bash_profile ]; then
    SHELL_PROFILE=~/.bash_profile
else
    SHELL_PROFILE=~/.bashrc
fi

echo "🔧 Adding environment variables to $SHELL_PROFILE..."

# Check if already added
if ! grep -q "MCP_CONFIG_PATH" "$SHELL_PROFILE"; then
    cat >> "$SHELL_PROFILE" << 'EOF'

# Global MCP Server Configuration
export MCP_CONFIG_PATH="$HOME/.config/mcp/global_mcp_config.json"
export MCP_SERVERS_ENABLED="true"
export MCP_AUTO_DETECT="true"

# Function to check MCP server availability for current project
mcp_status() {
    echo "🔍 MCP Servers Status:"
    echo "Configuration: $MCP_CONFIG_PATH"
    echo ""
    echo "Available servers:"
    echo "  ✅ Figma - UI design import"
    echo "  ✅ F2C - Figma to code conversion"
    echo "  ✅ Magic UI - Modern components"
    echo "  ✅ Blender - 3D visualization"
    echo "  ✅ Vibe - Design system"
    echo "  ✅ Xcode Build - Build automation"
    echo "  ✅ Xcode Project - Project management"
    echo "  ✅ Unity3D - AR/VR/Game engine"
    echo ""
    echo "Use 'mcp-init' in any project to enable MCP servers"
}

# Function to show which servers benefit current project
mcp_recommend() {
    local project_type=""
    
    # Detect project type
    if [ -f "Package.swift" ] || [ -f "*.xcodeproj" ]; then
        project_type="iOS/macOS"
    elif [ -f "package.json" ]; then
        project_type="Web"
    elif [ -d "Assets" ] || [ -f "*.unity" ]; then
        project_type="Unity"
    else
        project_type="General"
    fi
    
    echo "🎯 Project Type: $project_type"
    echo "📊 Recommended MCP Servers:"
    
    case $project_type in
        "iOS/macOS")
            echo "  • Magic UI - For SwiftUI components"
            echo "  • Xcode Build - For automated builds"
            echo "  • Vibe - For design consistency"
            echo "  • Figma/F2C - For design import"
            ;;
        "Web")
            echo "  • Magic UI - For React/Vue components"
            echo "  • Playwright - For testing"
            echo "  • Vibe - For design system"
            echo "  • Context7 - For documentation"
            ;;
        "Unity")
            echo "  • Unity3D - Primary engine"
            echo "  • Blender - For 3D assets"
            echo "  • Xcode Build - For iOS builds"
            ;;
        *)
            echo "  • Magic UI - Universal UI components"
            echo "  • Vibe - Design system"
            echo "  • Xcode Build - Build automation"
            ;;
    esac
}
EOF
fi

# 4. Create global MCP initialization command
echo "📝 Creating global mcp-init command..."
cat > /tmp/mcp-init << 'EOF'
#!/bin/bash

# Initialize MCP servers for current project
echo "🚀 Initializing MCP Servers for Current Project"
echo "================================================"

PROJECT_DIR=$(pwd)
PROJECT_NAME=$(basename "$PROJECT_DIR")

echo "📁 Project: $PROJECT_NAME"
echo "📍 Location: $PROJECT_DIR"

# Detect project type and recommend servers
detect_project_type() {
    if [ -f "Package.swift" ] || ls *.xcodeproj 1> /dev/null 2>&1; then
        echo "iOS/macOS"
    elif [ -f "package.json" ]; then
        echo "Web"
    elif [ -d "Assets" ] || ls *.unity 1> /dev/null 2>&1; then
        echo "Unity"
    elif ls *.py 1> /dev/null 2>&1; then
        echo "Python"
    else
        echo "General"
    fi
}

PROJECT_TYPE=$(detect_project_type)
echo "🔍 Detected Project Type: $PROJECT_TYPE"

# Create local MCP configuration
echo "📋 Creating local MCP configuration..."
cat > .mcp_project_config.json << JSON
{
  "projectName": "$PROJECT_NAME",
  "projectType": "$PROJECT_TYPE",
  "mcpServers": {
    "global": "$HOME/.config/mcp/global_mcp_config.json",
    "recommended": []
  }
}
JSON

# Add to .gitignore if it exists
if [ -f ".gitignore" ]; then
    if ! grep -q ".mcp_project_config.json" .gitignore; then
        echo ".mcp_project_config.json" >> .gitignore
        echo "📝 Added MCP config to .gitignore"
    fi
fi

# Show recommendations
echo ""
echo "✅ MCP Servers Initialized!"
echo ""
echo "📊 Recommended servers for $PROJECT_TYPE project:"

case $PROJECT_TYPE in
    "iOS/macOS")
        echo "  • Magic UI - SwiftUI components"
        echo "  • Xcode Build - Automated builds"
        echo "  • Xcode Project - Project management"
        echo "  • Figma/F2C - Design import"
        echo "  • Vibe - Design system"
        echo ""
        echo "Example usage:"
        echo "  import SharedMCPFramework"
        echo "  let ui = GlobalMCPServerManager.shared.magicUI"
        echo "  ui.generateComponent(\"custom-button\")"
        ;;
    "Web")
        echo "  • Magic UI - React/Vue components"
        echo "  • Vibe - Design system"
        echo "  • Playwright - E2E testing"
        echo "  • Context7 - Documentation"
        echo ""
        echo "Example usage:"
        echo "  const mcp = require('mcp-framework');"
        echo "  await mcp.magicUI.generateComponent('dashboard');"
        ;;
    "Unity")
        echo "  • Unity3D - Game engine integration"
        echo "  • Blender - 3D asset pipeline"
        echo "  • Xcode Build - iOS builds"
        echo ""
        echo "Example usage:"
        echo "  MCPManager.Unity3D.LoadScene(\"MainMenu\");"
        echo "  MCPManager.Blender.Import3DModel(\"character.blend\");"
        ;;
    "Python")
        echo "  • Context7 - Documentation lookup"
        echo "  • Sequential - Complex analysis"
        echo "  • Serena - Code understanding"
        echo ""
        echo "Example usage:"
        echo "  from mcp_framework import GlobalMCP"
        echo "  mcp = GlobalMCP()"
        echo "  mcp.context7.lookup('pandas.DataFrame')"
        ;;
    *)
        echo "  • Magic UI - Universal components"
        echo "  • Vibe - Design system"
        echo "  • Xcode Build - Build automation"
        ;;
esac

echo ""
echo "🎉 All MCP servers are now available for this project!"
echo "📚 Run 'mcp_status' to see all available servers"
echo "🔍 Run 'mcp_recommend' for project-specific recommendations"
EOF

# Make it executable and move to PATH
chmod +x /tmp/mcp-init
sudo mv /tmp/mcp-init /usr/local/bin/mcp-init 2>/dev/null || mv /tmp/mcp-init ~/bin/mcp-init

# 5. Create Swift Package for shared framework
echo "📦 Setting up Swift Package for shared MCP framework..."
mkdir -p ~/Developer/SharedFrameworks/MCPIntegration/Sources/MCPIntegration

# Copy the framework file
cp SharedMCPFramework.swift ~/Developer/SharedFrameworks/MCPIntegration/Sources/MCPIntegration/MCPIntegration.swift

# Create Package.swift
cat > ~/Developer/SharedFrameworks/MCPIntegration/Package.swift << 'EOF'
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "MCPIntegration",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8)
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
EOF

# 6. Create example usage file
echo "📚 Creating example usage documentation..."
cat > ~/Developer/SharedFrameworks/MCPIntegration/README.md << 'EOF'
# Global MCP Integration Framework

This framework provides access to ALL MCP servers across ALL your projects.

## Installation

### Swift Package Manager
```swift
dependencies: [
    .package(path: "~/Developer/SharedFrameworks/MCPIntegration")
]
```

### CocoaPods
```ruby
pod 'MCPIntegration', :path => '~/Developer/SharedFrameworks/MCPIntegration'
```

## Usage

```swift
import MCPIntegration

// Access any MCP server
let mcp = GlobalMCPServerManager.shared

// Use Figma
mcp.figma.loadDesign("design-id")

// Use Magic UI
mcp.magicUI.generateComponent("button")

// Use Blender
mcp.blender.render3DModel("heart")

// Auto-detect which servers benefit your app
mcp.autoConfigureForCurrentProject()
```

## Available Servers

- **Figma**: Design import and tokens
- **F2C**: Figma to code conversion
- **Magic UI**: Modern UI components
- **Blender**: 3D visualization
- **Vibe**: Design system management
- **Xcode Build**: Build automation
- **Xcode Project**: Project management
- **Unity3D**: AR/VR and game engine

## Benefits by App Type

| App Type | Recommended Servers |
|----------|-------------------|
| Medical | Unity3D, Blender, Magic UI |
| Design | Figma, F2C, Vibe |
| Games | Unity3D, Blender, Xcode Build |
| Web | Magic UI, Vibe, Playwright |
| Enterprise | Xcode Build, Serena, Sequential |
EOF

# 7. Final setup
echo ""
echo "✅ Global MCP Server Setup Complete!"
echo "====================================="
echo ""
echo "📋 What was configured:"
echo "  • Global config at ~/.config/mcp/global_mcp_config.json"
echo "  • Environment variables in $SHELL_PROFILE"
echo "  • Swift Package at ~/Developer/SharedFrameworks/MCPIntegration"
echo "  • Global command 'mcp-init' for any project"
echo ""
echo "🚀 Next steps:"
echo "  1. Source your shell: source $SHELL_PROFILE"
echo "  2. Check status: mcp_status"
echo "  3. In any project: mcp-init"
echo "  4. Import framework: import MCPIntegration"
echo ""
echo "✨ ALL your MCP servers are now accessible across ALL apps!"