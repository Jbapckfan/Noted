import Foundation

/// Human-like medical documentation patterns extracted from real scribe training
/// Based on actual certification programs and documentation examples
struct HumanLikeDocumentation {
    
    // MARK: - Exact Human Scribe Language Patterns
    
    /// Opening sentence patterns (from real examples)
    static let openingPatterns = [
        "The patient is a [age] year old [sex] who presents to the Emergency Department with a chief complaint of [symptom].",
        "This is a [age]-year-old [sex] presenting with [symptom] for [duration].",
        "Patient is a [age] y/o [sex] with a history of [PMH] presenting c/o [symptom].",
        "[Age] y/o [sex] with [duration] of [symptom]."
    ]
    
    /// HPI Development patterns (how humans write HPI)
    static let hpiPatterns = [
        // Pain description
        "The pain is described as [character] and is located in [location].",
        "Patient describes the [symptom] as [character], located [location], rated [severity]/10.",
        "On a scale of 1 to 10 the patient states that the pain is a [number].",
        
        // Timing and onset
        "It has been present for [duration] and it began [onset].",
        "Symptoms started [onset] while [context].",
        "The patient reports [symptom] that began [timeframe] ago.",
        
        // Associated symptoms (human style)
        "Associated symptoms include [list].",
        "The patient also reports [symptoms].",
        "Denies [negative symptoms].",
        "No associated [symptoms].",
        
        // Modifying factors
        "The pain is worse with [aggravating] and better with [alleviating].",
        "Symptoms are exacerbated by [factor] and relieved by [factor].",
        "Patient took [medication] with [effect].",
        
        // Context and progression
        "This prompted the patient to seek evaluation.",
        "The patient decided to come to the ED when [reason].",
        "Symptoms have been [progression] over time."
    ]
    
    /// Physical Exam Language (exactly as humans write)
    static let physicalExamPatterns = [
        // General appearance
        "Patient appears well-developed, well-nourished, and in no acute distress.",
        "Alert and oriented x3, cooperative with examination.",
        "Appears stated age, sitting comfortably on stretcher.",
        
        // Vital signs
        "Vital signs are stable and within normal limits.",
        "Afebrile with stable vital signs.",
        "BP elevated at [value], otherwise stable vitals.",
        
        // System examinations
        "HEENT: Normocephalic, atraumatic. PERRL, EOMI. No cervical lymphadenopathy.",
        "Cardiovascular: Regular rate and rhythm, no murmurs, rubs, or gallops.",
        "Pulmonary: Clear to auscultation bilaterally, no wheezes or rales.",
        "Abdomen: Soft, non-tender, non-distended, positive bowel sounds x4.",
        "Extremities: No clubbing, cyanosis, or edema.",
        "Neurological: Alert and oriented, no focal deficits noted.",
        
        // Abnormal findings
        "Tenderness to palpation in [location].",
        "Decreased breath sounds in [location].",
        "Erythema and swelling noted in [location].",
        "[Location] reveals [finding] on examination."
    ]
    
    /// Assessment & Plan Language (real human style)
    static let assessmentPatterns = [
        // Problem list format
        "#1 [Diagnosis] - [ICD-10 code if known]",
        "Most likely [diagnosis] given [reasoning].",
        "Differential diagnosis includes [list].",
        "Rule out [conditions] with [tests].",
        
        // Treatment plans
        "Start [medication] [dose] [frequency] for [duration].",
        "Continue current medications as prescribed.",
        "Discharge home with instructions.",
        "Admit for further evaluation and management.",
        "Follow up with [specialty] in [timeframe].",
        
        // Instructions
        "Return to ED if symptoms worsen or for any concerns.",
        "Strict return precautions given.",
        "Patient verbalized understanding of discharge instructions."
    ]
    
    // MARK: - Human Documentation Style Guidelines
    
    /// Sentence structure patterns humans use
    struct SentencePatterns {
        static let concise = "Brief, factual statements"
        static let chronological = "Events in time order"
        static let clinical = "Medical terminology, not lay language"
        static let objective = "Observable facts, not interpretations"
        
        // Examples:
        static let good = [
            "Pain onset 3 hours ago while watching television.",
            "Took 2 aspirin with minimal relief.",
            "Denies shortness of breath, nausea, or diaphoresis."
        ]
        
        static let avoid = [
            "The patient seems to have pain.",  // Too vague
            "Pain is really bad.",  // Not quantified
            "The patient is worried."  // Subjective interpretation
        ]
    }
    
    /// Medication documentation (exactly as humans write)
    struct MedicationPatterns {
        static let format = "[Name] [dose] [route] [frequency] for [duration]"
        
        static let examples = [
            "Lisinopril 10 mg PO daily",
            "Ibuprofen 600 mg PO q6h PRN pain",
            "Azithromycin 250 mg PO daily x5 days",
            "Omeprazole 20 mg PO BID before meals",
            "Albuterol inhaler 2 puffs q4h PRN SOB"
        ]
        
        static let compliance = [
            "Patient reports good compliance with medications.",
            "Admits to missing doses occasionally.",
            "Unable to afford medications, stopped taking [name] last month.",
            "No known drug allergies (NKDA).",
            "Allergic to penicillin - reports rash."
        ]
    }
    
    /// Education documentation (as you requested)
    struct EducationPatterns {
        static let standard = [
            "Education provided regarding [condition] and treatment plan.",
            "Patient counseled on [topic]. Verbalized understanding.",
            "Discussed [medication] side effects and proper usage.",
            "Lifestyle modifications reviewed including [specifics].",
            "Return precautions discussed. Patient instructed to return for [symptoms]."
        ]
        
        static let specific = [
            "Education on hypertension management provided.",
            "Diabetes self-monitoring techniques reviewed.",
            "Proper inhaler technique demonstrated.",
            "Wound care instructions given.",
            "Signs of infection discussed."
        ]
    }
    
    // MARK: - Generate Human-Like Note
    
    static func generateHumanLikeNote(
        chiefComplaint: String,
        hpiElements: [String: String],
        physicalFindings: [String],
        education: [String]
    ) -> String {
        
        // Use patterns exactly as humans write them
        let age = hpiElements["age"] ?? "XX"
        let sex = hpiElements["sex"] ?? "patient"
        let duration = hpiElements["duration"] ?? ""
        
        var note = ""
        
        // Opening (human pattern)
        note += "The patient is a \(age) year old \(sex) who presents with a chief complaint of \(chiefComplaint.lowercased())"
        if !duration.isEmpty {
            note += " for \(duration)"
        }
        note += ".\n\n"
        
        // HPI development (chronological, as humans write)
        note += "HPI:\n"
        
        if let onset = hpiElements["onset"] {
            note += "Symptoms began \(onset). "
        }
        
        if let character = hpiElements["character"] {
            note += "Patient describes the pain as \(character). "
        }
        
        if let location = hpiElements["location"] {
            note += "Pain is located in the \(location). "
        }
        
        if let severity = hpiElements["severity"] {
            note += "On a scale of 1 to 10, patient rates pain as \(severity). "
        }
        
        if let aggravating = hpiElements["aggravating"] {
            note += "Symptoms are worse with \(aggravating). "
        }
        
        if let alleviating = hpiElements["alleviating"] {
            note += "Pain is relieved by \(alleviating). "
        }
        
        if let associated = hpiElements["associated"] {
            note += "Associated symptoms include \(associated). "
        }
        
        if let negatives = hpiElements["negatives"] {
            note += "Denies \(negatives). "
        }
        
        note += "\n"
        
        // Physical exam (if provided)
        if !physicalFindings.isEmpty {
            note += "PHYSICAL EXAM:\n"
            for finding in physicalFindings {
                note += "\(finding)\n"
            }
            note += "\n"
        }
        
        // Education (as you requested - don't ignore)
        if !education.isEmpty {
            note += "PATIENT EDUCATION:\n"
            for item in education {
                note += "• \(item)\n"
            }
            note += "\n"
        }
        
        return note
    }
    
    // MARK: - Quality Checklist (from real training)
    
    static let humanQualityChecklist = [
        "✓ Opens with age, sex, chief complaint",
        "✓ Uses medical terminology appropriately", 
        "✓ Includes quantified pain scale (1-10)",
        "✓ Documents pertinent negatives",
        "✓ Chronological symptom progression",
        "✓ Specific medication names and doses",
        "✓ Education and counseling documented",
        "✓ Professional, objective language",
        "✓ No spelling or grammar errors",
        "✓ Appropriate length (not too verbose)"
    ]
}