import Foundation
import NaturalLanguage

/// Automatically structures transcribed conversations into standard medical note formats
/// Extracts and organizes information into HPI, ROS, Physical Exam, Assessment, and Plan sections
@MainActor
class AutoFormPopulator: ObservableObject {
    static let shared = AutoFormPopulator()
    
    // MARK: - Published Properties
    @Published var structuredNote: StructuredMedicalNote = StructuredMedicalNote()
    @Published var extractedSections: [String: String] = [:]
    @Published var confidenceScores: [String: Float] = [:]
    
    // MARK: - Section Identifiers
    private let hpiKeywords = [
        "started", "began", "onset", "since", "ago", "began", "first noticed", "initially",
        "pain", "discomfort", "symptoms", "feeling", "experiencing", "having", "complaining of"
    ]
    
    private let rosKeywords = [
        "denies", "negative for", "no", "positive for", "reports", "endorses",
        "fever", "chills", "weight loss", "fatigue", "headache", "vision changes",
        "hearing", "sore throat", "cough", "shortness of breath", "chest pain",
        "palpitations", "nausea", "vomiting", "diarrhea", "constipation", "urinary"
    ]
    
    private let physicalExamKeywords = [
        "appears", "alert", "oriented", "vital signs", "blood pressure", "temperature",
        "pulse", "respirations", "oxygen saturation", "height", "weight", "bmi",
        "head", "eyes", "ears", "nose", "throat", "neck", "lymph nodes",
        "heart", "lungs", "abdomen", "extremities", "skin", "neurologic"
    ]
    
    private let assessmentKeywords = [
        "assessment", "impression", "diagnosis", "likely", "suspect", "consistent with",
        "differential", "rule out", "possible", "probable", "think", "believe"
    ]
    
    private let planKeywords = [
        "plan", "will", "going to", "recommend", "suggest", "start", "continue",
        "follow up", "return", "see", "schedule", "order", "prescribe", "refer"
    ]
    
    // MARK: - Temporal Indicators
    private let timeIndicators = [
        "today", "yesterday", "last week", "last month", "years ago", "months ago",
        "days ago", "hours ago", "this morning", "tonight", "recently", "currently"
    ]
    
    // MARK: - Speaker Detection Patterns
    private let doctorPhrases = [
        "let me examine", "I'm going to", "I recommend", "I think", "my assessment",
        "we should", "the plan is", "I'll prescribe", "follow up with me"
    ]
    
    private let patientPhrases = [
        "I feel", "I have", "I've been", "my pain", "I'm experiencing", "I notice",
        "it hurts", "I can't", "I'm worried", "I think I have"
    ]
    
    private init() {}
    
    // MARK: - Main Processing Function
    
    func processTranscription(_ text: String, speakerSegments: [(speaker: String, text: String)] = []) -> StructuredMedicalNote {
        
        // Reset the structured note
        structuredNote = StructuredMedicalNote()
        extractedSections = [:]
        confidenceScores = [:]
        
        var workingText = text
        var segments = speakerSegments
        
        // If no speaker segments provided, try to infer from text
        if segments.isEmpty {
            segments = inferSpeakerSegments(from: text)
        }
        
        // Process each section
        extractChiefComplaint(from: segments)
        extractHistoryOfPresentIllness(from: segments)
        extractReviewOfSystems(from: segments)
        extractPhysicalExam(from: segments)
        extractAssessment(from: segments)
        extractPlan(from: segments)
        extractVitalSigns(from: workingText)
        
        // Calculate overall confidence
        calculateSectionConfidences()
        
        return structuredNote
    }
    
    // MARK: - Speaker Inference
    
    private func inferSpeakerSegments(from text: String) -> [(speaker: String, text: String)] {
        let sentences = text.components(separatedBy: .punctuationCharacters)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var segments: [(speaker: String, text: String)] = []
        
        for sentence in sentences {
            let speaker = inferSpeaker(from: sentence)
            segments.append((speaker: speaker, text: sentence))
        }
        
        return segments
    }
    
    private func inferSpeaker(from text: String) -> String {
        let lowercaseText = text.lowercased()
        
        var doctorScore = 0
        var patientScore = 0
        
        // Check for doctor phrases
        for phrase in doctorPhrases {
            if lowercaseText.contains(phrase) {
                doctorScore += 2
            }
        }
        
        // Check for patient phrases
        for phrase in patientPhrases {
            if lowercaseText.contains(phrase) {
                patientScore += 2
            }
        }
        
        // Check for medical terminology (usually doctor)
        let medicalTerms = ["diagnosis", "examination", "assessment", "prescription", "treatment"]
        for term in medicalTerms {
            if lowercaseText.contains(term) {
                doctorScore += 1
            }
        }
        
        // Check for personal symptoms (usually patient)
        let symptomTerms = ["hurt", "pain", "feel", "can't", "uncomfortable"]
        for term in symptomTerms {
            if lowercaseText.contains(term) {
                patientScore += 1
            }
        }
        
        return doctorScore > patientScore ? "Doctor" : "Patient"
    }
    
    // MARK: - Chief Complaint Extraction
    
    private func extractChiefComplaint(from segments: [(speaker: String, text: String)]) {
        var chiefComplaints: [String] = []
        
        // Look for patient's initial statements
        let patientSegments = segments.filter { $0.speaker == "Patient" }
        
        for segment in patientSegments.prefix(5) { // Check first few patient statements
            let text = segment.text.lowercased()
            
            // Common chief complaint patterns
            let ccPatterns = [
                "I'm here for", "I came in because", "I have", "I've been having",
                "my main concern", "the problem is", "I'm experiencing"
            ]
            
            for pattern in ccPatterns {
                if text.contains(pattern) {
                    chiefComplaints.append(segment.text)
                    break
                }
            }
            
            // Look for symptom descriptions in early statements
            if segment.text.count > 20 && segment.text.count < 150 {
                chiefComplaints.append(segment.text)
            }
            
            if chiefComplaints.count >= 3 { break }
        }
        
        structuredNote.chiefComplaint = chiefComplaints.joined(separator: " ")
        extractedSections["Chief Complaint"] = structuredNote.chiefComplaint
    }
    
    // MARK: - History of Present Illness
    
    private func extractHistoryOfPresentIllness(from segments: [(speaker: String, text: String)]) {
        var hpiComponents: [String] = []
        
        for segment in segments {
            let text = segment.text
            let lowercaseText = text.lowercased()
            
            // Look for HPI elements
            var hasHPIContent = false
            
            // Check for temporal elements
            for timeWord in timeIndicators {
                if lowercaseText.contains(timeWord) {
                    hasHPIContent = true
                    break
                }
            }
            
            // Check for symptom descriptions
            for keyword in hpiKeywords {
                if lowercaseText.contains(keyword) {
                    hasHPIContent = true
                    break
                }
            }
            
            // Look for OLDCARTS elements
            let oldcartsElements = [
                "onset", "location", "duration", "character", "alleviating", "radiation", "timing", "severity"
            ]
            
            for element in oldcartsElements {
                if lowercaseText.contains(element) {
                    hasHPIContent = true
                    break
                }
            }
            
            if hasHPIContent && text.count > 15 {
                hpiComponents.append(text)
            }
        }
        
        structuredNote.historyOfPresentIllness = hpiComponents.joined(separator: " ")
        extractedSections["History of Present Illness"] = structuredNote.historyOfPresentIllness
    }
    
    // MARK: - Review of Systems
    
    private func extractReviewOfSystems(from segments: [(speaker: String, text: String)]) {
        var rosElements: [String] = []
        
        for segment in segments {
            let text = segment.text
            let lowercaseText = text.lowercased()
            
            // Look for ROS-specific language
            var hasROSContent = false
            
            for keyword in rosKeywords {
                if lowercaseText.contains(keyword) {
                    hasROSContent = true
                    break
                }
            }
            
            // Look for systematic review patterns
            let rosPatterns = [
                "any (.+?) problems", "denies (.+?)", "no (.+?) symptoms",
                "positive for (.+?)", "reports (.+?)", "endorses (.+?)"
            ]
            
            for pattern in rosPatterns {
                if let _ = lowercaseText.range(of: pattern, options: .regularExpression) {
                    hasROSContent = true
                    break
                }
            }
            
            if hasROSContent {
                rosElements.append(text)
            }
        }
        
        structuredNote.reviewOfSystems = rosElements.joined(separator: " ")
        extractedSections["Review of Systems"] = structuredNote.reviewOfSystems
    }
    
    // MARK: - Physical Examination
    
    private func extractPhysicalExam(from segments: [(speaker: String, text: String)]) {
        var examFindings: [String] = []
        
        // Physical exam is usually doctor observations
        let doctorSegments = segments.filter { $0.speaker == "Doctor" }
        
        for segment in doctorSegments {
            let text = segment.text
            let lowercaseText = text.lowercased()
            
            var hasExamContent = false
            
            // Check for physical exam keywords
            for keyword in physicalExamKeywords {
                if lowercaseText.contains(keyword) {
                    hasExamContent = true
                    break
                }
            }
            
            // Look for examination language
            let examPhrases = [
                "on examination", "physical exam", "appears", "looks", "palpation",
                "auscultation", "inspection", "normal", "abnormal", "tender"
            ]
            
            for phrase in examPhrases {
                if lowercaseText.contains(phrase) {
                    hasExamContent = true
                    break
                }
            }
            
            if hasExamContent {
                examFindings.append(text)
            }
        }
        
        structuredNote.physicalExamination = examFindings.joined(separator: " ")
        extractedSections["Physical Examination"] = structuredNote.physicalExamination
    }
    
    // MARK: - Assessment Extraction
    
    private func extractAssessment(from segments: [(speaker: String, text: String)]) {
        var assessmentComponents: [String] = []
        
        // Assessment is usually doctor's clinical thinking
        let doctorSegments = segments.filter { $0.speaker == "Doctor" }
        
        for segment in doctorSegments {
            let text = segment.text
            let lowercaseText = text.lowercased()
            
            var hasAssessmentContent = false
            
            // Check for assessment keywords
            for keyword in assessmentKeywords {
                if lowercaseText.contains(keyword) {
                    hasAssessmentContent = true
                    break
                }
            }
            
            // Look for diagnostic thinking
            let diagnosticPhrases = [
                "I think", "appears to be", "consistent with", "suggests",
                "differential includes", "most likely", "working diagnosis"
            ]
            
            for phrase in diagnosticPhrases {
                if lowercaseText.contains(phrase) {
                    hasAssessmentContent = true
                    break
                }
            }
            
            if hasAssessmentContent {
                assessmentComponents.append(text)
            }
        }
        
        structuredNote.assessment = assessmentComponents.joined(separator: " ")
        extractedSections["Assessment"] = structuredNote.assessment
    }
    
    // MARK: - Plan Extraction
    
    private func extractPlan(from segments: [(speaker: String, text: String)]) {
        var planComponents: [String] = []
        
        // Plan is usually doctor's recommendations
        let doctorSegments = segments.filter { $0.speaker == "Doctor" }
        
        for segment in doctorSegments {
            let text = segment.text
            let lowercaseText = text.lowercased()
            
            var hasPlanContent = false
            
            // Check for plan keywords
            for keyword in planKeywords {
                if lowercaseText.contains(keyword) {
                    hasPlanContent = true
                    break
                }
            }
            
            // Look for action-oriented language
            let actionPhrases = [
                "we're going to", "I'll", "you should", "let's", "next step",
                "treatment plan", "I recommend", "prescription for"
            ]
            
            for phrase in actionPhrases {
                if lowercaseText.contains(phrase) {
                    hasPlanContent = true
                    break
                }
            }
            
            if hasPlanContent {
                planComponents.append(text)
            }
        }
        
        structuredNote.plan = planComponents.joined(separator: " ")
        extractedSections["Plan"] = structuredNote.plan
    }
    
    // MARK: - Vital Signs Extraction
    
    private func extractVitalSigns(from text: String) {
        var bloodPressure: BloodPressure?
        var heartRate: Int?
        var respiratoryRate: Int?
        var temperature: Double?
        var oxygenSaturation: Int?
        
        // Blood pressure patterns
        let bpPatterns = [
            "blood pressure (\\d{2,3})/(\\d{2,3})",
            "BP (\\d{2,3})/(\\d{2,3})",
            "(\\d{2,3}) over (\\d{2,3})"
        ]
        
        for pattern in bpPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let systolicRange = Range(match.range(at: 1), in: text),
                       let diastolicRange = Range(match.range(at: 2), in: text),
                       let systolic = Int(String(text[systolicRange])),
                       let diastolic = Int(String(text[diastolicRange])) {
                        bloodPressure = BloodPressure(systolic: systolic, diastolic: diastolic)
                        break
                    }
                }
            }
        }
        
        // Heart rate patterns
        let hrPatterns = [
            "heart rate (\\d{2,3})",
            "pulse (\\d{2,3})",
            "HR (\\d{2,3})"
        ]
        
        for pattern in hrPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let hrRange = Range(match.range(at: 1), in: text) {
                        heartRate = Int(String(text[hrRange]))
                        break
                    }
                }
            }
        }
        
        // Temperature patterns
        let tempPatterns = [
            "temperature (\\d{2,3}\\.?\\d*)",
            "temp (\\d{2,3}\\.?\\d*)",
            "fever (\\d{2,3}\\.?\\d*)"
        ]
        
        for pattern in tempPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let tempRange = Range(match.range(at: 1), in: text) {
                        temperature = Double(String(text[tempRange]))
                        break
                    }
                }
            }
        }
        
        // Respiratory rate patterns
        let rrPatterns = [
            "respiratory rate (\\d{1,2})",
            "respirations (\\d{1,2})",
            "RR (\\d{1,2})"
        ]
        
        for pattern in rrPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let rrRange = Range(match.range(at: 1), in: text) {
                        respiratoryRate = Int(String(text[rrRange]))
                        break
                    }
                }
            }
        }
        
        // Oxygen saturation patterns
        let o2Patterns = [
            "oxygen saturation (\\d{2,3})",
            "O2 sat (\\d{2,3})",
            "sat (\\d{2,3})%?"
        ]
        
        for pattern in o2Patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let o2Range = Range(match.range(at: 1), in: text) {
                        oxygenSaturation = Int(String(text[o2Range]))
                        break
                    }
                }
            }
        }
        
        structuredNote.vitalSigns = VitalSigns(
            bloodPressure: bloodPressure,
            heartRate: heartRate,
            respiratoryRate: respiratoryRate,
            temperature: temperature,
            oxygenSaturation: oxygenSaturation,
            weight: nil,
            height: nil,
            bmi: nil,
            timestamp: Date()
        )
    }
    
    // MARK: - Confidence Calculation
    
    private func calculateSectionConfidences() {
        for (section, content) in extractedSections {
            let confidence = calculateConfidence(for: content, section: section)
            confidenceScores[section] = confidence
        }
    }
    
    private func calculateConfidence(for content: String, section: String) -> Float {
        if content.isEmpty { return 0.0 }
        
        var score: Float = 0.5 // Base confidence
        
        // Length-based confidence
        let wordCount = content.split(separator: " ").count
        if wordCount > 5 { score += 0.2 }
        if wordCount > 15 { score += 0.1 }
        
        // Section-specific keywords
        let relevantKeywords: [String]
        switch section {
        case "History of Present Illness":
            relevantKeywords = hpiKeywords + timeIndicators
        case "Review of Systems":
            relevantKeywords = rosKeywords
        case "Physical Examination":
            relevantKeywords = physicalExamKeywords
        case "Assessment":
            relevantKeywords = assessmentKeywords
        case "Plan":
            relevantKeywords = planKeywords
        default:
            relevantKeywords = []
        }
        
        let lowercaseContent = content.lowercased()
        let keywordMatches = relevantKeywords.filter { lowercaseContent.contains($0) }.count
        let keywordBonus = min(0.3, Float(keywordMatches) * 0.05)
        score += keywordBonus
        
        return min(1.0, score)
    }
    
    // MARK: - Export Functions
    
    func generateSOAPNote() -> String {
        var soap = "SOAP NOTE\n"
        soap += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        soap += "SUBJECTIVE:\n"
        if !structuredNote.chiefComplaint.isEmpty {
            soap += "Chief Complaint: \(structuredNote.chiefComplaint)\n\n"
        }
        
        if !structuredNote.historyOfPresentIllness.isEmpty {
            soap += "History of Present Illness:\n\(structuredNote.historyOfPresentIllness)\n\n"
        }
        
        if !structuredNote.reviewOfSystems.isEmpty {
            soap += "Review of Systems:\n\(structuredNote.reviewOfSystems)\n\n"
        }
        
        soap += "OBJECTIVE:\n"
        if let vitals = structuredNote.vitalSigns {
            soap += "Vital Signs: "
            if let bp = vitals.bloodPressure {
                soap += "BP \(bp), "
            }
            if let hr = vitals.heartRate {
                soap += "HR \(hr), "
            }
            if let temp = vitals.temperature {
                soap += "Temp \(temp)°F, "
            }
            soap = String(soap.dropLast(2)) + "\n\n"
        }
        
        if !structuredNote.physicalExamination.isEmpty {
            soap += "Physical Examination:\n\(structuredNote.physicalExamination)\n\n"
        }
        
        soap += "ASSESSMENT:\n"
        if !structuredNote.assessment.isEmpty {
            soap += "\(structuredNote.assessment)\n\n"
        }
        
        soap += "PLAN:\n"
        if !structuredNote.plan.isEmpty {
            soap += "\(structuredNote.plan)\n\n"
        }
        
        return soap
    }
    
    func exportForEMR() -> [String: String] {
        return [
            "chief_complaint": structuredNote.chiefComplaint,
            "hpi": structuredNote.historyOfPresentIllness,
            "ros": structuredNote.reviewOfSystems,
            "physical_exam": structuredNote.physicalExamination,
            "assessment": structuredNote.assessment,
            "plan": structuredNote.plan,
            "vitals": formatVitalSigns()
        ]
    }
    
    private func formatVitalSigns() -> String {
        guard let vitals = structuredNote.vitalSigns else { return "" }
        
        var vitalString = ""
        if let bp = vitals.bloodPressure {
            vitalString += "BP: \(bp.systolic)/\(bp.diastolic) mmHg, "
        }
        if let hr = vitals.heartRate {
            vitalString += "HR: \(hr) bpm, "
        }
        if let temp = vitals.temperature {
            vitalString += "Temp: \(temp)°F, "
        }
        if let rr = vitals.respiratoryRate {
            vitalString += "RR: \(rr) breaths/min, "
        }
        if let o2 = vitals.oxygenSaturation {
            vitalString += "O2 Sat: \(o2)%"
        }
        
        return vitalString.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ","))
    }
}

// MARK: - Data Models

struct StructuredMedicalNote: Codable {
    var chiefComplaint: String = ""
    var historyOfPresentIllness: String = ""
    var reviewOfSystems: String = ""
    var physicalExamination: String = ""
    var assessment: String = ""
    var plan: String = ""
    var vitalSigns: VitalSigns?

    // New categorized arrays for incremental updates
    var hpi: [String] = []
    var ros: [String] = []
    var mdm: [String] = []
    var dischargeInstructions: [String] = []
    var pmh: [String] = []
    var medications: [String] = []
}

// Using VitalSigns from MedicalTypes.swift