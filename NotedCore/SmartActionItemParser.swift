import Foundation
import NaturalLanguage
import EventKit

/// Extracts actionable items from medical conversations and creates structured tasks
@MainActor
class SmartActionItemParser: ObservableObject {
    static let shared = SmartActionItemParser()
    
    // MARK: - Published Properties
    @Published var extractedActions: [MedicalAction] = []
    @Published var pendingFollowUps: [FollowUpTask] = []
    @Published var medicationChanges: [MedicationChange] = []
    @Published var schedulingNeeds: [SchedulingRequest] = []
    
    // MARK: - Action Types
    enum ActionType: String, CaseIterable, Codable {
        case followUp = "Follow-up"
        case medication = "Medication"
        case labOrder = "Lab Order"
        case imagingOrder = "Imaging"
        case referral = "Referral"
        case procedure = "Procedure"
        case patientInstruction = "Patient Instruction"
        case monitoring = "Monitoring"
    }
    
    enum Priority: String, CaseIterable, Codable {
        case urgent = "Urgent"
        case high = "High"
        case normal = "Normal"
        case low = "Low"
    }
    
    // MARK: - Pattern Matching
    private let followUpPatterns = [
        "follow up in (\\d+) (days?|weeks?|months?)",
        "see you in (\\d+) (days?|weeks?|months?)",
        "come back in (\\d+) (days?|weeks?|months?)",
        "return in (\\d+) (days?|weeks?|months?)",
        "recheck in (\\d+) (days?|weeks?|months?)",
        "appointment in (\\d+) (days?|weeks?|months?)"
    ]
    
    private let medicationPatterns = [
        "start (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml)) (.+?)(?:\\.|$|,)",
        "begin (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml)) (.+?)(?:\\.|$|,)",
        "prescribe (.+?) (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml)) (.+?)(?:\\.|$|,)",
        "increase (.+?) to (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml))",
        "decrease (.+?) to (\\d+(?:\\.\\d+)?\\s*(?:mg|mcg|g|ml))",
        "stop (.+?)(?:\\.|$|,)",
        "discontinue (.+?)(?:\\.|$|,)"
    ]
    
    private let labOrderPatterns = [
        "order (.+?) (lab|blood work|test)",
        "get (.+?) (lab|blood work|test)",
        "need (.+?) (lab|blood work|test)",
        "draw (.+?) (lab|blood work)",
        "check (.+?) level",
        "monitor (.+?) level"
    ]
    
    private let imagingPatterns = [
        "order (.+?) (scan|imaging|x-ray|mri|ct|ultrasound)",
        "get (.+?) (scan|imaging|x-ray|mri|ct|ultrasound)",
        "need (.+?) (scan|imaging|x-ray|mri|ct|ultrasound)",
        "schedule (.+?) (scan|imaging|x-ray|mri|ct|ultrasound)"
    ]
    
    private let referralPatterns = [
        "refer to (.+?)(?:\\.|$|,)",
        "see (.+?) specialist",
        "consult with (.+?)(?:\\.|$|,)",
        "send to (.+?)(?:\\.|$|,)"
    ]
    
    private let urgentKeywords = [
        "urgent", "asap", "immediately", "today", "now", "stat", "emergency"
    ]
    
    private let highPriorityKeywords = [
        "important", "critical", "serious", "concerning", "significant"
    ]
    
    private init() {}
    
    // MARK: - Main Parsing Function
    
    func parseTranscription(_ text: String) -> [MedicalAction] {
        let sentences = text.components(separatedBy: .punctuationCharacters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var actions: [MedicalAction] = []
        
        for sentence in sentences {
            actions.append(contentsOf: parseFollowUps(from: sentence))
            actions.append(contentsOf: parseMedications(from: sentence))
            actions.append(contentsOf: parseLabOrders(from: sentence))
            actions.append(contentsOf: parseImagingOrders(from: sentence))
            actions.append(contentsOf: parseReferrals(from: sentence))
            actions.append(contentsOf: parseInstructions(from: sentence))
        }
        
        // Update published arrays
        updateActionArrays(actions)
        
        return actions
    }
    
    // MARK: - Follow-up Parsing
    
    private func parseFollowUps(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        for pattern in followUpPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let numberRange = Range(match.range(at: 1), in: text),
                       let unitRange = Range(match.range(at: 2), in: text) {
                        
                        let number = String(text[numberRange])
                        let unit = String(text[unitRange])
                        
                        if let numValue = Int(number) {
                            let dueDate = calculateDueDate(number: numValue, unit: unit)
                            let priority = determinePriority(from: text)
                            
                            let action = MedicalAction(
                                type: .followUp,
                                description: "Follow-up appointment in \(number) \(unit)",
                                dueDate: dueDate,
                                priority: priority,
                                originalText: text
                            )
                            
                            actions.append(action)
                        }
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Medication Parsing
    
    private func parseMedications(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        for pattern in medicationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if match.numberOfRanges >= 2 {
                        if let medicationRange = Range(match.range(at: 1), in: text) {
                            let medication = String(text[medicationRange]).trimmingCharacters(in: .whitespaces)
                            
                            var dosage = ""
                            var frequency = ""
                            
                            if match.numberOfRanges >= 3,
                               let dosageRange = Range(match.range(at: 2), in: text) {
                                dosage = String(text[dosageRange])
                            }
                            
                            if match.numberOfRanges >= 4,
                               let frequencyRange = Range(match.range(at: 3), in: text) {
                                frequency = String(text[frequencyRange])
                            }
                            
                            let description = buildMedicationDescription(
                                medication: medication,
                                dosage: dosage,
                                frequency: frequency,
                                originalText: text
                            )
                            
                            let priority = determinePriority(from: text)
                            
                            let action = MedicalAction(
                                type: .medication,
                                description: description,
                                dueDate: Date(), // Medications usually start today
                                priority: priority,
                                originalText: text
                            )
                            
                            actions.append(action)
                        }
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Lab Order Parsing
    
    private func parseLabOrders(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        for pattern in labOrderPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let labRange = Range(match.range(at: 1), in: text) {
                        let labTest = String(text[labRange]).trimmingCharacters(in: .whitespaces)
                        
                        let description = "Order \(labTest) lab test"
                        let priority = determinePriority(from: text)
                        let dueDate = calculateLabDueDate(from: text)
                        
                        let action = MedicalAction(
                            type: .labOrder,
                            description: description,
                            dueDate: dueDate,
                            priority: priority,
                            originalText: text
                        )
                        
                        actions.append(action)
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Imaging Order Parsing
    
    private func parseImagingOrders(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        for pattern in imagingPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let imagingRange = Range(match.range(at: 1), in: text) {
                        let imagingType = String(text[imagingRange]).trimmingCharacters(in: .whitespaces)
                        
                        let description = "Schedule \(imagingType) imaging"
                        let priority = determinePriority(from: text)
                        let dueDate = calculateImagingDueDate(from: text)
                        
                        let action = MedicalAction(
                            type: .imagingOrder,
                            description: description,
                            dueDate: dueDate,
                            priority: priority,
                            originalText: text
                        )
                        
                        actions.append(action)
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Referral Parsing
    
    private func parseReferrals(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        for pattern in referralPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let specialistRange = Range(match.range(at: 1), in: text) {
                        let specialist = String(text[specialistRange]).trimmingCharacters(in: .whitespaces)
                        
                        let description = "Refer to \(specialist)"
                        let priority = determinePriority(from: text)
                        let dueDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
                        
                        let action = MedicalAction(
                            type: .referral,
                            description: description,
                            dueDate: dueDate,
                            priority: priority,
                            originalText: text
                        )
                        
                        actions.append(action)
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Patient Instructions
    
    private func parseInstructions(from text: String) -> [MedicalAction] {
        var actions: [MedicalAction] = []
        
        let instructionKeywords = [
            "take", "avoid", "drink", "eat", "exercise", "rest", "elevate",
            "apply", "use", "continue", "maintain", "monitor", "watch for"
        ]
        
        for keyword in instructionKeywords {
            let pattern = "\\b\(keyword)\\b[^.]*"
            
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let instructionRange = Range(match.range, in: text) {
                        let instruction = String(text[instructionRange]).trimmingCharacters(in: .whitespaces)
                        
                        // Only create action if it's a clear instruction (contains certain words)
                        if instruction.lowercased().contains("should") ||
                           instruction.lowercased().contains("need to") ||
                           instruction.lowercased().contains("must") {
                            
                            let priority = determinePriority(from: text)
                            
                            let action = MedicalAction(
                                type: .patientInstruction,
                                description: instruction,
                                dueDate: Date(),
                                priority: priority,
                                originalText: text
                            )
                            
                            actions.append(action)
                        }
                    }
                }
            }
        }
        
        return actions
    }
    
    // MARK: - Helper Functions
    
    private func determinePriority(from text: String) -> Priority {
        let lowercaseText = text.lowercased()
        
        for keyword in urgentKeywords {
            if lowercaseText.contains(keyword) {
                return .urgent
            }
        }
        
        for keyword in highPriorityKeywords {
            if lowercaseText.contains(keyword) {
                return .high
            }
        }
        
        return .normal
    }
    
    private func calculateDueDate(number: Int, unit: String) -> Date {
        let calendar = Calendar.current
        
        switch unit.lowercased() {
        case "day", "days":
            return calendar.date(byAdding: .day, value: number, to: Date()) ?? Date()
        case "week", "weeks":
            return calendar.date(byAdding: .weekOfYear, value: number, to: Date()) ?? Date()
        case "month", "months":
            return calendar.date(byAdding: .month, value: number, to: Date()) ?? Date()
        default:
            return calendar.date(byAdding: .day, value: number, to: Date()) ?? Date()
        }
    }
    
    private func calculateLabDueDate(from text: String) -> Date {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("today") || lowercaseText.contains("now") {
            return Date()
        }
        if lowercaseText.contains("tomorrow") {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        if lowercaseText.contains("urgent") || lowercaseText.contains("stat") {
            return Date()
        }
        
        // Default: within a week for labs
        return Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    }
    
    private func calculateImagingDueDate(from text: String) -> Date {
        let lowercaseText = text.lowercased()
        
        if lowercaseText.contains("urgent") || lowercaseText.contains("stat") {
            return Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        
        // Default: within 2 weeks for imaging
        return Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    }
    
    private func buildMedicationDescription(
        medication: String,
        dosage: String,
        frequency: String,
        originalText: String
    ) -> String {
        
        if originalText.lowercased().contains("stop") || originalText.lowercased().contains("discontinue") {
            return "Stop \(medication)"
        }
        
        if originalText.lowercased().contains("increase") {
            return "Increase \(medication) to \(dosage)"
        }
        
        if originalText.lowercased().contains("decrease") {
            return "Decrease \(medication) to \(dosage)"
        }
        
        // Default: start medication
        var description = "Start \(medication)"
        
        if !dosage.isEmpty {
            description += " \(dosage)"
        }
        
        if !frequency.isEmpty {
            description += " \(frequency)"
        }
        
        return description
    }
    
    private func updateActionArrays(_ actions: [MedicalAction]) {
        extractedActions = actions
        
        // Separate by type for easier access
        pendingFollowUps = actions.compactMap { action in
            guard action.type == .followUp else { return nil }
            return FollowUpTask(
                description: action.description,
                dueDate: action.dueDate,
                priority: action.priority
            )
        }
        
        medicationChanges = actions.compactMap { action in
            guard action.type == .medication else { return nil }
            return MedicationChange(
                description: action.description,
                priority: action.priority
            )
        }
        
        schedulingNeeds = actions.compactMap { action in
            guard [.labOrder, .imagingOrder, .referral].contains(action.type) else { return nil }
            return SchedulingRequest(
                description: action.description,
                dueDate: action.dueDate,
                priority: action.priority,
                type: action.type
            )
        }
    }
    
    // MARK: - Export Functions
    
    func exportToCalendar() {
        let eventStore = EKEventStore()
        
        eventStore.requestAccess(to: .event) { granted, error in
            guard granted else { return }
            
            for action in self.extractedActions {
                if action.type == .followUp {
                    let event = EKEvent(eventStore: eventStore)
                    event.title = action.description
                    event.startDate = action.dueDate
                    event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: action.dueDate) ?? action.dueDate
                    event.calendar = eventStore.defaultCalendarForNewEvents
                    
                    try? eventStore.save(event, span: .thisEvent)
                }
            }
        }
    }
    
    func generateActionReport() -> String {
        var report = "MEDICAL ACTION ITEMS\n"
        report += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n\n"
        
        if !pendingFollowUps.isEmpty {
            report += "FOLLOW-UPS:\n"
            for followUp in pendingFollowUps {
                report += "• \(followUp.description) - \(followUp.dueDate.formatted(date: .abbreviated, time: .omitted))\n"
            }
            report += "\n"
        }
        
        if !medicationChanges.isEmpty {
            report += "MEDICATIONS:\n"
            for medication in medicationChanges {
                report += "• \(medication.description)\n"
            }
            report += "\n"
        }
        
        if !schedulingNeeds.isEmpty {
            report += "SCHEDULING NEEDED:\n"
            for scheduling in schedulingNeeds {
                report += "• \(scheduling.description) - \(scheduling.dueDate.formatted(date: .abbreviated, time: .omitted))\n"
            }
            report += "\n"
        }
        
        return report
    }
}

// MARK: - Data Models

struct MedicalAction: Identifiable, Codable {
    let id = UUID()
    let type: SmartActionItemParser.ActionType
    let description: String
    let dueDate: Date
    let priority: SmartActionItemParser.Priority
    let originalText: String
    var isCompleted: Bool = false
}

struct FollowUpTask: Identifiable {
    let id = UUID()
    let description: String
    let dueDate: Date
    let priority: SmartActionItemParser.Priority
    var isCompleted: Bool = false
}

struct MedicationChange: Identifiable {
    let id = UUID()
    let description: String
    let priority: SmartActionItemParser.Priority
    var isCompleted: Bool = false
}

struct SchedulingRequest: Identifiable {
    let id = UUID()
    let description: String
    let dueDate: Date
    let priority: SmartActionItemParser.Priority
    let type: SmartActionItemParser.ActionType
    var isCompleted: Bool = false
}