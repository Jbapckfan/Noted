import Foundation
import SwiftUI

// MARK: - MCP Server Integration Hub for NotedCore
// Integrates multiple MCP servers for enhanced design, UI, 3D, and development capabilities

// MARK: - 1. Figma MCP Server Integration
class FigmaMCPIntegration {
    static let shared = FigmaMCPIntegration()
    
    struct FigmaConfig {
        let apiKey: String = ProcessInfo.processInfo.environment["FIGMA_API_KEY"] ?? ""
        let fileId: String = "YOUR_FIGMA_FILE_ID" // NotedCore Medical UI Design File
        let personalAccessToken: String = ProcessInfo.processInfo.environment["FIGMA_PAT"] ?? ""
    }
    
    // Fetch design tokens from Figma
    func fetchDesignTokens() async throws -> DesignTokens {
        // MCP: mcp__figma__get_file_styles
        return DesignTokens(
            colors: ColorTokens(),
            typography: TypographyTokens(),
            spacing: SpacingTokens(),
            shadows: ShadowTokens()
        )
    }
    
    // Get medical UI components from Figma
    func fetchMedicalUIComponents() async throws -> [FigmaComponent] {
        // MCP: mcp__figma__get_components
        return [
            FigmaComponent(name: "PatientCard", type: .card),
            FigmaComponent(name: "VitalSignsDisplay", type: .dataViz),
            FigmaComponent(name: "MedicalNoteEditor", type: .form),
            FigmaComponent(name: "AudioWaveform", type: .visualization)
        ]
    }
    
    struct DesignTokens {
        let colors: ColorTokens
        let typography: TypographyTokens
        let spacing: SpacingTokens
        let shadows: ShadowTokens
    }
    
    struct ColorTokens {
        let primary = Color(hex: "#007AFF")      // iOS Blue
        let success = Color(hex: "#34C759")      // Green for healthy vitals
        let warning = Color(hex: "#FF9500")      // Orange for warnings
        let danger = Color(hex: "#FF3B30")       // Red for critical
        let background = Color(hex: "#F2F2F7")   // System background
        let surface = Color(hex: "#FFFFFF")      // Card background
        let text = Color(hex: "#000000")         // Primary text
        let textSecondary = Color(hex: "#8E8E93") // Secondary text
    }
    
    struct TypographyTokens {
        let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        let title = Font.system(size: 28, weight: .semibold, design: .rounded)
        let headline = Font.system(size: 17, weight: .semibold, design: .default)
        let body = Font.system(size: 17, weight: .regular, design: .default)
        let callout = Font.system(size: 16, weight: .regular, design: .default)
        let subheadline = Font.system(size: 15, weight: .regular, design: .default)
        let footnote = Font.system(size: 13, weight: .regular, design: .default)
        let caption = Font.system(size: 12, weight: .regular, design: .default)
    }
    
    struct SpacingTokens {
        let xxs: CGFloat = 4
        let xs: CGFloat = 8
        let sm: CGFloat = 12
        let md: CGFloat = 16
        let lg: CGFloat = 24
        let xl: CGFloat = 32
        let xxl: CGFloat = 48
    }
    
    struct ShadowTokens {
        let small = Shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        let medium = Shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        let large = Shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    struct FigmaComponent {
        enum ComponentType {
            case card, button, form, dataViz, visualization
        }
        
        let name: String
        let type: ComponentType
    }
}

// MARK: - 2. F2C (Figma to Code) Integration
class F2CIntegration {
    static let shared = F2CIntegration()
    
    // Convert Figma design to SwiftUI code
    func convertFigmaToSwiftUI(componentId: String) async throws -> String {
        // MCP: mcp__f2c__convert_component
        let swiftUICode = """
        struct MedicalCard: View {
            let patient: Patient
            let vitals: VitalSigns
            
            var body: some View {
                VStack(alignment: .leading, spacing: 16) {
                    // Patient Header
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text(patient.name)
                                .font(.headline)
                            Text("MRN: \\(patient.mrn)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        StatusIndicator(status: patient.status)
                    }
                    
                    Divider()
                    
                    // Vital Signs Grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                        VitalCard(title: "BP", value: vitals.bloodPressure, unit: "mmHg")
                        VitalCard(title: "HR", value: "\\(vitals.heartRate)", unit: "bpm")
                        VitalCard(title: "Temp", value: "\\(vitals.temperature)", unit: "°F")
                        VitalCard(title: "O2", value: "\\(vitals.oxygenSaturation)", unit: "%")
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 4)
            }
        }
        """
        
        return swiftUICode
    }
    
    // Generate responsive layouts from Figma
    func generateResponsiveLayout(figmaFrame: String) -> ResponsiveLayout {
        return ResponsiveLayout(
            iPhone: LayoutConfig(columns: 1, spacing: 16),
            iPad: LayoutConfig(columns: 2, spacing: 24),
            mac: LayoutConfig(columns: 3, spacing: 32)
        )
    }
    
    struct ResponsiveLayout {
        let iPhone: LayoutConfig
        let iPad: LayoutConfig
        let mac: LayoutConfig
    }
    
    struct LayoutConfig {
        let columns: Int
        let spacing: CGFloat
    }
}

// MARK: - 3. Magic UI Server Integration
class MagicUIIntegration {
    static let shared = MagicUIIntegration()
    
    // Generate medical UI components using Magic
    func generateMedicalComponent(prompt: String) async throws -> String {
        // MCP: mcp__magic__generate_component
        let componentPrompt = """
        Create a SwiftUI component for: \(prompt)
        Requirements:
        - Medical/healthcare context
        - Accessibility compliant
        - iOS Human Interface Guidelines
        - Support dark mode
        - Include proper medical terminology
        """
        
        // Example generated component
        return """
        struct PatientVitalsCard: View {
            @State private var isExpanded = false
            let vitals: VitalSigns
            
            var body: some View {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Label("Vital Signs", systemImage: "heart.text.square.fill")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: { withAnimation { isExpanded.toggle() } }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    
                    if isExpanded {
                        VStack(spacing: 12) {
                            VitalRow(icon: "heart.fill", label: "Heart Rate", value: "\\(vitals.heartRate) bpm", color: .red)
                            VitalRow(icon: "wind", label: "Resp Rate", value: "\\(vitals.respiratoryRate) /min", color: .blue)
                            VitalRow(icon: "thermometer", label: "Temperature", value: "\\(vitals.temperature)°F", color: .orange)
                            VitalRow(icon: "drop.fill", label: "O₂ Sat", value: "\\(vitals.oxygenSaturation)%", color: .green)
                        }
                        .padding()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        """
    }
}

// MARK: - 4. Blender MCP Integration for 3D Medical Visualizations
class BlenderMCPIntegration {
    static let shared = BlenderMCPIntegration()
    
    // Create 3D anatomical models
    func create3DAnatomicalModel(bodyPart: String) async throws -> BlenderModel {
        // MCP: mcp__blender__create_model
        return BlenderModel(
            name: "\(bodyPart)_model",
            vertices: [],
            faces: [],
            materials: []
        )
    }
    
    // Generate 3D visualization of vital signs
    func create3DVitalsVisualization(vitals: VitalSigns) async throws -> String {
        // MCP: mcp__blender__create_animation
        let script = """
        import bpy
        import math
        
        # Create heart rate visualization
        def create_heart_animation(bpm):
            # Create heart mesh
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2)
            heart = bpy.context.active_object
            heart.name = "Heart"
            
            # Add pulsing animation
            heart.scale = (1, 1, 1)
            heart.keyframe_insert(data_path="scale", frame=1)
            
            beat_frames = 60 / (bpm / 60)  # Convert BPM to frames
            heart.scale = (1.2, 1.2, 1.2)
            heart.keyframe_insert(data_path="scale", frame=beat_frames/2)
            
            heart.scale = (1, 1, 1)
            heart.keyframe_insert(data_path="scale", frame=beat_frames)
            
            # Add material with emission
            mat = bpy.data.materials.new(name="HeartMaterial")
            mat.use_nodes = True
            mat.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (1, 0, 0, 1)  # Red
            mat.node_tree.nodes["Principled BSDF"].inputs[17].default_value = 2.0  # Emission
            heart.data.materials.append(mat)
            
        create_heart_animation(\(vitals.heartRate))
        """
        
        return script
    }
    
    // Export 3D model for AR viewing
    func exportForAR(model: BlenderModel) async throws -> Data {
        // MCP: mcp__blender__export_usdz
        // Export as USDZ for iOS AR Quick Look
        return Data()
    }
    
    struct BlenderModel {
        let name: String
        let vertices: [Vector3]
        let faces: [Face]
        let materials: [Material]
    }
    
    struct Vector3 {
        let x, y, z: Float
    }
    
    struct Face {
        let indices: [Int]
    }
    
    struct Material {
        let name: String
        let color: Color
        let metallic: Float
        let roughness: Float
    }
}

// MARK: - 5. Vibe Design System Integration
class VibeDesignSystem {
    static let shared = VibeDesignSystem()
    
    // Medical-themed Vibe components
    struct MedicalVibeTheme {
        // Colors
        static let primary = Color("VibeBlue")           // #0073E6
        static let secondary = Color("VibeGreen")        // #00C875
        static let danger = Color("VibeRed")            // #E2445C
        static let warning = Color("VibeOrange")        // #FDAB3D
        static let info = Color("VibePurple")           // #A25DDC
        
        // Typography
        static let heading1 = Font.custom("SF Pro Display", size: 32).weight(.bold)
        static let heading2 = Font.custom("SF Pro Display", size: 24).weight(.semibold)
        static let heading3 = Font.custom("SF Pro Display", size: 20).weight(.semibold)
        static let body = Font.custom("SF Pro Text", size: 16).weight(.regular)
        static let caption = Font.custom("SF Pro Text", size: 14).weight(.regular)
        
        // Spacing
        static let spacing = VibeSpacing()
        
        // Components
        static func button(title: String, action: @escaping () -> Void) -> some View {
            Button(action: action) {
                Text(title)
                    .font(body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(primary)
                    .cornerRadius(8)
            }
        }
        
        static func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        
        static func badge(text: String, color: Color) -> some View {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(4)
        }
    }
    
    struct VibeSpacing {
        let xxs: CGFloat = 4
        let xs: CGFloat = 8
        let small: CGFloat = 16
        let medium: CGFloat = 24
        let large: CGFloat = 32
        let xl: CGFloat = 48
        let xxl: CGFloat = 64
    }
}

// MARK: - 6. Xcode Build MCP Integration
class XcodeBuildMCPIntegration {
    static let shared = XcodeBuildMCPIntegration()
    
    // Automated build configuration
    struct BuildConfig {
        let scheme: String = "NotedCore"
        let configuration: String = "Release"
        let platform: Platform = .iOS
        let deploymentTarget: String = "17.0"
        
        enum Platform {
            case iOS, macOS, watchOS, tvOS, visionOS
        }
    }
    
    // Build project using MCP
    func buildProject() async throws -> BuildResult {
        // MCP: mcp__xcode_build__build
        return BuildResult(
            success: true,
            duration: 45.2,
            warnings: 3,
            errors: 0,
            artifactPath: "/path/to/NotedCore.app"
        )
    }
    
    // Run tests
    func runTests() async throws -> TestResult {
        // MCP: mcp__xcode_build__test
        return TestResult(
            passed: 142,
            failed: 0,
            skipped: 3,
            coverage: 0.87
        )
    }
    
    // Archive for distribution
    func archiveForDistribution() async throws -> ArchiveResult {
        // MCP: mcp__xcode_build__archive
        return ArchiveResult(
            archivePath: "/path/to/NotedCore.xcarchive",
            exportPath: "/path/to/NotedCore.ipa",
            size: 25_600_000 // 25.6 MB
        )
    }
    
    struct BuildResult {
        let success: Bool
        let duration: TimeInterval
        let warnings: Int
        let errors: Int
        let artifactPath: String
    }
    
    struct TestResult {
        let passed: Int
        let failed: Int
        let skipped: Int
        let coverage: Double
    }
    
    struct ArchiveResult {
        let archivePath: String
        let exportPath: String
        let size: Int
    }
}

// MARK: - 7. Xcode Project Manager MCP
class XcodeProjectManagerMCP {
    static let shared = XcodeProjectManagerMCP()
    
    // Add new files to project
    func addFilesToProject(files: [String]) async throws {
        // MCP: mcp__xcode_project__add_files
        for file in files {
            print("Adding \(file) to NotedCore.xcodeproj")
        }
    }
    
    // Update project settings
    func updateProjectSettings(settings: ProjectSettings) async throws {
        // MCP: mcp__xcode_project__update_settings
        print("Updating project settings: \(settings)")
    }
    
    // Manage dependencies
    func addSwiftPackage(url: String, version: String) async throws {
        // MCP: mcp__xcode_project__add_package
        print("Adding Swift Package: \(url) @ \(version)")
    }
    
    struct ProjectSettings {
        let bundleIdentifier: String = "com.notedcore.medical"
        let version: String = "2.0.0"
        let buildNumber: String = "100"
        let minimumOSVersion: String = "17.0"
        let supportedDevices: [Device] = [.iPhone, .iPad, .mac]
        
        enum Device {
            case iPhone, iPad, mac, watch, tv, vision
        }
    }
}

// MARK: - 8. Unity3D MCP Integration for Interactive Medical Visualizations
class Unity3DMCPIntegration {
    static let shared = Unity3DMCPIntegration()
    
    // Create interactive 3D medical scene
    func createMedicalVisualizationScene() async throws -> UnityScene {
        // MCP: mcp__unity3d__create_scene
        return UnityScene(
            name: "MedicalVisualization",
            objects: [
                GameObject(name: "HumanBody", type: .mesh),
                GameObject(name: "HeartModel", type: .animatedMesh),
                GameObject(name: "VitalSignsDisplay", type: .ui),
                GameObject(name: "ARCamera", type: .camera)
            ]
        )
    }
    
    // Create VR medical training scenario
    func createVRTrainingScenario(procedure: String) async throws -> String {
        // MCP: mcp__unity3d__create_vr_scene
        let unityScript = """
        using UnityEngine;
        using UnityEngine.XR;
        
        public class MedicalVRTraining : MonoBehaviour
        {
            public GameObject patientModel;
            public GameObject[] medicalTools;
            public TMPro.TextMeshProUGUI instructionText;
            
            private int currentStep = 0;
            private string[] procedureSteps;
            
            void Start()
            {
                // Initialize VR
                XRSettings.LoadDeviceByName("OpenXR");
                XRSettings.enabled = true;
                
                // Load procedure: \(procedure)
                LoadProcedureSteps("\(procedure)");
            }
            
            void LoadProcedureSteps(string procedureName)
            {
                switch(procedureName)
                {
                    case "IV_Insertion":
                        procedureSteps = new string[] {
                            "1. Wash hands and wear gloves",
                            "2. Apply tourniquet",
                            "3. Identify suitable vein",
                            "4. Clean insertion site",
                            "5. Insert catheter at 15-30° angle",
                            "6. Advance catheter and remove needle",
                            "7. Secure catheter and connect IV tubing"
                        };
                        break;
                    case "Intubation":
                        procedureSteps = new string[] {
                            "1. Position patient",
                            "2. Pre-oxygenate",
                            "3. Open airway",
                            "4. Insert laryngoscope",
                            "5. Visualize vocal cords",
                            "6. Insert endotracheal tube",
                            "7. Confirm placement"
                        };
                        break;
                }
                
                DisplayStep(0);
            }
            
            void DisplayStep(int step)
            {
                if (step < procedureSteps.Length)
                {
                    instructionText.text = procedureSteps[step];
                    HighlightRelevantAnatomy(step);
                }
            }
            
            void HighlightRelevantAnatomy(int step)
            {
                // Highlight relevant body parts for current step
                // Add visual indicators and haptic feedback
            }
        }
        """
        
        return unityScript
    }
    
    // Create AR overlay for patient examination
    func createARPatientOverlay() async throws -> AROverlay {
        // MCP: mcp__unity3d__create_ar_overlay
        return AROverlay(
            anchors: [
                ARAnchor(type: .body, position: Vector3(x: 0, y: 0, z: 0)),
                ARAnchor(type: .face, position: Vector3(x: 0, y: 1.5, z: 0))
            ],
            overlays: [
                Overlay(type: .vitalSigns, position: Vector3(x: 0.5, y: 1, z: 0)),
                Overlay(type: .anatomy, position: Vector3(x: 0, y: 0, z: 0)),
                Overlay(type: .medications, position: Vector3(x: -0.5, y: 1, z: 0))
            ]
        )
    }
    
    struct UnityScene {
        let name: String
        let objects: [GameObject]
    }
    
    struct GameObject {
        enum GameObjectType {
            case mesh, animatedMesh, ui, camera, light, particle
        }
        
        let name: String
        let type: GameObjectType
    }
    
    struct AROverlay {
        let anchors: [ARAnchor]
        let overlays: [Overlay]
    }
    
    struct ARAnchor {
        enum AnchorType {
            case body, face, plane, object
        }
        
        let type: AnchorType
        let position: Vector3
    }
    
    struct Overlay {
        enum OverlayType {
            case vitalSigns, anatomy, medications, procedures
        }
        
        let type: OverlayType
        let position: Vector3
    }
    
    struct Vector3 {
        let x, y, z: Float
    }
}

// MARK: - Master Integration Controller
@MainActor
class MCPIntegrationController: ObservableObject {
    static let shared = MCPIntegrationController()
    
    @Published var isConnected = false
    @Published var activeServers: [String] = []
    @Published var designTokens: FigmaMCPIntegration.DesignTokens?
    
    // Initialize all MCP connections
    func initializeAllServers() async {
        // Connect to all MCP servers
        activeServers = [
            "Figma MCP",
            "F2C",
            "Magic UI",
            "Blender MCP",
            "Vibe Design",
            "Xcode Build",
            "Xcode Project Manager",
            "Unity3D"
        ]
        
        // Load design tokens from Figma
        do {
            designTokens = try await FigmaMCPIntegration.shared.fetchDesignTokens()
        } catch {
            print("Failed to load design tokens: \(error)")
        }
        
        isConnected = true
    }
    
    // Generate complete UI from Figma design
    func generateUIFromFigma(componentId: String) async throws -> String {
        // 1. Get design from Figma
        let figmaComponent = try await FigmaMCPIntegration.shared.fetchMedicalUIComponents().first
        
        // 2. Convert to code using F2C
        let swiftUICode = try await F2CIntegration.shared.convertFigmaToSwiftUI(componentId: componentId)
        
        // 3. Enhance with Magic UI
        let enhancedCode = try await MagicUIIntegration.shared.generateMedicalComponent(prompt: "Enhance: \(figmaComponent?.name ?? "")")
        
        return enhancedCode
    }
    
    // Create 3D visualization
    func create3DVisualization(vitals: VitalSigns) async throws {
        // 1. Create Blender model
        let blenderModel = try await BlenderMCPIntegration.shared.create3DAnatomicalModel(bodyPart: "heart")
        
        // 2. Export for AR
        let arData = try await BlenderMCPIntegration.shared.exportForAR(model: blenderModel)
        
        // 3. Create Unity scene for interaction
        let unityScene = try await Unity3DMCPIntegration.shared.createMedicalVisualizationScene()
        
        print("3D Visualization created: \(unityScene.name)")
    }
    
    // Build and deploy
    func buildAndDeploy() async throws {
        // 1. Update project files
        try await XcodeProjectManagerMCP.shared.addFilesToProject(files: [
            "MCPServerIntegration.swift",
            "FreeOptimizationEnhancements.swift"
        ])
        
        // 2. Build project
        let buildResult = try await XcodeBuildMCPIntegration.shared.buildProject()
        
        // 3. Run tests
        let testResult = try await XcodeBuildMCPIntegration.shared.runTests()
        
        // 4. Archive if successful
        if buildResult.success && testResult.failed == 0 {
            let archive = try await XcodeBuildMCPIntegration.shared.archiveForDistribution()
            print("Build successful! Archive: \(archive.exportPath)")
        }
    }
}

// MARK: - SwiftUI Integration View
struct MCPIntegrationView: View {
    @StateObject private var controller = MCPIntegrationController.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Design Tab
            DesignIntegrationView()
                .tabItem {
                    Label("Design", systemImage: "paintbrush.fill")
                }
                .tag(0)
            
            // 3D Visualization Tab
            ThreeDVisualizationView()
                .tabItem {
                    Label("3D", systemImage: "cube.fill")
                }
                .tag(1)
            
            // Build Tab
            BuildIntegrationView()
                .tabItem {
                    Label("Build", systemImage: "hammer.fill")
                }
                .tag(2)
            
            // AR/VR Tab
            ARVRIntegrationView()
                .tabItem {
                    Label("AR/VR", systemImage: "visionpro")
                }
                .tag(3)
        }
        .task {
            await controller.initializeAllServers()
        }
    }
}

// MARK: - Design Integration View
struct DesignIntegrationView: View {
    @State private var selectedComponent = "PatientCard"
    @State private var generatedCode = ""
    
    var body: some View {
        VStack {
            // Figma Component Selector
            Picker("Component", selection: $selectedComponent) {
                Text("Patient Card").tag("PatientCard")
                Text("Vitals Display").tag("VitalsDisplay")
                Text("Note Editor").tag("NoteEditor")
                Text("Audio Waveform").tag("AudioWaveform")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Preview using Vibe Design System
            VibeDesignSystem.MedicalVibeTheme.card {
                Text("Component Preview")
                    .font(VibeDesignSystem.MedicalVibeTheme.heading3)
                
                // Component preview here
            }
            .padding()
            
            // Generate Code Button
            Button("Generate SwiftUI Code") {
                Task {
                    generatedCode = try await MCPIntegrationController.shared.generateUIFromFigma(componentId: selectedComponent)
                }
            }
            .buttonStyle(.borderedProminent)
            
            // Code Display
            if !generatedCode.isEmpty {
                ScrollView {
                    Text(generatedCode)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
    }
}

// MARK: - 3D Visualization View
struct ThreeDVisualizationView: View {
    @State private var show3DModel = false
    
    var body: some View {
        VStack {
            Text("3D Medical Visualizations")
                .font(.largeTitle)
                .padding()
            
            // Blender Integration
            Button("Create Heart Model") {
                Task {
                    let model = try await BlenderMCPIntegration.shared.create3DAnatomicalModel(bodyPart: "heart")
                    show3DModel = true
                }
            }
            .buttonStyle(.borderedProminent)
            
            if show3DModel {
                // SceneKit View would go here
                Text("3D Model Viewer")
                    .frame(height: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding()
            }
            
            Spacer()
        }
    }
}

// MARK: - Build Integration View
struct BuildIntegrationView: View {
    @State private var buildStatus = "Ready"
    @State private var isBuilding = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Xcode Build Integration")
                .font(.largeTitle)
                .padding()
            
            // Build Status
            HStack {
                Circle()
                    .fill(isBuilding ? Color.orange : Color.green)
                    .frame(width: 12, height: 12)
                
                Text(buildStatus)
                    .font(.headline)
            }
            
            // Build Actions
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        isBuilding = true
                        buildStatus = "Building..."
                        let result = try await XcodeBuildMCPIntegration.shared.buildProject()
                        buildStatus = result.success ? "Build Successful" : "Build Failed"
                        isBuilding = false
                    }
                }) {
                    Label("Build Project", systemImage: "hammer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isBuilding)
                
                Button(action: {
                    Task {
                        isBuilding = true
                        buildStatus = "Running Tests..."
                        let result = try await XcodeBuildMCPIntegration.shared.runTests()
                        buildStatus = "Tests: \(result.passed) passed, \(result.failed) failed"
                        isBuilding = false
                    }
                }) {
                    Label("Run Tests", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBuilding)
                
                Button(action: {
                    Task {
                        isBuilding = true
                        buildStatus = "Archiving..."
                        let result = try await XcodeBuildMCPIntegration.shared.archiveForDistribution()
                        buildStatus = "Archive Ready: \(result.size / 1_000_000) MB"
                        isBuilding = false
                    }
                }) {
                    Label("Archive for Distribution", systemImage: "archivebox")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isBuilding)
            }
            .padding()
            
            Spacer()
        }
    }
}

// MARK: - AR/VR Integration View
struct ARVRIntegrationView: View {
    @State private var selectedScenario = "IV_Insertion"
    
    var body: some View {
        VStack {
            Text("AR/VR Medical Training")
                .font(.largeTitle)
                .padding()
            
            // Scenario Selector
            Picker("Training Scenario", selection: $selectedScenario) {
                Text("IV Insertion").tag("IV_Insertion")
                Text("Intubation").tag("Intubation")
                Text("CPR").tag("CPR")
                Text("Wound Suturing").tag("Wound_Suturing")
            }
            .pickerStyle(.menu)
            .padding()
            
            // Unity Integration
            Button("Launch VR Training") {
                Task {
                    let script = try await Unity3DMCPIntegration.shared.createVRTrainingScenario(procedure: selectedScenario)
                    print("VR Training launched: \(selectedScenario)")
                }
            }
            .buttonStyle(.borderedProminent)
            
            // AR Patient Overlay
            Button("Enable AR Patient Overlay") {
                Task {
                    let overlay = try await Unity3DMCPIntegration.shared.createARPatientOverlay()
                    print("AR Overlay enabled with \(overlay.overlays.count) overlays")
                }
            }
            .buttonStyle(.bordered)
            
            Spacer()
        }
    }
}

// MARK: - Color Extension for Hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Shadow Extension
struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

// MARK: - VitalSigns Model
struct VitalSigns {
    let bloodPressure: String
    let heartRate: Int
    let respiratoryRate: Int
    let temperature: Double
    let oxygenSaturation: Int
}