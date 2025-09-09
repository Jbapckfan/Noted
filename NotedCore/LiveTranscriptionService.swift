import Foundation
import SwiftUI
import Combine
import WhisperKit

/// High-performance live transcription service with minimal latency
@MainActor
final class LiveTranscriptionService: ObservableObject {
    static let shared = LiveTranscriptionService()
    
    // MARK: - Live Transcription State
    @Published var liveTranscript = ""
    @Published var editableTranscript = ""
    @Published var transcriptionSegments: [TranscriptionSegment] = []
    @Published var isTranscribing = false
    @Published var lastUpdateTime = Date()
    @Published var wordsPerMinute: Int = 0
    @Published var audioLevel: Float = 0.0
    
    // MARK: - Performance Settings
    private let updateInterval: TimeInterval = 0.5  // Update UI every 500ms
    private let minSegmentLength: TimeInterval = 2.0  // Process 2-second chunks minimum
    private var updateTimer: Timer?
    private var pendingText = ""
    private var wordCount = 0
    private var sessionStartTime = Date()
    
    // Audio buffer for continuous processing
    private var audioBuffer = AudioRingBuffer(capacity: 48000 * 5)  // 5 seconds at 48kHz
    private var lastProcessedIndex = 0
    
    // WhisperKit instance
    private var whisperKit: WhisperKit?
    private var isProcessing = false
    
    struct TranscriptionSegment: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: Date
        let confidence: Float
        let isFinalized: Bool
        
        var displayTime: String {
            let formatter = DateFormatter()
            formatter.timeStyle = .medium
            return formatter.string(from: timestamp)
        }
    }
    
    private init() {
        // Setup WhisperKit for live transcription
        setupWhisperKit()
        startUpdateTimer()
    }
    
    // MARK: - WhisperKit Setup
    
    private func setupWhisperKit() {
        Task {
            do {
                // Try to load the fastest model for real-time performance
                whisperKit = try await WhisperKit(
                    model: "openai_whisper-tiny.en",  // Fastest model
                    modelRepo: "argmaxinc/whisperkit-coreml",
                    verbose: false,
                    logLevel: .error,
                    prewarm: true,
                    load: true,
                    download: true
                )
                Logger.transcriptionInfo("WhisperKit loaded for live transcription")
            } catch {
                Logger.transcriptionError("Failed to load WhisperKit: \(error)")
            }
        }
    }
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ samples: [Float], sampleRate: Float = 48000) {
        // Update audio level for UI
        let level = calculateAudioLevel(samples)
        Task { @MainActor in
            self.audioLevel = level
        }
        
        // Add to ring buffer
        audioBuffer.write(samples)
        
        // Process if we have enough data and not currently processing
        if !isProcessing && audioBuffer.availableToRead >= Int(minSegmentLength * Double(sampleRate)) {
            processAvailableAudio()
        }
    }
    
    private func processAvailableAudio() {
        // Actually process audio for live transcription
        guard !isProcessing else { return }
        
        isProcessing = true
        
        Task {
            // Get audio chunk for processing
            let chunkSize = Int(minSegmentLength * Double(48000))
            let audioChunk = audioBuffer.read(count: chunkSize)
            
            if audioChunk.count > 1000 { // Minimum viable audio
                await transcribeAudioSegment(audioChunk)
            }
            
            await MainActor.run {
                self.isProcessing = false
                self.isTranscribing = audioBuffer.availableToRead > 0
                self.lastUpdateTime = Date()
            }
        }
    }
    
    private func transcribeAudioSegment(_ audio: [Float]) async {
        guard let whisperKit = whisperKit else { return }
        
        do {
            // Downsample to 16kHz for Whisper
            let downsampled = downsample(audio, fromRate: 48000, toRate: 16000)
            
            // Quick transcription settings for real-time
            let options = DecodingOptions(
                language: "en",
                temperature: 0.0,
                temperatureIncrementOnFallback: 0.0,
                sampleLength: 224,  // Smaller chunks for speed
                topK: 3,
                usePrefillPrompt: false,
                usePrefillCache: false,
                skipSpecialTokens: true,
                withoutTimestamps: true
            )
            
            let results = try await whisperKit.transcribe(
                audioArray: downsampled,
                decodeOptions: options
            )
            
            if let result = results.first {
                await updateTranscription(result.text, confidence: 0.9)
            }
            
        } catch {
            Logger.transcriptionError("Live transcription error: \(error)")
        }
    }
    
    // MARK: - Transcription Updates
    
    func updateTranscription(_ text: String, confidence: Float) async {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }
        
        await MainActor.run {
            // Add to pending text
            pendingText += " " + cleanText
            
            // Create segment
            let segment = TranscriptionSegment(
                text: cleanText,
                timestamp: Date(),
                confidence: confidence,
                isFinalized: false
            )
            transcriptionSegments.append(segment)
            
            // Update word count for WPM
            wordCount += cleanText.split(separator: " ").count
            
            // Mark as transcribing
            isTranscribing = true
            lastUpdateTime = Date()
        }
    }
    
    // MARK: - UI Update Timer
    
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveDisplay()
            }
        }
    }
    
    private func updateLiveDisplay() {
        // Update live transcript with pending text
        if !pendingText.isEmpty {
            liveTranscript += pendingText
            editableTranscript = liveTranscript  // Keep editable version in sync
            pendingText = ""
        }
        
        // Calculate WPM
        let elapsed = Date().timeIntervalSince(sessionStartTime) / 60.0
        if elapsed > 0 {
            wordsPerMinute = Int(Double(wordCount) / elapsed)
        }
    }
    
    // MARK: - Public Interface
    
    func startLiveTranscription() async {
        await MainActor.run {
            isTranscribing = true
            sessionStartTime = Date()
            liveTranscript = ""
            editableTranscript = ""
            transcriptionSegments.removeAll()
            wordCount = 0
            pendingText = ""
        }
        
        // Ensure WhisperKit is loaded
        if whisperKit == nil {
            setupWhisperKit()
        }
        
        Logger.transcriptionInfo("Live transcription started")
    }
    
    func finalizeTranscription() async {
        await MainActor.run {
            // Finalize any pending segments
            if !pendingText.isEmpty {
                liveTranscript += pendingText
                editableTranscript = liveTranscript
                pendingText = ""
            }
            
            // Mark all segments as finalized
            for i in transcriptionSegments.indices {
                transcriptionSegments[i] = TranscriptionSegment(
                    text: transcriptionSegments[i].text,
                    timestamp: transcriptionSegments[i].timestamp,
                    confidence: transcriptionSegments[i].confidence,
                    isFinalized: true
                )
            }
            
            isTranscribing = false
        }
        
        Logger.transcriptionInfo("Live transcription finalized: \(liveTranscript.count) characters")
    }
    
    // MARK: - User Controls
    
    func updateEditableTranscript(_ newText: String) {
        editableTranscript = newText
    }
    
    func finalizeTranscript() -> String {
        // Return the edited version for LLM processing
        return editableTranscript.isEmpty ? liveTranscript : editableTranscript
    }
    
    func clearTranscription() {
        liveTranscript = ""
        editableTranscript = ""
        transcriptionSegments.removeAll()
        pendingText = ""
        wordCount = 0
        sessionStartTime = Date()
        wordsPerMinute = 0
        audioBuffer.reset()
    }
    
    // MARK: - Helper Functions
    
    private func calculateAudioLevel(_ samples: [Float]) -> Float {
        let sum = samples.reduce(0) { $0 + abs($1) }
        return min(1.0, sum / Float(samples.count) * 10)
    }
    
    private func downsample(_ input: [Float], fromRate: Int, toRate: Int) -> [Float] {
        let ratio = Float(fromRate) / Float(toRate)
        let outputLength = Int(Float(input.count) / ratio)
        var output = [Float](repeating: 0, count: outputLength)
        
        for i in 0..<outputLength {
            let sourceIndex = Int(Float(i) * ratio)
            if sourceIndex < input.count {
                output[i] = input[sourceIndex]
            }
        }
        
        return output
    }
}

// MARK: - Audio Ring Buffer

class AudioRingBuffer {
    private var buffer: [Float]
    private var writeIndex = 0
    private var readIndex = 0
    private var count = 0
    private let capacity: Int
    private let lock = NSLock()
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = [Float](repeating: 0, count: capacity)
    }
    
    func write(_ samples: [Float]) {
        lock.lock()
        defer { lock.unlock() }
        
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
            
            if count < capacity {
                count += 1
            } else {
                // Overwriting old data
                readIndex = (readIndex + 1) % capacity
            }
        }
    }
    
    func read(count requestedCount: Int) -> [Float] {
        lock.lock()
        defer { lock.unlock() }
        
        let availableCount = min(requestedCount, self.count)
        var result = [Float](repeating: 0, count: availableCount)
        
        for i in 0..<availableCount {
            result[i] = buffer[readIndex]
            readIndex = (readIndex + 1) % capacity
            self.count -= 1
        }
        
        return result
    }
    
    var availableToRead: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
    
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        
        writeIndex = 0
        readIndex = 0
        count = 0
        buffer = [Float](repeating: 0, count: capacity)
    }
}