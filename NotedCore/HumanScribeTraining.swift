import Foundation

/// How REAL Human Medical Scribes Are Trained
/// Based on actual certification programs and training materials
struct HumanScribeTraining {
    
    // MARK: - Core Skills Human Scribes Learn
    
    /// 1. LISTENING AND TYPING simultaneously
    /// "The biggest thing is learning how to listen and type"
    /// Scribes spend 3 months feeling like they're "drowning" before getting comfortable
    
    /// 2. FILTERING: What to document vs what to summarize
    static let filteringRules = [
        "Doctor explaining condition" : "DOCUMENT as 'Education on [topic] provided'",
        "Doctor giving instructions" : "DOCUMENT - treatment instructions",
        "Lifestyle counseling" : "DOCUMENT - supports billing",
        "Warning signs discussed" : "DOCUMENT - critical for liability",
        "Social chitchat (weather)" : "SKIP - truly irrelevant",
        "Patient symptoms" : "DOCUMENT IN FULL - always relevant",
        "Medication discussion" : "DOCUMENT IN FULL - critical for care",
        "Physical exam findings" : "DOCUMENT IN FULL - objective data",
        "Family mentions" : "EVALUATE - may be family history",
        "Work discussion" : "EVALUATE - may be occupational exposure"
    ]
    
    /// 3. CHIEF COMPLAINT extraction
    /// - Must be in patient's own words
    /// - Brief statement (1-2 sentences max)
    /// - The MAIN reason for visit
    static func extractChiefComplaint(from conversation: String) -> String {
        // Human scribes are trained to identify:
        // "What brings you in today?" → Next patient statement is CC
        // "I'm here because..." → This IS the CC
        // Look for FIRST mention of primary symptom
        
        let ccPatterns = [
            "brings you in",
            "here because", 
            "main concern",
            "bothering me most"
        ]
        
        // Extract the patient's exact words following these prompts
        return "Patient's exact words here"
    }
    
    /// 4. HPI using OLDCARTS framework
    /// Every human scribe memorizes this mnemonic
    struct OLDCARTS {
        static let components = [
            "O - Onset": "When did it start? (3 days ago, yesterday, last week)",
            "L - Location": "Where is the pain? (chest, head, abdomen)",
            "D - Duration": "How long does it last? (constant, comes and goes)",
            "C - Character": "What does it feel like? (sharp, dull, throbbing)",
            "A - Alleviating/Aggravating": "What makes it better/worse?",
            "R - Radiation": "Does it spread anywhere? (to arm, back, neck)",
            "T - Timing": "When does it occur? (morning, after meals, at night)",
            "S - Severity": "Rate 1-10, mild/moderate/severe"
        ]
        
        static func buildHPI(from patientResponses: [String: String]) -> String {
            // Human scribes are trained to write HPI in this exact format:
            return """
            [Age] year old [sex] presenting with [chief complaint] for [duration].
            Patient describes the [symptom] as [character], located in [location],
            rated [severity]/10. Symptoms are worse with [aggravating] and better
            with [alleviating]. Associated symptoms include [list].
            Denies [pertinent negatives].
            """
        }
    }
    
    /// 5. PERTINENT NEGATIVES - Critical for billing
    /// Human scribes MUST document what patient DOESN'T have
    static let pertinentNegatives = [
        "Chest pain" : ["Denies SOB, diaphoresis, radiation to arm"],
        "Headache" : ["Denies vision changes, neck stiffness, fever"],
        "Abdominal pain" : ["Denies nausea, vomiting, diarrhea, blood in stool"]
    ]
    
    /// 6. ROS (Review of Systems) - Systematic questioning
    /// Scribes learn to organize by body system
    struct ReviewOfSystems {
        static let systems = [
            "Constitutional": ["fever", "chills", "weight loss", "fatigue"],
            "HEENT": ["headache", "vision changes", "hearing loss", "sore throat"],
            "Cardiovascular": ["chest pain", "palpitations", "edema"],
            "Respiratory": ["SOB", "cough", "wheezing", "hemoptysis"],
            "GI": ["nausea", "vomiting", "diarrhea", "constipation"],
            "GU": ["dysuria", "frequency", "urgency", "hematuria"],
            "Musculoskeletal": ["joint pain", "stiffness", "swelling"],
            "Neurological": ["weakness", "numbness", "tingling", "seizures"],
            "Psychiatric": ["depression", "anxiety", "SI/HI"],
            "Skin": ["rash", "lesions", "itching"]
        ]
    }
    
    /// 7. Physical Exam Documentation
    /// Scribes learn specific terminology for each finding
    static let physicalExamTerms = [
        "Normal findings": [
            "HEENT": "Normocephalic, atraumatic, PERRL, EOMI",
            "Cardiac": "RRR, no murmurs/rubs/gallops",
            "Lungs": "Clear to auscultation bilaterally",
            "Abdomen": "Soft, non-tender, non-distended, +BS x4"
        ],
        "Abnormal findings": [
            "Tender": "Tenderness to palpation in [location]",
            "Swollen": "Edema noted in [location]",
            "Abnormal sound": "Rales/wheezes/decreased breath sounds"
        ]
    ]
    
    /// 8. Assessment & Plan Format
    /// Human scribes learn problem-based documentation
    static func formatAssessmentPlan(problems: [(diagnosis: String, plan: String)]) -> String {
        var output = "ASSESSMENT & PLAN:\n"
        for (index, problem) in problems.enumerated() {
            output += """
            \(index + 1). \(problem.diagnosis)
            - \(problem.plan)
            
            """
        }
        return output
    }
    
    // MARK: - What Scribes DON'T Do
    
    /// Human scribes are explicitly trained NOT to:
    static let prohibitedActions = [
        "Make medical decisions",
        "Interpret test results",
        "Suggest diagnoses",
        "Answer patient questions",
        "Document things they didn't hear",
        "Add their own observations"
    ]
    
    // MARK: - Training Timeline
    
    /// How long it takes to become proficient:
    static let trainingTimeline = [
        "Week 1-2": "Medical terminology, anatomy basics",
        "Week 3-4": "SOAP notes, OLDCARTS, documentation",
        "Week 5-8": "Practice with recordings (93+ scenarios)",
        "Week 9-12": "Shadow experienced scribes",
        "Month 3": "Start feeling comfortable",
        "Month 6": "Fully proficient"
    ]
    
    // MARK: - Quality Metrics
    
    /// What makes a GOOD scribe note:
    static let qualityChecklist = [
        "✓ CC in patient's own words",
        "✓ Complete OLDCARTS for HPI",
        "✓ All pertinent positives AND negatives",
        "✓ Chronological timeline clear",
        "✓ Medications with doses",
        "✓ Allergies documented",
        "✓ Physical exam findings",
        "✓ Assessment matches findings",
        "✓ Plan is specific and actionable",
        "✓ Nothing extraneous included"
    ]
}

// MARK: - Apply to AI Implementation

extension HumanScribeTraining {
    
    /// What the AI needs to replicate:
    static func applyToAI(conversation: String) -> String {
        """
        STEP 1: FILTER
        - Remove all non-medical chitchat
        - Remove doctor explaining to patient
        - Keep ONLY clinically relevant statements
        
        STEP 2: IDENTIFY SPEAKERS
        - Tag each statement as [Doctor] or [Patient]
        - Patient statements → Subjective section
        - Doctor findings → Objective section
        
        STEP 3: EXTRACT CC
        - Find "What brings you in?" or similar
        - Next patient statement = Chief Complaint
        - Keep exact words, max 2 sentences
        
        STEP 4: BUILD HPI WITH OLDCARTS
        - Scan for each OLDCARTS element
        - Organize chronologically
        - Include pertinent negatives
        
        STEP 5: ORGANIZE BY SOAP
        S: CC + HPI + ROS + Medications + Allergies
        O: Vitals + Physical Exam + Test Results  
        A: Diagnosis/Differential
        P: Treatment plan, follow-up
        
        STEP 6: QUALITY CHECK
        - Is CC in patient's words? ✓
        - Does HPI have OLDCARTS? ✓
        - Are pertinent negatives included? ✓
        - Is timeline clear? ✓
        - Anything irrelevant? Remove it.
        """
    }
    
    /// The REAL difference between human and AI scribes:
    static let keyInsight = """
    Human scribes spend 3-6 months learning to:
    1. Listen and type simultaneously (AI: instant)
    2. Filter relevant from irrelevant (AI: needs rules)
    3. Apply OLDCARTS consistently (AI: perfect every time)
    4. Remember medical terms (AI: built-in)
    
    The HARD part isn't medical knowledge - it's knowing
    what to IGNORE. Scribes say: "Learning how to listen
    and type" and "feeling like drowning for 3 months."
    
    For AI, this should be EASY:
    - No typing lag
    - Perfect memory
    - Consistent formatting
    - Never tired or distracted
    
    We just need to teach it the FILTERING rules!
    """
}