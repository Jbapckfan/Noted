import Foundation
import AVFoundation

// MARK: - Pause Detection Service
// Detects natural pauses in conversation for better segmentation

@MainActor
class PauseDetectionService: ObservableObject {
    // MARK: - Published Properties
    @Published var detectedPauses: [PauseMarker] = []
    @Published var isProcessing = false
    @Published var currentSilenceDuration: TimeInterval = 0
    
    // MARK: - Configuration
    struct Configuration {
        var silenceThreshold: Float = 0.01  // Amplitude threshold for silence
        var minimumPauseDuration: TimeInterval = 1.0  // Minimum pause to mark (seconds)
        var significantPauseDuration: TimeInterval = 2.0  // Significant pause threshold
        var contextWindow: Int = 100  // Samples to average for noise reduction
    }
    
    private var config = Configuration()
    private var silenceStartTime: TimeInterval?
    var lastProcessedTime: TimeInterval = 0
    
    // MARK: - Pause Marker Model
    struct PauseMarker: Identifiable {
        let id = UUID()
        let startTime: TimeInterval
        let duration: TimeInterval
        let type: PauseType
        
        enum PauseType {
            case brief  // 1-2 seconds
            case normal  // 2-3 seconds
            case long  // 3+ seconds
            
            var description: String {
                switch self {
                case .brief: return "..."
                case .normal: return "[pause]"
                case .long: return "[long pause]"
                }
            }
            
            func displayDuration(_ duration: TimeInterval) -> String {
                return String(format: "[%.1fs pause]", duration)
            }
        }
        
        static func typeForDuration(_ duration: TimeInterval) -> PauseType {
            if duration >= 3.0 { return .long }
            if duration >= 2.0 { return .normal }
            return .brief
        }
    }
    
    // MARK: - Audio Processing
    
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at timestamp: TimeInterval) {
        guard let channelData = buffer.floatChannelData else { return }
        guard buffer.frameLength > 0 else { return }
        
        let channelDataValue = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        
        // Calculate RMS (Root Mean Square) for better silence detection
        let rms = calculateRMS(samples: channelDataValue, count: frameLength)
        
        // Update current time
        let bufferDuration = TimeInterval(frameLength) / sampleRate
        let currentTime = timestamp + bufferDuration
        
        // Detect silence or speech
        if rms < config.silenceThreshold {
            // Silence detected
            if silenceStartTime == nil {
                silenceStartTime = currentTime
            }
            currentSilenceDuration = currentTime - (silenceStartTime ?? currentTime)
            
        } else {
            // Speech detected
            if let startTime = silenceStartTime {
                let pauseDuration = currentTime - startTime
                
                // Only mark pauses longer than minimum duration
                if pauseDuration >= config.minimumPauseDuration {
                    let pauseType = PauseMarker.typeForDuration(pauseDuration)
                    let marker = PauseMarker(
                        startTime: startTime,
                        duration: pauseDuration,
                        type: pauseType
                    )
                    
                    Task { @MainActor in
                        detectedPauses.append(marker)
                        
                        // Keep only recent pauses (last 100)
                        if detectedPauses.count > 100 {
                            detectedPauses.removeFirst()
                        }
                    }
                }
                
                silenceStartTime = nil
                currentSilenceDuration = 0
            }
        }
        
        lastProcessedTime = currentTime
    }
    
    // MARK: - Helper Functions
    
    private func calculateRMS(samples: UnsafeMutablePointer<Float>, count: Int) -> Float {
        guard count > 0 else { return 0 }
        
        var sum: Float = 0
        var sampleCount = 0
        
        // Use strided access for performance
        let strideValue = max(1, min(count, count / 1000))  // Sample every nth value for large buffers
        
        for i in Swift.stride(from: 0, to: count, by: strideValue) {
            if i < count {  // Bounds check
                let sample = samples[i]
                sum += sample * sample
                sampleCount += 1
            }
        }
        
        guard sampleCount > 0 else { return 0 }
        let mean = sum / Float(sampleCount)
        return sqrt(mean)
    }
    
    // MARK: - Transcript Integration
    
    func insertPausesIntoTranscript(_ transcript: String, segments: [EnhancedTranscriptionSegment]) -> String {
        var result = ""
        var lastEndTime: TimeInterval = 0
        
        for segment in segments {
            // Check for pauses between segments
            let pausesInGap = detectedPauses.filter { pause in
                pause.startTime >= lastEndTime && 
                pause.startTime < segment.startTime
            }
            
            // Add pause markers
            for pause in pausesInGap {
                result += " \(pause.type.description) "
            }
            
            // Add segment text
            result += segment.text
            lastEndTime = segment.endTime
        }
        
        return result
    }
    
    // MARK: - Enhanced Transcript Formatting
    
    func formatTranscriptWithPauses(_ segments: [EnhancedTranscriptionSegment]) -> String {
        var formattedText = ""
        var lastEndTime: TimeInterval = 0
        var currentSpeaker: String?
        
        for segment in segments {
            // Check for speaker change
            if segment.speaker != currentSpeaker {
                if currentSpeaker != nil {
                    formattedText += "\n\n"
                }
                formattedText += "\(segment.speaker): "
                currentSpeaker = segment.speaker
            }
            
            // Insert pauses between segments
            let pausesInGap = detectedPauses.filter { pause in
                pause.startTime >= lastEndTime && 
                pause.startTime < segment.startTime
            }
            
            for pause in pausesInGap {
                if pause.type == .long {
                    formattedText += "\n\(pause.type.displayDuration(pause.duration))\n"
                } else {
                    formattedText += " \(pause.type.description) "
                }
            }
            
            // Add the actual text
            formattedText += segment.text
            lastEndTime = segment.endTime
        }
        
        return formattedText
    }
    
    // MARK: - Configuration
    
    func updateConfiguration(
        silenceThreshold: Float? = nil,
        minimumPauseDuration: TimeInterval? = nil,
        significantPauseDuration: TimeInterval? = nil
    ) {
        if let threshold = silenceThreshold {
            config.silenceThreshold = threshold
        }
        if let minDuration = minimumPauseDuration {
            config.minimumPauseDuration = minDuration
        }
        if let sigDuration = significantPauseDuration {
            config.significantPauseDuration = sigDuration
        }
    }
    
    // MARK: - Analytics
    
    func getPauseStatistics() -> PauseStatistics {
        let totalPauses = detectedPauses.count
        let totalDuration = detectedPauses.reduce(0) { $0 + $1.duration }
        let averageDuration = totalPauses > 0 ? totalDuration / Double(totalPauses) : 0
        
        let briefCount = detectedPauses.filter { $0.type == .brief }.count
        let normalCount = detectedPauses.filter { $0.type == .normal }.count
        let longCount = detectedPauses.filter { $0.type == .long }.count
        
        return PauseStatistics(
            totalPauses: totalPauses,
            totalPauseDuration: totalDuration,
            averagePauseDuration: averageDuration,
            briefPauses: briefCount,
            normalPauses: normalCount,
            longPauses: longCount
        )
    }
    
    struct PauseStatistics {
        let totalPauses: Int
        let totalPauseDuration: TimeInterval
        let averagePauseDuration: TimeInterval
        let briefPauses: Int
        let normalPauses: Int
        let longPauses: Int
        
        var conversationFlowScore: Float {
            // Score based on pause patterns
            // Natural conversation has mix of brief and normal pauses
            let idealBriefRatio: Float = 0.5
            let idealNormalRatio: Float = 0.35
            let idealLongRatio: Float = 0.15
            
            guard totalPauses > 0 else { return 0 }
            
            let briefRatio = Float(briefPauses) / Float(totalPauses)
            let normalRatio = Float(normalPauses) / Float(totalPauses)
            let longRatio = Float(longPauses) / Float(totalPauses)
            
            let briefScore = 1.0 - abs(briefRatio - idealBriefRatio)
            let normalScore = 1.0 - abs(normalRatio - idealNormalRatio)
            let longScore = 1.0 - abs(longRatio - idealLongRatio)
            
            return (briefScore + normalScore + longScore) / 3.0
        }
    }
    
    // MARK: - Reset
    
    func reset() {
        detectedPauses.removeAll()
        silenceStartTime = nil
        currentSilenceDuration = 0
        lastProcessedTime = 0
    }
}

// MARK: - Enhanced Transcription Segment
// Extends transcription with pause awareness

struct EnhancedTranscriptionSegment {
    let speaker: String
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}