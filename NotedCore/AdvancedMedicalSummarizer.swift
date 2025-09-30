import Foundation
import NaturalLanguage

/// Advanced medical summarization with sentence fusion, templates, and clinical reasoning
class AdvancedMedicalSummarizer {
    static let shared = AdvancedMedicalSummarizer()

    private let embeddingModel: NLEmbedding?

    private init() {
        embeddingModel = NLEmbedding.wordEmbedding(for: .english)
    }

    // MARK: - 1. Sentence Fusion Engine

    func fuseSentences(from transcript: String, entities: MedicalEntities) -> [FusedSentence] {
        // For conversational transcripts, we need to extract complete thoughts, not fragments
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { sentence in
                // Filter out junk: too short, no medical content, or filler
                guard sentence.count > 15 else { return false }
                let lower = sentence.lowercased()

                // Remove pure conversational filler
                if lower.contains("yeah yeah") || lower.contains("mhmm") ||
                   lower.contains("uh") || lower.contains("um") ||
                   lower == "okay" || lower == "yeah" || lower == "alright" {
                    return false
                }

                // Keep sentences with medical content
                let hasMedicalContent = entities.symptoms.contains { lower.contains($0.lowercased()) } ||
                                       entities.medications.contains { lower.contains($0.lowercased()) } ||
                                       lower.contains("pain") || lower.contains("feel") ||
                                       lower.contains("heart") || lower.contains("chest") ||
                                       lower.contains("started") || lower.contains("hours") ||
                                       lower.contains("days") || lower.contains("rate")

                return hasMedicalContent
            }

        // Score each sentence by clinical relevance
        let scoredSentences = sentences.map { sentence -> (sentence: String, score: Double) in
            var score = 0.0
            let lower = sentence.lowercased()

            // High value: Patient describing symptoms
            if lower.contains("feel") || lower.contains("having") || lower.contains("started") {
                score += 5.0
            }

            // High value: Contains chief complaint
            if lower.contains("palpitation") || lower.contains("heart") {
                score += 4.0
            }

            // High value: Duration/timing
            if lower.contains("hour") || lower.contains("day") || lower.contains("week") ||
               lower.contains("ago") || lower.contains("started") {
                score += 3.0
            }

            // High value: Quality descriptors
            if lower.contains("sharp") || lower.contains("dull") || lower.contains("racing") ||
               lower.contains("pounding") || lower.contains("fast") {
                score += 3.0
            }

            // Medium value: Associated symptoms
            if lower.contains("dizzy") || lower.contains("nausea") || lower.contains("sweaty") {
                score += 2.0
            }

            // Penalize doctor questions (we want patient responses)
            if sentence.starts(with: "Any") || sentence.starts(with: "Have you") ||
               sentence.starts(with: "Do you") || sentence.starts(with: "Did you") {
                score -= 2.0
            }

            return (sentence, score)
        }

        // Take top scoring sentences
        let topSentences = scoredSentences.sorted { $0.score > $1.score }
            .prefix(8)
            .map { FusedSentence(content: $0.sentence, topic: "clinical", sourceCount: 1) }

        return topSentences
    }

    private func extractPrimaryTopic(from sentence: String, entities: MedicalEntities) -> String {
        let lower = sentence.lowercased()

        // Check for symptoms
        for symptom in entities.symptoms {
            if lower.contains(symptom.lowercased()) {
                return "symptom:\(symptom)"
            }
        }

        // Check for medications
        for med in entities.medications {
            if lower.contains(med.lowercased()) {
                return "medication:\(med)"
            }
        }

        // Check for conditions
        for condition in entities.conditions {
            if lower.contains(condition.lowercased()) {
                return "condition:\(condition)"
            }
        }

        // Check for temporal markers
        if lower.contains("started") || lower.contains("began") || lower.contains("onset") {
            return "onset"
        }

        if lower.contains("worse") || lower.contains("better") || lower.contains("changed") {
            return "progression"
        }

        return "general"
    }

    private func fuseSentenceGroup(_ sentences: [String], topic: String) -> FusedSentence? {
        guard !sentences.isEmpty else { return nil }

        if sentences.count == 1 {
            return FusedSentence(content: sentences[0], topic: topic, sourceCount: 1)
        }

        // Extract key information from each sentence
        var temporal: String?
        var quality: String?
        var severity: String?
        var location: String?
        var modifiers: [String] = []
        var baseContent = sentences[0]

        for sentence in sentences {
            let lower = sentence.lowercased()

            // Extract temporal
            if temporal == nil {
                if let time = extractTemporal(from: lower) {
                    temporal = time
                }
            }

            // Extract quality descriptors
            if quality == nil {
                if let qual = extractQuality(from: lower) {
                    quality = qual
                }
            }

            // Extract severity
            if severity == nil {
                if let sev = extractSeverity(from: lower) {
                    severity = sev
                }
            }

            // Extract location
            if location == nil {
                if let loc = extractLocation(from: lower) {
                    location = loc
                }
            }

            // Extract modifiers
            let mods = extractModifiers(from: lower)
            modifiers.append(contentsOf: mods)
        }

        // Fuse into single sentence
        var fused = baseContent

        if let quality = quality, !fused.lowercased().contains(quality.lowercased()) {
            fused = fused.replacingOccurrences(of: "pain", with: "\(quality) pain", options: .caseInsensitive)
        }

        if let temporal = temporal, !fused.lowercased().contains(temporal.lowercased()) {
            if fused.hasSuffix(".") {
                fused = String(fused.dropLast())
            }
            fused += " that \(temporal)."
        }

        if let severity = severity, !fused.lowercased().contains(severity.lowercased()) {
            if fused.hasSuffix(".") {
                fused = String(fused.dropLast())
            }
            fused += ", rated \(severity)."
        }

        return FusedSentence(content: fused, topic: topic, sourceCount: sentences.count)
    }

    private func extractTemporal(from text: String) -> String? {
        let patterns = ["started", "began", "onset", "hours ago", "days ago", "weeks ago", "yesterday", "this morning"]
        for pattern in patterns {
            if let range = text.range(of: pattern) {
                let start = text.index(range.lowerBound, offsetBy: -10, limitedBy: text.startIndex) ?? text.startIndex
                let end = text.index(range.upperBound, offsetBy: 20, limitedBy: text.endIndex) ?? text.endIndex
                return String(text[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private func extractQuality(from text: String) -> String? {
        let qualities = ["sharp", "dull", "aching", "burning", "stabbing", "throbbing", "crushing", "pressure"]
        for quality in qualities {
            if text.contains(quality) {
                return quality
            }
        }
        return nil
    }

    private func extractSeverity(from text: String) -> String? {
        if let range = text.range(of: #"\d+/10"#, options: .regularExpression) {
            return String(text[range])
        }

        let severities = ["severe", "moderate", "mild", "worst"]
        for severity in severities {
            if text.contains(severity) {
                return severity
            }
        }
        return nil
    }

    private func extractLocation(from text: String) -> String? {
        let locations = ["chest", "head", "abdomen", "back", "arm", "leg", "neck"]
        for location in locations {
            if text.contains(location) {
                return location
            }
        }
        return nil
    }

    private func extractModifiers(from text: String) -> [String] {
        var modifiers: [String] = []

        if text.contains("worse with") || text.contains("aggravated by") {
            modifiers.append("aggravating factor present")
        }

        if text.contains("better with") || text.contains("relieved by") {
            modifiers.append("relieving factor present")
        }

        return modifiers
    }

    // MARK: - 2. Medical Writing Templates

    func generateStructuredHPI(
        chiefComplaint: String,
        fusedSentences: [FusedSentence],
        entities: MedicalEntities,
        demographics: PatientDemographics?
    ) -> String {
        var hpi = ""

        // Opening statement
        hpi += "Patient presents with \(chiefComplaint.lowercased()). "

        // Add key clinical details from top sentences
        for (index, sentence) in fusedSentences.prefix(5).enumerated() {
            let content = sentence.content
            // Clean up the sentence
            let cleaned = content
                .replacingOccurrences(of: "Yeah", with: "")
                .replacingOccurrences(of: "Mhmm", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleaned.isEmpty && cleaned.count > 10 {
                hpi += cleaned
                if !cleaned.hasSuffix(".") && !cleaned.hasSuffix("!") && !cleaned.hasSuffix("?") {
                    hpi += "."
                }
                hpi += " "
            }
        }

        // Add pertinent negatives
        let negatives = getPertinentNegatives(for: chiefComplaint, entities: entities)
        if !negatives.isEmpty {
            hpi += "Denies \(negatives.prefix(4).joined(separator: ", ")). "
        }

        return hpi.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - 3. Pertinent Negatives Database

    private func getPertinentNegatives(for chiefComplaint: String, entities: MedicalEntities) -> [String] {
        let lower = chiefComplaint.lowercased()
        let existingSymptoms = Set(entities.symptoms.map { $0.lowercased() })

        var expectedFindings: [String] = []

        // Chest pain
        if lower.contains("chest") || lower.contains("pain") {
            expectedFindings = ["shortness of breath", "diaphoresis", "nausea", "radiation to arm", "radiation to jaw", "palpitations"]
        }

        // Headache
        if lower.contains("headache") || lower.contains("head") {
            expectedFindings = ["vision changes", "neck stiffness", "fever", "photophobia", "vomiting", "confusion"]
        }

        // Abdominal pain
        if lower.contains("abdominal") || lower.contains("stomach") || lower.contains("belly") {
            expectedFindings = ["nausea", "vomiting", "diarrhea", "constipation", "fever", "blood in stool"]
        }

        // Shortness of breath
        if lower.contains("breath") || lower.contains("dyspnea") || lower.contains("sob") {
            expectedFindings = ["chest pain", "cough", "fever", "leg swelling", "orthopnea", "wheezing"]
        }

        // Fever
        if lower.contains("fever") {
            expectedFindings = ["cough", "sore throat", "urinary symptoms", "rash", "headache", "neck stiffness"]
        }

        // Return only those NOT present in existing symptoms
        return expectedFindings.filter { !existingSymptoms.contains($0) }
    }

    // MARK: - 4. Redundancy Detection

    func removeRedundantSentences(_ sentences: [FusedSentence]) -> [FusedSentence] {
        guard let embedding = embeddingModel else {
            return sentences
        }

        var unique: [FusedSentence] = []
        var seenVectors: [(vector: [Double]?, sentence: FusedSentence)] = []

        for sentence in sentences {
            let vector = getEmbeddingVector(for: sentence.content, using: embedding)

            // Check if semantically similar to existing sentences
            var isDuplicate = false
            for seen in seenVectors {
                if let v1 = vector, let v2 = seen.vector {
                    let similarity = cosineSimilarity(v1, v2)
                    if similarity > 0.85 { // High similarity threshold
                        isDuplicate = true
                        // Keep the one with more information (longer or from more sources)
                        if sentence.sourceCount > seen.sentence.sourceCount {
                            // Replace with more informative version
                            if let index = unique.firstIndex(where: { $0.content == seen.sentence.content }) {
                                unique[index] = sentence
                            }
                        }
                        break
                    }
                }
            }

            if !isDuplicate {
                unique.append(sentence)
                seenVectors.append((vector, sentence))
            }
        }

        return unique
    }

    private func getEmbeddingVector(for text: String, using embedding: NLEmbedding) -> [Double]? {
        // Get average embedding for all words
        let words = text.components(separatedBy: .whitespaces)
        var vectors: [[Double]] = []

        for word in words {
            if let vector = embedding.vector(for: word) {
                vectors.append(vector)
            }
        }

        guard !vectors.isEmpty else { return nil }

        // Average the vectors
        let dimension = vectors[0].count
        var avgVector = [Double](repeating: 0.0, count: dimension)

        for vector in vectors {
            for i in 0..<dimension {
                avgVector[i] += vector[i]
            }
        }

        for i in 0..<dimension {
            avgVector[i] /= Double(vectors.count)
        }

        return avgVector
    }

    private func cosineSimilarity(_ v1: [Double], _ v2: [Double]) -> Double {
        guard v1.count == v2.count else { return 0.0 }

        var dotProduct = 0.0
        var mag1 = 0.0
        var mag2 = 0.0

        for i in 0..<v1.count {
            dotProduct += v1[i] * v2[i]
            mag1 += v1[i] * v1[i]
            mag2 += v2[i] * v2[i]
        }

        mag1 = sqrt(mag1)
        mag2 = sqrt(mag2)

        guard mag1 > 0 && mag2 > 0 else { return 0.0 }

        return dotProduct / (mag1 * mag2)
    }

    // MARK: - 5. Clinical Reasoning Chains

    func generateClinicalReasoning(
        entities: MedicalEntities,
        chiefComplaint: String,
        differentials: [DifferentialDiagnosis]
    ) -> String {
        // Only generate reasoning if we have valid differentials
        guard !differentials.isEmpty else {
            return "Assessment based on clinical presentation.\n\n"
        }

        var reasoning = ""

        // Only show top differential if it makes sense for the chief complaint
        if let topDiff = differentials.first {
            // Filter to only emergent/urgent conditions actually matching the chief complaint
            let relevantDifferentials = differentials.filter { diff in
                let ccLower = chiefComplaint.lowercased()
                let diagLower = diff.diagnosis.lowercased()

                // Check if differential actually relates to chief complaint
                if ccLower.contains("palpitation") || ccLower.contains("heart") {
                    return diagLower.contains("cardiac") || diagLower.contains("mi") ||
                           diagLower.contains("arrhythmia") || diagLower.contains("pe") ||
                           diagLower.contains("chf")
                }

                if ccLower.contains("chest") && ccLower.contains("pain") {
                    return diagLower.contains("cardiac") || diagLower.contains("acs") ||
                           diagLower.contains("pe") || diagLower.contains("dissection")
                }

                if ccLower.contains("headache") || ccLower.contains("head") {
                    return diagLower.contains("hemorrhage") || diagLower.contains("meningitis") ||
                           diagLower.contains("migraine")
                }

                return false
            }

            if !relevantDifferentials.isEmpty {
                reasoning += "**Differential Diagnosis:**\n"
                for (index, diff) in relevantDifferentials.prefix(3).enumerated() {
                    reasoning += "\(index + 1). \(diff.diagnosis) (\(diff.urgency.displayText))\n"
                    reasoning += "   - Workup: \(diff.workup.prefix(3).joined(separator: ", "))\n"
                }
                reasoning += "\n"
            }
        }

        return reasoning
    }
}

// MARK: - Supporting Types

struct FusedSentence {
    let content: String
    let topic: String
    let sourceCount: Int
}

struct PatientDemographics {
    let age: Int
    let gender: String
}