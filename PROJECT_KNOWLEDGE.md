markdown# NOTEDCORE PROJECT KNOWLEDGE BASE

**Purpose:** Preserve NotedCore-specific architectural decisions and patterns
**Target:** Ensure consistent implementation across Claude Code sessions
**Last Updated:** July 10, 2025

## 🏥 NOTEDCORE ARCHITECTURE DECISIONS

### Why This Specific Architecture?

#### 1. Dual Transcription Strategy
**Decision:** Apple Speech Recognition (primary) + WhisperKit (backup)
**Rationale:**
- **Apple Speech:** Real-time, optimized for iOS, 95% medical accuracy
- **WhisperKit:** Offline backup, privacy-focused, handles edge cases
- **Medical Requirements:** Need redundancy for clinical environments
- **Reliability:** Graceful degradation if one service fails
- **HIPAA Compliance:** Both work on-device without cloud dependency

#### 2. Microsoft Phi-3 Mini Selection  
**Decision:** Phi-3 Mini (3.8B parameters, 4-bit quantized) over other models
**Rationale:**
- **Medical Knowledge:** Trained on medical literature and terminology
- **Apple Silicon Optimized:** MLX framework provides best performance
- **Size/Performance Balance:** 2.4GB model fits on device, 5-15s generation
- **Privacy:** 100% on-device processing for HIPAA compliance
- **Quality:** Professional medical documentation capability

#### 3. On-Device Only Processing
**Decision:** Zero cloud dependencies, all processing local
**Rationale:**
- **HIPAA Requirements:** Patient data never leaves device
- **Privacy First:** Medical conversations stay completely private
- **Reliability:** No internet dependency in clinical settings
- **Performance:** Lower latency than cloud round-trips
- **Enterprise Ready:** Meets healthcare security standards

#### 4. Three-Tab UI Design
**Decision:** Recording | Notes | Sessions tab structure
**Rationale:**
- **Clinical Workflow:** Matches how doctors work (record → document → review)
- **Real-time Feedback:** Live audio visualization keeps doctors engaged
- **Professional Polish:** Clean interface suitable for medical environments
- **Session Management:** Easy access to previous encounters

## 🔧 NOTEDCORE CODE PATTERNS

### Service Architecture Pattern (Follow This)
```swift
// All NotedCore services follow this pattern
@MainActor
class SomeService: ObservableObject {
    @Published var status: ServiceStatus = .idle
    @Published var progress: Double = 0.0
    @Published var error: String?
    
    private let logger = Logger(subsystem: "com.notedcore.app", category: "ServiceName")
    private var isInitialized = false
    
    func initialize() async throws {
        logger.info("Initializing service...")
        // Service initialization
        isInitialized = true
    }
    
    func performOperation() async throws {
        guard isInitialized else { throw ServiceError.notInitialized }
        // Main operation with progress updates
    }
    
    private func updateProgress(_ value: Double, message: String) {
        DispatchQueue.main.async {
            self.progress = value
            self.progressMessage = message
        }
    }
}
Medical-Specific Error Handling
swiftenum MedicalServiceError: LocalizedError {
    case modelNotLoaded
    case generationFailed(String)
    case memoryConstraints
    case invalidTranscription
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Medical AI model not available. Please restart the app."
        case .generationFailed(let reason):
            return "Unable to generate medical note: \(reason)"
        case .memoryConstraints:
            return "Insufficient memory for AI processing. Close other apps and try again."
        case .invalidTranscription:
            return "No transcription available to process."
        }
    }
}
CoreAppState Integration Pattern
swift// How services integrate with NotedCore's state management
class SomeService: ObservableObject {
    @ObservedObject private var appState = CoreAppState.shared
    
    func updateAppState() {
        appState.updateTranscription(newText)
        appState.addMedicalNote(generatedNote)
        appState.updateRecordingStatus(.processing)
    }
}
📁 NOTEDCORE FILE RELATIONSHIPS
Core Service Dependencies
AudioCaptureService ✅ WORKING
    ├── Captures microphone audio
    ├── Real-time level monitoring  
    ├── Bluetooth detection
    └── Feeds to → SpeechRecognitionService & WhisperService

SpeechRecognitionService ✅ WORKING  
    ├── Apple Speech Recognition
    ├── Real-time partial results
    └── Updates → CoreAppState.transcriptionText

WhisperService ✅ WORKING
    ├── WhisperKit backup transcription
    ├── Offline processing
    └── Updates → CoreAppState.transcriptionText (as backup)

CoreAppState ✅ WORKING
    ├── Central state management
    ├── @Published properties for UI
    └── Feeds transcription to → MedicalSummarizerService

MedicalSummarizerService ✅ UI READY
    ├── Service wrapper for UI integration
    ├── Progress monitoring
    └── Delegates to → Phi3MLXService 🔄 NEEDS WORK

Phi3MLXService 🔄 PRIMARY FOCUS
    ├── MLX framework integration needed
    ├── Microsoft Phi-3 Mini model
    └── Medical note generation
UI Component Relationships
ContentView.swift ✅ COMPLETE (589 lines)
    ├── Tab 1: Recording interface with audio services
    ├── Tab 2: Medical notes with MedicalNotesView
    └── Tab 3: Session management

MedicalNotesView.swift ✅ COMPLETE
    ├── Note type selection (SOAP, Narrative, etc.)
    ├── Custom instructions input
    ├── Connects to MedicalSummarizerService
    └── Displays generated notes
🏥 MEDICAL DOMAIN KNOWLEDGE
Note Types & Clinical Use

SOAP Note - Most common clinical format

Subjective: Patient's description of symptoms
Objective: Physical examination findings, vital signs
Assessment: Clinical impression, diagnosis
Plan: Treatment plan, medications, follow-up


Narrative Note - Storytelling format

Flowing description of patient encounter
Good for complex cases requiring detailed explanation
Maintains chronological flow of appointment


Structured Note - Organized sections

Standardized headers for consistency
Easy to scan for specific information
Good for routine visits


Differential Diagnosis - Clinical reasoning focus

Multiple diagnostic possibilities
Evidence supporting/opposing each diagnosis
Diagnostic plan and rationale



Medical Accuracy Standards

Terminology: Use proper medical abbreviations (e.g., "HTN" for hypertension)
Precision: Specific measurements, dosages, durations
Clinical Logic: Diagnostic reasoning should be sound
Professional Tone: Formal medical documentation style
Completeness: Include all relevant clinical information

🛡️ NOTEDCORE SECURITY PATTERNS
HIPAA-Compliant Data Handling
swift// How NotedCore handles sensitive medical data
class SecureSessionManager {
    // All data stays on device
    private let coreDataStack = CoreDataStack()
    
    func saveSession(_ session: MedicalSession) {
        // Local CoreData only, no cloud sync
        // 10-session limit with automatic cleanup
        // No data transmission anywhere
    }
    
    func cleanupOldSessions() {
        // Automatic deletion after session limit
        // Secure data disposal
    }
}
Memory Management for AI Processing
swift// Pattern for managing large AI models
class Phi3MLXService {
    private var model: LanguageModel?
    
    func loadModel() async throws {
        // Monitor memory usage
        let memoryInfo = ProcessInfo.processInfo.physicalMemory
        guard memoryInfo > 6_000_000_000 else { // 6GB minimum
            throw MedicalServiceError.memoryConstraints
        }
        
        // Load model with cleanup
    }
    
    deinit {
        // Ensure model cleanup
        model = nil
    }
}
🚀 NOTEDCORE PERFORMANCE PATTERNS
Real-Time Audio Processing
swift// Pattern from AudioCaptureService.swift
class AudioCaptureService {
    private let audioEngine = AVAudioEngine()
    private let inputNode: AVAudioInputNode
    
    func startCapture() {
        // <100ms latency requirement
        // Real-time processing with circular buffers
        // Bluetooth microphone priority
    }
}
AI Processing with UI Feedback
swift// Pattern for long-running AI operations
func generateMedicalNote() async throws -> String {
    updateProgress(0.0, "Preparing medical AI...")
    
    return try await withCheckedThrowingContinuation { continuation in
        Task.detached { [weak self] in
            // Background AI processing
            // Progress updates on main thread
            // Don't block UI
        }
    }
}
🚨 NOTEDCORE CRITICAL PATTERNS
What Never to Modify (Working Components)
swift// These files are production-ready and optimized:
// - AudioCaptureService.swift (434 lines) - Complex audio engine
// - SpeechRecognitionService.swift - Apple Speech integration  
// - WhisperService.swift (413 lines) - Sophisticated backup system
// - ContentView.swift (589 lines) - Polished UI
// - CoreAppState.swift (134 lines) - Solid state management

// Only modify if absolutely necessary, and test extensively
Service Integration Pattern
swift// How to add new functionality to NotedCore
class NewService: ObservableObject {
    // 1. Follow @MainActor pattern
    // 2. Use @Published for UI properties
    // 3. Integrate with CoreAppState
    // 4. Add comprehensive logging
    // 5. Implement progress monitoring
    // 6. Handle errors gracefully
}
Medical Prompting Best Practices
swiftfunc buildMedicalPrompt(type: MedicalNoteType, transcription: String) -> String {
    // 1. Start with clear role definition
    // 2. Specify medical documentation standards
    // 3. Include output format requirements
    // 4. Add transcription content
    // 5. Include custom instructions
    // 6. End with clear generation request
}
🎯 NOTEDCORE QUALITY STANDARDS
Code Quality Requirements

 Follows Swift naming conventions
 Uses @MainActor for UI-related classes
 Implements comprehensive error handling
 Includes logging for debugging
 Provides user-friendly error messages
 Monitors performance and memory usage

Medical Quality Requirements

 Uses proper medical terminology
 Follows clinical documentation standards
 Includes appropriate diagnostic reasoning
 Maintains professional tone
 Supports specialty-specific needs

User Experience Requirements

 UI remains responsive during operations
 Clear progress indicators for long operations
 Intuitive error messages and recovery
 Consistent interaction patterns
 Professional appearance suitable for clinical use


NotedCore Knowledge Base: Ensuring medical-grade quality and clinical workflow optimization