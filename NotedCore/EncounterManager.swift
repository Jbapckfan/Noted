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
        loadEncounters()
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

            // Use three-layer architecture for intelligent comprehension
            processTranscriptionWithThreeLayerArchitecture(transcription, for: encounterId)

            // Fallback: Also run legacy categorization for now during transition
            categorizeNewInformation(transcription, for: encounterId)
            saveEncounters()
        }
    }

    // MARK: - Three-Layer Architecture Integration

    /// Process transcription using the genius three-layer architecture
    /// Layer 1: Perception (what was said)
    /// Layer 2: Comprehension (what it means)
    /// Layer 3: Generation (how to document)
    private func processTranscriptionWithThreeLayerArchitecture(_ transcription: String, for encounterId: UUID) {
        guard let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) else { return }

        // Process through the three-layer pipeline
        let clinicalNote = ThreeLayerPipeline.process(transcription)

        // Store the generated clinical note
        activeEncounters[index].generatedClinicalNote = clinicalNote

        // Update chief complaint if detected and not already set
        if activeEncounters[index].chiefComplaint.isEmpty && !clinicalNote.chiefComplaint.isEmpty {
            activeEncounters[index].chiefComplaint = clinicalNote.chiefComplaint
        }
    }

    /// Generate a complete clinical note for an encounter using three-layer architecture
    func generateClinicalNoteForEncounter(_ encounterId: UUID) -> String? {
        guard let encounter = activeEncounters.first(where: { $0.id == encounterId }) else { return nil }

        // If we don't have transcription, return nil
        guard !encounter.transcription.isEmpty else { return nil }

        // Process the full transcription through three-layer architecture
        let clinicalNote = ThreeLayerPipeline.process(encounter.transcription)

        // Return formatted SOAP note
        return clinicalNote.generateSOAPNote()
    }

    /// Get quality metrics for an encounter's clinical note
    func getQualityMetrics(for encounterId: UUID) -> GenerationLayer.QualityMetrics? {
        guard let encounter = activeEncounters.first(where: { $0.id == encounterId }),
              let generatedNote = encounter.generatedClinicalNote else {
            return nil
        }

        return generatedNote.qualityMetrics
    }

    // MARK: - Intelligent Categorization

    private func categorizeNewInformation(_ text: String, for encounterId: UUID) {
        guard let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) else { return }

        let lowercased = text.lowercased()

        // Initialize structured note if needed
        if activeEncounters[index].structuredNote == nil {
            activeEncounters[index].structuredNote = StructuredMedicalNote()
        }

        // HPI - History of Present Illness (symptoms, onset, duration, severity)
        if lowercased.contains("pain") || lowercased.contains("ache") ||
           lowercased.contains("started") || lowercased.contains("began") ||
           lowercased.contains("since") || lowercased.contains("for") ||
           lowercased.contains("hours") || lowercased.contains("days") ||
           lowercased.contains("worse") || lowercased.contains("better") ||
           lowercased.contains("radiates") || lowercased.contains("sharp") ||
           lowercased.contains("dull") || lowercased.contains("burning") {
            activeEncounters[index].structuredNote?.hpi.append(text)
        }

        // ROS - Review of Systems (general symptoms by system)
        if lowercased.contains("fever") || lowercased.contains("chills") ||
           lowercased.contains("sweats") || lowercased.contains("weight") ||
           lowercased.contains("fatigue") || lowercased.contains("weakness") ||
           lowercased.contains("shortness of breath") || lowercased.contains("sob") ||
           lowercased.contains("cough") || lowercased.contains("nausea") ||
           lowercased.contains("vomiting") || lowercased.contains("diarrhea") ||
           lowercased.contains("constipation") || lowercased.contains("headache") ||
           lowercased.contains("dizziness") || lowercased.contains("vision") {
            activeEncounters[index].structuredNote?.ros.append(text)
        }

        // MDM - Medical Decision Making (assessment, differential, plan)
        if lowercased.contains("differential") || lowercased.contains("diagnosis") ||
           lowercased.contains("think") || lowercased.contains("consider") ||
           lowercased.contains("rule out") || lowercased.contains("unlikely") ||
           lowercased.contains("possible") || lowercased.contains("risk") ||
           lowercased.contains("plan") || lowercased.contains("order") ||
           lowercased.contains("test") || lowercased.contains("consult") ||
           lowercased.contains("ekg") || lowercased.contains("labs") ||
           lowercased.contains("imaging") || lowercased.contains("ct") ||
           lowercased.contains("xray") || lowercased.contains("ultrasound") {
            activeEncounters[index].structuredNote?.mdm.append(text)
        }

        // Discharge Instructions (follow-up, return precautions, medications)
        if lowercased.contains("follow up") || lowercased.contains("return") ||
           lowercased.contains("if worse") || lowercased.contains("precautions") ||
           lowercased.contains("discharge") || lowercased.contains("go home") ||
           lowercased.contains("instructions") || lowercased.contains("prescription") ||
           lowercased.contains("take") || lowercased.contains("medication") ||
           lowercased.contains("see your doctor") || lowercased.contains("come back") ||
           lowercased.contains("warning signs") {
            activeEncounters[index].structuredNote?.dischargeInstructions.append(text)
        }

        // PMH - Past Medical History
        if lowercased.contains("history of") || lowercased.contains("diagnosed with") ||
           lowercased.contains("hypertension") || lowercased.contains("diabetes") ||
           lowercased.contains("asthma") || lowercased.contains("copd") {
            activeEncounters[index].structuredNote?.pmh.append(text)
        }

        // Medications
        if lowercased.contains("taking") || lowercased.contains("medication") ||
           lowercased.contains("prescribed") || lowercased.contains("mg") ||
           lowercased.contains("lisinopril") || lowercased.contains("metformin") ||
           lowercased.contains("aspirin") || lowercased.contains("atorvastatin") {
            activeEncounters[index].structuredNote?.medications.append(text)
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

    func saveEncounters() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(activeEncounters)
            UserDefaults.standard.set(data, forKey: "saved_encounters")
            UserDefaults.standard.set(Date(), forKey: "last_save_time")
        } catch {
            print("Failed to save encounters: \(error)")
        }
    }

    func loadEncounters() {
        guard let data = UserDefaults.standard.data(forKey: "saved_encounters") else { return }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let loaded = try decoder.decode([MedicalEncounter].self, from: data)
            activeEncounters = loaded

            // Restore room occupancy
            for encounter in loaded where encounter.isActive {
                if let roomIndex = availableRooms.firstIndex(where: { $0.id == encounter.room.id }) {
                    availableRooms[roomIndex].isOccupied = true
                    availableRooms[roomIndex].currentEncounter = encounter.id
                }
            }
        } catch {
            print("Failed to load encounters: \(error)")
        }
    }

    // MARK: - Pause/Resume Functionality

    func pauseEncounter(_ encounterId: UUID) {
        if let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) {
            activeEncounters[index].isPaused = true
            activeEncounters[index].pauseTime = Date()
            activeEncounters[index].status = .waiting
            saveEncounters()
        }
    }

    func resumeEncounter(_ encounterId: UUID) {
        if let index = activeEncounters.firstIndex(where: { $0.id == encounterId }) {
            if let pauseTime = activeEncounters[index].pauseTime {
                let pauseDuration = Date().timeIntervalSince(pauseTime)
                activeEncounters[index].totalPausedDuration += pauseDuration
            }
            activeEncounters[index].isPaused = false
            activeEncounters[index].pauseTime = nil
            activeEncounters[index].status = .inProgress
            activeEncounters[index].lastUpdated = Date()
            currentEncounter = activeEncounters[index]
            saveEncounters()
        }
    }

    func deleteEncounter(_ encounterId: UUID) {
        // Remove from active encounters
        activeEncounters.removeAll { $0.id == encounterId }

        // Free up the room
        if let roomIndex = availableRooms.firstIndex(where: { $0.currentEncounter == encounterId }) {
            availableRooms[roomIndex].isOccupied = false
            availableRooms[roomIndex].currentEncounter = nil
        }

        // Clear current encounter if this was it
        if currentEncounter?.id == encounterId {
            currentEncounter = nil
        }

        saveEncounters()
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

    // Three-Layer Architecture: Generated clinical note with quality metrics
    var generatedClinicalNote: GenerationLayer.ClinicalNote?

    // Pause/Resume tracking
    var isPaused: Bool = false
    var pauseTime: Date?
    var totalPausedDuration: TimeInterval = 0

    var duration: TimeInterval? {
        if let endTime = endTime {
            return endTime.timeIntervalSince(startTime) - totalPausedDuration
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