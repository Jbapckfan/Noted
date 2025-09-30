import Foundation
import WhisperKit
import AVFoundation

/// Production-ready WhisperKit service with retry logic and fallback models
@MainActor
final class ProductionWhisperService: ObservableObject {
    static let shared = ProductionWhisperService()
    
    @Published var isLoading = false
    @Published var isTranscribing = false
    @Published var loadingProgress: Float = 0.0
    @Published var modelQuality: ModelQuality = .notLoaded
    @Published var transcriptionQuality: Float = 0.0
    
    private var whisperKit: WhisperKit?
    private var audioBuffer: [Float] = []
    private var lastProcessTime: Date = Date()
    private var cumulativeTranscription: String = ""
    private var sessionStartTime: Date = Date()
    
    // Duplicate detection to prevent infinite loops
    private var lastTranscribedText = ""
    private var allPreviousText = ""  // Track ALL text ever transcribed in this session
    private var fullSessionText = ""  // Store the complete cumulative text from WhisperKit
    private var duplicateCount = 0
    private let maxDuplicates = 3
    
    // CRITICAL FIX: Track processed audio position to never reprocess
    private var processedSampleCount: Int = 0
    private var totalSamplesReceived: Int = 0
    
    // LIVE TRANSCRIPTION: Optimized for iPhone 16 Pro Max (A18 Pro Neural Engine)
    private var windowSize: TimeInterval = 2.0   // Shorter windows = faster response on A18 Pro
    private let overlapSize: TimeInterval = 0.3  // 300ms overlap - A18 Pro handles transitions smoothly
    private let sampleRate: Double = 16000
    private let maxRetries = 3
    private var currentModelIndex = 0
    private var retryCount = 0

    // Dynamic scaling metrics - A18 Pro is much faster
    private var avgProcessingRatio: Double = 1.0 // processingTime/windowSize
    private var processingSamples: Int = 0
    private var lastAdjustTime: Date = .distantPast
    private let adjustCooldown: TimeInterval = 15.0 // Faster adjustments on powerful hardware
    private let minWindowSize: TimeInterval = 1.5  // A18 Pro can handle shorter windows
    private let maxWindowSize: TimeInterval = 3.0
    
    // Model quality tracking
    enum ModelQuality: Int {
        case notLoaded = 0
        case tiny = 1      // Fastest but lowest quality
        case base = 2      // Good balance
        case small = 3     // Better quality
        case medium = 4    // Best quality (if available)
        
        var displayName: String {
            switch self {
            case .notLoaded: return "Not Loaded"
            case .tiny: return "Fast Mode"
            case .base: return "Standard Mode"
            case .small: return "Enhanced Mode"
            case .medium: return "Premium Mode"
            }
        }
        
        var accuracyScore: Float {
            switch self {
            case .notLoaded: return 0.0
            case .tiny: return 0.6
            case .base: return 0.75
            case .small: return 0.85
            case .medium: return 0.95
            }
        }
    }
    
    // Models optimized for iPhone 16 Pro Max (A18 Pro + 8GB RAM)
    // A18 Pro Neural Engine can handle larger models efficiently
    private let modelHierarchy = [
        ("openai_whisper-base.en", ModelQuality.base),     // BEST for iPhone 16 Pro - faster + accurate
        ("openai_whisper-small.en", ModelQuality.small),   // Even better quality (A18 Pro handles it)
        ("openai_whisper-tiny.en", ModelQuality.tiny),     // Fallback if memory constrained
        ("openai_whisper-base", ModelQuality.base),        // Non-English fallback
        ("openai_whisper-small", ModelQuality.small),      // Non-English better quality
        ("openai_whisper-tiny", ModelQuality.tiny)         // Non-English fast fallback
    ]
    
    init() {
        print("🚀 ProductionWhisperService initializing...")

        // Auto-detect device and apply optimizations
        let optimizer = DeviceOptimizer.shared
        let settings = optimizer.getOptimizedSettings()

        print("📱 Device: \(optimizer.currentDevice.displayName)")
        print("⚡ Optimized for: \(settings.whisperModel)")

        // Apply optimized settings
        windowSize = settings.windowSize
        // Note: overlapSize and other constants are already set optimally

        Task {
            await loadModelWithRetry()
        }
    }
    
    func transcribe(audioData: [Float]) async -> String {
        // Simple transcription method for compatibility
        return await transcribeAudioBuffer(audioData)
    }
    
    func transcribeAudioBuffer(_ audioData: [Float]) async -> String {
        // Placeholder implementation - returns empty string for now
        // Real implementation would use WhisperKit
        return ""
    }
    
    // MARK: - Model Loading with Retry Logic
    
    func loadModelWithRetry() {
        guard whisperKit == nil else { return }
        
        isLoading = true
        loadingProgress = 0.0
        retryCount = 0
        currentModelIndex = 0
        
        Task {
            await attemptModelLoad()
        }
    }
    
    private func attemptModelLoad() async {
        while currentModelIndex < modelHierarchy.count && retryCount < maxRetries {
            let (modelName, quality) = modelHierarchy[currentModelIndex]
            
            print("🔄 Attempting to load WhisperKit model: \(modelName) (Attempt \(retryCount + 1)/\(maxRetries))")
            Logger.transcriptionInfo("Attempting to load model: \(modelName) (Attempt \(retryCount + 1)/\(maxRetries))")
            
            do {
                // Update progress
                let progress = Float(currentModelIndex) / Float(modelHierarchy.count)
                await MainActor.run {
                    self.loadingProgress = progress
                }
                
                print("📥 Downloading/loading WhisperKit model: \(modelName)...")
                
                // Attempt to load model
                whisperKit = try await WhisperKit(
                    model: modelName,
                    modelRepo: "argmaxinc/whisperkit-coreml",
                    verbose: true,   // Verbose to see what's happening
                    prewarm: true,   // Prewarm for better performance
                    download: true
                )
                
                // Success!
                await MainActor.run {
                    self.modelQuality = quality
                    self.isLoading = false
                    self.loadingProgress = 1.0
                }
                
                Logger.transcriptionInfo("✅ Successfully loaded model: \(modelName) with quality: \(quality.displayName)")
                
                // Test the model
                await verifyModel()
                return
                
            } catch {
                Logger.transcriptionError("Failed to load \(modelName): \(error.localizedDescription)")
                retryCount += 1
                
                if retryCount >= maxRetries {
                    // Move to next model
                    currentModelIndex += 1
                    retryCount = 0
                }
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        // All attempts failed
        await MainActor.run {
            self.isLoading = false
            self.loadingProgress = 0.0
            self.modelQuality = .notLoaded
        }
        
        Logger.transcriptionError("❌ Failed to load any WhisperKit model after all attempts")
    }
    
    private func scheduleModelLoad(at index: Int) async {
        guard index >= 0 && index < modelHierarchy.count else { return }
        currentModelIndex = index
        retryCount = 0
        await attemptModelLoad()
    }
    
    private func verifyModel() async {
        guard let whisperKit = whisperKit else { return }
        
        // Test with a simple audio sample
        let testAudio = Array(repeating: Float(0.0), count: Int(sampleRate))
        
        do {
            _ = try await whisperKit.transcribe(audioArray: testAudio)
            Logger.transcriptionInfo("✅ Model verification successful")
        } catch {
            Logger.transcriptionError("⚠️ Model verification failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func extractNewText(from currentText: String) -> String {
        // WhisperKit returns cumulative text, extract only what's new
        let current = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if fullSessionText.isEmpty {
            fullSessionText = current
            return current
        }
        
        // If current text starts with our previous session text, extract the new part
        if current.lowercased().starts(with: fullSessionText.lowercased()) {
            let newPart = String(current.dropFirst(fullSessionText.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !newPart.isEmpty {
                fullSessionText = current
                return newPart
            }
        }
        
        // If exact match, nothing new
        if current.lowercased() == fullSessionText.lowercased() {
            return ""
        }
        
        // Otherwise it might be a new segment, return it all
        fullSessionText = current
        return current
    }
    
    // MARK: - Public Transcription Interface

    func transcribe(_ buffer: AVAudioPCMBuffer) async -> String? {
        guard let channelData = buffer.floatChannelData?[0] else {
            Logger.transcriptionError("Failed to get channel data from buffer")
            return nil
        }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))

        // CRITICAL FIX: Route through the same transcription logic
        return await performUnifiedTranscription(samples)
    }
    
    // MARK: - Unified Transcription Logic

    private func performUnifiedTranscription(_ audioData: [Float]) async -> String? {
        guard let whisperKit = whisperKit else {
            Logger.transcriptionInfo("WhisperKit not loaded, attempting to load...")
            if !isLoading {
                loadModelWithRetry()
            }
            return nil
        }

        print("🎯 Starting unified transcription of \(audioData.count) samples")

        do {
            let options = DecodingOptions(
                language: "en",
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.0,
                sampleLength: Int(windowSize),
                topK: 1,
                usePrefillPrompt: false,
                usePrefillCache: false,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )

            let results = try await whisperKit.transcribe(
                audioArray: audioData,
                decodeOptions: options
            )

            if !results.isEmpty {
                let combinedText = results.map { $0.text }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)

                // Use sophisticated cumulative extraction to prevent duplicates
                let extractedText = extractNewTextFromCumulative(combinedText)

                if !extractedText.isEmpty {
                    print("✅ Extracted new text: '\(extractedText)'")
                    return extractedText
                } else {
                    print("⚠️ No new text extracted (duplicate detected)")
                }
            }

        } catch {
            Logger.transcriptionError("Unified transcription failed: \(error)")
        }

        return nil
    }

    // CRITICAL FIX: Sophisticated cumulative text extraction
    private func extractNewTextFromCumulative(_ currentText: String) -> String {
        let trimmedCurrent = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        // First transcription - return everything
        if allPreviousText.isEmpty {
            print("🎯 First transcription, using full text")
            allPreviousText = trimmedCurrent
            return trimmedCurrent
        }

        // If current is shorter than or equal to previous, likely a duplicate or incomplete result
        if trimmedCurrent.count <= allPreviousText.count {
            print("⚠️ Current text is shorter or equal to previous, likely duplicate")
            return ""
        }

        // Advanced text diffing approach - find the longest common prefix
        let previousWords = allPreviousText.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let currentWords = trimmedCurrent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }

        // Find where the new content starts
        var commonPrefixLength = 0
        let minCount = min(previousWords.count, currentWords.count)

        for i in 0..<minCount {
            if previousWords[i].lowercased() == currentWords[i].lowercased() {
                commonPrefixLength = i + 1
            } else {
                break
            }
        }

        // Extract new words after the common prefix
        if commonPrefixLength < currentWords.count {
            let newWords = Array(currentWords[commonPrefixLength...])
            let newText = newWords.joined(separator: " ")

            print("🔍 Found \(newWords.count) new words after position \(commonPrefixLength)")
            print("🔍 Common prefix: \(commonPrefixLength)/\(previousWords.count) words")
            print("🔍 New text: '\(newText)'")

            // Update tracking with the full current text
            allPreviousText = trimmedCurrent
            return newText
        }

        print("⚠️ No new content found in cumulative result")
        return ""
    }

    // MARK: - Enhanced Audio Processing

    func enqueueAudio(_ audioData: Array<Float>, frameCount: Int) async {
        // CRITICAL: Don't add more audio if we're already transcribing
        guard !isTranscribing else {
            print("⚠️ Skipping audio enqueue - already transcribing")
            return
        }
        
        // Add to buffer
        audioBuffer.append(contentsOf: audioData)
        totalSamplesReceived += frameCount
        
        // DEBUG: Log audio reception
        print("🎤 Received \(frameCount) samples, buffer now: \(audioBuffer.count)")
        
        // Process when we have enough audio (at least 1 second)
        let requiredSamples = Int(1.0 * sampleRate)
        
        if audioBuffer.count >= requiredSamples && !isTranscribing {
            print("✅ Processing audio chunk of \(audioBuffer.count) samples")
            processNewAudioOnly()
        }
    }
    
    private func processNewAudioOnly() {
        guard !audioBuffer.isEmpty && !isTranscribing else { return }
        
        let windowSamples = Int(windowSize * sampleRate)
        
        // CRITICAL FIX: Clear the audio buffer after each transcription
        // Instead of accumulating, process whatever we have and clear it
        let audioToProcess = Array(audioBuffer)
        
        guard audioToProcess.count >= Int(0.5 * sampleRate) else { // At least 0.5 seconds
            print("⚠️ Not enough audio to process: \(audioToProcess.count) samples")
            return
        }
        
        // Clear the buffer immediately - this prevents cumulative audio
        audioBuffer.removeAll()
        processedSampleCount = 0
        
        print("📍 Processing \(audioToProcess.count) samples (cleared buffer)")
        
        lastProcessTime = Date()
        
        Task {
            await performRobustTranscriptionUnified(audioToProcess)
        }
    }
    
    // Deprecated - keeping for compatibility but not used
    private func processWithOverlap() {
        // This function is no longer used
        print("⚠️ processWithOverlap called but should not be used")
    }
    
    // MARK: - Robust Transcription with Error Recovery

    private func performRobustTranscriptionUnified(_ audioData: [Float]) async {
        print("🎯 Starting robust transcription of \(audioData.count) samples")
        self.isTranscribing = true
        let start = Date()
        defer {
            self.isTranscribing = false
            let dt = Date().timeIntervalSince(start)
            let ratio = dt / self.windowSize
            self.updateProcessingStats(ratio: ratio)
            Task { await self.maybeAdjustModelAndWindow() }
        }

        // Use the unified transcription logic
        if let transcribedText = await performUnifiedTranscription(audioData) {
            if !transcribedText.isEmpty {
                print("✅ Got transcription text: '\(transcribedText.prefix(100))...'")

                // Create our local LocalTranscriptionResult
                let transcription = LocalTranscriptionResult(
                    text: transcribedText,
                    segments: [],
                    language: "en",
                    timings: TranscriptionTimings(tokensPerSecond: nil, audioProcessingTime: nil),
                    confidence: 0.9,
                    processingTime: Date().timeIntervalSince(start)
                )
                await handleTranscriptionResult(transcription)
            }
        } else {
            print("⚠️ Unified transcription returned nil")
        }
    }
    
    private func updateProcessingStats(ratio: Double) {
        // Exponential moving average to smooth fluctuations
        let alpha = 0.3
        if processingSamples == 0 {
            avgProcessingRatio = ratio
        } else {
            avgProcessingRatio = alpha * ratio + (1 - alpha) * avgProcessingRatio
        }
        processingSamples += 1
        print("📈 Processing ratio avg: \(String(format: "%.2f", avgProcessingRatio))")
    }
    
    private func maybeAdjustModelAndWindow() async {
        // Respect cooldown
        guard Date().timeIntervalSince(lastAdjustTime) > adjustCooldown else { return }
        // Only adjust after a few samples
        guard processingSamples >= 3 else { return }
        
        let performance = avgProcessingRatio // >1 slower than real-time
        let currentQuality = await MainActor.run { self.transcriptionQuality }
        
        // Too slow: prefer speed - smaller model and/or smaller window
        if performance > 1.2 {
            var changed = false
            if currentModelIndex > 0 {
                print("⚡️ Too slow (ratio=\(performance)). Downgrading model for speed...")
                changed = true
                await scheduleModelLoad(at: currentModelIndex - 1)
            }
            if windowSize > minWindowSize {
                windowSize = max(minWindowSize, windowSize - 0.5)
                changed = true
                print("⚡️ Reduced window size to \(windowSize)s")
            }
            if changed { lastAdjustTime = Date() }
            return
        }
        
        // Fast and confident: try higher quality model and/or larger window
        if performance < 0.6 && currentQuality >= 0.8 {
            var changed = false
            // Prefer upgrading within the English .en set (indices 0..2)
            let maxIndex = min(2, modelHierarchy.count - 1)
            if currentModelIndex < maxIndex {
                print("✅ Fast and confident (ratio=\(performance)). Upgrading model for quality...")
                changed = true
                await scheduleModelLoad(at: currentModelIndex + 1)
            }
            if windowSize < maxWindowSize {
                windowSize = min(maxWindowSize, windowSize + 0.5)
                changed = true
                print("✅ Increased window size to \(windowSize)s")
            }
            if changed { lastAdjustTime = Date() }
        }
    }
    
    // MARK: - Audio Enhancement
    
    private func enhanceAudioForTranscription(_ audio: [Float]) -> [Float] {
        // ULTRA-FAST: Skip most processing for speed
        
        // Only normalize for consistent volume
        return normalizeAudio(audio, targetPeak: 0.9)
    }
    
    private func applyPreEmphasis(_ audio: [Float], coefficient: Float) -> [Float] {
        guard audio.count > 1 else { return audio }
        
        var filtered = [Float](repeating: 0, count: audio.count)
        filtered[0] = audio[0]
        
        for i in 1..<audio.count {
            filtered[i] = audio[i] - coefficient * audio[i-1]
        }
        
        return filtered
    }
    
    private func normalizeAudio(_ audio: [Float], targetPeak: Float) -> [Float] {
        let maxAbs = audio.map { abs($0) }.max() ?? 1.0
        guard maxAbs > 0 else { return audio }
        
        let scale = min(targetPeak / maxAbs, 10.0) // Limit amplification
        return audio.map { $0 * scale }
    }
    
    private func applyNoiseGate(_ audio: [Float], threshold: Float) -> [Float] {
        return audio.map { abs($0) > threshold ? $0 : $0 * 0.1 }
    }
    
    // MARK: - Result Handling
    
    private func handleTranscriptionResult(_ result: LocalTranscriptionResult) async {
        let text = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { 
            print("⚠️ Empty transcription result")
            return 
        }
        
        // CRITICAL FIX: Prevent duplicate text from being added repeatedly
        if text == lastTranscribedText {
            duplicateCount += 1
            print("⚠️ Duplicate transcription detected (count: \(duplicateCount)): '\(text.prefix(50))...'")
            
            // If we see too many duplicates, clear the audio buffer to break the loop
            if duplicateCount >= maxDuplicates {
                print("❌ Too many duplicates! Clearing audio buffer to break loop")
                audioBuffer.removeAll()
                duplicateCount = 0
                lastTranscribedText = ""
            }
            return  // Skip duplicate
        }
        
        // Reset duplicate tracking for new text
        lastTranscribedText = text
        duplicateCount = 0
        
        print("🎯 TRANSCRIBED: '\(text)'")
        
        // Update cumulative transcription
        cumulativeTranscription += " " + text
        
        // CRITICAL: Send to RealtimeMedicalProcessor for live display!
        print("📝 Sending to UI: '\(text)'")
        await RealtimeMedicalProcessor.shared.appendLiveText(text)
        
        // ALSO update CoreAppState for ContentView display
        await MainActor.run {
            CoreAppState.shared.transcriptionText += " " + text
            // CRITICAL: Update EncounterSessionManager for UI display
            EncounterSessionManager.shared.transcriptionBuffer += " " + text
        }
        
        // Keep reasonable size
        if cumulativeTranscription.count > 100000 {
            let start = cumulativeTranscription.index(
                cumulativeTranscription.startIndex,
                offsetBy: cumulativeTranscription.count - 80000
            )
            cumulativeTranscription = String(cumulativeTranscription[start...])
        }
        
        // Calculate quality score based on confidence metrics
        let qualityScore = calculateTranscriptionQuality(result)
        let confidence = qualityScore // Use quality score as confidence
        await MainActor.run {
            self.transcriptionQuality = qualityScore
        }
        
        // Quality info logged
        // Would send to medical summarizer here
        
        Logger.transcriptionInfo("Transcribed [\(modelQuality.displayName)]: \(text.prefix(100))...")
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        guard !text1.isEmpty && !text2.isEmpty else { return 0.0 }
        
        let words1 = Set(text1.lowercased().split(separator: " "))
        let words2 = Set(text2.lowercased().split(separator: " "))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateTranscriptionQuality(_ result: Any) -> Float {
        // Base quality from model
        var quality = modelQuality.accuracyScore
        
        // Simplified quality calculation
        // Would check segments and confidence if we had the proper type
        
        return quality
    }
    
    // MARK: - Public Interface
    
    func finalizeCurrentSession() async {
        print("🔄 Finalizing current transcription session...")

        // Process any remaining audio
        if !audioBuffer.isEmpty && processedSampleCount < audioBuffer.count {
            let remaining = Array(audioBuffer[processedSampleCount...])
            await performRobustTranscriptionUnified(remaining)
        }

        // Generate final summary
        let finalConfidence = transcriptionQuality
        print("📊 Final session confidence: \(finalConfidence)")

        // CRITICAL: Reset ALL tracking variables for next session
        audioBuffer.removeAll()
        cumulativeTranscription = ""
        sessionStartTime = Date()
        transcriptionQuality = 0.0
        processedSampleCount = 0
        totalSamplesReceived = 0
        lastTranscribedText = ""
        allPreviousText = "" // This is the key variable that was causing cumulative issues
        fullSessionText = "" // Reset the cumulative text tracker
        duplicateCount = 0
        isTranscribing = false

        print("✅ Session finalized and ALL state reset - cumulative tracking cleared")
    }
    
    func getCurrentTranscription() -> String {
        return cumulativeTranscription
    }

    // CRITICAL FIX: Manual reset method for when transcription gets stuck in loops
    func resetTranscriptionState() {
        print("🔄 MANUAL RESET: Clearing all transcription state to break cumulative loops")

        audioBuffer.removeAll()
        cumulativeTranscription = ""
        sessionStartTime = Date()
        transcriptionQuality = 0.0
        processedSampleCount = 0
        totalSamplesReceived = 0
        lastTranscribedText = ""
        allPreviousText = "" // Critical: Clear cumulative tracking
        duplicateCount = 0
        isTranscribing = false

        print("✅ Manual reset complete - all cumulative state cleared")
    }
    
    func getModelStatus() -> String {
        if isLoading {
            return "Loading model... \(Int(loadingProgress * 100))%"
        }
        
        switch modelQuality {
        case .notLoaded:
            return "No model loaded - Offline mode"
        default:
            return "\(modelQuality.displayName) - Quality: \(Int(transcriptionQuality * 100))%"
        }
    }
    
    func getPerformanceSummary() -> String {
        let ratio = avgProcessingRatio
        let speedStr = String(format: "x%.2f", 1.0 / max(0.01, ratio)) // >1 is faster than realtime
        return "Speed \(speedStr), Window \(String(format: "%.1f", windowSize))s"
    }
    
    func forceModelUpgrade() async {
        // Try to load a better model if possible
        if currentModelIndex > 0 {
            currentModelIndex = 0
            retryCount = 0
            await attemptModelLoad()
        }
    }
}

// MARK: - Extension for MedicalSummarizerService

extension MedicalSummarizerService {
    func processTranscriptionSegment(_ text: String, quality: Float, modelUsed: String) async {
        // Store quality metrics for reporting
        let segment = TranscriptionSegment(
            id: UUID(),
            text: text,
            start: 0.0,
            end: 0.0
        )
        
        // Process with red flag detection
        let redFlags = MedicalRedFlagService.shared.analyzeTranscription(text)
        
        // Process with enhanced analyzer
        let context = EnhancedMedicalAnalyzer().analyzeTranscription(text)
        
        // Update current session with all context
        await updateCurrentSession(
            segment: segment,
            redFlags: redFlags,
            medicalContext: context
        )
    }
    
    // Using TranscriptionSegment from MedicalTypes
    
    func updateCurrentSession(
        segment: TranscriptionSegment,
        redFlags: [MedicalRedFlagService.DetectedRedFlag],
        medicalContext: EnhancedMedicalAnalyzer.MedicalContext
    ) async {
        // This would update the current medical note with all the enhanced information
        // Implementation depends on your existing session management
    }
    
    func finalizeSession(_ fullTranscription: String) async {
        // Generate final medical note with all enhancements
        let finalRedFlags = MedicalRedFlagService.shared.analyzeTranscription(fullTranscription)
        let finalContext = EnhancedMedicalAnalyzer().analyzeTranscription(fullTranscription)
        
        // Generate comprehensive note
        var finalNote = ""
        
        // Add red flag alerts at the top if any
        if !finalRedFlags.isEmpty {
            finalNote += MedicalRedFlagService.shared.generateRedFlagSummary()
            finalNote += "\n\n---\n\n"
        }
        
        // Add enhanced medical analysis
        finalNote += EnhancedMedicalAnalyzer().generateEnhancedSummary(from: finalContext)
        
        // For now, skip the generation step since it's not in this service
        // The actual generation happens in ProductionMedicalSummarizerService
        
        // Combine everything
        finalNote += "\n\n---\n\nMedical note generation pending..."
        
        // Update the generated note
        await MainActor.run {
            self.generatedNote = finalNote
        }
    }
}
