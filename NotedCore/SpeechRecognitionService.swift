import Foundation
import Speech
import AVFoundation

@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {
    static let shared = SpeechRecognitionService()
    
    @Published var isAvailable = false
    @Published var isTranscribing = false
    @Published var error: SpeechError?
    @Published var currentTranscription = ""
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var lastDeliveredText: String = ""
    private let voiceDetector = VoiceActivityDetector.shared
    
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
    
    override init() {
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
        
        // Request microphone permission first
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        let microphoneStatus = await withCheckedContinuation { continuation in
            audioSession.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard microphoneStatus else {
            print("❌ Microphone permission denied")
            throw SpeechError.permissionDenied
        }
        
        print("✅ Microphone permission granted")
        #endif
        
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
        
        // MAXIMUM QUALITY: Enable all advanced recognition features
        recognitionRequest.shouldReportPartialResults = true

        // CRITICAL: Use on-device recognition for offline operation
        recognitionRequest.requiresOnDeviceRecognition = true

        // MEDICAL OPTIMIZATION:
        // 1. Task hint for medical dictation
        recognitionRequest.taskHint = .dictation

        // 2. Contextual vocabulary biasing (medical terms)
        let medicalVocab = MedicalVocabularyCache.shared.getContextualTerms()
        recognitionRequest.contextualStrings = medicalVocab

        // 3. Enable punctuation and formatting
        recognitionRequest.addsPunctuation = true

        print("✅ Speech recognition optimized with \(medicalVocab.count) medical terms")
        
        // Set up audio session (will be shared with existing audio capture)
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        #else
        // macOS doesn't use AVAudioSession, audio handled by AVAudioEngine
        print("✅ Using macOS audio configuration")
        #endif

        // Configure audio engine
        let inputNode = audioEngine.inputNode
        
        // Use the hardware's native format to avoid format mismatch
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("📊 Using audio format: \(recordingFormat.sampleRate) Hz, \(recordingFormat.channelCount) channels")
        
        // Install tap on audio input with proper buffer size
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
            // Debug: Log when we receive audio buffers
            if buffer.frameLength > 0 {
                print("🎤 Received audio buffer: \(buffer.frameLength) frames")
            }
            self?.recognitionRequest?.append(buffer)
        }

        // Start the audio engine
        audioEngine.prepare()
        try audioEngine.start()
        print("🎙️ Audio engine started successfully")

        await MainActor.run {
            self.isTranscribing = true
        }

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
                        self?.currentTranscription = transcribedText
                        CoreAppState.shared.transcription = transcribedText
                        
                        // Also update the session manager's buffer directly for UI display
                        EncounterSessionManager.shared.transcriptionBuffer = transcribedText
                        
                        print("✅ Transcription updated: '\(transcribedText)'")
                        
                        // Compute incremental fragment, enhance, and ensemble-merge
                        let fragment = self?.computeNewFragment(full: transcribedText) ?? ""
                        if !fragment.isEmpty {
                            let enhanced = MedicalVocabularyEnhancer.shared.correctTranscription(fragment).corrected
                            // TODO: Re-enable when TranscriptionEnsembler is available
                            // let mergedDelta = await TranscriptionEnsembler.shared.submit(source: .apple, fragment: enhanced, confidence: 0.7)
                            // if !mergedDelta.isEmpty {
                            //     await RealtimeMedicalProcessor.shared.appendLiveText(mergedDelta)
                            // }
                            await RealtimeMedicalProcessor.shared.appendLiveText(enhanced)
                        }
                        
                        // Update last delivered text conservatively on final or when it extends
                        if result.isFinal || transcribedText.count >= (self?.lastDeliveredText.count ?? 0) {
                            self?.lastDeliveredText = transcribedText
                        }
                        
                        if result.isFinal {
                            print("🏁 Final result confirmed")
                        }
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    let errorCode = nsError.code
                    
                    // Handle different error types
                    if errorCode == 301 { // kLSRErrorDomain Code=301 is cancellation
                        print("ℹ️ Speech Recognition was stopped normally")
                        Task {
                            await self?.stopTranscription()
                        }
                    } else if errorCode == 1110 { // "No speech detected" error
                        print("⚠️ No speech detected - continuing to listen...")
                        // Don't stop! Just continue listening
                    } else if errorCode == 203 { // Audio engine stopped error
                        print("⚠️ Audio engine issue - restarting...")
                        // Don't stop, the engine might recover
                    } else {
                        // Only stop for actual fatal errors
                        print("❌ Speech Recognition Error: \(error)")
                        self?.error = SpeechError.recognitionFailed(error.localizedDescription)
                        Task {
                            await self?.stopTranscription()
                        }
                    }
                }
            }
        }
        
        isTranscribing = true
        print("✅ Speech Recognition started successfully")
    }
    
    func stopTranscription() async {
        print("🛑 Stopping Speech Recognition...")

        // Stop the audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            print("🛑 Audio engine stopped")
        }

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isTranscribing = false
        lastDeliveredText = ""

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

// MARK: - Incremental Fragment Computation
extension SpeechRecognitionService {
    fileprivate func computeNewFragment(full: String) -> String {
        // If full contains lastDeliveredText as prefix, return the suffix
        if !lastDeliveredText.isEmpty, full.hasPrefix(lastDeliveredText) {
            // Safely check if we can create the index
            guard lastDeliveredText.count < full.count else {
                return "" // No new content if they're the same or lastDelivered is longer
            }
            let start = full.index(full.startIndex, offsetBy: lastDeliveredText.count)
            let suffix = full[start...]
            return String(suffix).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Fallback: diff by words
        let oldWords = lastDeliveredText.split(separator: " ")
        let newWords = full.split(separator: " ")
        var i = 0
        while i < oldWords.count && i < newWords.count && oldWords[i] == newWords[i] {
            i += 1
        }
        let fragmentWords = newWords.dropFirst(i)
        return fragmentWords.joined(separator: " ")
    }
    
    fileprivate func medicalContextualStrings() -> [String] {
        // Curate a limited list of specialty-specific terms and phrases
        let baseTerms = Array(MedicalVocabularyEnhancer.shared.medicalTerms.prefix(200))
        let edPhrases = [
            // Core ED
            "emergency department",
            "triage",
            "history of present illness",
            "review of systems",
            "physical exam",
            "vital signs",
            // Common ED complaints
            "chest pain",
            "shortness of breath",
            "abdominal pain",
            "headache",
            "syncope",
            // ED diagnostics and treatments
            "electrocardiogram",
            "EKG",
            "ECG",
            "chest x-ray",
            "CT angiogram",
            "CTA chest",
            "computed tomography",
            "ultrasound",
            "D-dimer",
            "troponin",
            "BMP",
            "CBC",
            // ED meds/interventions
            "nitroglycerin",
            "aspirin",
            "heparin",
            "morphine",
            "ondansetron",
            "IV fluids",
            // Risk and red flags
            "no known drug allergies",
            "return precautions",
            "follow up",
            "critical care",
            // Cardiopulmonary terms
            "tachycardia",
            "bradycardia",
            "hypotension",
            "hypertension",
            "hypoxia",
            "oxygen saturation",
            // Common conditions
            "atrial fibrillation",
            "pulmonary embolism",
            "deep vein thrombosis",
            "acute coronary syndrome",
            "congestive heart failure",
            "pneumonia"
        ]
        let hospitalPhrases = [
            "admission",
            "rounds",
            "progress note",
            "transfer orders",
            "discharge planning",
            "heparin drip",
            "telemetry",
            "DVT prophylaxis",
            "PT/OT consult",
            "case management"
        ]
        let clinicPhrases = [
            "follow up",
            "outpatient",
            "medication refill",
            "preventive care",
            "vaccination",
            "screening",
            "lab results",
            "care plan",
            "diet and exercise",
            "chronic disease management"
        ]
        let urgentCarePhrases = [
            "walk-in",
            "rapid strep",
            "influenza test",
            "urgent visit",
            "laceration repair",
            "sprain",
            "x-ray",
            "tetanus shot",
            "work note",
            "return to work"
        ]
        
        let specialty = CoreAppState.shared.specialty
        let phrases: [String]
        switch specialty {
        case .emergency: phrases = edPhrases
        case .hospitalMedicine: phrases = hospitalPhrases
        case .clinic: phrases = clinicPhrases
        case .urgentCare: phrases = urgentCarePhrases
        default: phrases = edPhrases
        }
        
        return Array(Set(baseTerms + phrases)).sorted()
    }
}
