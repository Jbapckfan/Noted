import Foundation

/// Scores confidence levels for extracted medical information
class ClinicalConfidenceScorer {
    
    enum ConfidenceLevel: String {
        case high = "Explicitly stated"
        case medium = "Inferred from context"
        case low = "Uncertain/Assumed"
        
        var score: Float {
            switch self {
            case .high: return 0.9
            case .medium: return 0.6
            case .low: return 0.3
            }
        }
        
        var symbol: String {
            switch self {
            case .high: return "✓✓"
            case .medium: return "✓"
            case .low: return "?"
            }
        }
    }
    
    struct ScoredInformation {
        let text: String
        let confidence: ConfidenceLevel
        let evidence: String // What in the conversation supports this
        
        var annotated: String {
            return "\(text) \(confidence.symbol)"
        }
    }
    
    /// Score chief complaint extraction confidence
    static func scoreChiefComplaint(_ complaint: String, from conversation: String) -> ScoredInformation {
        let conv = conversation.lowercased()
        
        // High confidence if explicitly stated
        if conv.contains("i'm here for") || conv.contains("i came in for") || 
           conv.contains("my main concern") || conv.contains("chief complaint") {
            return ScoredInformation(
                text: complaint,
                confidence: .high,
                evidence: "Patient explicitly stated reason for visit"
            )
        }
        
        // Medium confidence if mentioned but not as primary
        if conv.contains(complaint.lowercased()) {
            return ScoredInformation(
                text: complaint,
                confidence: .medium,
                evidence: "Symptom mentioned in conversation"
            )
        }
        
        // Low confidence if inferred
        return ScoredInformation(
            text: complaint,
            confidence: .low,
            evidence: "Inferred from conversation context"
        )
    }
    
    /// Score onset timing confidence
    static func scoreOnset(_ onset: String, from conversation: String) -> ScoredInformation {
        let conv = conversation.lowercased()
        
        // High confidence for specific times
        let specificTimePatterns = [
            "\\d+:\\d+", // Clock time
            "\\d+\\s*(hours?|days?|weeks?)\\s*ago", // Specific duration
            "yesterday at", "this morning at", "last night at"
        ]
        
        for pattern in specificTimePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                if regex.firstMatch(in: conv, range: NSRange(conv.startIndex..., in: conv)) != nil {
                    return ScoredInformation(
                        text: onset,
                        confidence: .high,
                        evidence: "Specific time mentioned"
                    )
                }
            }
        }
        
        // Medium confidence for general times
        if conv.contains("yesterday") || conv.contains("this morning") || 
           conv.contains("last night") || conv.contains("few days") {
            return ScoredInformation(
                text: onset,
                confidence: .medium,
                evidence: "General timeframe provided"
            )
        }
        
        // Low confidence
        return ScoredInformation(
            text: onset,
            confidence: .low,
            evidence: "Onset time unclear or not specified"
        )
    }
    
    /// Score medication extraction confidence
    static func scoreMedication(_ medication: String, from conversation: String) -> ScoredInformation {
        let conv = conversation.lowercased()
        let med = medication.lowercased()
        
        // High confidence if dose and frequency included
        if conv.contains(med) && (conv.contains("mg") || conv.contains("milligrams")) &&
           (conv.contains("daily") || conv.contains("twice") || conv.contains("three times")) {
            return ScoredInformation(
                text: medication,
                confidence: .high,
                evidence: "Medication with dose and frequency stated"
            )
        }
        
        // Medium confidence if just medication name
        if conv.contains(med) {
            return ScoredInformation(
                text: medication,
                confidence: .medium,
                evidence: "Medication name mentioned"
            )
        }
        
        // Low confidence
        return ScoredInformation(
            text: medication,
            confidence: .low,
            evidence: "Medication inferred or unclear"
        )
    }
    
    /// Score severity assessment confidence
    static func scoreSeverity(_ severity: String, from conversation: String) -> ScoredInformation {
        let conv = conversation.lowercased()
        
        // High confidence for numeric scales
        if let regex = try? NSRegularExpression(pattern: "\\d+\\s*(/10|out of 10|of 10)", options: []) {
            if regex.firstMatch(in: conv, range: NSRange(conv.startIndex..., in: conv)) != nil {
                return ScoredInformation(
                    text: severity,
                    confidence: .high,
                    evidence: "Numeric pain scale provided"
                )
            }
        }
        
        // High confidence for specific descriptors
        let severeTerms = ["worst", "severe", "excruciating", "unbearable", "extreme"]
        let mildTerms = ["mild", "slight", "minor", "minimal"]
        
        for term in severeTerms + mildTerms {
            if conv.contains(term) {
                return ScoredInformation(
                    text: severity,
                    confidence: .high,
                    evidence: "Specific severity descriptor used"
                )
            }
        }
        
        // Medium confidence for general descriptors
        if conv.contains("bad") || conv.contains("hurts") || conv.contains("painful") {
            return ScoredInformation(
                text: severity,
                confidence: .medium,
                evidence: "General pain description"
            )
        }
        
        // Low confidence
        return ScoredInformation(
            text: severity,
            confidence: .low,
            evidence: "Severity not clearly stated"
        )
    }
    
    /// Generate confidence report for entire note
    static func generateConfidenceReport(for sections: [String: String], from conversation: String) -> String {
        var report = "=== EXTRACTION CONFIDENCE REPORT ===\n\n"
        
        var highConfidence = 0
        var mediumConfidence = 0
        var lowConfidence = 0
        
        // Score each section
        for (section, content) in sections {
            let confidence: ConfidenceLevel
            
            switch section {
            case "Chief Complaint":
                confidence = scoreChiefComplaint(content, from: conversation).confidence
            case "Onset":
                confidence = scoreOnset(content, from: conversation).confidence
            case "Medications":
                confidence = scoreMedication(content, from: conversation).confidence
            case "Severity":
                confidence = scoreSeverity(content, from: conversation).confidence
            default:
                // Default scoring based on content length and keywords
                confidence = content.count > 20 ? .medium : .low
            }
            
            report += "\(section): \(confidence.symbol) \(confidence.rawValue)\n"
            
            switch confidence {
            case .high: highConfidence += 1
            case .medium: mediumConfidence += 1
            case .low: lowConfidence += 1
            }
        }
        
        // Overall confidence score
        let total = highConfidence + mediumConfidence + lowConfidence
        let overallScore = Float(highConfidence * 3 + mediumConfidence * 2 + lowConfidence) / Float(total * 3)
        
        report += "\n=== OVERALL CONFIDENCE ===\n"
        report += "High Confidence: \(highConfidence) sections\n"
        report += "Medium Confidence: \(mediumConfidence) sections\n"
        report += "Low Confidence: \(lowConfidence) sections\n"
        report += "Overall Score: \(String(format: "%.1f%%", overallScore * 100))\n"
        
        if overallScore < 0.5 {
            report += "\n⚠️ Low overall confidence - consider gathering more information\n"
        } else if overallScore > 0.8 {
            report += "\n✅ High confidence extraction - information appears complete\n"
        }
        
        return report
    }
    
    /// Annotate text with confidence markers
    static func annotateWithConfidence(_ text: String, confidence: ConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return text // No annotation needed for high confidence
        case .medium:
            return "\(text) [?]" // Uncertainty marker
        case .low:
            return "\(text) [assumed]" // Clear assumption marker
        }
    }
}