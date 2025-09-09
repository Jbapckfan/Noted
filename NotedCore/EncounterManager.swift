import Foundation
import CoreData
import Combine
import SwiftUI

@MainActor
class EncounterManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var activeEncounters: [MedicalEncounter] = []
    @Published var completedEncounters: [MedicalEncounter] = []
    @Published var currentEncounter: MedicalEncounter?
    @Published var selectedBed: String = ""
    @Published var savedEncounters: [MedicalEncounter] = []
    @Published var isEncounterActive = false
    
    // MARK: - Private Properties
    private let persistentContainer: NSPersistentContainer
    private let userDefaults = UserDefaults.standard
    private let activeEncountersKey = "ActiveEncounters"
    private let completedEncountersKey = "CompletedEncounters"
    private let maxActiveEncounters = 10
    private let maxCompletedEncounters = 50
    
    init() {
        persistentContainer = NSPersistentContainer(name: "NotedCore")
        persistentContainer.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data error: \(error)")
            }
        }
        
        loadEncounters()
        loadSavedEncounters()
    }
    
    // MARK: - Encounter Management
    func startNewEncounter(bed: String? = nil, chiefComplaint: String? = nil) {
        // Save current encounter if exists
        if let current = currentEncounter, !current.transcription.isEmpty {
            saveEncounter(current)
        }
        
        // Create new encounter
        let encounter = MedicalEncounter(
            id: UUID(),
            timestamp: Date(),
            bed: bed,
            chiefComplaint: chiefComplaint,
            transcription: "",
            generatedNote: "",
            noteType: .edNote,
            status: .active
        )
        
        currentEncounter = encounter
        isEncounterActive = true
    }
    
    func stopCurrentEncounter() {
        guard let current = currentEncounter else { return }
        
        current.status = .completed
        current.endTime = Date()
        
        saveEncounter(current)
        isEncounterActive = false
    }
    
    func saveEncounter(_ encounter: MedicalEncounter) {
        let context = persistentContainer.viewContext
        
        // Check if encounter already exists
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", encounter.id as CVarArg)
        
        do {
            let existingEncounters = try context.fetch(fetchRequest)
            let entity = existingEncounters.first ?? EncounterEntity(context: context)
            
            // Update entity
            entity.id = encounter.id
            entity.timestamp = encounter.timestamp
            entity.bed = encounter.bed
            entity.chiefComplaint = encounter.chiefComplaint
            entity.transcription = encounter.transcription
            entity.generatedNote = encounter.generatedNote
            entity.noteType = encounter.noteType.rawValue
            entity.status = encounter.status.rawValue
            entity.endTime = encounter.endTime
            
            try context.save()
            loadSavedEncounters()
            
        } catch {
            print("Error saving encounter: \(error)")
        }
    }
    
    func loadEncounter(_ encounter: MedicalEncounter) {
        // Save current if exists
        if let current = currentEncounter, !current.transcription.isEmpty {
            saveEncounter(current)
        }
        
        currentEncounter = encounter
        isEncounterActive = encounter.status == .active
    }
    
    func deleteEncounter(_ encounter: MedicalEncounter) {
        let context = persistentContainer.viewContext
        
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", encounter.id as CVarArg)
        
        do {
            let entities = try context.fetch(fetchRequest)
            for entity in entities {
                context.delete(entity)
            }
            try context.save()
            loadSavedEncounters()
        } catch {
            print("Error deleting encounter: \(error)")
        }
    }
    
    private func loadSavedEncounters() {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        fetchRequest.fetchLimit = 50 // Keep last 50 encounters
        
        do {
            let entities = try context.fetch(fetchRequest)
            savedEncounters = entities.compactMap { entity in
                guard let id = entity.id,
                      let timestamp = entity.timestamp,
                      let noteTypeString = entity.noteType,
                      let noteType = NoteType(rawValue: noteTypeString),
                      let statusString = entity.status,
                      let status = EncounterStatus(rawValue: statusString) else {
                    return nil
                }
                
                return MedicalEncounter(
                    id: id,
                    timestamp: timestamp,
                    bed: entity.bed,
                    chiefComplaint: entity.chiefComplaint,
                    transcription: entity.transcription ?? "",
                    generatedNote: entity.generatedNote ?? "",
                    noteType: noteType,
                    status: status,
                    endTime: entity.endTime
                )
            }
        } catch {
            print("Error loading encounters: \(error)")
        }
    }
    
    // MARK: - Encounter Updates
    func updateCurrentEncounterTranscription(_ text: String) {
        currentEncounter?.transcription = text
        
        // Also update in active encounters if it exists there
        if let encounter = currentEncounter,
           let index = activeEncounters.firstIndex(where: { $0.id == encounter.id }) {
            activeEncounters[index].transcription = text
            saveActiveEncounters()
        }
    }
    
    func updateCurrentEncounterNote(_ note: String, type: NoteType) {
        currentEncounter?.generatedNote = note
        currentEncounter?.noteType = type
        
        // Also update in active encounters if it exists there
        if let encounter = currentEncounter,
           let index = activeEncounters.firstIndex(where: { $0.id == encounter.id }) {
            activeEncounters[index].generatedNote = note
            activeEncounters[index].noteType = type
            saveActiveEncounters()
        }
    }
    
    // MARK: - Multi-Patient Workflow
    
    func createNewEncounter(bedLocation: String, chiefComplaint: String = "To be determined") -> MedicalEncounter {
        let encounter = MedicalEncounter(
            id: UUID(),
            timestamp: Date(),
            bed: bedLocation,
            chiefComplaint: chiefComplaint,
            transcription: "",
            generatedNote: "",
            noteType: .edNote,
            status: .active
        )
        
        // Remove any existing encounter for this bed
        activeEncounters.removeAll { $0.bed == bedLocation }
        
        // Add new encounter
        activeEncounters.insert(encounter, at: 0)
        
        // Limit active encounters
        if activeEncounters.count > maxActiveEncounters {
            let oldestEncounter = activeEncounters.removeLast()
            archiveEncounter(oldestEncounter)
        }
        
        currentEncounter = encounter
        selectedBed = bedLocation
        isEncounterActive = true
        saveActiveEncounters()
        
        return encounter
    }
    
    func completeEncounter(_ encounter: MedicalEncounter) {
        let completedEncounter = encounter
        completedEncounter.status = .completed
        completedEncounter.endTime = Date()
        
        // Move from active to completed
        activeEncounters.removeAll { $0.id == encounter.id }
        completedEncounters.insert(completedEncounter, at: 0)
        
        // Limit completed encounters
        if completedEncounters.count > maxCompletedEncounters {
            completedEncounters.removeLast()
        }
        
        // Clear current encounter if it was completed
        if currentEncounter?.id == encounter.id {
            currentEncounter = nil
            isEncounterActive = false
        }
        
        saveEncounterData()
    }
    
    func archiveEncounter(_ encounter: MedicalEncounter) {
        let archivedEncounter = encounter
        archivedEncounter.status = .completed // Using completed as archived
        archivedEncounter.endTime = Date()
        
        activeEncounters.removeAll { $0.id == encounter.id }
        completedEncounters.insert(archivedEncounter, at: 0)
        
        saveEncounterData()
    }
    
    // MARK: - Encounter Lookup
    
    func getActiveEncounter(for bedLocation: String) -> MedicalEncounter? {
        return activeEncounters.first { $0.bed == bedLocation }
    }
    
    func getEncountersByBed() -> [String: [MedicalEncounter]] {
        var encountersByBed: [String: [MedicalEncounter]] = [:]
        
        for encounter in activeEncounters {
            let bedName = encounter.bed ?? "Unknown"
            if encountersByBed[bedName] == nil {
                encountersByBed[bedName] = []
            }
            encountersByBed[bedName]?.append(encounter)
        }
        
        return encountersByBed
    }
    
    func getRecentEncounters(limit: Int = 10) -> [MedicalEncounter] {
        let allEncounters = activeEncounters + completedEncounters
        return Array(allEncounters.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
    
    func searchEncounters(query: String) -> [MedicalEncounter] {
        let allEncounters = activeEncounters + completedEncounters
        let searchQuery = query.lowercased()
        
        return allEncounters.filter { encounter in
            (encounter.bed?.lowercased().contains(searchQuery) ?? false) ||
            (encounter.chiefComplaint?.lowercased().contains(searchQuery) ?? false) ||
            encounter.transcription.lowercased().contains(searchQuery)
        }
    }
    
    // MARK: - Bed Management
    
    func switchToBed(_ bedLocation: String) {
        selectedBed = bedLocation
        
        // Load existing encounter for this bed or create new one
        if let existingEncounter = getActiveEncounter(for: bedLocation) {
            currentEncounter = existingEncounter
            isEncounterActive = existingEncounter.status == .active
        } else {
            currentEncounter = createNewEncounter(bedLocation: bedLocation)
        }
    }
    
    func getOccupiedBeds() -> [String] {
        return Array(Set(activeEncounters.compactMap { $0.bed }))
    }
    
    func getBedStatus(_ bedLocation: String) -> BedStatus {
        if let encounter = getActiveEncounter(for: bedLocation) {
            switch encounter.status {
            case .active:
                return .occupied
            case .completed:
                return .ready
            case .draft:
                return .cleanup
            }
        }
        return .available
    }
    
    // MARK: - Statistics
    
    func getTodaysEncounters() -> [MedicalEncounter] {
        let calendar = Calendar.current
        let today = Date()
        
        let allEncounters = activeEncounters + completedEncounters
        return allEncounters.filter { encounter in
            calendar.isDate(encounter.timestamp, inSameDayAs: today)
        }
    }
    
    func getEncounterStats() -> EncounterStats {
        let todaysEncounters = getTodaysEncounters()
        
        return EncounterStats(
            totalToday: todaysEncounters.count,
            activeCount: activeEncounters.count,
            completedToday: todaysEncounters.filter { $0.status == .completed }.count,
            averageDuration: calculateAverageDuration(todaysEncounters),
            occupiedBeds: getOccupiedBeds().count
        )
    }
    
    private func calculateAverageDuration(_ encounters: [MedicalEncounter]) -> TimeInterval {
        let completedEncounters = encounters.filter { $0.status == .completed }
        guard !completedEncounters.isEmpty else { return 0 }
        
        let totalDuration = completedEncounters.reduce(0) { total, encounter in
            let duration = (encounter.endTime ?? Date()).timeIntervalSince(encounter.timestamp)
            return total + duration
        }
        
        return totalDuration / Double(completedEncounters.count)
    }
    
    // MARK: - Enhanced Persistence
    
    private func saveActiveEncounters() {
        saveToDefaults(activeEncounters, key: activeEncountersKey)
    }
    
    private func saveCompletedEncounters() {
        saveToDefaults(completedEncounters, key: completedEncountersKey)
    }
    
    private func saveEncounterData() {
        saveActiveEncounters()
        saveCompletedEncounters()
    }
    
    private func saveToDefaults<T: Codable>(_ data: T, key: String) {
        do {
            let encoded = try JSONEncoder().encode(data)
            userDefaults.set(encoded, forKey: key)
        } catch {
            print("Failed to save \(key): \(error)")
        }
    }
    
    private func loadEncounters() {
        activeEncounters = loadFromDefaults([MedicalEncounter].self, key: activeEncountersKey) ?? []
        completedEncounters = loadFromDefaults([MedicalEncounter].self, key: completedEncountersKey) ?? []
        
        // Set current encounter to most recent active
        currentEncounter = activeEncounters.first
        selectedBed = currentEncounter?.bed ?? ""
        isEncounterActive = currentEncounter?.status == .active
    }
    
    private func loadFromDefaults<T: Codable>(_ type: T.Type, key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load \(key): \(error)")
            return nil
        }
    }
    
    // MARK: - Export/Import
    
    func exportEncounters() -> Data? {
        let exportData = EncounterExport(
            activeEncounters: activeEncounters,
            completedEncounters: completedEncounters,
            exportDate: Date()
        )
        
        return try? JSONEncoder().encode(exportData)
    }
    
    func importEncounters(from data: Data) throws {
        let importData = try JSONDecoder().decode(EncounterExport.self, from: data)
        
        // Merge imported encounters (avoiding duplicates)
        for encounter in importData.activeEncounters {
            if !activeEncounters.contains(where: { $0.id == encounter.id }) {
                activeEncounters.append(encounter)
            }
        }
        
        for encounter in importData.completedEncounters {
            if !completedEncounters.contains(where: { $0.id == encounter.id }) {
                completedEncounters.append(encounter)
            }
        }
        
        saveEncounterData()
    }
}

// MARK: - Medical Encounter Model
class MedicalEncounter: ObservableObject, Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    var bed: String?
    var chiefComplaint: String?
    @Published var transcription: String
    @Published var generatedNote: String
    @Published var noteType: NoteType
    @Published var status: EncounterStatus
    var endTime: Date?
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         bed: String? = nil,
         chiefComplaint: String? = nil,
         transcription: String = "",
         generatedNote: String = "",
         noteType: NoteType = .edNote,
         status: EncounterStatus = .active,
         endTime: Date? = nil) {
        
        self.id = id
        self.timestamp = timestamp
        self.bed = bed
        self.chiefComplaint = chiefComplaint
        self.transcription = transcription
        self.generatedNote = generatedNote
        self.noteType = noteType
        self.status = status
        self.endTime = endTime
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case id, timestamp, bed, chiefComplaint, transcription, generatedNote, noteType, status, endTime
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        bed = try container.decodeIfPresent(String.self, forKey: .bed)
        chiefComplaint = try container.decodeIfPresent(String.self, forKey: .chiefComplaint)
        transcription = try container.decode(String.self, forKey: .transcription)
        generatedNote = try container.decode(String.self, forKey: .generatedNote)
        noteType = try container.decode(NoteType.self, forKey: .noteType)
        status = try container.decode(EncounterStatus.self, forKey: .status)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encodeIfPresent(bed, forKey: .bed)
        try container.encodeIfPresent(chiefComplaint, forKey: .chiefComplaint)
        try container.encode(transcription, forKey: .transcription)
        try container.encode(generatedNote, forKey: .generatedNote)
        try container.encode(noteType, forKey: .noteType)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(endTime, forKey: .endTime)
    }
    
    var displayTitle: String {
        if let bed = bed, let complaint = chiefComplaint {
            return "\(bed) - \(complaint)"
        } else if let bed = bed {
            return bed
        } else if let complaint = chiefComplaint {
            return complaint
        } else {
            return "Encounter \(timestamp.formatted(date: .omitted, time: .shortened))"
        }
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

enum EncounterStatus: String, CaseIterable, Codable {
    case active = "active"
    case completed = "completed"
    case draft = "draft"
}