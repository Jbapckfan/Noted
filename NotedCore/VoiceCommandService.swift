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
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #else
        // macOS handles audio differently
        print("✅ Using macOS audio configuration for voice commands")
        #endif
        
        // Setup recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceCommandError.failedToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = true // Neural Engine for fastest voice commands
        
        // Setup audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { buffer, _ in
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

        // Start commands
        if text.contains("start note") || text.contains("start encounter") {
            return .startEncounter
        }

        // Stop commands
        if text.contains("stop note") || text.contains("stop encounter") {
            return .stopEncounter
        }

        // Pause commands
        if text.contains("pause note") || text.contains("pause encounter") {
            return .pauseEncounter
        }

        // Resume commands
        if text.contains("resume note") || text.contains("resume encounter") {
            return .resumeEncounter
        }

        // Bed-specific commands with regex
        if let bedCommand = parseBedCommand(text) {
            return bedCommand
        }

        return nil
    }
    
    private func parseBedCommand(_ text: String) -> VoiceCommand? {
        let lowerText = text.lowercased()

        // "hey noted start note on trauma 1 for chest pain"
        let traumaWithComplaintPattern = "hey noted.*start note on trauma ([12]).*for (.+)"
        if let regex = try? NSRegularExpression(pattern: traumaWithComplaintPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let traumaRange = Range(match.range(at: 1), in: text),
                   let complaintRange = Range(match.range(at: 2), in: text) {
                    let traumaNumber = String(text[traumaRange])
                    let complaint = String(text[complaintRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    return .newPatientOnBed(bed: "Trauma \(traumaNumber)", complaint: complaint)
                }
            }
        }

        // "hey noted start note on trauma 1" (without complaint)
        let traumaOnlyPattern = "hey noted.*start note on trauma ([12])"
        if let regex = try? NSRegularExpression(pattern: traumaOnlyPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let traumaRange = Range(match.range(at: 1), in: text) {
                    let traumaNumber = String(text[traumaRange])
                    return .newPatientOnBed(bed: "Trauma \(traumaNumber)", complaint: "")
                }
            }
        }

        // "hey noted start note on psych 10 for altered mental status" or "hey noted start note on bed 10 for psych"
        if lowerText.contains("psych 10") || lowerText.contains("psych ten") ||
           (lowerText.contains("bed 10") || lowerText.contains("bed ten")) {
            let complaint = extractComplaintFromPsychCommand(text)
            return .newPatientOnBed(bed: "Bed 10 (Psych)", complaint: complaint)
        }

        // "hey noted start note on fast track 3 for laceration" or "hey noted start note on FT 3"
        let fastTrackWithComplaintPattern = "hey noted.*start note on (?:fast track|ft) ([1-5]).*for (.+)"
        if let regex = try? NSRegularExpression(pattern: fastTrackWithComplaintPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let ftRange = Range(match.range(at: 1), in: text),
                   let complaintRange = Range(match.range(at: 2), in: text) {
                    let ftNumber = String(text[ftRange])
                    let complaint = String(text[complaintRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    return .newPatientOnBed(bed: "Fast Track \(ftNumber)", complaint: complaint)
                }
            }
        }

        // "hey noted start note on fast track 3" or "hey noted start note on FT 3" (without complaint)
        let fastTrackOnlyPattern = "hey noted.*start note on (?:fast track|ft) ([1-5])"
        if let regex = try? NSRegularExpression(pattern: fastTrackOnlyPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let ftRange = Range(match.range(at: 1), in: text) {
                    let ftNumber = String(text[ftRange])
                    return .newPatientOnBed(bed: "Fast Track \(ftNumber)", complaint: "")
                }
            }
        }

        // "hey noted start note on bed 3-9, 11-12, 14 for chest pain"
        let bedWithComplaintPattern = "hey noted.*start note on bed (\\d+).*for (.+)"
        if let regex = try? NSRegularExpression(pattern: bedWithComplaintPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let bedRange = Range(match.range(at: 1), in: text),
                   let complaintRange = Range(match.range(at: 2), in: text) {
                    let bedNumber = String(text[bedRange])
                    let complaint = String(text[complaintRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                    // Validate bed number (3-10, 11-12, 14 - no 13)
                    if isValidBedNumber(bedNumber) {
                        let bedName = bedNumber == "10" ? "Bed 10 (Psych)" : "Bed \(bedNumber)"
                        return .newPatientOnBed(bed: bedName, complaint: complaint)
                    }
                }
            }
        }

        // "hey noted start note on bed 3" (without complaint)
        let bedOnlyPattern = "hey noted.*start note on bed (\\d+)"
        if let regex = try? NSRegularExpression(pattern: bedOnlyPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                if let bedRange = Range(match.range(at: 1), in: text) {
                    let bedNumber = String(text[bedRange])

                    // Validate bed number (3-10, 11-12, 14 - no 13)
                    if isValidBedNumber(bedNumber) {
                        let bedName = bedNumber == "10" ? "Bed 10 (Psych)" : "Bed \(bedNumber)"
                        return .newPatientOnBed(bed: bedName, complaint: "")
                    }
                }
            }
        }

        return nil
    }

    private func extractComplaintFromPsychCommand(_ text: String) -> String {
        if text.lowercased().contains(" for ") {
            let components = text.lowercased().components(separatedBy: " for ")
            if components.count > 1 {
                return components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return ""
    }

    private func isValidBedNumber(_ bedNumber: String) -> Bool {
        guard let number = Int(bedNumber) else { return false }

        // Valid bed numbers: 3-10 (10=Psych), 11-12, 14 (no 13)
        switch number {
        case 3...12, 14:
            return number != 13 // Exclude 13
        default:
            return false
        }
    }
    
    // MARK: - Audio Feedback
    private func provideAudioFeedback(for command: VoiceCommand?) {
        let synthesizer = AVSpeechSynthesizer()
        let utterance: AVSpeechUtterance
        
        if let command = command {
            switch command {
            case .startEncounter:
                utterance = AVSpeechUtterance(string: "Starting encounter")
            case .stopEncounter:
                utterance = AVSpeechUtterance(string: "Encounter stopped")
            case .pauseEncounter:
                utterance = AVSpeechUtterance(string: "Encounter paused")
            case .resumeEncounter:
                utterance = AVSpeechUtterance(string: "Encounter resumed")
            case .newPatientOnBed(let bed, let complaint):
                if complaint.isEmpty {
                    utterance = AVSpeechUtterance(string: "Starting note on \(bed)")
                } else {
                    utterance = AVSpeechUtterance(string: "Starting \(bed) for \(complaint)")
                }
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
        
        #if os(iOS)
        let audioStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        guard audioStatus else {
            throw VoiceCommandError.audioPermissionDenied
        }
        #else
        // macOS handles permissions differently
        // Permission requests are handled at the system level
        print("✅ macOS audio permissions handled by system")
        #endif
    }
}

// MARK: - Voice Commands
enum VoiceCommand: CustomStringConvertible {
    case startEncounter
    case stopEncounter
    case pauseEncounter
    case resumeEncounter
    case newPatientOnBed(bed: String, complaint: String)

    var description: String {
        switch self {
        case .startEncounter:
            return "Start Encounter"
        case .stopEncounter:
            return "Stop Encounter"
        case .pauseEncounter:
            return "Pause Encounter"
        case .resumeEncounter:
            return "Resume Encounter"
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