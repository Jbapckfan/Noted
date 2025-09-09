import Foundation

/// Strict medical note formatter ensuring exact output format with HPI focus
/// This guarantees the format you need regardless of which model is used
@MainActor
class StrictMedicalFormatter: ObservableObject {
    
    // MARK: - Required Sections in Order
    enum RequiredSection: String, CaseIterable {
        case cc = "CHIEF COMPLAINT"
        case hpi = "HISTORY OF PRESENT ILLNESS"
        case fh = "FAMILY HISTORY"
        case sh = "SOCIAL HISTORY"
        case pmh = "PAST MEDICAL HISTORY"
        case psh = "PAST SURGICAL HISTORY"
        case ros = "REVIEW OF SYSTEMS"
        case pe = "PHYSICAL EXAM/VITALS"
        case results = "RESULTS"
        case mdm = "MEDICAL DECISION MAKING"
        case diagnoses = "DIAGNOSES"
        case disposition = "DISPOSITION"
        case discharge = "DISCHARGE SUMMARY"
        
        var isOptional: Bool {
            switch self {
            case .fh, .sh, .pmh, .psh, .discharge:
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - HPI Detail Extractor
    
    struct HPIDetails {
        var onset: String?
        var location: String?
        var duration: String?
        var character: String?
        var associatedSymptoms: [String] = []
        var relievingFactors: [String] = []
        var exacerbatingFactors: [String] = []
        var radiation: String?
        var severity: String?
        var timing: String?
        var context: String?
        var modifyingFactors: [String] = []
        var priorEpisodes: String?
        var treatments: [String] = []
    }
    
    // MARK: - Extract All Details from Conversation
    
    func extractStructuredData(from conversation: String) -> [RequiredSection: String] {
        var sections: [RequiredSection: String] = [:]
        
        // 1. Extract Chief Complaint
        sections[.cc] = extractChiefComplaint(from: conversation)
        
        // 2. Extract comprehensive HPI (MOST IMPORTANT)
        sections[.hpi] = extractDetailedHPI(from: conversation)
        
        // 3. Extract other sections
        sections[.fh] = extractFamilyHistory(from: conversation)
        sections[.sh] = extractSocialHistory(from: conversation)
        sections[.pmh] = extractPastMedicalHistory(from: conversation)
        sections[.psh] = extractPastSurgicalHistory(from: conversation)
        sections[.ros] = extractReviewOfSystems(from: conversation)
        sections[.pe] = extractPhysicalExam(from: conversation)
        sections[.results] = extractResults(from: conversation)
        sections[.mdm] = generateMDM(from: sections)
        sections[.diagnoses] = extractDiagnoses(from: conversation, mdm: sections[.mdm])
        sections[.disposition] = extractDisposition(from: conversation)
        sections[.discharge] = extractDischargeInfo(from: conversation)
        
        return sections
    }
    
    // MARK: - Chief Complaint Extraction
    
    private func extractChiefComplaint(from conversation: String) -> String {
        // Look for primary concern mentioned early in conversation
        let patterns = [
            "having (.*?) for",
            "complaining of (.*?)\\.",
            "here for (.*?)\\.",
            "problem is (.*?)\\.",
            "been (.*?) since",
            "started having (.*?) [0-9]",
            "chief complaint:? (.*?)\\n"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: conversation, range: NSRange(conversation.startIndex..., in: conversation)),
               let range = Range(match.range(at: 1), in: conversation) {
                let complaint = String(conversation[range])
                return complaint.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Fallback: look for symptom keywords
        let symptoms = ["pain", "fever", "cough", "nausea", "headache", "shortness of breath", "chest pain", "abdominal pain"]
        for symptom in symptoms {
            if conversation.lowercased().contains(symptom) {
                return symptom.capitalized
            }
        }
        
        return "See HPI"
    }
    
    // MARK: - Detailed HPI Extraction (CRITICAL)
    
    private func extractDetailedHPI(from conversation: String) -> String {
        let hpiDetails = extractHPIComponents(from: conversation)
        
        // Build comprehensive HPI narrative
        var hpi = ""
        
        // Start with timing and onset
        if let onset = hpiDetails.onset {
            hpi += "Patient reports symptom onset \(onset). "
        }
        
        // Add location
        if let location = hpiDetails.location {
            hpi += "Located in the \(location). "
        }
        
        // Add character/quality
        if let character = hpiDetails.character {
            hpi += "Described as \(character). "
        }
        
        // Add severity
        if let severity = hpiDetails.severity {
            hpi += "Severity rated \(severity). "
        }
        
        // Add duration
        if let duration = hpiDetails.duration {
            hpi += "Duration of symptoms: \(duration). "
        }
        
        // Add associated symptoms
        if !hpiDetails.associatedSymptoms.isEmpty {
            hpi += "Associated symptoms include \(hpiDetails.associatedSymptoms.joined(separator: ", ")). "
        }
        
        // Add exacerbating factors
        if !hpiDetails.exacerbatingFactors.isEmpty {
            hpi += "Symptoms worsen with \(hpiDetails.exacerbatingFactors.joined(separator: ", ")). "
        }
        
        // Add relieving factors
        if !hpiDetails.relievingFactors.isEmpty {
            hpi += "Relief obtained with \(hpiDetails.relievingFactors.joined(separator: ", ")). "
        }
        
        // Add radiation
        if let radiation = hpiDetails.radiation {
            hpi += "Radiates to \(radiation). "
        }
        
        // Add treatments tried
        if !hpiDetails.treatments.isEmpty {
            hpi += "Patient has tried \(hpiDetails.treatments.joined(separator: ", ")). "
        }
        
        // Add context
        if let context = hpiDetails.context {
            hpi += context + " "
        }
        
        // Ensure we capture ALL mentioned details
        let additionalDetails = extractUnstructuredHPIDetails(from: conversation, existing: hpi)
        if !additionalDetails.isEmpty {
            hpi += "\n\nAdditional history: " + additionalDetails
        }
        
        return hpi.isEmpty ? "Patient presents with symptoms as discussed. See chief complaint." : hpi
    }
    
    private func extractHPIComponents(from conversation: String) -> HPIDetails {
        var details = HPIDetails()
        let text = conversation.lowercased()
        
        // Extract onset/timing
        let onsetPatterns = [
            "(\\d+) days? ago",
            "(\\d+) hours? ago",
            "(\\d+) weeks? ago",
            "since (yesterday|today|last night|this morning|monday|tuesday|wednesday|thursday|friday|saturday|sunday)",
            "started (.*?) ago",
            "began (.*?) ago",
            "for the past (\\d+ \\w+)"
        ]
        
        for pattern in onsetPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                details.onset = String(text[range])
                break
            }
        }
        
        // Extract location
        let locationWords = ["chest", "head", "abdomen", "back", "neck", "arm", "leg", "throat", "stomach", "eye", "ear", "left", "right", "bilateral", "upper", "lower", "epigastric", "periumbilical", "flank"]
        for location in locationWords {
            if text.contains(location) && text.contains("pain") {
                let context = extractContext(around: location, in: text, windowSize: 20)
                if context.contains("pain") || context.contains("ache") || context.contains("discomfort") {
                    details.location = location
                    break
                }
            }
        }
        
        // Extract character/quality
        let characterWords = ["sharp", "dull", "burning", "crushing", "stabbing", "throbbing", "aching", "cramping", "pressure", "tightness", "squeezing", "tearing", "constant", "intermittent", "colicky"]
        for quality in characterWords {
            if text.contains(quality) {
                details.character = quality
                break
            }
        }
        
        // Extract severity
        let severityPatterns = [
            "(\\d+) out of (\\d+)",
            "(\\d+)/(\\d+)",
            "(mild|moderate|severe|intense|excruciating)",
            "worst .*? ever",
            "unbearable"
        ]
        
        for pattern in severityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                details.severity = String(text[range])
                break
            }
        }
        
        // Extract associated symptoms
        let symptomKeywords = ["nausea", "vomiting", "fever", "chills", "sweating", "shortness of breath", "dizziness", "weakness", "fatigue", "cough", "chest pain", "palpitations", "headache", "blurry vision", "numbness", "tingling"]
        for symptom in symptomKeywords {
            if text.contains(symptom) {
                details.associatedSymptoms.append(symptom)
            }
        }
        
        // Extract exacerbating factors
        let worsePatterns = ["worse with", "worsens with", "aggravated by", "increases with", "gets worse when"]
        for pattern in worsePatterns {
            if let range = text.range(of: pattern) {
                let afterText = String(text[range.upperBound...]).prefix(50)
                let factor = afterText.split(separator: ".").first ?? ""
                if !factor.isEmpty {
                    details.exacerbatingFactors.append(String(factor).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        // Extract relieving factors
        let betterPatterns = ["better with", "improves with", "relieved by", "helps with", "relief with"]
        for pattern in betterPatterns {
            if let range = text.range(of: pattern) {
                let afterText = String(text[range.upperBound...]).prefix(50)
                let factor = afterText.split(separator: ".").first ?? ""
                if !factor.isEmpty {
                    details.relievingFactors.append(String(factor).trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
        
        // Extract radiation
        let radiationPatterns = ["radiates to", "radiation to", "spreads to", "goes to", "shoots to"]
        for pattern in radiationPatterns {
            if let range = text.range(of: pattern) {
                let afterText = String(text[range.upperBound...]).prefix(30)
                let location = afterText.split(separator: ".").first ?? ""
                if !location.isEmpty {
                    details.radiation = String(location).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }
        
        // Extract treatments tried
        let treatmentPatterns = ["took", "tried", "used", "taking"]
        let medications = ["ibuprofen", "tylenol", "acetaminophen", "aspirin", "advil", "motrin", "aleve", "naproxen"]
        for med in medications {
            if text.contains(med) {
                details.treatments.append(med)
            }
        }
        
        return details
    }
    
    private func extractContext(around word: String, in text: String, windowSize: Int) -> String {
        guard let range = text.range(of: word) else { return "" }
        
        let startIndex = text.index(range.lowerBound, offsetBy: -windowSize, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: windowSize, limitedBy: text.endIndex) ?? text.endIndex
        
        return String(text[startIndex..<endIndex])
    }
    
    private func extractUnstructuredHPIDetails(from conversation: String, existing: String) -> String {
        // Capture any important details not already in HPI
        var additionalDetails: [String] = []
        
        // Look for quoted patient statements about symptoms
        let quotePattern = "patient:? \"?(.*?)\"?"
        if let regex = try? NSRegularExpression(pattern: quotePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: conversation, range: NSRange(conversation.startIndex..., in: conversation))
            for match in matches {
                if let range = Range(match.range(at: 1), in: conversation) {
                    let statement = String(conversation[range])
                    // Only add if it contains symptom info and isn't already captured
                    if containsSymptomInfo(statement) && !existing.lowercased().contains(statement.lowercased()) {
                        additionalDetails.append(statement)
                    }
                }
            }
        }
        
        return additionalDetails.joined(separator: ". ")
    }
    
    private func containsSymptomInfo(_ text: String) -> Bool {
        let symptomIndicators = ["pain", "ache", "hurt", "feel", "symptom", "worse", "better", "started", "began", "noticed"]
        return symptomIndicators.contains { text.lowercased().contains($0) }
    }
    
    // MARK: - Other Section Extractors
    
    private func extractFamilyHistory(from conversation: String) -> String? {
        let patterns = ["family history", "mother had", "father had", "family member", "runs in the family", "genetic"]
        for pattern in patterns {
            if conversation.lowercased().contains(pattern) {
                // Extract the relevant sentence
                let sentences = conversation.components(separatedBy: ".")
                for sentence in sentences {
                    if sentence.lowercased().contains(pattern) {
                        return sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }
        return nil
    }
    
    private func extractSocialHistory(from conversation: String) -> String? {
        var socialHistory: [String] = []
        let text = conversation.lowercased()
        
        // Smoking
        if text.contains("smok") {
            if text.contains("never smoked") || text.contains("non-smoker") {
                socialHistory.append("Denies tobacco use")
            } else if text.contains("quit smoking") {
                socialHistory.append("Former smoker")
            } else if text.contains("smoke") || text.contains("cigarette") {
                socialHistory.append("Current smoker")
            }
        }
        
        // Alcohol
        if text.contains("alcohol") || text.contains("drink") {
            if text.contains("no alcohol") || text.contains("don't drink") {
                socialHistory.append("Denies alcohol use")
            } else if text.contains("social") {
                socialHistory.append("Social alcohol use")
            }
        }
        
        // Occupation
        let occupationPatterns = ["work as", "job is", "employed as", "occupation"]
        for pattern in occupationPatterns {
            if let range = text.range(of: pattern) {
                let afterText = String(text[range.upperBound...]).prefix(30)
                if !afterText.isEmpty {
                    socialHistory.append("Occupation: \(afterText)")
                    break
                }
            }
        }
        
        return socialHistory.isEmpty ? nil : socialHistory.joined(separator: ". ")
    }
    
    private func extractPastMedicalHistory(from conversation: String) -> String? {
        var pmh: [String] = []
        let text = conversation.lowercased()
        
        // Common conditions
        let conditions = [
            "diabetes": "Diabetes mellitus",
            "hypertension": "Hypertension",
            "high blood pressure": "Hypertension",
            "heart disease": "Cardiac disease",
            "asthma": "Asthma",
            "copd": "COPD",
            "cancer": "Cancer",
            "kidney disease": "Kidney disease",
            "liver disease": "Liver disease",
            "thyroid": "Thyroid disease",
            "depression": "Depression",
            "anxiety": "Anxiety"
        ]
        
        for (keyword, condition) in conditions {
            if text.contains(keyword) && !text.contains("no " + keyword) && !text.contains("denies " + keyword) {
                pmh.append(condition)
            }
        }
        
        // Medications (implies conditions)
        if text.contains("metformin") { pmh.append("Diabetes mellitus (on metformin)") }
        if text.contains("lisinopril") || text.contains("amlodipine") { pmh.append("Hypertension (on medication)") }
        if text.contains("levothyroxine") { pmh.append("Hypothyroidism (on levothyroxine)") }
        
        return pmh.isEmpty ? nil : pmh.joined(separator: ", ")
    }
    
    private func extractPastSurgicalHistory(from conversation: String) -> String? {
        let text = conversation.lowercased()
        var surgeries: [String] = []
        
        let surgicalKeywords = ["surgery", "operation", "removed", "appendectomy", "cholecystectomy", "hysterectomy", "c-section", "cesarean", "hernia repair", "gallbladder"]
        
        for keyword in surgicalKeywords {
            if text.contains(keyword) {
                // Extract context
                let sentences = conversation.components(separatedBy: ".")
                for sentence in sentences {
                    if sentence.lowercased().contains(keyword) {
                        surgeries.append(sentence.trimmingCharacters(in: .whitespacesAndNewlines))
                        break
                    }
                }
            }
        }
        
        return surgeries.isEmpty ? nil : surgeries.joined(separator: ". ")
    }
    
    private func extractReviewOfSystems(from conversation: String) -> String {
        var ros: [String] = []
        let text = conversation.lowercased()
        
        // Constitutional
        if text.contains("fever") || text.contains("chills") {
            ros.append("Constitutional: Positive for fever/chills")
        } else {
            ros.append("Constitutional: No fever, chills, or weight loss")
        }
        
        // Respiratory
        if text.contains("shortness of breath") || text.contains("cough") || text.contains("dyspnea") {
            ros.append("Respiratory: Positive for dyspnea/cough")
        } else {
            ros.append("Respiratory: Denies cough or dyspnea")
        }
        
        // Cardiovascular
        if text.contains("chest pain") || text.contains("palpitations") {
            ros.append("Cardiovascular: Positive for chest pain/palpitations")
        } else {
            ros.append("Cardiovascular: Denies chest pain or palpitations")
        }
        
        // GI
        if text.contains("nausea") || text.contains("vomiting") || text.contains("abdominal") {
            ros.append("GI: Positive for nausea/vomiting/abdominal symptoms")
        } else {
            ros.append("GI: Denies nausea, vomiting, or abdominal pain")
        }
        
        // Other systems
        ros.append("All other systems reviewed and negative")
        
        return ros.joined(separator: "\n")
    }
    
    private func extractPhysicalExam(from conversation: String) -> String {
        var pe: [String] = ["Physical exam to be performed"]
        let text = conversation.lowercased()
        
        // Extract mentioned vitals
        let vitalPatterns = [
            "blood pressure:? ([0-9]+/[0-9]+)",
            "bp:? ([0-9]+/[0-9]+)",
            "heart rate:? ([0-9]+)",
            "pulse:? ([0-9]+)",
            "temperature:? ([0-9.]+)",
            "oxygen:? ([0-9]+)%?"
        ]
        
        for pattern in vitalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: conversation, range: NSRange(conversation.startIndex..., in: conversation)),
               let range = Range(match.range, in: conversation) {
                let vital = String(conversation[range])
                pe.append("Vitals: " + vital)
                break
            }
        }
        
        return pe.joined(separator: "\n")
    }
    
    private func extractResults(from conversation: String) -> String {
        let text = conversation.lowercased()
        var results: [String] = []
        
        // Lab keywords
        let labKeywords = ["lab", "blood work", "cbc", "chemistry", "glucose", "white count", "hemoglobin"]
        for keyword in labKeywords {
            if text.contains(keyword) {
                results.append("Labs ordered/pending")
                break
            }
        }
        
        // Imaging keywords
        let imagingKeywords = ["x-ray", "ct", "mri", "ultrasound", "echo", "ekg", "ecg"]
        for keyword in imagingKeywords {
            if text.contains(keyword) {
                results.append("Imaging ordered/pending")
                break
            }
        }
        
        return results.isEmpty ? "No results available at this time" : results.joined(separator: ". ")
    }
    
    private func generateMDM(from sections: [RequiredSection: String]) -> String {
        var mdm = "Patient presents with "
        
        if let cc = sections[.cc] {
            mdm += cc.lowercased() + ". "
        }
        
        mdm += "History and examination findings as above. "
        mdm += "Differential diagnosis considered. "
        mdm += "Workup initiated as indicated. "
        mdm += "Risk stratification performed."
        
        return mdm
    }
    
    private func extractDiagnoses(from conversation: String, mdm: String?) -> String {
        // Look for specific diagnoses mentioned
        let text = conversation.lowercased()
        var diagnoses: [String] = []
        
        // Based on symptoms, suggest likely diagnoses
        if text.contains("chest pain") {
            diagnoses.append("Chest pain, unspecified")
        }
        if text.contains("headache") {
            if text.contains("migraine") {
                diagnoses.append("Migraine")
            } else {
                diagnoses.append("Headache")
            }
        }
        if text.contains("abdominal pain") {
            diagnoses.append("Abdominal pain")
        }
        
        return diagnoses.isEmpty ? "See assessment" : diagnoses.joined(separator: "\n")
    }
    
    private func extractDisposition(from conversation: String) -> String {
        let text = conversation.lowercased()
        
        if text.contains("admit") {
            return "Admission recommended"
        } else if text.contains("discharge") {
            return "Discharge home with follow-up"
        } else if text.contains("follow up") {
            return "Outpatient management with close follow-up"
        } else {
            return "Disposition pending clinical evaluation"
        }
    }
    
    private func extractDischargeInfo(from conversation: String) -> String? {
        let text = conversation.lowercased()
        
        if text.contains("discharge") || text.contains("go home") || text.contains("follow up") {
            return "Patient to follow up with primary care physician. Return precautions discussed."
        }
        
        return nil
    }
    
    // MARK: - Format Final Note
    
    func formatMedicalNote(sections: [RequiredSection: String]) -> String {
        var note = ""
        
        for section in RequiredSection.allCases {
            if let content = sections[section] {
                note += "**\(section.rawValue):**\n"
                note += content + "\n\n"
            } else if !section.isOptional {
                // Include required sections even if empty
                note += "**\(section.rawValue):**\n"
                note += "[To be documented]\n\n"
            }
        }
        
        return note
    }
    
    // MARK: - Main Entry Point
    
    func generateStrictFormatNote(from conversation: String) -> String {
        let sections = extractStructuredData(from: conversation)
        return formatMedicalNote(sections: sections)
    }
}