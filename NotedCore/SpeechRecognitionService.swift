import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var isAvailable = false
    @Published var isTranscribing = false
    @Published var error: SpeechError?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    enum SpeechError: Error, LocalizedError {
        case recognizerUnavailable
        case permissionDenied
        case recognitionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .recognizerUnavailable:
                return "Speech recognizer is not available"
            case .permissionDenied:
                return "Speech recognition permission denied"
            case .recognitionFailed(let message):
                return "Recognition failed: \(message)"
            }
        }
    }
    
    private override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        // Use device locale, fallback to English
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        
        isAvailable = speechRecognizer?.isAvailable ?? false
        
        Logger.transcriptionInfo("Speech Recognition Setup - Locale: \(speechRecognizer?.locale.identifier ?? "unknown"), Available: \(isAvailable)")
    }
    
    func requestPermissions() async throws {
        print("🔒 Requesting speech recognition permissions...")
        
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        
        guard speechStatus == .authorized else {
            print("❌ Speech recognition permission denied: \(speechStatus)")
            throw SpeechError.permissionDenied
        }
        
        print("✅ Speech recognition permission granted")
    }
    
    func startTranscription() async throws {
        print("🎙️ Starting Speech Recognition transcription...")
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechError.recognizerUnavailable
        }
        
        try await requestPermissions()
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw SpeechError.recognitionFailed("Could not create recognition request")
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use cloud for better accuracy
        
        // Set up audio session (will be shared with existing audio capture)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    let transcribedText = result.bestTranscription.formattedString
                    print("🎙️ Speech Recognition Result: '\(transcribedText)'")
                    print("🎙️ Is Final: \(result.isFinal)")
                    
                    // Update the app state with transcription - use partial results for real-time feedback
                    if !transcribedText.isEmpty {
                        // For medical transcription, we want real-time updates
                        CoreAppState.shared.transcription = transcribedText
                        print("✅ Transcription updated: '\(CoreAppState.shared.transcription)'")
                        
                        if result.isFinal {
                            print("🏁 Final result confirmed")
                        }
                    }
                }
                
                if let error = error {
                    let errorCode = (error as NSError).code
                    // Don't treat cancellation as an error - it's normal when stopping
                    if errorCode != 301 { // kLSRErrorDomain Code=301 is cancellation
                        print("❌ Speech Recognition Error: \(error)")
                        self?.error = SpeechError.recognitionFailed(error.localizedDescription)
                    } else {
                        print("ℹ️ Speech Recognition was stopped normally")
                    }
                    self?.stopTranscription()
                }
            }
        }
        
        isTranscribing = true
        print("✅ Speech Recognition started successfully")
    }
    
    func stopTranscription() {
        print("🛑 Stopping Speech Recognition...")
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false
        
        print("✅ Speech Recognition stopped")
    }
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isTranscribing, let recognitionRequest = recognitionRequest else {
            print("⚠️ Speech Recognition: Not processing audio - isTranscribing: \(isTranscribing), hasRequest: \(recognitionRequest != nil)")
            return
        }
        
        print("🎤 Speech Recognition: Processing audio buffer with \(buffer.frameLength) frames")
        
        recognitionRequest.append(buffer)
        print("✅ Audio buffer appended to recognition request")
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechRecognitionService: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            self.isAvailable = available
            print("🎙️ Speech Recognition availability changed: \(available)")
        }
    }
}