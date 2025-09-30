import Foundation

/// Advanced medical prompt engineering for human-scribe-level documentation
class AdvancedMedicalPromptEngine {
    
    // MARK: - Ultra-Sophisticated Medical Note Generation
    static func generateUltraAccurateMedicalNote(
        transcript: String,
        noteType: NoteType,
        clinicalContext: String = "",
        patientDemographics: PatientDemographics? = nil
    ) -> String {
        
        let systemPrompt = """
        You are an expert medical scribe with 20+ years of experience in emergency medicine, internal medicine, and clinical documentation. You have:
        
        EXPERTISE:
        • Board certification in medical documentation
        • Deep understanding of ICD-10, CPT coding, and E/M guidelines
        • Extensive knowledge of medical terminology, anatomy, physiology, and pathophysiology
        • Experience with all medical specialties and subspecialties
        • Understanding of clinical workflows and physician documentation requirements
        • Familiarity with CMS guidelines, quality measures, and regulatory requirements
        
        DOCUMENTATION PRINCIPLES:
        1. ACCURACY: Every medical term must be precisely correct. Never guess medical terminology.
        2. COMPLETENESS: Capture ALL clinically relevant information, including negatives
        3. CLARITY: Use clear, professional medical language that other physicians will understand
        4. CONTEXT: Understand implied clinical reasoning and fill in standard medical workflows
        5. COMPLIANCE: Follow documentation guidelines for medical necessity and billing
        6. OBJECTIVITY: Document only what was stated or can be clinically inferred
        
        CRITICAL REQUIREMENTS:
        • Use proper medical abbreviations (BP, HR, RR, O2 sat, etc.)
        • Include pertinent negatives (what the patient denies)
        • Document in standard medical format with appropriate sections
        • Maintain chronological accuracy for symptom progression
        • Include all medications with doses, routes, and frequencies when mentioned
        • Document all vital signs with units
        • Use appropriate medical terminology (dyspnea not "trouble breathing")
        • Include relevant social history if mentioned
        • Document allergies and reactions
        • Note any red flag symptoms
        
        LISTENING SKILLS:
        • Recognize when numbers are vital signs (e.g., "120 over 80" = BP 120/80)
        • Understand medical context (e.g., "sugar" often means diabetes/glucose)
        • Identify medication names even if mispronounced
        • Recognize symptom descriptions in lay terms and translate to medical terms
        • Understand temporal relationships (onset, duration, progression)
        • Identify severity indicators (mild, moderate, severe, 7/10 pain)
        
        CLINICAL REASONING:
        • Infer likely differential diagnoses from symptom constellation
        • Recognize classic presentations (e.g., chest pain + SOB + diaphoresis = possible ACS)
        • Understand which review of systems questions are relevant
        • Know which physical exam findings would be pertinent
        • Recognize when additional history is clinically important
        
        OUTPUT REQUIREMENTS:
        • Each section should flow naturally but maintain clinical precision
        • Use numbered lists for multiple conditions/medications
        • Include time stamps when provided
        • Document decision-making rationale in Assessment/Plan
        • Include follow-up instructions and return precautions
        • Note any patient education provided
        """
        
        let noteSpecificInstructions = getNoteTypeSpecificInstructions(noteType)
        
        let transcriptAnalysisPrompt = """
        Analyze this medical encounter transcript with extreme attention to detail:
        
        TRANSCRIPT:
        \(transcript)
        
        \(clinicalContext.isEmpty ? "" : "CLINICAL CONTEXT:\n\(clinicalContext)\n")
        \(patientDemographics?.description ?? "")
        
        ANALYSIS REQUIREMENTS:
        
        1. IDENTIFY ALL MEDICAL INFORMATION:
           • Chief complaint (exact words if possible)
           • Every symptom mentioned with all characteristics (OLDCARTS)
           • All medications (current and new)
           • All medical conditions (past and present)
           • All vital signs
           • All test results
           • All procedures mentioned
           
        2. TEMPORAL ANALYSIS:
           • When did symptoms start?
           • How have they progressed?
           • What is the sequence of events?
           • Any triggers or patterns?
           
        3. CLINICAL CORRELATION:
           • What symptoms go together?
           • What is the likely diagnosis?
           • What are the red flags?
           • What needs immediate attention?
           
        4. DOCUMENTATION GAPS:
           • What information is clinically necessary but missing?
           • What would typically be asked but wasn't?
           • What exam findings would be expected?
           
        5. PATIENT SAFETY:
           • Any allergies mentioned?
           • Any contraindications?
           • Any high-risk features?
           • Any need for urgent intervention?
        
        Now generate a \(noteType.rawValue) note that would pass any medical audit and peer review.
        
        \(noteSpecificInstructions)
        
        CRITICAL: 
        - If information is unclear or missing, note it appropriately (e.g., "not documented", "not assessed")
        - Never fabricate medical information
        - Include all pertinent positives AND negatives
        - Maintain medical-legal documentation standards
        """
        
        return systemPrompt + "\n\n" + transcriptAnalysisPrompt
    }
    
    // MARK: - Note Type Specific Instructions
    private static func getNoteTypeSpecificInstructions(_ noteType: NoteType) -> String {
        switch noteType {
        case .soap:
            return """
            Generate a SOAP note with these sections:
            
            SUBJECTIVE:
            • Chief Complaint: Direct quote if available
            • History of Present Illness: Full OLDCARTS narrative
            • Review of Systems: Comprehensive, organized by system
            • Past Medical History: All conditions
            • Medications: Complete list with doses
            • Allergies: With reaction types
            • Social History: Relevant habits
            • Family History: If relevant
            
            OBJECTIVE:
            • Vital Signs: All values with units
            • Physical Exam: Pertinent findings by system
            • Diagnostic Results: Any tests mentioned
            
            ASSESSMENT:
            • Primary diagnosis or symptom
            • Differential diagnoses (numbered)
            • Clinical reasoning
            • Risk stratification
            
            PLAN:
            • Diagnostic workup (labs, imaging)
            • Therapeutic interventions
            • Medications prescribed
            • Patient education
            • Follow-up instructions
            • Return precautions
            """
            
        case .edNote:
            return """
            Generate an Emergency Department note:
            
            CHIEF COMPLAINT: (Quote patient's words)
            
            HISTORY OF PRESENT ILLNESS:
            • Detailed narrative with complete timeline
            • Include all pertinent positives and negatives
            • Document severity, quality, and associated symptoms
            • Note what makes symptoms better/worse
            • Include relevant past episodes
            
            REVIEW OF SYSTEMS:
            Constitutional: (fever, chills, weight loss, fatigue)
            HEENT: (headache, vision changes, hearing loss, sore throat)
            Cardiovascular: (chest pain, palpitations, edema)
            Respiratory: (SOB, cough, wheezing, hemoptysis)
            GI: (nausea, vomiting, diarrhea, abdominal pain)
            GU: (dysuria, frequency, hematuria)
            Musculoskeletal: (joint pain, swelling, weakness)
            Neurological: (numbness, tingling, weakness, seizures)
            Psychiatric: (depression, anxiety, SI/HI)
            Skin: (rash, wounds, lesions)
            
            PAST MEDICAL HISTORY:
            
            MEDICATIONS: (Include dose, route, frequency)
            
            ALLERGIES: (Include reaction)
            
            SOCIAL HISTORY: (Tobacco, alcohol, drugs, occupation)
            
            PHYSICAL EXAMINATION:
            General: (appearance, distress level)
            Vital Signs: (BP, HR, RR, Temp, O2 sat, pain score)
            HEENT: (normocephalic, PERRL, TMs clear, oropharynx clear)
            Neck: (supple, no LAD, no JVD)
            Cardiovascular: (rate, rhythm, murmurs, pulses)
            Pulmonary: (effort, breath sounds, wheezes/rales)
            Abdomen: (soft, tender/nontender, bowel sounds)
            Extremities: (edema, pulses, skin changes)
            Neurological: (alert, oriented, strength, sensation)
            Skin: (warm, dry, rashes, wounds)
            
            EMERGENCY DEPARTMENT COURSE:
            • Timeline of care
            • Interventions performed
            • Response to treatment
            • Test results and interpretation
            
            MEDICAL DECISION MAKING:
            • Differential diagnosis with reasoning
            • Why admission/discharge
            • Risk stratification
            • Critical decisions explained
            
            ASSESSMENT AND PLAN:
            1. [Primary diagnosis]: 
               - Workup: 
               - Treatment: 
               - Disposition: 
            
            2. [Secondary diagnoses...]
            
            DISPOSITION: (Admit/Discharge/Transfer)
            
            DISCHARGE INSTRUCTIONS: (If applicable)
            • Diagnosis explained
            • Medications
            • Follow-up
            • Return precautions
            • Activity restrictions
            """
            
        case .progress:
            return """
            Generate a Progress Note:
            
            INTERVAL HISTORY:
            • Changes since last visit
            • Response to treatment
            • New symptoms or concerns
            • Medication compliance
            • Side effects
            
            REVIEW OF SYSTEMS: (Focused on active issues)
            
            PHYSICAL EXAM: (Focused, with changes from baseline)
            
            DIAGNOSTIC RESULTS: (New results with interpretation)
            
            ASSESSMENT:
            • Problem list with status (improved/stable/worsening)
            • Clinical reasoning for changes
            
            PLAN:
            • Modifications to treatment
            • Continued therapies
            • New interventions
            • Monitoring parameters
            • Next steps
            """
            
        case .discharge:
            return """
            Generate a Discharge Summary:
            
            ADMISSION DATE:
            DISCHARGE DATE:
            
            ADMITTING DIAGNOSIS:
            
            DISCHARGE DIAGNOSES:
            Principal:
            Secondary:
            
            HOSPITAL COURSE:
            • Chronological narrative
            • Major events and interventions
            • Response to treatment
            • Complications if any
            
            PROCEDURES PERFORMED:
            
            DISCHARGE MEDICATIONS: (Complete reconciliation)
            
            DISCHARGE CONDITION:
            
            DISCHARGE INSTRUCTIONS:
            • Activity
            • Diet
            • Wound care
            • Medication instructions
            
            FOLLOW-UP APPOINTMENTS:
            
            PENDING RESULTS:
            
            CODE STATUS:
            """
            
        case .consult:
            return """
            Generate a Consultation Note:
            
            REASON FOR CONSULTATION:
            
            HISTORY OF PRESENT ILLNESS:
            • Detailed relevant history
            • Previous workup and treatments
            • Response to interventions
            
            PAST MEDICAL HISTORY: (Relevant to consultation)
            
            PHYSICAL EXAMINATION: (Focused on consultation issue)
            
            DIAGNOSTIC DATA: (Review and interpretation)
            
            ASSESSMENT:
            • Expert opinion on diagnosis
            • Severity assessment
            • Prognosis
            
            RECOMMENDATIONS:
            1. Diagnostic recommendations
            2. Therapeutic recommendations
            3. Monitoring recommendations
            4. Follow-up plan
            
            Thank you for this interesting consultation.
            """
            
        case .handoff:
            return "Generate a comprehensive medical note following standard medical documentation practices."
        }
    }
    
    // MARK: - Enhanced Context Analysis
    static func analyzeTranscriptForMedicalContext(_ transcript: String) -> MedicalContextAnalysis {
        var analysis = MedicalContextAnalysis()
        
        // Detect setting
        analysis.setting = detectClinicalSetting(transcript)
        
        // Extract vital signs
        analysis.vitalSigns = extractVitalSigns(transcript)
        
        // Identify symptoms with characteristics
        analysis.symptoms = extractSymptomsWithCharacteristics(transcript)
        
        // Extract medications
        analysis.medications = extractMedicationsWithDetails(transcript)
        
        // Identify red flags
        analysis.redFlags = identifyRedFlags(transcript)
        
        // Determine urgency
        analysis.urgencyLevel = determineUrgencyLevel(transcript)
        
        return analysis
    }
    
    private static func detectClinicalSetting(_ transcript: String) -> String {
        if transcript.contains("emergency") || transcript.contains("ER") || transcript.contains("ED") {
            return "Emergency Department"
        } else if transcript.contains("clinic") || transcript.contains("office") {
            return "Outpatient Clinic"
        } else if transcript.contains("hospital") || transcript.contains("admitted") {
            return "Inpatient"
        } else if transcript.contains("urgent care") {
            return "Urgent Care"
        }
        return "Clinical Setting"
    }
    
    private static func extractVitalSigns(_ transcript: String) -> [String: String] {
        var vitals: [String: String] = [:]
        
        // Blood pressure pattern
        if let bpMatch = transcript.range(of: #"(\d{2,3})\s*[/over]\s*(\d{2,3})"#, options: .regularExpression) {
            let bp = transcript[bpMatch]
            vitals["Blood Pressure"] = String(bp)
        }
        
        // Heart rate
        if let hrMatch = transcript.range(of: #"(heart rate|pulse|HR).*?(\d{2,3})"#, options: .regularExpression) {
            let hr = transcript[hrMatch]
            vitals["Heart Rate"] = String(hr)
        }
        
        // Temperature
        if let tempMatch = transcript.range(of: #"(temp|temperature|fever).*?(\d{2,3}\.?\d?)"#, options: .regularExpression) {
            let temp = transcript[tempMatch]
            vitals["Temperature"] = String(temp)
        }
        
        // Oxygen saturation
        if let o2Match = transcript.range(of: #"(O2|oxygen|sat).*?(\d{2,3})"#, options: .regularExpression) {
            let o2 = transcript[o2Match]
            vitals["O2 Saturation"] = String(o2)
        }
        
        return vitals
    }
    
    private static func extractSymptomsWithCharacteristics(_ transcript: String) -> [SymptomDetail] {
        var symptoms: [SymptomDetail] = []
        
        // Common symptom patterns
        let symptomPatterns = [
            "chest pain", "shortness of breath", "headache", "abdominal pain",
            "nausea", "vomiting", "diarrhea", "fever", "cough", "fatigue",
            "dizziness", "weakness", "numbness", "tingling", "rash",
            "swelling", "pain", "discomfort", "pressure", "tightness"
        ]
        
        for pattern in symptomPatterns {
            if let range = transcript.range(of: pattern, options: .caseInsensitive) {
                var symptom = SymptomDetail(name: pattern)
                
                // Look for severity
                let contextStart = transcript.index(range.lowerBound, offsetBy: -50, limitedBy: transcript.startIndex) ?? transcript.startIndex
                let contextEnd = transcript.index(range.upperBound, offsetBy: 50, limitedBy: transcript.endIndex) ?? transcript.endIndex
                let context = String(transcript[contextStart..<contextEnd])
                
                // Extract severity
                if context.contains("severe") || context.contains("10/10") || context.contains("worst") {
                    symptom.severity = "severe"
                } else if context.contains("moderate") || context.contains("5/10") || context.contains("6/10") {
                    symptom.severity = "moderate"
                } else if context.contains("mild") || context.contains("2/10") || context.contains("3/10") {
                    symptom.severity = "mild"
                }
                
                // Extract duration
                if let durationMatch = context.range(of: #"(\d+)\s*(hours?|days?|weeks?|months?)"#, options: .regularExpression) {
                    symptom.duration = String(context[durationMatch])
                }
                
                // Extract location
                if pattern.contains("pain") {
                    if context.contains("left") { symptom.location = "left" }
                    if context.contains("right") { symptom.location = "right" }
                    if context.contains("bilateral") { symptom.location = "bilateral" }
                }
                
                symptoms.append(symptom)
            }
        }
        
        return symptoms
    }
    
    private static func extractMedicationsWithDetails(_ transcript: String) -> [MedicationDetail] {
        var medications: [MedicationDetail] = []
        
        // Common medication patterns
        let medicationPatterns = [
            "aspirin", "tylenol", "ibuprofen", "metformin", "lisinopril",
            "atorvastatin", "metoprolol", "amlodipine", "omeprazole",
            "levothyroxine", "gabapentin", "hydrochlorothiazide"
        ]
        
        for pattern in medicationPatterns {
            if transcript.lowercased().contains(pattern) {
                var medication = MedicationDetail(name: pattern)
                
                // Look for dose
                if let doseMatch = transcript.range(of: "\(pattern).*?(\\d+\\s*mg)", options: [.caseInsensitive, .regularExpression]) {
                    let doseText = transcript[doseMatch]
                    medication.dose = String(doseText)
                }
                
                medications.append(medication)
            }
        }
        
        return medications
    }
    
    private static func identifyRedFlags(_ transcript: String) -> [String] {
        var redFlags: [String] = []
        
        let redFlagPatterns = [
            "chest pain": "Possible cardiac event",
            "worst headache": "Possible subarachnoid hemorrhage",
            "difficulty breathing": "Respiratory distress",
            "slurred speech": "Possible stroke",
            "confusion": "Altered mental status",
            "severe abdominal pain": "Possible surgical abdomen",
            "suicidal": "Suicide risk",
            "unconscious": "Loss of consciousness",
            "bleeding": "Active hemorrhage",
            "allergic reaction": "Possible anaphylaxis"
        ]
        
        for (pattern, flag) in redFlagPatterns {
            if transcript.lowercased().contains(pattern) {
                redFlags.append(flag)
            }
        }
        
        return redFlags
    }
    
    private static func determineUrgencyLevel(_ transcript: String) -> String {
        if transcript.contains("emergency") || transcript.contains("severe") || transcript.contains("immediately") {
            return "EMERGENT"
        } else if transcript.contains("urgent") || transcript.contains("soon") {
            return "URGENT"
        }
        return "ROUTINE"
    }
    
    // MARK: - Supporting Types
    struct MedicalContextAnalysis {
        var setting: String = ""
        var vitalSigns: [String: String] = [:]
        var symptoms: [SymptomDetail] = []
        var medications: [MedicationDetail] = []
        var redFlags: [String] = []
        var urgencyLevel: String = "ROUTINE"
    }
    
    struct SymptomDetail {
        var name: String
        var severity: String?
        var duration: String?
        var location: String?
        var quality: String?
        var associatedSymptoms: [String] = []
    }
    
    struct MedicationDetail {
        var name: String
        var dose: String?
        var frequency: String?
        var route: String?
    }
    
    struct PatientDemographics {
        let age: Int?
        let gender: String?
        let relevantHistory: [String]
        
        var description: String {
            var desc = "PATIENT DEMOGRAPHICS:\n"
            if let age = age { desc += "Age: \(age)\n" }
            if let gender = gender { desc += "Gender: \(gender)\n" }
            if !relevantHistory.isEmpty {
                desc += "Relevant History: \(relevantHistory.joined(separator: ", "))\n"
            }
            return desc
        }
    }
}