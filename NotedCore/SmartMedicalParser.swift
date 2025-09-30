import Foundation
import NaturalLanguage

/// Smart medical conversation parser with actual clinical understanding
class SmartMedicalParser {
    static let shared = SmartMedicalParser()

    // MARK: - Main Parse Function

    func parseConversation(_ transcript: String) -> ParsedMedicalNote {
        // 1. Separate doctor vs patient speech
        let segments = separateSpeakers(transcript)

        // 2. Extract chief complaint from patient's opening
        let chiefComplaint = extractChiefComplaint(from: segments.patientStatements)

        // 3. Extract symptom details with context
        let symptomDetails = extractSymptomDetails(from: segments.patientStatements, chiefComplaint: chiefComplaint)

        // 4. Extract timeline with temporal reasoning
        let timeline = extractTimeline(from: segments.patientStatements)

        // 5. Extract associated symptoms
        let associatedSymptoms = extractAssociatedSymptoms(from: segments.patientStatements, primary: chiefComplaint)

        // 6. Extract pertinent negatives from doctor's questions
        let negatives = extractPertinentNegatives(from: segments, chiefComplaint: chiefComplaint)

        // 7. Extract past medical history (patient only)
        let pmh = extractMedicalHistory(from: segments.patientStatements)

        // 7b. Extract family history (separate from patient)
        let familyHistory = extractFamilyHistory(from: segments.patientStatements)

        // 8. Extract medications
        let meds = extractMedications(from: segments.patientStatements)

        // 9. Extract vitals mentioned
        let vitals = extractVitals(from: transcript)

        // 10. Build clinical assessment
        let assessment = buildAssessment(chiefComplaint: chiefComplaint, symptoms: symptomDetails, timeline: timeline)

        return ParsedMedicalNote(
            chiefComplaint: chiefComplaint,
            symptomDetails: symptomDetails,
            timeline: timeline,
            associatedSymptoms: associatedSymptoms,
            pertinentNegatives: negatives,
            medicalHistory: pmh,
            familyHistory: familyHistory,
            medications: meds,
            vitals: vitals,
            assessment: assessment
        )
    }

    // MARK: - Separate Speakers

    private func separateSpeakers(_ transcript: String) -> ConversationSegments {
        var patientStatements: [String] = []
        var doctorQuestions: [String] = []

        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count > 5 }

        for sentence in sentences {
            let lower = sentence.lowercased()

            // Doctor's questions/statements
            if lower.starts(with: "any ") || lower.starts(with: "have you ") ||
               lower.starts(with: "do you ") || lower.starts(with: "did you ") ||
               lower.starts(with: "are you ") || lower.starts(with: "were you ") ||
               lower.starts(with: "what ") || lower.starts(with: "when ") ||
               lower.starts(with: "how ") || lower.starts(with: "is it ") ||
               lower.contains("your ") && lower.contains(" looks ") {
                doctorQuestions.append(sentence)
            }
            // Patient's responses (filter out pure filler)
            else if !lower.hasPrefix("yeah") && !lower.hasPrefix("okay") &&
                    !lower.hasPrefix("mhmm") && !lower.hasPrefix("uh-huh") &&
                    sentence.count > 15 {
                patientStatements.append(sentence)
            }
        }

        return ConversationSegments(patientStatements: patientStatements, doctorQuestions: doctorQuestions)
    }

    // MARK: - Extract Chief Complaint

    private func extractChiefComplaint(from statements: [String]) -> String {
        // Look for early statements with symptoms
        for statement in statements.prefix(10) {
            let lower = statement.lowercased()

            // Pattern: "I'm having X"
            if lower.contains("having ") || lower.contains("i have ") {
                if lower.contains("palpitations") { return "Palpitations" }
                if lower.contains("chest pain") { return "Chest pain" }
                if lower.contains("shortness of breath") { return "Shortness of breath" }
                if lower.contains("headache") { return "Headache" }
            }

            // Pattern: "My X hurts"
            if lower.contains("hurts") || lower.contains("hurt") {
                if lower.contains("chest") { return "Chest pain" }
                if lower.contains("head") { return "Headache" }
                if lower.contains("stomach") || lower.contains("abdomen") { return "Abdominal pain" }
                if lower.contains("back") { return "Back pain" }
            }

            // Pattern: "I can't breathe"
            if lower.contains("can't breathe") || lower.contains("couldn't breathe") ||
               lower.contains("can't catch my breath") || lower.contains("couldn't catch my breath") {
                return "Shortness of breath"
            }

            // Pattern: "I woke up with X"
            if lower.contains("woke up") && lower.contains("chest") {
                return "Chest pain"
            }
        }

        return "Unspecified complaint"
    }

    // MARK: - Extract Symptom Details

    private func extractSymptomDetails(from statements: [String], chiefComplaint: String) -> SymptomDetails {
        var quality: String?
        var severity: String?
        var location: String?
        var radiation: String?
        var aggravating: [String] = []
        var relieving: [String] = []

        for statement in statements {
            let lower = statement.lowercased()

            // Quality descriptors
            let qualities = ["sharp", "dull", "aching", "burning", "stabbing", "throbbing",
                           "crushing", "pressure", "tight", "squeezing", "racing", "pounding", "fast"]
            for q in qualities {
                if lower.contains(q) && quality == nil {
                    quality = q
                    break
                }
            }

            // Severity - PRIORITIZE NUMERIC over descriptive
            if severity == nil {
                // Numeric scale - look for "7 out of 10" pattern
                let scalePattern = #"(\d+)\s+out of\s+10"#
                if let regex = try? NSRegularExpression(pattern: scalePattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                   let range = Range(match.range(at: 1), in: lower) {
                    severity = "\(lower[range])/10"
                }
                // Try slash format
                else {
                    let slashPattern = #"(\d+)/10"#
                    if let regex = try? NSRegularExpression(pattern: slashPattern, options: .caseInsensitive),
                       let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                       let range = Range(match.range(at: 1), in: lower) {
                        severity = "\(lower[range])/10"
                    }
                }
            }

            // Only use descriptive if no numeric found
            if severity == nil {
                if lower.contains("severe") || lower.contains("worst") { severity = "severe" }
                else if lower.contains("moderate") { severity = "moderate" }
                else if lower.contains("mild") { severity = "mild" }
            }

            // Location (for pain complaints) - PRIORITIZE center/middle before left/right
            if location == nil && chiefComplaint.lowercased().contains("pain") {
                if lower.contains("center") || lower.contains("middle") || lower.contains("central") {
                    location = "central chest"
                }
                else if lower.contains("substernal") || lower.contains("behind my breastbone") {
                    location = "substernal"
                }
                else if lower.contains("left") && lower.contains("chest") {
                    location = "left chest"
                }
                else if lower.contains("right") && lower.contains("chest") {
                    location = "right chest"
                }
            }

            // Radiation - catch more natural language patterns
            if radiation == nil {
                if lower.contains("radiates") || lower.contains("goes to") || lower.contains("spreads to") ||
                   lower.contains("goes into") || lower.contains("travels to") || lower.contains("shoots to") {
                    if lower.contains("left arm") { radiation = "to left arm" }
                    else if lower.contains("right arm") { radiation = "to right arm" }
                    else if lower.contains("both arms") { radiation = "to both arms" }
                    else if lower.contains("arm") { radiation = "to arm" }
                    else if lower.contains("jaw") { radiation = "to jaw" }
                    else if lower.contains("back") { radiation = "to back" }
                    else if lower.contains("neck") { radiation = "to neck" }
                    else if lower.contains("shoulder") { radiation = "to shoulder" }
                }
            }

            // Aggravating factors
            if lower.contains("worse with") || lower.contains("worse when") {
                if lower.contains("movement") { aggravating.append("movement") }
                else if lower.contains("breathing") || lower.contains("breath") { aggravating.append("deep breathing") }
                else if lower.contains("lying") { aggravating.append("lying down") }
                else if lower.contains("exertion") { aggravating.append("exertion") }
            }

            // Relieving factors
            if lower.contains("better with") || lower.contains("relieved by") {
                if lower.contains("rest") { relieving.append("rest") }
                else if lower.contains("sitting") { relieving.append("sitting up") }
                else if lower.contains("medication") { relieving.append("medication") }
            }
        }

        return SymptomDetails(
            quality: quality,
            severity: severity,
            location: location,
            radiation: radiation,
            aggravatingFactors: aggravating.isEmpty ? nil : aggravating,
            relievingFactors: relieving.isEmpty ? nil : relieving
        )
    }

    // MARK: - Extract Timeline

    private func extractTimeline(from statements: [String]) -> SymptomTimeline {
        var onset: String?
        var duration: String?
        var progression: String?
        var frequency: String?

        for statement in statements {
            let lower = statement.lowercased()

            // Onset patterns
            if onset == nil {
                // "Started X ago"
                let agoPattern = #"(\d+)\s+(hour|day|week|month)s?\s+ago"#
                if let regex = try? NSRegularExpression(pattern: agoPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                   let range = Range(match.range, in: lower) {
                    onset = String(lower[range])
                }
                // "This morning", "last night"
                else if lower.contains("this morning") { onset = "this morning" }
                else if lower.contains("last night") { onset = "last night" }
                else if lower.contains("yesterday") { onset = "yesterday" }
                else if lower.contains("today") { onset = "today" }
                else if lower.contains("woke up with") || lower.contains("woke up and") { onset = "upon waking" }
                // Specific time
                else if lower.contains("5 am") || lower.contains("5:00") || lower.contains("five in the morning") {
                    onset = "5 AM today"
                }
            }

            // Duration
            if duration == nil {
                let durationPattern = #"(?:for|lasted|lasting)\s+(?:about\s+)?(\d+)\s+(hour|minute|day)s?"#
                if let regex = try? NSRegularExpression(pattern: durationPattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
                   let range = Range(match.range, in: lower) {
                    duration = String(lower[range])
                }
            }

            // Progression
            if progression == nil {
                if lower.contains("getting worse") || lower.contains("worsening") { progression = "worsening" }
                else if lower.contains("getting better") || lower.contains("improving") { progression = "improving" }
                else if lower.contains("same") || lower.contains("unchanged") { progression = "stable" }
                else if lower.contains("comes and goes") { progression = "intermittent" }
            }

            // Frequency
            if frequency == nil {
                if lower.contains("constant") || lower.contains("all the time") { frequency = "constant" }
                else if lower.contains("intermittent") || lower.contains("comes and goes") { frequency = "intermittent" }
                else if lower.contains("occasional") { frequency = "occasional" }
            }
        }

        return SymptomTimeline(
            onset: onset,
            duration: duration,
            progression: progression,
            frequency: frequency
        )
    }

    // MARK: - Extract Associated Symptoms

    private func extractAssociatedSymptoms(from statements: [String], primary: String) -> [String] {
        var symptoms: Set<String> = []
        let primaryLower = primary.lowercased()

        let symptomKeywords: [String: String] = [
            "nausea": "nausea",
            "nauseous": "nausea",
            "vomit": "vomiting",
            "vomiting": "vomiting",
            "dizzy": "dizziness",
            "dizziness": "dizziness",
            "lightheaded": "lightheadedness",
            "sweating": "diaphoresis",
            "sweaty": "diaphoresis",
            "cold sweats": "diaphoresis",
            "fever": "fever",
            "chills": "chills",
            "cough": "cough",
            "shortness of breath": "shortness of breath",
            "can't breathe": "dyspnea",
            "can't take a full": "dyspnea",
            "difficulty breathing": "dyspnea",
            "palpitations": "palpitations",
            "rapid heart": "tachycardia",
            "racing heart": "tachycardia",
            "chest pain": "chest pain",
            "headache": "headache",
            "confusion": "confusion",
            "weakness": "weakness",
            "tired": "fatigue",
            "numbness": "numbness",
            "tingling": "tingling"
        ]

        for statement in statements {
            let lower = statement.lowercased()

            // CRITICAL: Skip if patient is DENYING the symptom
            let isDenial = lower.contains("no ") || lower.contains("not ") || lower.contains("nope") ||
                          lower.contains("none") || lower.contains("nothing like that") ||
                          lower.contains("denies") || lower.contains("negative for")

            if isDenial {
                continue  // Skip denial statements entirely
            }

            // POSITIVE affirmation required for symptoms
            let isAffirmative = lower.contains("yes") || lower.contains("yeah") || lower.contains("i have") ||
                               lower.contains("i've been") || lower.contains("i feel") || lower.contains("a little bit") ||
                               lower.contains("pretty") || lower.contains("very") || lower.contains("really")

            for (keyword, symptom) in symptomKeywords {
                if lower.contains(keyword) && !primaryLower.contains(keyword) && isAffirmative {
                    symptoms.insert(symptom)
                }
            }
        }

        return Array(symptoms).sorted()
    }

    // MARK: - Extract Pertinent Negatives

    private func extractPertinentNegatives(from segments: ConversationSegments, chiefComplaint: String) -> [String] {
        var negatives: Set<String> = []
        let lower = chiefComplaint.lowercased()

        // Define expected symptoms based on chief complaint
        let expectedSymptoms: [String]
        if lower.contains("chest") || lower.contains("palpitation") {
            expectedSymptoms = ["shortness of breath", "diaphoresis", "nausea", "radiation", "dizziness", "syncope", "lightheadedness"]
        } else if lower.contains("headache") {
            expectedSymptoms = ["vision changes", "neck stiffness", "fever", "photophobia", "confusion", "vomiting"]
        } else if lower.contains("abdominal") {
            expectedSymptoms = ["vomiting", "diarrhea", "fever", "blood in stool", "melena"]
        } else if lower.contains("breath") {
            expectedSymptoms = ["chest pain", "cough", "fever", "leg swelling", "hemoptysis"]
        } else {
            expectedSymptoms = []
        }

        // Look for doctor asking and patient denying
        for (index, question) in segments.doctorQuestions.enumerated() {
            let qLower = question.lowercased()

            for symptom in expectedSymptoms {
                if qLower.contains(symptom) {
                    // Look at patient's response (next statement)
                    if index < segments.patientStatements.count {
                        let response = segments.patientStatements[index].lowercased()
                        if response.contains("no") || response.contains("nope") ||
                           response.contains("not ") || response.contains("denies") {
                            negatives.insert(symptom)
                        }
                    }
                }
            }
        }

        return Array(negatives).sorted()
    }

    // MARK: - Extract Medical History

    private func extractMedicalHistory(from statements: [String]) -> [String] {
        var history: Set<String> = []

        let conditions = [
            "diabetes": "diabetes mellitus",
            "diabetic": "diabetes mellitus",
            "hypertension": "hypertension",
            "high blood pressure": "hypertension",
            "high cholesterol": "hyperlipidemia",
            "asthma": "asthma",
            "copd": "COPD",
            "heart disease": "coronary artery disease",
            "cancer": "cancer",
            "bronchitis": "recent bronchitis",
            "pneumonia": "pneumonia"
        ]

        for statement in statements {
            let lower = statement.lowercased()

            // Skip if talking about family member
            if lower.contains("my dad") || lower.contains("my father") || lower.contains("my mom") ||
               lower.contains("my mother") || lower.contains("my brother") || lower.contains("my sister") ||
               lower.contains("family history") {
                continue
            }

            // Check for patient's conditions (use "I have" pattern)
            for (keyword, condition) in conditions {
                if lower.contains(keyword) && (lower.contains("i have") || lower.contains("i'm on") ||
                                               lower.contains("been on medication") || lower.contains("my ")) {
                    // Avoid "heart attack" if it's clearly about family
                    if keyword == "heart attack" && (lower.contains("dad had") || lower.contains("father had")) {
                        continue
                    }
                    history.insert(condition)
                }
            }

            // Smoking history - detailed extraction
            if (lower.contains("smoke") || lower.contains("smoking")) && !lower.contains("non-smoker") {
                var smokingStatus = ""
                var years: String?
                var packPerDay = false
                var quitYearsAgo: String?

                // Extract years smoked
                if let match = lower.range(of: #"(\d+)\s+years?"#, options: .regularExpression) {
                    years = String(lower[match]).replacingOccurrences(of: "years", with: "").replacingOccurrences(of: "year", with: "").trimmingCharacters(in: .whitespaces)
                }

                // Check for pack a day
                if lower.contains("pack a day") || lower.contains("pack/day") || lower.contains("ppd") {
                    packPerDay = true
                }

                // Check if quit
                if lower.contains("quit") || lower.contains("former") || lower.contains("used to") {
                    // Extract how long ago quit
                    if let quitMatch = lower.range(of: #"quit\s+(\d+)\s+years?\s+ago"#, options: .regularExpression) {
                        let quitText = String(lower[quitMatch])
                        if let yearMatch = quitText.range(of: #"\d+"#, options: .regularExpression) {
                            quitYearsAgo = String(quitText[yearMatch])
                        }
                    }

                    // Build detailed former smoker string
                    if let years = years, packPerDay {
                        let packYears = Int(years) ?? 0
                        if let quitYears = quitYearsAgo {
                            smokingStatus = "Former smoker (\(packYears) pack-years, quit \(quitYears) years ago)"
                        } else {
                            smokingStatus = "Former smoker (\(packYears) pack-years)"
                        }
                    } else if let years = years {
                        if let quitYears = quitYearsAgo {
                            smokingStatus = "Former smoker (quit \(quitYears) years ago)"
                        } else {
                            smokingStatus = "Former smoker"
                        }
                    } else {
                        smokingStatus = "Former smoker"
                    }
                } else {
                    smokingStatus = "Active smoker"
                }

                if !smokingStatus.isEmpty {
                    history.insert(smokingStatus)
                }
            }
        }

        return Array(history).sorted()
    }

    // MARK: - Extract Family History

    private func extractFamilyHistory(from statements: [String]) -> [String] {
        var familyHistory: Set<String> = []

        for statement in statements {
            let lower = statement.lowercased()

            // Look for family member indicators
            var familyMember = ""
            if lower.contains("my dad") || lower.contains("my father") {
                familyMember = "Father"
            } else if lower.contains("my mom") || lower.contains("my mother") {
                familyMember = "Mother"
            } else if lower.contains("my brother") {
                familyMember = "Brother"
            } else if lower.contains("my sister") {
                familyMember = "Sister"
            }

            if !familyMember.isEmpty {
                // Extract condition and age
                if lower.contains("heart attack") || lower.contains("mi") {
                    // Try to extract age
                    if let ageMatch = lower.range(of: #"when he was (\d+)"#, options: .regularExpression) {
                        let ageText = String(lower[ageMatch])
                        if let numberMatch = ageText.range(of: #"\d+"#, options: .regularExpression) {
                            let age = String(ageText[numberMatch])
                            familyHistory.insert("\(familyMember) with MI at age \(age)")
                        }
                    } else {
                        familyHistory.insert("\(familyMember) with MI")
                    }
                }

                if lower.contains("stroke") || lower.contains("cva") {
                    familyHistory.insert("\(familyMember) with CVA")
                }

                if lower.contains("diabetes") {
                    familyHistory.insert("\(familyMember) with diabetes")
                }

                if lower.contains("cancer") {
                    familyHistory.insert("\(familyMember) with cancer")
                }

                if lower.contains("high blood pressure") || lower.contains("hypertension") {
                    familyHistory.insert("\(familyMember) with hypertension")
                }
            }
        }

        return Array(familyHistory).sorted()
    }

    // MARK: - Extract Medications

    private func extractMedications(from statements: [String]) -> [String] {
        var meds: Set<String> = []

        for statement in statements {
            let lower = statement.lowercased()

            // Skip if patient is denying medication use
            if lower.contains("no medications") || lower.contains("not taking") {
                continue
            }

            // Common medications with dose extraction
            let medPatterns: [(name: String, display: String)] = [
                ("lisinopril", "Lisinopril"),
                ("metoprolol", "Metoprolol"),
                ("atorvastatin", "Atorvastatin"),
                ("metformin", "Metformin"),
                ("albuterol", "Albuterol"),
                ("aspirin", "Aspirin"),
                ("ibuprofen", "Ibuprofen"),
                ("tylenol", "Tylenol"),
                ("acetaminophen", "Acetaminophen"),
                ("prednisone", "Prednisone"),
                ("levothyroxine", "Levothyroxine"),
                ("amlodipine", "Amlodipine")
            ]

            for (medName, displayName) in medPatterns {
                if lower.contains(medName) || (medName == "aspirin" && lower.contains("baby aspirin")) {
                    // Try to extract dose
                    var medString = displayName

                    // Look for dose pattern: "20 milligrams", "20mg", "81 mg"
                    let dosePattern = #"(\d+)\s*(?:mg|milligrams?)"#
                    if let regex = try? NSRegularExpression(pattern: dosePattern, options: .caseInsensitive),
                       let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
                        if let doseRange = Range(match.range(at: 1), in: lower) {
                            let dose = String(lower[doseRange])
                            medString += " \(dose)mg"
                        }
                    }

                    // Look for frequency: "once a day", "twice daily", "daily"
                    if lower.contains("once a day") || lower.contains("once daily") || lower.contains("every morning") {
                        medString += " daily"
                    } else if lower.contains("twice a day") || lower.contains("twice daily") {
                        medString += " BID"
                    } else if lower.contains("three times") {
                        medString += " TID"
                    }

                    meds.insert(medString)
                }
            }

            // Generic antibiotics
            if lower.contains("antibiotic") || lower.contains("z-pack") || lower.contains("azithromycin") {
                meds.insert("Recent antibiotics")
            }
        }

        return Array(meds).sorted()
    }

    // MARK: - Extract Vitals

    private func extractVitals(from text: String) -> ParsedVitalSigns? {
        let lower = text.lowercased()
        var hr: Int?
        var bp: String?
        var temp: Double?
        var o2: Int?

        // Heart rate
        let hrPattern = #"(?:heart rate|hr|pulse)[\s:]+(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: hrPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let value = Int(lower[range]) {
            hr = value
        }

        // Blood pressure
        let bpPattern = #"(\d{2,3})/(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: bpPattern),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range, in: lower) {
            bp = String(lower[range])
        }

        // Temperature
        let tempPattern = #"(\d{2,3}(?:\.\d)?)\s*(?:degrees|°)"#
        if let regex = try? NSRegularExpression(pattern: tempPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let value = Double(lower[range]) {
            temp = value
        }

        // O2 saturation
        let o2Pattern = #"(?:o2|oxygen|sat|saturation)[\s:]+(\d{2,3})%?"#
        if let regex = try? NSRegularExpression(pattern: o2Pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)),
           let range = Range(match.range(at: 1), in: lower),
           let value = Int(lower[range]) {
            o2 = value
        }

        if hr != nil || bp != nil || temp != nil || o2 != nil {
            return ParsedVitalSigns(heartRate: hr, bloodPressure: bp, temperature: temp, oxygenSaturation: o2)
        }

        return nil
    }

    // MARK: - Build Assessment

    private func buildAssessment(chiefComplaint: String, symptoms: SymptomDetails, timeline: SymptomTimeline) -> String {
        let lower = chiefComplaint.lowercased()

        // Determine acuity
        var acuity = "routine"
        if timeline.onset?.contains("minutes") == true || timeline.onset?.contains("hours") == true ||
           timeline.onset == "today" || timeline.onset == "this morning" {
            acuity = "acute"
        }

        // Match to common presentations
        if lower.contains("chest") && (lower.contains("pain") || lower.contains("pressure")) {
            if acuity == "acute" {
                return "Acute chest pain - rule out ACS, PE, aortic dissection"
            } else {
                return "Chest pain - consider musculoskeletal, GERD, anxiety"
            }
        }

        if lower.contains("palpitation") || lower.contains("heart racing") {
            return "Palpitations - consider arrhythmia, anxiety, thyroid disorder"
        }

        if lower.contains("breath") && (lower.contains("short") || lower.contains("difficulty")) {
            if acuity == "acute" {
                return "Acute dyspnea - rule out PE, pneumonia, CHF exacerbation"
            } else {
                return "Dyspnea - consider asthma, COPD, deconditioning"
            }
        }

        if lower.contains("headache") {
            if symptoms.severity == "severe" || timeline.onset == "sudden" {
                return "Severe headache - rule out SAH, meningitis, temporal arteritis"
            } else {
                return "Headache - consider migraine, tension headache, cluster headache"
            }
        }

        return "Clinical assessment based on presentation"
    }

    // MARK: - Generate Professional Note

    func generateNote(from medicalNote: ParsedMedicalNote) -> String {
        var note = ""

        // Chief Complaint
        note += "**CHIEF COMPLAINT:**\n"
        note += "\(medicalNote.chiefComplaint)\n\n"

        // HPI
        note += "**HISTORY OF PRESENT ILLNESS:**\n\n"
        note += "Patient presents with \(medicalNote.chiefComplaint.lowercased())"

        // Add symptom details
        let details = medicalNote.symptomDetails
        var descriptors: [String] = []
        if let quality = details.quality { descriptors.append("described as \(quality)") }
        if let severity = details.severity { descriptors.append("severity \(severity)") }
        if let location = details.location { descriptors.append("located \(location)") }
        if let radiation = details.radiation { descriptors.append("radiating \(radiation)") }

        if !descriptors.isEmpty {
            note += ", \(descriptors.joined(separator: ", "))"
        }
        note += ". "

        // Timeline
        if let onset = medicalNote.timeline.onset {
            note += "Symptom onset \(onset). "
        }
        if let duration = medicalNote.timeline.duration {
            note += "Duration: \(duration). "
        }
        if let progression = medicalNote.timeline.progression {
            note += "Course: \(progression). "
        }
        if let frequency = medicalNote.timeline.frequency {
            note += "Pattern: \(frequency). "
        }

        // Modifying factors
        if let agg = details.aggravatingFactors, !agg.isEmpty {
            note += "Aggravated by \(agg.joined(separator: ", ")). "
        }
        if let rel = details.relievingFactors, !rel.isEmpty {
            note += "Relieved by \(rel.joined(separator: ", ")). "
        }

        // Associated symptoms
        if !medicalNote.associatedSymptoms.isEmpty {
            note += "Associated symptoms include \(medicalNote.associatedSymptoms.joined(separator: ", ")). "
        }

        // Pertinent negatives
        if !medicalNote.pertinentNegatives.isEmpty {
            note += "Patient denies \(medicalNote.pertinentNegatives.joined(separator: ", ")). "
        }

        note += "\n\n"

        // PMH
        if !medicalNote.medicalHistory.isEmpty {
            note += "**PAST MEDICAL HISTORY:**\n"
            for condition in medicalNote.medicalHistory {
                note += "• \(condition)\n"
            }
            note += "\n"
        }

        // Family History
        if !medicalNote.familyHistory.isEmpty {
            note += "**FAMILY HISTORY:**\n"
            for familyItem in medicalNote.familyHistory {
                note += "• \(familyItem)\n"
            }
            note += "\n"
        }

        // Medications
        if !medicalNote.medications.isEmpty {
            note += "**MEDICATIONS:**\n"
            for med in medicalNote.medications {
                note += "• \(med)\n"
            }
            note += "\n"
        }

        // Vitals
        if let vitals = medicalNote.vitals {
            note += "**VITAL SIGNS:**\n"
            if let hr = vitals.heartRate {
                note += "• Heart Rate: \(hr) bpm\n"
            }
            if let bp = vitals.bloodPressure {
                note += "• Blood Pressure: \(bp)\n"
            }
            if let temp = vitals.temperature {
                note += "• Temperature: \(temp)°F\n"
            }
            if let o2 = vitals.oxygenSaturation {
                note += "• O2 Saturation: \(o2)%\n"
            }
            note += "\n"
        }

        // Assessment
        note += "**ASSESSMENT:**\n"
        note += "\(medicalNote.assessment)\n\n"

        note += "---\n"
        note += "📱 100% Offline - Smart Clinical Parser\n"

        return note
    }
}

// MARK: - Supporting Types

struct ConversationSegments {
    let patientStatements: [String]
    let doctorQuestions: [String]
}

struct ParsedMedicalNote {
    let chiefComplaint: String
    let symptomDetails: SymptomDetails
    let timeline: SymptomTimeline
    let associatedSymptoms: [String]
    let pertinentNegatives: [String]
    let medicalHistory: [String]
    let familyHistory: [String]
    let medications: [String]
    let vitals: ParsedVitalSigns?
    let assessment: String
}

struct SymptomDetails {
    let quality: String?
    let severity: String?
    let location: String?
    let radiation: String?
    let aggravatingFactors: [String]?
    let relievingFactors: [String]?
}

struct SymptomTimeline {
    let onset: String?
    let duration: String?
    let progression: String?
    let frequency: String?
}

struct ParsedVitalSigns {
    let heartRate: Int?
    let bloodPressure: String?
    let temperature: Double?
    let oxygenSaturation: Int?
}