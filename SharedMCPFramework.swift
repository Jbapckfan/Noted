import Foundation
import SwiftUI

// MARK: - Global MCP Server Manager
// This shared framework ensures ALL your MCP servers are accessible across ALL apps
// NO RESTRICTIONS - All servers available to all apps, with smart recommendations

public class GlobalMCPServerManager {
    public static let shared = GlobalMCPServerManager()
    
    // MARK: - All Available MCP Servers
    // ALL servers are ALWAYS accessible in EVERY app - no restrictions!
    
    public let figma: FigmaMCPService
    public let f2c: F2CService
    public let magicUI: MagicUIService
    public let blender: BlenderMCPService
    public let vibe: VibeDesignSystemService
    public let xcodeBuild: XcodeBuildMCPService
    public let xcodeProject: XcodeProjectManagerService
    public let unity3D: Unity3DMCPService
    
    // Additional MCP servers - also always available
    public let playwright: PlaywrightMCPService
    public let context7: Context7MCPService
    public let sequential: SequentialThinkingService
    public let serena: SerenaMCPService
    
    // New MCP servers (added per user request) - ALL always available
    public let sequentialThinking: SequentialThinkingMCPService
    public let mcpCompass: MCPCompassService
    public let searchMCP: DuckDuckGoBraveSearchService
    public let firecrawl: FirecrawlMCPService
    public let openAgents: OpenAgentsMCPService
    public let magicUIContext: MagicUIContextService
    public let figmaContext: FigmaContextMCPService
    public let zen: ZenMCPService
    
    // Recommendations tracker (non-restrictive)
    @Published public var recommendations: [ServerRecommendation] = []
    @Published public var userPreferences: UserMCPPreferences
    
    private init() {
        // Initialize ALL MCP servers from global config - no restrictions
        let configPath = ProcessInfo.processInfo.environment["MCP_CONFIG_PATH"] 
            ?? "\(NSHomeDirectory())/.config/mcp/global_mcp_config.json"
        
        // ALL servers initialized and available
        self.figma = FigmaMCPService(configPath: configPath)
        self.f2c = F2CService(configPath: configPath)
        self.magicUI = MagicUIService(configPath: configPath)
        self.blender = BlenderMCPService(configPath: configPath)
        self.vibe = VibeDesignSystemService(configPath: configPath)
        self.xcodeBuild = XcodeBuildMCPService(configPath: configPath)
        self.xcodeProject = XcodeProjectManagerService(configPath: configPath)
        self.unity3D = Unity3DMCPService(configPath: configPath)
        
        // Additional servers - always available, not optional
        self.playwright = PlaywrightMCPService(configPath: configPath)
        self.context7 = Context7MCPService(configPath: configPath)
        self.sequential = SequentialThinkingService(configPath: configPath)
        self.serena = SerenaMCPService(configPath: configPath)
        
        // New MCP servers - ALL available to everyone
        self.sequentialThinking = SequentialThinkingMCPService(configPath: configPath)
        self.mcpCompass = MCPCompassService(configPath: configPath)
        self.searchMCP = DuckDuckGoBraveSearchService(configPath: configPath)
        self.firecrawl = FirecrawlMCPService(configPath: configPath)
        self.openAgents = OpenAgentsMCPService(configPath: configPath)
        self.magicUIContext = MagicUIContextService(configPath: configPath)
        self.figmaContext = FigmaContextMCPService(configPath: configPath)
        self.zen = ZenMCPService(configPath: configPath)
        
        // Load user preferences
        self.userPreferences = UserMCPPreferences.load()
    }
}

// MARK: - Non-Restrictive Recommendations
// Provides intelligent suggestions WITHOUT restricting access to ANY servers

public struct ServerRecommendation {
    let serverName: String
    let reason: String
    let confidence: Float // 0.0 to 1.0
    let benefits: [String]
}

public struct UserMCPPreferences: Codable {
    var alwaysEnabledServers: Set<String> = []
    var neverRecommendServers: Set<String> = []
    var acceptRecommendations: Bool = true
    
    static func load() -> UserMCPPreferences {
        // Load from user defaults or config file
        if let data = UserDefaults.standard.data(forKey: "MCPPreferences"),
           let prefs = try? JSONDecoder().decode(UserMCPPreferences.self, from: data) {
            return prefs
        }
        return UserMCPPreferences()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "MCPPreferences")
        }
    }
}

public extension GlobalMCPServerManager {
    
    /// Generate recommendations WITHOUT restricting access
    /// ALL servers remain available regardless of recommendations
    func generateRecommendations(for projectContext: ProjectContext? = nil) -> [ServerRecommendation] {
        var recommendations: [ServerRecommendation] = []
        
        // Analyze project context if provided
        let context = projectContext ?? analyzeCurrentProject()
        
        // Generate NON-RESTRICTIVE recommendations
        // Users can always use ANY server they want
        
        if context.hasUIComponents {
            recommendations.append(ServerRecommendation(
                serverName: "magicUI",
                reason: "Project contains UI components that could benefit from modern design patterns",
                confidence: 0.9,
                benefits: ["Pre-built components", "Responsive layouts", "Accessibility features"]
            ))
            
            recommendations.append(ServerRecommendation(
                serverName: "vibe",
                reason: "Design system could help maintain consistency",
                confidence: 0.7,
                benefits: ["Consistent styling", "Theme management", "Design tokens"]
            ))
        }
        
        if context.hasDesignFiles {
            recommendations.append(ServerRecommendation(
                serverName: "figma",
                reason: "Design files detected - Figma integration could streamline workflow",
                confidence: 0.95,
                benefits: ["Direct design import", "Auto-sync updates", "Design tokens"]
            ))
            
            recommendations.append(ServerRecommendation(
                serverName: "f2c",
                reason: "Convert designs to code automatically",
                confidence: 0.8,
                benefits: ["Time savings", "Pixel-perfect implementation", "Consistency"]
            ))
        }
        
        if context.has3DContent || context.hasVisualizationNeeds {
            recommendations.append(ServerRecommendation(
                serverName: "blender",
                reason: "3D visualization could enhance data presentation",
                confidence: 0.75,
                benefits: ["3D models", "Data visualization", "Animation"]
            ))
            
            recommendations.append(ServerRecommendation(
                serverName: "unity3D",
                reason: "Interactive 3D or AR/VR capabilities detected as beneficial",
                confidence: 0.7,
                benefits: ["Interactive 3D", "AR/VR support", "Game engine features"]
            ))
        }
        
        if context.hasTests {
            recommendations.append(ServerRecommendation(
                serverName: "playwright",
                reason: "E2E testing could improve quality assurance",
                confidence: 0.85,
                benefits: ["Browser automation", "Visual testing", "Cross-browser support"]
            ))
        }
        
        if context.isXcodeProject {
            recommendations.append(ServerRecommendation(
                serverName: "xcodeBuild",
                reason: "Xcode project detected - build automation available",
                confidence: 0.95,
                benefits: ["Automated builds", "CI/CD integration", "Build optimization"]
            ))
        }
        
        // Filter out user's "never recommend" preferences
        recommendations = recommendations.filter { 
            !userPreferences.neverRecommendServers.contains($0.serverName)
        }
        
        // Sort by confidence
        recommendations.sort { $0.confidence > $1.confidence }
        
        return recommendations
    }
    
    /// Show recommendations to user WITHOUT enforcing them
    func showRecommendations() {
        let recommendations = generateRecommendations()
        
        if recommendations.isEmpty {
            print("ℹ️ All MCP servers are available. No specific recommendations for this project.")
            return
        }
        
        print("\n💡 MCP Server Recommendations (ALL servers remain available):")
        print("=" + String(repeating: "=", count: 60))
        
        for (index, rec) in recommendations.enumerated() {
            print("\n\(index + 1). \(rec.serverName) (Confidence: \(Int(rec.confidence * 100))%)")
            print("   Reason: \(rec.reason)")
            print("   Benefits:")
            for benefit in rec.benefits {
                print("     • \(benefit)")
            }
        }
        
        print("\n📌 Remember: These are just suggestions!")
        print("   You can use ANY MCP server at any time:")
        print("   • figma, f2c, magicUI, blender, vibe")
        print("   • xcodeBuild, xcodeProject, unity3D")
        print("   • playwright, context7, sequential, serena")
        print("\n✨ Use 'mcp.anyServer' to access any server you need!")
    }
    
    /// Analyze current project context
    private func analyzeCurrentProject() -> ProjectContext {
        var context = ProjectContext()
        
        // Check for various indicators
        let fileManager = FileManager.default
        let currentPath = fileManager.currentDirectoryPath
        
        // Check for UI components
        context.hasUIComponents = fileManager.fileExists(atPath: "\(currentPath)/Views") ||
                                   fileManager.fileExists(atPath: "\(currentPath)/Components") ||
                                   fileManager.fileExists(atPath: "\(currentPath)/UI")
        
        // Check for design files
        context.hasDesignFiles = (try? fileManager.contentsOfDirectory(atPath: currentPath))?
            .contains { $0.hasSuffix(".fig") || $0.hasSuffix(".sketch") || $0.hasSuffix(".xd") } ?? false
        
        // Check for 3D content
        context.has3DContent = (try? fileManager.contentsOfDirectory(atPath: currentPath))?
            .contains { $0.hasSuffix(".blend") || $0.hasSuffix(".obj") || $0.hasSuffix(".fbx") } ?? false
        
        // Check for tests
        context.hasTests = fileManager.fileExists(atPath: "\(currentPath)/Tests") ||
                          fileManager.fileExists(atPath: "\(currentPath)/__tests__")
        
        // Check for Xcode project
        context.isXcodeProject = (try? fileManager.contentsOfDirectory(atPath: currentPath))?
            .contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") } ?? false
        
        return context
    }
    
    /// Interactive server selection
    func askUserAboutRecommendations() {
        guard userPreferences.acceptRecommendations else {
            print("ℹ️ Recommendations disabled. All MCP servers available for use.")
            return
        }
        
        let recommendations = generateRecommendations()
        
        if !recommendations.isEmpty {
            print("\n🤔 Would you like to see MCP server recommendations for this project?")
            print("   (All servers remain available regardless of your choice)")
            print("   Type 'yes' to see recommendations, or press Enter to skip")
            
            // In a real implementation, this would wait for user input
            // For now, we'll just show them
            showRecommendations()
        }
    }
}

// MARK: - Project Context (Non-Restrictive)

public struct ProjectContext {
    var hasUIComponents: Bool = false
    var hasDesignFiles: Bool = false
    var has3DContent: Bool = false
    var hasVisualizationNeeds: Bool = false
    var hasTests: Bool = false
    var isXcodeProject: Bool = false
    var hasMedicalContent: Bool = false
    var hasGameContent: Bool = false
    var customTags: Set<String> = []
    
    // Allow users to add their own context
    public mutating func addCustomContext(_ tag: String) {
        customTags.insert(tag)
    }
}

// MARK: - Universal MCP Access
// ALL servers available to ALL apps - no restrictions!

public struct MCPUniversalAccess {
    public static let allServers = [
        "figma": "UI design import and tokens",
        "f2c": "Figma to code conversion",
        "magicUI": "Modern UI components",
        "blender": "3D visualization and modeling",
        "vibe": "Design system management",
        "xcodeBuild": "Build automation",
        "xcodeProject": "Project management",
        "unity3D": "AR/VR and game engine",
        "playwright": "E2E testing",
        "context7": "Documentation lookup",
        "sequential": "Complex reasoning",
        "serena": "Code understanding",
        "sequentialThinking": "Advanced multi-step reasoning and problem solving",
        "mcpCompass": "AI navigation and task coordination",
        "searchMCP": "DuckDuckGo/Brave privacy-focused web search",
        "firecrawl": "Web scraping and content extraction",
        "openAgents": "Multi-agent AI orchestration",
        "magicUIContext": "Enhanced UI component generation with context",
        "figmaContext": "Design-to-code with full context awareness",
        "zen": "Mindful AI assistance and meditation features"
    ]
    
    /// Get description of what a server does
    public static func description(for server: String) -> String {
        return allServers[server] ?? "MCP server"
    }
    
    /// ALL servers are ALWAYS accessible
    public static func isAccessible(_ server: String) -> Bool {
        return true // Always true - no restrictions!
    }
}

// MARK: - Easy Integration Examples

public extension GlobalMCPServerManager {
    
    // Medical App Example
    func enhanceMedicalApp() {
        // Use Unity3D for 3D anatomy
        unity3D.loadAnatomyModel("heart", detail: .high)
        
        // Use Blender for medical visualizations
        blender.renderMedicalVisualization("blood-flow")
        
        // Use MagicUI for professional medical UI
        magicUI.generateMedicalDashboard()
    }
    
    // Design Tool Example
    func enhanceDesignApp() {
        // Import from Figma
        figma.importDesign("design-system-v2")
        
        // Convert to code
        f2c.convertToSwiftUI()
        
        // Apply design system
        vibe.applyDesignSystem()
    }
    
    // Game Development Example
    func enhanceGameApp() {
        // Use Unity for game engine
        unity3D.loadScene("main-menu")
        
        // Use Blender for 3D assets
        blender.import3DModel("character")
        
        // Automated builds
        xcodeBuild.buildForAppStore()
    }
}

// MARK: - SwiftUI Integration Helper

@available(iOS 15.0, macOS 12.0, *)
public struct MCPEnabledView: View {
    @StateObject private var mcpManager = MCPViewManager()
    
    public var body: some View {
        VStack {
            Text("MCP Servers Status")
                .font(.headline)
            
            ForEach(mcpManager.availableServers, id: \.name) { server in
                HStack {
                    Circle()
                        .fill(server.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(server.name)
                        .font(.caption)
                    
                    Spacer()
                    
                    if server.canBenefitCurrentApp {
                        Text("Recommended")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
    }
}

class MCPViewManager: ObservableObject {
    struct ServerStatus {
        let name: String
        let isConnected: Bool
        let canBenefitCurrentApp: Bool
    }
    
    @Published var availableServers: [ServerStatus] = [
        ServerStatus(name: "Figma", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "F2C", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "Magic UI", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "Blender", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "Vibe", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "Xcode Build", isConnected: true, canBenefitCurrentApp: true),
        ServerStatus(name: "Xcode Project", isConnected: true, canBenefitCurrentApp: false),
        ServerStatus(name: "Unity3D", isConnected: true, canBenefitCurrentApp: true)
    ]
}

// MARK: - Placeholder Service Implementations
// These would be fully implemented in the actual framework

public class FigmaMCPService {
    init(configPath: String) {}
    public func loadDesign(_ id: String) { print("Loading Figma design: \(id)") }
    public func importDesign(_ name: String) { print("Importing: \(name)") }
}

public class F2CService {
    init(configPath: String) {}
    public func convertToSwiftUI(_ frameId: String? = nil) { print("Converting to SwiftUI") }
}

public class MagicUIService {
    init(configPath: String) {}
    public func generateComponent(_ type: String) { print("Generating \(type) component") }
    public func generateMedicalDashboard() { print("Generating medical dashboard") }
}

public class BlenderMCPService {
    init(configPath: String) {}
    public func render3DModel(_ model: String) { print("Rendering 3D model: \(model)") }
    public func renderMedicalVisualization(_ type: String) { print("Rendering medical viz: \(type)") }
    public func import3DModel(_ name: String) { print("Importing 3D model: \(name)") }
}

public class VibeDesignSystemService {
    init(configPath: String) {}
    public func applyDesignSystem() { print("Applying Vibe design system") }
}

public class XcodeBuildMCPService {
    init(configPath: String) {}
    public func build() { print("Building with Xcode") }
    public func buildAndTest() { print("Building and testing") }
    public func buildForAppStore() { print("Building for App Store") }
}

public class XcodeProjectManagerService {
    init(configPath: String) {}
    public func createTarget(_ name: String) { print("Creating target: \(name)") }
}

public class Unity3DMCPService {
    init(configPath: String) {}
    public func loadMedicalModel(_ model: String) { print("Loading medical model: \(model)") }
    public func loadAnatomyModel(_ model: String, detail: DetailLevel) { print("Loading anatomy: \(model)") }
    public func loadScene(_ scene: String) { print("Loading scene: \(scene)") }
    
    public enum DetailLevel {
        case low, medium, high
    }
}

// Additional MCP Services - ALL ALWAYS AVAILABLE
public class PlaywrightMCPService {
    init(configPath: String) {}
    public func runE2ETest(_ test: String) { print("Running E2E test: \(test)") }
}

public class Context7MCPService {
    init(configPath: String) {}
    public func lookupDocumentation(_ query: String) { print("Looking up: \(query)") }
}

public class SequentialThinkingService {
    init(configPath: String) {}
    public func analyzeComplex(_ problem: String) { print("Analyzing: \(problem)") }
}

public class SerenaMCPService {
    init(configPath: String) {}
    public func understandCode(_ path: String) { print("Understanding code at: \(path)") }
}
// MARK: - New MCP Service Implementations (Added per user request)
// ALL services are ALWAYS available to ALL apps - no restrictions!

public class SequentialThinkingMCPService {
    init(configPath: String) {}
    public func thinkStep(by step: String, depth: Int = 5) { 
        print("Sequential thinking: \(step) with depth \(depth)") 
    }
    public func analyzeComplexProblem(_ problem: String) -> [String] {
        print("Analyzing complex problem: \(problem)")
        return ["Step 1: Understand", "Step 2: Decompose", "Step 3: Solve", "Step 4: Validate"]
    }
    public func generateHypothesis(from data: String) { 
        print("Generating hypothesis from: \(data)") 
    }
}

public class MCPCompassService {
    init(configPath: String) {}
    public func navigate(to destination: String) { 
        print("MCP Compass navigating to: \(destination)") 
    }
    public func coordinateTasks(_ tasks: [String]) {
        print("Coordinating \(tasks.count) tasks")
    }
    public func optimizeWorkflow(_ workflow: String) {
        print("Optimizing workflow: \(workflow)")
    }
}

public class DuckDuckGoBraveSearchService {
    init(configPath: String) {}
    public func searchPrivately(_ query: String, engine: SearchEngine = .duckduckgo) {
        print("Private search for: \(query) using \(engine)")
    }
    public func searchMedicalInfo(_ condition: String) {
        print("Searching medical information: \(condition)")
    }
    public func searchDocumentation(_ library: String) {
        print("Searching documentation for: \(library)")
    }
    
    public enum SearchEngine {
        case duckduckgo, brave
    }
}

public class FirecrawlMCPService {
    init(configPath: String) {}
    public func scrapeWebsite(_ url: String, depth: Int = 1) {
        print("Scraping website: \(url) with depth \(depth)")
    }
    public func extractContent(from url: String, selector: String? = nil) {
        print("Extracting content from: \(url)")
    }
    public func crawlDocumentation(_ baseUrl: String) {
        print("Crawling documentation at: \(baseUrl)")
    }
}

public class OpenAgentsMCPService {
    init(configPath: String) {}
    public func orchestrateAgents(_ agents: [String], task: String) {
        print("Orchestrating \(agents.count) agents for: \(task)")
    }
    public func delegateTask(_ task: String, to agent: String) {
        print("Delegating '\(task)' to agent: \(agent)")
    }
    public func createAgentPipeline(_ steps: [String]) {
        print("Creating agent pipeline with \(steps.count) steps")
    }
}

public class MagicUIContextService {
    init(configPath: String) {}
    public func generateWithContext(_ component: String, context: UIContext) {
        print("Generating \(component) with context")
    }
    public func adaptToUserPreferences(_ preferences: [String: Any]) {
        print("Adapting UI to user preferences")
    }
    public func generateResponsiveLayout(_ layout: String) {
        print("Generating responsive layout: \(layout)")
    }
    
    public struct UIContext {
        public let theme: String
        public let accessibility: Bool
        public let platform: String
    }
}

public class FigmaContextMCPService {
    init(configPath: String) {}
    public func importWithContext(_ designId: String, context: DesignContext) {
        print("Importing Figma design \(designId) with full context")
    }
    public func syncDesignSystem(_ systemId: String) {
        print("Syncing design system: \(systemId)")
    }
    public func generateFromComponents(_ components: [String]) {
        print("Generating from \(components.count) Figma components")
    }
    
    public struct DesignContext {
        public let projectType: String
        public let targetPlatform: String
        public let designTokens: Bool
    }
}

public class ZenMCPService {
    init(configPath: String) {}
    public func mindfulAssist(_ task: String) {
        print("Providing mindful assistance for: \(task)")
    }
    public func generateCalmInterface(_ type: String) {
        print("Generating calm interface: \(type)")
    }
    public func meditationTimer(minutes: Int) {
        print("Starting \(minutes) minute meditation timer")
    }
    public func reduceComplexity(in code: String) {
        print("Reducing complexity through zen principles")
    }
}
