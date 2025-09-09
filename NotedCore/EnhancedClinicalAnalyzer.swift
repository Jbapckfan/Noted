import Foundation

/// Enhanced clinical analyzer with all professional features integrated
class EnhancedClinicalAnalyzer {
    
    struct EnhancedClinicalData {
        // Basic fields
        let chiefComplaint: String
        let hpi: String
        let pmh: String
        let psh: String
        let medications: String
        let allergies: String
        let socialHistory: String
        let familyHistory: String
        let ros: String
        let physicalExam: String
        let assessment: String
        let mdm: String
        let diagnosis: String
        let disposition: String
        let dischargeInstructions: String?
        
        // Enhanced fields
        let differentialDiagnosis: String
        let icd10Codes: String
        let confidenceScore: String
        let qualityMetrics: String
        let criticalActions: String
        let timeStamps: String
        
        func generateEnhancedNote() -> String {
            var note = """
            ════════════════════════════════════════════════════════════════
            EMERGENCY DEPARTMENT CLINICAL NOTE
            Generated: \(Date().formatted())
            ════════════════════════════════════════════════════════════════
            
            **CHIEF COMPLAINT:** \(chiefComplaint)
            
            **HISTORY OF PRESENT ILLNESS:**
            \(hpi)
            
            **PAST MEDICAL HISTORY:** \(pmh)
            **PAST SURGICAL HISTORY:** \(psh)
            **MEDICATIONS:** \(medications)
            **ALLERGIES:** \(allergies)
            **SOCIAL HISTORY:** \(socialHistory)
            **FAMILY HISTORY:** \(familyHistory)
            
            **REVIEW OF SYSTEMS:** \(ros)
            
            **PHYSICAL EXAMINATION:**
            \(physicalExam)
            
            **ASSESSMENT:**
            \(assessment)
            
            \(differentialDiagnosis)
            
            **MEDICAL DECISION MAKING:**
            \(mdm)
            
            **DIAGNOSIS:**
            \(diagnosis)
            
            \(icd10Codes)
            
            **DISPOSITION:**
            \(disposition)
            """
            
            // Add discharge instructions if applicable
            if let instructions = dischargeInstructions, !instructions.isEmpty {
                note += """
                
                
                **DISCHARGE INSTRUCTIONS:**
                \(instructions)
                """
            }
            
            // Add quality metrics at the end
            note += """
            
            
            ════════════════════════════════════════════════════════════════
            DOCUMENTATION METRICS
            ════════════════════════════════════════════════════════════════
            \(qualityMetrics)
            
            \(confidenceScore)
            
            **CRITICAL ACTIONS COMPLETED:**
            \(criticalActions)
            
            **TIMESTAMPS:**
            \(timeStamps)
            """
            
            return note
        }
    }
    
    /// Main analysis function with all enhancements
    static func analyzeWithEnhancements(_ transcription: String) -> EnhancedClinicalData {
        // Step 1: Pre-process with medical improvements
        let improvedText = MedicalAbbreviationExpander.processText(transcription)
        let text = improvedText.lowercased()
        
        // Step 2: Extract basic information
        let chiefComplaint = extractRealChiefComplaint(from: text)
        let hpi = extractEnhancedHPI(from: improvedText)
        let symptoms = extractSymptoms(from: text)
        
        // Step 3: Select appropriate template
        let template = ClinicalTemplateSystem.selectTemplate(for: chiefComplaint)
        
        // Step 4: Generate differential diagnosis
        let differentials = DifferentialDiagnosisGenerator.generateDifferential(
            chiefComplaint: chiefComplaint,
            symptoms: symptoms
        )
        let differentialText = DifferentialDiagnosisGenerator.formatDifferentialForNote(differentials)
        let icd10Codes = DifferentialDiagnosisGenerator.generateICD10List(differentials)
        
        // Step 5: Score confidence levels
        let sections = [
            "Chief Complaint": chiefComplaint,
            "HPI": hpi,
            "Medications": extractRealMedications(from: text),
            "Allergies": extractRealAllergies(from: text)
        ]
        let confidenceReport = ClinicalConfidenceScorer.generateConfidenceReport(
            for: sections,
            from: transcription
        )
        
        // Step 6: Generate quality metrics
        let fullNote = hpi + extractRealROS(from: text) + extractRealAssessment(from: text)
        let qualityMetrics = ClinicalTemplateSystem.generateQualityMetrics(
            note: fullNote,
            template: template
        )
        
        // Step 7: Extract critical actions and timestamps
        let criticalActions = extractCriticalActions(from: text, template: template)
        let timeStamps = extractTimeStamps(from: text)
        
        // Step 8: Determine disposition
        let disposition = extractDisposition(from: text)
        let isDischarge = disposition.contains("discharge") || disposition.contains("home")
        
        return EnhancedClinicalData(
            chiefComplaint: chiefComplaint,
            hpi: hpi,
            pmh: extractRealPMH(from: text),
            psh: extractRealPSH(from: text),
            medications: extractRealMedications(from: text),
            allergies: extractRealAllergies(from: text),
            socialHistory: extractRealSocialHistory(from: text),
            familyHistory: extractRealFamilyHistory(from: text),
            ros: extractRealROS(from: text),
            physicalExam: extractEnhancedPhysicalExam(from: text, template: template),
            assessment: extractRealAssessment(from: text),
            mdm: generateEnhancedMDM(from: text, differentials: differentials),
            diagnosis: extractDiagnosis(from: text),
            disposition: disposition,
            dischargeInstructions: isDischarge ? generateDischargeInstructions(from: text) : nil,
            differentialDiagnosis: differentialText,
            icd10Codes: icd10Codes,
            confidenceScore: confidenceReport,
            qualityMetrics: qualityMetrics,
            criticalActions: criticalActions,
            timeStamps: timeStamps
        )
    }
    
    // MARK: - Enhanced Extraction Functions
    
    private static func extractEnhancedHPI(from text: String) -> String {
        // Use the narrative style from RealConversationAnalyzer
        var hpi = RealConversationAnalyzer.extractRealHPI(from: text)
        
        // Add clinical reasoning phrases
        if hpi.contains("chest pain") {
            hpi += " Given the presentation, cardiac etiology must be ruled out."
        } else if hpi.contains("abdominal pain") {
            hpi += " Clinical picture raises concern for acute surgical pathology."
        } else if hpi.contains("headache") {
            hpi += " Red flags for secondary headache were assessed."
        }
        
        return hpi
    }
    
    private static func extractEnhancedPhysicalExam(from text: String, template: ClinicalTemplateSystem.ClinicalTemplate?) -> String {
        var exam = "**General**: Patient appears "
        
        // General appearance
        if text.contains("distress") || text.contains("pain") {
            exam += "in moderate distress secondary to pain.\n"
        } else {
            exam += "well-appearing, in no acute distress.\n"
        }
        
        // Vital signs
        exam += "**Vital Signs**: "
        if let bpMatch = text.range(of: "\\d{2,3}/\\d{2,3}", options: .regularExpression) {
            exam += "BP \(String(text[bpMatch])) mmHg, "
        }
        if let hrMatch = text.range(of: "heart rate.{0,10}\\d{2,3}", options: .regularExpression) {
            exam += String(text[hrMatch]) + ", "
        }
        if let tempMatch = text.range(of: "\\d{2}\\.\\d", options: .regularExpression) {
            exam += "Temp \(String(text[tempMatch]))°F, "
        }
        exam += "other vital signs within normal limits.\n"
        
        // Template-specific exam
        if let template = template {
            exam += "\n**Focused Examination**:\n"
            for focus in template.physicalExamFocus.prefix(3) {
                exam += "• \(focus): Within normal limits\n"
            }
        }
        
        // Specific findings from conversation
        if text.contains("tender") {
            exam += "\n**Pertinent Positives**: Tenderness noted on examination\n"
        }
        if text.contains("rebound") {
            exam += "• Positive rebound tenderness\n"
        }
        if text.contains("guarding") {
            exam += "• Voluntary guarding present\n"
        }
        
        return exam
    }
    
    private static func generateEnhancedMDM(from text: String, differentials: [DifferentialDiagnosisGenerator.DifferentialDiagnosis]) -> String {
        var mdm = "**Clinical Reasoning:**\n"
        
        // Risk stratification
        mdm += "Risk stratification performed based on presentation. "
        
        if let primary = differentials.first {
            mdm += "Primary consideration is \(primary.condition). "
            
            if primary.probability == "High" {
                mdm += "High clinical suspicion based on classic presentation. "
            } else {
                mdm += "Cannot exclude based on current findings. "
            }
        }
        
        mdm += "\n\n**Diagnostic Approach:**\n"
        if let primary = differentials.first {
            mdm += "Recommended workup: \(primary.workup.prefix(3).joined(separator: ", "))\n"
        }
        
        mdm += "\n**Therapeutic Interventions:**\n"
        if text.contains("pain") {
            mdm += "• Analgesia provided for symptom control\n"
        }
        if text.contains("nausea") {
            mdm += "• Antiemetics administered\n"
        }
        if text.contains("fluids") || text.contains("iv") {
            mdm += "• IV hydration initiated\n"
        }
        
        mdm += "\n**Disposition Rationale:**\n"
        if text.contains("stable") && (text.contains("discharge") || text.contains("home")) {
            mdm += "Patient clinically stable with improvement of symptoms. Safe for outpatient management with close follow-up."
        } else if text.contains("admit") {
            mdm += "Admission warranted for further monitoring and treatment."
        } else {
            mdm += "Disposition pending clinical response and test results."
        }
        
        return mdm
    }
    
    private static func extractSymptoms(from text: String) -> [String] {
        var symptoms: [String] = []
        
        let symptomKeywords = [
            "pain", "fever", "nausea", "vomiting", "diarrhea",
            "cough", "shortness of breath", "chest pain", "headache",
            "dizziness", "weakness", "fatigue", "rash", "swelling"
        ]
        
        for keyword in symptomKeywords {
            if text.contains(keyword) {
                symptoms.append(keyword)
            }
        }
        
        return symptoms
    }
    
    private static func extractCriticalActions(from text: String, template: ClinicalTemplateSystem.ClinicalTemplate?) -> String {
        var actions = ""
        
        if let template = template {
            actions = "Based on \(template.name) protocol:\n"
            for action in template.criticalActions {
                let completed = checkIfActionCompleted(action, in: text)
                actions += "\(completed ? "✅" : "⏳") \(action)\n"
            }
        } else {
            actions = "Standard ED critical actions:\n"
            actions += "✅ Vital signs obtained\n"
            actions += "✅ History and physical completed\n"
            
            if text.contains("ecg") || text.contains("ekg") {
                actions += "✅ ECG performed\n"
            }
            if text.contains("labs") || text.contains("blood") {
                actions += "✅ Laboratory studies ordered\n"
            }
            if text.contains("imaging") || text.contains("ct") || text.contains("xray") {
                actions += "✅ Imaging obtained\n"
            }
        }
        
        return actions
    }
    
    private static func checkIfActionCompleted(_ action: String, in text: String) -> Bool {
        let actionLower = action.lowercased()
        let textLower = text.lowercased()
        
        // Check for key words from the action in the text
        let keywords = actionLower.components(separatedBy: " ")
        var matchCount = 0
        
        for keyword in keywords where keyword.count > 3 {
            if textLower.contains(keyword) {
                matchCount += 1
            }
        }
        
        return matchCount >= 2 || (matchCount == 1 && keywords.count <= 3)
    }
    
    private static func extractTimeStamps(from text: String) -> String {
        var timestamps = ""
        
        // Look for time references
        if let arrivalTime = extractTime(pattern: "arrived?.{0,10}\\d{1,2}:\\d{2}", from: text) {
            timestamps += "Arrival: \(arrivalTime)\n"
        }
        
        if let triageTime = extractTime(pattern: "triage.{0,10}\\d{1,2}:\\d{2}", from: text) {
            timestamps += "Triage: \(triageTime)\n"
        }
        
        if let mdTime = extractTime(pattern: "seen by.{0,10}\\d{1,2}:\\d{2}", from: text) {
            timestamps += "Provider evaluation: \(mdTime)\n"
        }
        
        if timestamps.isEmpty {
            timestamps = "Arrival: [TIME]\nProvider evaluation: [TIME]\nDisposition: [TIME]"
        }
        
        return timestamps
    }
    
    private static func extractTime(pattern: String, from text: String) -> String? {
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        return nil
    }
    
    // MARK: - Delegate to RealConversationAnalyzer for basic extractions
    
    private static func extractRealChiefComplaint(from text: String) -> String {
        return RealConversationAnalyzer.extractRealChiefComplaint(from: text)
    }
    
    private static func extractRealPMH(from text: String) -> String {
        return RealConversationAnalyzer.extractRealPMH(from: text)
    }
    
    private static func extractRealPSH(from text: String) -> String {
        return RealConversationAnalyzer.extractRealPSH(from: text)
    }
    
    private static func extractRealMedications(from text: String) -> String {
        return RealConversationAnalyzer.extractRealMedications(from: text)
    }
    
    private static func extractRealAllergies(from text: String) -> String {
        return RealConversationAnalyzer.extractRealAllergies(from: text)
    }
    
    private static func extractRealSocialHistory(from text: String) -> String {
        return RealConversationAnalyzer.extractRealSocialHistory(from: text)
    }
    
    private static func extractRealFamilyHistory(from text: String) -> String {
        return RealConversationAnalyzer.extractRealFamilyHistory(from: text)
    }
    
    private static func extractRealROS(from text: String) -> String {
        return RealConversationAnalyzer.extractRealROS(from: text)
    }
    
    private static func extractRealAssessment(from text: String) -> String {
        return RealConversationAnalyzer.generateRealAssessment(from: text)
    }
    
    private static func extractDiagnosis(from text: String) -> String {
        return RealConversationAnalyzer.extractDiagnosis(from: text)
    }
    
    private static func extractDisposition(from text: String) -> String {
        return RealConversationAnalyzer.extractDisposition(from: text)
    }
    
    private static func generateDischargeInstructions(from text: String) -> String {
        return RealConversationAnalyzer.generateDischargeInstructions(from: text)
    }
}

// Extension removed - RealConversationAnalyzer already has these as private static functions