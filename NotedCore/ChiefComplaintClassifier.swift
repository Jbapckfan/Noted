import Foundation

/// Enhanced Chief Complaint Classifier
/// Now supports both legacy pattern matching AND entity-based classification
/// from the three-layer architecture for dramatically improved accuracy
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

        // Neurological keywords with weights
        let neuroKeywords: [(String, Double)] = [
            ("seizure", 10.0), ("seizing", 10.0), ("convuls", 10.0),
            ("unconscious", 8.0), ("unresponsive", 8.0), ("cyanotic", 7.0),
            ("confused", 5.0), ("altered", 5.0), ("stroke", 10.0),
            ("weak", 3.0), ("weakness", 4.0), ("fall", 2.0), ("fell", 2.0),
            ("foam", 4.0), ("lethargic", 5.0), ("ams", 8.0)
        ]
        scores[.neurological] = calculateWeightedScore(lowercased, keywords: neuroKeywords)

        // Cardiovascular keywords with weights
        let cardiacKeywords: [(String, Double)] = [
            ("chest pain", 10.0), ("grabbing chest", 9.0), ("crushing", 8.0),
            ("pressure", 6.0), ("radiating", 7.0), ("radiation", 7.0),
            ("jaw", 6.0), ("left arm", 7.0), ("diaphoretic", 6.0),
            ("heart", 4.0), ("tachycardia", 7.0), ("palpitation", 8.0),
            ("sob", 5.0), ("shortness of breath", 6.0), ("dyspnea", 6.0)
        ]
        scores[.cardiovascular] = calculateWeightedScore(lowercased, keywords: cardiacKeywords)

        // Respiratory keywords with weights
        let respKeywords: [(String, Double)] = [
            ("can't breathe", 9.0), ("dyspnea", 8.0), ("hypoxia", 9.0),
            ("oxygen", 6.0), ("wheeze", 7.0), ("wheezing", 7.0),
            ("cough", 5.0), ("congestion", 4.0), ("respiratory", 6.0),
            ("sats", 6.0), ("saturation", 6.0), ("desaturat", 8.0)
        ]
        scores[.respiratory] = calculateWeightedScore(lowercased, keywords: respKeywords)

        // GI keywords with weights
        let giKeywords: [(String, Double)] = [
            ("belly", 6.0), ("abdomen", 6.0), ("abdominal", 6.0),
            ("vomit", 7.0), ("throwing up", 7.0), ("nausea", 6.0),
            ("diarrhea", 7.0), ("constipat", 7.0), ("stool", 5.0),
            ("cholecystitis", 9.0), ("ascites", 9.0), ("peritonitis", 9.0),
            ("distended", 6.0), ("tender", 4.0)
        ]
        scores[.gastrointestinal] = calculateWeightedScore(lowercased, keywords: giKeywords)

        // GU keywords with weights
        let guKeywords: [(String, Double)] = [
            ("can't pee", 10.0), ("urinary retention", 10.0), ("retention", 7.0),
            ("bladder", 7.0), ("catheter", 6.0), ("urine", 6.0),
            ("uti", 8.0), ("dysuria", 8.0), ("hematuria", 8.0),
            ("kidney", 6.0), ("foley", 6.0), ("pee", 5.0)
        ]
        scores[.genitourinary] = calculateWeightedScore(lowercased, keywords: guKeywords)

        // Musculoskeletal keywords with weights
        let mskKeywords: [(String, Double)] = [
            ("back pain", 8.0), ("radiculopathy", 9.0), ("sciatica", 9.0),
            ("spine", 6.0), ("joint", 6.0), ("muscle", 4.0),
            ("fracture", 8.0), ("injury", 5.0), ("sprain", 7.0),
            ("tingling", 6.0), ("numbness", 6.0), ("shooting", 6.0)
        ]
        scores[.musculoskeletal] = calculateWeightedScore(lowercased, keywords: mskKeywords)

        // Infectious keywords with weights
        let infectKeywords: [(String, Double)] = [
            ("fever", 7.0), ("febrile", 7.0), ("infection", 8.0),
            ("abscess", 9.0), ("pus", 7.0), ("drainage", 6.0),
            ("cellulitis", 9.0), ("sepsis", 10.0), ("septic", 10.0),
            ("erythema", 6.0), ("warm", 3.0), ("swollen", 4.0)
        ]
        scores[.infectious] = calculateWeightedScore(lowercased, keywords: infectKeywords)

        // Psychiatric keywords with weights
        let psychKeywords: [(String, Double)] = [
            ("suicidal", 10.0), ("suicide", 10.0), ("kill myself", 10.0),
            ("anxiety", 7.0), ("panic", 7.0), ("depression", 7.0),
            ("psych", 8.0), ("psychiatric", 8.0), ("bipolar", 8.0),
            ("schizophren", 8.0), ("hallucin", 8.0), ("delusion", 8.0)
        ]
        scores[.psychiatric] = calculateWeightedScore(lowercased, keywords: psychKeywords)

        // Metabolic keywords with weights
        let metabolicKeywords: [(String, Double)] = [
            ("blood sugar", 8.0), ("glucose", 7.0), ("diabetic", 7.0),
            ("hyperglycemia", 9.0), ("hypoglycemia", 9.0), ("dka", 10.0),
            ("electrolyte", 7.0), ("potassium", 6.0), ("sodium", 6.0),
            ("dehydrat", 6.0), ("metabolic", 7.0)
        ]
        scores[.metabolic] = calculateWeightedScore(lowercased, keywords: metabolicKeywords)

        // Oncological keywords with weights
        let oncoKeywords: [(String, Double)] = [
            ("cancer", 9.0), ("tumor", 9.0), ("oncology", 9.0),
            ("chemo", 8.0), ("chemotherapy", 8.0), ("radiation", 7.0),
            ("metasta", 9.0), ("malignancy", 9.0), ("lymphoma", 9.0),
            ("leukemia", 9.0), ("carcinoma", 9.0)
        ]
        scores[.oncological] = calculateWeightedScore(lowercased, keywords: oncoKeywords)

        // Find best match
        let best = scores.max(by: { $0.value < $1.value }) ?? (.neurological, 0.0)

        // Normalize confidence to 0-1 range (assuming max weight is 10)
        let normalizedConfidence = min(best.value / 10.0, 1.0)

        return (best.key, normalizedConfidence)
    }

    private func calculateWeightedScore(_ text: String, keywords: [(String, Double)]) -> Double {
        var totalScore = 0.0
        for (keyword, weight) in keywords {
            if text.contains(keyword) {
                totalScore += weight
            }
        }
        return totalScore
    }

    // MARK: - Entity-Based Classification (Three-Layer Architecture)

    /// Enhanced classification using entities from the three-layer architecture
    /// This is dramatically more accurate than pattern matching alone
    func classifyFromEntities(_ entities: [ComprehensionLayer.ClinicalEntity]) -> (type: ChiefComplaintType, confidence: Double) {
        var scores: [ChiefComplaintType: Double] = [:]

        for entity in entities where entity.type == .symptom {
            // Extract symptom characteristics from entity attributes
            let location = entity.attributes["location"] as? String ?? ""
            let type = entity.attributes["type"] as? String ?? ""
            let character = entity.attributes["character"] as? [String] ?? []
            let radiation = entity.attributes["radiation"] as? [String] ?? []

            // Score based on structured entity data
            if type == "pain" {
                if location.contains("chest") {
                    scores[.cardiovascular] = (scores[.cardiovascular] ?? 0) + 10.0

                    // Check for cardiac-specific patterns
                    if character.contains(where: { ["crushing", "pressure", "squeezing"].contains($0) }) {
                        scores[.cardiovascular] = (scores[.cardiovascular] ?? 0) + 8.0
                    }

                    if radiation.contains(where: { ["left arm", "jaw", "neck"].contains($0) }) {
                        scores[.cardiovascular] = (scores[.cardiovascular] ?? 0) + 7.0
                    }
                } else if location.contains("abdom") || location.contains("belly") || location.contains("stomach") {
                    scores[.gastrointestinal] = (scores[.gastrointestinal] ?? 0) + 10.0

                    if location.contains("right upper") || location.contains("ruq") {
                        scores[.gastrointestinal] = (scores[.gastrointestinal] ?? 0) + 5.0 // Cholecystitis
                    } else if location.contains("right lower") || location.contains("rlq") {
                        scores[.gastrointestinal] = (scores[.gastrointestinal] ?? 0) + 5.0 // Appendicitis
                    }
                } else if location.contains("head") {
                    scores[.neurological] = (scores[.neurological] ?? 0) + 8.0

                    if character.contains(where: { ["worst", "thunderclap", "sudden"].contains($0) }) {
                        scores[.neurological] = (scores[.neurological] ?? 0) + 10.0 // SAH concern
                    }
                } else if location.contains("back") {
                    scores[.musculoskeletal] = (scores[.musculoskeletal] ?? 0) + 8.0

                    if radiation.contains(where: { $0.contains("leg") || $0.contains("foot") }) {
                        scores[.musculoskeletal] = (scores[.musculoskeletal] ?? 0) + 7.0 // Radiculopathy
                    }
                }
            } else if type == "dyspnea" || type == "shortness of breath" {
                scores[.respiratory] = (scores[.respiratory] ?? 0) + 10.0
                scores[.cardiovascular] = (scores[.cardiovascular] ?? 0) + 5.0 // Can be cardiac too
            } else if type == "nausea" || type == "vomiting" {
                scores[.gastrointestinal] = (scores[.gastrointestinal] ?? 0) + 5.0
            } else if type == "weakness" {
                scores[.neurological] = (scores[.neurological] ?? 0) + 7.0

                // Check for focal vs generalized
                if let laterality = entity.attributes["laterality"] as? String,
                   laterality.contains("left") || laterality.contains("right") {
                    scores[.neurological] = (scores[.neurological] ?? 0) + 5.0 // Focal = stroke concern
                }
            } else if type == "altered mental status" || type == "confusion" {
                scores[.neurological] = (scores[.neurological] ?? 0) + 10.0
            } else if type == "seizure" {
                scores[.neurological] = (scores[.neurological] ?? 0) + 15.0
            } else if type == "fever" {
                scores[.infectious] = (scores[.infectious] ?? 0) + 8.0
            } else if type == "anxiety" || type == "panic" {
                scores[.psychiatric] = (scores[.psychiatric] ?? 0) + 8.0
            } else if type == "hyperglycemia" || type == "hypoglycemia" {
                scores[.metabolic] = (scores[.metabolic] ?? 0) + 10.0
            }
        }

        // Check for medical history entities that suggest category
        for entity in entities where entity.type == .medicalHistory {
            if let condition = entity.attributes["condition"] as? String {
                if condition.contains("cancer") || condition.contains("malignancy") {
                    scores[.oncological] = (scores[.oncological] ?? 0) + 5.0
                } else if condition.contains("diabetes") {
                    scores[.metabolic] = (scores[.metabolic] ?? 0) + 3.0
                }
            }
        }

        // Find best match
        guard let best = scores.max(by: { $0.value < $1.value }) else {
            return (.neurological, 0.0)
        }

        // Normalize confidence to 0-1 range
        let normalizedConfidence = min(best.value / 20.0, 1.0)

        return (best.key, normalizedConfidence)
    }

    /// Hybrid classification: Use entity-based if available, fall back to pattern matching
    func classifyHybrid(transcript: String, entities: [ComprehensionLayer.ClinicalEntity]?) -> (type: ChiefComplaintType, confidence: Double) {
        if let entities = entities, !entities.isEmpty {
            let entityResult = classifyFromEntities(entities)

            // If entity-based classification has high confidence, use it
            if entityResult.confidence > 0.5 {
                return entityResult
            }

            // Otherwise, combine with pattern matching for robustness
            let patternResult = classify(transcript: transcript)

            // Weight entity-based higher (70/30 split)
            let combinedConfidence = (entityResult.confidence * 0.7) + (patternResult.confidence * 0.3)

            // Use entity-based type if confidence is decent, otherwise use pattern result
            return entityResult.confidence > patternResult.confidence ?
                (entityResult.type, combinedConfidence) :
                (patternResult.type, combinedConfidence)
        }

        // Fall back to pattern matching if no entities
        return classify(transcript: transcript)
    }
}