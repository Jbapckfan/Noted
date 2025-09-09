import Foundation
import SwiftUI

// MARK: - Unrestricted MCP Usage Examples
// Shows how ALL servers are ALWAYS available for ANY app

/// Example 1: Medical App with Creative Freedom
/// Not restricted to "medical" servers - can use ANY server
func medicalAppExample() {
    let mcp = GlobalMCPServerManager.shared
    
    // Traditional medical servers
    mcp.unity3D.loadAnatomyModel("heart", detail: .high)
    mcp.blender.renderMedicalVisualization("blood-flow")
    
    // But ALSO can use ANY other server!
    mcp.figma.importDesign("modern-medical-ui")  // ✅ Allowed!
    mcp.playwright.runE2ETest("patient-flow")     // ✅ Allowed!
    mcp.sequential.analyzeComplex("diagnosis")    // ✅ Allowed!
    
    // No restrictions - use what makes sense for YOUR app
}

/// Example 2: Simple Todo App with Advanced Features
/// Not limited to "basic" servers - can use anything!
func todoAppExample() {
    let mcp = GlobalMCPServerManager.shared
    
    // You might think a todo app only needs basic UI
    mcp.magicUI.generateComponent("task-list")
    
    // But you're FREE to use advanced servers too!
    mcp.unity3D.loadScene("3d-task-visualization")  // ✅ Want 3D todos? Go for it!
    mcp.blender.render3DModel("task-completion")    // ✅ 3D celebrations? Why not!
    mcp.context7.lookupDocumentation("productivity") // ✅ Research tools? Sure!
    
    // Your creativity is the only limit
}

/// Example 3: Game with Unexpected Integrations
func gameAppExample() {
    let mcp = GlobalMCPServerManager.shared
    
    // Expected game servers
    mcp.unity3D.loadScene("main-menu")
    mcp.blender.import3DModel("character")
    
    // But also can integrate unexpected servers!
    mcp.context7.lookupDocumentation("game-physics")  // ✅ Research while building
    mcp.serena.understandCode("enemy-ai.swift")      // ✅ Code analysis
    mcp.vibe.applyDesignSystem()                      // ✅ Consistent UI design
    
    // Mix and match as needed
}

/// Example 4: Prototype that evolves
func prototypeEvolution() {
    let mcp = GlobalMCPServerManager.shared
    
    print("Week 1: Simple UI prototype")
    mcp.figma.importDesign("wireframes")
    mcp.magicUI.generateComponent("prototype")
    
    print("Week 2: Adding 3D visualization (not restricted!)")
    mcp.blender.render3DModel("data-viz")  // ✅ Prototype can use 3D!
    mcp.unity3D.loadScene("interactive")   // ✅ Why not make it interactive?
    
    print("Week 3: Adding testing (still allowed!)")
    mcp.playwright.runE2ETest("user-flow") // ✅ Prototypes can have tests!
    
    print("Week 4: Production features (no category change needed!)")
    mcp.xcodeBuild.buildForAppStore()      // ✅ Same project, new servers!
    
    // No need to recategorize - just use what you need
}

// MARK: - User Control Examples

/// User preferences for MCP servers
struct UserMCPControl {
    let mcp = GlobalMCPServerManager.shared
    
    /// User can explicitly choose which servers to use
    func userDrivenSelection() {
        // User says: "I want to use Blender for my text editor"
        // System: "Sure! Here's how:"
        mcp.blender.render3DModel("3d-text-cursor")  // ✅ Unusual but allowed!
        
        // User says: "I want Playwright for my music app"
        // System: "Go ahead!"
        mcp.playwright.runE2ETest("audio-playback")  // ✅ Your choice!
    }
    
    /// User can ignore all recommendations
    func ignoreRecommendations() {
        // System recommends: [magicUI, vibe]
        // User: "No thanks, I'll use Unity and Blender instead"
        
        mcp.unity3D.loadScene("custom-ui")     // ✅ User choice wins
        mcp.blender.render3DModel("ui-element") // ✅ User knows best
        
        // Recommendations are ONLY suggestions
    }
    
    /// User can mix unexpected combinations
    func creativeCominations() {
        // Building a spreadsheet app? Use game engine!
        mcp.unity3D.loadScene("3d-spreadsheet")
        
        // Making a game? Use documentation tools!
        mcp.context7.lookupDocumentation("game-design")
        
        // Creating docs? Use 3D visualization!
        mcp.blender.render3DModel("document-structure")
        
        // ALL combinations are valid!
    }
}

// MARK: - SwiftUI View for User Control

struct MCPServerSelector: View {
    @State private var selectedServers: Set<String> = []
    @State private var showingRecommendations = false
    let mcp = GlobalMCPServerManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("MCP Server Selection")
                .font(.title)
                .fontWeight(.bold)
            
            Text("ALL servers are available. Select any combination you want!")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // All servers available for selection
            ForEach(Array(MCPUniversalAccess.allServers.keys.sorted()), id: \.self) { server in
                HStack {
                    Image(systemName: selectedServers.contains(server) ? "checkmark.square.fill" : "square")
                        .foregroundColor(selectedServers.contains(server) ? .blue : .gray)
                        .onTapGesture {
                            if selectedServers.contains(server) {
                                selectedServers.remove(server)
                            } else {
                                selectedServers.insert(server)
                            }
                        }
                    
                    VStack(alignment: .leading) {
                        Text(server)
                            .fontWeight(.medium)
                        Text(MCPUniversalAccess.description(for: server))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Show if recommended (but not required!)
                    if isRecommended(server) {
                        Text("Suggested")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Divider()
            
            HStack {
                Button("Use All Servers") {
                    selectedServers = Set(MCPUniversalAccess.allServers.keys)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Show Suggestions") {
                    showingRecommendations = true
                    mcp.showRecommendations()
                }
                .buttonStyle(.bordered)
                
                Button("Clear All") {
                    selectedServers.removeAll()
                }
                .buttonStyle(.bordered)
            }
            
            if !selectedServers.isEmpty {
                Text("Selected: \(selectedServers.sorted().joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        }
        .padding()
    }
    
    func isRecommended(_ server: String) -> Bool {
        // Check if this server is in recommendations
        let recommendations = mcp.generateRecommendations()
        return recommendations.contains { $0.serverName == server }
    }
}

// MARK: - Freedom Message

public struct MCPFreedomMessage {
    public static func display() {
        print("""
        
        ╔════════════════════════════════════════════════════════════╗
        ║           🚀 MCP SERVERS - COMPLETE FREEDOM 🚀            ║
        ╠════════════════════════════════════════════════════════════╣
        ║                                                            ║
        ║  ALL servers are available for ALL apps, ALWAYS!          ║
        ║                                                            ║
        ║  ✅ No category restrictions                              ║
        ║  ✅ No artificial limitations                             ║
        ║  ✅ Use any server in any app                            ║
        ║  ✅ Mix unexpected combinations                           ║
        ║  ✅ Your creativity is the only limit                     ║
        ║                                                            ║
        ║  Recommendations are SUGGESTIONS, not rules:              ║
        ║  • Take them or leave them                                ║
        ║  • Combine servers creatively                             ║
        ║  • Experiment freely                                      ║
        ║                                                            ║
        ║  Available Servers:                                        ║
        ║  • figma      - Design import                             ║
        ║  • f2c        - Design to code                            ║
        ║  • magicUI    - UI components                             ║
        ║  • blender    - 3D visualization                          ║
        ║  • vibe       - Design systems                            ║
        ║  • xcodeBuild - Build automation                          ║
        ║  • xcodeProject - Project management                      ║
        ║  • unity3D    - AR/VR/Games                               ║
        ║  • playwright - E2E testing                               ║
        ║  • context7   - Documentation                             ║
        ║  • sequential - Complex reasoning                         ║
        ║  • serena     - Code understanding                        ║
        ║                                                            ║
        ║  Use them ALL, use SOME, use NONE - it's YOUR choice!     ║
        ║                                                            ║
        ╚════════════════════════════════════════════════════════════╝
        
        """)
    }
}

// Usage:
// MCPFreedomMessage.display()
// let mcp = GlobalMCPServerManager.shared
// mcp.anyServer.anyMethod() // Complete freedom!