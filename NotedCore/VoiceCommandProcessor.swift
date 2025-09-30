import Foundation
import Speech
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// Voice command processor for hands-free control
/// Supports commands like "Start encounter", "Stop encounter", "Add bookmark", "Pause recording"
class VoiceCommandProcessor: NSObject, ObservableObject {
    static let shared = VoiceCommandProcessor()
    
    @Published var isListening = false
    @Published var lastCommand: String = ""
    @Published var lastCommandTime: Date?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Command patterns
    private let commandPatterns: [(pattern: String, action: VoiceCommand)] = [
        ("start note", .startEncounter),
        ("start encounter", .startEncounter),
        ("stop note", .stopEncounter),
        ("stop encounter", .stopEncounter),
        ("pause note", .pauseRecording),
        ("pause encounter", .pauseRecording),
        ("resume note", .resumeRecording),
        ("resume encounter", .resumeRecording)
    ]
    
    enum VoiceCommand {
        case startEncounter
        case stopEncounter
        case pauseRecording
        case resumeRecording
        case addBookmark
        case nextPhase
        case previousPhase
        case saveNote
        case generateNote
        case switchToHPI
        case switchToROS
        case switchToExam
        case switchToMDM
        case showHelp
    }
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    // MARK: - Authorization
    
    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    print("Voice commands authorized")
                case .denied:
                    print("Voice commands denied")
                case .restricted:
                    print("Voice commands restricted")
                case .notDetermined:
                    print("Voice commands not determined")
                @unknown default:
                    break
                }
            }
        }
    }
    
    // MARK: - Voice Command Detection
    
    func startListening() {
        guard !isListening else { return }
        
        do {
            try startVoiceRecognition()
            isListening = true
        } catch {
            print("Failed to start voice command listening: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }
    
    private func startVoiceRecognition() throws {
        // Cancel any ongoing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceCommand", code: 1, userInfo: nil)
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Offline support
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcription = result.bestTranscription.formattedString.lowercased()
                
                // Check for wake word "Hey Noted"
                if transcription.contains("hey noted") {
                    // Process command after wake word
                    let afterWakeWord = self.extractCommandAfterWakeWord(transcription)
                    self.processCommand(afterWakeWord)
                }
                
                // Also check for direct commands (when already in listening mode)
                self.checkForDirectCommand(transcription)
            }
            
            if error != nil || result?.isFinal == true {
                self.stopListening()
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
    }
    
    private func extractCommandAfterWakeWord(_ transcription: String) -> String {
        let wakeWords = ["noted core", "hey noted"]
        for wakeWord in wakeWords {
            if let range = transcription.range(of: wakeWord) {
                return String(transcription[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return transcription
    }
    
    private func checkForDirectCommand(_ transcription: String) {
        for (pattern, command) in commandPatterns {
            if transcription.contains(pattern) {
                executeCommand(command)
                lastCommand = pattern
                lastCommandTime = Date()
                break
            }
        }
    }
    
    private func processCommand(_ commandText: String) {
        for (pattern, command) in commandPatterns {
            if commandText.contains(pattern) {
                executeCommand(command)
                lastCommand = "NotedCore: \(pattern)"
                lastCommandTime = Date()
                break
            }
        }
    }
    
    // MARK: - Command Execution
    
    private func executeCommand(_ command: VoiceCommand) {
        // Haptic feedback
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
        #endif
        
        DispatchQueue.main.async {
            switch command {
            case .startEncounter:
                self.handleStartEncounter()
                
            case .stopEncounter:
                self.handleStopEncounter()
                
            case .pauseRecording:
                self.handlePauseRecording()
                
            case .resumeRecording:
                self.handleResumeRecording()
                
            case .addBookmark:
                self.handleAddBookmark()
                
            case .nextPhase:
                self.handleNextPhase()
                
            case .previousPhase:
                self.handlePreviousPhase()
                
            case .saveNote:
                self.handleSaveNote()
                
            case .generateNote:
                self.handleGenerateNote()
                
            case .switchToHPI:
                self.switchToPhase(.intake)
                
            case .switchToROS:
                self.switchToPhase(.examination)
                
            case .switchToExam:
                self.switchToPhase(.examination)
                
            case .switchToMDM:
                self.switchToPhase(.assessment)
                
            case .showHelp:
                self.showAvailableCommands()
            }
        }
    }
    
    // MARK: - Command Handlers
    
    private func handleStartEncounter() {
        print("Voice Command: Starting encounter")
        Task {
            await LiveTranscriptionEngine.shared.startLiveTranscription()
        }
        
        // Audio feedback
        AudioServicesPlaySystemSound(1054) // Tink sound
    }
    
    private func handleStopEncounter() {
        print("Voice Command: Stopping encounter")
        Task {
            await LiveTranscriptionEngine.shared.stopTranscription()
        }
        
        // Audio feedback
        AudioServicesPlaySystemSound(1055) // Tweet sound
    }
    
    private func handlePauseRecording() {
        print("Voice Command: Pausing recording")
        Task {
            await LiveTranscriptionEngine.shared.pauseTranscription()
        }
    }
    
    private func handleResumeRecording() {
        print("Voice Command: Resuming recording")
        Task {
            await LiveTranscriptionEngine.shared.resumeTranscription()
        }
    }
    
    @MainActor
    private func handleAddBookmark() {
        print("Voice Command: Adding bookmark")
        // Add bookmark functionality
        NotificationCenter.default.post(name: NSNotification.Name("AddBookmark"), object: nil)
        
        // Audio feedback
        AudioServicesPlaySystemSound(1057) // Tick sound
    }
    
    @MainActor
    private func handleNextPhase() {
        print("Voice Command: Next phase")
        let currentPhase = EncounterSessionManager.shared.currentPhase
        let allPhases = EncounterPhaseType.allCases
        if let currentIndex = allPhases.firstIndex(of: currentPhase),
           currentIndex < allPhases.count - 1 {
            let nextPhase = allPhases[currentIndex + 1]
            EncounterSessionManager.shared.transitionToPhase(nextPhase)
        }
    }
    
    @MainActor
    private func handlePreviousPhase() {
        print("Voice Command: Previous phase")
        let currentPhase = EncounterSessionManager.shared.currentPhase
        let allPhases = EncounterPhaseType.allCases
        if let currentIndex = allPhases.firstIndex(of: currentPhase),
           currentIndex > 0 {
            let previousPhase = allPhases[currentIndex - 1]
            EncounterSessionManager.shared.transitionToPhase(previousPhase)
        }
    }
    
    @MainActor
    private func handleSaveNote() {
        print("Voice Command: Saving note")
        EncounterSessionManager.shared.saveEditedTranscript(
            EncounterSessionManager.shared.editableTranscript
        )
    }
    
    @MainActor
    private func handleGenerateNote() {
        print("Voice Command: Generating note")
        EncounterSessionManager.shared.generateNote()
    }
    
    @MainActor
    private func switchToPhase(_ phase: EncounterPhaseType) {
        print("Voice Command: Switching to \(phase.rawValue)")
        EncounterSessionManager.shared.transitionToPhase(phase)
    }
    
    private func showAvailableCommands() {
        let commands = """
        Available voice commands:
        • "Start encounter" - Begin recording
        • "Stop encounter" - End recording
        • "Pause" / "Resume" - Control recording
        • "Add bookmark" - Mark important moment
        • "Next/Previous phase" - Navigate phases
        • "Switch to HPI/ROS/Exam/MDM" - Jump to phase
        • "Generate note" - Create medical note
        • "Save note" - Save current session
        
        Wake word: "Hey Noted"
        """
        
        print(commands)
        
        // You could also show this in a UI alert or notification
        NotificationCenter.default.post(
            name: NSNotification.Name("VoiceCommandHelp"),
            object: nil,
            userInfo: ["commands": commands]
        )
    }
}