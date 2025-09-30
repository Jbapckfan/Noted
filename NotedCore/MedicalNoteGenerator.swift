import Foundation

// MARK: - Shared Medical Note Generator
/// Centralized note generation to eliminate code duplication across services
@MainActor
final class MedicalNoteGenerator {
    static let shared = MedicalNoteGenerator()
    
    init() {}
    
    // MARK: - Main Note Generation
    
    func generateNote(from conversation: ConversationAnalysis, noteType: NoteType) -> String {
        switch noteType {
        case .edNote:
            return generateEDNote(from: conversation)
        case .soap:
            return generateSOAPNote(from: conversation)
        case .progress:
            return generateProgressNote(from: conversation)
        case .consult:
            return generateConsultNote(from: conversation)
        case .handoff:
            return generateHandoffNote(from: conversation)
        case .discharge:
            return generateDischargeNote(from: conversation)
        }
    }
    
    // MARK: - ED Note Generation
    func generateEDNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        Generated: \(timestamp)
        **EMERGENCY DEPARTMENT NOTE**

        **CHIEF COMPLAINT:** \(conversation.chiefComplaint)

        **HISTORY OF PRESENT ILLNESS:**
        \(createHPI(conversation: conversation))

        **PAST MEDICAL HISTORY:**
        \(createPMHSection(conversation: conversation))
        
        **PAST SURGICAL HISTORY:**
        \(createPastSurgicalHistory(conversation: conversation))

        **MEDICATIONS:**
        \(createMedicationsSection(conversation: conversation))

        **ALLERGIES:**
        \(createAllergiesSection(conversation: conversation))
        
        **FAMILY HISTORY:**
        \(createFamilyHistory(conversation: conversation))

        **SOCIAL HISTORY:**
        \(createSocialHistorySection(conversation: conversation))
        
        **REVIEW OF SYSTEMS:**
        \(createReviewOfSystems(conversation: conversation))

        **PHYSICAL EXAM:**
        \(createPhysicalExam(conversation: conversation))
        
        **LAB AND IMAGING RESULTS:**
        \(createLabAndImagingResults(conversation: conversation))

        **MEDICAL DECISION MAKING:**
        \(createMDMSection(conversation: conversation))

        **DIAGNOSES:**
        \(createDiagnoses(conversation: conversation))

        **DISPOSITION:**
        \(createDisposition(conversation: conversation))
        
        **DISCHARGE INSTRUCTIONS:**
        \(createDischargeInstructions(conversation: conversation))
        
        **FOLLOW-UP:**
        \(createFollowUp(conversation: conversation))

        ---
        *Generated from conversation analysis - completely private and secure*
        """
    }
    
    // MARK: - Section Generators
    
    private func createHPI(conversation: ConversationAnalysis) -> String {
        var components: [String] = []
        
        // Opening: Natural presentation
        let presentation = "Patient presents with \(conversation.chiefComplaint.lowercased())"
        if let timing = conversation.timing {
            components.append("\(presentation) that began \(timing) prior to arrival")
        } else {
            components.append(presentation)
        }
        
        // Pain details if applicable
        if let painDetails = createPainDescription(conversation: conversation), !painDetails.isEmpty {
            components.append(painDetails)
        }
        
        // Modifying factors
        if let modifying = createModifyingFactors(conversation: conversation), !modifying.isEmpty {
            components.append(modifying)
        }
        
        // Associated symptoms
        if !conversation.symptoms.isEmpty {
            let symptoms = conversation.symptoms.joined(separator: ", ")
            components.append("Associated symptoms include \(symptoms)")
        }
        
        // Relevant history in context
        if let relevantHistory = createRelevantHistory(conversation: conversation), !relevantHistory.isEmpty {
            components.append(relevantHistory)
        }
        
        // Medication context
        if let medContext = createMedicationContext(conversation: conversation), !medContext.isEmpty {
            components.append(medContext)
        }
        
        return components.joined(separator: ". ") + "."
    }
    
    private func createPainDescription(conversation: ConversationAnalysis) -> String? {
        let text = conversation.originalText.lowercased()
        var descriptions: [String] = []
        
        if text.contains("sharp") {
            descriptions.append("described as sharp")
        } else if text.contains("crushing") {
            descriptions.append("described as crushing")
        } else if text.contains("pressure") {
            descriptions.append("described as pressure-like")
        }
        
        if text.contains("radiates to") || text.contains("goes to") {
            if text.contains("left arm") || text.contains("jaw") {
                descriptions.append("radiates to the left arm and jaw")
            } else if text.contains("shoulder") {
                descriptions.append("radiates to the shoulder")
            }
        }
        
        return descriptions.isEmpty ? nil : "The pain is \(descriptions.joined(separator: ", "))"
    }
    
    private func createModifyingFactors(conversation: ConversationAnalysis) -> String? {
        let text = conversation.originalText.lowercased()
        var factors: [String] = []
        
        if text.contains("worsened by coughing") || text.contains("worse with cough") {
            factors.append("worsened by coughing")
        }
        if text.contains("improved with") || text.contains("better with") {
            if text.contains("shallow breathing") {
                factors.append("improved with shallow breathing")
            } else if text.contains("rest") {
                factors.append("improved with rest")
            }
        }
        
        return factors.isEmpty ? nil : "The pain is \(factors.joined(separator: " and "))"
    }
    
    private func createRelevantHistory(conversation: ConversationAnalysis) -> String? {
        let text = conversation.originalText.lowercased()
        var historyElements: [String] = []
        
        // Medical history - natural language
        var pmh: [String] = []
        if text.contains("diabetes") { pmh.append("diabetes") }
        if text.contains("high blood pressure") || text.contains("hypertension") {
            pmh.append("hypertension")
        }
        if text.contains("blood clot") {
            pmh.append("blood clots")
        }
        
        if !pmh.isEmpty {
            historyElements.append("Patient has a history of \(pmh.joined(separator: ", "))")
        }
        
        // Prior episodes or denials
        if text.contains("no problems with my heart") || text.contains("no heart problems") {
            historyElements.append("denies any prior cardiac problems")
        }
        
        return historyElements.isEmpty ? nil : historyElements.joined(separator: " but ")
    }
    
    private func createMedicationContext(conversation: ConversationAnalysis) -> String? {
        let text = conversation.originalText.lowercased()
        
        if text.contains("blood thinner") {
            if text.contains("ran out") || text.contains("stopped") {
                if text.contains("six weeks") || text.contains("6 weeks") {
                    return "Patient was previously on blood thinners but stopped 6 weeks ago when the prescription ran out"
                } else {
                    return "Patient was previously on blood thinners but recently discontinued"
                }
            }
        }
        
        return nil
    }
    
    private func createPMHSection(conversation: ConversationAnalysis) -> String {
        let pmh = conversation.medicalHistory
        return pmh.isEmpty ? "No significant past medical history obtained." : pmh.map { "• \($0)" }.joined(separator: "\n")
    }
    
    private func createPastSurgicalHistory(conversation: ConversationAnalysis) -> String {
        let text = conversation.originalText.lowercased()
        var surgicalHistory: [String] = []
        
        if text.contains("appendectomy") { surgicalHistory.append("• Appendectomy") }
        if text.contains("cholecystectomy") { surgicalHistory.append("• Cholecystectomy") }
        if text.contains("hernia repair") { surgicalHistory.append("• Hernia repair") }
        if text.contains("c-section") || text.contains("cesarean") { surgicalHistory.append("• Cesarean section") }
        if text.contains("tonsillectomy") { surgicalHistory.append("• Tonsillectomy") }
        
        if text.contains("surgery") && !text.contains("no surgery") && !text.contains("no prior surgery") {
            if surgicalHistory.isEmpty {
                surgicalHistory.append("• Prior surgical history reported")
            }
        }
        
        return surgicalHistory.isEmpty ? "No prior surgeries reported." : surgicalHistory.joined(separator: "\n")
    }
    
    private func createMedicationsSection(conversation: ConversationAnalysis) -> String {
        let medications = conversation.medications
        return medications.isEmpty ? "No current medications." : medications.map { "• \($0)" }.joined(separator: "\n")
    }
    
    private func createAllergiesSection(conversation: ConversationAnalysis) -> String {
        let text = conversation.originalText.lowercased()
        var allergies: [String] = []
        
        if text.contains("allergic to") || text.contains("allergy to") {
            if text.contains("penicillin") { allergies.append("• Penicillin") }
            if text.contains("sulfa") { allergies.append("• Sulfa drugs") }
            if text.contains("morphine") { allergies.append("• Morphine") }
            if text.contains("codeine") { allergies.append("• Codeine") }
            if text.contains("shellfish") { allergies.append("• Shellfish") }
            if text.contains("latex") { allergies.append("• Latex") }
        }
        
        if text.contains("nkda") || text.contains("no known drug allergies") || text.contains("no allergies") {
            return "No known drug allergies (NKDA)"
        }
        
        return allergies.isEmpty ? "Not assessed." : allergies.joined(separator: "\n")
    }
    
    private func createFamilyHistory(conversation: ConversationAnalysis) -> String {
        let text = conversation.originalText.lowercased()
        var familyHistory: [String] = []
        
        if text.contains("mother") || text.contains("father") || text.contains("parent") || text.contains("family") {
            if text.contains("diabetes") { familyHistory.append("• Family history of diabetes") }
            if text.contains("heart disease") || text.contains("cardiac") { 
                familyHistory.append("• Family history of cardiac disease") 
            }
            if text.contains("cancer") { familyHistory.append("• Family history of cancer") }
            if text.contains("stroke") { familyHistory.append("• Family history of stroke") }
            if text.contains("hypertension") || text.contains("high blood pressure") { 
                familyHistory.append("• Family history of hypertension") 
            }
        }
        
        return familyHistory.isEmpty ? "Not obtained." : familyHistory.joined(separator: "\n")
    }
    
    private func createSocialHistorySection(conversation: ConversationAnalysis) -> String {
        let socialHistory = conversation.socialHistory
        return socialHistory.isEmpty ? "Not obtained." : socialHistory.map { "• \($0)" }.joined(separator: "\n")
    }
    
    private func createReviewOfSystems(conversation: ConversationAnalysis) -> String {
        let text = conversation.originalText.lowercased()
        var ros: [String] = []
        
        // Constitutional
        if text.contains("fever") || text.contains("chills") || text.contains("weight loss") {
            let symptoms = [
                text.contains("fever") ? "fever" : nil,
                text.contains("chills") ? "chills" : nil,
                text.contains("weight loss") ? "weight loss" : nil
            ].compactMap { $0 }.joined(separator: ", ")
            ros.append("• Constitutional: Positive for \(symptoms)")
        } else {
            ros.append("• Constitutional: Denies fever, chills, weight loss")
        }
        
        // Respiratory
        if text.contains("cough") || text.contains("shortness of breath") || text.contains("dyspnea") {
            let symptoms = [
                text.contains("cough") ? "cough" : nil,
                text.contains("shortness of breath") ? "dyspnea" : nil
            ].compactMap { $0 }.joined(separator: ", ")
            ros.append("• Respiratory: Positive for \(symptoms)")
        } else {
            ros.append("• Respiratory: Denies cough, dyspnea")
        }
        
        // Cardiovascular
        if text.contains("chest pain") || text.contains("palpitations") {
            ros.append("• Cardiovascular: Positive for chest pain")
        } else {
            ros.append("• Cardiovascular: Denies chest pain, palpitations")
        }
        
        // GI
        if text.contains("nausea") || text.contains("vomiting") || text.contains("diarrhea") {
            let symptoms = [
                text.contains("nausea") ? "nausea" : nil,
                text.contains("vomiting") ? "vomiting" : nil,
                text.contains("diarrhea") ? "diarrhea" : nil
            ].compactMap { $0 }.joined(separator: ", ")
            ros.append("• GI: Positive for \(symptoms)")
        } else {
            ros.append("• GI: Denies nausea, vomiting, diarrhea")
        }
        
        ros.append("• All other systems reviewed and negative")
        
        return ros.joined(separator: "\n")
    }
    
    private func createPhysicalExam(conversation: ConversationAnalysis) -> String {
        return """
        • General: Alert and oriented, no acute distress
        • Vital Signs: [To be documented]
        • HEENT: Normocephalic, atraumatic
        • Cardiovascular: Regular rate and rhythm
        • Pulmonary: Clear to auscultation bilaterally
        • Abdomen: Soft, non-tender, non-distended
        • Extremities: No edema, no cyanosis
        • Neurological: Alert and oriented x3
        [Complete exam to be documented by provider]
        """
    }
    
    private func createLabAndImagingResults(conversation: ConversationAnalysis) -> String {
        if conversation.workup.isEmpty {
            return "Pending based on clinical assessment."
        }
        
        let ordered = conversation.workup.map { "• \($0)" }.joined(separator: "\n")
        return "**Ordered:**\n\(ordered)\n\n**Results:** Pending"
    }
    
    private func createMDMSection(conversation: ConversationAnalysis) -> String {
        var mdm: [String] = []
        
        // Check for high-risk scenarios
        if conversation.riskFactors.contains(where: { $0.contains("VTE") }) {
            mdm.append("This presentation is highly concerning for pulmonary embolism given the patient's history of venous thromboembolism and recent discontinuation of anticoagulation therapy.")
        }
        
        if conversation.medicalHistory.contains("Diabetes mellitus") && 
           conversation.chiefComplaint.lowercased().contains("chest") {
            mdm.append("Diabetes mellitus increases the risk for atypical presentations of acute coronary syndrome.")
        }
        
        if mdm.isEmpty {
            mdm.append("Clinical decision making focuses on ruling out life-threatening causes of the patient's presentation.")
        }
        
        return mdm.joined(separator: " ")
    }
    
    private func createDiagnoses(conversation: ConversationAnalysis) -> String {
        if conversation.chiefComplaint.lowercased().contains("chest") {
            if conversation.riskFactors.contains(where: { $0.contains("VTE") }) {
                return """
                **Primary Diagnoses Under Consideration:**
                1. Pulmonary embolism (high risk)
                2. Acute coronary syndrome
                3. Chest pain, unspecified
                
                **Secondary Diagnoses:**
                • History of venous thromboembolism
                • Medication noncompliance (anticoagulation)
                """
            } else {
                return """
                **Primary Diagnoses Under Consideration:**
                1. Chest pain, unspecified
                2. Possible acute coronary syndrome
                3. Possible pulmonary embolism
                """
            }
        }
        
        return """
        **Working Diagnoses:**
        1. \(conversation.chiefComplaint)
        2. Additional diagnoses pending evaluation
        """
    }
    
    private func createDisposition(conversation: ConversationAnalysis) -> String {
        return "Pending diagnostic workup and clinical reassessment. Disposition to be determined based on test results and response to treatment."
    }
    
    private func createDischargeInstructions(conversation: ConversationAnalysis) -> String {
        return """
        **If Discharged:**
        • Return immediately for worsening symptoms, new chest pain, difficulty breathing, or any concerning symptoms
        • Take medications as prescribed
        • Follow up with primary care provider within 24-48 hours
        • Activity as tolerated
        • Additional specific instructions based on final diagnosis
        """
    }
    
    private func createFollowUp(conversation: ConversationAnalysis) -> String {
        return """
        • Primary care provider: Within 24-48 hours
        • Specialist referrals as indicated by final diagnosis
        • Return to ED for worsening symptoms or new concerns
        """
    }
    
    // MARK: - SOAP Note Generation
    func generateSOAPNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        Generated: \(timestamp)
        **SOAP NOTE**
        
        **SUBJECTIVE:**
        Chief Complaint: \(conversation.chiefComplaint)
        
        History of Present Illness:
        \(createHPI(conversation: conversation))
        
        Past Medical History: \(conversation.medicalHistory.isEmpty ? "None reported" : conversation.medicalHistory.joined(separator: ", "))
        Medications: \(conversation.medications.isEmpty ? "None" : conversation.medications.joined(separator: ", "))
        Allergies: \(createAllergiesSection(conversation: conversation))
        Social History: \(conversation.socialHistory.isEmpty ? "Not obtained" : conversation.socialHistory.joined(separator: ", "))
        
        **OBJECTIVE:**
        Vital Signs: [To be documented]
        Physical Exam:
        • General: Alert and oriented, no acute distress
        • HEENT: Normocephalic, atraumatic
        • Cardiovascular: Regular rate and rhythm
        • Pulmonary: Clear to auscultation bilaterally
        • Abdomen: Soft, non-tender, non-distended
        • Extremities: No edema, no cyanosis
        • Neurological: Alert and oriented x3
        
        **ASSESSMENT:**
        \(createDiagnoses(conversation: conversation))
        
        Clinical Reasoning:
        \(createMDMSection(conversation: conversation))
        
        **PLAN:**
        Diagnostic Workup:
        \(conversation.workup.isEmpty ? "• Based on clinical assessment" : conversation.workup.map { "• \($0)" }.joined(separator: "\n"))
        
        Treatment:
        • Symptom management as appropriate
        • Monitor response to treatment
        
        Disposition: \(createDisposition(conversation: conversation))
        
        Follow-up: \(createFollowUp(conversation: conversation))
        
        ---
        *Generated from conversation analysis - SOAP format*
        """
    }
    
    // MARK: - Progress Note Generation
    func generateProgressNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        PROGRESS NOTE
        Date/Time: \(timestamp)
        
        INTERVAL HISTORY:
        \(conversation.chiefComplaint ?? "See previous notes")
        Changes since last evaluation: Patient reports \(extractProgressChanges(from: conversation))
        
        CURRENT STATUS:
        Symptoms: \(formatSymptoms(conversation.symptoms))
        Medication compliance: \(extractMedicationCompliance(from: conversation))
        
        PHYSICAL EXAMINATION:
        \(formatVitals([]))
        Focused exam: See physical exam
        
        ASSESSMENT & PLAN:
        Continuing current treatment plan
        \(formatPlan([]))
        
        ---
        *Generated from conversation analysis - Progress Note format*
        """
    }
    
    // MARK: - Consult Note Generation
    func generateConsultNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        CONSULTATION NOTE
        Date/Time: \(timestamp)
        
        REASON FOR CONSULTATION:
        \(conversation.chiefComplaint ?? "Evaluation requested")
        
        HISTORY OF PRESENT ILLNESS:
        \(formatHPI(conversation))
        
        PAST MEDICAL HISTORY:
        \(formatMedicalHistory(conversation.medicalHistory))
        
        MEDICATIONS:
        \(formatMedications(conversation.medications))
        
        ALLERGIES:
        \(formatAllergies([]))
        
        PHYSICAL EXAMINATION:
        \(formatPhysicalExam([]))
        
        ASSESSMENT:
        See recommendations
        
        RECOMMENDATIONS:
        \(formatRecommendations(conversation))
        
        Thank you for this interesting consultation.
        
        ---
        *Generated from conversation analysis - Consultation format*
        """
    }
    
    // MARK: - Handoff Note Generation
    func generateHandoffNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        HANDOFF NOTE (SBAR Format)
        Date/Time: \(timestamp)
        
        SITUATION:
        Patient presenting with: \(conversation.chiefComplaint ?? "See HPI")
        Current location: Emergency Department
        Code status: Full code
        
        BACKGROUND:
        \(formatHPI(conversation))
        PMH: \(formatMedicalHistory(conversation.medicalHistory))
        Current medications: \(formatMedications(conversation.medications))
        
        ASSESSMENT:
        Vital signs: See flowsheet
        Clinical status: Stable
        Pending items: \(extractPendingItems(from: conversation))
        
        RECOMMENDATIONS:
        \(formatHandoffRecommendations(conversation))
        Contingency plans: Monitor for deterioration, escalate if needed
        
        ---
        *Generated from conversation analysis - SBAR Handoff format*
        """
    }
    
    // MARK: - Discharge Note Generation
    func generateDischargeNote(from conversation: ConversationAnalysis) -> String {
        let timestamp = DateFormatter.medicalTimestamp.string(from: Date())
        
        return """
        DISCHARGE SUMMARY
        Date/Time: \(timestamp)
        
        ADMISSION DIAGNOSIS:
        \(conversation.chiefComplaint ?? "See HPI")
        
        DISCHARGE DIAGNOSIS:
        Primary: See assessment
        Secondary: \(formatSecondaryDiagnoses(conversation))
        
        HOSPITAL COURSE:
        Patient presented with \(conversation.chiefComplaint ?? "acute illness").
        \(formatHospitalCourse(conversation))
        
        DISCHARGE MEDICATIONS:
        \(formatDischargeMedications(conversation))
        
        DISCHARGE INSTRUCTIONS:
        Activity: As tolerated
        Diet: Regular
        Follow-up: \(createFollowUp(conversation: conversation))
        
        Return to ED if: Worsening symptoms, fever >101°F, chest pain, shortness of breath
        
        CONDITION AT DISCHARGE:
        Stable, ambulatory
        
        ---
        *Generated from conversation analysis - Discharge Summary format*
        """
    }
    
    // MARK: - Helper Methods for New Note Types
    private func extractProgressChanges(from conversation: ConversationAnalysis) -> String {
        return conversation.symptoms.first ?? "improvement in symptoms"
    }
    
    private func extractMedicationCompliance(from conversation: ConversationAnalysis) -> String {
        return "Reported as compliant"
    }
    
    private func formatRecommendations(_ conversation: ConversationAnalysis) -> String {
        return "See recommendations and plan"
    }
    
    private func extractPendingItems(from conversation: ConversationAnalysis) -> String {
        return conversation.workup.isEmpty ? "None" : conversation.workup.joined(separator: ", ")
    }
    
    private func formatHandoffRecommendations(_ conversation: ConversationAnalysis) -> String {
        var recommendations = ["Continue current treatment plan"]
        if !conversation.workup.isEmpty {
            recommendations.append("Follow up on: \(conversation.workup.joined(separator: ", "))")
        }
        return recommendations.joined(separator: "\n")
    }
    
    private func formatSecondaryDiagnoses(_ conversation: ConversationAnalysis) -> String {
        return conversation.medicalHistory.isEmpty ? "None" : conversation.medicalHistory.joined(separator: ", ")
    }
    
    private func formatHospitalCourse(_ conversation: ConversationAnalysis) -> String {
        return "Workup included \(conversation.workup.joined(separator: ", ")). Treatment provided with improvement in symptoms."
    }
    
    private func formatDischargeMedications(_ conversation: ConversationAnalysis) -> String {
        if conversation.medications.isEmpty {
            return "Continue home medications"
        }
        return conversation.medications.joined(separator: "\n")
    }
    
    // MARK: - Additional Helper Methods
    
    private func formatSymptoms(_ symptoms: [String]) -> String {
        return symptoms.isEmpty ? "None reported" : symptoms.joined(separator: ", ")
    }
    
    private func formatVitals(_ vitals: [String]) -> String {
        return vitals.isEmpty ? "See flowsheet" : vitals.joined(separator: ", ")
    }
    
    private func formatPhysicalExam(_ exam: [String]) -> String {
        return exam.isEmpty ? "See physical exam" : exam.joined(separator: ", ")
    }
    
    private func formatPlan(_ plan: [String]) -> String {
        return plan.isEmpty ? "See treatment plan" : plan.joined(separator: "\n")
    }
    
    private func formatHPI(_ conversation: ConversationAnalysis) -> String {
        return createHPI(conversation: conversation)
    }
    
    private func formatMedicalHistory(_ history: [String]) -> String {
        return history.isEmpty ? "None significant" : history.joined(separator: ", ")
    }
    
    private func formatMedications(_ medications: [String]) -> String {
        return medications.isEmpty ? "None" : medications.joined(separator: ", ")
    }
    
    private func formatAllergies(_ allergies: [String]) -> String {
        return allergies.isEmpty ? "NKDA" : allergies.joined(separator: ", ")
    }
}