import Foundation

/// Expands common medical abbreviations and ensures proper medical terminology
class MedicalAbbreviationExpander {
    
    // Common medical abbreviations to expand in conversations
    static let commonAbbreviations: [String: String] = [
        // Vital signs
        "bp": "blood pressure",
        "hr": "heart rate", 
        "rr": "respiratory rate",
        "o2 sat": "oxygen saturation",
        "temp": "temperature",
        
        // Symptoms
        "sob": "shortness of breath",
        "cp": "chest pain",
        "n/v": "nausea and vomiting",
        "ha": "headache",
        "abd": "abdominal",
        "rlq": "right lower quadrant",
        "ruq": "right upper quadrant",
        "llq": "left lower quadrant",
        "luq": "left upper quadrant",
        
        // Medical terms
        "hx": "history",
        "fx": "fracture",
        "tx": "treatment",
        "dx": "diagnosis",
        "sx": "symptoms",
        "rx": "prescription",
        "pt": "patient",
        "pcp": "primary care physician",
        "ed": "emergency department",
        "er": "emergency room",
        "icu": "intensive care unit",
        "or": "operating room",
        
        // Conditions
        "htn": "hypertension",
        "dm": "diabetes mellitus",
        "cad": "coronary artery disease",
        "chf": "congestive heart failure",
        "copd": "chronic obstructive pulmonary disease",
        "uti": "urinary tract infection",
        "uri": "upper respiratory infection",
        "gerd": "gastroesophageal reflux disease",
        "mi": "myocardial infarction",
        "cva": "cerebrovascular accident",
        "dvt": "deep vein thrombosis",
        "pe": "pulmonary embolism",
        
        // Medications (common)
        "asa": "aspirin",
        "apap": "acetaminophen",
        "nsaid": "non-steroidal anti-inflammatory drug",
        "abx": "antibiotics",
        "iv": "intravenous",
        "po": "by mouth",
        "prn": "as needed",
        "bid": "twice daily",
        "tid": "three times daily",
        "qid": "four times daily",
        "qhs": "at bedtime",
        "qd": "daily",
        
        // Physical exam
        "wnl": "within normal limits",
        "nad": "no acute distress",
        "aox3": "alert and oriented times three",
        "ctab": "clear to auscultation bilaterally",
        "rrr": "regular rate and rhythm",
        "nt/nd": "non-tender, non-distended",
        "eomi": "extraocular movements intact",
        "perrl": "pupils equal, round, reactive to light"
    ]
    
    // Medical phrase improvements
    static let phraseImprovements: [String: String] = [
        // Patient descriptions
        "stomach pain": "abdominal pain",
        "belly pain": "abdominal pain",
        "stomach ache": "abdominal discomfort",
        "can't breathe": "dyspnea",
        "trouble breathing": "respiratory distress",
        "dizzy": "vertigo/dizziness",
        "passed out": "syncope",
        "threw up": "emesis",
        "throwing up": "vomiting",
        "can't sleep": "insomnia",
        "tired": "fatigue",
        "weak": "generalized weakness",
        "racing heart": "palpitations",
        
        // Anatomical corrections
        "back end": "perianal region",
        "private parts": "genitalia",
        "lady parts": "female genitalia",
        "down there": "pelvic region",
        "tummy": "abdomen",
        "chest": "thorax",
        
        // Time descriptions
        "a while": "several weeks",
        "recently": "within the past week",
        "long time": "chronic duration",
        "sudden": "acute onset",
        "slowly": "gradual onset"
    ]
    
    /// Expand abbreviations in text
    static func expandAbbreviations(in text: String) -> String {
        var expandedText = text
        
        // Sort by length (longest first) to avoid partial replacements
        let sortedAbbreviations = commonAbbreviations.sorted { $0.key.count > $1.key.count }
        
        for (abbrev, expansion) in sortedAbbreviations {
            // Case-insensitive replacement with word boundaries
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbrev))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                expandedText = regex.stringByReplacingMatches(
                    in: expandedText,
                    range: NSRange(expandedText.startIndex..., in: expandedText),
                    withTemplate: expansion
                )
            }
        }
        
        return expandedText
    }
    
    /// Improve medical phrasing
    static func improveMedicalPhrasing(in text: String) -> String {
        var improvedText = text.lowercased()
        
        // Replace colloquial phrases with medical terms
        for (colloquial, medical) in phraseImprovements {
            improvedText = improvedText.replacingOccurrences(of: colloquial, with: medical)
        }
        
        // Capitalize first letter of sentences
        improvedText = improvedText.capitalizingFirstLetter()
        
        return improvedText
    }
    
    /// Add medical context to numbers
    static func addMedicalContext(to text: String) -> String {
        var contextualText = text
        
        // Add units to vital signs
        // Blood pressure pattern: 120/80 → 120/80 mmHg
        if let bpRegex = try? NSRegularExpression(pattern: "\\b(\\d{2,3})/(\\d{2,3})\\b(?!\\s*mmHg)", options: []) {
            contextualText = bpRegex.stringByReplacingMatches(
                in: contextualText,
                range: NSRange(contextualText.startIndex..., in: contextualText),
                withTemplate: "$1/$2 mmHg"
            )
        }
        
        // Temperature pattern: 98.6 → 98.6°F (if not already specified)
        if let tempRegex = try? NSRegularExpression(pattern: "\\b(9[6-9]|10[0-5])\\.\\d\\b(?!\\s*°)", options: []) {
            contextualText = tempRegex.stringByReplacingMatches(
                in: contextualText,
                range: NSRange(contextualText.startIndex..., in: contextualText),
                withTemplate: "$0°F"
            )
        }
        
        // Heart rate: 80 (in context of pulse/heart) → 80 bpm
        if contextualText.contains("heart rate") || contextualText.contains("pulse") {
            if let hrRegex = try? NSRegularExpression(pattern: "\\b([4-9]\\d|1[0-9]\\d)\\b(?!\\s*bpm)", options: []) {
                let matches = hrRegex.matches(in: contextualText, range: NSRange(contextualText.startIndex..., in: contextualText))
                // Only replace if number is in reasonable HR range (40-200)
                for match in matches.reversed() {
                    if let range = Range(match.range, in: contextualText) {
                        let number = String(contextualText[range])
                        if let value = Int(number), value >= 40 && value <= 200 {
                            contextualText.replaceSubrange(range, with: "\(number) bpm")
                        }
                    }
                }
            }
        }
        
        return contextualText
    }
    
    /// Process text through all improvements
    static func processText(_ text: String) -> String {
        var processedText = text
        
        // 1. Expand abbreviations
        processedText = expandAbbreviations(in: processedText)
        
        // 2. Improve medical phrasing
        processedText = improveMedicalPhrasing(in: processedText)
        
        // 3. Add medical context
        processedText = addMedicalContext(to: processedText)
        
        return processedText
    }
}

// String extension helper
extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
}