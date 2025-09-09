import Foundation

@MainActor
class EmergencyMedicinePrompter {
    
    // MARK: - Core Emergency Medicine Prompting
    static func createEmergencyNotePrompt(
        from transcription: String,
        noteType: NoteType
    ) -> String {
        
        // Analyze the conversation for clinical content
        let clinicalData = extractClinicalContent(from: transcription)
        
        let basePrompt = """
        You are an expert emergency medicine physician. Analyze this doctor-patient conversation and create a professional emergency department clinical note.

        CRITICAL DOCUMENTATION REQUIREMENTS:
        1. Write in professional medical narrative style (third person)
        2. SUMMARIZE conversation content - do not quote dialogue verbatim
        3. Extract and synthesize clinical information professionally
        4. Use standard medical terminology and abbreviations
        5. Focus on emergency medicine priorities and clinical reasoning
        6. Do NOT include conversational quotes or "Patient states..." format

        CONVERSATION TO ANALYZE:
        \(transcription)

        CLINICAL CONTEXT IDENTIFIED:
        - Primary Concern: \(clinicalData.chiefComplaint)
        - Risk Factors: \(clinicalData.riskFactors.joined(separator: ", "))
        - Timeline: \(clinicalData.timing ?? "Not specified")

        CREATE PROFESSIONAL CLINICAL SUMMARY:
        """
        
        switch noteType {
        case .edNote:
            return basePrompt + createEDNotePrompt(clinicalData: clinicalData)
        case .soap:
            return basePrompt + createSOAPNotePrompt(clinicalData: clinicalData)
        case .progress:
            return basePrompt + createProgressNotePrompt(clinicalData: clinicalData)
        case .consult:
            return basePrompt + createConsultNotePrompt(clinicalData: clinicalData)
        case .handoff:
            return basePrompt + createHandoffNotePrompt(clinicalData: clinicalData)
        case .discharge:
            return basePrompt + createDischargeNotePrompt(clinicalData: clinicalData)
        }
    }
    
    // MARK: - ED Note Format
    static func createEDNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a comprehensive Emergency Department note with ALL of these sections:
        
        **CHIEF COMPLAINT:** [Extract exact complaint with timing]
        
        **HISTORY OF PRESENT ILLNESS:**
        [Create detailed HPI including onset, location, duration, characteristics, associated symptoms, relieving/exacerbating factors, and treatments tried]
        
        **PAST MEDICAL HISTORY:**
        [List all medical conditions mentioned]
        
        **PAST SURGICAL HISTORY:**
        [List any surgeries mentioned or state "No prior surgeries"]
        
        **MEDICATIONS:**
        [List all current medications with dosages if available]
        
        **ALLERGIES:**
        [List allergies or state "NKDA" if none]
        
        **FAMILY HISTORY:**
        [Include relevant family medical history]
        
        **SOCIAL HISTORY:**
        [Include tobacco, alcohol, drug use, occupation, living situation]
        
        **REVIEW OF SYSTEMS:**
        [Complete 10-point ROS with pertinent positives and negatives]
        
        **PHYSICAL EXAM:**
        [Include vital signs and complete physical examination findings]
        
        **LAB AND IMAGING RESULTS:**
        [Include any test results mentioned or ordered]
        
        **MEDICAL DECISION MAKING:**
        [Include clinical reasoning, risk stratification, and differential diagnosis considerations]
        
        **DIAGNOSES:**
        [List primary and secondary diagnoses]
        
        **DISPOSITION:**
        [Include admission/discharge decision and rationale]
        
        **DISCHARGE INSTRUCTIONS:**
        [If discharged, include return precautions, medications, activity, and follow-up]
        
        **FOLLOW-UP:**
        [Specific follow-up recommendations with timeframes]
        """
    }
    
    
    
    
    
    // MARK: - Clinical Content Extraction
    static func extractClinicalContent(from transcription: String) -> ClinicalContent {
        let text = transcription.lowercased()
        
        return ClinicalContent(
            chiefComplaint: extractChiefComplaint(from: text),
            timing: extractTiming(from: text),
            riskFactors: identifyHighRiskFeatures(from: text),
            medicalHistory: extractMedicalHistory(from: text),
            symptoms: extractSymptoms(from: text),
            plannedWorkup: extractPlannedTests(from: text)
        )
    }
    
    static func extractChiefComplaint(from text: String) -> String {
        if text.contains("chest pain") {
            if let timing = extractTiming(from: text) {
                return "Chest pain x \(timing)"
            }
            return "Chest pain"
        }
        if text.contains("abdominal pain") || text.contains("belly") {
            return "Abdominal pain"
        }
        if text.contains("shortness of breath") || text.contains("breathing") {
            return "Shortness of breath"
        }
        return "Undifferentiated complaint"
    }
    
    static func extractTiming(from text: String) -> String? {
        let patterns = [
            "\\b(\\d+)\\s*hours?\\b",
            "\\b(\\d+)\\s*days?\\b",
            "\\b(\\d+)\\s*weeks?\\b"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let timeRange = Range(match.range(at: 0), in: text) {
                return String(text[timeRange])
            }
        }
        return nil
    }
    
    static func identifyHighRiskFeatures(from text: String) -> [String] {
        var risks: [String] = []
        
        if text.contains("blood clot") && (text.contains("ran out") || text.contains("stopped")) {
            risks.append("History of VTE with recent anticoagulation discontinuation")
        }
        
        if text.contains("chest pain") && text.contains("diabetes") {
            risks.append("Cardiac risk factors present")
        }
        
        if text.contains("cough") && text.contains("chest") {
            risks.append("Pleuritic symptoms concerning for PE")
        }
        
        return risks
    }
    
    static func extractMedicalHistory(from text: String) -> [String] {
        var conditions: [String] = []
        
        let conditionMap = [
            "diabetes": "Diabetes mellitus",
            "high blood pressure": "Hypertension",
            "blood clot": "History of venous thromboembolism",
            "heart attack": "History of myocardial infarction"
        ]
        
        for (keyword, condition) in conditionMap {
            if text.contains(keyword) {
                conditions.append(condition)
            }
        }
        
        return conditions
    }
    
    static func extractSymptoms(from text: String) -> [String] {
        var symptoms: [String] = []
        
        if text.contains("cough") { symptoms.append("Cough") }
        if text.contains("nausea") { symptoms.append("Nausea") }
        if text.contains("shortness of breath") { symptoms.append("Dyspnea") }
        
        return symptoms
    }
    
    static func extractPlannedTests(from text: String) -> [String] {
        var tests: [String] = []
        
        if text.contains("ekg") || text.contains("ecg") { tests.append("12-lead EKG") }
        if text.contains("lab") { tests.append("Laboratory studies") }
        if text.contains("chest x-ray") || text.contains("x-ray") { tests.append("Chest radiograph") }
        if text.contains("blood clot") { tests.append("Consider CT pulmonary angiogram") }
        
        return tests
    }
    
    // MARK: - SOAP Note Format
    static func createSOAPNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a professional SOAP note:
        
        **SUBJECTIVE:**
        - Chief Complaint: \(clinicalData.symptoms.joined(separator: ", "))
        - HPI: Include onset, location, duration, characteristics, associated symptoms, relieving/exacerbating factors
        - PMH, Medications, Allergies, Social History
        - Review of Systems
        
        **OBJECTIVE:**
        - Vital Signs
        - Physical Examination
        - Lab/Imaging Results
        
        **ASSESSMENT:**
        - Primary diagnosis or clinical impression
        - Differential diagnoses with reasoning
        - Risk stratification
        
        **PLAN:**
        - Diagnostic workup
        - Treatment plan
        - Disposition
        - Follow-up recommendations
        """
    }
}

// MARK: - Supporting Types
struct ClinicalContent {
    let chiefComplaint: String
    let timing: String?
    let riskFactors: [String]
    let medicalHistory: [String]
    let symptoms: [String]
    let plannedWorkup: [String]
}

// MARK: - Additional Note Format Methods
extension EmergencyMedicinePrompter {
    
    static func createProgressNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a Progress Note with these sections:
        
        **INTERVAL HISTORY:**
        [Document changes since last evaluation and response to treatment]
        
        **CURRENT STATUS:**
        [Current symptoms, medication compliance, new concerns]
        
        **PHYSICAL EXAMINATION:**
        [Focused exam findings relevant to condition]
        
        **ASSESSMENT & PLAN:**
        [Clinical progress evaluation and treatment modifications]
        """
    }
    
    static func createConsultNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a Consultation Note with these sections:
        
        **REASON FOR CONSULTATION:**
        [Specific question or concern from primary team]
        
        **HISTORY OF PRESENT ILLNESS:**
        [Detailed narrative relevant to consultation]
        
        **PAST MEDICAL HISTORY:**
        [Relevant medical conditions]
        
        **PHYSICAL EXAMINATION:**
        [Focused examination findings]
        
        **ASSESSMENT:**
        [Consultant's clinical impression]
        
        **RECOMMENDATIONS:**
        [Specific treatment recommendations and follow-up plan]
        """
    }
    
    static func createHandoffNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a Handoff Note using SBAR format:
        
        **SITUATION:**
        [Patient identification, current location, immediate concern]
        
        **BACKGROUND:**
        [Relevant medical history and current treatment]
        
        **ASSESSMENT:**
        [Current clinical status and pending items]
        
        **RECOMMENDATIONS:**
        [Action items for next provider and contingency plans]
        """
    }
    
    static func createDischargeNotePrompt(clinicalData: ClinicalContent) -> String {
        return """
        
        Generate a Discharge Summary with these sections:
        
        **ADMISSION DIAGNOSIS:**
        [Initial presenting complaint and diagnosis]
        
        **DISCHARGE DIAGNOSIS:**
        [Final primary and secondary diagnoses]
        
        **HOSPITAL COURSE:**
        [Summary of treatment and response]
        
        **DISCHARGE MEDICATIONS:**
        [Complete medication list with instructions]
        
        **DISCHARGE INSTRUCTIONS:**
        [Activity restrictions, follow-up appointments, warning signs]
        
        **CONDITION AT DISCHARGE:**
        [Clinical status at time of discharge]
        """
    }
}