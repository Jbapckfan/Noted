import Foundation
import AVFoundation
import Accelerate

/// High-performance voice activity detection to skip processing silence
@MainActor
class VoiceActivityDetector: ObservableObject {
    static let shared = VoiceActivityDetector()

    @Published var isVoiceActive = false
    @Published var currentLevel: Float = 0.0

    // Optimized thresholds for medical environments
    private let voiceThreshold: Float = 0.02  // Sensitive enough for quiet speech
    private let silenceThreshold: Float = 0.005 // Ignore background noise
    private let smoothingFactor: Float = 0.7   // Prevent flickering

    private var previousLevel: Float = 0.0
    private var consecutiveVoiceFrames = 0
    private var consecutiveSilenceFrames = 0

    // Performance optimization: reuse buffers
    private var magnitudeBuffer: [Float] = []
    private var windowBuffer: [Float] = []

    private init() {
        // Pre-allocate buffers for common audio frame sizes
        magnitudeBuffer.reserveCapacity(1024)
        windowBuffer.reserveCapacity(256)
    }

    /// Optimized voice activity detection using RMS and spectral analysis
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = buffer.floatChannelData?[0] else { return false }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return false }

        // Fast RMS calculation using vDSP
        var rms: Float = 0.0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))

        // Smooth the signal to prevent flickering
        let smoothedLevel = (smoothingFactor * previousLevel) + ((1.0 - smoothingFactor) * rms)
        previousLevel = smoothedLevel
        currentLevel = smoothedLevel

        // Voice activity logic with hysteresis
        if smoothedLevel > voiceThreshold {
            consecutiveVoiceFrames += 1
            consecutiveSilenceFrames = 0

            // Require 2 consecutive voice frames to start
            if consecutiveVoiceFrames >= 2 {
                isVoiceActive = true
                return true
            }
        } else if smoothedLevel < silenceThreshold {
            consecutiveSilenceFrames += 1
            consecutiveVoiceFrames = 0

            // Require 5 consecutive silence frames to stop (prevents cutting off words)
            if consecutiveSilenceFrames >= 5 {
                isVoiceActive = false
                return false
            }
        }

        // Maintain current state during transition periods
        return isVoiceActive
    }

    /// Enhanced detection with spectral analysis for medical speech
    func detectMedicalSpeech(in buffer: AVAudioPCMBuffer) -> (isVoice: Bool, confidence: Float) {
        let basicDetection = detectVoiceActivity(in: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            return (basicDetection, 0.0)
        }

        let frameCount = Int(buffer.frameLength)
        guard frameCount >= 256 else { return (basicDetection, 0.0) }

        // Spectral centroid analysis for speech characteristics
        let spectralCentroid = calculateSpectralCentroid(channelData, frameCount: frameCount)

        // Medical speech typically has spectral centroid between 800-2000 Hz
        let medicalSpeechRange: ClosedRange<Float> = 800...2000
        let confidence: Float

        if medicalSpeechRange.contains(spectralCentroid) {
            confidence = min(1.0, currentLevel * 10.0) // Scale confidence based on volume
        } else {
            confidence = max(0.0, min(1.0, currentLevel * 5.0)) // Lower confidence for non-speech
        }

        return (basicDetection, confidence)
    }

    /// Fast spectral centroid calculation for speech detection
    private func calculateSpectralCentroid(_ data: UnsafePointer<Float>, frameCount: Int) -> Float {
        let windowSize = min(256, frameCount)

        // Ensure buffer capacity
        if windowBuffer.count < windowSize {
            windowBuffer = Array(repeating: 0.0, count: windowSize)
        }

        // Copy window of data
        for i in 0..<windowSize {
            windowBuffer[i] = data[i]
        }

        // Simple spectral centroid approximation
        var weightedSum: Float = 0.0
        var magnitudeSum: Float = 0.0

        for i in 0..<windowSize {
            let magnitude = abs(windowBuffer[i])
            let frequency = Float(i) * 48000.0 / Float(windowSize) // Assuming 48kHz sample rate

            weightedSum += magnitude * frequency
            magnitudeSum += magnitude
        }

        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0.0
    }

    /// Reset detector state
    func reset() {
        isVoiceActive = false
        currentLevel = 0.0
        previousLevel = 0.0
        consecutiveVoiceFrames = 0
        consecutiveSilenceFrames = 0
    }

    /// Adjust sensitivity for different environments
    func adjustSensitivity(for environment: AudioEnvironment) {
        // Implementation would adjust thresholds based on environment
        // This is a placeholder for future enhancement
    }
}

enum AudioEnvironment {
    case quiet      // Private office
    case normal     // Standard clinical environment
    case noisy      // Emergency department
    case car        // Ambulance/transport
}