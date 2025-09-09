import Foundation
import Speech
import Combine

// Real-time transcription correction with confidence scoring
@MainActor
class RealTimeTranscriptionCorrector: ObservableObject {
    static let shared = RealTimeTranscriptionCorrector()
    
    @Published var correctedTranscript = ""
    @Published var corrections: [Correction] = []
    @Published var overallConfidence: Float = 0.0
    @Published var speakerSegments: [SpeakerSegment] = []
    
    private let vocabularyEnhancer = MedicalVocabularyEnhancer.shared
    private let patternRecognizer = EDPatternRecognitionService.shared
    private var transcriptionBuffer = TranscriptionBuffer()
    
    // MARK: - Real-Time Processing Pipeline
    func processTranscriptionResult(_ result: SFSpeechRecognitionResult) {
        // Get the best transcription
        let bestTranscription = result.bestTranscription
        
        // Process segments for confidence and alternatives
        var enhancedSegments: [EnhancedSegment] = []
        
        for segment in bestTranscription.segments {
            let enhanced = processSegment(segment, alternativeSegments: getAlternatives(for: segment, in: result))
            enhancedSegments.append(enhanced)
        }
        
        // Build corrected transcript
        let corrected = buildCorrectedTranscript(from: enhancedSegments)
        
        // Apply medical corrections
        let (medicalCorrected, medicalCorrections) = vocabularyEnhancer.correctTranscription(corrected)
        
        // Update state
        correctedTranscript = medicalCorrected
        corrections = medicalCorrections
        overallConfidence = calculateOverallConfidence(enhancedSegments)
        
        // Identify speakers
        speakerSegments = identifySpeakers(from: enhancedSegments)
    }
    
    // MARK: - Segment Processing
    private func processSegment(
        _ segment: SFTranscriptionSegment,
        alternativeSegments: [SFTranscriptionSegment]
    ) -> EnhancedSegment {
        
        var bestSubstring = segment.substring
        var confidence = segment.confidence
        var corrections: [SegmentCorrection] = []
        
        // Check if this might be a medical term
        if isMedicalContext(segment) {
            // Look for better alternatives
            for alt in alternativeSegments {
                if let medicalMatch = matchMedicalTerm(alt.substring) {
                    if medicalMatch.confidence > confidence {
                        corrections.append(SegmentCorrection(
                            original: bestSubstring,
                            corrected: medicalMatch.term,
                            confidence: medicalMatch.confidence
                        ))
                        bestSubstring = medicalMatch.term
                        confidence = medicalMatch.confidence
                    }
                }
            }
        }
        
        // Apply contextual corrections
        if let contextCorrection = applyContextCorrection(segment, buffer: transcriptionBuffer) {
            corrections.append(contextCorrection)
            bestSubstring = contextCorrection.corrected
            confidence = max(confidence, contextCorrection.confidence)
        }
        
        return EnhancedSegment(
            substring: bestSubstring,
            timestamp: segment.timestamp,
            duration: segment.duration,
            confidence: confidence,
            corrections: corrections,
            alternatives: alternativeSegments.map { $0.substring }
        )
    }
    
    private func getAlternatives(
        for segment: SFTranscriptionSegment,
        in result: SFSpeechRecognitionResult
    ) -> [SFTranscriptionSegment] {
        var alternatives: [SFTranscriptionSegment] = []
        
        // Get alternatives from other transcriptions
        for transcription in result.transcriptions where transcription != result.bestTranscription {
            for altSegment in transcription.segments {
                // Match by timestamp
                if abs(altSegment.timestamp - segment.timestamp) < 0.1 {
                    alternatives.append(altSegment)
                }
            }
        }
        
        return alternatives
    }
    
    // MARK: - Medical Context Detection
    private func isMedicalContext(_ segment: SFTranscriptionSegment) -> Bool {
        let context = transcriptionBuffer.getContext(for: segment.timestamp)
        
        // Check for medical indicators
        let medicalIndicators = [
            "patient", "doctor", "physician", "nurse",
            "pain", "symptom", "medication", "diagnosis",
            "exam", "history", "presents", "complains"
        ]
        
        let lowerContext = context.lowercased()
        return medicalIndicators.contains { lowerContext.contains($0) }
    }
    
    private func matchMedicalTerm(_ text: String) -> (term: String, confidence: Float)? {
        let normalized = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Direct match
        if MedicalVocabularyEnhancer.shared.medicalTerms.contains(normalized) {
            return (normalized, 0.95)
        }
        
        // Fuzzy match
        for term in MedicalVocabularyEnhancer.shared.medicalTerms {
            let similarity = calculateSimilarity(normalized, term)
            if similarity > 0.85 {
                return (term, Float(similarity))
            }
        }
        
        return nil
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        // Use Jaro-Winkler for better phonetic matching
        return jaroWinklerSimilarity(str1, str2)
    }
    
    private func jaroWinklerSimilarity(_ str1: String, _ str2: String) -> Double {
        let jaro = jaroSimilarity(str1, str2)
        
        // Calculate common prefix (up to 4 chars)
        var prefixLen = 0
        for i in 0..<min(4, min(str1.count, str2.count)) {
            if str1[str1.index(str1.startIndex, offsetBy: i)] == 
               str2[str2.index(str2.startIndex, offsetBy: i)] {
                prefixLen += 1
            } else {
                break
            }
        }
        
        return jaro + (Double(prefixLen) * 0.1 * (1.0 - jaro))
    }
    
    private func jaroSimilarity(_ str1: String, _ str2: String) -> Double {
        guard !str1.isEmpty && !str2.isEmpty else { return 0.0 }
        
        let matchDistance = max(str1.count, str2.count) / 2 - 1
        var str1Matches = [Bool](repeating: false, count: str1.count)
        var str2Matches = [Bool](repeating: false, count: str2.count)
        
        var matches = 0
        var transpositions = 0
        
        // Find matches
        for i in 0..<str1.count {
            let start = max(0, i - matchDistance)
            let end = min(i + matchDistance + 1, str2.count)
            
            for j in start..<end {
                if str2Matches[j] || 
                   str1[str1.index(str1.startIndex, offsetBy: i)] != 
                   str2[str2.index(str2.startIndex, offsetBy: j)] {
                    continue
                }
                str1Matches[i] = true
                str2Matches[j] = true
                matches += 1
                break
            }
        }
        
        guard matches > 0 else { return 0.0 }
        
        // Count transpositions
        var k = 0
        for i in 0..<str1.count {
            if !str1Matches[i] { continue }
            while !str2Matches[k] { k += 1 }
            if str1[str1.index(str1.startIndex, offsetBy: i)] != 
               str2[str2.index(str2.startIndex, offsetBy: k)] {
                transpositions += 1
            }
            k += 1
        }
        
        return (Double(matches) / Double(str1.count) +
                Double(matches) / Double(str2.count) +
                Double(matches - transpositions/2) / Double(matches)) / 3.0
    }
    
    // MARK: - Context-Based Correction
    private func applyContextCorrection(
        _ segment: SFTranscriptionSegment,
        buffer: TranscriptionBuffer
    ) -> SegmentCorrection? {
        
        let context = buffer.getContext(for: segment.timestamp)
        let word = segment.substring.lowercased()
        
        // Number corrections in medical context
        if context.contains("pain") || context.contains("scale") {
            if word == "to" || word == "too" || word == "two" {
                return SegmentCorrection(
                    original: segment.substring,
                    corrected: "2",
                    confidence: 0.85
                )
            }
            if word == "for" || word == "four" {
                return SegmentCorrection(
                    original: segment.substring,
                    corrected: "4",
                    confidence: 0.85
                )
            }
            if word == "ate" || word == "eight" {
                return SegmentCorrection(
                    original: segment.substring,
                    corrected: "8",
                    confidence: 0.85
                )
            }
            if word == "tin" || word == "ten" {
                return SegmentCorrection(
                    original: segment.substring,
                    corrected: "10",
                    confidence: 0.90
                )
            }
        }
        
        // Dosage corrections
        if context.contains("milligram") || context.contains("mg") {
            if word == "to" { return SegmentCorrection(original: word, corrected: "2", confidence: 0.8) }
            if word == "for" { return SegmentCorrection(original: word, corrected: "4", confidence: 0.8) }
            if word == "tin" { return SegmentCorrection(original: word, corrected: "10", confidence: 0.8) }
        }
        
        return nil
    }
    
    // MARK: - Transcript Building
    private func buildCorrectedTranscript(from segments: [EnhancedSegment]) -> String {
        var transcript = ""
        var lastTimestamp: TimeInterval = 0
        
        for segment in segments {
            // Add spacing based on pause duration
            if segment.timestamp - lastTimestamp > 1.0 {
                transcript += "\n" // New sentence after pause
            } else if segment.timestamp - lastTimestamp > 0.3 {
                transcript += ". " // End sentence on moderate pause
            } else if !transcript.isEmpty {
                transcript += " "
            }
            
            transcript += segment.substring
            lastTimestamp = segment.timestamp + segment.duration
        }
        
        // Clean up spacing and punctuation
        transcript = cleanupTranscript(transcript)
        
        return transcript
    }
    
    private func cleanupTranscript(_ text: String) -> String {
        var cleaned = text
        
        // Fix spacing around punctuation
        cleaned = cleaned.replacingOccurrences(of: " .", with: ".")
        cleaned = cleaned.replacingOccurrences(of: " ,", with: ",")
        cleaned = cleaned.replacingOccurrences(of: " ?", with: "?")
        
        // Capitalize sentences
        cleaned = capitalizeSentences(cleaned)
        
        // Fix multiple spaces
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func capitalizeSentences(_ text: String) -> String {
        let sentences = text.components(separatedBy: ". ")
        return sentences.map { sentence in
            guard !sentence.isEmpty else { return sentence }
            return sentence.prefix(1).uppercased() + sentence.dropFirst()
        }.joined(separator: ". ")
    }
    
    // MARK: - Speaker Diarization
    private func identifySpeakers(from segments: [EnhancedSegment]) -> [SpeakerSegment] {
        var speakerSegments: [SpeakerSegment] = []
        var currentSpeaker: Speaker = .unknown
        var segmentStart: TimeInterval = 0
        var segmentText = ""
        
        for segment in segments {
            let speaker = identifySpeaker(for: segment)
            
            if speaker != currentSpeaker && !segmentText.isEmpty {
                // Speaker changed, save current segment
                speakerSegments.append(SpeakerSegment(
                    speaker: currentSpeaker,
                    text: segmentText,
                    startTime: segmentStart,
                    endTime: segment.timestamp
                ))
                
                // Start new segment
                currentSpeaker = speaker
                segmentStart = segment.timestamp
                segmentText = segment.substring
            } else {
                // Continue current segment
                segmentText += " " + segment.substring
            }
        }
        
        // Add final segment
        if !segmentText.isEmpty {
            speakerSegments.append(SpeakerSegment(
                speaker: currentSpeaker,
                text: segmentText,
                startTime: segmentStart,
                endTime: segments.last?.timestamp ?? segmentStart
            ))
        }
        
        return speakerSegments
    }
    
    private func identifySpeaker(for segment: EnhancedSegment) -> Speaker {
        let text = segment.substring.lowercased()
        let context = transcriptionBuffer.getContext(for: segment.timestamp).lowercased()
        
        // Pattern-based identification
        if text.contains("i'm dr") || text.contains("i'm doctor") ||
           context.contains("physician:") {
            return .physician
        }
        
        if text.contains("my pain") || text.contains("i have") ||
           text.contains("i feel") || context.contains("patient:") {
            return .patient
        }
        
        // Could add acoustic features here for better accuracy
        
        return .unknown
    }
    
    private func calculateOverallConfidence(_ segments: [EnhancedSegment]) -> Float {
        guard !segments.isEmpty else { return 0 }
        
        let totalConfidence = segments.reduce(Float(0)) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }
}

// MARK: - Supporting Types
struct EnhancedSegment {
    let substring: String
    let timestamp: TimeInterval
    let duration: TimeInterval
    let confidence: Float
    let corrections: [SegmentCorrection]
    let alternatives: [String]
}

struct SegmentCorrection {
    let original: String
    let corrected: String
    let confidence: Float
}

class TranscriptionBuffer {
    private var segments: [(text: String, timestamp: TimeInterval)] = []
    private let maxSize = 100
    
    func append(_ text: String, at timestamp: TimeInterval) {
        segments.append((text, timestamp))
        
        if segments.count > maxSize {
            segments.removeFirst()
        }
    }
    
    func getContext(for timestamp: TimeInterval, windowSeconds: TimeInterval = 5.0) -> String {
        let relevantSegments = segments.filter {
            abs($0.timestamp - timestamp) <= windowSeconds
        }
        
        return relevantSegments.map { $0.text }.joined(separator: " ")
    }
}

enum Speaker {
    case physician
    case patient
    case nurse
    case unknown
}

struct SpeakerSegment {
    let speaker: Speaker
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
}

// MARK: - Confidence Metrics
struct TranscriptionMetrics {
    let overallConfidence: Float
    let medicalTermAccuracy: Float
    let correctionCount: Int
    let averageSegmentConfidence: Float
    let speakerIdentificationConfidence: Float
    
    var quality: TranscriptionQuality {
        if overallConfidence > 0.9 && medicalTermAccuracy > 0.85 {
            return .excellent
        } else if overallConfidence > 0.8 && medicalTermAccuracy > 0.75 {
            return .good
        } else if overallConfidence > 0.7 {
            return .fair
        } else {
            return .poor
        }
    }
    
    enum TranscriptionQuality {
        case excellent
        case good
        case fair
        case poor
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "yellow"
            case .poor: return "red"
            }
        }
    }
}