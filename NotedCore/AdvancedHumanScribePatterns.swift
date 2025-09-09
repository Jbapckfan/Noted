// Advanced Human Scribe Documentation Patterns
// Generated: 2025-09-01 from comprehensive training research
// Sources: ACMSO, ScribeAmerica, UC San Diego Medical, AAFP guidelines

import Foundation

struct AdvancedHumanScribePatterns {
    
    /// Real language patterns from human medical scribe training programs
    static let documentationPatterns: [String: String] = [
        // Patient presentation patterns (exactly as humans are trained)
        "Patient presents with": "Patient presents with",
        "This is a [age]-year-old [gender] who presents with": "This is a [age]-year-old [gender] who presents with",
        "The patient is a [age] year old [gender] that comes to": "The patient is a [age] year old [gender] that comes to",
        
        // Opening HPI patterns from real training
        "complains of": "presents with chief complaint of",
        "came in for": "presents for evaluation of",
        "here for": "presents for",
        "brought in by": "brought to ED by",
        
        // Temporal documentation (human scribe training)
        "since yesterday": "x1 day",
        "for the past few days": "x3-4 days", 
        "over the last week": "x1 week",
        "started this morning": "onset this AM",
        "began last night": "onset overnight",
        "for several hours": "x several hours",
        "about 3 days ago": "approximately 3 days ago",
        
        // Symptom characterization (OLDCARTS training)
        "describes as": "characterized as",
        "feels like": "described as sensation of",
        "says it's": "reports symptoms as",
        "told me it": "states that symptoms",
        "it's a": "described as",
        
        // Pertinent negatives (critical for billing)
        "no fever": "Denies fever",
        "no chills": "Denies chills", 
        "no nausea": "Denies nausea",
        "no vomiting": "Denies vomiting",
        "no headache": "Denies headache",
        "no diarrhea": "Denies diarrhea",
        "no weight loss": "Denies weight loss",
        "no chest pain": "Denies chest pain",
        "no shortness of breath": "Denies dyspnea",
        "no difficulty breathing": "Denies respiratory distress",
        
        // Pertinent positives (human scribe language)
        "has fever": "Reports fever",
        "feels nauseous": "Reports nausea", 
        "is dizzy": "Reports dizziness",
        "has been vomiting": "Reports vomiting",
        "short of breath": "Reports dyspnea",
        "can't catch breath": "Reports respiratory distress",
        
        // Pain documentation (trained patterns)
        "really hurts": "severe pain",
        "hurts a lot": "significant pain",
        "doesn't hurt much": "minimal discomfort",
        "pain is": "pain characterized as",
        "rates pain": "rates pain severity",
        "on a scale": "on 10-point scale",
        "out of 10": "/10",
        "10 out of 10": "10/10 severe",
        "1 out of 10": "1/10 minimal",
        
        // Medication patterns (scribe documentation)
        "takes": "Current medications include",
        "on": "Currently prescribed",
        "uses": "Reports use of",
        "sometimes takes": "Intermittent use of",
        "forgot to take": "Reports medication non-compliance",
        "ran out of": "Reports medication discontinuation",
        
        // Allergy documentation (required patterns)
        "allergic to": "Known allergy to",
        "no allergies": "NKDA (No Known Drug Allergies)",
        "no drug allergies": "NKDA",
        "can't take": "Intolerance to",
        
        // Social history patterns
        "smokes": "Tobacco use",
        "drinks": "Alcohol use", 
        "doesn't smoke": "Denies tobacco use",
        "doesn't drink": "Denies alcohol use",
        "quit smoking": "Former tobacco user",
        "used to drink": "Former alcohol use",
        
        // Family history patterns  
        "mom had": "Family history of (maternal)",
        "dad has": "Family history of (paternal)",
        "family history of": "Positive family history for",
        "no family history": "Negative family history for",
        "runs in family": "Positive family history",
        
        // Review of systems patterns (ROS)
        "everything else normal": "All other systems negative",
        "nothing else": "All other ROS negative", 
        "per HPI": "per HPI above",
        "as noted": "as documented above",
        
        // Assessment patterns (clinical reasoning)
        "likely": "Most consistent with",
        "probably": "Clinical impression consistent with",
        "could be": "Differential diagnosis includes",
        "rule out": "Rule out",
        "working diagnosis": "Primary diagnosis",
        
        // Plan patterns (human scribe format)
        "will order": "Plan includes",
        "going to": "Will proceed with",
        "follow up": "Follow-up arranged",
        "come back if": "Return precautions given",
        "call if worse": "Return if symptoms worsen",
        
        // Discharge patterns
        "patient understands": "Patient verbalized understanding",
        "given instructions": "Discharge instructions provided",
        "prescription given": "Prescription provided for",
        "told to": "Patient instructed to"
    ]
    
    /// HPI sentence starters (from real training materials)
    static let hpiStarters = [
        "This is a [age]-year-old [gender] who presents with",
        "The patient is a [age] year old [gender] that comes to the ED with",
        "[Age]-year-old [gender] presents with chief complaint of", 
        "Patient presents with [duration] history of",
        "This patient reports",
        "The patient describes"
    ]
    
    /// Pertinent negative templates (billing requirement)
    static let pertinentNegativeTemplates = [
        "Constitutional: Denies fever, chills, night sweats",
        "Cardiovascular: Denies chest pain, palpitations, leg swelling",
        "Respiratory: Denies cough, shortness of breath, wheezing",
        "GI: Denies nausea, vomiting, diarrhea, constipation",
        "GU: Denies dysuria, frequency, urgency",
        "Neurological: Denies headache, dizziness, weakness",
        "Musculoskeletal: Denies joint pain, muscle aches",
        "Psychiatric: Denies depression, anxiety, suicidal ideation",
        "Hematologic: Denies easy bruising, bleeding",
        "Endocrine: Denies heat/cold intolerance, polyuria"
    ]
    
    /// Assessment and plan patterns (real scribe language)
    static let assessmentPatterns = [
        "Clinical impression consistent with": "Most likely diagnosis:",
        "Differential diagnosis includes": "Consider:",
        "Rule out": "R/O:",
        "Working diagnosis": "Primary Dx:",
        "Most consistent with": "Impression:",
        "Plan includes": "Plan:",
        "Will proceed with": "Management:",
        "Follow-up arranged": "F/U:",
        "Return if symptoms worsen": "Return precautions:",
        "Patient verbalized understanding": "Patient education completed"
    ]
    
    /// Apply advanced human-like patterns
    static func applyAdvancedPatterns(to text: String) -> String {
        var improved = text
        
        // Apply documentation patterns (longest first to avoid conflicts)
        let sortedPatterns = documentationPatterns.sorted { $0.key.count > $1.key.count }
        for (pattern, replacement) in sortedPatterns {
            let regex = try? NSRegularExpression(
                pattern: "\\b\(NSRegularExpression.escapedPattern(for: pattern))\\b",
                options: .caseInsensitive
            )
            
            if let regex = regex {
                improved = regex.stringByReplacingMatches(
                    in: improved,
                    range: NSRange(improved.startIndex..., in: improved),
                    withTemplate: replacement
                )
            }
        }
        
        return improved
    }
    
    /// Generate HPI using human scribe methodology
    static func generateHumanLikeHPI(
        age: String,
        gender: String, 
        chiefComplaint: String,
        symptoms: [String: String] // OLDCARTS format
    ) -> String {
        var hpi = "This is a \(age)-year-old \(gender) who presents with \(chiefComplaint). "
        
        // Add OLDCARTS details in human scribe order
        if let onset = symptoms["onset"] {
            hpi += "Symptoms began \(onset). "
        }
        
        if let location = symptoms["location"] {
            hpi += "Pain/discomfort located in \(location). "
        }
        
        if let character = symptoms["character"] {
            hpi += "Described as \(character). "
        }
        
        if let radiation = symptoms["radiation"] {
            hpi += "Radiates to \(radiation). "
        }
        
        if let severity = symptoms["severity"] {
            hpi += "Rates severity \(severity)/10. "
        }
        
        if let timing = symptoms["timing"] {
            hpi += "Symptoms are \(timing). "
        }
        
        if let aggravating = symptoms["aggravating"] {
            hpi += "Worsens with \(aggravating). "
        }
        
        if let alleviating = symptoms["alleviating"] {
            hpi += "Improves with \(alleviating). "
        }
        
        return hpi.trimmingCharacters(in: .whitespaces)
    }
    
    /// Add pertinent negatives (billing requirement)
    static func addPertinentNegatives(for chiefComplaint: String) -> [String] {
        // Map chief complaints to relevant pertinent negatives
        let negativeMap: [String: [String]] = [
            "chest pain": [
                "Denies shortness of breath",
                "Denies nausea or vomiting", 
                "Denies diaphoresis",
                "Denies radiation to arm or jaw"
            ],
            "headache": [
                "Denies fever",
                "Denies neck stiffness",
                "Denies visual changes",
                "Denies nausea or vomiting"
            ],
            "abdominal pain": [
                "Denies fever",
                "Denies nausea or vomiting",
                "Denies diarrhea or constipation",
                "Denies urinary symptoms"
            ],
            "shortness of breath": [
                "Denies chest pain",
                "Denies fever",
                "Denies leg swelling",
                "Denies cough or wheeze"
            ]
        ]
        
        // Find matching negatives or return general ones
        for (complaint, negatives) in negativeMap {
            if chiefComplaint.lowercased().contains(complaint) {
                return negatives
            }
        }
        
        // Default pertinent negatives
        return [
            "Denies fever or chills",
            "Denies nausea or vomiting",
            "Denies significant pain elsewhere"
        ]
    }
}