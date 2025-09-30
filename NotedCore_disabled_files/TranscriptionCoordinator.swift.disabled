import SwiftUI
import Combine
import WhisperKit

/// Coordinates the entire transcription pipeline: Audio → WhisperKit → Live Updates → Medical Analysis
@MainActor
final class TranscriptionCoordinator: ObservableObject {
    static let shared = TranscriptionCoordinator()
    
    // MARK: - Published State for UI
    @Published var isActive = false
    @Published var liveTranscription = ""
    @Published var finalizedTranscription = ""
    @Published var processingStatus = "Ready"
    @Published var qualityScore: Float = 0.0
    
    // MARK: - Service References
    private let audioService = AudioCaptureService()
    private let whisperService = ProductionWhisperService.shared
    private let liveService = LiveTranscriptionService.shared
    private let summarizerService = EnhancedMedicalSummarizerService.shared
    
    // MARK: - Pipeline State
    private var cancellables = Set<AnyCancellable>()
    private let updateQueue = DispatchQueue(label: "transcription.coordinator", qos: .userInitiated)
    
    private init() {
        setupPipeline()
    }
    
    // MARK: - Core Pipeline Setup
    
    private func setupPipeline() {
        print("🔧 Setting up transcription pipeline...")
        
        // Connect audio service to state
        audioService.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isActive = isRecording
                CoreAppState.shared.isRecording = isRecording
                
                if isRecording {
                    self?.processingStatus = "Recording..."
                } else {
                    self?.processingStatus = "Ready"
                }
            }
            .store(in: &cancellables)
        
        // Connect audio level
        audioService.$level
            .receive(on: DispatchQueue.main)
            .sink { level in
                CoreAppState.shared.audioLevel = level
            }
            .store(in: &cancellables)
        
        // Connect live transcription updates
        liveService.$liveTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                self?.liveTranscription = transcript
                CoreAppState.shared.transcription = transcript
                
                // Update processing status
                if !transcript.isEmpty {
                    self?.processingStatus = "Transcribing..."
                }
            }
            .store(in: &cancellables)
        
        // Connect quality scoring
        summarizerService.$overallQualityScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                self?.qualityScore = score
            }
            .store(in: &cancellables)
        
        print("✅ Transcription pipeline connected")
    }
    
    // MARK: - Public Interface
    
    func startTranscription() async throws {
        print("🎙️ Starting complete transcription pipeline...")
        
        // Step 1: Initialize WhisperKit if needed
        processingStatus = "Loading AI models..."
        try await whisperService.loadModelWithRetry()
        
        // Step 2: Start audio capture
        processingStatus = "Starting audio capture..."
        try await audioService.start()
        
        // Step 3: Begin live transcription
        processingStatus = "Starting live transcription..."
        await liveService.startLiveTranscription()
        
        // Step 4: Enable real-time processing
        isActive = true
        processingStatus = "Recording and transcribing..."
        
        print("✅ Complete transcription pipeline active")
    }
    
    func stopTranscription() async {
        print("🛑 Stopping transcription pipeline...")
        
        processingStatus = "Finalizing transcription..."
        
        // Step 1: Stop audio capture
        audioService.stop()
        
        // Step 2: Finalize transcription
        await whisperService.finalizeCurrentSession()
        await liveService.finalizeTranscription()
        
        // Step 3: Get final transcription
        finalizedTranscription = liveService.liveTranscript
        
        // Step 4: Generate medical summary
        if !finalizedTranscription.isEmpty {
            processingStatus = "Generating medical summary..."
            await summarizerService.generateSummary(from: finalizedTranscription)
        }
        
        isActive = false
        processingStatus = "Complete"
        
        print("✅ Transcription pipeline stopped")
    }
    
    // MARK: - Quality Monitoring
    
    func getSystemHealth() -> SystemHealth {
        return SystemHealth(
            audioServiceActive: audioService.isRecording,
            whisperServiceLoaded: whisperService.whisperKit != nil,
            liveServiceActive: liveService.isTranscribing,
            overallHealth: calculateOverallHealth()
        )
    }
    
    private func calculateOverallHealth() -> Float {
        var healthScore: Float = 0.0
        var components = 0
        
        // Audio service health
        if audioService.error == nil {
            healthScore += 0.25
        }
        components += 1
        
        // WhisperKit health
        if whisperService.whisperKit != nil {
            healthScore += 0.25
        }
        components += 1
        
        // Live service health
        if liveService.isTranscribing {
            healthScore += 0.25
        }
        components += 1
        
        // Quality score
        healthScore += (qualityScore * 0.25)
        components += 1
        
        return healthScore
    }
}

// MARK: - Supporting Types

struct SystemHealth {
    let audioServiceActive: Bool
    let whisperServiceLoaded: Bool  
    let liveServiceActive: Bool
    let overallHealth: Float
    
    var isHealthy: Bool {
        return overallHealth > 0.8
    }
    
    var statusMessage: String {
        if overallHealth > 0.9 { return "Excellent" }
        if overallHealth > 0.7 { return "Good" }
        if overallHealth > 0.5 { return "Fair" }
        return "Poor"
    }
}