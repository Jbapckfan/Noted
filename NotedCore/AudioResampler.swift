import Foundation
import Accelerate

/// Utility class for resampling audio from one sample rate to another
class AudioResampler {
    
    /// Downsample audio from a higher sample rate to 16kHz for WhisperKit
    /// - Parameters:
    ///   - input: Input audio samples
    ///   - fromRate: Source sample rate (e.g., 48000)
    ///   - toRate: Target sample rate (e.g., 16000)
    /// - Returns: Resampled audio
    static func resample(_ input: [Float], fromRate: Double, toRate: Double) -> [Float] {
        guard fromRate > 0, toRate > 0, !input.isEmpty else { return [] }
        
        // If rates are the same, return as-is
        if abs(fromRate - toRate) < 1.0 {
            return input
        }
        
        let ratio = toRate / fromRate
        let outputLength = Int(Double(input.count) * ratio)
        var output = [Float](repeating: 0, count: outputLength)
        
        // Simple linear interpolation resampling
        for i in 0..<outputLength {
            let srcIndex = Double(i) / ratio
            let index = Int(srcIndex)
            let fraction = Float(srcIndex - Double(index))
            
            if index < input.count - 1 {
                // Linear interpolation between samples
                output[i] = input[index] * (1.0 - fraction) + input[index + 1] * fraction
            } else if index < input.count {
                output[i] = input[index]
            }
        }
        
        return output
    }
    
    /// Apply a simple low-pass filter before downsampling to prevent aliasing
    /// - Parameters:
    ///   - input: Input audio samples
    ///   - cutoffFrequency: Cutoff frequency in Hz
    ///   - sampleRate: Sample rate of the input
    /// - Returns: Filtered audio
    static func lowPassFilter(_ input: [Float], cutoffFrequency: Float, sampleRate: Float) -> [Float] {
        guard !input.isEmpty else { return [] }
        
        // Simple moving average filter as a basic low-pass
        let filterLength = Int(sampleRate / cutoffFrequency)
        let windowSize = min(filterLength, 32) // Limit window size for performance
        
        var output = [Float](repeating: 0, count: input.count)
        
        for i in 0..<input.count {
            var sum: Float = 0
            var count = 0
            
            for j in max(0, i - windowSize/2)..<min(input.count, i + windowSize/2 + 1) {
                sum += input[j]
                count += 1
            }
            
            output[i] = sum / Float(count)
        }
        
        return output
    }
    
    /// Intelligent resampling with anti-aliasing filter
    /// - Parameters:
    ///   - input: Input audio samples
    ///   - fromRate: Source sample rate
    ///   - toRate: Target sample rate (should be 16000 for WhisperKit)
    /// - Returns: Properly resampled audio for WhisperKit
    static func resampleForWhisperKit(_ input: [Float], fromRate: Double) -> [Float] {
        let targetRate: Double = 16000 // WhisperKit's expected rate
        
        // If already at target rate, return as-is
        if abs(fromRate - targetRate) < 1.0 {
            return input
        }
        
        // Apply anti-aliasing filter if downsampling
        var filtered = input
        if fromRate > targetRate {
            // Apply low-pass filter at Nyquist frequency of target rate
            filtered = lowPassFilter(input, cutoffFrequency: Float(targetRate / 2), sampleRate: Float(fromRate))
        }
        
        // Resample to target rate
        return resample(filtered, fromRate: fromRate, toRate: targetRate)
    }
}