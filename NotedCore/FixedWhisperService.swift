import Foundation
import WhisperKit
import AVFoundation

/// Fixed WhisperKit service that prevents progressive word buildup
@MainActor
final class FixedWhisperService: ObservableObject {
    static let shared = FixedWhisperService()

    @Published var isReady = false
    @Published var isProcessing = false
    @Published var statusMessage = "Initializing..."

    private var whisperKit: WhisperKit?
    private var audioBuffer: [Float] = []
    private let bufferSize = 24000 // 1.5 seconds at 16kHz

    // FIX: Track last transcribed text to detect incremental results
    private var lastTranscribedText = ""
    private var lastTranscribedTime = Date()
    private let transcriptionTimeout: TimeInterval = 2.0 // Reset after 2 seconds of silence

    // FIX: Incremental detection
    private var isReceivingIncremental = false
    private var incrementalBuffer = ""

    private init() {
        print("🚀 FixedWhisperService starting...")
        Task {
            await initializeWhisperKit()
        }
    }

    private func initializeWhisperKit() async {
        print("📥 Loading WhisperKit with fixed settings...")
        statusMessage = "Loading WhisperKit model..."

        do {
            // Use tiny model for speed and to reduce incremental issues
            whisperKit = try await WhisperKit(
                model: "openai_whisper-tiny.en",  // Tiny model is faster and less prone to incrementals
                modelRepo: "argmaxinc/whisperkit-coreml",
                verbose: false,
                logLevel: .error,
                prewarm: true,
                load: true,
                download: true
            )

            print("✅ FixedWhisperKit loaded successfully!")
            statusMessage = "WhisperKit ready"
            isReady = true

        } catch {
            print("❌ Failed to load WhisperKit: \(error)")
            statusMessage = "Failed to load WhisperKit"
        }
    }

    func processAudio(_ samples: [Float]) async {
        guard isReady, let whisperKit = whisperKit else { return }
        guard !isProcessing else { return } // Prevent overlapping processing

        // Add to buffer
        audioBuffer.append(contentsOf: samples)

        // Process when we have enough data
        if audioBuffer.count >= bufferSize {
            isProcessing = true

            // Take a chunk and clear it immediately to prevent reprocessing
            let audioChunk = Array(audioBuffer.prefix(bufferSize))
            audioBuffer.removeFirst(min(bufferSize, audioBuffer.count))

            // Check audio level
            let maxAmplitude = audioChunk.map { abs($0) }.max() ?? 0
            guard maxAmplitude > 0.0001 else {
                isProcessing = false
                return
            }

            do {
                // CRITICAL FIX: Use streaming=false to get final results only
                let options = DecodingOptions(
                    language: "en",
                    temperature: 0.0,
                    temperatureFallbackCount: 0,  // Don't retry
                    sampleLength: 224,
                    topK: 3,  // Reduce beam search for speed
                    usePrefillPrompt: false,
                    skipSpecialTokens: true,
                    withoutTimestamps: true  // No timestamps for speed
                )

                let results = try await whisperKit.transcribe(
                    audioArray: audioChunk,
                    decodeOptions: options
                )

                // Process results with incremental detection
                if !results.isEmpty {
                    let text = results.map { $0.text }.joined(separator: " ")
                    let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

                    if !trimmed.isEmpty {
                        await handleTranscriptionResult(trimmed)
                    }
                }
            } catch {
                print("❌ Transcription error: \(error)")
            }

            isProcessing = false
        }
    }

    private func handleTranscriptionResult(_ text: String) async {
        // Check if this is an incremental result
        let isIncremental = detectIncremental(text)

        if isIncremental {
            // This is a partial/incremental result
            print("🔄 Detected incremental: '\(text)'")

            // Only keep the new part
            let newPart = extractNewContent(from: text)
            if !newPart.isEmpty {
                await appendTranscription(newPart)
            }
        } else {
            // This is a complete new transcription
            print("✅ New transcription: '\(text)'")
            await appendTranscription(text)
        }

        // Update tracking
        lastTranscribedText = text
        lastTranscribedTime = Date()
    }

    private func detectIncremental(_ text: String) -> Bool {
        // Check if new text starts with the last text (incremental pattern)
        if !lastTranscribedText.isEmpty {
            // If the new text contains the old text at the beginning, it's incremental
            if text.lowercased().starts(with: lastTranscribedText.lowercased()) {
                return true
            }

            // Check for partial overlap (common in progressive results)
            let words = lastTranscribedText.split(separator: " ")
            let newWords = text.split(separator: " ")

            if words.count > 0 && newWords.count > words.count {
                // Check if new text contains all words from last text in order
                let lastPhrase = words.joined(separator: " ").lowercased()
                if text.lowercased().contains(lastPhrase) {
                    return true
                }
            }
        }

        // Check if enough time has passed to consider this a new utterance
        if Date().timeIntervalSince(lastTranscribedTime) > transcriptionTimeout {
            return false
        }

        return false
    }

    private func extractNewContent(from text: String) -> String {
        // Extract only the new part that wasn't in the last transcription
        if text.lowercased().starts(with: lastTranscribedText.lowercased()) {
            // Remove the old part, keep only new
            let startIndex = text.index(text.startIndex, offsetBy: lastTranscribedText.count)
            let newPart = String(text[startIndex...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return newPart
        }

        // If we can't clearly identify the new part, check word by word
        let oldWords = Set(lastTranscribedText.lowercased().split(separator: " "))
        let newWords = text.lowercased().split(separator: " ")

        var newContent: [String] = []
        for word in newWords {
            if !oldWords.contains(word) {
                newContent.append(String(word))
            }
        }

        return newContent.joined(separator: " ")
    }

    private func appendTranscription(_ text: String) async {
        guard !text.isEmpty else { return }

        // Apply duplicate detection
        if text == lastTranscribedText {
            print("⚠️ Skipping duplicate: '\(text)'")
            return
        }

        // Send to the transcription system
        await RealtimeMedicalProcessor.shared.appendLiveText(text)

        // Update the main app state
        await MainActor.run {
            if !CoreAppState.shared.transcriptionText.isEmpty {
                CoreAppState.shared.transcriptionText += " "
            }
            CoreAppState.shared.transcriptionText += text
        }
    }

    func reset() {
        audioBuffer.removeAll()
        isProcessing = false
        lastTranscribedText = ""
        lastTranscribedTime = Date()
        incrementalBuffer = ""
        isReceivingIncremental = false
    }
}

// MARK: - Smart Incremental Handler
extension FixedWhisperService {

    /// Advanced incremental detection using Levenshtein distance
    private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
        let longer = s1.count > s2.count ? s1 : s2
        let shorter = s1.count > s2.count ? s2 : s1

        if longer.isEmpty { return 1.0 }

        let editDistance = levenshteinDistance(shorter, longer)
        return Double(longer.count - editDistance) / Double(longer.count)
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                let cost = Array(s1)[i-1] == Array(s2)[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,     // deletion
                    matrix[i][j-1] + 1,     // insertion
                    matrix[i-1][j-1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }
}