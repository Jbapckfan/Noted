import Foundation
import AVFoundation
import Accelerate
import CoreML

// Advanced audio processing for maximum transcription accuracy
@MainActor
class EnhancedAudioProcessor: ObservableObject {
    static let shared = EnhancedAudioProcessor()
    
    @Published var isProcessing = false
    @Published var noiseReductionLevel: Float = 0.7
    @Published var voiceEnhancementLevel: Float = 0.8
    
    // MARK: - Audio Enhancement Pipeline
    func enhanceAudioForTranscription(_ audioBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard let processedBuffer = audioBuffer.copy() as? AVAudioPCMBuffer else {
            return audioBuffer
        }
        
        // Apply enhancement pipeline
        applyNoiseGate(to: processedBuffer)
        applySpectralNoiseReduction(to: processedBuffer)
        enhanceVoiceFrequencies(to: processedBuffer)
        normalizeAudioLevels(to: processedBuffer)
        applyDynamicRangeCompression(to: processedBuffer)
        
        return processedBuffer
    }
    
    // MARK: - Noise Gate (Remove background noise during silence)
    private func applyNoiseGate(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let threshold: Float = 0.01 // Adjust based on noise floor
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            
            for frame in 0..<frameLength {
                if abs(data[frame]) < threshold {
                    data[frame] = 0
                }
            }
        }
    }
    
    // MARK: - Spectral Noise Reduction
    private func applySpectralNoiseReduction(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // FFT setup
        let log2n = vDSP_Length(log2(Float(frameLength)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else { return }
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        for channel in 0..<channelCount {
            let data = channelData[channel]
            
            // Convert to frequency domain
            var realp = [Float](repeating: 0, count: frameLength/2)
            var imagp = [Float](repeating: 0, count: frameLength/2)
            
            realp.withUnsafeMutableBufferPointer { realPtr in
                imagp.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(
                        realp: realPtr.baseAddress!,
                        imagp: imagPtr.baseAddress!
                    )
                    
                    data.withMemoryRebound(to: DSPComplex.self, capacity: frameLength/2) { complexData in
                        vDSP_ctoz(complexData, 2, &splitComplex, 1, vDSP_Length(frameLength/2))
                    }
                    
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // Apply spectral subtraction
                    applySpectralSubtraction(&splitComplex, frameCount: frameLength/2)
                    
                    // Convert back to time domain
                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_INVERSE))
                    
                    var scale = Float(1.0 / Float(frameLength))
                    vDSP_vsmul(splitComplex.realp, 1, &scale, splitComplex.realp, 1, vDSP_Length(frameLength/2))
                    vDSP_vsmul(splitComplex.imagp, 1, &scale, splitComplex.imagp, 1, vDSP_Length(frameLength/2))
                    
                    // Copy back
                    data.withMemoryRebound(to: DSPComplex.self, capacity: frameLength/2) { complexData in
                        vDSP_ztoc(&splitComplex, 1, complexData, 2, vDSP_Length(frameLength/2))
                    }
                }
            }
        }
    }
    
    private func applySpectralSubtraction(_ splitComplex: inout DSPSplitComplex, frameCount: Int) {
        // Estimate noise spectrum (simplified - in practice, use noise profile)
        var magnitudes = [Float](repeating: 0, count: frameCount)
        withUnsafePointer(to: &splitComplex) { ptr in
            vDSP_zvmags(ptr, 1, &magnitudes, 1, vDSP_Length(frameCount))
        }
        
        // Find noise floor (bottom 10% of magnitudes)
        let sorted = magnitudes.sorted()
        let noiseFloor = sorted[frameCount / 10]
        
        // Subtract noise floor with over-subtraction factor
        let alpha: Float = noiseReductionLevel * 2.0
        for i in 0..<frameCount {
            let magnitude = sqrt(magnitudes[i])
            let phase = atan2(splitComplex.imagp[i], splitComplex.realp[i])
            
            var newMagnitude = magnitude - (alpha * noiseFloor)
            if newMagnitude < 0 {
                newMagnitude = magnitude * 0.1 // Minimal residual
            }
            
            splitComplex.realp[i] = newMagnitude * cos(phase)
            splitComplex.imagp[i] = newMagnitude * sin(phase)
        }
    }
    
    // MARK: - Voice Frequency Enhancement
    private func enhanceVoiceFrequencies(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        // Voice frequency ranges (Hz) - not directly used but documented for reference
        // fundamentalRange: 85...255 Hz - Fundamental frequency
        // formant1Range: 700...1220 Hz - First formant  
        // formant2Range: 1800...2600 Hz - Second formant
        // clarityRange: 2000...4000 Hz - Clarity/intelligibility
        
        // Apply bandpass filters for voice enhancement
        for channel in 0..<Int(buffer.format.channelCount) {
            let data = channelData[channel]
            
            // Apply EQ boost to voice frequencies
            applyParametricEQ(
                data: data,
                frameCount: frameLength,
                sampleRate: sampleRate,
                centerFreq: 150,  // Fundamental
                q: 0.7,
                gain: 3.0 * voiceEnhancementLevel
            )
            
            applyParametricEQ(
                data: data,
                frameCount: frameLength,
                sampleRate: sampleRate,
                centerFreq: 1000, // First formant
                q: 0.5,
                gain: 2.5 * voiceEnhancementLevel
            )
            
            applyParametricEQ(
                data: data,
                frameCount: frameLength,
                sampleRate: sampleRate,
                centerFreq: 3000, // Clarity
                q: 0.7,
                gain: 4.0 * voiceEnhancementLevel
            )
        }
    }
    
    private func applyParametricEQ(
        data: UnsafeMutablePointer<Float>,
        frameCount: Int,
        sampleRate: Float,
        centerFreq: Float,
        q: Float,
        gain: Float
    ) {
        // Simplified parametric EQ using biquad filter
        let omega = 2.0 * Float.pi * centerFreq / sampleRate
        let alpha = sin(omega) / (2.0 * q)
        let A = pow(10.0, gain / 40.0)
        
        // Peaking EQ coefficients
        let b0 = 1.0 + alpha * A
        let b1 = -2.0 * cos(omega)
        let b2 = 1.0 - alpha * A
        let a0 = 1.0 + alpha / A
        let a1 = -2.0 * cos(omega)
        let a2 = 1.0 - alpha / A
        
        // Normalize coefficients
        let norm = 1.0 / a0
        
        // Apply filter
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0
        
        for i in 0..<frameCount {
            let input = data[i]
            let output = (b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) * norm
            
            x2 = x1
            x1 = input
            y2 = y1
            y1 = output
            
            data[i] = output
        }
    }
    
    // MARK: - Dynamic Range Compression
    private func applyDynamicRangeCompression(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let threshold: Float = 0.5
        let ratio: Float = 4.0  // 4:1 compression
        let attack: Float = 0.003  // 3ms
        let release: Float = 0.1   // 100ms
        
        for channel in 0..<Int(buffer.format.channelCount) {
            let data = channelData[channel]
            var envelope: Float = 0
            
            for i in 0..<frameLength {
                let input = abs(data[i])
                
                // Envelope follower
                let rate = input > envelope ? attack : release
                envelope = envelope + rate * (input - envelope)
                
                // Apply compression
                if envelope > threshold {
                    let excess = envelope - threshold
                    let compressedExcess = excess / ratio
                    let gain = (threshold + compressedExcess) / envelope
                    data[i] *= gain
                }
            }
        }
    }
    
    // MARK: - Audio Level Normalization
    private func normalizeAudioLevels(to buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = vDSP_Length(buffer.frameLength)
        let targetLevel: Float = 0.8
        
        for channel in 0..<Int(buffer.format.channelCount) {
            let data = channelData[channel]
            
            // Find peak
            var peak: Float = 0
            vDSP_maxmgv(data, 1, &peak, frameLength)
            
            // Apply normalization
            if peak > 0 {
                var scale = targetLevel / peak
                vDSP_vsmul(data, 1, &scale, data, 1, frameLength)
            }
        }
    }
    
    // MARK: - Voice Activity Detection (VAD)
    func detectVoiceActivity(in buffer: AVAudioPCMBuffer) -> [VoiceSegment] {
        guard let channelData = buffer.floatChannelData else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        let windowSize = Int(sampleRate * 0.03) // 30ms windows
        var segments: [VoiceSegment] = []
        
        let data = channelData[0] // Use first channel
        var isVoice = false
        var segmentStart: Int = 0
        
        for i in stride(from: 0, to: frameLength, by: windowSize) {
            let endIndex = min(i + windowSize, frameLength)
            let window = Array(UnsafeBufferPointer(start: data + i, count: endIndex - i))
            
            let features = extractVoiceFeatures(window, sampleRate: sampleRate)
            let voiceDetected = classifyVoice(features)
            
            if voiceDetected && !isVoice {
                // Voice started
                segmentStart = i
                isVoice = true
            } else if !voiceDetected && isVoice {
                // Voice ended
                let startTime = Float(segmentStart) / sampleRate
                let endTime = Float(i) / sampleRate
                segments.append(VoiceSegment(
                    startTime: startTime,
                    endTime: endTime,
                    confidence: features.confidence
                ))
                isVoice = false
            }
        }
        
        // Handle ongoing voice at end
        if isVoice {
            let startTime = Float(segmentStart) / sampleRate
            let endTime = Float(frameLength) / sampleRate
            segments.append(VoiceSegment(
                startTime: startTime,
                endTime: endTime,
                confidence: 0.8
            ))
        }
        
        return segments
    }
    
    private func extractVoiceFeatures(_ window: [Float], sampleRate: Float) -> VoiceFeatures {
        // Energy
        var energy: Float = 0
        vDSP_sve(window, 1, &energy, vDSP_Length(window.count))
        energy = energy / Float(window.count)
        
        // Zero crossing rate
        var zcr: Float = 0
        for i in 1..<window.count {
            if window[i] * window[i-1] < 0 {
                zcr += 1
            }
        }
        zcr = zcr / Float(window.count)
        
        // Spectral centroid (simplified)
        let spectralCentroid = calculateSpectralCentroid(window, sampleRate: sampleRate)
        
        // Confidence based on typical voice characteristics
        var confidence: Float = 0
        if energy > 0.001 { confidence += 0.3 }
        if zcr > 0.02 && zcr < 0.15 { confidence += 0.3 }
        if spectralCentroid > 200 && spectralCentroid < 3500 { confidence += 0.4 }
        
        return VoiceFeatures(
            energy: energy,
            zeroCrossingRate: zcr,
            spectralCentroid: spectralCentroid,
            confidence: min(confidence, 1.0)
        )
    }
    
    private func calculateSpectralCentroid(_ window: [Float], sampleRate: Float) -> Float {
        // Simplified spectral centroid calculation
        let fftSize = window.count
        let freqBin = sampleRate / Float(fftSize)
        
        var sum: Float = 0
        var weightedSum: Float = 0
        
        for (i, sample) in window.enumerated() {
            let magnitude = abs(sample)
            let frequency = Float(i) * freqBin
            weightedSum += frequency * magnitude
            sum += magnitude
        }
        
        return sum > 0 ? weightedSum / sum : 0
    }
    
    private func classifyVoice(_ features: VoiceFeatures) -> Bool {
        // Simple rule-based classifier
        // In production, use trained ML model
        return features.confidence > 0.6
    }
}

// MARK: - Supporting Types
struct VoiceSegment {
    let startTime: Float
    let endTime: Float
    let confidence: Float
    
    var duration: Float {
        return endTime - startTime
    }
}

struct VoiceFeatures {
    let energy: Float
    let zeroCrossingRate: Float
    let spectralCentroid: Float
    let confidence: Float
}

// MARK: - Audio Configuration
struct AudioEnhancementConfig {
    var noiseReduction: Bool = true
    var noiseReductionLevel: Float = 0.7
    var voiceEnhancement: Bool = true
    var voiceEnhancementLevel: Float = 0.8
    var dynamicRangeCompression: Bool = true
    var normalization: Bool = true
    var voiceActivityDetection: Bool = true
    
    static let medicalOptimized = AudioEnhancementConfig(
        noiseReduction: true,
        noiseReductionLevel: 0.8,      // High noise reduction for clinical settings
        voiceEnhancement: true,
        voiceEnhancementLevel: 0.9,    // Maximum voice clarity
        dynamicRangeCompression: true,
        normalization: true,
        voiceActivityDetection: true
    )
}