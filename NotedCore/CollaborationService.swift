import Foundation
import Combine

@MainActor
class CollaborationService: ObservableObject {
    @Published var activeHandoffs: [ProviderHandoff] = []
    @Published var recentMessages: [TeamMessage] = []
    @Published var activeProviders: Int = 12
    @Published var teamMembers: [Provider] = []
    
    init() {
        loadInitialData()
        startRealTimeUpdates()
    }
    
    func createHandoff(_ handoff: ProviderHandoff) {
        activeHandoffs.append(handoff)
        
        // Simulate real-time notification
        let message = TeamMessage(
            id: UUID().uuidString,
            sender: handoff.fromProvider,
            content: "Created handoff for \(handoff.patientInitials)",
            timestamp: Date(),
            type: .handoff,
            isUnread: true
        )
        recentMessages.insert(message, at: 0)
    }
    
    func completeHandoff(_ handoffId: String) {
        activeHandoffs.removeAll { $0.id == handoffId }
    }
    
    func sendSecureMessage(_ message: String, to provider: String) {
        let teamMessage = TeamMessage(
            id: UUID().uuidString,
            sender: "Current User",
            content: message,
            timestamp: Date(),
            type: .message,
            isUnread: false
        )
        recentMessages.insert(teamMessage, at: 0)
    }
    
    private func loadInitialData() {
        // Load sample handoffs
        activeHandoffs = [
            ProviderHandoff(
                id: UUID().uuidString,
                patientInitials: "J.D.",
                fromProvider: "Dr. Smith",
                toProvider: "Dr. Johnson",
                summary: "65yo M with chest pain, vitals stable, awaiting cardiology consult",
                priority: .high,
                timestamp: Date().addingTimeInterval(-1200),
                hasCriticalItems: true,
                criticalItems: [
                    CriticalItem(type: .allergy, description: "Penicillin allergy"),
                    CriticalItem(type: .medication, description: "Taking Warfarin")
                ]
            ),
            ProviderHandoff(
                id: UUID().uuidString,
                patientInitials: "M.K.",
                fromProvider: "Dr. Williams",
                toProvider: "Dr. Brown",
                summary: "Post-op monitoring, recovery progressing well",
                priority: .medium,
                timestamp: Date().addingTimeInterval(-2400),
                hasCriticalItems: false,
                criticalItems: []
            )
        ]
        
        // Load sample messages
        recentMessages = [
            TeamMessage(
                id: UUID().uuidString,
                sender: "Dr. Chen",
                content: "Patient in room 205 requesting pain medication reassessment",
                timestamp: Date().addingTimeInterval(-300),
                type: .request,
                isUnread: true
            ),
            TeamMessage(
                id: UUID().uuidString,
                sender: "Nurse Rodriguez",
                content: "New patient admission in progress, ETA 15 minutes",
                timestamp: Date().addingTimeInterval(-600),
                type: .notification,
                isUnread: true
            ),
            TeamMessage(
                id: UUID().uuidString,
                sender: "Dr. Patel",
                content: "Lab results available for patient Thompson",
                timestamp: Date().addingTimeInterval(-900),
                type: .result,
                isUnread: false
            ),
            TeamMessage(
                id: UUID().uuidString,
                sender: "Pharmacist Lee",
                content: "Drug interaction alert resolved for patient Wilson",
                timestamp: Date().addingTimeInterval(-1200),
                type: .alert,
                isUnread: false
            )
        ]
        
        // Load team members
        teamMembers = [
            Provider(id: "1", name: "Dr. Sarah Chen", role: .physician, specialty: "Emergency Medicine", isOnline: true),
            Provider(id: "2", name: "Dr. Michael Johnson", role: .physician, specialty: "Internal Medicine", isOnline: true),
            Provider(id: "3", name: "Dr. Emily Williams", role: .physician, specialty: "Cardiology", isOnline: false),
            Provider(id: "4", name: "Nurse Patricia Rodriguez", role: .nurse, specialty: "Emergency", isOnline: true),
            Provider(id: "5", name: "Dr. James Patel", role: .physician, specialty: "Radiology", isOnline: true),
            Provider(id: "6", name: "Pharmacist David Lee", role: .pharmacist, specialty: "Clinical Pharmacy", isOnline: true)
        ]
    }
    
    private func startRealTimeUpdates() {
        // Simulate real-time updates every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateRealTimeUpdate()
            }
        }
    }
    
    private func simulateRealTimeUpdate() {
        // Randomly update active providers count
        if Int.random(in: 1...10) <= 3 {
            activeProviders = Int.random(in: 8...15)
        }
        
        // Occasionally add new messages
        if Int.random(in: 1...10) <= 2 {
            let sampleMessages = [
                "Patient vitals updated",
                "Consultation request received",
                "Lab results pending",
                "Discharge planning initiated",
                "Medication review completed"
            ]
            
            let newMessage = TeamMessage(
                id: UUID().uuidString,
                sender: teamMembers.randomElement()?.name ?? "System",
                content: sampleMessages.randomElement() ?? "System update",
                timestamp: Date(),
                type: TeamMessageType.allCases.randomElement() ?? .notification,
                isUnread: true
            )
            
            recentMessages.insert(newMessage, at: 0)
            
            // Keep only last 20 messages
            if recentMessages.count > 20 {
                recentMessages = Array(recentMessages.prefix(20))
            }
        }
    }
}

// MARK: - Data Models

struct ProviderHandoff: Identifiable {
    let id: String
    let patientInitials: String
    let fromProvider: String
    let toProvider: String
    let summary: String
    let priority: HandoffPriority
    let timestamp: Date
    let hasCriticalItems: Bool
    let criticalItems: [CriticalItem]
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum HandoffPriority: CaseIterable {
    case low, medium, high, critical
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

enum HandoffType: CaseIterable {
    case sbar, narrative, structured
    
    var displayName: String {
        switch self {
        case .sbar: return "SBAR Format"
        case .narrative: return "Narrative"
        case .structured: return "Structured"
        }
    }
}

struct CriticalItem: Identifiable {
    let id = UUID()
    let type: CriticalItemType
    let description: String
}

enum CriticalItemType: CaseIterable {
    case allergy, medication, condition, instruction
    
    var icon: String {
        switch self {
        case .allergy: return "exclamationmark.triangle.fill"
        case .medication: return "pills.fill"
        case .condition: return "heart.fill"
        case .instruction: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .allergy: return .red
        case .medication: return .blue
        case .condition: return .orange
        case .instruction: return .purple
        }
    }
}

struct TeamMessage: Identifiable {
    let id: String
    let sender: String
    let content: String
    let timestamp: Date
    let type: TeamMessageType
    var isUnread: Bool
}

enum TeamMessageType: CaseIterable {
    case message, notification, alert, request, result, handoff
    
    var color: Color {
        switch self {
        case .message: return .blue
        case .notification: return .green
        case .alert: return .red
        case .request: return .orange
        case .result: return .purple
        case .handoff: return .cyan
        }
    }
    
    var icon: String {
        switch self {
        case .message: return "message.fill"
        case .notification: return "bell.fill"
        case .alert: return "exclamationmark.triangle.fill"
        case .request: return "hand.raised.fill"
        case .result: return "doc.text.fill"
        case .handoff: return "arrow.triangle.2.circlepath"
        }
    }
}

struct Provider: Identifiable {
    let id: String
    let name: String
    let role: ProviderRole
    let specialty: String
    let isOnline: Bool
}

enum ProviderRole: CaseIterable {
    case physician, nurse, pharmacist, technician, specialist
    
    var displayName: String {
        switch self {
        case .physician: return "Physician"
        case .nurse: return "Nurse"
        case .pharmacist: return "Pharmacist"
        case .technician: return "Technician"
        case .specialist: return "Specialist"
        }
    }
    
    var icon: String {
        switch self {
        case .physician: return "stethoscope"
        case .nurse: return "cross.fill"
        case .pharmacist: return "pills.fill"
        case .technician: return "gear"
        case .specialist: return "brain.head.profile"
        }
    }
}

import SwiftUI