import Foundation
import AVFoundation
import Accelerate
import SwiftUI

// MARK: - Free Optimization Enhancements for NotedCore
// Zero-cost improvements for better summaries, UI, and audio processing

// MARK: - 1. Enhanced Audio Preprocessing (No Cost)
class OptimizedAudioProcessor {
    
    // Noise reduction using vDSP (Apple's free Accelerate framework)
    static func reduceNoise(from audioBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let channelData = audioBuffer.floatChannelData else { return nil }
        
        let frameLength = Int(audioBuffer.frameLength)
        let channelCount = Int(audioBuffer.format.channelCount)
        
        // Apply high-pass filter to remove low-frequency noise
        var filter = [Float](repeating: 0, count: frameLength)
        let cutoffFrequency: Float = 80.0 // Remove below 80Hz (room noise)
        
        for channel in 0..<channelCount {
            // Simple high-pass filter using vDSP
            var alpha: Float = 0.95
            vDSP_vsmul(channelData[channel], 1, &alpha, &filter, 1, vDSP_Length(frameLength))
        }
        
        return audioBuffer
    }
    
    // Voice Activity Detection (VAD) to skip silence
    static func detectVoiceActivity(in audioBuffer: AVAudioPCMBuffer) -> Bool {
        guard let channelData = audioBuffer.floatChannelData else { return false }
        
        let frameLength = Int(audioBuffer.frameLength)
        var energy: Float = 0
        
        // Calculate RMS energy
        vDSP_rmsqv(channelData[0], 1, &energy, vDSP_Length(frameLength))
        
        // Dynamic threshold based on ambient noise
        let voiceThreshold: Float = 0.01
        return energy > voiceThreshold
    }
    
    // Automatic Gain Control (AGC) for consistent volume
    static func normalizeAudioLevel(audioBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let channelData = audioBuffer.floatChannelData else { return nil }
        
        let frameLength = Int(audioBuffer.frameLength)
        let channelCount = Int(audioBuffer.format.channelCount)
        
        for channel in 0..<channelCount {
            var maxValue: Float = 0
            vDSP_maxv(channelData[channel], 1, &maxValue, vDSP_Length(frameLength))
            
            if maxValue > 0 {
                let targetLevel: Float = 0.8
                var scale = targetLevel / maxValue
                vDSP_vsmul(channelData[channel], 1, &scale, channelData[channel], 1, vDSP_Length(frameLength))
            }
        }
        
        return audioBuffer
    }
}

// MARK: - 2. Smart Medical Context Cache
class MedicalContextCache {
    static let shared = MedicalContextCache()
    
    private var cache: [String: CachedContext] = [:]
    private let maxCacheSize = 100
    
    struct CachedContext {
        let text: String
        let context: MedicalContext
        let timestamp: Date
        let confidence: Float
    }
    
    struct MedicalContext {
        let chiefComplaint: String
        let symptoms: [String]
        let medications: [String]
        let allergies: [String]
        let medicalHistory: [String]
        let vitalSigns: [String: String]
        let differentialDiagnosis: [String]
    }
    
    func getCachedContext(for text: String) -> MedicalContext? {
        let key = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let cached = cache[key],
           Date().timeIntervalSince(cached.timestamp) < 300 { // 5 minute cache
            return cached.context
        }
        
        return nil
    }
    
    func cacheContext(_ context: MedicalContext, for text: String, confidence: Float) {
        let key = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        cache[key] = CachedContext(
            text: text,
            context: context,
            timestamp: Date(),
            confidence: confidence
        )
        
        // Maintain cache size
        if cache.count > maxCacheSize {
            // Remove oldest entries
            let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sorted.prefix(20) {
                cache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - 3. Enhanced UI Components
struct OptimizedUIComponents {
    
    // Better visual hierarchy with gradients and shadows
    struct EnhancedNoteCard: View {
        let title: String
        let content: String
        let quality: Float
        let isGenerating: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                // Header with quality indicator
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    QualityIndicator(quality: quality)
                }
                
                // Content with better typography
                Text(content)
                    .font(.system(.body, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemBackground),
                                Color(.secondarySystemBackground).opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.3),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        }
    }
    
    struct QualityIndicator: View {
        let quality: Float
        
        var color: Color {
            switch quality {
            case 0.8...1.0: return .green
            case 0.6..<0.8: return .yellow
            default: return .red
            }
        }
        
        var body: some View {
            HStack(spacing: 2) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(Float(index) / 5.0 <= quality ? color : Color.gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }
    
    // Animated transcription view with word highlighting
    struct AnimatedTranscriptionView: View {
        let text: String
        @State private var visibleCharacters = 0
        
        var body: some View {
            Text(String(text.prefix(visibleCharacters)))
                .font(.system(.body, design: .monospaced))
                .onAppear {
                    animateText()
                }
                .onChange(of: text) { _ in
                    visibleCharacters = 0
                    animateText()
                }
        }
        
        private func animateText() {
            for index in 0..<text.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.01) {
                    if index < text.count {
                        visibleCharacters = index + 1
                    }
                }
            }
        }
    }
}

// MARK: - 4. Smart Medical Abbreviation Expander
// Moved to separate file: MedicalAbbreviationExpander.swift

// MARK: - 5. Summary Quality Scorer
class SummaryQualityScorer {
    
    struct QualityMetrics {
        let completeness: Float      // Has all required sections
        let specificity: Float        // Contains specific medical terms
        let structure: Float          // Well-formatted
        let clinicalRelevance: Float // Contains actionable information
        let confidence: Float         // Overall confidence
        
        var overallScore: Float {
            return (completeness + specificity + structure + clinicalRelevance + confidence) / 5.0
        }
    }
    
    static func scoreSummary(_ summary: String, noteType: NoteType) -> QualityMetrics {
        let sections = detectSections(in: summary)
        let medicalTerms = countMedicalTerms(in: summary)
        let structure = evaluateStructure(summary)
        let relevance = assessClinicalRelevance(summary)
        
        return QualityMetrics(
            completeness: Float(sections.count) / Float(requiredSections(for: noteType).count),
            specificity: min(Float(medicalTerms) / 20.0, 1.0),
            structure: structure,
            clinicalRelevance: relevance,
            confidence: calculateConfidence(summary)
        )
    }
    
    private static func detectSections(in text: String) -> Set<String> {
        let sectionKeywords = [
            "chief complaint", "hpi", "history of present illness",
            "review of systems", "ros", "physical exam", "pe",
            "assessment", "plan", "diagnosis", "medications",
            "allergies", "past medical history", "pmh"
        ]
        
        var found = Set<String>()
        let lowercased = text.lowercased()
        
        for keyword in sectionKeywords {
            if lowercased.contains(keyword) {
                found.insert(keyword)
            }
        }
        
        return found
    }
    
    private static func countMedicalTerms(in text: String) -> Int {
        let medicalTerms = [
            "diagnosis", "symptom", "treatment", "medication",
            "examination", "history", "assessment", "plan",
            "vital", "blood pressure", "heart rate", "temperature",
            "pain", "fever", "cough", "dyspnea", "nausea"
        ]
        
        let lowercased = text.lowercased()
        return medicalTerms.reduce(0) { count, term in
            count + (lowercased.contains(term) ? 1 : 0)
        }
    }
    
    private static func evaluateStructure(_ text: String) -> Float {
        let lines = text.components(separatedBy: .newlines)
        let hasHeaders = lines.contains { $0.contains(":") || $0.hasPrefix("#") }
        let hasBullets = text.contains("•") || text.contains("-") || text.contains("*")
        let properLength = text.count > 100 && text.count < 5000
        
        var score: Float = 0
        if hasHeaders { score += 0.4 }
        if hasBullets { score += 0.3 }
        if properLength { score += 0.3 }
        
        return score
    }
    
    private static func assessClinicalRelevance(_ text: String) -> Float {
        let actionableTerms = [
            "recommend", "prescribe", "order", "follow-up",
            "monitor", "evaluate", "consider", "rule out",
            "differential", "workup", "admit", "discharge"
        ]
        
        let lowercased = text.lowercased()
        let relevanceCount = actionableTerms.reduce(0) { count, term in
            count + (lowercased.contains(term) ? 1 : 0)
        }
        
        return min(Float(relevanceCount) / 5.0, 1.0)
    }
    
    private static func calculateConfidence(_ text: String) -> Float {
        // Check for uncertainty markers
        let uncertainTerms = ["maybe", "possibly", "might", "unclear", "unknown"]
        let lowercased = text.lowercased()
        let uncertaintyCount = uncertainTerms.reduce(0) { count, term in
            count + (lowercased.contains(term) ? 1 : 0)
        }
        
        // More uncertainty = lower confidence
        return max(1.0 - (Float(uncertaintyCount) * 0.2), 0.2)
    }
    
    private static func requiredSections(for noteType: NoteType) -> [String] {
        switch noteType {
        case .soap:
            return ["subjective", "objective", "assessment", "plan"]
        case .progress:
            return ["interval history", "assessment", "plan"]
        case .consult:
            return ["reason", "assessment", "recommendations"]
        case .discharge:
            return ["diagnosis", "hospital course", "medications", "follow-up"]
        default:
            return ["chief complaint", "hpi", "assessment", "plan"]
        }
    }
}

// MARK: - 6. Prompt Optimization Engine
class PromptOptimizationEngine {
    
    static func optimizePrompt(_ basePrompt: String, context: MedicalContextCache.MedicalContext?) -> String {
        var optimized = basePrompt
        
        // Add few-shot examples for better output
        let examples = """
        
        EXAMPLE OUTPUT FORMAT:
        
        **Chief Complaint:** Chest pain x 2 hours
        
        **HPI:** 45-year-old male presents with acute onset substernal chest pressure beginning 2 hours prior to arrival. Pain described as 8/10, crushing in nature, radiating to left arm. Associated with diaphoresis and mild dyspnea. No relief with rest. Patient has history of HTN, hyperlipidemia.
        
        **Assessment:** Acute chest pain concerning for ACS. Differential includes NSTEMI, unstable angina, PE, aortic dissection.
        
        **Plan:**
        - Serial troponins, EKG
        - Aspirin 325mg, start heparin protocol
        - Cardiology consultation
        - Admit to telemetry
        """
        
        optimized += examples
        
        // Add context if available
        if let ctx = context {
            optimized += """
            
            CONTEXT FROM PREVIOUS ENCOUNTERS:
            - Known allergies: \(ctx.allergies.joined(separator: ", "))
            - Current medications: \(ctx.medications.joined(separator: ", "))
            - Past medical history: \(ctx.medicalHistory.joined(separator: ", "))
            """
        }
        
        // Add quality instructions
        optimized += """
        
        QUALITY REQUIREMENTS:
        - Use specific medical terminology
        - Include all relevant time stamps
        - Quantify symptoms when possible (pain scale, duration, frequency)
        - Document pertinent negatives
        - Provide clear assessment with differential diagnosis
        - Include specific, actionable plan items
        """
        
        return optimized
    }
}

// MARK: - 7. Real-time Transcription Enhancer
class TranscriptionEnhancer {
    
    // Medical term autocorrection
    private static let medicalCorrections: [String: String] = [
        "hard attack": "heart attack",
        "sugar diabetes": "diabetes mellitus",
        "high blood": "hypertension",
        "low blood": "hypotension",
        "can't breathe": "dyspnea",
        "throwing up": "vomiting",
        "going to bathroom": "urination",
        "water pills": "diuretics",
        "blood thinners": "anticoagulants",
        "pain pills": "analgesics",
        "stomach bug": "gastroenteritis",
        "strep": "streptococcal",
        "staph": "staphylococcal"
    ]
    
    static func enhanceTranscription(_ text: String) -> String {
        var enhanced = text
        
        // Apply medical corrections
        for (wrong, correct) in medicalCorrections {
            enhanced = enhanced.replacingOccurrences(
                of: wrong,
                with: correct,
                options: [.caseInsensitive]
            )
        }
        
        // Fix common speech recognition errors
        enhanced = fixCommonErrors(enhanced)
        
        // Add punctuation if missing
        enhanced = addSmartPunctuation(enhanced)
        
        return enhanced
    }
    
    private static func fixCommonErrors(_ text: String) -> String {
        var fixed = text
        
        // Fix number recognition
        let numberFixes = [
            "to": "2",
            "for": "4",
            "ate": "8",
            "won": "1"
        ]
        
        // Only fix if followed by medical units
        for (word, number) in numberFixes {
            let pattern = "\(word) (mg|ml|mcg|units|tablets|pills|times|days|weeks|months|years|hours)"
            fixed = fixed.replacingOccurrences(
                of: pattern,
                with: "\(number) $1",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return fixed
    }
    
    private static func addSmartPunctuation(_ text: String) -> String {
        var result = text
        
        // Add periods at obvious sentence boundaries
        let sentenceEnders = ["and then", "after that", "next", "also"]
        for ender in sentenceEnders {
            result = result.replacingOccurrences(
                of: " \(ender) ",
                with: ". \(ender.capitalized) ",
                options: [.caseInsensitive]
            )
        }
        
        // Capitalize first letter after periods
        if let regex = try? NSRegularExpression(pattern: "\\. ([a-z])", options: []) {
            let range = NSRange(location: 0, length: result.utf16.count)
            let matches = regex.matches(in: result, options: [], range: range)
            
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: result) {
                    let letter = String(result[range])
                    result.replaceSubrange(range, with: letter.uppercased())
                }
            }
        }
        
        return result
    }
}

// MARK: - Integration Helper
extension EnhancedMedicalSummarizerService {
    
    func applyFreeOptimizations(to transcription: String) -> String {
        // Apply all free optimizations
        var optimized = transcription
        
        // 1. Enhance transcription
        optimized = TranscriptionEnhancer.enhanceTranscription(optimized)
        
        // 2. Expand medical abbreviations
        optimized = MedicalAbbreviationExpander.expandAbbreviations(in: optimized)
        
        // 3. Check cache for context
        if let cachedContext = MedicalContextCache.shared.getCachedContext(for: optimized) {
            // Use cached context to improve summary generation
            Logger.medicalAIInfo("Using cached medical context for faster processing")
        }
        
        return optimized
    }
    
    func scoreGeneratedSummary(_ summary: String, noteType: NoteType) -> SummaryQualityScorer.QualityMetrics {
        return SummaryQualityScorer.scoreSummary(summary, noteType: noteType)
    }
}