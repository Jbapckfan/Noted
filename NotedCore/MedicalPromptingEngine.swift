import Foundation

// MARK: - Medical Prompting System for Emergency Medicine
class MedicalPromptingEngine {
    
    // MARK: - Core Prompt Templates
    
    static let emergencyMedicineSystemPrompt = """
    You are an expert emergency medicine physician assistant specializing in clinical documentation. Your role is to transform physician-patient conversations into professional emergency department notes.

    CRITICAL INSTRUCTIONS:
    1. ANALYZE ONLY what is actually discussed in the conversation - NEVER generate fake symptoms or data
    2. SUMMARIZE the conversation - do NOT quote dialogue verbatim
    3. Extract ONLY clinical information explicitly mentioned by patient or physician
    4. Use proper medical terminology and abbreviations
    5. Follow emergency medicine documentation standards
    6. Include REAL differential diagnosis based on actual presentation described
    7. Structure notes according to standard medical format
    8. Focus on emergency medicine priorities (sick vs not sick, disposition)
    9. NEVER add symptoms, conditions, or findings not mentioned in conversation

    EMERGENCY MEDICINE PRIORITIES:
    - Time-sensitive conditions (MI, stroke, sepsis, trauma)
    - Life-threatening diagnoses (PE, aortic dissection, pneumothorax)
    - High-risk presentations requiring immediate workup
    - Proper risk stratification and disposition planning

    DO NOT INCLUDE:
    - Direct quotes like "Patient states..." or "Physician asked..."
    - Conversational dialogue format
    - Transcript-style repetition of questions and answers

    OUTPUT FORMAT: Professional clinical summary suitable for medical record
    """
    
    static let soapNoteTemplate = """
    Generate a professional emergency department SOAP note by analyzing and summarizing this conversation:

    CONVERSATION:
    {transcription}

    REQUIRED STRUCTURE:
    **CHIEF COMPLAINT:** [Primary reason for visit - brief clinical statement]

    **HISTORY OF PRESENT ILLNESS:**
    [Professional clinical narrative summarizing:
    - Onset, location, duration, character, aggravating/relieving factors
    - Associated symptoms described by patient
    - Pertinent negatives identified during interview
    - Previous treatments attempted]

    **PAST MEDICAL HISTORY:** [Medical conditions mentioned]
    **MEDICATIONS:** [Current medications discussed]
    **ALLERGIES:** [Known allergies mentioned]
    **SOCIAL HISTORY:** [Relevant social history obtained]

    **REVIEW OF SYSTEMS:** [Clinical review based on symptoms discussed]

    **ASSESSMENT AND PLAN:**
    [Professional clinical reasoning including:
    - Clinical summary statement
    - Prioritized differential diagnosis with rationale
    - Planned diagnostic workup
    - Treatment interventions
    - Disposition planning]

    CRITICAL REQUIREMENTS:
    - Write in third person medical narrative style
    - Summarize and synthesize information, do not quote dialogue
    - Use professional medical language throughout
    - Only include information explicitly discussed in conversation
    - NEVER generate fake symptoms, vital signs, or medical data
    - Base differential diagnosis ONLY on symptoms actually described by patient
    - If information is missing, state "not discussed" rather than inventing data
    """
    
    // MARK: - Specialized Prompts by Chief Complaint
    
    static func chestPainPrompt(transcription: String) -> String {
        return """
        Create an emergency department note for this CHEST PAIN patient:

        TRANSCRIPTION: \(transcription)

        FOCUS ON:
        - Cardiac risk stratification (age, gender, risk factors)
        - Character of pain (crushing, sharp, pleuritic, etc.)
        - Radiation pattern (jaw, arm, back)
        - Associated symptoms (SOB, diaphoresis, nausea)
        - Triggers/timing (exertional, at rest)
        - Response to interventions (nitro, aspirin)

        DIFFERENTIAL DIAGNOSIS PRIORITIES:
        1. Acute Coronary Syndrome (STEMI/NSTEMI/Unstable Angina)
        2. Pulmonary Embolism
        3. Aortic Dissection
        4. Pneumothorax (spontaneous/tension)
        5. Pneumonia/Pneumonitis
        6. Esophageal spasm/rupture
        7. Pericarditis/Myocarditis
        8. Pleuritis/Pleurisy
        9. Costochondritis/Musculoskeletal
        10. GERD/Peptic ulcer disease

        Include clinical reasoning for each diagnosis based on presentation.
        """
    }
    
    static func abdominalPainPrompt(transcription: String) -> String {
        return """
        Create an emergency department note for this ABDOMINAL PAIN patient:

        TRANSCRIPTION: \(transcription)

        FOCUS ON:
        - Pain location and migration
        - Character (crampy, constant, colicky)
        - Associated symptoms (nausea, vomiting, fever, changes in bowel habits)
        - Menstrual history (if applicable)
        - Surgical history

        DIFFERENTIAL DIAGNOSIS PRIORITIES:
        1. Acute surgical abdomen (appendicitis, perforation, obstruction)
        2. Gynecologic emergencies (ectopic, ovarian torsion)
        3. Urologic pathology (stones, UTI)
        4. Vascular emergencies (AAA, mesenteric ischemia)
        5. Medical causes (gastroenteritis, IBD)

        Include clinical reasoning and risk stratification.
        """
    }
    
    static func shortnessOfBreathPrompt(transcription: String) -> String {
        return """
        Create an emergency department note for this SHORTNESS OF BREATH patient:

        TRANSCRIPTION: \(transcription)

        FOCUS ON:
        - Onset (acute vs gradual)
        - Exertional tolerance
        - Associated symptoms (chest pain, palpitations, fever)
        - Cardiac/pulmonary history
        - Risk factors for PE/CHF

        DIFFERENTIAL DIAGNOSIS PRIORITIES:
        1. Pulmonary Embolism
        2. Acute Heart Failure
        3. Pneumonia
        4. Asthma/COPD exacerbation
        5. Pneumothorax
        6. Acute Coronary Syndrome

        Include Wells criteria for PE and clinical reasoning.
        """
    }
    
    // MARK: - Note Format Templates
    
    static let soapFormat = """
    **SUBJECTIVE:**
    Chief Complaint: {chief_complaint}
    
    HPI: {hpi}
    
    PMH: {pmh}
    Medications: {medications}
    Allergies: {allergies}
    Social History: {social_history}
    
    ROS: {ros}

    **OBJECTIVE:**
    [Physical exam findings and vital signs to be documented during encounter]

    **ASSESSMENT:**
    {assessment}

    **PLAN:**
    {plan}
    """
    
    static let narrativeFormat = """
    **EMERGENCY DEPARTMENT NOTE**
    
    {summary_statement}
    
    {clinical_narrative}
    
    **Assessment and Plan:**
    {differential_diagnosis}
    
    {treatment_plan}
    
    **Disposition:**
    {disposition}
    """
    
    // MARK: - Prompt Selection Logic
    
    static func selectPrompt(for transcription: String, noteType: NoteType) -> String {
        let content = transcription.lowercased()
        
        // Chief complaint detection
        let chiefComplaint = detectChiefComplaint(from: content)
        
        switch noteType {
        case .edNote:
            return generateEDNotePrompt(transcription: transcription, chiefComplaint: chiefComplaint)
        case .soap:
            return generateSOAPNotePrompt(transcription: transcription, chiefComplaint: chiefComplaint)
        case .progress, .consult, .handoff, .discharge:
            // Use SOAP format as default for other note types
            return generateSOAPNotePrompt(transcription: transcription, chiefComplaint: chiefComplaint)
        }
    }
    
    // MARK: - ED Note Prompt Generation
    
    static func generateEDNotePrompt(transcription: String, chiefComplaint: ChiefComplaint) -> String {
        return """
        Create a comprehensive Emergency Department Note by analyzing and summarizing this clinical conversation. Write in professional medical documentation style.

        CONVERSATION TO ANALYZE:
        \(transcription)

        PRIMARY PRESENTATION: \(chiefComplaint.description)

        GENERATE COMPREHENSIVE NOTE WITH ALL SECTIONS:

        **CHIEF COMPLAINT:**
        [Brief clinical statement of primary concern]

        **HISTORY OF PRESENT ILLNESS:**
        [Comprehensive narrative summary of current illness including onset, progression, associated symptoms, and relevant timeline]

        **PAST MEDICAL HISTORY:**
        [Relevant medical conditions and surgical history mentioned]

        **MEDICATIONS:**
        [Current medications with dosages if provided]

        **ALLERGIES:**
        [Known allergies or state NKDA if none mentioned]

        **FAMILY HISTORY:**
        [Relevant family medical history discussed]

        **SOCIAL HISTORY:**
        [Pertinent social factors including tobacco, alcohol, occupation]

        **REVIEW OF SYSTEMS:**
        [Systematic review based on symptoms discussed during encounter]

        **PHYSICAL EXAM:**
        [Document any physical findings mentioned or note "pending" if not performed]

        **DIAGNOSTIC RESULTS:**
        [Lab values, imaging results, or other tests mentioned]

        **MEDICAL DECISION MAKING:**
        [Clinical reasoning, risk assessment, and differential diagnosis considerations]

        **ASSESSMENT:**
        [Primary and secondary diagnoses with ICD-appropriate terminology]

        **PLAN:**
        [Treatment plan, disposition, medications, and follow-up instructions]

        DOCUMENTATION REQUIREMENTS:
        - Write in third person clinical narrative style
        - Use proper medical terminology and standard abbreviations
        - Summarize conversation content professionally
        - Do not include direct dialogue quotes or conversational format
        - Focus on clinically relevant information only
        """
    }
    
    // MARK: - SOAP Note Prompt Generation
    
    static func generateSOAPNotePrompt(transcription: String, chiefComplaint: ChiefComplaint) -> String {
        return """
        Generate a professional SOAP note by analyzing and summarizing this clinical conversation:

        CONVERSATION:
        \(transcription)

        CLINICAL CONTEXT: \(chiefComplaint.description)

        STRUCTURE YOUR CLINICAL SUMMARY AS:

        **SUBJECTIVE:**
        Chief Complaint: [Brief statement of primary concern]
        
        History of Present Illness: [Narrative summary of current symptoms, onset, duration, associated factors, and timeline without quoting dialogue]
        
        Review of Systems: [Summary of pertinent positives and negatives discussed]
        
        Past Medical History: [Relevant conditions mentioned]
        Medications: [Current medications discussed]
        Allergies: [Known allergies or NKDA]
        Social History: [Relevant social factors]

        **OBJECTIVE:**
        Vital Signs: [Document if mentioned or indicate "to be obtained"]
        Physical Examination: [Document findings mentioned or indicate "pending"]
        Diagnostic Studies: [Results mentioned or tests ordered]

        **ASSESSMENT:**
        [Clinical impression and reasoning]
        [Differential diagnosis considerations with rationale]

        **PLAN:**
        [Diagnostic workup planned]
        [Treatment interventions]
        [Disposition and follow-up]

        CRITICAL FORMATTING REQUIREMENTS:
        - Write in professional medical narrative style
        - Use third person clinical language
        - Synthesize and summarize information from conversation
        - Avoid direct quotes or dialogue format
        - Use standard medical terminology and abbreviations
        """
    }
    
    // MARK: - Chief Complaint Detection
    
    static func detectChiefComplaint(from content: String) -> ChiefComplaint {
        let chestPainKeywords = ["chest pain", "chest discomfort", "heart", "cardiac"]
        let abdominalKeywords = ["abdominal pain", "stomach", "belly", "nausea", "vomiting"]
        let sobKeywords = ["shortness of breath", "dyspnea", "breathing", "sob"]
        let headacheKeywords = ["headache", "head pain", "migraine"]
        
        if chestPainKeywords.contains(where: content.contains) {
            return .chestPain
        } else if abdominalKeywords.contains(where: content.contains) {
            return .abdominalPain
        } else if sobKeywords.contains(where: content.contains) {
            return .shortnessOfBreath
        } else if headacheKeywords.contains(where: content.contains) {
            return .headache
        }
        
        return .general
    }
    
    // MARK: - Specialized Prompt Generators
    
    static func generateNarrativePrompt(transcription: String, chiefComplaint: ChiefComplaint) -> String {
        let basePrompt = """
        Generate a narrative emergency department note from this transcription:
        
        TRANSCRIPTION: \(transcription)
        
        Create a flowing narrative that tells the story of this patient's presentation, 
        including clinical reasoning and decision-making process.
        """
        
        switch chiefComplaint {
        case .chestPain:
            return basePrompt + "\n\nFocus on cardiac risk stratification and ruling out life-threatening causes."
        case .abdominalPain:
            return basePrompt + "\n\nFocus on surgical emergencies and systematic evaluation."
        case .shortnessOfBreath:
            return basePrompt + "\n\nFocus on cardiopulmonary causes and risk stratification."
        default:
            return basePrompt
        }
    }
    
    static func generateStructuredPrompt(transcription: String, chiefComplaint: ChiefComplaint) -> String {
        return """
        Generate a structured emergency department note with clear sections:
        
        TRANSCRIPTION: \(transcription)
        
        STRUCTURE:
        1. PRESENTATION
        2. CLINICAL ASSESSMENT  
        3. DIFFERENTIAL DIAGNOSIS
        4. DIAGNOSTIC PLAN
        5. TREATMENT PLAN
        6. DISPOSITION
        
        Use bullet points and clear organization for easy reference.
        """
    }
    
    static func generateDifferentialPrompt(transcription: String, chiefComplaint: ChiefComplaint) -> String {
        return """
        Generate a note focused on differential diagnosis and clinical reasoning:
        
        TRANSCRIPTION: \(transcription)
        
        EMPHASIZE:
        - Detailed differential diagnosis with likelihood assessment
        - Clinical reasoning for inclusion/exclusion of diagnoses
        - Risk stratification
        - Diagnostic strategy to differentiate conditions
        
        Format as clinical reasoning exercise suitable for teaching.
        """
    }
    
}

// MARK: - Supporting Enums

enum ChiefComplaint {
    case chestPain
    case abdominalPain
    case shortnessOfBreath
    case headache
    case general
    
    var description: String {
        switch self {
        case .chestPain:
            return "Chest pain - evaluate for cardiac, pulmonary, and other life-threatening causes"
        case .abdominalPain:
            return "Abdominal pain - consider surgical and medical etiologies"
        case .shortnessOfBreath:
            return "Shortness of breath - assess cardiopulmonary causes"
        case .headache:
            return "Headache - rule out dangerous secondary causes"
        case .general:
            return "General presentation requiring comprehensive evaluation"
        }
    }
}

// MARK: - Clinical Templates

extension MedicalPromptingEngine {
    
    static let clinicalReasoningTemplate = """
    **Clinical Reasoning:**
    
    This {age}-year-old {gender} presents with {chief_complaint}. 
    
    **Differential Diagnosis (prioritized):**
    
    1. **{diagnosis1}** - {reasoning1}
    2. **{diagnosis2}** - {reasoning2}
    3. **{diagnosis3}** - {reasoning3}
    
    **Diagnostic Strategy:**
    {diagnostic_plan}
    
    **Risk Stratification:**
    {risk_assessment}
    
    **Disposition Rationale:**
    {disposition_reasoning}
    """
    
    static let emergencyProtocolsTemplate = """
    **Protocol Considerations:**
    
    - Sepsis Screening: {sepsis_assessment}
    - Stroke Protocol: {stroke_assessment}  
    - STEMI Protocol: {stemi_assessment}
    - Trauma Protocol: {trauma_assessment}
    
    **Time-Sensitive Interventions:**
    {time_sensitive_actions}
    """
}