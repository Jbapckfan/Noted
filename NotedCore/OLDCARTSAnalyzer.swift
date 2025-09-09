import Foundation

/// Medical scribe analyzer using OLDCARTS - exactly how humans are trained
/// This is what REAL medical scribes learn in their 30-hour certification
struct OLDCARTSAnalyzer {
    
    // MARK: - Extract Chief Complaint (Exactly as humans do)
    
    static func extractChiefComplaint(from conversation: String) -> String {
        let lines = conversation.components(separatedBy: .newlines)
        
        // Human scribes look for these doctor prompts:
        let doctorPrompts = [
            "what brings you in",
            "how can i help",
            "what's going on",
            "tell me what's happening",
            "reason for your visit",
            "what seems to be the problem"
        ]
        
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // Find doctor asking for CC
            if doctorPrompts.contains(where: lower.contains) {
                // Next patient statement is the CC
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    
                    // Extract patient's exact words
                    if nextLine.lowercased().contains("patient:") {
                        return nextLine.replacingOccurrences(of: "Patient:", with: "")
                            .trimmingCharacters(in: .whitespaces)
                    }
                    return nextLine.trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Direct patient statement of CC
            if lower.contains("i'm here because") || 
               lower.contains("i've been having") ||
               lower.contains("i have this") {
                return line.replacingOccurrences(of: "Patient:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        
        return "Patient presents for evaluation"
    }
    
    // MARK: - Build HPI using OLDCARTS (Human scribe method)
    
    struct OLDCARTS {
        var onset: String?
        var location: String?
        var duration: String?
        var character: String?
        var alleviating: String?
        var aggravating: String?
        var radiation: String?
        var timing: String?
        var severity: String?
        var associatedSymptoms: [String] = []
        var pertinentNegatives: [String] = []
    }
    
    static func extractOLDCARTS(from conversation: String) -> OLDCARTS {
        var oldcarts = OLDCARTS()
        let text = conversation.lowercased()
        
        // ONSET - When did it start?
        let onsetPatterns = [
            #"(\d+)\s*(days?|weeks?|months?|hours?)\s*ago"#,
            #"started\s*(yesterday|today|last\s*night|this\s*morning)"#,
            #"since\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday)"#
        ]
        
        for pattern in onsetPatterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                oldcarts.onset = String(text[match])
            }
        }
        
        // LOCATION - Where is it?
        let bodyParts = ["chest", "head", "abdomen", "back", "throat", "stomach", 
                        "arm", "leg", "neck", "shoulder", "knee", "foot"]
        for part in bodyParts {
            if text.contains(part) {
                oldcarts.location = part
                
                // Add specifics (left, right, upper, lower)
                if text.contains("left \(part)") { oldcarts.location = "left \(part)" }
                if text.contains("right \(part)") { oldcarts.location = "right \(part)" }
                if text.contains("upper \(part)") { oldcarts.location = "upper \(part)" }
                if text.contains("lower \(part)") { oldcarts.location = "lower \(part)" }
            }
        }
        
        // DURATION - How long does it last?
        if text.contains("constant") { oldcarts.duration = "constant" }
        if text.contains("comes and goes") { oldcarts.duration = "intermittent" }
        if text.contains("all day") { oldcarts.duration = "continuous" }
        if text.contains("few minutes") { oldcarts.duration = "minutes" }
        if text.contains("few hours") { oldcarts.duration = "hours" }
        
        // CHARACTER - What does it feel like?
        let characterWords = [
            "sharp": "sharp",
            "dull": "dull aching",
            "throbbing": "throbbing",
            "burning": "burning",
            "stabbing": "stabbing",
            "pressure": "pressure-like",
            "crushing": "crushing",
            "squeezing": "squeezing",
            "cramping": "crampy"
        ]
        
        for (word, description) in characterWords {
            if text.contains(word) {
                oldcarts.character = description
                break
            }
        }
        
        // ALLEVIATING - What makes it better?
        if text.contains("better with rest") { oldcarts.alleviating = "rest" }
        if text.contains("better when") {
            if let range = text.range(of: #"better when \w+"#, options: .regularExpression) {
                oldcarts.alleviating = String(text[range])
            }
        }
        
        // AGGRAVATING - What makes it worse?
        if text.contains("worse with") {
            if let range = text.range(of: #"worse with \w+"#, options: .regularExpression) {
                oldcarts.aggravating = String(text[range])
            }
        }
        if text.contains("worse when") {
            if let range = text.range(of: #"worse when \w+"#, options: .regularExpression) {
                oldcarts.aggravating = String(text[range])
            }
        }
        
        // RADIATION - Does it spread?
        if text.contains("radiates to") || text.contains("spreads to") || text.contains("goes to") {
            if text.contains("arm") { oldcarts.radiation = "radiates to arm" }
            if text.contains("back") { oldcarts.radiation = "radiates to back" }
            if text.contains("jaw") { oldcarts.radiation = "radiates to jaw" }
            if text.contains("shoulder") { oldcarts.radiation = "radiates to shoulder" }
        }
        
        // TIMING - When does it occur?
        if text.contains("at night") { oldcarts.timing = "nocturnal" }
        if text.contains("in the morning") { oldcarts.timing = "morning" }
        if text.contains("after eating") { oldcarts.timing = "postprandial" }
        if text.contains("with activity") { oldcarts.timing = "with exertion" }
        
        // SEVERITY - How bad is it?
        if let severityMatch = text.range(of: #"\d+/10"#, options: .regularExpression) {
            oldcarts.severity = String(text[severityMatch])
        } else if text.contains("mild") {
            oldcarts.severity = "mild"
        } else if text.contains("moderate") {
            oldcarts.severity = "moderate"
        } else if text.contains("severe") || text.contains("worst") || text.contains("terrible") {
            oldcarts.severity = "severe"
        }
        
        // ASSOCIATED SYMPTOMS
        let symptoms = ["nausea", "vomiting", "fever", "chills", "sweating", "dizziness",
                       "shortness of breath", "fatigue", "weakness", "numbness", "tingling"]
        for symptom in symptoms {
            if text.contains(symptom) && !text.contains("no \(symptom)") && !text.contains("denies \(symptom)") {
                oldcarts.associatedSymptoms.append(symptom)
            }
        }
        
        // PERTINENT NEGATIVES (what they DON'T have)
        for symptom in symptoms {
            if text.contains("no \(symptom)") || text.contains("denies \(symptom)") || text.contains("without \(symptom)") {
                oldcarts.pertinentNegatives.append("no \(symptom)")
            }
        }
        
        return oldcarts
    }
    
    // MARK: - Format HPI (Exactly as humans are trained)
    
    static func formatHPI(chiefComplaint: String, oldcarts: OLDCARTS, demographics: (age: Int?, sex: String?)) -> String {
        // Human scribes are trained to write HPI in this EXACT format:
        
        var hpi = ""
        
        // Opening line (always age, sex, CC)
        let age = demographics.age ?? 0
        let sex = demographics.sex ?? "patient"
        hpi += "\(age) year old \(sex) presenting with \(chiefComplaint.lowercased())"
        
        // Add onset if known
        if let onset = oldcarts.onset {
            hpi += " for \(onset)"
        }
        hpi += ". "
        
        // Describe the symptom
        if let location = oldcarts.location {
            hpi += "Patient reports \(location) "
        }
        
        if let character = oldcarts.character {
            hpi += "\(character) pain "
        } else {
            hpi += "pain "
        }
        
        // Add severity
        if let severity = oldcarts.severity {
            hpi += "rated \(severity)"
            if severity.contains("/10") {
                hpi += " in severity"
            }
        }
        hpi += ". "
        
        // Duration and timing
        if let duration = oldcarts.duration {
            hpi += "Symptoms are \(duration). "
        }
        
        if let timing = oldcarts.timing {
            hpi += "Occurs \(timing). "
        }
        
        // Aggravating and alleviating
        if let aggravating = oldcarts.aggravating {
            hpi += "Symptoms are \(aggravating). "
        }
        
        if let alleviating = oldcarts.alleviating {
            hpi += "Improved with \(alleviating). "
        }
        
        // Radiation
        if let radiation = oldcarts.radiation {
            hpi += "Pain \(radiation). "
        }
        
        // Associated symptoms
        if !oldcarts.associatedSymptoms.isEmpty {
            hpi += "Associated symptoms include \(oldcarts.associatedSymptoms.joined(separator: ", ")). "
        }
        
        // Pertinent negatives (CRITICAL for billing)
        if !oldcarts.pertinentNegatives.isEmpty {
            hpi += "Denies \(oldcarts.pertinentNegatives.joined(separator: ", "))."
        }
        
        return hpi
    }
    
    // MARK: - Filter Conversation (Remove irrelevant parts)
    
    static func filterConversation(_ conversation: String) -> String {
        let lines = conversation.components(separatedBy: .newlines)
        var filtered: [String] = []
        
        for line in lines {
            let lower = line.lowercased()
            
            // SKIP only truly irrelevant content:
            let skipPatterns = [
                "nice to meet you",
                "how's the weather",
                "traffic was bad",
                "parking was difficult"
                // Note: Keep family/friend mentions if medically relevant
                // e.g., "my mother has diabetes" is relevant family history
            ]
            
            let shouldSkip = skipPatterns.contains { lower.contains($0) }
            
            if !shouldSkip {
                // KEEP medical content AND education
                let keepPatterns = [
                    "pain", "ache", "hurt", "symptom",
                    "medication", "allergy", "history",
                    "fever", "cough", "nausea", "dizzy",
                    "blood pressure", "temperature", "pulse",
                    "exam", "tender", "swollen",
                    "explain", "understand", "because", "works by",  // Doctor education
                    "recommend", "suggest", "should", "avoid"  // Medical advice
                ]
                
                let shouldKeep = keepPatterns.contains { lower.contains($0) }
                
                if shouldKeep || lower.contains("patient:") || lower.contains("doctor:") {
                    filtered.append(line)
                }
            }
        }
        
        return filtered.joined(separator: "\n")
    }
    
    // MARK: - Generate Complete SOAP Note
    
    static func generateSOAPNote(from conversation: String) -> String {
        // Step 1: Filter out irrelevant content
        let filtered = filterConversation(conversation)
        
        // Step 2: Extract components
        let chiefComplaint = extractChiefComplaint(from: filtered)
        let oldcarts = extractOLDCARTS(from: filtered)
        
        // Step 3: Extract demographics (simplified)
        var age: Int?
        var sex: String?
        if let ageMatch = filtered.range(of: #"\d+ year old"#, options: .regularExpression) {
            age = Int(filtered[ageMatch].components(separatedBy: " ").first ?? "0")
        }
        if filtered.lowercased().contains("female") || filtered.lowercased().contains("woman") {
            sex = "female"
        } else if filtered.lowercased().contains("male") || filtered.lowercased().contains("man") {
            sex = "male"
        }
        
        // Step 4: Build SOAP note
        let hpi = formatHPI(chiefComplaint: chiefComplaint, oldcarts: oldcarts, demographics: (age, sex))
        
        // Add education documentation
        let educationSection = MedicalEducationDocumenter.generateEducationSection(from: filtered)
        let billingSupport = MedicalEducationDocumenter.generateBillingSupport(from: filtered)
        
        return """
        CHIEF COMPLAINT:
        "\(chiefComplaint)"
        
        HPI (History of Present Illness):
        \(hpi)
        
        REVIEW OF SYSTEMS:
        Constitutional: \(oldcarts.associatedSymptoms.contains("fever") ? "Positive for fever" : "Negative")
        Respiratory: \(oldcarts.associatedSymptoms.contains("shortness of breath") ? "Positive for SOB" : "Negative")
        GI: \(oldcarts.associatedSymptoms.contains("nausea") ? "Positive for nausea" : "Negative")
        Neurological: \(oldcarts.associatedSymptoms.contains("dizziness") ? "Positive for dizziness" : "Negative")
        
        PHYSICAL EXAM:
        (To be documented during examination)
        
        ASSESSMENT & PLAN:
        (To be completed by provider)
        
        \(educationSection)
        
        \(billingSupport)
        """
    }
}