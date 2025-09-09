import Foundation
import NaturalLanguage
import Speech

// Medical vocabulary enhancement for transcription accuracy
@MainActor
class MedicalVocabularyEnhancer: ObservableObject {
    static let shared = MedicalVocabularyEnhancer()
    
    // MARK: - Medical Lexicon
    let medicalTerms: Set<String> = [
        // Common conditions
        "hypertension", "diabetes", "hyperlipidemia", "atrial fibrillation",
        "coronary artery disease", "chronic obstructive pulmonary disease",
        "gastroesophageal reflux", "pneumonia", "urinary tract infection",
        "myocardial infarction", "cerebrovascular accident", "pulmonary embolism",
        "deep vein thrombosis", "sepsis", "appendicitis", "cholecystitis",
        
        // Medications (top 100)
        "lisinopril", "metformin", "atorvastatin", "amlodipine", "metoprolol",
        "omeprazole", "simvastatin", "losartan", "albuterol", "gabapentin",
        "hydrochlorothiazide", "sertraline", "levothyroxine", "azithromycin",
        "amoxicillin", "prednisone", "ibuprofen", "acetaminophen", "aspirin",
        "warfarin", "furosemide", "pantoprazole", "escitalopram", "insulin",
        "clopidogrel", "tamsulosin", "meloxicam", "citalopram", "pravastatin",
        "trazodone", "carvedilol", "duloxetine", "lisinopril", "rosuvastatin",
        
        // Anatomical terms
        "anterior", "posterior", "lateral", "medial", "superior", "inferior",
        "proximal", "distal", "ventral", "dorsal", "cranial", "caudal",
        "supine", "prone", "ipsilateral", "contralateral", "bilateral",
        
        // Symptoms
        "dyspnea", "orthopnea", "paroxysmal nocturnal dyspnea", "angina",
        "claudication", "syncope", "presyncope", "vertigo", "diaphoresis",
        "nausea", "emesis", "hematemesis", "melena", "hematochezia",
        "dysuria", "hematuria", "polyuria", "oliguria", "anuria",
        
        // Physical exam
        "auscultation", "palpation", "percussion", "inspection",
        "tachycardia", "bradycardia", "tachypnea", "bradypnea",
        "hypertensive", "hypotensive", "febrile", "afebrile",
        "erythema", "edema", "cyanosis", "pallor", "jaundice",
        
        // Labs
        "hemoglobin", "hematocrit", "leukocyte", "platelet", "neutrophil",
        "lymphocyte", "eosinophil", "basophil", "monocyte",
        "creatinine", "blood urea nitrogen", "glomerular filtration rate",
        "alanine aminotransferase", "aspartate aminotransferase",
        "alkaline phosphatase", "bilirubin", "albumin", "prothrombin",
        "partial thromboplastin", "international normalized ratio",
        "troponin", "brain natriuretic peptide", "d-dimer",
        "C-reactive protein", "erythrocyte sedimentation rate"
    ]
    
    private let medicalAbbreviations: [String: String] = [
        // Common abbreviations
        "bp": "blood pressure",
        "hr": "heart rate",
        "rr": "respiratory rate",
        "o2 sat": "oxygen saturation",
        "temp": "temperature",
        "bpm": "beats per minute",
        "sob": "shortness of breath",
        "cp": "chest pain",
        "abd": "abdominal",
        "htn": "hypertension",
        "dm": "diabetes mellitus",
        "cad": "coronary artery disease",
        "chf": "congestive heart failure",
        "copd": "chronic obstructive pulmonary disease",
        "gerd": "gastroesophageal reflux disease",
        "uti": "urinary tract infection",
        "mi": "myocardial infarction",
        "cva": "cerebrovascular accident",
        "pe": "pulmonary embolism",
        "dvt": "deep vein thrombosis",
        "gi": "gastrointestinal",
        "gu": "genitourinary",
        "cv": "cardiovascular",
        "neuro": "neurological",
        "psych": "psychiatric",
        "msk": "musculoskeletal",
        "nkda": "no known drug allergies",
        "pmh": "past medical history",
        "psh": "past surgical history",
        "fh": "family history",
        "sh": "social history",
        "ros": "review of systems",
        "hpi": "history of present illness",
        "cc": "chief complaint",
        "ed": "emergency department",
        "icu": "intensive care unit",
        "or": "operating room",
        "pre op": "preoperative",
        "post op": "postoperative",
        "prn": "as needed",
        "bid": "twice daily",
        "tid": "three times daily",
        "qid": "four times daily",
        "qhs": "at bedtime",
        "po": "by mouth",
        "iv": "intravenous",
        "im": "intramuscular",
        "subq": "subcutaneous",
        "mg": "milligrams",
        "mcg": "micrograms",
        "ml": "milliliters",
        "l": "liters"
    ]
    
    // Phonetic similarities for common misheard medical terms
    private let phoneticCorrections: [(pattern: String, correction: String, confidence: Float)] = [
        // Medications often misheard
        ("listen april", "lisinopril", 0.9),
        ("met for men", "metformin", 0.9),
        ("a torvastatin", "atorvastatin", 0.9),
        ("i'm low to pine", "amlodipine", 0.85),
        ("metro lol", "metoprolol", 0.85),
        ("oh my prazole", "omeprazole", 0.85),
        ("as it throw my sin", "azithromycin", 0.8),
        ("a moxicillin", "amoxicillin", 0.9),
        ("I brew profin", "ibuprofen", 0.85),
        ("a seat of minophen", "acetaminophen", 0.85),
        
        // Conditions often misheard
        ("high pretension", "hypertension", 0.9),
        ("die of betes", "diabetes", 0.85),
        ("new monia", "pneumonia", 0.9),
        ("a pen the site is", "appendicitis", 0.85),
        ("college cystitis", "cholecystitis", 0.85),
        ("pulmonary and bolism", "pulmonary embolism", 0.85),
        
        // Anatomy often misheard
        ("app domain", "abdomen", 0.85),
        ("by lateral", "bilateral", 0.9),
        ("aproximal", "proximal", 0.85),
        
        // Symptoms often misheard
        ("disney uh", "dyspnea", 0.85),
        ("or thought knee uh", "orthopnea", 0.8),
        ("sink up ee", "syncope", 0.85),
        ("die for recess", "diaphoresis", 0.8),
        ("he might emesis", "hematemesis", 0.85),
        ("dis urea", "dysuria", 0.85),
        
        // Lab values often misheard
        ("troop oh nin", "troponin", 0.9),
        ("create a mean", "creatinine", 0.85),
        ("billy ruben", "bilirubin", 0.85),
        ("pro thrombin", "prothrombin", 0.9),
        ("d die mer", "d-dimer", 0.9)
    ]
    
    // MARK: - Custom Language Model Enhancement
    func enhanceTranscriptionRequest(_ request: SFSpeechAudioBufferRecognitionRequest) {
        // Add custom vocabulary
        request.addsPunctuation = true
        request.requiresOnDeviceRecognition = false // Use server for better accuracy
        
        // Set task hint for medical context
        if #available(iOS 16.0, *) {
            request.taskHint = .dictation
        }
        
        // Add contextual strings (iOS 16+)
        // Note: customizedLanguageModel requires specific configuration
        // We'll use contextualStrings instead which is available
        
        // Add contextual strings for better recognition
        request.contextualStrings = Array(medicalTerms.prefix(100)) + Array(medicalAbbreviations.keys)
    }
    
    @available(iOS 16.0, *)
    private func createCustomLanguageModel() -> Data? {
        // Create custom language model data
        // Note: In production, this would use SFSpeechLanguageModel.Configuration
        // but that API requires specific setup and training data format
        return createMedicalLanguageModelData()
    }
    
    @available(iOS 16.0, *)
    private func createMedicalLanguageModelData() -> Data? {
        // Create language model data with medical phrase patterns
        let phrases = [
            "patient presents with chest pain",
            "history of hypertension and diabetes",
            "taking lisinopril and metformin",
            "blood pressure is elevated",
            "shortness of breath on exertion",
            "no known drug allergies",
            "review of systems is negative",
            "physical exam reveals",
            "plan to order chest x-ray",
            "will admit for observation"
        ]
        
        return phrases.joined(separator: "\n").data(using: .utf8)
    }
    
    @available(iOS 16.0, *)
    private func createMedicalVocabulary() -> [String] {
        // Return vocabulary array
        return Array(medicalTerms).sorted()
    }
    
    // MARK: - Post-Processing Correction
    func correctTranscription(_ text: String) -> (corrected: String, corrections: [Correction]) {
        var correctedText = text
        var corrections: [Correction] = []
        
        // Step 1: Fix known phonetic errors
        for (pattern, correction, confidence) in phoneticCorrections {
            let regex = try? NSRegularExpression(
                pattern: "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b",
                options: [.caseInsensitive]
            )
            
            if let matches = regex?.matches(
                in: correctedText,
                range: NSRange(correctedText.startIndex..., in: correctedText)
            ) {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: correctedText) {
                        let original = String(correctedText[range])
                        correctedText.replaceSubrange(range, with: correction)
                        
                        corrections.append(Correction(
                            original: original,
                            corrected: correction,
                            confidence: confidence,
                            type: .phonetic
                        ))
                    }
                }
            }
        }
        
        // Step 2: Expand abbreviations in context
        correctedText = expandAbbreviations(correctedText, corrections: &corrections)
        
        // Step 3: Fix medical term spelling
        correctedText = correctMedicalSpelling(correctedText, corrections: &corrections)
        
        // Step 4: Apply context-based corrections
        correctedText = applyContextualCorrections(correctedText, corrections: &corrections)
        
        return (correctedText, corrections)
    }
    
    private func expandAbbreviations(_ text: String, corrections: inout [Correction]) -> String {
        var result = text
        
        for (abbr, expanded) in medicalAbbreviations {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbr))\\b"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
                
                for match in matches.reversed() {
                    // Check context to avoid over-expansion
                    if shouldExpandAbbreviation(abbr, in: result, at: match.range) {
                        if let range = Range(match.range, in: result) {
                            result.replaceSubrange(range, with: expanded)
                            
                            corrections.append(Correction(
                                original: abbr,
                                corrected: expanded,
                                confidence: 0.8,
                                type: .abbreviation
                            ))
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func shouldExpandAbbreviation(_ abbr: String, in text: String, at range: NSRange) -> Bool {
        // Don't expand in certain contexts (e.g., vital signs section)
        let context = getContext(for: text, at: range, windowSize: 50)
        
        // Keep abbreviations in vital signs
        if context.contains("vital") || context.contains("VS:") {
            return false
        }
        
        // Keep common measurement abbreviations
        if ["mg", "ml", "mcg", "l"].contains(abbr.lowercased()) && 
           context.range(of: "\\d+", options: .regularExpression) != nil {
            return false
        }
        
        return true
    }
    
    private func correctMedicalSpelling(_ text: String, corrections: inout [Correction]) -> String {
        var result = text
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        
        for word in words {
            let cleaned = word.lowercased().trimmingCharacters(in: .punctuationCharacters)
            
            if let correction = findClosestMedicalTerm(for: cleaned) {
                if correction.similarity > 0.8 && correction.term != cleaned {
                    result = result.replacingOccurrences(
                        of: word,
                        with: word.replacingOccurrences(of: cleaned, with: correction.term)
                    )
                    
                    corrections.append(Correction(
                        original: cleaned,
                        corrected: correction.term,
                        confidence: Float(correction.similarity),
                        type: .spelling
                    ))
                }
            }
        }
        
        return result
    }
    
    private func findClosestMedicalTerm(for word: String) -> (term: String, similarity: Double)? {
        var bestMatch: (String, Double)?
        
        for term in medicalTerms {
            let similarity = calculateLevenshteinSimilarity(word, term)
            
            if similarity > 0.8 {
                if bestMatch == nil || similarity > bestMatch!.1 {
                    bestMatch = (term, similarity)
                }
            }
        }
        
        return bestMatch.map { (term: $0.0, similarity: $0.1) }
    }
    
    private func calculateLevenshteinSimilarity(_ str1: String, _ str2: String) -> Double {
        let distance = levenshteinDistance(str1, str2)
        let maxLength = max(str1.count, str2.count)
        return maxLength > 0 ? 1.0 - (Double(distance) / Double(maxLength)) : 0.0
    }
    
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let s1 = Array(str1)
        let s2 = Array(str2)
        
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count {
            matrix[i][0] = i
        }
        for j in 0...s2.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                let cost = s1[i-1] == s2[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1.count][s2.count]
    }
    
    private func applyContextualCorrections(_ text: String, corrections: inout [Correction]) -> String {
        var result = text
        
        // Context-based rules
        let contextRules: [(context: String, wrong: String, right: String, confidence: Float)] = [
            ("blood pressure", "hire", "higher", 0.9),
            ("blood pressure", "loan", "low", 0.9),
            ("heart rate", "regular", "regular", 0.95),
            ("heart rate", "a regular", "irregular", 0.9),
            ("temperature", "a febrile", "afebrile", 0.9),
            ("pain", "attend", "10", 0.85),
            ("scale", "attend", "10", 0.9),
            ("allergic to", "pen of cillin", "penicillin", 0.95),
            ("history of", "my a cardial", "myocardial", 0.9)
        ]
        
        for (context, wrong, right, confidence) in contextRules {
            if result.lowercased().contains(context) {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: wrong))\\b"
                
                if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                    let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
                    
                    for match in matches.reversed() {
                        let contextWindow = getContext(for: result, at: match.range, windowSize: 100)
                        
                        if contextWindow.lowercased().contains(context) {
                            if let range = Range(match.range, in: result) {
                                result.replaceSubrange(range, with: right)
                                
                                corrections.append(Correction(
                                    original: wrong,
                                    corrected: right,
                                    confidence: confidence,
                                    type: .contextual
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return result
    }
    
    private func getContext(for text: String, at range: NSRange, windowSize: Int) -> String {
        guard let textRange = Range(range, in: text) else { return "" }
        
        let startIndex = text.index(textRange.lowerBound, offsetBy: -windowSize, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(textRange.upperBound, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[startIndex..<endIndex])
    }
}

// MARK: - Supporting Types
struct Correction {
    let original: String
    let corrected: String
    let confidence: Float
    let type: CorrectionType
    
    enum CorrectionType {
        case phonetic
        case abbreviation
        case spelling
        case contextual
    }
}

// MARK: - Medical Phrase Templates
class MedicalPhraseTemplates {
    static let commonPhrases = [
        // Chief complaints
        "patient presents with",
        "complains of",
        "reports",
        "denies",
        "states that",
        
        // HPI
        "onset was",
        "started approximately",
        "has been ongoing for",
        "associated with",
        "aggravated by",
        "alleviated by",
        "rates the pain",
        "describes the pain as",
        
        // Physical exam
        "on examination",
        "physical exam reveals",
        "vital signs show",
        "appears comfortable",
        "in no acute distress",
        "alert and oriented",
        
        // Assessment/Plan
        "differential diagnosis includes",
        "plan to obtain",
        "will order",
        "recommend",
        "follow up with",
        "return if",
        "discharge home with"
    ]
    
    static func createPhraseBooster() -> [String: Float] {
        var booster: [String: Float] = [:]
        
        for phrase in commonPhrases {
            booster[phrase] = 1.5 // Boost confidence when these phrases detected
        }
        
        return booster
    }
}