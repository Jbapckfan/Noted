import Foundation

/// Enhanced medical accuracy for transcription and summarization
@MainActor
final class MedicalAccuracyEnhancer: ObservableObject {
    static let shared = MedicalAccuracyEnhancer()
    
    // MARK: - Drug Name Database
    private let commonDrugs: [String: [String]] = [
        // Drug: [Common misspellings/mishearings]
        "metoprolol": ["metoprolol", "metropolol", "metoprolo"],
        "lisinopril": ["lisinopril", "lysinopril", "lisonopril"],
        "atorvastatin": ["atorvastatin", "atorvastin", "lipitor"],
        "metformin": ["metformin", "metformen", "glucophage"],
        "amlodipine": ["amlodipine", "amlodapine", "norvasc"],
        "omeprazole": ["omeprazole", "omeprazol", "prilosec"],
        "gabapentin": ["gabapentin", "gabapenten", "neurontin"],
        "levothyroxine": ["levothyroxine", "synthroid", "levothyroxin"],
        "hydrochlorothiazide": ["hydrochlorothiazide", "HCTZ", "hydrochlorothiazid"],
        "furosemide": ["furosemide", "lasix", "furosemid"],
        "prednisone": ["prednisone", "prednizone", "prednison"],
        "albuterol": ["albuterol", "proventil", "ventolin"],
        "aspirin": ["aspirin", "ASA", "asprin"],
        "clopidogrel": ["clopidogrel", "plavix", "clopidogrel"],
        "warfarin": ["warfarin", "coumadin", "warferin"]
    ]
    
    // MARK: - Dosage Pattern Recognition
    private let dosagePatterns = [
        // Pattern: Standardized format
        "([0-9]+) milligrams?": "$1mg",
        "([0-9]+) mg": "$1mg",
        "([0-9]+) micrograms?": "$1mcg",
        "([0-9]+) units?": "$1 units",
        "twice a day": "BID",
        "twice daily": "BID",
        "three times a day": "TID",
        "three times daily": "TID",
        "four times a day": "QID",
        "four times daily": "QID",
        "once a day": "daily",
        "once daily": "daily",
        "as needed": "PRN",
        "by mouth": "PO",
        "intravenous": "IV",
        "subcutaneous": "SubQ"
    ]
    
    // MARK: - Anatomical Terms
    private let anatomicalConfusions = [
        // Common confusions
        ["humeral", "humoral"],
        ["ileum", "ilium"],
        ["peroneal", "perineal"],
        ["vesical", "vesicle"],
        ["trachea", "tracheal"],
        ["thyroid", "thyroid"],
        ["carotid", "parotid"],
        ["hepatic", "herpetic"],
        ["gastric", "gastro"],
        ["renal", "adrenal"],
        ["femoral", "femur"],
        ["radial", "radius"],
        ["ulnar", "ulna"],
        ["tibial", "tibia"],
        ["fibular", "fibula"]
    ]
    
    // MARK: - Critical Negatives Detection
    private let criticalNegatives = [
        "denies": ["chest pain", "shortness of breath", "fever", "nausea", "vomiting"],
        "no": ["chest pain", "SOB", "fever", "N/V", "diarrhea", "bleeding"],
        "negative for": ["MI", "PE", "DVT", "infection", "malignancy"],
        "without": ["complications", "difficulty", "problems", "issues"]
    ]
    
    // MARK: - Temporal Expression Parser
    func parseTemporalExpression(_ text: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            ("for the past ([0-9]+) hours?", "x $1 hours"),
            ("for the past ([0-9]+) days?", "x $1 days"),
            ("for the past ([0-9]+) weeks?", "x $1 weeks"),
            ("since yesterday", "x 1 day"),
            ("since this morning", "since AM"),
            ("since last night", "since last PM"),
            ("([0-9]+) hours? ago", "$1 hours PTA"),
            ("([0-9]+) days? ago", "$1 days PTA"),
            ("started ([0-9]+) hours? ago", "onset $1 hours ago"),
            ("began ([0-9]+) days? ago", "onset $1 days ago")
        ]
        
        var result = text
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        return result
    }
    
    // MARK: - Drug Name Correction
    func correctDrugName(_ text: String) -> String {
        var corrected = text
        let words = text.lowercased().components(separatedBy: .whitespaces)
        
        for word in words {
            for (drug, variants) in commonDrugs {
                if variants.contains(word) {
                    corrected = corrected.replacingOccurrences(
                        of: word,
                        with: drug,
                        options: .caseInsensitive
                    )
                    break
                }
            }
        }
        
        return corrected
    }
    
    // MARK: - Dosage Standardization
    func standardizeDosages(_ text: String) -> String {
        var result = text
        
        for (pattern, replacement) in dosagePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        
        return result
    }
    
    // MARK: - Anatomical Term Validation
    func validateAnatomicalTerms(_ text: String, context: String) -> String {
        var corrected = text
        
        for confusionSet in anatomicalConfusions {
            for term in confusionSet {
                if text.lowercased().contains(term) {
                    // Use context to determine correct term
                    if context.contains("bone") || context.contains("fracture") {
                        // Likely skeletal
                        if term == "humoral" {
                            corrected = corrected.replacingOccurrences(of: term, with: "humeral")
                        }
                    } else if context.contains("immune") || context.contains("antibody") {
                        // Likely humoral immunity
                        if term == "humeral" {
                            corrected = corrected.replacingOccurrences(of: term, with: "humoral")
                        }
                    }
                }
            }
        }
        
        return corrected
    }
    
    // MARK: - Extract Pertinent Negatives
    func extractPertinentNegatives(_ text: String) -> [String] {
        var negatives: [String] = []
        let lowercased = text.lowercased()
        
        for (negativeWord, symptoms) in criticalNegatives {
            if lowercased.contains(negativeWord) {
                // Find which symptoms are denied
                for symptom in symptoms {
                    if lowercased.contains(negativeWord + " " + symptom.lowercased()) {
                        negatives.append("Denies \(symptom)")
                    }
                }
            }
        }
        
        // Also check for "no" patterns
        let noPattern = "no ([a-z]+)"
        if let regex = try? NSRegularExpression(pattern: noPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range(at: 1), in: text) {
                    let symptom = String(text[range])
                    negatives.append("No \(symptom)")
                }
            }
        }
        
        return negatives
    }
    
    // MARK: - Vital Signs Standardization
    func standardizeVitals(_ text: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            ("blood pressure (is |of )?([0-9]+) over ([0-9]+)", "BP $2/$3"),
            ("blood pressure (is |of )?([0-9]+)/([0-9]+)", "BP $2/$3"),
            ("heart rate (is |of )?([0-9]+)", "HR $2"),
            ("pulse (is |of )?([0-9]+)", "HR $2"),
            ("temperature (is |of )?([0-9.]+)", "T $2°F"),
            ("temp (is |of )?([0-9.]+)", "T $2°F"),
            ("respiratory rate (is |of )?([0-9]+)", "RR $2"),
            ("respirations (is |of )?([0-9]+)", "RR $2"),
            ("oxygen saturation (is |of )?([0-9]+)%?", "SpO2 $2%"),
            ("O2 sat (is |of )?([0-9]+)%?", "SpO2 $2%"),
            ("satting ([0-9]+)%?", "SpO2 $1%")
        ]
        
        var result = text
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        
        return result
    }
    
    // MARK: - Lab Value Recognition
    func standardizeLabValues(_ text: String) -> String {
        let patterns: [(pattern: String, replacement: String)] = [
            ("white count (of |is )?([0-9.]+)", "WBC $2"),
            ("hemoglobin (of |is )?([0-9.]+)", "Hgb $2"),
            ("hematocrit (of |is )?([0-9.]+)", "Hct $2"),
            ("platelets (of |is )?([0-9]+)", "Plt $2"),
            ("sodium (of |is )?([0-9]+)", "Na $2"),
            ("potassium (of |is )?([0-9.]+)", "K $2"),
            ("chloride (of |is )?([0-9]+)", "Cl $2"),
            ("bicarbonate (of |is )?([0-9]+)", "HCO3 $2"),
            ("glucose (of |is )?([0-9]+)", "Glucose $2"),
            ("creatinine (of |is )?([0-9.]+)", "Cr $2"),
            ("BUN (of |is )?([0-9]+)", "BUN $2"),
            ("troponin (of |is )?([0-9.]+)", "Troponin $2"),
            ("INR (of |is )?([0-9.]+)", "INR $2")
        ]
        
        var result = text
        for (pattern, replacement) in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: replacement
                )
            }
        }
        
        return result
    }
    
    // MARK: - Complete Enhancement Pipeline
    func enhanceTranscription(_ text: String) -> String {
        var enhanced = text
        
        // 1. Correct drug names
        enhanced = correctDrugName(enhanced)
        
        // 2. Standardize dosages
        enhanced = standardizeDosages(enhanced)
        
        // 3. Standardize vital signs
        enhanced = standardizeVitals(enhanced)
        
        // 4. Standardize lab values
        enhanced = standardizeLabValues(enhanced)
        
        // 5. Parse temporal expressions
        enhanced = parseTemporalExpression(enhanced)
        
        // 6. Validate anatomical terms (with context)
        enhanced = validateAnatomicalTerms(enhanced, context: text)
        
        return enhanced
    }
    
    // MARK: - Enhanced ED Note Generation
    func enhanceEDNoteGeneration(from text: String) -> [String: Any] {
        let enhanced = enhanceTranscription(text)
        let negatives = extractPertinentNegatives(enhanced)
        
        return [
            "enhancedText": enhanced,
            "pertinentNegatives": negatives,
            "hasCriticalFindings": detectCriticalFindings(enhanced)
        ]
    }
    
    private func detectCriticalFindings(_ text: String) -> Bool {
        let criticalTerms = [
            "chest pain", "shortness of breath", "altered mental status",
            "hypotension", "tachycardia", "hypoxia", "fever",
            "severe pain", "acute abdomen", "trauma", "unresponsive"
        ]
        
        let lowercased = text.lowercased()
        return criticalTerms.contains { lowercased.contains($0) }
    }
}

// MARK: - Integration Extension
extension AppleIntelligenceSummarizer {
    func generateEnhancedSummary(from transcription: String, noteType: String) async -> String {
        // First enhance the transcription
        let enhancer = MedicalAccuracyEnhancer.shared
        let enhancedData = enhancer.enhanceEDNoteGeneration(from: transcription)
        let enhancedText = enhancedData["enhancedText"] as? String ?? transcription
        
        // Generate summary with enhanced text
        // Generate summary using AppleIntelligenceSummarizer
        let summarizer = AppleIntelligenceSummarizer.shared
        await summarizer.processTranscription(enhancedText, noteType: NoteType(rawValue: noteType) ?? .soap)
        var summary = await MainActor.run { summarizer.medicalNote }
        
        // Add pertinent negatives if ED note
        if noteType == "ED", 
           let negatives = enhancedData["pertinentNegatives"] as? [String],
           !negatives.isEmpty {
            
            // Insert pertinent negatives into ROS section
            let rosMarker = "**ROS:**"
            if let rosRange = summary.range(of: rosMarker) {
                let insertPoint = summary.index(rosRange.upperBound, offsetBy: 1)
                let negativesText = negatives.map { "• \($0)" }.joined(separator: "\n")
                summary.insert(contentsOf: "\n" + negativesText, at: insertPoint)
            }
        }
        
        return summary
    }
}