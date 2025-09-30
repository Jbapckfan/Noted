import Foundation
import Combine

/// Manages medical encounters with room-based organization and chief complaint tracking
@MainActor
class EncounterManager: ObservableObject {
    static let shared = EncounterManager()
    
    // MARK: - Published Properties
    @Published var activeEncounters: [MedicalEncounter] = []
    @Published var currentEncounter: MedicalEncounter?
    @Published var availableRooms: [Room] = []
    @Published var recentChiefComplaints: [String] = []
    
    // MARK: - Encounter Status
    enum EncounterStatus: String, CaseIterable, Codable {
        case waiting = "Waiting"
        case inProgress = "In Progress"
        case completed = "Completed"
        case followUp = "Follow-up Needed"
        case discharged = "Discharged"
        
        var color: String {
            switch self {
            case .waiting: return "#FFB800"
            case .inProgress: return "#007AFF"
            case .completed: return "#34C759"
            case .followUp: return "#FF9500"
            case .discharged: return "#8E8E93"
            }
        }
    }
    
    // MARK: - Room Types
    enum RoomType: String, CaseIterable, Codable {
        case examRoom = "Exam Room"
        case procedure = "Procedure Room"
        case trauma = "Trauma Bay"
        case triage = "Triage"
        case consultation = "Consultation"
        case discharge = "Discharge"
        
        var icon: String {
            switch self {
            case .examRoom: return "stethoscope"
            case .procedure: return "cross.case"
            case .trauma: return "cross.fill"
            case .triage: return "list.clipboard"
            case .consultation: return "person.2"
            case .discharge: return "house"
            }
        }
    }
    
    // MARK: - Default Rooms
    private let defaultRooms: [Room] = [
        Room(number: "101", type: .examRoom, floor: 1),
        Room(number: "102", type: .examRoom, floor: 1),
        Room(number: "103", type: .examRoom, floor: 1),
        Room(number: "104", type: .examRoom, floor: 1),
        Room(number: "105", type: .examRoom, floor: 1),
        Room(number: "201", type: .examRoom, floor: 2),
        Room(number: "202", type: .examRoom, floor: 2),
        Room(number: "203", type: .examRoom, floor: 2),
        Room(number: "Trauma 1", type: .trauma, floor: 1),
        Room(number: "Trauma 2", type: .trauma, floor: 1),
        Room(number: "Proc 1", type: .procedure, floor: 1),
        Room(number: "Proc 2", type: .procedure, floor: 1),
        Room(number: "Triage", type: .triage, floor: 1),
        Room(number: "Discharge", type: .examRoom, floor: 1)
    ]
    
    // MARK: - Common Chief Complaints
    private let commonChiefComplaints: [String] = [
        "Chest pain",
        "Shortness of breath", 
        "Abdominal pain",
        "Headache",
        "Back pain",
        "Fever",
        "Nausea and vomiting",
        "Dizziness",
        "Cough",
        "Sore throat",
        "Joint pain",
        "Skin rash",
        "Fatigue",
        "Anxiety",
        "Follow-up visit",
        "Medication refill",
        "Physical exam",
        "Lab results",
        "Wound check",
        "Blood pressure check"
    ]
    
    init() {
        availableRooms = defaultRooms
        loadRecentChiefComplaints()
    }
    
    // MARK: - Encounter Creation
    
    func startNewEncounter(room: Room, chiefComplaint: String = "") -> MedicalEncounter {
        let encounter = MedicalEncounter(
            room: room,
            chiefComplaint: chiefComplaint,
            status: .inProgress,
            startTime: Date()
        )
        
        activeEncounters.append(encounter)
        currentEncounter = encounter
        
        // Add to recent chief complaints if not empty
        if !chiefComplaint.isEmpty {
            addToRecentChiefComplaints(chiefComplaint)
        }
        
        // Mark room as occupied
        if let index = availableRooms.firstIndex(where: { $0.id == room.id }) {
            availableRooms[index].isOccupied = true
            availableRooms[index].currentEncounter = encounter.id
        }
        
        return encounter
    }
    
    func startEncounterFromWatch(roomNumber: String, chiefComplaint: String = "") -> MedicalEncounter? {
        guard let room = availableRooms.first(where: { $0.number == roomNumber }) else {
            return nil
        }
        
        return startNewEncounter(room: room, chiefComplaint: chiefComplaint)
    }
    
    // MARK: - Encounter Management
    
    func updateEncounterStatus(_ encounterId: UUID, status: EncounterStatus) {
        if let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) {
            activeEncounters[index].status = status
            
            if status == .completed || status == .discharged {
                activeEncounters[index].endTime = Date()
                
                // Free up the room
                if let roomIndex = availableRooms.firstIndex(where: { 
                    $0.currentEncounter == encounterId 
                }) {
                    availableRooms[roomIndex].isOccupied = false
                    availableRooms[roomIndex].currentEncounter = nil
                }
            }
        }
    }
    
    func updateEncounterChiefComplaint(_ encounterId: UUID, chiefComplaint: String) {
        if let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) {
            activeEncounters[index].chiefComplaint = chiefComplaint
            addToRecentChiefComplaints(chiefComplaint)
        }
    }
    
    func addTranscriptionToEncounter(_ encounterId: UUID, transcription: String) {
        if let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) {
            activeEncounters[index].transcription += (activeEncounters[index].transcription.isEmpty ? "" : "\n") + transcription
            activeEncounters[index].lastUpdated = Date()
        }
    }
    
    func completeEncounter(_ encounterId: UUID) {
        updateEncounterStatus(encounterId, status: .completed)
        
        // If this was the current encounter, clear it
        if currentEncounter?.id == encounterId {
            currentEncounter = nil
        }
    }
    
    // MARK: - Room Management
    
    func getAvailableRooms() -> [Room] {
        return availableRooms.filter { !$0.isOccupied }
    }
    
    func getRoomsByFloor(_ floor: Int) -> [Room] {
        return availableRooms.filter { $0.floor == floor }
    }
    
    func getRoomsByType(_ type: RoomType) -> [Room] {
        return availableRooms.filter { $0.type == type }
    }
    
    func findRoom(by number: String) -> Room? {
        return availableRooms.first { $0.number.lowercased() == number.lowercased() }
    }
    
    // MARK: - Chief Complaint Management
    
    private func addToRecentChiefComplaints(_ complaint: String) {
        // Remove if already exists
        recentChiefComplaints.removeAll { $0.lowercased() == complaint.lowercased() }
        
        // Add to beginning
        recentChiefComplaints.insert(complaint, at: 0)
        
        // Keep only last 20
        if recentChiefComplaints.count > 20 {
            recentChiefComplaints.removeLast()
        }
        
        saveRecentChiefComplaints()
    }
    
    func getChiefComplaintSuggestions(for text: String) -> [String] {
        let searchText = text.lowercased()
        
        if searchText.isEmpty {
            return Array(recentChiefComplaints.prefix(10))
        }
        
        var suggestions: [String] = []
        
        // First, exact matches from recent
        suggestions.append(contentsOf: recentChiefComplaints.filter { 
            $0.lowercased().contains(searchText) 
        })
        
        // Then, matches from common complaints
        suggestions.append(contentsOf: commonChiefComplaints.filter { 
            $0.lowercased().contains(searchText) && 
            !suggestions.contains($0)
        })
        
        return Array(suggestions.prefix(10))
    }
    
    // MARK: - Encounter Search and Filtering
    
    func getEncountersByStatus(_ status: EncounterStatus) -> [MedicalEncounter] {
        return activeEncounters.filter { $0.status == status }
    }
    
    func getEncountersByRoom(_ room: Room) -> [MedicalEncounter] {
        return activeEncounters.filter { $0.room.id == room.id }
    }
    
    func getTodaysEncounters() -> [MedicalEncounter] {
        let calendar = Calendar.current
        let today = Date()
        
        return activeEncounters.filter { encounter in
            calendar.isDate(encounter.startTime, inSameDayAs: today)
        }
    }
    
    func getActiveEncounters() -> [MedicalEncounter] {
        return activeEncounters.filter { 
            $0.status == .inProgress || $0.status == .waiting 
        }
    }
    
    // MARK: - Watch Integration Support
    
    func getWatchRoomList() -> [WatchRoom] {
        return availableRooms.map { room in
            WatchRoom(
                number: room.number,
                type: room.type.rawValue,
                isOccupied: room.isOccupied,
                floor: room.floor,
                hasActiveEncounter: room.currentEncounter != nil
            )
        }
    }
    
    func startEncounterFromWatchData(_ data: [String: Any]) -> MedicalEncounter? {
        guard let roomNumber = data["roomNumber"] as? String else { return nil }
        
        let chiefComplaint = data["chiefComplaint"] as? String ?? ""
        
        return startEncounterFromWatch(roomNumber: roomNumber, chiefComplaint: chiefComplaint)
    }
    
    // MARK: - Statistics and Analytics
    
    func getEncounterStatistics() -> EncounterStatistics {
        let today = getTodaysEncounters()
        let active = getActiveEncounters()
        let completed = getEncountersByStatus(.completed)
        
        let averageDuration: TimeInterval
        if !completed.isEmpty {
            let totalDuration = completed.compactMap { encounter in
                encounter.duration
            }.reduce(0, +)
            averageDuration = totalDuration / Double(completed.count)
        } else {
            averageDuration = 0
        }
        
        return EncounterStatistics(
            totalToday: today.count,
            activeCount: active.count,
            completedCount: completed.count,
            averageDuration: averageDuration,
            roomUtilization: calculateRoomUtilization()
        )
    }
    
    private func calculateRoomUtilization() -> Float {
        let occupiedRooms = availableRooms.filter { $0.isOccupied }.count
        return Float(occupiedRooms) / Float(availableRooms.count)
    }
    
    // MARK: - Persistence
    
    private func saveRecentChiefComplaints() {
        UserDefaults.standard.set(recentChiefComplaints, forKey: "recent_chief_complaints")
    }
    
    private func loadRecentChiefComplaints() {
        if let saved = UserDefaults.standard.array(forKey: "recent_chief_complaints") as? [String] {
            recentChiefComplaints = saved
        }
    }
    
    // MARK: - Export Functions
    
    func exportEncounterData(_ encounter: MedicalEncounter) -> [String: Any] {
        return [
            "id": encounter.id.uuidString,
            "roomNumber": encounter.room.number,
            "chiefComplaint": encounter.chiefComplaint,
            "status": encounter.status.rawValue,
            "startTime": ISO8601DateFormatter().string(from: encounter.startTime),
            "endTime": encounter.endTime.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "duration": encounter.duration ?? 0,
            "transcription": encounter.transcription,
            "lastUpdated": ISO8601DateFormatter().string(from: encounter.lastUpdated)
        ]
    }
    
    func generateEncounterSummary(_ encounter: MedicalEncounter) -> String {
        var summary = "ENCOUNTER SUMMARY\n"
        summary += "Room: \(encounter.room.number)\n"
        summary += "Chief Complaint: \(encounter.chiefComplaint.isEmpty ? "Not specified" : encounter.chiefComplaint)\n"
        summary += "Start Time: \(encounter.startTime.formatted(date: .abbreviated, time: .shortened))\n"
        
        if let endTime = encounter.endTime {
            summary += "End Time: \(endTime.formatted(date: .abbreviated, time: .shortened))\n"
            if let duration = encounter.duration {
                let minutes = Int(duration / 60)
                summary += "Duration: \(minutes) minutes\n"
            }
        }
        
        summary += "Status: \(encounter.status.rawValue)\n"
        
        if !encounter.transcription.isEmpty {
            summary += "\nTRANSCRIPTION:\n"
            summary += encounter.transcription
        }
        
        return summary
    }
}

// MARK: - Data Models

struct MedicalEncounter: Identifiable, Codable {
    let id = UUID()
    let room: Room
    var chiefComplaint: String
    var status: EncounterManager.EncounterStatus
    let startTime: Date
    var endTime: Date?
    var transcription: String = ""
    var lastUpdated: Date = Date()
    var notes: String = ""
    var structuredNote: StructuredMedicalNote?
    var actionItems: [MedicalAction] = []
    
    var duration: TimeInterval? {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime)
        }
        return nil
    }
    
    var isActive: Bool {
        return status == .inProgress || status == .waiting
    }
}

struct Room: Identifiable, Codable {
    let id = UUID()
    let number: String
    let type: EncounterManager.RoomType
    let floor: Int
    var isOccupied: Bool = false
    var currentEncounter: UUID?
    var equipment: [String] = []
    var specialNotes: String = ""
    
    var displayName: String {
        return "\(type.rawValue) \(number)"
    }
}

struct WatchRoom: Identifiable {
    let id = UUID()
    let number: String
    let type: String
    let isOccupied: Bool
    let floor: Int
    let hasActiveEncounter: Bool
}

struct EncounterStatistics {
    let totalToday: Int
    let activeCount: Int
    let completedCount: Int
    let averageDuration: TimeInterval
    let roomUtilization: Float
    
    var formattedAverageDuration: String {
        let minutes = Int(averageDuration / 60)
        return "\(minutes) min"
    }
    
    var formattedUtilization: String {
        return "\(Int(roomUtilization * 100))%"
    }
}