import Foundation
import SwiftUI

/// Structured Visit Workflow for systematic documentation
/// Focuses on Initial Visit (CC/HPI/ROS) then MDM and Discharge Instructions
class StructuredVisitWorkflow: ObservableObject {
    
    // MARK: - Visit Phases
    
    enum VisitPhase: String, CaseIterable {
        case initial = "Initial Assessment"
        case mdm = "Medical Decision Making"
        case discharge = "Discharge Planning"
        
        var icon: String {
            switch self {
            case .initial: return "stethoscope"
            case .mdm: return "brain.head.profile"
            case .discharge: return "doc.text"
            }
        }
        
        var components: [DocumentationSection] {
            switch self {
            case .initial:
                return [.chiefComplaint, .hpi, .ros, .pmh, .psh, .socialHistory, .familyHistory]
            case .mdm:
                return [.assessment, .plan, .diagnostics, .therapeutics]
            case .discharge:
                return [.instructions, .followUp, .precautions, .medications]
            }
        }
    }
    
    // MARK: - Documentation Sections
    
    enum DocumentationSection: String, CaseIterable {
        // Initial Visit - Primary Focus
        case chiefComplaint = "Chief Complaint"
        case hpi = "History of Present Illness"
        case ros = "Review of Systems"
        
        // Initial Visit - Secondary
        case pmh = "Past Medical History"
        case psh = "Past Surgical History"
        case socialHistory = "Social History"
        case familyHistory = "Family History"
        
        // MDM Phase
        case assessment = "Assessment"
        case plan = "Plan"
        case diagnostics = "Diagnostic Studies"
        case therapeutics = "Therapeutic Interventions"
        
        // Discharge Phase
        case instructions = "Discharge Instructions"
        case followUp = "Follow-up"
        case precautions = "Return Precautions"
        case medications = "Discharge Medications"
        
        var prompts: [String] {
            switch self {
            case .chiefComplaint:
                return ["What brings you in today?", "Main concern?", "Chief complaint?"]
            case .hpi:
                return ["When did this start?", "Describe the symptoms", "What makes it better/worse?", "Associated symptoms?", "Severity 1-10?"]
            case .ros:
                return ["Any fever/chills?", "Headaches?", "Vision changes?", "Chest pain?", "Shortness of breath?", "Abdominal pain?", "Urinary symptoms?"]
            case .pmh:
                return ["Any medical conditions?", "Chronic illnesses?", "Previous hospitalizations?"]
            case .psh:
                return ["Any surgeries?", "Operations?", "Procedures?"]
            case .socialHistory:
                return ["Do you smoke?", "Alcohol use?", "Occupation?", "Living situation?"]
            case .familyHistory:
                return ["Family medical history?", "Parents' health?", "Siblings?"]
            case .assessment:
                return ["Clinical impression", "Differential diagnosis", "Working diagnosis"]
            case .plan:
                return ["Treatment plan", "Next steps", "Management strategy"]
            case .diagnostics:
                return ["Labs ordered", "Imaging", "Tests", "Studies"]
            case .therapeutics:
                return ["Medications given", "Procedures performed", "Interventions"]
            case .instructions:
                return ["Activity restrictions", "Diet", "Wound care", "Medication instructions"]
            case .followUp:
                return ["Follow up with", "Return in", "Call if", "Schedule appointment"]
            case .precautions:
                return ["Return immediately if", "Warning signs", "When to seek care"]
            case .medications:
                return ["New prescriptions", "Continue", "Stop", "Change dose"]
            }
        }
        
        var importance: ImportanceLevel {
            switch self {
            case .chiefComplaint, .hpi, .ros:
                return .critical
            case .assessment, .plan, .instructions:
                return .high
            case .pmh, .psh, .diagnostics, .therapeutics, .followUp, .precautions, .medications:
                return .medium
            case .socialHistory, .familyHistory:
                return .low
            }
        }
    }
    
    enum ImportanceLevel {
        case critical  // Must have
        case high      // Should have
        case medium    // Nice to have
        case low       // Optional
        
        var color: Color {
            switch self {
            case .critical: return .red
            case .high: return .orange
            case .medium: return .yellow
            case .low: return .gray
            }
        }
    }
    
    // MARK: - Visit State
    
    @Published var currentPhase: VisitPhase = .initial
    @Published var completedSections: Set<DocumentationSection> = []
    @Published var sectionContent: [DocumentationSection: String] = [:]
    @Published var visitStartTime: Date = Date()
    @Published var isActiveVisit: Bool = false
    
    // MARK: - Section Capture
    
    struct SectionCapture {
        let section: DocumentationSection
        var content: String
        var startTime: Date
        var endTime: Date?
        var confidence: Float  // 0-1 confidence in capture completeness
        var suggestedQuestions: [String]
        
        var duration: TimeInterval? {
            guard let endTime = endTime else { return nil }
            return endTime.timeIntervalSince(startTime)
        }
        
        var isComplete: Bool {
            return !content.isEmpty && confidence > 0.7
        }
    }
    
    // MARK: - Intelligent Section Detection
    
    /// Analyze transcription to auto-populate sections
    static func detectSections(in transcription: String) -> [DocumentationSection: String] {
        var sections: [DocumentationSection: String] = [:]
        let sentences = transcription.components(separatedBy: ". ")
        
        // Chief Complaint - Usually first symptom mentioned
        if let ccPattern = findPattern(in: transcription, 
                                       patterns: ["here for", "complaining of", "presents with", "chief complaint"]) {
            sections[.chiefComplaint] = ccPattern
        } else if !sentences.isEmpty {
            // First sentence often contains CC
            sections[.chiefComplaint] = sentences[0]
        }
        
        // HPI - Look for temporal and descriptive elements
        var hpiElements: [String] = []
        
        // Onset
        if let onset = findPattern(in: transcription,
                                   patterns: ["started", "began", "since", "for the past", "ago"]) {
            hpiElements.append(onset)
        }
        
        // Location
        if let location = findPattern(in: transcription,
                                      patterns: ["located in", "pain in", "discomfort in", "left", "right", "bilateral"]) {
            hpiElements.append(location)
        }
        
        // Duration
        if let duration = findPattern(in: transcription,
                                     patterns: ["minutes", "hours", "days", "weeks", "months", "constant", "intermittent"]) {
            hpiElements.append(duration)
        }
        
        // Character/Quality
        if let quality = findPattern(in: transcription,
                                    patterns: ["sharp", "dull", "aching", "burning", "stabbing", "throbbing", "pressure"]) {
            hpiElements.append(quality)
        }
        
        // Severity
        if let severity = findPattern(in: transcription,
                                     patterns: ["out of 10", "/10", "mild", "moderate", "severe", "worst", "unbearable"]) {
            hpiElements.append(severity)
        }
        
        // Timing
        if let timing = findPattern(in: transcription,
                                   patterns: ["worse at", "better in", "morning", "night", "after eating", "with activity"]) {
            hpiElements.append(timing)
        }
        
        // Alleviating/Aggravating
        if let factors = findPattern(in: transcription,
                                     patterns: ["better with", "worse with", "relieved by", "aggravated by", "helps", "doesn't help"]) {
            hpiElements.append(factors)
        }
        
        // Associated symptoms
        if let associated = findPattern(in: transcription,
                                       patterns: ["also has", "associated with", "along with", "denies", "no fever", "no nausea"]) {
            hpiElements.append(associated)
        }
        
        if !hpiElements.isEmpty {
            sections[.hpi] = hpiElements.joined(separator: ". ")
        }
        
        // ROS - System-by-system review
        var rosElements: [String] = []
        
        // Constitutional
        if transcription.lowercased().contains("fever") || transcription.lowercased().contains("chills") ||
           transcription.lowercased().contains("weight") || transcription.lowercased().contains("fatigue") {
            rosElements.append("Constitutional: " + extractROSDetails(transcription, system: "constitutional"))
        }
        
        // HEENT
        if transcription.lowercased().contains("headache") || transcription.lowercased().contains("vision") ||
           transcription.lowercased().contains("hearing") || transcription.lowercased().contains("throat") {
            rosElements.append("HEENT: " + extractROSDetails(transcription, system: "heent"))
        }
        
        // Cardiovascular
        if transcription.lowercased().contains("chest pain") || transcription.lowercased().contains("palpitations") ||
           transcription.lowercased().contains("edema") {
            rosElements.append("Cardiovascular: " + extractROSDetails(transcription, system: "cardiovascular"))
        }
        
        // Respiratory
        if transcription.lowercased().contains("shortness") || transcription.lowercased().contains("cough") ||
           transcription.lowercased().contains("wheez") {
            rosElements.append("Respiratory: " + extractROSDetails(transcription, system: "respiratory"))
        }
        
        // GI
        if transcription.lowercased().contains("nausea") || transcription.lowercased().contains("vomit") ||
           transcription.lowercased().contains("diarrhea") || transcription.lowercased().contains("abdominal") {
            rosElements.append("GI: " + extractROSDetails(transcription, system: "gi"))
        }
        
        // GU
        if transcription.lowercased().contains("urinary") || transcription.lowercased().contains("dysuria") ||
           transcription.lowercased().contains("frequency") {
            rosElements.append("GU: " + extractROSDetails(transcription, system: "gu"))
        }
        
        // Musculoskeletal
        if transcription.lowercased().contains("joint") || transcription.lowercased().contains("muscle") ||
           transcription.lowercased().contains("back pain") {
            rosElements.append("Musculoskeletal: " + extractROSDetails(transcription, system: "musculoskeletal"))
        }
        
        // Neurological
        if transcription.lowercased().contains("numbness") || transcription.lowercased().contains("tingling") ||
           transcription.lowercased().contains("weakness") || transcription.lowercased().contains("dizz") {
            rosElements.append("Neurological: " + extractROSDetails(transcription, system: "neurological"))
        }
        
        // Psychiatric
        if transcription.lowercased().contains("anxiety") || transcription.lowercased().contains("depression") ||
           transcription.lowercased().contains("mood") {
            rosElements.append("Psychiatric: " + extractROSDetails(transcription, system: "psychiatric"))
        }
        
        if !rosElements.isEmpty {
            sections[.ros] = rosElements.joined(separator: "\n")
        }
        
        // Past Medical History
        if let pmh = findPattern(in: transcription,
                                 patterns: ["medical history", "past medical", "diabetes", "hypertension", "asthma", "copd"]) {
            sections[.pmh] = pmh
        }
        
        // Past Surgical History
        if let psh = findPattern(in: transcription,
                                patterns: ["surgery", "operation", "appendectomy", "cholecystectomy", "hernia repair"]) {
            sections[.psh] = psh
        }
        
        // Social History
        if let sh = findPattern(in: transcription,
                               patterns: ["smoke", "tobacco", "alcohol", "drinks", "occupation", "married", "lives"]) {
            sections[.socialHistory] = sh
        }
        
        // Family History
        if let fh = findPattern(in: transcription,
                               patterns: ["family history", "mother", "father", "siblings", "cancer", "heart disease"]) {
            sections[.familyHistory] = fh
        }
        
        // Assessment
        if let assessment = findPattern(in: transcription,
                                       patterns: ["assessment", "impression", "likely", "suspect", "consistent with", "differential"]) {
            sections[.assessment] = assessment
        }
        
        // Plan
        if let plan = findPattern(in: transcription,
                                patterns: ["plan", "will", "order", "prescribe", "follow up", "return", "admit", "discharge"]) {
            sections[.plan] = plan
        }
        
        return sections
    }
    
    // MARK: - Helper Functions
    
    static func findPattern(in text: String, patterns: [String]) -> String? {
        let lower = text.lowercased()
        
        for pattern in patterns {
            if let range = lower.range(of: pattern) {
                // Get the sentence containing this pattern
                let beforePattern = String(text[..<range.lowerBound])
                let afterPattern = String(text[range.upperBound...])
                
                // Find sentence boundaries
                let sentenceStart = beforePattern.lastIndex(of: ".") ?? text.startIndex
                let sentenceEnd = afterPattern.firstIndex(of: ".") ?? text.endIndex
                
                let fullRange = sentenceStart...sentenceEnd
                var sentence = String(text[fullRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                
                if !sentence.isEmpty {
                    return sentence
                }
            }
        }
        
        return nil
    }
    
    static func extractROSDetails(_ text: String, system: String) -> String {
        let lower = text.lowercased()
        var positives: [String] = []
        var negatives: [String] = []
        
        switch system {
        case "constitutional":
            if lower.contains("fever") { positives.append("fever") }
            if lower.contains("no fever") { negatives.append("fever") }
            if lower.contains("chills") { positives.append("chills") }
            if lower.contains("weight loss") { positives.append("weight loss") }
            if lower.contains("fatigue") { positives.append("fatigue") }
            
        case "cardiovascular":
            if lower.contains("chest pain") { positives.append("chest pain") }
            if lower.contains("no chest pain") { negatives.append("chest pain") }
            if lower.contains("palpitations") { positives.append("palpitations") }
            if lower.contains("edema") { positives.append("edema") }
            
        case "respiratory":
            if lower.contains("shortness of breath") { positives.append("SOB") }
            if lower.contains("cough") { positives.append("cough") }
            if lower.contains("wheezing") { positives.append("wheezing") }
            
        default:
            break
        }
        
        var result = ""
        if !positives.isEmpty {
            result += "Positive for " + positives.joined(separator: ", ")
        }
        if !negatives.isEmpty {
            if !result.isEmpty { result += ". " }
            result += "Negative for " + negatives.joined(separator: ", ")
        }
        
        return result.isEmpty ? "Review performed" : result
    }
    
    // MARK: - Discharge Instructions Generator
    
    struct DischargeInstructions {
        let diagnosis: String
        let patientName: String
        var activityRestrictions: [String] = []
        var dietaryInstructions: [String] = []
        var medications: [MedicationInstruction] = []
        var woundCare: [String] = []
        var followUp: FollowUpInstruction?
        var returnPrecautions: [String] = []
        var additionalInstructions: [String] = []
        
        struct MedicationInstruction {
            let name: String
            let dose: String
            let frequency: String
            let duration: String?
            let instructions: String?
        }
        
        struct FollowUpInstruction {
            let provider: String
            let timeframe: String
            let reason: String?
            let phone: String?
        }
        
        func generatePatientHandout() -> String {
            var handout = """
            DISCHARGE INSTRUCTIONS
            ======================
            
            Patient: \(patientName)
            Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .short))
            Diagnosis: \(diagnosis)
            
            """
            
            // Activity
            if !activityRestrictions.isEmpty {
                handout += """
                ACTIVITY:
                ---------
                \(activityRestrictions.map { "• \($0)" }.joined(separator: "\n"))
                
                """
            }
            
            // Diet
            if !dietaryInstructions.isEmpty {
                handout += """
                DIET:
                -----
                \(dietaryInstructions.map { "• \($0)" }.joined(separator: "\n"))
                
                """
            }
            
            // Medications
            if !medications.isEmpty {
                handout += """
                MEDICATIONS:
                ------------
                
                """
                for med in medications {
                    handout += "• \(med.name) \(med.dose)\n"
                    handout += "  Take \(med.frequency)"
                    if let duration = med.duration {
                        handout += " for \(duration)"
                    }
                    if let instructions = med.instructions {
                        handout += "\n  Special instructions: \(instructions)"
                    }
                    handout += "\n\n"
                }
            }
            
            // Wound Care
            if !woundCare.isEmpty {
                handout += """
                WOUND CARE:
                -----------
                \(woundCare.map { "• \($0)" }.joined(separator: "\n"))
                
                """
            }
            
            // Follow-up
            if let followUp = followUp {
                handout += """
                FOLLOW-UP:
                ----------
                See \(followUp.provider) in \(followUp.timeframe)
                """
                if let reason = followUp.reason {
                    handout += "\nReason: \(reason)"
                }
                if let phone = followUp.phone {
                    handout += "\nCall \(phone) to schedule"
                }
                handout += "\n\n"
            }
            
            // Return Precautions
            if !returnPrecautions.isEmpty {
                handout += """
                RETURN TO EMERGENCY DEPARTMENT IF:
                -----------------------------------
                \(returnPrecautions.map { "• \($0)" }.joined(separator: "\n"))
                
                """
            }
            
            // Additional Instructions
            if !additionalInstructions.isEmpty {
                handout += """
                ADDITIONAL INSTRUCTIONS:
                ------------------------
                \(additionalInstructions.map { "• \($0)" }.joined(separator: "\n"))
                
                """
            }
            
            handout += """
            
            If you have any questions or concerns, please contact your doctor's office.
            
            _______________________________
            Provider Signature
            """
            
            return handout
        }
    }
    
    // MARK: - Generate Discharge Instructions from Context
    
    static func generateDischargeInstructions(
        diagnosis: String,
        patientName: String,
        visitContext: String
    ) -> DischargeInstructions {
        
        var instructions = DischargeInstructions(
            diagnosis: diagnosis,
            patientName: patientName
        )
        
        // Common condition-specific instructions
        let lower = diagnosis.lowercased()
        
        // Activity restrictions based on diagnosis
        if lower.contains("fracture") || lower.contains("sprain") {
            instructions.activityRestrictions = [
                "Rest and elevate the affected area",
                "Use crutches or walker as directed",
                "No weight bearing for 48 hours",
                "Avoid strenuous activity"
            ]
        } else if lower.contains("concussion") {
            instructions.activityRestrictions = [
                "Rest for 24-48 hours",
                "No driving for 24 hours",
                "No sports or physical activity until cleared",
                "Avoid screens and bright lights"
            ]
        } else if lower.contains("back pain") {
            instructions.activityRestrictions = [
                "Avoid heavy lifting (>10 lbs)",
                "Gentle stretching as tolerated",
                "Alternate ice and heat",
                "Maintain good posture"
            ]
        }
        
        // Dietary instructions
        if lower.contains("gastro") || lower.contains("nausea") || lower.contains("vomiting") {
            instructions.dietaryInstructions = [
                "Clear liquids for 24 hours",
                "BRAT diet (bananas, rice, applesauce, toast)",
                "Avoid dairy, caffeine, and fatty foods",
                "Small frequent meals"
            ]
        } else if lower.contains("diabetes") {
            instructions.dietaryInstructions = [
                "Follow diabetic diet",
                "Monitor blood sugar as directed",
                "Limit carbohydrates"
            ]
        }
        
        // Return precautions - always include these
        instructions.returnPrecautions = [
            "Worsening symptoms",
            "New or severe pain",
            "Fever over 101°F",
            "Difficulty breathing",
            "Persistent vomiting",
            "Signs of infection (redness, warmth, pus)"
        ]
        
        // Condition-specific return precautions
        if lower.contains("head") || lower.contains("concussion") {
            instructions.returnPrecautions.append(contentsOf: [
                "Confusion or difficulty waking up",
                "Severe headache",
                "Repeated vomiting",
                "Seizure",
                "Weakness or numbness"
            ])
        } else if lower.contains("chest pain") || lower.contains("cardiac") {
            instructions.returnPrecautions.append(contentsOf: [
                "Chest pain or pressure",
                "Shortness of breath",
                "Dizziness or fainting",
                "Rapid or irregular heartbeat"
            ])
        }
        
        // Default follow-up
        instructions.followUp = DischargeInstructions.FollowUpInstruction(
            provider: "your primary care physician",
            timeframe: "2-3 days",
            reason: "recheck and ongoing care",
            phone: nil
        )
        
        return instructions
    }
}