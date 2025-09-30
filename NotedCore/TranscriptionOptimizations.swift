import Foundation
import Accelerate
import AVFoundation

/// Free transcription optimizations that improve speed and quality
class TranscriptionOptimizations {

    // MARK: - 1. Adaptive Buffer Management
    class AdaptiveBufferManager {
        private var bufferSize: Int = 16000  // Start at 1 second
        private let minSize = 8000   // 0.5 seconds
        private let maxSize = 48000  // 3 seconds
        private var latencyHistory: [Double] = []

        func adaptBufferSize(basedOn latency: Double) -> Int {
            latencyHistory.append(latency)
            if latencyHistory.count > 10 {
                latencyHistory.removeFirst()
            }

            let avgLatency = latencyHistory.reduce(0, +) / Double(latencyHistory.count)

            if avgLatency > 500 {  // Too slow, reduce buffer
                bufferSize = max(minSize, bufferSize - 2000)
            } else if avgLatency < 200 {  // Fast enough, can increase for quality
                bufferSize = min(maxSize, bufferSize + 2000)
            }

            return bufferSize
        }
    }

    // MARK: - 2. Parallel Processing Pipeline
    class ParallelProcessor {
        private let processingQueue = DispatchQueue(label: "transcription", qos: .userInitiated, attributes: .concurrent)
        private let resultQueue = DispatchQueue(label: "results", qos: .userInitiated)

        func processInParallel(
            audioChunks: [[Float]],
            processor: @escaping ([Float]) async -> String?
        ) async -> [String] {
            await withTaskGroup(of: (Int, String?).self) { group in
                for (index, chunk) in audioChunks.enumerated() {
                    group.addTask {
                        let result = await processor(chunk)
                        return (index, result)
                    }
                }

                var results: [(Int, String?)] = []
                for await result in group {
                    results.append(result)
                }

                // Sort by index to maintain order
                results.sort { $0.0 < $1.0 }
                return results.compactMap { $0.1 }
            }
        }
    }

    // MARK: - 3. Smart Phrase Deduplication
    class PhraseDeduplicator {
        private var recentPhrases: [String] = []
        private let maxHistory = 10
        private let similarityThreshold: Double = 0.85

        func deduplicate(_ text: String) -> String? {
            // Check for exact duplicates
            if recentPhrases.contains(text) {
                return nil
            }

            // Check for similar phrases using Levenshtein distance
            for recent in recentPhrases {
                let similarity = calculateSimilarity(text, recent)
                if similarity > similarityThreshold {
                    return nil  // Too similar, skip
                }
            }

            // Add to history
            recentPhrases.append(text)
            if recentPhrases.count > maxHistory {
                recentPhrases.removeFirst()
            }

            return text
        }

        private func calculateSimilarity(_ s1: String, _ s2: String) -> Double {
            let distance = levenshteinDistance(s1, s2)
            let maxLength = max(s1.count, s2.count)
            return 1.0 - (Double(distance) / Double(maxLength))
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
                    let cost = s1[s1.index(s1.startIndex, offsetBy: i-1)] ==
                               s2[s2.index(s2.startIndex, offsetBy: j-1)] ? 0 : 1
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,
                        matrix[i][j-1] + 1,
                        matrix[i-1][j-1] + cost
                    )
                }
            }
            return matrix[m][n]
        }
    }

    // MARK: - 4. Context-Aware Processing
    class ContextProcessor {
        private var contextWindow: [String] = []
        private let windowSize = 3

        func processWithContext(_ text: String) -> String {
            // Medical context keywords that suggest continuity
            let continuityWords = ["and", "also", "additionally", "furthermore", "with"]
            let medicalTerms = ["patient", "presents", "symptoms", "examination", "history"]

            var processedText = text

            // If we have context and the new text starts with a lowercase letter,
            // it's likely a continuation
            if let lastContext = contextWindow.last,
               let firstChar = text.first,
               firstChar.isLowercase {
                // Don't add a period, just append
                processedText = text
            }

            // Add medical context if missing
            if contextWindow.isEmpty && !medicalTerms.contains(where: text.lowercased().contains) {
                if text.lowercased().contains("he") || text.lowercased().contains("she") {
                    processedText = "The patient " + text.lowercased()
                }
            }

            // Update context window
            contextWindow.append(text)
            if contextWindow.count > windowSize {
                contextWindow.removeFirst()
            }

            return processedText
        }
    }

    // MARK: - 5. Audio Enhancement Pipeline
    class AudioEnhancer {
        // Pre-emphasis filter to boost high frequencies (improves speech clarity)
        func applyPreEmphasis(_ samples: [Float], factor: Float = 0.97) -> [Float] {
            guard samples.count > 1 else { return samples }

            var enhanced = [Float](repeating: 0, count: samples.count)
            enhanced[0] = samples[0]

            for i in 1..<samples.count {
                enhanced[i] = samples[i] - factor * samples[i - 1]
            }

            return enhanced
        }

        // Spectral subtraction for noise reduction (simple version)
        func reduceNoise(_ samples: [Float], noiseProfile: [Float]? = nil) -> [Float] {
            var processed = samples

            // Estimate noise from first 0.1 seconds if no profile provided
            let noiseEstimate: Float
            if let profile = noiseProfile {
                noiseEstimate = profile.reduce(0, +) / Float(profile.count)
            } else {
                let noiseWindow = min(1600, samples.count / 10)  // 0.1 seconds
                let noiseSample = Array(samples.prefix(noiseWindow))
                noiseEstimate = noiseSample.map { abs($0) }.reduce(0, +) / Float(noiseWindow)
            }

            // Simple spectral subtraction
            let threshold = noiseEstimate * 2.0
            for i in 0..<processed.count {
                if abs(processed[i]) < threshold {
                    processed[i] *= 0.1  // Reduce low-level noise
                }
            }

            return processed
        }

        // Dynamic range compression for consistent volume
        func compressAudio(_ samples: [Float], ratio: Float = 4.0, threshold: Float = 0.5) -> [Float] {
            var compressed = samples

            for i in 0..<compressed.count {
                let level = abs(compressed[i])
                if level > threshold {
                    let excess = level - threshold
                    let compressedExcess = excess / ratio
                    let newLevel = threshold + compressedExcess
                    compressed[i] = compressed[i] > 0 ? newLevel : -newLevel
                }
            }

            return compressed
        }
    }

    // MARK: - 6. Result Confidence Scoring
    class ConfidenceScorer {
        func calculateConfidence(
            text: String,
            audioEnergy: Float,
            processingTime: Double
        ) -> Float {
            var confidence: Float = 0.5  // Base confidence

            // Factor 1: Text quality
            if text.count > 10 {
                confidence += 0.1
            }
            if text.contains(" ") {  // Multiple words
                confidence += 0.1
            }

            // Factor 2: Audio energy (not too quiet, not clipping)
            if audioEnergy > 0.01 && audioEnergy < 0.9 {
                confidence += 0.15
            }

            // Factor 3: Processing speed (faster = more confident)
            if processingTime < 200 {
                confidence += 0.15
            }

            return min(confidence, 1.0)
        }
    }
}

// MARK: - Optimization Configuration
struct TranscriptionConfig {
    // Free optimizations that can be toggled
    static let enableVAD = true
    static let enableNoiseReduction = true
    static let enablePreEmphasis = true
    static let enableCompression = true
    static let enableParallelProcessing = true
    static let enableSmartCaching = true
    static let enableContextAwareness = true

    // Performance tuning
    static let targetLatency: Double = 300  // milliseconds
    static let maxConcurrentChunks = 3
    static let cacheSize = 100

    // Quality settings
    static let minConfidenceThreshold: Float = 0.4
    static let useTinyModel = true  // Tiny model is 5-10x faster
    static let useEnglishOnly = true  // English-only models are faster
}

// MARK: - Usage Example
extension OptimizedTranscriptionService {
    func applyAllOptimizations(_ samples: [Float]) -> [Float] {
        var processed = samples

        let enhancer = TranscriptionOptimizations.AudioEnhancer()

        if TranscriptionConfig.enablePreEmphasis {
            processed = enhancer.applyPreEmphasis(processed)
        }

        if TranscriptionConfig.enableNoiseReduction {
            processed = enhancer.reduceNoise(processed)
        }

        if TranscriptionConfig.enableCompression {
            processed = enhancer.compressAudio(processed)
        }

        return processed
    }
}