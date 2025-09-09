import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
class VoiceCommandService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isListeningForCommands = false
    @Published var lastCommandHeard = ""
    @Published var commandStatus = "Ready"
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    // MARK: - Voice Command Patterns
    private let commandPatterns = [
        // Encounter management
        "hey noted start a new encounter",
        "hey noted start new encounter", 
        "hey noted new encounter",
        "hey noted stop this encounter",
        "hey noted stop encounter",
        "hey noted end encounter",
        
        // Bed-specific commands
        "hey noted start a new note on bed (\\d+) for (.+)",
        "hey noted start new patient encounter on bed (\\d+) (.+)",
        "hey noted new patient on bed (\\d+) (.+)",
        "hey noted bed (\\d+) (.+)",
        
        // Location-specific
        "hey noted start trauma (\\d+) for (.+)",
        "hey noted fast track (\\d+) (.+)",
        "hey noted psych bed for (.+)"
    ]
    
    // MARK: - Delegate
    var delegate: VoiceCommandDelegate?
    
    override init() {
        super.init()
        setupSpeechRecognition()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognition() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Voice Command Listening
    func startListeningForCommands() async {
        guard speechRecognizer?.isAvailable == true else {
            commandStatus = "Speech recognition not available"
            return
        }
        
        do {
            try await requestPermissions()
            try startCommandRecognition()
            isListeningForCommands = true
            commandStatus = "Listening for 'Hey Noted...' commands"
        } catch {
            commandStatus = "Error starting voice commands: \(error.localizedDescription)"
        }
    }
    
    func stopListeningForCommands() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        isListeningForCommands = false
        commandStatus = "Voice commands stopped"
    }
    
    // MARK: - Command Recognition
    private func startCommandRecognition() throws {
        // Cancel previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceCommandError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
    }
    
    // MARK: - Command Processing
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            print("Voice command error: \(error)")
            return
        }
        
        guard let result = result else { return }
        
        let spokenText = result.bestTranscription.formattedString.lowercased()
        lastCommandHeard = spokenText
        
        // Check for wake phrase
        if spokenText.contains("hey noted") {
            processVoiceCommand(spokenText)
        }
    }
    
    private func processVoiceCommand(_ spokenText: String) {
        commandStatus = "Processing: \(spokenText)"
        
        // Parse command
        if let command = parseVoiceCommand(spokenText) {
            delegate?.executeVoiceCommand(command)
            commandStatus = "Executed: \(command.description)"
            
            // Provide audio feedback
            provideAudioFeedback(for: command)
        } else {
            commandStatus = "Command not recognized"
            provideAudioFeedback(for: nil)
        }
    }
    
    // MARK: - Command Parsing
    private func parseVoiceCommand(_ spokenText: String) -> VoiceCommand? {
        let text = spokenText.lowercased()
        
        // New encounter commands
        if text.contains("start a new encounter") || text.contains("start new encounter") || text.contains("new encounter") {
            return .newEncounter
        }
        
        if text.contains("stop this encounter") || text.contains("stop encounter") || text.contains("end encounter") {
            return .stopEncounter
        }
        
        // Bed-specific commands with regex
        if let bedCommand = parseBedCommand(text) {
            return bedCommand
        }
        
        return nil
    }
    
    private func parseBedCommand(_ text: String) -> VoiceCommand? {
        // "hey noted start a new note on bed 3 for chest pain"
        let bedPattern = "hey noted.*bed (\\d+).*for (.+)"
        if let regex = try? NSRegularExpression(pattern: bedPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let bedRange = Range(match.range(at: 1), in: text),
                   let complaintRange = Range(match.range(at: 2), in: text) {
                    let bedNumber = String(text[bedRange])
                    let complaint = String(text[complaintRange])
                    return .newPatientOnBed(bed: bedNumber, complaint: complaint)
                }
            }
        }
        
        // "hey noted trauma 1 for multiple trauma"
        let traumaPattern = "hey noted.*trauma (\\d+).*for (.+)"
        if let regex = try? NSRegularExpression(pattern: traumaPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let bedRange = Range(match.range(at: 1), in: text),
                   let complaintRange = Range(match.range(at: 2), in: text) {
                    let bedNumber = String(text[bedRange])
                    let complaint = String(text[complaintRange])
                    return .newPatientOnBed(bed: "Trauma \(bedNumber)", complaint: complaint)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Audio Feedback
    private func provideAudioFeedback(for command: VoiceCommand?) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance: AVSpeechUtterance
        
        if let command = command {
            switch command {
            case .newEncounter:
                utterance = AVSpeechUtterance(string: "Starting new encounter")
            case .stopEncounter:
                utterance = AVSpeechUtterance(string: "Encounter saved")
            case .newPatientOnBed(let bed, let complaint):
                utterance = AVSpeechUtterance(string: "Starting \(bed) for \(complaint)")
            }
        } else {
            utterance = AVSpeechUtterance(string: "Command not recognized")
        }
        
        utterance.rate = 0.5
        utterance.volume = 0.8
        synthesizer.speak(utterance)
    }
    
    // MARK: - Permissions
    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw VoiceCommandError.speechPermissionDenied
        }
        
        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard audioStatus else {
            throw VoiceCommandError.audioPermissionDenied
        }
    }
}

// MARK: - Voice Commands
enum VoiceCommand: CustomStringConvertible {
    case newEncounter
    case stopEncounter
    case newPatientOnBed(bed: String, complaint: String)
    
    var description: String {
        switch self {
        case .newEncounter:
            return "New Encounter"
        case .stopEncounter:
            return "Stop Encounter"
        case .newPatientOnBed(let bed, let complaint):
            return "New Patient on \(bed) - \(complaint)"
        }
    }
}

// MARK: - Voice Command Delegate
protocol VoiceCommandDelegate {
    func executeVoiceCommand(_ command: VoiceCommand)
}

// MARK: - Errors
enum VoiceCommandError: Error, LocalizedError {
    case speechPermissionDenied
    case audioPermissionDenied
    case failedToCreateRequest
    
    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "Speech recognition permission denied"
        case .audioPermissionDenied:
            return "Audio permission denied"
        case .failedToCreateRequest:
            return "Failed to create recognition request"
        }
    }
}

// MARK: - Speech Recognizer Delegate
extension VoiceCommandService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            commandStatus = available ? "Voice commands available" : "Voice commands unavailable"
        }
    }
}