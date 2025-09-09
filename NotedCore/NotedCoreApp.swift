import SwiftUI

import SwiftUI

@main
struct NotedCoreApp: App {
    @StateObject private var pipeline = UnifiedMedicalPipelineManager()
    @StateObject private var appState = CoreAppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(pipeline)
                .environmentObject(appState)
                .onAppear {
                    Task {
                        await initializeApp()
                    }
                }
        }
    }
    
    private func initializeApp() async {
        // Initialize configuration
        let config = NotedCoreConfiguration.shared
        let validationIssues = config.validate()
        
        if !validationIssues.isEmpty {
            print("⚠️ Configuration issues: \(validationIssues)")
        }
        
        // Initialize pipeline
        await pipeline.initialize()
        
        // Perform health check
        let healthCheck = ConfigurationManager.shared.performHealthCheck()
        print("🏥 Health Check: \(healthCheck.status)")
    }
}

// Pipeline Manager wrapper for SwiftUI
@MainActor
class UnifiedMedicalPipelineManager: ObservableObject {
    private var pipeline: UnifiedMedicalPipeline?
    @Published var isReady = false
    @Published var currentSessionID: UUID?
    
    func initialize() async {
        pipeline = UnifiedMedicalPipeline()
        isReady = true
    }
    
    func createSession(patientID: String? = nil, encounterType: EncounterType = .general) async throws -> UUID {
        guard let pipeline = pipeline else { throw PipelineError.notInitialized }
        let sessionID = try await pipeline.createSession(patientID: patientID, encounterType: encounterType)
        currentSessionID = sessionID
        return sessionID
    }
    
    func processAudio(_ data: Data) async throws -> ProcessingResult {
        guard let pipeline = pipeline, let sessionID = currentSessionID else {
            throw PipelineError.noActiveSession
        }
        return try await pipeline.processAudioChunk(data, sessionID: sessionID)
    }
    
    func finalizeSession() async throws -> FinalReport? {
        guard let pipeline = pipeline, let sessionID = currentSessionID else {
            throw PipelineError.noActiveSession
        }
        let report = try await pipeline.finalizeSession(sessionID)
        currentSessionID = nil
        return report
    }
}

enum PipelineError: Error {
    case notInitialized
    case noActiveSession
}
