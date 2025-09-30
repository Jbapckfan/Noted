import Foundation

class IntelligentMedicalTransformer {

    // MARK: - Symptom Patterns with Medical Adjectives
    private let symptomPatterns: [(pattern: String, medical: String, type: SymptomType)] = [
        // Respiratory
        ("blue", "cyanotic", .adjective),
        ("can't breathe", "dyspneic", .adjective),
        ("short of breath", "dyspneic", .adjective),
        ("difficulty breathing", "dyspneic", .adjective),
        ("gasping", "in respiratory distress", .phrase),
        ("wheezing", "with expiratory wheezing", .phrase),

        // Cardiovascular
        ("heart racing", "tachycardic", .adjective),
        ("fast heart", "tachycardic", .adjective),
        ("heart pounding", "with palpitations", .phrase),
        ("pressure up", "hypertensive", .adjective),
        ("blood pressure high", "hypertensive", .adjective),
        ("chest pain", "with chest pain", .phrase),
        ("chest pressure", "with chest pressure", .phrase),

        // Neurological
        ("passed out", "with syncope", .phrase),
        ("lost consciousness", "with loss of consciousness", .phrase),
        ("fainted", "with syncope", .phrase),
        ("unconscious", "unconscious", .adjective),
        ("confused", "confused", .adjective),
        ("dizzy", "vertiginous", .adjective),
        ("seizure", "post-ictal", .contextual),

        // Gastrointestinal
        ("throwing up", "with emesis", .phrase),
        ("vomiting", "with emesis", .phrase),
        ("nausea", "nauseated", .adjective),
        ("belly pain", "with abdominal pain", .phrase),
        ("stomach hurts", "with abdominal pain", .phrase),
        ("can't poop", "constipated", .adjective),
        ("diarrhea", "with diarrhea", .phrase),

        // Genitourinary
        ("can't pee", "with urinary retention", .phrase),
        ("peeing a lot", "with urinary frequency", .phrase),
        ("burning when peeing", "with dysuria", .phrase),

        // General/Constitutional
        ("fever", "febrile", .adjective),
        ("hot", "febrile", .adjective),
        ("cold", "hypothermic", .contextual),
        ("sweating", "diaphoretic", .adjective),
        ("sweaty", "diaphoretic", .adjective),
        ("tired", "fatigued", .adjective),
        ("weak", "weak appearing", .adjective),

        // Mental Status
        ("anxious", "anxious", .adjective),
        ("scared", "anxious appearing", .adjective),
        ("agitated", "agitated", .adjective),

        // Skin
        ("pale", "pale", .adjective),
        ("yellow", "jaundiced", .adjective),
        ("swollen", "edematous", .adjective),
        ("red", "erythematous", .adjective),
        ("rash", "with a rash", .phrase)
    ]

    private enum SymptomType {
        case adjective  // Can be combined with "and"
        case phrase     // Needs to be appended with comma
        case contextual // Depends on context
    }

    // MARK: - Pain Descriptors
    private let painDescriptors: [String: String] = [
        "hurts bad": "severe",
        "hurts really bad": "severe",
        "killing me": "severe",
        "worst pain ever": "10/10",
        "10 out of 10": "10/10",
        "mild pain": "mild",
        "moderate pain": "moderate",
        "severe pain": "severe"
    ]

    // MARK: - Vital Signs Patterns
    private func formatVitalSigns(_ text: String) -> String {
        var result = text

        // Blood Pressure - match patterns like "180/120" or "BP 180/120"
        let bpPattern = #"(?:BP\s*(?:was\s*)?)?(\d{2,3})/(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: bpPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.count),
                withTemplate: "with a blood pressure of $1/$2"
            )
        }

        // Temperature
        let tempPattern = #"(?:temp|temperature)\s*(?:is|was)?\s*(\d{2,3}(?:\.\d)?)"#
        if let regex = try? NSRegularExpression(pattern: tempPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.count),
                withTemplate: "with a temperature of $1°F"
            )
        }

        // Heart Rate
        let hrPattern = #"(?:HR|heart rate)\s*(?:is|was)?\s*(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: hrPattern, options: .caseInsensitive) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(location: 0, length: result.count),
                withTemplate: "with a heart rate of $1"
            )
        }

        return result
    }

    // MARK: - Main Transformation Method
    func transformToMedical(_ input: String) -> String {
        var sentences = input.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var transformedSentences: [String] = []

        for sentence in sentences {
            let transformed = transformSentence(sentence)
            if !transformed.isEmpty {
                transformedSentences.append(transformed)
            }
        }

        return transformedSentences.joined(separator: ". ") + "."
    }

    private func transformSentence(_ sentence: String) -> String {
        var result = sentence.lowercased()
        var collectedAdjectives: [String] = []
        var collectedPhrases: [String] = []
        var hasPatient = result.contains("patient")

        // Extract and transform symptoms
        for (pattern, medical, type) in symptomPatterns {
            if result.contains(pattern) {
                result = result.replacingOccurrences(of: pattern, with: "###PLACEHOLDER###")

                switch type {
                case .adjective:
                    collectedAdjectives.append(medical)
                case .phrase:
                    collectedPhrases.append(medical)
                case .contextual:
                    // Handle based on context
                    if pattern == "seizure" && result.contains("had") {
                        collectedPhrases.append("who had a seizure")
                    } else if pattern == "cold" && !result.contains("feel") {
                        collectedAdjectives.append("hypothermic")
                    } else {
                        collectedAdjectives.append(medical)
                    }
                }
            }
        }

        // Transform pain descriptors
        for (casual, medical) in painDescriptors {
            if result.contains(casual) {
                if casual.contains("10") {
                    result = result.replacingOccurrences(of: casual, with: medical + " pain")
                } else {
                    result = result.replacingOccurrences(of: casual, with: medical + " pain")
                }
            }
        }

        // Format vital signs
        result = formatVitalSigns(result)

        // Check if we need to extract BP specially
        if result.contains("with a blood pressure of") {
            let bpMatch = result.firstMatch(of: /with a blood pressure of (\d{2,3}\/\d{2,3})/)
            if let match = bpMatch {
                let bp = String(match.1)
                let systolic = Int(bp.split(separator: "/")[0]) ?? 0

                // Add hypertensive/hypotensive if not already present
                if systolic >= 140 && !collectedAdjectives.contains("hypertensive") {
                    collectedAdjectives.append("hypertensive")
                }
                if systolic < 90 && !collectedAdjectives.contains("hypotensive") {
                    collectedAdjectives.append("hypotensive")
                }
            }
        }

        // Build the medical sentence
        if !collectedAdjectives.isEmpty || !collectedPhrases.isEmpty {
            var medicalSentence = ""

            // Start with "Patient"
            if !hasPatient {
                medicalSentence = "Patient"
            } else {
                medicalSentence = "The patient"
            }

            // Add presentation verb
            if result.contains("was") || result.contains("were") {
                medicalSentence += " was"
            } else if result.contains("is") {
                medicalSentence += " is"
            } else {
                medicalSentence += " presents as"
            }

            // Add adjectives with proper grammar
            if !collectedAdjectives.isEmpty {
                if collectedAdjectives.count == 1 {
                    medicalSentence += " " + collectedAdjectives[0]
                } else if collectedAdjectives.count == 2 {
                    medicalSentence += " " + collectedAdjectives[0] + " and " + collectedAdjectives[1]
                } else {
                    let lastAdjective = collectedAdjectives.removeLast()
                    medicalSentence += " " + collectedAdjectives.joined(separator: ", ") + ", and " + lastAdjective
                }
            }

            // Add phrases
            if !collectedPhrases.isEmpty {
                if !collectedAdjectives.isEmpty {
                    medicalSentence += " " + collectedPhrases.joined(separator: " ")
                } else {
                    medicalSentence += " presenting " + collectedPhrases.joined(separator: " ")
                }
            }

            // Add vital signs if present
            if result.contains("with a blood pressure") {
                if let range = result.range(of: "with a blood pressure of \\d{2,3}/\\d{2,3}", options: .regularExpression) {
                    medicalSentence += " " + result[range]
                }
            }

            return medicalSentence
        }

        // If no transformations, return cleaned original
        return sentence
    }

    // MARK: - Clean up helpers
    private func cleanUpFillers(_ text: String) -> String {
        var result = text
        let fillers = ["um", "uh", "you know", "like", "basically", "literally", "actually", "I mean"]

        for filler in fillers {
            result = result.replacingOccurrences(of: filler, with: "", options: .caseInsensitive)
        }

        // Clean up multiple spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}