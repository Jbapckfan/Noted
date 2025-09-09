import Foundation
import Accelerate
import AVFoundation

/// Enhanced audio processing for medical transcription quality
final class AudioEnhancementService {
    
    // MARK: - Optimized Configuration
    struct OptimizedAudioConfig {
        static let sampleRate: Double = 48000      // Higher quality for medical terminology
        static let bufferSize: AVAudioFrameCount = 4096  // Larger buffer for better processing
        static let channelCount: UInt32 = 1
        
        // Whisper optimal settings
        static let whisperTargetSampleRate: Double = 16000  // Whisper's expected rate
        static let windowSize: TimeInterval = 10.0   // 10 second windows for context
        static let overlapSize: TimeInterval = 2.0   // 2 second overlap to not miss words
    }
    
    // MARK: - Audio Enhancement Components
    
    /// Pre-emphasis filter to enhance speech frequencies
    class PreEmphasisFilter {
        private let coefficient: Float
        private var previousSample: Float = 0
        
        init(coefficient: Float = 0.97) {
            self.coefficient = coefficient
        }
        
        func process(_ samples: [Float]) -> [Float] {
            var filtered = [Float](repeating: 0, count: samples.count)
            
            // First sample
            filtered[0] = samples[0] - coefficient * previousSample
            
            // Remaining samples
            for i in 1..<samples.count {
                filtered[i] = samples[i] - coefficient * samples[i-1]
            }
            
            previousSample = samples.last ?? 0
            return filtered
        }
    }
    
    /// Adaptive noise gate that learns ambient noise level
    class AdaptiveNoiseGate {
        private var noiseFloor: Float = 0.0
        private var signalPower: Float = 0.0
        private let adaptationRate: Float = 0.001
        private let gateThreshold: Float = 2.5  // Signal must be 2.5x noise floor
        private var gateOpen = false
        private let hysteresis: Float = 0.8  // Prevent rapid switching
        
        func process(_ samples: [Float]) -> [Float] {
            var processed = [Float](repeating: 0, count: samples.count)
            
            for i in 0..<samples.count {
                let samplePower = abs(samples[i])
                
                // Update noise floor estimate during quiet periods
                if samplePower < noiseFloor * 1.5 {
                    noiseFloor = (1 - adaptationRate) * noiseFloor + adaptationRate * samplePower
                }
                
                // Update signal power estimate
                signalPower = (1 - adaptationRate * 10) * signalPower + adaptationRate * 10 * samplePower
                
                // Gate logic with hysteresis
                if !gateOpen && signalPower > noiseFloor * gateThreshold {
                    gateOpen = true
                } else if gateOpen && signalPower < noiseFloor * gateThreshold * hysteresis {
                    gateOpen = false
                }
                
                processed[i] = gateOpen ? samples[i] : samples[i] * 0.1  // Soft gating
            }
            
            return processed
        }
    }
    
    /// Voice Activity Detection using energy and zero-crossing rate
    class VoiceActivityDetector {
        private let energyThreshold: Float = 0.01
        private let zcRateLow: Float = 10
        private let zcRateHigh: Float = 100
        private var speechBuffer: [Bool] = []
        private let smoothingWindow = 5
        
        func detectSpeech(_ samples: [Float]) -> Bool {
            // Calculate energy
            let energy = calculateEnergy(samples)
            
            // Calculate zero-crossing rate
            let zcRate = calculateZeroCrossingRate(samples)
            
            // Speech detection logic
            let isSpeech = energy > energyThreshold && 
                          zcRate > zcRateLow && 
                          zcRate < zcRateHigh
            
            // Smooth the decision
            speechBuffer.append(isSpeech)
            if speechBuffer.count > smoothingWindow {
                speechBuffer.removeFirst()
            }
            
            // Return true if majority of recent frames are speech
            let speechCount = speechBuffer.filter { $0 }.count
            return speechCount > smoothingWindow / 2
        }
        
        private func calculateEnergy(_ samples: [Float]) -> Float {
            var energy: Float = 0
            vDSP_measqv(samples, 1, &energy, vDSP_Length(samples.count))
            return energy / Float(samples.count)
        }
        
        private func calculateZeroCrossingRate(_ samples: [Float]) -> Float {
            var crossings = 0
            for i in 1..<samples.count {
                if (samples[i] >= 0) != (samples[i-1] >= 0) {
                    crossings += 1
                }
            }
            return Float(crossings) / Float(samples.count) * Float(OptimizedAudioConfig.sampleRate)
        }
    }
    
    /// Spectral subtraction for background noise reduction
    class SpectralNoiseReducer {
        private let fftSize = 512
        private var noiseProfile: [Float]?
        private let fftSetup: FFTSetup
        private let subtrationFactor: Float = 2.0
        
        init() {
            self.fftSetup = vDSP_create_fftsetup(vDSP_Length(log2(Float(fftSize))), FFTRadix(kFFTRadix2))!
        }
        
        deinit {
            vDSP_destroy_fftsetup(fftSetup)
        }
        
        func updateNoiseProfile(_ samples: [Float]) {
            // Perform FFT to get frequency spectrum
            let spectrum = performFFT(samples)
            
            // Update noise profile (average spectrum during non-speech)
            if noiseProfile == nil {
                noiseProfile = spectrum
            } else {
                for i in 0..<spectrum.count {
                    noiseProfile![i] = noiseProfile![i] * 0.9 + spectrum[i] * 0.1
                }
            }
        }
        
        func process(_ samples: [Float]) -> [Float] {
            guard let noise = noiseProfile else { return samples }
            
            // FFT to frequency domain
            let spectrum = performFFT(samples)
            
            // Spectral subtraction
            var cleanSpectrum = [Float](repeating: 0, count: spectrum.count)
            for i in 0..<spectrum.count {
                let subtracted = spectrum[i] - subtrationFactor * noise[i]
                cleanSpectrum[i] = max(subtracted, spectrum[i] * 0.1)  // Floor at 10% to avoid musical noise
            }
            
            // IFFT back to time domain
            return performIFFT(cleanSpectrum)
        }
        
        private func performFFT(_ samples: [Float]) -> [Float] {
            // Simplified FFT - actual implementation would use vDSP
            return samples  // Placeholder
        }
        
        private func performIFFT(_ spectrum: [Float]) -> [Float] {
            // Simplified IFFT - actual implementation would use vDSP
            return spectrum  // Placeholder
        }
    }
    
    /// Medical terminology enhancement using frequency boosting
    class MedicalSpeechEnhancer {
        // Medical speech typically has important information in 1-4kHz range
        private let importantFreqRange: ClosedRange<Float> = 1000...4000
        private let boostFactor: Float = 1.5
        
        func enhance(_ samples: [Float], sampleRate: Float) -> [Float] {
            // Apply bandpass filter to boost important frequencies
            return applyBandpassFilter(samples, 
                                      lowFreq: importantFreqRange.lowerBound,
                                      highFreq: importantFreqRange.upperBound,
                                      sampleRate: sampleRate,
                                      boost: boostFactor)
        }
        
        private func applyBandpassFilter(_ samples: [Float], 
                                        lowFreq: Float, 
                                        highFreq: Float, 
                                        sampleRate: Float,
                                        boost: Float) -> [Float] {
            // Simplified bandpass - actual implementation would use vDSP
            return samples.map { $0 * boost }  // Placeholder
        }
    }
    
    // MARK: - Main Processing Pipeline
    
    private let preEmphasis = PreEmphasisFilter()
    private let noiseGate = AdaptiveNoiseGate()
    private let vad = VoiceActivityDetector()
    private let noiseReducer = SpectralNoiseReducer()
    private let speechEnhancer = MedicalSpeechEnhancer()
    
    /// Process audio for optimal medical transcription
    func processForTranscription(_ audioBuffer: [Float], sampleRate: Float = Float(OptimizedAudioConfig.sampleRate)) -> [Float] {
        
        // 1. Pre-emphasis to enhance high frequencies
        let emphasized = preEmphasis.process(audioBuffer)
        
        // 2. Adaptive noise gating
        let gated = noiseGate.process(emphasized)
        
        // 3. Voice activity detection
        guard vad.detectSpeech(gated) else {
            // Update noise profile during non-speech
            noiseReducer.updateNoiseProfile(gated)
            return []  // Don't process non-speech segments
        }
        
        // 4. Spectral noise reduction
        let denoised = noiseReducer.process(gated)
        
        // 5. Medical speech enhancement
        let enhanced = speechEnhancer.enhance(denoised, sampleRate: sampleRate)
        
        // 6. Normalize for Whisper (avoid clipping)
        let normalized = normalizeAudio(enhanced)
        
        // 7. Resample to Whisper's expected rate if needed
        if abs(sampleRate - Float(OptimizedAudioConfig.whisperTargetSampleRate)) > 1 {
            return resample(normalized, 
                          fromRate: sampleRate, 
                          toRate: Float(OptimizedAudioConfig.whisperTargetSampleRate))
        }
        
        return normalized
    }
    
    /// Normalize audio to optimal range for Whisper
    private func normalizeAudio(_ samples: [Float]) -> [Float] {
        // Find peak
        var peak: Float = 0
        vDSP_maxmgv(samples, 1, &peak, vDSP_Length(samples.count))
        
        guard peak > 0 else { return samples }
        
        // Target peak at 0.95 to avoid clipping
        let targetPeak: Float = 0.95
        let scale = targetPeak / peak
        
        var normalized = [Float](repeating: 0, count: samples.count)
        vDSP_vsmul(samples, 1, [scale], &normalized, 1, vDSP_Length(samples.count))
        
        return normalized
    }
    
    /// High-quality resampling using linear interpolation
    private func resample(_ samples: [Float], fromRate: Float, toRate: Float) -> [Float] {
        let ratio = toRate / fromRate
        let newLength = Int(Float(samples.count) * ratio)
        var resampled = [Float](repeating: 0, count: newLength)
        
        for i in 0..<newLength {
            let sourceIndex = Float(i) / ratio
            let index = Int(sourceIndex)
            let fraction = sourceIndex - Float(index)
            
            if index < samples.count - 1 {
                // Linear interpolation
                resampled[i] = samples[index] * (1 - fraction) + samples[index + 1] * fraction
            } else if index < samples.count {
                resampled[i] = samples[index]
            }
        }
        
        return resampled
    }
    
    // MARK: - Quality Metrics
    
    struct AudioQualityMetrics {
        let signalToNoiseRatio: Float
        let speechPresence: Float
        let clippingRatio: Float
        let averageLevel: Float
        
        var qualityScore: Float {
            // Weighted quality score
            let snrScore = min(signalToNoiseRatio / 40, 1.0) * 0.3
            let speechScore = speechPresence * 0.3
            let clippingScore = (1 - clippingRatio) * 0.2
            let levelScore = (averageLevel > 0.1 && averageLevel < 0.8) ? 0.2 : 0.0
            
            return snrScore + speechScore + clippingScore + Float(levelScore)
        }
        
        var qualityDescription: String {
            switch qualityScore {
            case 0.8...1.0: return "Excellent"
            case 0.6..<0.8: return "Good"
            case 0.4..<0.6: return "Fair"
            case 0.2..<0.4: return "Poor"
            default: return "Very Poor"
            }
        }
    }
    
    func analyzeQuality(_ samples: [Float]) -> AudioQualityMetrics {
        // Calculate SNR
        let signal = samples.filter { abs($0) > 0.01 }
        let noise = samples.filter { abs($0) <= 0.01 }
        
        var signalPower: Float = 0
        var noisePower: Float = 0
        
        if !signal.isEmpty {
            vDSP_measqv(signal, 1, &signalPower, vDSP_Length(signal.count))
            signalPower /= Float(signal.count)
        }
        
        if !noise.isEmpty {
            vDSP_measqv(noise, 1, &noisePower, vDSP_Length(noise.count))
            noisePower /= Float(noise.count)
        }
        
        let snr = noisePower > 0 ? 10 * log10(signalPower / noisePower) : 40
        
        // Calculate speech presence
        let speechPresence = Float(signal.count) / Float(samples.count)
        
        // Calculate clipping
        let clipped = samples.filter { abs($0) > 0.99 }
        let clippingRatio = Float(clipped.count) / Float(samples.count)
        
        // Calculate average level
        var avgLevel: Float = 0
        vDSP_meamgv(samples, 1, &avgLevel, vDSP_Length(samples.count))
        
        return AudioQualityMetrics(
            signalToNoiseRatio: snr,
            speechPresence: speechPresence,
            clippingRatio: clippingRatio,
            averageLevel: avgLevel
        )
    }
}

// MARK: - Audio Configuration Extension
extension AVAudioFormat {
    static var optimizedMedicalFormat: AVAudioFormat {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: AudioEnhancementService.OptimizedAudioConfig.sampleRate,
            channels: AudioEnhancementService.OptimizedAudioConfig.channelCount,
            interleaved: false
        )!
    }
}
