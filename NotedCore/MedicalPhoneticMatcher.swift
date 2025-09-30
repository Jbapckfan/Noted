import Foundation
import NaturalLanguage

/// Advanced phonetic matching for medical terms using Levenshtein distance and soundex algorithms
/// Dramatically improves drug name and medical term accuracy
@MainActor
class MedicalPhoneticMatcher: ObservableObject {
    static let shared = MedicalPhoneticMatcher()
    
    // MARK: - Common Medical Term Corrections
    private let medicalCorrections: [String: String] = [
        // Common misheard drug names
        "metformen": "metformin",
        "metropolol": "metoprolol",
        "atorvastatin": "atorvastatin", // correct
        "atorvastin": "atorvastatin",
        "lisinopril": "lisinopril", // correct
        "lysinopril": "lisinopril",
        "omeprazol": "omeprazole",
        "amoxicillin": "amoxicillin", // correct
        "amoxicilin": "amoxicillin",
        "gabapentin": "gabapentin", // correct
        "gabapentine": "gabapentin",
        "prednisone": "prednisone", // correct
        "prednizone": "prednisone",
        "albuterol": "albuterol", // correct
        "albuteral": "albuterol",
        "simvastatin": "simvastatin", // correct
        "simvastin": "simvastatin",
        "levothyroxine": "levothyroxine", // correct
        "levothyroxin": "levothyroxine",
        "amlodipine": "amlodipine", // correct
        "amlodipene": "amlodipine",
        
        // Medical conditions
        "diabetis": "diabetes",
        "hypertention": "hypertension",
        "pneumonia": "pneumonia", // correct
        "numonia": "pneumonia",
        "appendicitis": "appendicitis", // correct
        "appendisitis": "appendicitis",
        "arrhythmia": "arrhythmia", // correct
        "arithmia": "arrhythmia",
        "asthma": "asthma", // correct
        "asma": "asthma",
        
        // Medical procedures
        "electrocardiogram": "electrocardiogram", // correct
        "ecg": "ECG",
        "ekg": "EKG",
        "mri": "MRI",
        "cat scan": "CT scan",
        "x-ray": "X-ray",
        "xray": "X-ray",
        
        // Anatomical terms
        "appendix": "appendix", // correct
        "appendics": "appendix",
        "esophagus": "esophagus", // correct
        "esophogus": "esophagus",
        "pharynx": "pharynx", // correct
        "farinx": "pharynx"
    ]
    
    // MARK: - Drug Database (Top 200 drugs)
    private let commonDrugs = [
        "atorvastatin", "levothyroxine", "metformin", "lisinopril", "amlodipine",
        "metoprolol", "albuterol", "omeprazole", "losartan", "gabapentin",
        "hydrochlorothiazide", "sertraline", "simvastatin", "montelukast", "escitalopram",
        "azithromycin", "amoxicillin", "furosemide", "alprazolam", "pantoprazole",
        "prednisone", "fluticasone", "doxycycline", "citalopram", "pravastatin",
        "trazodone", "insulin", "glargine", "fluoxetine", "tamsulosin",
        "meloxicam", "clopidogrel", "rosuvastatin", "bupropion", "carvedilol",
        "warfarin", "tramadol", "duloxetine", "propranolol", "venlafaxine",
        "spironolactone", "glipizide", "buspirone", "lorazepam", "zolpidem",
        "clonazepam", "latanoprost", "finasteride", "ranitidine", "diltiazem",
        "oxycodone", "hydrocodone", "acetaminophen", "ibuprofen", "cyclobenzaprine",
        "methylphenidate", "valsartan", "pregabalin", "atenolol", "diazepam",
        "oxybutynin", "quinapril", "amitriptyline", "naproxen", "loratadine",
        "potassium", "chloride", "paroxetine", "bisoprolol", "clonidine",
        "quetiapine", "celecoxib", "mirtazapine", "folic", "acid",
        "donepezil", "nifedipine", "hydralazine", "verapamil", "famotidine"
    ]
    
    // MARK: - Medical Specialties Vocabulary
    private let specialtyTerms: [String: [String]] = [
        "cardiology": [
            "myocardial", "infarction", "angina", "stenosis", "arrhythmia",
            "bradycardia", "tachycardia", "fibrillation", "ejection", "fraction",
            "angioplasty", "stent", "bypass", "catheterization", "echocardiogram"
        ],
        "pulmonology": [
            "dyspnea", "hypoxia", "bronchitis", "emphysema", "pneumothorax",
            "pleural", "effusion", "bronchodilator", "spirometry", "asthma",
            "COPD", "pulmonary", "embolism", "ventilation", "perfusion"
        ],
        "gastroenterology": [
            "dysphagia", "GERD", "peptic", "ulcer", "cirrhosis",
            "hepatitis", "pancreatitis", "colitis", "Crohn's", "endoscopy",
            "colonoscopy", "biopsy", "polyp", "diverticulitis", "gastroparesis"
        ],
        "neurology": [
            "seizure", "epilepsy", "migraine", "stroke", "TIA",
            "neuropathy", "paresthesia", "tremor", "ataxia", "dyskinesia",
            "dementia", "Alzheimer's", "Parkinson's", "multiple", "sclerosis"
        ]
    ]
    
    init() {}
    
    func correctMedicalTerms(_ text: String) -> String {
        return correctMedicalTerm(text).corrected
    }
    
    // MARK: - Main Correction Function
    
    func correctMedicalTerm(_ text: String) -> (corrected: String, confidence: Float, suggestions: [String]) {
        let words = text.lowercased().split(separator: " ").map(String.init)
        var correctedWords: [String] = []
        var overallConfidence: Float = 1.0
        var allSuggestions: [String] = []
        
        for word in words {
            // Check direct corrections first
            if let correction = medicalCorrections[word] {
                correctedWords.append(correction)
                overallConfidence *= 0.95 // Slight confidence reduction for correction
                continue
            }
            
            // Check if it's a known drug
            if let drugMatch = findBestDrugMatch(word) {
                correctedWords.append(drugMatch.term)
                overallConfidence *= drugMatch.confidence
                if drugMatch.confidence < 0.9 {
                    allSuggestions.append(contentsOf: drugMatch.alternatives)
                }
                continue
            }
            
            // Check specialty terms
            if let specialtyMatch = findSpecialtyTerm(word) {
                correctedWords.append(specialtyMatch.term)
                overallConfidence *= specialtyMatch.confidence
                continue
            }
            
            // No correction needed
            correctedWords.append(word)
        }
        
        return (correctedWords.joined(separator: " "), overallConfidence, allSuggestions)
    }
    
    // MARK: - Levenshtein Distance
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Soundex Algorithm
    
    private func soundex(_ word: String) -> String {
        let word = word.uppercased()
        guard !word.isEmpty else { return "" }
        
        var soundex = String(word.first!)
        let consonantMap: [Character: String] = [
            "B": "1", "F": "1", "P": "1", "V": "1",
            "C": "2", "G": "2", "J": "2", "K": "2", "Q": "2", "S": "2", "X": "2", "Z": "2",
            "D": "3", "T": "3",
            "L": "4",
            "M": "5", "N": "5",
            "R": "6"
        ]
        
        var previousCode = consonantMap[word.first!] ?? "0"
        
        for char in word.dropFirst() {
            if let code = consonantMap[char] {
                if code != previousCode {
                    soundex += code
                    previousCode = code
                }
            } else if "AEIOUYHW".contains(char) {
                previousCode = "0"
            }
            
            if soundex.count >= 4 { break }
        }
        
        while soundex.count < 4 {
            soundex += "0"
        }
        
        return String(soundex.prefix(4))
    }
    
    // MARK: - Drug Matching
    
    private func findBestDrugMatch(_ word: String) -> (term: String, confidence: Float, alternatives: [String])? {
        var candidates: [(drug: String, distance: Int, soundexMatch: Bool)] = []
        
        let wordSoundex = soundex(word)
        
        for drug in commonDrugs {
            let distance = levenshteinDistance(word, drug)
            
            // Only consider if reasonably close
            if distance <= 3 {
                let soundexMatch = soundex(drug) == wordSoundex
                candidates.append((drug, distance, soundexMatch))
            }
        }
        
        // Sort by distance, prefer soundex matches
        candidates.sort { 
            if $0.soundexMatch != $1.soundexMatch {
                return $0.soundexMatch
            }
            return $0.distance < $1.distance
        }
        
        guard let best = candidates.first else { return nil }
        
        // Calculate confidence
        let confidence: Float = {
            if best.distance == 0 { return 1.0 }
            if best.distance == 1 && best.soundexMatch { return 0.95 }
            if best.distance == 1 { return 0.9 }
            if best.distance == 2 && best.soundexMatch { return 0.85 }
            if best.distance == 2 { return 0.75 }
            return 0.6
        }()
        
        // Get alternatives
        let alternatives = candidates.prefix(3).map { $0.drug }
        
        return (best.drug, confidence, Array(alternatives))
    }
    
    // MARK: - Specialty Term Matching
    
    private func findSpecialtyTerm(_ word: String) -> (term: String, confidence: Float)? {
        for (_, terms) in specialtyTerms {
            for term in terms {
                let distance = levenshteinDistance(word, term)
                if distance <= 2 {
                    let confidence: Float = distance == 0 ? 1.0 : (distance == 1 ? 0.9 : 0.75)
                    return (term, confidence)
                }
            }
        }
        return nil
    }
    
    // MARK: - Context-Aware Correction
    
    func correctWithContext(_ text: String, previousContext: String? = nil) -> String {
        // Use context to improve accuracy
        var correctedText = text
        
        // Common medical phrase patterns
        let patterns: [(pattern: String, replacement: String)] = [
            ("blood pressure of (\\d+) over (\\d+)", "blood pressure of $1/$2"),
            ("temp of (\\d+\\.?\\d*)", "temperature of $1°F"),
            ("sat of (\\d+)", "oxygen saturation of $1%"),
            ("pulse of (\\d+)", "pulse of $1 bpm"),
            ("respiration of (\\d+)", "respiratory rate of $1"),
            ("pain (\\d+) out of 10", "pain level $1/10"),
            ("milligrams", "mg"),
            ("milliliters", "mL"),
            ("twice a day", "BID"),
            ("three times a day", "TID"),
            ("four times a day", "QID"),
            ("as needed", "PRN"),
            ("by mouth", "PO"),
            ("intravenous", "IV"),
            ("intramuscular", "IM"),
            ("subcutaneous", "SubQ")
        ]
        
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                correctedText = regex.stringByReplacingMatches(
                    in: correctedText,
                    options: [],
                    range: NSRange(correctedText.startIndex..., in: correctedText),
                    withTemplate: replacement
                )
            }
        }
        
        // Apply term corrections
        let (corrected, _, _) = correctMedicalTerm(correctedText)
        
        return corrected
    }
    
    // MARK: - Confidence Scoring
    
    func scoreTranscriptionConfidence(_ text: String) -> Float {
        let words = text.lowercased().split(separator: " ").map(String.init)
        var totalConfidence: Float = 0
        var medicalTermCount = 0
        
        for word in words {
            // Check if it's a medical term
            if medicalCorrections.keys.contains(word) ||
               commonDrugs.contains(word) ||
               specialtyTerms.values.flatMap({ $0 }).contains(word) {
                medicalTermCount += 1
                
                // High confidence for correctly spelled medical terms
                totalConfidence += 1.0
            }
        }
        
        // Base confidence
        let baseConfidence: Float = 0.7
        
        // Boost for medical terms
        let medicalBoost = Float(medicalTermCount) * 0.05
        
        return min(1.0, baseConfidence + medicalBoost)
    }
}