import Foundation
import AVFoundation
import Speech

// MARK: - Speaker Identification Service
// Identifies and labels different speakers in medical conversations

@MainActor
class SpeakerIdentificationService: ObservableObject {
    // MARK: - Published Properties
    @Published var identifiedSpeakers: [Speaker] = []
    @Published var currentSpeaker: Speaker?
    @Published var speakerConfidence: Float = 0
    @Published var isCalibrating = false
    
    // MARK: - Speaker Model
    struct Speaker: Identifiable, Equatable {
        let id = UUID()
        var role: SpeakerRole
        var voiceProfile: VoiceProfile
        var speakingTime: TimeInterval = 0
        var lastActiveTime: TimeInterval = 0
        
        enum SpeakerRole: String, CaseIterable {
            case doctor = "Doctor"
            case patient = "Patient"
            case nurse = "Nurse"
            case family = "Family"
            case unknown = "Speaker"
            
            var icon: String {
                switch self {
                case .doctor: return "🩺"
                case .patient: return "🤒"
                case .nurse: return "👩‍⚕️"
                case .family: return "👥"
                case .unknown: return "🗣️"
                }
            }
        }
    }
    
    // MARK: - Voice Profile
    struct VoiceProfile: Equatable {
        var fundamentalFrequency: Float = 0  // F0 - pitch
        var formants: [Float] = []  // Vocal tract resonances
        var spectralCentroid: Float = 0  // Brightness of voice
        var mfccFeatures: [Float] = []  // Mel-frequency cepstral coefficients
        var energyPattern: [Float] = []  // Speech energy pattern
        var speakingRate: Float = 0  // Words per minute estimate
        
        // Calculate similarity between profiles
        func similarity(to other: VoiceProfile) -> Float {
            var score: Float = 0
            var components = 0
            
            // Compare fundamental frequency (weight: 30%)
            if fundamentalFrequency > 0 && other.fundamentalFrequency > 0 {
                let pitchDiff = abs(fundamentalFrequency - other.fundamentalFrequency)
                let pitchScore = max(0, 1 - pitchDiff / 100)
                score += pitchScore * 0.3
                components += 1
            }
            
            // Compare spectral centroid (weight: 20%)
            if spectralCentroid > 0 && other.spectralCentroid > 0 {
                let centroidDiff = abs(spectralCentroid - other.spectralCentroid)
                let centroidScore = max(0, 1 - centroidDiff / 1000)
                score += centroidScore * 0.2
                components += 1
            }
            
            // Compare speaking rate (weight: 20%)
            if speakingRate > 0 && other.speakingRate > 0 {
                let rateDiff = abs(speakingRate - other.speakingRate)
                let rateScore = max(0, 1 - rateDiff / 50)
                score += rateScore * 0.2
                components += 1
            }
            
            // Compare MFCC features (weight: 30%)
            if !mfccFeatures.isEmpty && !other.mfccFeatures.isEmpty {
                let mfccScore = cosineSimilarity(mfccFeatures, other.mfccFeatures)
                score += mfccScore * 0.3
                components += 1
            }
            
            return components > 0 ? score : 0
        }
        
        private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
            guard a.count == b.count && !a.isEmpty else { return 0 }
            
            var dotProduct: Float = 0
            var magnitudeA: Float = 0
            var magnitudeB: Float = 0
            
            for i in 0..<a.count {
                dotProduct += a[i] * b[i]
                magnitudeA += a[i] * a[i]
                magnitudeB += b[i] * b[i]
            }
            
            let denominator = sqrt(magnitudeA) * sqrt(magnitudeB)
            return denominator > 0 ? dotProduct / denominator : 0
        }
    }
    
    // MARK: - Configuration
    private let similarityThreshold: Float = 0.7  // Minimum similarity to match speaker
    private let maxSpeakers = 5  // Maximum expected speakers in encounter
    private var calibrationSamples: [String: [VoiceProfile]] = [:]
    
    // MARK: - Audio Analysis
    
    func analyzeAudioBuffer(_ buffer: AVAudioPCMBuffer, at timestamp: TimeInterval) -> Speaker {
        let profile = extractVoiceProfile(from: buffer)
        
        // Try to match with existing speakers
        var bestMatch: Speaker?
        var bestScore: Float = 0
        
        for speaker in identifiedSpeakers {
            let similarity = profile.similarity(to: speaker.voiceProfile)
            if similarity > bestScore && similarity > similarityThreshold {
                bestMatch = speaker
                bestScore = similarity
            }
        }
        
        if let matched = bestMatch {
            // Update speaker's profile with new data (adaptive learning)
            updateSpeakerProfile(matched, with: profile)
            currentSpeaker = matched
            speakerConfidence = bestScore
            return matched
        } else {
            // Create new speaker
            let newSpeaker = createNewSpeaker(with: profile)
            identifiedSpeakers.append(newSpeaker)
            currentSpeaker = newSpeaker
            speakerConfidence = 1.0  // New speaker
            return newSpeaker
        }
    }
    
    // MARK: - Voice Profile Extraction
    
    private func extractVoiceProfile(from buffer: AVAudioPCMBuffer) -> VoiceProfile {
        guard let channelData = buffer.floatChannelData else {
            return VoiceProfile()
        }
        
        let samples = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        let sampleRate = Float(buffer.format.sampleRate)
        
        var profile = VoiceProfile()
        
        // Extract fundamental frequency (F0) using autocorrelation
        profile.fundamentalFrequency = extractPitch(samples: samples, count: frameLength, sampleRate: sampleRate)
        
        // Extract spectral centroid
        profile.spectralCentroid = calculateSpectralCentroid(samples: samples, count: frameLength, sampleRate: sampleRate)
        
        // Extract MFCC features (simplified)
        profile.mfccFeatures = extractMFCC(samples: samples, count: frameLength)
        
        // Estimate speaking rate from energy patterns
        profile.energyPattern = extractEnergyPattern(samples: samples, count: frameLength)
        profile.speakingRate = estimateSpeakingRate(from: profile.energyPattern)
        
        return profile
    }
    
    // MARK: - Feature Extraction Methods
    
    private func extractPitch(samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // Simplified pitch detection using autocorrelation
        let minPeriod = Int(sampleRate / 300)  // 300 Hz max
        let maxPeriod = Int(sampleRate / 50)   // 50 Hz min
        
        var maxCorrelation: Float = 0
        var bestPeriod = 0
        
        for period in minPeriod...min(maxPeriod, count/2) {
            var correlation: Float = 0
            var norm1: Float = 0
            var norm2: Float = 0
            
            for i in 0..<(count - period) {
                correlation += samples[i] * samples[i + period]
                norm1 += samples[i] * samples[i]
                norm2 += samples[i + period] * samples[i + period]
            }
            
            let normalizedCorr = correlation / sqrt(norm1 * norm2)
            if normalizedCorr > maxCorrelation {
                maxCorrelation = normalizedCorr
                bestPeriod = period
            }
        }
        
        return bestPeriod > 0 ? sampleRate / Float(bestPeriod) : 0
    }
    
    private func calculateSpectralCentroid(samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Float) -> Float {
        // Simplified spectral centroid calculation
        var weightedSum: Float = 0
        var magnitudeSum: Float = 0
        
        for i in 0..<count {
            let magnitude = abs(samples[i])
            let frequency = Float(i) * sampleRate / Float(count)
            weightedSum += frequency * magnitude
            magnitudeSum += magnitude
        }
        
        return magnitudeSum > 0 ? weightedSum / magnitudeSum : 0
    }
    
    private func extractMFCC(samples: UnsafeMutablePointer<Float>, count: Int) -> [Float] {
        // Simplified MFCC extraction (would use vDSP in production)
        var mfcc: [Float] = []
        let numCoefficients = 13
        
        for i in 0..<numCoefficients {
            var sum: Float = 0
            for j in stride(from: i, to: count, by: numCoefficients) {
                sum += samples[j]
            }
            mfcc.append(sum / Float(count / numCoefficients))
        }
        
        return mfcc
    }
    
    private func extractEnergyPattern(samples: UnsafeMutablePointer<Float>, count: Int) -> [Float] {
        let windowSize = count / 10
        var pattern: [Float] = []
        
        for i in stride(from: 0, to: count, by: windowSize) {
            var energy: Float = 0
            for j in i..<min(i + windowSize, count) {
                energy += samples[j] * samples[j]
            }
            pattern.append(sqrt(energy / Float(windowSize)))
        }
        
        return pattern
    }
    
    private func estimateSpeakingRate(from energyPattern: [Float]) -> Float {
        // Estimate speaking rate from energy fluctuations
        var transitions = 0
        let threshold: Float = 0.1
        
        for i in 1..<energyPattern.count {
            if (energyPattern[i-1] < threshold && energyPattern[i] > threshold) ||
               (energyPattern[i-1] > threshold && energyPattern[i] < threshold) {
                transitions += 1
            }
        }
        
        // Approximate words per minute (rough estimate)
        return Float(transitions) * 10  // Calibrated estimate
    }
    
    // MARK: - Speaker Management
    
    private func createNewSpeaker(with profile: VoiceProfile) -> Speaker {
        // Assign role based on order and characteristics
        let role: Speaker.SpeakerRole
        
        if identifiedSpeakers.isEmpty {
            // First speaker is usually the healthcare provider
            role = .doctor
        } else if identifiedSpeakers.count == 1 {
            // Second speaker is usually the patient
            role = .patient
        } else {
            // Additional speakers
            role = .unknown
        }
        
        return Speaker(role: role, voiceProfile: profile)
    }
    
    private func updateSpeakerProfile(_ speaker: Speaker, with newProfile: VoiceProfile) {
        guard let index = identifiedSpeakers.firstIndex(where: { $0.id == speaker.id }) else { return }
        
        // Adaptive learning: blend new features with existing
        var updated = identifiedSpeakers[index]
        
        // Weighted average (90% existing, 10% new)
        updated.voiceProfile.fundamentalFrequency = 
            updated.voiceProfile.fundamentalFrequency * 0.9 + newProfile.fundamentalFrequency * 0.1
        
        updated.voiceProfile.spectralCentroid = 
            updated.voiceProfile.spectralCentroid * 0.9 + newProfile.spectralCentroid * 0.1
        
        updated.voiceProfile.speakingRate = 
            updated.voiceProfile.speakingRate * 0.9 + newProfile.speakingRate * 0.1
        
        updated.lastActiveTime = Date().timeIntervalSince1970
        identifiedSpeakers[index] = updated
    }
    
    // MARK: - Manual Speaker Assignment
    
    func assignSpeakerRole(_ speaker: Speaker, to role: Speaker.SpeakerRole) {
        guard let index = identifiedSpeakers.firstIndex(where: { $0.id == speaker.id }) else { return }
        identifiedSpeakers[index].role = role
    }
    
    // MARK: - Calibration Mode
    
    func startCalibration(for role: Speaker.SpeakerRole) {
        isCalibrating = true
        calibrationSamples[role.rawValue] = []
    }
    
    func addCalibrationSample(_ buffer: AVAudioPCMBuffer, for role: Speaker.SpeakerRole) {
        let profile = extractVoiceProfile(from: buffer)
        calibrationSamples[role.rawValue, default: []].append(profile)
    }
    
    func finishCalibration() {
        isCalibrating = false
        
        // Create speakers from calibration samples
        for (roleString, profiles) in calibrationSamples {
            guard let role = Speaker.SpeakerRole(rawValue: roleString),
                  !profiles.isEmpty else { continue }
            
            // Average the profiles
            var avgProfile = VoiceProfile()
            
            avgProfile.fundamentalFrequency = profiles.map { $0.fundamentalFrequency }.reduce(0, +) / Float(profiles.count)
            avgProfile.spectralCentroid = profiles.map { $0.spectralCentroid }.reduce(0, +) / Float(profiles.count)
            avgProfile.speakingRate = profiles.map { $0.speakingRate }.reduce(0, +) / Float(profiles.count)
            
            // Create calibrated speaker
            let speaker = Speaker(role: role, voiceProfile: avgProfile)
            identifiedSpeakers.append(speaker)
        }
        
        calibrationSamples.removeAll()
    }
    
    // MARK: - Statistics
    
    func getSpeakerStatistics() -> SpeakerStatistics {
        let totalSpeakers = identifiedSpeakers.count
        let doctorTime = identifiedSpeakers.first { $0.role == .doctor }?.speakingTime ?? 0
        let patientTime = identifiedSpeakers.first { $0.role == .patient }?.speakingTime ?? 0
        let totalTime = identifiedSpeakers.reduce(0) { $0 + $1.speakingTime }
        
        return SpeakerStatistics(
            totalSpeakers: totalSpeakers,
            doctorSpeakingTime: doctorTime,
            patientSpeakingTime: patientTime,
            totalSpeakingTime: totalTime,
            speakers: identifiedSpeakers
        )
    }
    
    struct SpeakerStatistics {
        let totalSpeakers: Int
        let doctorSpeakingTime: TimeInterval
        let patientSpeakingTime: TimeInterval
        let totalSpeakingTime: TimeInterval
        let speakers: [Speaker]
        
        var doctorPercentage: Float {
            totalSpeakingTime > 0 ? Float(doctorSpeakingTime / totalSpeakingTime) : 0
        }
        
        var patientPercentage: Float {
            totalSpeakingTime > 0 ? Float(patientSpeakingTime / totalSpeakingTime) : 0
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        identifiedSpeakers.removeAll()
        currentSpeaker = nil
        speakerConfidence = 0
        calibrationSamples.removeAll()
        isCalibrating = false
    }
}