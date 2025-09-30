import Foundation

/// Dead simple medical summarizer - just extract facts, no BS
class SimpleMedicalSummarizer {
    static let shared = SimpleMedicalSummarizer()

    func summarize(_ transcript: String) -> String {
        // 1. Find chief complaint
        let cc = findChiefComplaint(transcript)

        // 2. Find key facts
        let facts = extractKeyFacts(transcript)

        // 3. Build simple note
        var note = "**Chief Complaint:**\n\(cc)\n\n"
        note += "**Key Clinical Information:**\n"

        for fact in facts {
            note += "• \(fact)\n"
        }

        note += "\n---\n📱 100% Offline\n"

        return note
    }

    private func findChiefComplaint(_ text: String) -> String {
        let lower = text.lowercased()

        // Direct patterns
        if lower.contains("having palpitations") { return "Palpitations" }
        if lower.contains("chest hurts") || lower.contains("chest pain") { return "Chest pain" }
        if lower.contains("shortness of breath") || lower.contains("can't breathe") || lower.contains("couldn't catch my breath") { return "Shortness of breath" }
        if lower.contains("headache") || lower.contains("head hurts") { return "Headache" }
        if lower.contains("abdominal pain") || lower.contains("stomach hurts") { return "Abdominal pain" }
        if lower.contains("fever") { return "Fever" }
        if lower.contains("cough") { return "Cough" }

        return "Presenting complaint"
    }

    private func extractKeyFacts(_ text: String) -> [String] {
        var facts: [String] = []
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 20 }

        for sentence in sentences {
            let lower = sentence.lowercased()

            // Skip pure filler
            if lower.hasPrefix("yeah") || lower.hasPrefix("okay") || lower.hasPrefix("mhmm") {
                continue
            }

            // Skip doctor questions
            if lower.hasPrefix("any ") || lower.hasPrefix("do you") || lower.hasPrefix("have you") || lower.hasPrefix("did you") {
                continue
            }

            // Keep medically relevant sentences
            let medicalKeywords = [
                "pain", "hurt", "feel", "chest", "heart", "breath", "dizzy",
                "nausea", "vomit", "fever", "cough", "started", "ago", "hour",
                "day", "week", "severe", "moderate", "mild", "blood pressure",
                "rate", "bronchitis", "asthma", "diabetes", "medication"
            ]

            var isRelevant = false
            for keyword in medicalKeywords {
                if lower.contains(keyword) {
                    isRelevant = true
                    break
                }
            }

            if isRelevant && sentence.count < 200 {
                // Clean up
                var clean = sentence
                    .replacingOccurrences(of: "Yeah,", with: "")
                    .replacingOccurrences(of: "Mhmm,", with: "")
                    .replacingOccurrences(of: "Okay,", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !clean.isEmpty && clean.count > 15 {
                    facts.append(clean)
                }
            }
        }

        // Limit to most relevant 10 facts
        return Array(facts.prefix(10))
    }
}