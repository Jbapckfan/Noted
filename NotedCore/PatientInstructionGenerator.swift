import Foundation
import NaturalLanguage

/// Generates patient discharge instructions and medication summaries from clinical conversations
@MainActor
class PatientInstructionGenerator: ObservableObject {
    static let shared = PatientInstructionGenerator()
    
    // MARK: - Published Properties
    @Published var generatedInstructions: PatientInstructions = PatientInstructions()
    @Published var dischargeSummary: DischargeSummary = DischargeSummary(
        patientName: "",
        dischargeDate: Date(),
        medications: [],
        followUps: [],
        activityRestrictions: [],
        dietInstructions: [],
        warningSignsToReturn: []
    )
    @Published var medicationList: [MedicationInstruction] = []
    @Published var followUpInstructions: [FollowUpInstruction] = []
    
    // MARK: - Instruction Templates
    private let medicationInstructionTemplates: [String: String] = [
        "twice daily": "Take {medication} {dose} by mouth twice daily (morning and evening)",
        "once daily": "Take {medication} {dose} by mouth once daily",
        "three times daily": "Take {medication} {dose} by mouth three times daily with meals",
        "as needed": "Take {medication} {dose} by mouth as needed for {indication}",
        "before meals": "Take {medication} {dose} by mouth 30 minutes before meals",
        "with food": "Take {medication} {dose} by mouth with food",
        "bedtime": "Take {medication} {dose} by mouth at bedtime"
    ]
    
    private let activityInstructions: [String: [String]] = [
        "rest": [
            "Rest and limit activity for the next few days",
            "Avoid strenuous activities until cleared by your doctor",
            "Return to activities gradually as tolerated"
        ],
        "elevation": [
            "Elevate the affected area above heart level when possible",
            "Keep elevated for 15-20 minutes several times daily",
            "Use pillows to maintain elevation while sleeping"
        ],
        "ice": [
            "Apply ice for 15-20 minutes every 2-3 hours for the first 48 hours",
            "Wrap ice in a towel - do not apply directly to skin",
            "Continue ice until swelling decreases"
        ],
        "heat": [
            "Apply warm compresses for 15-20 minutes several times daily",
            "Use after initial swelling has decreased",
            "Heat can help with stiffness and pain"
        ]
    ]
    
    private let warningSignTemplates: [String: [String]] = [
        "infection": [
            "Increasing redness, swelling, or warmth",
            "Red streaks from the wound",
            "Pus or unusual drainage",
            "Fever over 101°F (38.3°C)"
        ],
        "cardiac": [
            "Chest pain or pressure",
            "Severe shortness of breath",
            "Dizziness or fainting",
            "Rapid or irregular heartbeat"
        ],
        "neurological": [
            "Severe or worsening headache",
            "Vision changes",
            "Weakness or numbness",
            "Confusion or difficulty speaking"
        ],
        "respiratory": [
            "Difficulty breathing or shortness of breath",
            "Chest pain with breathing",
            "Coughing up blood",
            "High fever with cough"
        ]
    ]
    
    private init() {}
    
    // MARK: - Main Generation Function
    
    func generateInstructions(from transcription: String, patientName: String = "Patient") -> PatientInstructions {
        
        // Reset instructions
        generatedInstructions = PatientInstructions()
        medicationList = []
        followUpInstructions = []
        
        // Extract components
        extractMedicationInstructions(from: transcription)
        extractActivityInstructions(from: transcription)
        extractDietInstructions(from: transcription)
        extractFollowUpInstructions(from: transcription)
        extractWarningSignsContext(from: transcription)
        extractWoundCareInstructions(from: transcription)
        
        // Build comprehensive instructions
        buildComprehensiveInstructions(patientName: patientName)
        
        return generatedInstructions
    }
    
    // MARK: - Medication Instructions
    
    private func extractMedicationInstructions(from text: String) {
        let medicationPatterns = [
            "take (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|ml)) (.+?)(?:\\.|$|,)",
            "start (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|ml)) (.+?)(?:\\.|$|,)",
            "prescribe (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|ml)) (.+?)(?:\\.|$|,)",
            "continue (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|ml)) (.+?)(?:\\.|$|,)"
        ]
        
        for pattern in medicationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if match.numberOfRanges >= 4 {
                        if let medicationRange = Range(match.range(at: 1), in: text),
                           let dosageRange = Range(match.range(at: 2), in: text),
                           let frequencyRange = Range(match.range(at: 3), in: text) {
                            
                            let medication = String(text[medicationRange]).trimmingCharacters(in: .whitespaces)
                            let dosage = String(text[dosageRange])
                            let frequency = String(text[frequencyRange]).trimmingCharacters(in: .whitespaces)
                            
                            let instruction = createMedicationInstruction(
                                medication: medication,
                                dosage: dosage,
                                frequency: frequency,
                                originalText: text
                            )
                            
                            medicationList.append(instruction)
                        }
                    }
                }
            }
        }
        
        // Also look for simpler patterns
        extractSimpleMedicationInstructions(from: text)
    }
    
    private func extractSimpleMedicationInstructions(from text: String) {
        let simplePatterns = [
            "take (.+?) twice daily",
            "take (.+?) once daily",
            "take (.+?) as needed",
            "continue (.+?)(?:\\.|$|,)"
        ]
        
        for pattern in simplePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let medicationRange = Range(match.range(at: 1), in: text) {
                        let medicationText = String(text[medicationRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Parse medication and dosage if present
                        let components = medicationText.split(separator: " ")
                        let medication = String(components.first ?? "")
                        let dosage = components.count > 1 ? components[1...].joined(separator: " ") : ""
                        
                        let frequency = determineFrequency(from: text, around: match.range)
                        
                        let instruction = MedicationInstruction(
                            medication: medication,
                            dosage: dosage,
                            frequency: frequency,
                            route: "by mouth",
                            indication: extractMedicationIndication(from: text, medication: medication),
                            instructions: formatMedicationInstruction(medication: medication, dosage: dosage, frequency: frequency),
                            specialInstructions: extractSpecialInstructions(from: text, medication: medication)
                        )
                        
                        medicationList.append(instruction)
                    }
                }
            }
        }
    }
    
    private func createMedicationInstruction(medication: String, dosage: String, frequency: String, originalText: String) -> MedicationInstruction {
        let cleanFrequency = normalizeFrequency(frequency)
        let route = extractRoute(from: originalText) ?? "by mouth"
        let indication = extractMedicationIndication(from: originalText, medication: medication)
        let specialInstructions = extractSpecialInstructions(from: originalText, medication: medication)
        
        let formattedInstructions = formatMedicationInstruction(
            medication: medication,
            dosage: dosage,
            frequency: cleanFrequency,
            route: route,
            indication: indication
        )
        
        return MedicationInstruction(
            medication: medication,
            dosage: dosage,
            frequency: cleanFrequency,
            route: route,
            indication: indication,
            instructions: formattedInstructions,
            specialInstructions: specialInstructions
        )
    }
    
    // MARK: - Activity Instructions
    
    private func extractActivityInstructions(from text: String) {
        var activities: [String] = []
        let lowercaseText = text.lowercased()
        
        // Rest instructions
        if lowercaseText.contains("rest") || lowercaseText.contains("take it easy") || lowercaseText.contains("avoid activity") {
            activities.append(contentsOf: activityInstructions["rest"] ?? [])
        }
        
        // Elevation
        if lowercaseText.contains("elevate") || lowercaseText.contains("keep elevated") {
            activities.append(contentsOf: activityInstructions["elevation"] ?? [])
        }
        
        // Ice/Cold therapy
        if lowercaseText.contains("ice") || lowercaseText.contains("cold pack") {
            activities.append(contentsOf: activityInstructions["ice"] ?? [])
        }
        
        // Heat therapy
        if lowercaseText.contains("warm compress") || lowercaseText.contains("heat") {
            activities.append(contentsOf: activityInstructions["heat"] ?? [])
        }
        
        // Exercise/PT
        if lowercaseText.contains("exercise") || lowercaseText.contains("physical therapy") {
            activities.append("Follow up with physical therapy as recommended")
            activities.append("Perform prescribed exercises daily")
        }
        
        // Work/Activity restrictions
        if lowercaseText.contains("no lifting") || lowercaseText.contains("light duty") {
            activities.append("Avoid lifting anything heavier than 10 pounds")
            activities.append("No strenuous activities until cleared by your doctor")
        }
        
        generatedInstructions.activityInstructions = activities
    }
    
    // MARK: - Diet Instructions
    
    private func extractDietInstructions(from text: String) {
        var dietInstructions: [String] = []
        let lowercaseText = text.lowercased()
        
        // Clear liquids
        if lowercaseText.contains("clear liquids") {
            dietInstructions.append("Clear liquids only for the next 24 hours")
            dietInstructions.append("Water, broth, clear juices, tea without milk")
        }
        
        // Bland diet
        if lowercaseText.contains("bland diet") {
            dietInstructions.append("Follow a bland diet for the next few days")
            dietInstructions.append("Avoid spicy, fatty, or acidic foods")
            dietInstructions.append("BRAT diet: Bananas, Rice, Applesauce, Toast")
        }
        
        // Diabetic diet
        if lowercaseText.contains("diabetic diet") || lowercaseText.contains("watch your sugar") {
            dietInstructions.append("Follow your diabetic diet plan")
            dietInstructions.append("Monitor blood sugars as directed")
            dietInstructions.append("Avoid concentrated sweets and simple carbohydrates")
        }
        
        // Fluid restrictions
        if lowercaseText.contains("limit fluids") || lowercaseText.contains("fluid restriction") {
            dietInstructions.append("Limit fluid intake as directed by your doctor")
            dietInstructions.append("Track your daily fluid intake")
        }
        
        // Increased fluids
        if lowercaseText.contains("drink plenty") || lowercaseText.contains("increase fluids") {
            dietInstructions.append("Drink plenty of fluids - at least 8 glasses of water daily")
            dietInstructions.append("Clear liquids are best if you're having nausea")
        }
        
        generatedInstructions.dietInstructions = dietInstructions
    }
    
    // MARK: - Follow-up Instructions
    
    private func extractFollowUpInstructions(from text: String) {
        let followUpPatterns = [
            "follow up in (\\d+) (days?|weeks?|months?)",
            "see you in (\\d+) (days?|weeks?|months?)",
            "return in (\\d+) (days?|weeks?|months?)",
            "come back in (\\d+) (days?|weeks?|months?)"
        ]
        
        for pattern in followUpPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let numberRange = Range(match.range(at: 1), in: text),
                       let unitRange = Range(match.range(at: 2), in: text) {
                        
                        let number = String(text[numberRange])
                        let unit = String(text[unitRange])
                        
                        let instruction = FollowUpInstruction(
                            timeframe: "\(number) \(unit)",
                            provider: "your doctor",
                            reason: "routine follow-up",
                            instructions: "Schedule a follow-up appointment with your doctor in \(number) \(unit)"
                        )
                        
                        followUpInstructions.append(instruction)
                    }
                }
            }
        }
        
        // Specialist referrals
        extractSpecialistReferrals(from: text)
        
        generatedInstructions.followUpInstructions = followUpInstructions
    }
    
    private func extractSpecialistReferrals(from text: String) {
        let referralPatterns = [
            "refer to (.+?)(?:\\.|$|,)",
            "see (.+?) specialist",
            "follow up with (.+?)(?:\\.|$|,)"
        ]
        
        for pattern in referralPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let specialistRange = Range(match.range(at: 1), in: text) {
                        let specialist = String(text[specialistRange]).trimmingCharacters(in: .whitespaces)
                        
                        let instruction = FollowUpInstruction(
                            timeframe: "as scheduled",
                            provider: specialist,
                            reason: "specialist consultation",
                            instructions: "Follow up with \(specialist) as scheduled. We will provide a referral."
                        )
                        
                        followUpInstructions.append(instruction)
                    }
                }
            }
        }
    }
    
    // MARK: - Warning Signs
    
    private func extractWarningSignsContext(from text: String) {
        var warnings: [String] = []
        let lowercaseText = text.lowercased()
        
        // Determine context and add appropriate warning signs
        if lowercaseText.contains("infection") || lowercaseText.contains("wound") || lowercaseText.contains("antibiotic") {
            warnings.append(contentsOf: warningSignTemplates["infection"] ?? [])
        }
        
        if lowercaseText.contains("heart") || lowercaseText.contains("cardiac") || lowercaseText.contains("chest") {
            warnings.append(contentsOf: warningSignTemplates["cardiac"] ?? [])
        }
        
        if lowercaseText.contains("head") || lowercaseText.contains("neurologic") || lowercaseText.contains("brain") {
            warnings.append(contentsOf: warningSignTemplates["neurological"] ?? [])
        }
        
        if lowercaseText.contains("breath") || lowercaseText.contains("lung") || lowercaseText.contains("cough") {
            warnings.append(contentsOf: warningSignTemplates["respiratory"] ?? [])
        }
        
        // General warning signs if no specific context
        if warnings.isEmpty {
            warnings.append("Fever over 101°F (38.3°C)")
            warnings.append("Severe or worsening pain")
            warnings.append("Unusual symptoms or concerns")
        }
        
        generatedInstructions.warningSignsToReturn = warnings
    }
    
    // MARK: - Wound Care
    
    private func extractWoundCareInstructions(from text: String) {
        var woundCare: [String] = []
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("wound") || lowercaseText.contains("incision") || lowercaseText.contains("stitches") {
            woundCare.append("Keep the wound clean and dry")
            woundCare.append("Change dressing daily or as directed")
            woundCare.append("Gently clean with soap and water")
            
            if lowercaseText.contains("stitches") || lowercaseText.contains("sutures") {
                woundCare.append("Do not remove stitches - return for removal as scheduled")
                woundCare.append("Avoid soaking in baths or swimming until stitches are removed")
            }
            
            if lowercaseText.contains("staples") {
                woundCare.append("Return for staple removal as scheduled")
            }
        }
        
        generatedInstructions.woundCareInstructions = woundCare
    }
    
    // MARK: - Helper Functions
    
    private func normalizeFrequency(_ frequency: String) -> String {
        let freq = frequency.lowercased()
        
        if freq.contains("twice") || freq.contains("bid") || freq.contains("two times") {
            return "twice daily"
        } else if freq.contains("once") || freq.contains("daily") || freq.contains("qd") {
            return "once daily"
        } else if freq.contains("three") || freq.contains("tid") {
            return "three times daily"
        } else if freq.contains("four") || freq.contains("qid") {
            return "four times daily"
        } else if freq.contains("needed") || freq.contains("prn") {
            return "as needed"
        } else if freq.contains("bedtime") || freq.contains("hs") {
            return "at bedtime"
        }
        
        return frequency
    }
    
    private func determineFrequency(from text: String, around range: NSRange) -> String {
        let context = String(text).lowercased()
        
        if context.contains("twice") { return "twice daily" }
        if context.contains("once") { return "once daily" }
        if context.contains("three") { return "three times daily" }
        if context.contains("needed") { return "as needed" }
        
        return "as directed"
    }
    
    private func extractRoute(from text: String) -> String? {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("by mouth") || lowercaseText.contains("po") || lowercaseText.contains("oral") {
            return "by mouth"
        } else if lowercaseText.contains("topical") || lowercaseText.contains("apply") {
            return "topically"
        } else if lowercaseText.contains("injection") || lowercaseText.contains("inject") {
            return "by injection"
        } else if lowercaseText.contains("inhale") || lowercaseText.contains("nebulizer") {
            return "by inhalation"
        }
        
        return nil
    }
    
    private func extractMedicationIndication(from text: String, medication: String) -> String? {
        let indicationPatterns = [
            "\(medication).+?for (.+?)(?:\\.|$|,)",
            "take.+?\(medication).+?for (.+?)(?:\\.|$|,)"
        ]
        
        for pattern in indicationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let indicationRange = Range(match.range(at: 1), in: text) {
                        return String(text[indicationRange]).trimmingCharacters(in: .whitespaces)
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractSpecialInstructions(from text: String, medication: String) -> [String] {
        var special: [String] = []
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("with food") {
            special.append("Take with food to reduce stomach upset")
        }
        
        if lowercaseText.contains("empty stomach") {
            special.append("Take on an empty stomach, 1 hour before or 2 hours after meals")
        }
        
        if lowercaseText.contains("plenty of water") {
            special.append("Drink plenty of water while taking this medication")
        }
        
        if lowercaseText.contains("avoid alcohol") {
            special.append("Avoid alcohol while taking this medication")
        }
        
        return special
    }
    
    private func formatMedicationInstruction(medication: String, dosage: String, frequency: String, route: String = "by mouth", indication: String? = nil) -> String {
        var instruction = "Take \(medication)"
        
        if !dosage.isEmpty {
            instruction += " \(dosage)"
        }
        
        instruction += " \(route) \(frequency)"
        
        if let indication = indication, !indication.isEmpty {
            instruction += " for \(indication)"
        }
        
        return instruction
    }
    
    // MARK: - Comprehensive Instructions Builder
    
    private func buildComprehensiveInstructions(patientName: String) {
        generatedInstructions.patientName = patientName
        generatedInstructions.dateGenerated = Date()
        generatedInstructions.medicationInstructions = medicationList
        
        // Build discharge summary
        dischargeSummary = DischargeSummary(
            patientName: patientName,
            dischargeDate: Date(),
            medications: medicationList,
            followUps: followUpInstructions,
            activityRestrictions: generatedInstructions.activityInstructions,
            dietInstructions: generatedInstructions.dietInstructions,
            warningSignsToReturn: generatedInstructions.warningSignsToReturn
        )
    }
    
    // MARK: - Export Functions
    
    func generatePatientHandout() -> String {
        var handout = "DISCHARGE INSTRUCTIONS\n"
        handout += "Patient: \(generatedInstructions.patientName)\n"
        handout += "Date: \(Date().formatted(date: .abbreviated, time: .omitted))\n\n"
        
        if !medicationList.isEmpty {
            handout += "MEDICATIONS:\n"
            for medication in medicationList {
                handout += "• \(medication.instructions)\n"
                for special in medication.specialInstructions {
                    handout += "  - \(special)\n"
                }
            }
            handout += "\n"
        }
        
        if !generatedInstructions.activityInstructions.isEmpty {
            handout += "ACTIVITY:\n"
            for activity in generatedInstructions.activityInstructions {
                handout += "• \(activity)\n"
            }
            handout += "\n"
        }
        
        if !generatedInstructions.dietInstructions.isEmpty {
            handout += "DIET:\n"
            for diet in generatedInstructions.dietInstructions {
                handout += "• \(diet)\n"
            }
            handout += "\n"
        }
        
        if !followUpInstructions.isEmpty {
            handout += "FOLLOW-UP APPOINTMENTS:\n"
            for followUp in followUpInstructions {
                handout += "• \(followUp.instructions)\n"
            }
            handout += "\n"
        }
        
        if !generatedInstructions.woundCareInstructions.isEmpty {
            handout += "WOUND CARE:\n"
            for wound in generatedInstructions.woundCareInstructions {
                handout += "• \(wound)\n"
            }
            handout += "\n"
        }
        
        if !generatedInstructions.warningSignsToReturn.isEmpty {
            handout += "WHEN TO CALL YOUR DOCTOR OR RETURN TO THE HOSPITAL:\n"
            for warning in generatedInstructions.warningSignsToReturn {
                handout += "• \(warning)\n"
            }
            handout += "\n"
        }
        
        handout += "If you have any questions or concerns, please contact your doctor's office.\n"
        
        return handout
    }
    
    func generateMedicationList() -> String {
        var medList = "MEDICATION LIST\n"
        medList += "Patient: \(generatedInstructions.patientName)\n"
        medList += "Date: \(Date().formatted(date: .abbreviated, time: .omitted))\n\n"
        
        for medication in medicationList {
            medList += "\(medication.medication.uppercased())\n"
            medList += "Dose: \(medication.dosage)\n"
            medList += "Instructions: \(medication.instructions)\n"
            if let indication = medication.indication {
                medList += "Purpose: \(indication)\n"
            }
            if !medication.specialInstructions.isEmpty {
                medList += "Special Instructions: \(medication.specialInstructions.joined(separator: "; "))\n"
            }
            medList += "\n"
        }
        
        return medList
    }
}

// MARK: - Data Models

struct PatientInstructions {
    var patientName: String = ""
    var dateGenerated: Date = Date()
    var medicationInstructions: [MedicationInstruction] = []
    var activityInstructions: [String] = []
    var dietInstructions: [String] = []
    var followUpInstructions: [FollowUpInstruction] = []
    var woundCareInstructions: [String] = []
    var warningSignsToReturn: [String] = []
}

struct MedicationInstruction: Identifiable {
    let id = UUID()
    let medication: String
    let dosage: String
    let frequency: String
    let route: String
    let indication: String?
    let instructions: String
    let specialInstructions: [String]
}

struct FollowUpInstruction: Identifiable {
    let id = UUID()
    let timeframe: String
    let provider: String
    let reason: String
    let instructions: String
}

struct DischargeSummary {
    let patientName: String
    let dischargeDate: Date
    let medications: [MedicationInstruction]
    let followUps: [FollowUpInstruction]
    let activityRestrictions: [String]
    let dietInstructions: [String]
    let warningSignsToReturn: [String]
}