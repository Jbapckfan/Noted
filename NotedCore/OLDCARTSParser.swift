import Foundation

/// OLDCARTS format parser for structured HPI
/// Onset, Location, Duration, Character, Aggravating, Relieving, Timing, Severity
struct OLDCARTSParser {

    static func parseTranscript(_ text: String) -> OLDCARTSComponents {
        let lower = text.lowercased()
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        return OLDCARTSComponents(
            onset: extractOnset(from: sentences, fullText: lower),
            location: extractLocation(from: sentences, fullText: lower),
            duration: extractDuration(from: sentences, fullText: lower),
            character: extractCharacter(from: sentences, fullText: lower),
            aggravating: extractAggravating(from: sentences, fullText: lower),
            relieving: extractRelieving(from: sentences, fullText: lower),
            timing: extractTiming(from: sentences, fullText: lower),
            severity: extractSeverity(from: sentences, fullText: lower)
        )
    }

    static func formatAsHPI(_ components: OLDCARTSComponents, chiefComplaint: String) -> String {
        var hpi = "**HISTORY OF PRESENT ILLNESS:**\n\n"
        hpi += "Chief Complaint: \(chiefComplaint)\n\n"

        // Build narrative from components
        var narrative: [String] = []

        if let onset = components.onset {
            narrative.append(onset)
        }

        if let location = components.location {
            narrative.append("The pain is located \(location)")
        }

        if let character = components.character {
            narrative.append("described as \(character)")
        }

        if let severity = components.severity {
            narrative.append("with severity of \(severity)")
        }

        if let duration = components.duration {
            narrative.append("lasting \(duration)")
        }

        if let timing = components.timing {
            narrative.append("The symptoms are \(timing)")
        }

        if let aggravating = components.aggravating {
            narrative.append("Aggravated by \(aggravating)")
        }

        if let relieving = components.relieving {
            narrative.append("Relieved by \(relieving)")
        }

        hpi += narrative.joined(separator: ". ") + "."

        return hpi
    }

    // MARK: - Component Extraction

    private static func extractOnset(from sentences: [String], fullText: String) -> String? {
        let onsetPatterns = [
            "started", "began", "onset", "came on", "woke up with",
            "noticed", "developed", "first experienced"
        ]

        for sentence in sentences {
            let lower = sentence.lowercased()
            for pattern in onsetPatterns {
                if lower.contains(pattern) {
                    // Extract temporal info
                    if let time = extractTimeReference(from: lower) {
                        return "Symptoms started \(time)"
                    }
                    return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        return nil
    }

    private static func extractLocation(from sentences: [String], fullText: String) -> String? {
        let locationPatterns = [
            "chest", "head", "abdomen", "belly", "stomach", "back",
            "left", "right", "upper", "lower", "side",
            "arm", "leg", "neck", "shoulder", "hip", "knee"
        ]

        var locations: [String] = []

        for sentence in sentences {
            let lower = sentence.lowercased()
            for pattern in locationPatterns {
                if lower.contains(pattern) {
                    // Check for modifiers
                    if lower.contains("left " + pattern) || lower.contains(pattern + " left") {
                        locations.append("left \(pattern)")
                    } else if lower.contains("right " + pattern) || lower.contains(pattern + " right") {
                        locations.append("right \(pattern)")
                    } else if lower.contains(pattern) {
                        locations.append(pattern)
                    }
                }
            }
        }

        return locations.isEmpty ? nil : Array(Set(locations)).joined(separator: ", ")
    }

    private static func extractDuration(from sentences: [String], fullText: String) -> String? {
        let durationPatterns = [
            (pattern: #"(\d+)\s*(hour|hr|h)"#, unit: "hours"),
            (pattern: #"(\d+)\s*(day|d)"#, unit: "days"),
            (pattern: #"(\d+)\s*(week|wk|w)"#, unit: "weeks"),
            (pattern: #"(\d+)\s*(month|mo|m)"#, unit: "months"),
            (pattern: #"(\d+)\s*(minute|min)"#, unit: "minutes")
        ]

        for (pattern, _) in durationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(fullText.startIndex..., in: fullText)
                if let match = regex.firstMatch(in: fullText, range: range) {
                    if let matchRange = Range(match.range, in: fullText) {
                        return String(fullText[matchRange])
                    }
                }
            }
        }

        return nil
    }

    private static func extractCharacter(from sentences: [String], fullText: String) -> String? {
        let characterDescriptors = [
            "sharp", "dull", "aching", "burning", "stabbing", "throbbing",
            "crushing", "pressure", "squeezing", "tearing", "cramping",
            "shooting", "radiating", "constant", "intermittent"
        ]

        var descriptors: [String] = []

        for sentence in sentences {
            let lower = sentence.lowercased()
            for descriptor in characterDescriptors {
                if lower.contains(descriptor) {
                    descriptors.append(descriptor)
                }
            }
        }

        return descriptors.isEmpty ? nil : Array(Set(descriptors)).joined(separator: ", ")
    }

    private static func extractAggravating(from sentences: [String], fullText: String) -> String? {
        let aggravatingPatterns = [
            "worse with", "aggravated by", "increased by", "brought on by",
            "triggered by", "worsens with", "when i", "after"
        ]

        for sentence in sentences {
            let lower = sentence.lowercased()
            for pattern in aggravatingPatterns {
                if lower.contains(pattern) {
                    // Extract what comes after the pattern
                    if let range = lower.range(of: pattern) {
                        let after = String(lower[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let words = after.components(separatedBy: .whitespaces).prefix(5).joined(separator: " ")
                        return words.isEmpty ? nil : words
                    }
                }
            }
        }

        // Common aggravating factors
        let commonFactors = ["movement", "deep breath", "coughing", "eating", "lying down", "standing", "walking"]
        for factor in commonFactors {
            if fullText.contains(factor) {
                return factor
            }
        }

        return nil
    }

    private static func extractRelieving(from sentences: [String], fullText: String) -> String? {
        let relievingPatterns = [
            "better with", "relieved by", "improves with", "helped by",
            "goes away with", "eased by"
        ]

        for sentence in sentences {
            let lower = sentence.lowercased()
            for pattern in relievingPatterns {
                if lower.contains(pattern) {
                    if let range = lower.range(of: pattern) {
                        let after = String(lower[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let words = after.components(separatedBy: .whitespaces).prefix(5).joined(separator: " ")
                        return words.isEmpty ? nil : words
                    }
                }
            }
        }

        // Common relieving factors
        let commonFactors = ["rest", "medication", "sitting", "lying down", "ibuprofen", "tylenol"]
        for factor in commonFactors {
            if fullText.contains(factor) {
                return factor
            }
        }

        return nil
    }

    private static func extractTiming(from sentences: [String], fullText: String) -> String? {
        if fullText.contains("constant") || fullText.contains("all the time") || fullText.contains("doesn't go away") {
            return "constant"
        }

        if fullText.contains("comes and goes") || fullText.contains("intermittent") || fullText.contains("on and off") {
            return "intermittent"
        }

        if fullText.contains("getting worse") || fullText.contains("worsening") || fullText.contains("progressing") {
            return "worsening"
        }

        if fullText.contains("improving") || fullText.contains("getting better") {
            return "improving"
        }

        return nil
    }

    private static func extractSeverity(from sentences: [String], fullText: String) -> String? {
        // Pain scale
        let scalePattern = #"(\d+)(?:\s*out of\s*|\s*/\s*)(\d+)"#
        if let regex = try? NSRegularExpression(pattern: scalePattern) {
            let range = NSRange(fullText.startIndex..., in: fullText)
            if let match = regex.firstMatch(in: fullText, range: range) {
                if let matchRange = Range(match.range, in: fullText) {
                    return String(fullText[matchRange])
                }
            }
        }

        // Severity descriptors
        let severityTerms = [
            ("severe", "severe"),
            ("moderate", "moderate"),
            ("mild", "mild"),
            ("worst", "worst ever"),
            ("unbearable", "unbearable"),
            ("excruciating", "excruciating")
        ]

        for (term, description) in severityTerms {
            if fullText.contains(term) {
                return description
            }
        }

        return nil
    }

    private static func extractTimeReference(from text: String) -> String? {
        let timePatterns = [
            "today", "yesterday", "this morning", "this afternoon",
            "last night", "this week", "last week"
        ]

        for pattern in timePatterns {
            if text.contains(pattern) {
                return pattern
            }
        }

        // Hours/days ago
        let agoPattern = #"(\d+)\s*(hour|day|week)s?\s*ago"#
        if let regex = try? NSRegularExpression(pattern: agoPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if let matchRange = Range(match.range, in: text) {
                    return String(text[matchRange])
                }
            }
        }

        return nil
    }
}

// MARK: - OLDCARTS Components

struct OLDCARTSComponents {
    let onset: String?
    let location: String?
    let duration: String?
    let character: String?
    let aggravating: String?
    let relieving: String?
    let timing: String?
    let severity: String?

    var hasAnyComponents: Bool {
        return onset != nil || location != nil || duration != nil ||
               character != nil || aggravating != nil || relieving != nil ||
               timing != nil || severity != nil
    }

    func toStructuredFormat() -> String {
        var components: [String] = []

        if let onset = onset {
            components.append("**Onset:** \(onset)")
        }
        if let location = location {
            components.append("**Location:** \(location)")
        }
        if let duration = duration {
            components.append("**Duration:** \(duration)")
        }
        if let character = character {
            components.append("**Character:** \(character)")
        }
        if let aggravating = aggravating {
            components.append("**Aggravating Factors:** \(aggravating)")
        }
        if let relieving = relieving {
            components.append("**Relieving Factors:** \(relieving)")
        }
        if let timing = timing {
            components.append("**Timing:** \(timing)")
        }
        if let severity = severity {
            components.append("**Severity:** \(severity)")
        }

        return components.joined(separator: "\n")
    }
}