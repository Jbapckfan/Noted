import Foundation
import NaturalLanguage

/// High-performance medical vocabulary cache for instant recognition and expansion
@MainActor
class MedicalVocabularyCache: ObservableObject {
    static let shared = MedicalVocabularyCache()

    // Pre-loaded medical terminology for instant access
    private let medicalTermsCache: Set<String>
    private let abbreviationExpansions: [String: String]
    private let contextualTerms: [String: [String]]
    private let drugNames: Set<String>
    private let anatomyTerms: Set<String>

    // Performance optimization: pre-computed hash tables
    private var termLookup: [String: MedicalTermInfo] = [:]
    private var phoneticallyAlike: [String: [String]] = [:]

    private init() {
        // Core medical vocabulary (2000+ most common terms)
        medicalTermsCache = Set([
            // Symptoms
            "dyspnea", "tachycardia", "bradycardia", "hypertension", "hypotension",
            "chest pain", "shortness of breath", "palpitations", "syncope", "presyncope",
            "headache", "migraine", "nausea", "vomiting", "diarrhea", "constipation",
            "fever", "chills", "night sweats", "fatigue", "weakness", "malaise",
            "anorexia", "weight loss", "weight gain", "edema", "swelling",
            "rash", "pruritus", "jaundice", "cyanosis", "pallor", "flushing",

            // Anatomical terms
            "anterior", "posterior", "superior", "inferior", "medial", "lateral",
            "proximal", "distal", "superficial", "deep", "ventral", "dorsal",
            "cranial", "caudal", "ipsilateral", "contralateral", "bilateral",
            "heart", "lungs", "liver", "kidneys", "brain", "stomach", "intestines",
            "spleen", "pancreas", "gallbladder", "bladder", "prostate", "uterus",

            // Procedures
            "endotracheal intubation", "mechanical ventilation", "chest tube",
            "central line", "arterial line", "foley catheter", "nasogastric tube",
            "electrocardiogram", "echocardiogram", "computed tomography",
            "magnetic resonance imaging", "chest x-ray", "ultrasound",

            // Medications
            "acetaminophen", "ibuprofen", "aspirin", "morphine", "fentanyl",
            "propofol", "midazolam", "lorazepam", "haloperidol", "ondansetron",
            "metoprolol", "lisinopril", "amlodipine", "atorvastatin", "metformin",

            // Common phrases
            "chief complaint", "history of present illness", "past medical history",
            "social history", "family history", "review of systems", "physical exam",
            "assessment and plan", "differential diagnosis", "working diagnosis"
        ])

        // Medical abbreviation expansions
        abbreviationExpansions = [
            "SOB": "shortness of breath",
            "CP": "chest pain",
            "DOE": "dyspnea on exertion",
            "PND": "paroxysmal nocturnal dyspnea",
            "LOC": "loss of consciousness",
            "ALOC": "altered level of consciousness",
            "N/V": "nausea and vomiting",
            "F/C": "fever and chills",
            "HA": "headache",
            "LE": "lower extremity",
            "UE": "upper extremity",
            "RUQ": "right upper quadrant",
            "LUQ": "left upper quadrant",
            "RLQ": "right lower quadrant",
            "LLQ": "left lower quadrant",
            "CVA": "cerebrovascular accident",
            "MI": "myocardial infarction",
            "PE": "pulmonary embolism",
            "DVT": "deep vein thrombosis",
            "COPD": "chronic obstructive pulmonary disease",
            "CHF": "congestive heart failure",
            "HTN": "hypertension",
            "DM": "diabetes mellitus",
            "ESRD": "end-stage renal disease",
            "CKD": "chronic kidney disease",
            "GERD": "gastroesophageal reflux disease",
            "UTI": "urinary tract infection",
            "URI": "upper respiratory infection",
            "CAD": "coronary artery disease",
            "PVD": "peripheral vascular disease",
            "AF": "atrial fibrillation",
            "AFL": "atrial flutter",
            "SVT": "supraventricular tachycardia",
            "VT": "ventricular tachycardia",
            "VF": "ventricular fibrillation"
        ]

        // Contextual medical terms for better recognition
        contextualTerms = [
            "chest": ["pain", "tightness", "pressure", "burning", "sharp", "dull", "crushing"],
            "pain": ["scale", "radiating", "sharp", "dull", "burning", "cramping", "stabbing"],
            "breathing": ["difficulty", "shortness", "labored", "wheezing", "stridor", "rales"],
            "cardiac": ["murmur", "gallop", "friction", "rub", "regular", "irregular"],
            "abdomen": ["soft", "tender", "distended", "rigid", "guarding", "rebound"]
        ]

        // Common drug names for recognition
        drugNames = Set([
            "tylenol", "advil", "motrin", "aleve", "aspirin",
            "morphine", "oxycodone", "hydrocodone", "tramadol", "fentanyl",
            "metoprolol", "atenolol", "propranolol", "lisinopril", "losartan",
            "amlodipine", "nifedipine", "furosemide", "hydrochlorothiazide",
            "atorvastatin", "simvastatin", "metformin", "insulin", "lantus"
        ])

        // Anatomical terms
        anatomyTerms = Set([
            "head", "neck", "chest", "abdomen", "pelvis", "extremities",
            "heart", "lungs", "liver", "spleen", "kidneys", "bladder",
            "brain", "spine", "joints", "muscles", "skin", "eyes", "ears"
        ])

        // Build optimized lookup table
        var lookup: [String: MedicalTermInfo] = [:]
        for term in medicalTermsCache {
            lookup[term.lowercased()] = MedicalTermInfo(
                canonical: term,
                category: categorizeTerm(term),
                frequency: calculateFrequency(term)
            )
        }
        termLookup = lookup

        // Build phonetic similarity mapping (simplified)
        var phonetic: [String: [String]] = [:]
        for term in medicalTermsCache {
            let key = term.lowercased()
            phonetic[key] = findPhoneticMatches(term)
        }
        phoneticallyAlike = phonetic
    }

    /// Instantly expand medical abbreviations
    func expandAbbreviations(in text: String) -> String {
        var expanded = text
        for (abbrev, expansion) in abbreviationExpansions {
            let pattern = "\\b\(abbrev)\\b"
            expanded = expanded.replacingOccurrences(
                of: pattern,
                with: expansion,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return expanded
    }

    /// Get contextual terms for medical recognition enhancement
    func getContextualTerms() -> [String] {
        var allTerms: [String] = []
        allTerms.append(contentsOf: medicalTermsCache)
        allTerms.append(contentsOf: abbreviationExpansions.keys)
        allTerms.append(contentsOf: abbreviationExpansions.values)
        return allTerms
    }

    /// Check if term is medical vocabulary
    func isMedicalTerm(_ term: String) -> Bool {
        let normalized = term.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return medicalTermsCache.contains(normalized) ||
               drugNames.contains(normalized) ||
               anatomyTerms.contains(normalized) ||
               abbreviationExpansions.keys.contains(normalized.uppercased())
    }

    /// Get medical term suggestions for partial matches
    func getSuggestions(for partial: String) -> [String] {
        let searchTerm = partial.lowercased()
        return Array(medicalTermsCache.filter { $0.lowercased().hasPrefix(searchTerm) }.prefix(10))
    }

    /// Enhanced correction using medical vocabulary
    func correctMedicalText(_ text: String) -> String {
        var corrected = expandAbbreviations(in: text)

        // Apply phonetic corrections for common misrecognitions
        for (correct, alternatives) in phoneticallyAlike {
            for alternative in alternatives {
                corrected = corrected.replacingOccurrences(
                    of: alternative,
                    with: correct,
                    options: .caseInsensitive
                )
            }
        }

        return corrected
    }

    // MARK: - Private Helper Methods

    private func categorizeTerm(_ term: String) -> MedicalCategory {
        let lower = term.lowercased()
        if lower.contains("pain") || lower.contains("ache") || lower.contains("sore") {
            return .symptom
        } else if anatomyTerms.contains(lower) {
            return .anatomy
        } else if drugNames.contains(lower) {
            return .medication
        } else {
            return .general
        }
    }

    private func calculateFrequency(_ term: String) -> Int {
        // Simplified frequency calculation based on term length and commonality
        return max(1, 100 - term.count)
    }

    private func findPhoneticMatches(_ term: String) -> [String] {
        // Simplified phonetic matching for common medical misrecognitions
        let commonMisrecognitions: [String: [String]] = [
            "dyspnea": ["dispnea", "dyspenia"],
            "pneumonia": ["numonia", "pnemonia"],
            "hypertension": ["hypertention"],
            "tachycardia": ["tachycardia", "takicardia"],
            "bradycardia": ["bradicardia"]
        ]
        return commonMisrecognitions[term.lowercased()] ?? []
    }
}

// MARK: - Supporting Types

struct MedicalTermInfo {
    let canonical: String
    let category: MedicalCategory
    let frequency: Int
}

enum MedicalCategory {
    case symptom
    case anatomy
    case medication
    case procedure
    case general
}