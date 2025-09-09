import Foundation

// MARK: - Patient Management Models

struct Patient: Identifiable, Codable {
    let id: String
    let firstName: String
    let lastName: String
    let age: Int
    let gender: String
    let room: String
    let chiefComplaint: String
    let arrivalTime: Date
    var status: PatientStatus
    let assignedProvider: String
    let acuity: Int
    var chartLevel: ChartLevel
    var rvuValue: Double
    var criticalAlerts: [ClinicalAlert]
    var pendingResults: [PendingResult]
    
    var fullName: String {
        "\(lastName), \(firstName)"
    }
    
    var displayAge: String {
        "\(age)\(gender.first?.uppercased() ?? "")"
    }
    
    var timeInDepartment: TimeInterval {
        Date().timeIntervalSince(arrivalTime)
    }
    
    var formattedTimeInDepartment: String {
        let hours = Int(timeInDepartment) / 3600
        let minutes = Int(timeInDepartment.truncatingRemainder(dividingBy: 3600)) / 60
        return "\(hours):\(String(format: "%02d", minutes))"
    }
}

enum PatientStatus: String, Codable, CaseIterable {
    case arriving = "Arriving"
    case triaged = "Triaged"
    case roomed = "Roomed"
    case inProgress = "In Progress"
    case awaitingResults = "Labs Pending"
    case consulting = "Consulting"
    case boarding = "Boarding"
    case dischargeReady = "D/C Ready"
    case discharged = "Discharged"
    
    var icon: String {
        switch self {
        case .arriving: return "🚶"
        case .triaged: return "📋"
        case .roomed: return "🏥"
        case .inProgress: return "🩺"
        case .awaitingResults: return "⏰"
        case .consulting: return "👨‍⚕️"
        case .boarding: return "🛏️"
        case .dischargeReady: return "🏠"
        case .discharged: return "✅"
        }
    }
    
    var priority: Int {
        switch self {
        case .arriving: return 1
        case .triaged: return 2
        case .roomed: return 3
        case .inProgress: return 4
        case .awaitingResults: return 5
        case .consulting: return 6
        case .boarding: return 7
        case .dischargeReady: return 8
        case .discharged: return 9
        }
    }
}

struct ChartLevel: Codable {
    let current: Int
    let potential: Int
    let completionPercentage: Int
    let missingElements: [String]
    let rvuCurrent: Double
    let rvuPotential: Double
    
    var revenueOpportunity: Double {
        rvuPotential - rvuCurrent
    }
    
    var levelDisplay: String {
        current == potential ? "\(current)" : "\(current)→\(potential)"
    }
}

struct ClinicalAlert: Identifiable, Codable {
    let id: String
    let type: AlertType
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let patientId: String
    let actionable: Bool
    let autoActions: [String]
    
    enum AlertType: String, Codable {
        case sepsis = "Sepsis"
        case criticalValue = "Critical Lab"
        case procedureOpportunity = "Procedure"
        case revenueOpportunity = "Revenue"
        case clinicalReminder = "Clinical"
        case qualityMetric = "Quality"
    }
    
    enum AlertSeverity: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .low: return "systemBlue"
            case .medium: return "systemOrange"
            case .high: return "systemRed"
            case .critical: return "systemPurple"
            }
        }
    }
}

struct PendingResult: Identifiable, Codable {
    let id: String
    let test: String
    let orderedTime: Date
    let expectedTime: Date
    let priority: ResultPriority
    
    enum ResultPriority: String, Codable {
        case routine = "Routine"
        case urgent = "Urgent"
        case stat = "STAT"
    }
    
    var timeRemaining: TimeInterval {
        expectedTime.timeIntervalSinceNow
    }
    
    var formattedTimeRemaining: String {
        let minutes = Int(timeRemaining) / 60
        return minutes > 0 ? "\(minutes) min" : "Due"
    }
}

// MARK: - Shift Management Models

struct ShiftMetrics: Codable {
    let startTime: Date
    var endTime: Date?
    let providerId: String
    var patientsSeenCount: Int
    var totalRVUs: Double
    var averageLevel: Double
    var hourlyRate: Double
    var completedDischarges: Int
    var qualityMetrics: QualityMetrics
    var missedOpportunities: [MissedOpportunity]
    
    var shiftDuration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var formattedShiftDuration: String {
        let hours = Int(shiftDuration) / 3600
        let minutes = Int(shiftDuration.truncatingRemainder(dividingBy: 3600)) / 60
        return "\(hours)h \(minutes)m"
    }
    
    var patientsPerHour: Double {
        shiftDuration > 0 ? Double(patientsSeenCount) / (shiftDuration / 3600) : 0
    }
    
    var rvuPerHour: Double {
        shiftDuration > 0 ? totalRVUs / (shiftDuration / 3600) : 0
    }
}

struct QualityMetrics: Codable {
    var sepsisBundle: Double
    var doorToDoc: Double
    var patientSatisfaction: Double
    var documentationRate: Double
    var returnRate: Double
}

struct MissedOpportunity: Identifiable, Codable {
    let id: String
    let type: OpportunityType
    let description: String
    let potentialRVU: Double
    let potentialRevenue: Double
    let patientId: String
    
    enum OpportunityType: String, Codable {
        case procedure = "Procedure"
        case criticalCare = "Critical Care"
        case documentation = "Documentation"
        case levelUpgrade = "Level Upgrade"
    }
}

// MARK: - Revenue Optimization Models

struct RevenueOpportunity: Identifiable, Codable {
    let id: String
    let patientId: String
    let type: OpportunityType
    let description: String
    let quickFix: String?
    let estimatedTime: Int // seconds
    let rvuIncrease: Double
    let revenueIncrease: Double
    let priority: Priority
    
    enum OpportunityType: String, Codable {
        case socialHistory = "Social History"
        case reviewOfSystems = "Review of Systems"
        case dataReview = "Data Review"
        case procedureDocumentation = "Procedure Documentation"
        case levelUpgrade = "Level Upgrade"
    }
    
    enum Priority: String, Codable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        
        var sortOrder: Int {
            switch self {
            case .high: return 3
            case .medium: return 2
            case .low: return 1
            }
        }
    }
}

// MARK: - Handoff Models

struct HandoffReport: Codable {
    let shiftDate: Date
    let fromProvider: String
    let toProvider: String
    let criticalPatients: [HandoffPatient]
    let timeSensitiveActions: [TimeSensitiveAction]
    let boardingPatients: [Patient]
    let departmentMetrics: DepartmentMetrics
    
    var formattedShiftTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: shiftDate)
    }
}

struct HandoffPatient: Identifiable, Codable {
    let id: String
    let patient: Patient
    let summary: String
    let actionItems: [String]
    let familyUpdates: String?
    let criticalTiming: String?
    let consultants: [String]
}

struct TimeSensitiveAction: Identifiable, Codable {
    let id: String
    let patientId: String
    let action: String
    let timeframe: String
    let priority: ActionPriority
    
    enum ActionPriority: String, Codable {
        case immediate = "Immediate"
        case within1Hour = "Within 1 Hour"
        case within4Hours = "Within 4 Hours"
        case endOfShift = "End of Shift"
    }
}

struct DepartmentMetrics: Codable {
    let totalPatients: Int
    let averageWaitTime: TimeInterval
    let bedOccupancy: Double
    let staffingLevel: StaffingLevel
    
    enum StaffingLevel: String, Codable {
        case understaffed = "Understaffed"
        case adequate = "Adequate"
        case optimal = "Optimal"
        case overstaffed = "Overstaffed"
    }
}

// MARK: - Procedure Detection Models

struct DetectedProcedure: Identifiable, Codable {
    let id: String
    let transcript: String
    let procedureName: String
    let cptCode: String
    let rvuValue: Double
    let estimatedRevenue: Double
    let confidence: Double
    let timestamp: Date
    let autoGeneratedNote: String?
    
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.9...1.0: return .high
        case 0.7..<0.9: return .medium
        default: return .low
        }
    }
    
    enum ConfidenceLevel: String {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        
        var color: String {
            switch self {
            case .high: return "systemGreen"
            case .medium: return "systemOrange"
            case .low: return "systemRed"
            }
        }
    }
}

// MARK: - Note Analysis Models

struct NoteAnalysis: Codable {
    let currentLevel: Int
    let potentialLevel: Int
    let currentRVU: Double
    let potentialRVU: Double
    let missingElements: [MissingElement]
    let quickFixes: [QuickFix]
    let detectedProcedures: [DetectedProcedure]
    let analysisTime: TimeInterval
    
    var revenueOpportunity: Double {
        (potentialRVU - currentRVU) * 32.74 // 2024 conversion factor
    }
    
    var completionTime: Int {
        quickFixes.reduce(0) { $0 + $1.estimatedSeconds }
    }
}

struct MissingElement: Identifiable, Codable {
    let id: String
    let category: ElementCategory
    let description: String
    let impact: String
    let suggestion: String
    
    enum ElementCategory: String, Codable {
        case hpi = "HPI"
        case ros = "ROS"
        case pfsh = "PFSH"
        case physicalExam = "Physical Exam"
        case medicalDecisionMaking = "MDM"
        case procedures = "Procedures"
    }
}

struct QuickFix: Identifiable, Codable {
    let id: String
    let description: String
    let suggestedText: String
    let estimatedSeconds: Int
    let rvuImpact: Double
    let category: FixCategory
    
    enum FixCategory: String, Codable {
        case addText = "Add Text"
        case enhanceExisting = "Enhance Existing"
        case addProcedure = "Add Procedure"
        case upgradeLevel = "Upgrade Level"
    }
}