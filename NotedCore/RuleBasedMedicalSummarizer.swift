import Foundation
import NaturalLanguage

/// Rule-based medical summarizer that actually understands clinical encounters
class RuleBasedMedicalSummarizer {
    static let shared = RuleBasedMedicalSummarizer()

    // MARK: - Analyze Full Transcript

    func analyzeTranscript(_ transcript: String) -> ClinicalEncounter {
        let lower = transcript.lowercased()

        // 1. Extract Chief Complaint
        let chiefComplaint = extractChiefComplaint(from: lower)

        // 2. Extract symptom characteristics
        let characteristics = extractSymptomCharacteristics(from: lower, chiefComplaint: chiefComplaint)

        // 3. Extract timeline
        let timeline = extractTimeline(from: lower)

        // 4. Extract associated symptoms
        let associatedSymptoms = extractAssociatedSymptoms(from: lower, chiefComplaint: chiefComplaint)

        // 5. Extract pertinent negatives
        let negatives = extractPertinentNegatives(from: lower, chiefComplaint: chiefComplaint)

        // 6. Extract medical history
        let history = extractMedicalHistory(from: lower)

        // 7. Extract medications
        let medications = extractMedications(from: lower)

        // 8. Extract vital signs if mentioned
        let vitals = extractVitals(from: lower)

        return ClinicalEncounter(
            chiefComplaint: chiefComplaint,
            characteristics: characteristics,
            timeline: timeline,
            associatedSymptoms: associatedSymptoms,
            pertinentNegatives: negatives,
            medicalHistory: history,
            medications: medications,
            vitals: vitals
        )
    }

    // MARK: - Extract Chief Complaint

    private func extractChiefComplaint(from text: String) -> String {
        // Look for explicit statements
        if let range = text.range(of: "having ") {
            let after = String(text[range.upperBound...])
            if let end = after.firstIndex(where: { $0 == "." || $0 == "," }) {
                let symptom = String(after[..<end]).trimmingCharacters(in: .whitespaces)
                if symptom.count < 30 {
                    return symptom
                }
            }
        }

        // Common chief complaints
        let complaints = [
            "palpitations", "chest pain", "shortness of breath", "headache",
            "abdominal pain", "fever", "cough", "dizziness", "back pain"
        ]

        for complaint in complaints {
            if text.contains(complaint) {
                return complaint
            }
        }

        return "unclear chief complaint"
    }

    // MARK: - Extract Symptom Characteristics

    private func extractSymptomCharacteristics(from text: String, chiefComplaint: String) -> [String] {
        var characteristics: [String] = []

        // Quality descriptors
        let qualities = ["sharp", "dull", "aching", "burning", "stabbing", "throbbing",
                        "crushing", "pressure", "racing", "pounding", "fast", "slow"]
        for quality in qualities {
            if text.contains(quality) {
                characteristics.append("Quality: \(quality)")
                break
            }
        }

        // Severity
        if let severity = extractSeverity(from: text) {
            characteristics.append("Severity: \(severity)")
        }

        // Location for pain
        if chiefComplaint.contains("pain") {
            let locations = ["chest", "head", "abdomen", "back", "left", "right", "center"]
            for location in locations {
                if text.contains(location) {
                    characteristics.append("Location: \(location)")
                    break
                }
            }
        }

        // Duration
        if let duration = extractDuration(from: text) {
            characteristics.append("Duration: \(duration)")
        }

        return characteristics
    }

    private func extractSeverity(from text: String) -> String? {
        // Numeric scale
        let scalePattern = #"(\d+)\s*(?:out of|\/)\s*10"#
        if let regex = try? NSRegularExpression(pattern: scalePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return "\(text[range])/10"
        }

        // Descriptive
        if text.contains("severe") { return "severe" }
        if text.contains("moderate") { return "moderate" }
        if text.contains("mild") { return "mild" }

        return nil
    }

    private func extractDuration(from text: String) -> String? {
        // Pattern: "for X hours/days/weeks"
        let patterns = [
            #"(?:for|lasting|about)\s+(\d+)\s+(hour|day|week|month)s?"#,
            #"(\d+)\s+(hour|day|week|month)s?\s+ago"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return String(text[range])
            }
        }

        return nil
    }

    // MARK: - Extract Timeline

    private func extractTimeline(from text: String) -> Timeline {
        var onset: String?
        var progression: String?

        // Onset patterns
        let onsetPatterns = [
            "started", "began", "onset", "came on", "first noticed", "started having"
        ]

        for pattern in onsetPatterns {
            if let range = text.range(of: pattern) {
                // Get context around this
                let start = text.index(range.lowerBound, offsetBy: -10, limitedBy: text.startIndex) ?? text.startIndex
                let end = text.index(range.upperBound, offsetBy: 40, limitedBy: text.endIndex) ?? text.endIndex
                let context = String(text[start..<end])

                // Look for time markers
                if context.contains("hour") || context.contains("day") || context.contains("week") || context.contains("month") {
                    onset = context.trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        // Progression
        if text.contains("getting worse") || text.contains("worsening") {
            progression = "worsening"
        } else if text.contains("getting better") || text.contains("improving") {
            progression = "improving"
        } else if text.contains("same") || text.contains("unchanged") {
            progression = "stable"
        }

        return Timeline(onset: onset, progression: progression)
    }

    // MARK: - Extract Associated Symptoms

    private func extractAssociatedSymptoms(from text: String, chiefComplaint: String) -> [String] {
        var symptoms: [String] = []

        let symptomList = [
            "nausea", "vomiting", "diarrhea", "fever", "chills", "sweating",
            "shortness of breath", "chest pain", "dizziness", "lightheadedness",
            "headache", "confusion", "weakness", "numbness", "tingling"
        ]

        for symptom in symptomList {
            if text.contains(symptom) && !chiefComplaint.contains(symptom) {
                symptoms.append(symptom)
            }
        }

        return symptoms
    }

    // MARK: - Extract Pertinent Negatives

    private func extractPertinentNegatives(from text: String, chiefComplaint: String) -> [String] {
        var negatives: [String] = []

        // Look for explicit denials
        let denialPatterns = ["denies", "no ", "not ", "without", "negative for"]

        let expectedSymptoms: [String]
        if chiefComplaint.contains("chest") || chiefComplaint.contains("palpitation") {
            expectedSymptoms = ["shortness of breath", "diaphoresis", "nausea", "dizziness", "syncope", "chest pain"]
        } else if chiefComplaint.contains("headache") {
            expectedSymptoms = ["vision changes", "neck stiffness", "fever", "confusion", "nausea"]
        } else if chiefComplaint.contains("abdominal") {
            expectedSymptoms = ["vomiting", "diarrhea", "fever", "blood"]
        } else {
            expectedSymptoms = []
        }

        for symptom in expectedSymptoms {
            // Check if explicitly denied
            for pattern in denialPatterns {
                if text.contains(pattern + symptom) || text.contains(pattern + " " + symptom) {
                    negatives.append(symptom)
                    break
                }
            }

            // Also check if doctor asked and patient said no
            if text.contains(symptom + "?") || text.contains(symptom) {
                // Look for "no" or "nope" nearby
                if let range = text.range(of: symptom) {
                    let start = range.lowerBound
                    let end = text.index(range.upperBound, offsetBy: 30, limitedBy: text.endIndex) ?? text.endIndex
                    let context = String(text[start..<end]).lowercased()

                    if context.contains(" no") || context.contains("no ") || context.contains("nope") {
                        negatives.append(symptom)
                    }
                }
            }
        }

        return Array(Set(negatives)) // Remove duplicates
    }

    // MARK: - Extract Medical History

    private func extractMedicalHistory(from text: String) -> [String] {
        var history: [String] = []

        // Common conditions
        let conditions = [
            "diabetes", "hypertension", "high blood pressure", "high cholesterol",
            "asthma", "copd", "heart disease", "stroke", "cancer"
        ]

        for condition in conditions {
            if text.contains(condition) {
                history.append(condition)
            }
        }

        return history
    }

    // MARK: - Extract Medications

    private func extractMedications(from text: String) -> [String] {
        var meds: [String] = []

        // Common medications
        let medications = [
            "aspirin", "metoprolol", "lisinopril", "atorvastatin", "metformin",
            "albuterol", "ibuprofen", "tylenol", "acetaminophen"
        ]

        for med in medications {
            if text.contains(med) {
                meds.append(med)
            }
        }

        return meds
    }

    // MARK: - Extract Vitals

    private func extractVitals(from text: String) -> Vitals? {
        var heartRate: Int?
        var bloodPressure: String?

        // Heart rate pattern
        let hrPattern = #"(?:heart rate|hr|pulse)[\s:]+(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: hrPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text),
           let hr = Int(text[range]) {
            heartRate = hr
        }

        // Blood pressure pattern
        let bpPattern = #"(\d{2,3})/(\d{2,3})"#
        if let regex = try? NSRegularExpression(pattern: bpPattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range, in: text) {
            bloodPressure = String(text[range])
        }

        if heartRate != nil || bloodPressure != nil {
            return Vitals(heartRate: heartRate, bloodPressure: bloodPressure)
        }

        return nil
    }

    // MARK: - Generate Professional Note

    func generateNote(from encounter: ClinicalEncounter, noteType: NoteType) -> String {
        var note = ""

        note += "**SUBJECTIVE:**\n\n"
        note += "**Chief Complaint:** \(encounter.chiefComplaint.capitalized)\n\n"

        // HPI
        note += "**HPI:** Patient presents with \(encounter.chiefComplaint)"

        // Add characteristics
        if !encounter.characteristics.isEmpty {
            note += " (\(encounter.characteristics.joined(separator: ", ")))"
        }

        note += ". "

        // Timeline
        if let onset = encounter.timeline.onset {
            note += "Symptom onset \(onset). "
        }

        if let progression = encounter.timeline.progression {
            note += "Patient reports symptoms are \(progression). "
        }

        // Associated symptoms
        if !encounter.associatedSymptoms.isEmpty {
            note += "Associated symptoms: \(encounter.associatedSymptoms.joined(separator: ", ")). "
        }

        // Pertinent negatives
        if !encounter.pertinentNegatives.isEmpty {
            note += "Denies \(encounter.pertinentNegatives.joined(separator: ", ")). "
        }

        note += "\n\n"

        // Medical history
        if !encounter.medicalHistory.isEmpty {
            note += "**PMH:** \(encounter.medicalHistory.joined(separator: ", "))\n\n"
        }

        // Medications
        if !encounter.medications.isEmpty {
            note += "**Medications:** \(encounter.medications.joined(separator: ", "))\n\n"
        }

        // OBJECTIVE
        note += "**OBJECTIVE:**\n\n"

        if let vitals = encounter.vitals {
            if let hr = vitals.heartRate {
                note += "Heart Rate: \(hr) bpm\n"
            }
            if let bp = vitals.bloodPressure {
                note += "Blood Pressure: \(bp)\n"
            }
            note += "\n"
        }

        // ASSESSMENT
        note += "**ASSESSMENT:**\n\n"
        note += "Assessment pending further evaluation.\n\n"

        // PLAN
        note += "**PLAN:**\n\n"
        note += "1. Further diagnostic workup as indicated\n"
        note += "2. Patient counseling and follow-up\n\n"

        note += "---\n"
        note += "📱 100% Offline - Rule-Based Clinical Summarization\n"

        return note
    }
}

// MARK: - Supporting Types

struct ClinicalEncounter {
    let chiefComplaint: String
    let characteristics: [String]
    let timeline: Timeline
    let associatedSymptoms: [String]
    let pertinentNegatives: [String]
    let medicalHistory: [String]
    let medications: [String]
    let vitals: Vitals?
}

struct Timeline {
    let onset: String?
    let progression: String?
}

struct Vitals {
    let heartRate: Int?
    let bloodPressure: String?
}