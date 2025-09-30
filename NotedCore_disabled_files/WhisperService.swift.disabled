import Foundation
import WhisperKit
import AVFoundation
import Speech

@MainActor
final class WhisperService: ObservableObject {
    static let shared = WhisperService()
    
    @Published var isLoading = false
    @Published var isTranscribing = false
    @Published var loadingProgress: Float = 0.0
    
    private var whisperKit: WhisperKit?
    private var audioBuffer: [Float] = []
    private let minimumAudioLength: TimeInterval = 3.0 // Process every 3 seconds for better accuracy
    private var lastProcessTime: Date = Date()
    private let sampleRate: Double = 16000
    private var cumulativeTranscription: String = "" // Store running transcription
    private let maxTranscriptionLength = 50000 // Prevent unbounded growth
    private var sessionStartTime: Date = Date()
    
    // Enhanced transcription services
    private let audioProcessor = EnhancedAudioProcessor.shared
    private let vocabularyEnhancer = MedicalVocabularyEnhancer.shared
    private let corrector = RealTimeTranscriptionCorrector.shared
    
    private init() {
        loadWhisperModel()
    }
    
    private func loadWhisperModel() {
        guard whisperKit == nil else { return }
        
        isLoading = true
        loadingProgress = 0.0
        
        Task {
            do {
                print("🤖 Loading Whisper model...")
                print("🤖 Available models: \(WhisperKit.recommendedModels())")
                
                // Try better models in order of preference for medical transcription
                let modelsToTry = [
                    "openai_whisper-base.en",  // Better accuracy than tiny
                    "openai_whisper-small.en", // Even better for medical
                    "openai_whisper-base",
                    "openai_whisper-small",
                    "openai_whisper-tiny.en",  // Fallback
                    "openai_whisper-tiny"
                ]
                
                var lastError: Error?
                
                for modelName in modelsToTry {
                    do {
                        print("🤖 Trying model: \(modelName)")
                        whisperKit = try await WhisperKit(
                            model: modelName,
                            modelRepo: "argmaxinc/whisperkit-coreml",
                            verbose: true,
                            download: true
                        )
                        
                        print("✅ Whisper model '\(modelName)' loaded successfully!")
                        self.isLoading = false
                        self.loadingProgress = 1.0
                        return
                        
                    } catch {
                        print("❌ Failed to load model '\(modelName)': \(error)")
                        lastError = error
                        continue
                    }
                }
                
                // If we get here, all models failed
                throw lastError ?? NSError(domain: "WhisperKit", code: -1, userInfo: [NSLocalizedDescriptionKey: "All models failed to load"])
                
            } catch {
                print("❌ Failed to load any Whisper model: \(error)")
                print("❌ Error details: \(error.localizedDescription)")
                
                self.isLoading = false
                self.loadingProgress = 0.0
            }
        }
    }
    
    nonisolated func enqueueAudio(_ audioData: Array<Float>, frameCount: Int) {
        Task { @MainActor in
            // Add new audio data to buffer
            audioBuffer.append(contentsOf: audioData)
            
            // Check if we should process
            let requiredSamples = Int(minimumAudioLength * sampleRate)
            let timeSinceLastProcess = Date().timeIntervalSince(lastProcessTime)
            
            if audioBuffer.count >= requiredSamples || (timeSinceLastProcess > minimumAudioLength && audioBuffer.count > 0) {
                processAccumulatedAudio()
            }
        }
    }
    
    private func processAccumulatedAudio() {
        guard !audioBuffer.isEmpty && !isTranscribing else { return }
        
        // Copy buffer for processing
        let audioToProcess = Array(audioBuffer)
        audioBuffer.removeAll()
        lastProcessTime = Date()
        
        Task {
            await performTranscription(audioToProcess)
        }
    }
    
    private func performTranscription(_ audioToProcess: [Float]) async {
        self.isTranscribing = true
        
        Logger.debug("WhisperKit status - loaded: \(whisperKit != nil), isLoading: \(isLoading)", category: .transcription)
        
        if let whisperKit = whisperKit {
            // Real WhisperKit transcription
            do {
                Logger.transcriptionInfo("WhisperKit processing \(audioToProcess.count) audio samples")
                
                let enhancedAudio = enhanceAndNormalizeAudio(audioToProcess)
                let transcriptionResult = try await transcribeWithWhisperKit(whisperKit, audio: enhancedAudio)
                
                handleTranscriptionResult(transcriptionResult)
                
            } catch {
                Logger.transcriptionError("WhisperKit transcription error: \(error)")
            }
        } else {
            // No WhisperKit available - skip transcription
            Logger.transcriptionError("WhisperKit not loaded, skipping transcription of \(audioToProcess.count) samples")
        }
        
        self.isTranscribing = false
    }
    
    private func enhanceAndNormalizeAudio(_ audioData: [Float]) -> [Float] {
        // First apply existing normalization
        let normalized = normalizeAudio(audioData)
        
        // Convert to AVAudioPCMBuffer for enhancement
        guard let buffer = createPCMBuffer(from: normalized) else {
            return normalized
        }
        
        // Apply audio enhancement
        let enhanced = audioProcessor.enhanceAudioForTranscription(buffer)
        
        // Convert back to float array
        return extractFloatArray(from: enhanced) ?? normalized
    }
    
    private func createPCMBuffer(from audioData: [Float]) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(audioData.count)) else {
            return nil
        }
        
        buffer.frameLength = AVAudioFrameCount(audioData.count)
        if let channelData = buffer.floatChannelData?[0] {
            audioData.withUnsafeBufferPointer { ptr in
                channelData.initialize(from: ptr.baseAddress!, count: audioData.count)
            }
        }
        
        return buffer
    }
    
    private func extractFloatArray(from buffer: AVAudioPCMBuffer) -> [Float]? {
        guard let channelData = buffer.floatChannelData?[0] else { return nil }
        let frameLength = Int(buffer.frameLength)
        return Array(UnsafeBufferPointer(start: channelData, count: frameLength))
    }
    
    private func normalizeAudio(_ audioData: [Float]) -> [Float] {
        let maxAbs = audioData.lazy.map { abs($0) }.max() ?? 0.0
        let avgAbs = audioData.lazy.map { abs($0) }.reduce(0, +) / Float(audioData.count)
        
        print("🎤 Audio stats - Max amplitude: \(maxAbs), Avg amplitude: \(avgAbs), Samples: \(audioData.count)")
        
        guard maxAbs > 0 else {
            print("❌ Audio is completely silent!")
            return audioData
        }
        
        // Check if audio is too quiet
        if maxAbs < 0.01 {
            print("⚠️ Audio is very quiet (max < 0.01)")
        }
        
        let targetLevel: Float = 0.7
        
        if maxAbs > 1.0 {
            print("🔊 Audio clipping detected, normalizing down")
            return audioData.map { $0 / maxAbs }
        } else if maxAbs < targetLevel {
            let amplification = targetLevel / maxAbs
            print("🔊 Amplifying audio by \(amplification)x")
            return audioData.map { $0 * amplification }
        }
        
        return audioData
    }
    
    private func transcribeWithWhisperKit(_ whisperKit: WhisperKit, audio: [Float]) async throws -> [TranscriptionResult] {
        // Optimized transcription parameters for medical speech
        print("🎵 Attempting WhisperKit transcription with medical-optimized settings...")
        
        // Medical transcription optimized settings
        let decodeOptions = DecodingOptions(
            language: "en",
            temperature: 0.0,  // Use deterministic output for medical accuracy
            wordTimestamps: true,  // Enable word timestamps for better segmentation
            compressionRatioThreshold: 2.4, // Improved threshold for speech detection
            logProbThreshold: -1.0,
            noSpeechThreshold: 0.6
        )
        
        do {
            let result = try await whisperKit.transcribe(
                audioArray: audio,
                decodeOptions: decodeOptions
            )
            
            if !result.isEmpty && !(result.first?.text.isEmpty ?? true) {
                print("✅ WhisperKit succeeded with medical-optimized settings")
                return result
            }
        } catch {
            print("⚠️ WhisperKit failed with optimized settings: \(error)")
        }
        
        // Fallback with higher temperature to encourage output
        print("🔄 Trying fallback WhisperKit transcription with higher temperature...")
        let fallbackOptions = DecodingOptions(
            language: "en",
            temperature: 0.3,  // Higher temperature as fallback
            compressionRatioThreshold: 2.0,
            logProbThreshold: -1.0,
            noSpeechThreshold: 0.5
        )
        
        return try await whisperKit.transcribe(
            audioArray: audio,
            decodeOptions: fallbackOptions
        )
    }
    
    private func handleTranscriptionResult(_ transcriptionResult: [TranscriptionResult]) {
        guard !transcriptionResult.isEmpty else {
            print("❌ WhisperKit returned empty transcription results")
            return
        }
        
        let rawTranscription = transcriptionResult.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if rawTranscription.isEmpty {
            print("❌ WhisperKit transcription text is empty")
            return
        }
        
        // Apply medical vocabulary corrections
        let (correctedText, corrections) = vocabularyEnhancer.correctTranscription(rawTranscription)
        
        if !corrections.isEmpty {
            Logger.medicalAIInfo("Applied \(corrections.count) medical corrections")
            for correction in corrections.prefix(5) {  // Log first 5 corrections
                Logger.medicalAIInfo("Corrected: '\(correction.original)' → '\(correction.corrected)' (\(correction.confidence))")
            }
        }
        
        print("✅ WhisperKit transcribed: \"\(correctedText)\"")
        
        // WhisperKit is now the PRIMARY transcription engine
        let filteredText = filterNonSpeech(correctedText)
        if !filteredText.isEmpty {
            // Append to cumulative transcription with memory management
            if !cumulativeTranscription.isEmpty && !cumulativeTranscription.hasSuffix(" ") {
                cumulativeTranscription += " "
            }
            cumulativeTranscription += filteredText
            
            // Prevent unbounded memory growth during long sessions
            if cumulativeTranscription.count > maxTranscriptionLength {
                // Keep the last 80% of the transcription to maintain context
                let keepLength = Int(Double(maxTranscriptionLength) * 0.8)
                let startIndex = cumulativeTranscription.index(cumulativeTranscription.endIndex, offsetBy: -keepLength)
                cumulativeTranscription = String(cumulativeTranscription[startIndex...])
                print("⚠️ Transcription trimmed to prevent memory issues")
            }
            
            // Update CoreAppState directly with cumulative results
            Task { @MainActor in
                CoreAppState.shared.transcription = cumulativeTranscription
                print("✅ WhisperKit transcription updated (PRIMARY ENGINE)")
                print("📄 Length: \(cumulativeTranscription.count) chars, Session: \(Int(Date().timeIntervalSince(sessionStartTime)))s")
                print("🔍 Current transcription state: '\(CoreAppState.shared.transcription)'")
                print("🔍 UI should now show: '\(cumulativeTranscription)'")
            }
        } else {
            print("⚠️ Filtered text was empty after removing non-speech")
        }
    }
    
    // MARK: - Session Management
    func startNewSession() {
        // Reset all session state for new medical session
        cumulativeTranscription = ""
        audioBuffer.removeAll()
        lastProcessTime = Date()
        sessionStartTime = Date()
        print("🔄 Started new WhisperKit transcription session")
    }
    
    func finalizeCurrentSession() async {
        // Process any remaining audio in the buffer
        let remainingAudio = Array(audioBuffer)
        audioBuffer.removeAll()
        
        guard !remainingAudio.isEmpty else { return }
        
        self.isTranscribing = true
        
        if let whisperKit = whisperKit {
            // Real WhisperKit finalization
            do {
                print("🎵 Final processing of \(remainingAudio.count) samples with WhisperKit...")
                
                let transcriptionResult = try await whisperKit.transcribe(audioArray: remainingAudio)
                
                if !transcriptionResult.isEmpty {
                    let transcribedText = transcriptionResult.compactMap { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !transcribedText.isEmpty && transcribedText.count > 2 {
                        print("📝 Final transcribed: \(transcribedText)")
                        
                        if CoreAppState.shared.transcription.isEmpty {
                            CoreAppState.shared.transcription = transcribedText
                        } else {
                            CoreAppState.shared.transcription += " " + transcribedText
                        }
                    }
                }
                
            } catch {
                print("❌ Final transcription error: \(error)")
            }
        } else {
            // No WhisperKit available - skip final transcription
            print("🎵 WhisperKit not loaded, skipping final transcription of \(remainingAudio.count) samples")
        }
        
        self.isTranscribing = false
    }
    
    func reset() {
        audioBuffer.removeAll()
        lastProcessTime = Date()
        CoreAppState.shared.transcription = ""
    }
    
    var isReady: Bool {
        return !isLoading  // Ready when not loading (either real WhisperKit or fallback mode)
    }
    
    private func filterNonSpeech(_ text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // For development/testing - accept any non-empty text
        // Later we can make this more restrictive for production
        guard !cleanText.isEmpty else { return "" }
        
        // Only filter out obvious non-speech markers
        let lowercased = cleanText.lowercased()
        if lowercased == "[silence]" || lowercased == "[music]" || lowercased == "[background]" {
            return ""
        }
        
        return cleanText
    }
}
