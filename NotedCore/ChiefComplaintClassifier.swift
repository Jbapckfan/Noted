import Foundation

class ChiefComplaintClassifier {

    enum ChiefComplaintType: String, CaseIterable {
        case neurological
        case cardiovascular
        case respiratory
        case gastrointestinal
        case genitourinary
        case musculoskeletal
        case infectious
        case psychiatric
        case metabolic
        case oncological

        var requiredElements: [String] {
            switch self {
            case .neurological:
                return ["onset", "witnessed", "LOC", "confusion", "weakness"]
            case .cardiovascular:
                return ["chest_pain", "quality", "radiation", "associated_symptoms"]
            case .respiratory:
                return ["dyspnea", "oxygen", "cough", "sputum"]
            case .gastrointestinal:
                return ["pain_location", "nausea", "bowel_habits", "eating"]
            case .genitourinary:
                return ["urinary_symptoms", "frequency", "dysuria"]
            case .musculoskeletal:
                return ["mechanism", "radiation", "neurological"]
            case .infectious:
                return ["fever", "drainage", "erythema", "duration"]
            case .psychiatric:
                return ["symptoms", "duration", "triggers", "safety"]
            case .metabolic:
                return ["labs", "weakness", "intake", "medications"]
            case .oncological:
                return ["cancer_history", "treatments", "complications"]
            }
        }
    }

    func classify(transcript: String) -> (type: ChiefComplaintType, confidence: Double) {
        let lowercased = transcript.lowercased()
        var scores: [ChiefComplaintType: Double] = [:]

        // Neurological keywords
        let neuroKeywords = ["seizure", "unconscious", "confused", "stroke", "weak", "fall"]
        scores[.neurological] = calculateScore(lowercased, keywords: neuroKeywords)

        // Cardiovascular keywords
        let cardiacKeywords = ["chest", "heart", "pressure", "crushing", "radiating"]
        scores[.cardiovascular] = calculateScore(lowercased, keywords: cardiacKeywords)

        // Respiratory keywords
        let respKeywords = ["breathe", "oxygen", "wheeze", "cough", "congestion"]
        scores[.respiratory] = calculateScore(lowercased, keywords: respKeywords)

        // GI keywords
        let giKeywords = ["stomach", "belly", "vomit", "diarrhea", "constipated"]
        scores[.gastrointestinal] = calculateScore(lowercased, keywords: giKeywords)

        // GU keywords
        let guKeywords = ["urine", "pee", "bladder", "kidney", "uti"]
        scores[.genitourinary] = calculateScore(lowercased, keywords: guKeywords)

        // Musculoskeletal keywords
        let mskKeywords = ["pain", "joint", "muscle", "injury", "fracture", "sprain"]
        scores[.musculoskeletal] = calculateScore(lowercased, keywords: mskKeywords)

        // Infectious keywords
        let infectKeywords = ["fever", "infection", "abscess", "pus", "drainage"]
        scores[.infectious] = calculateScore(lowercased, keywords: infectKeywords)

        // Psychiatric keywords
        let psychKeywords = ["anxiety", "depression", "suicidal", "panic", "mood"]
        scores[.psychiatric] = calculateScore(lowercased, keywords: psychKeywords)

        // Metabolic keywords
        let metabolicKeywords = ["sugar", "diabetes", "glucose", "electrolyte"]
        scores[.metabolic] = calculateScore(lowercased, keywords: metabolicKeywords)

        // Oncological keywords
        let oncoKeywords = ["cancer", "tumor", "chemo", "radiation", "oncology"]
        scores[.oncological] = calculateScore(lowercased, keywords: oncoKeywords)

        let best = scores.max(by: { $0.value < $1.value }) ?? (.neurological, 0.0)
        return (best.key, best.value)
    }

    private func calculateScore(_ text: String, keywords: [String]) -> Double {
        let matches = keywords.filter { text.contains($0) }.count
        return Double(matches) / Double(keywords.count)
    }
}