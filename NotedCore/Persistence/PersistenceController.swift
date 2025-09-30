import CoreData
import Foundation

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init() {
        container = NSPersistentContainer(name: "NotedCore")
        
        // Configure for production
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            
            // Enable encryption
            // File protection disabled for macOS
        }
        
        container.loadPersistentStores { description, error in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
                // In production, handle this gracefully
                self.handlePersistenceError(error)
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Encounter Management
    
    func saveEncounter(_ encounter: MedicalEncounter) {
        let context = container.viewContext
        
        // Check if encounter exists
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", encounter.id as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            let entity = results.first ?? EncounterEntity(context: context)
            
            // Update entity
            entity.id = encounter.id
            // entity.roomNumber = encounter.room.number
            // entity.roomName = encounter.room.displayName
            entity.chiefComplaint = encounter.chiefComplaint
            entity.status = encounter.status.rawValue
//             entity.startTime = encounter.startTime
//             entity.endTime = encounter.endTime
//             entity.transcription = encounter.transcription
//             entity.generatedNote = encounter.generatedNote
//             entity.lastUpdated = Date()
//             
//             // Save structured data as JSON
//             if let notesData = try? JSONEncoder().encode(encounter.notes) {
//                 entity.notesData = notesData
//             }
            
            try context.save()
        } catch {
            print("Failed to save encounter: \(error)")
        }
    }
    
    func fetchEncounters(limit: Int = 50) -> [MedicalEncounter] {
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \EncounterEntity.id, ascending: false)]
        fetchRequest.fetchLimit = limit
        
        do {
            let entities = try container.viewContext.fetch(fetchRequest)
            return entities.compactMap { convertToEncounter($0) }
        } catch {
            print("Failed to fetch encounters: \(error)")
            return []
        }
    }
    
    func fetchActiveEncounters() -> [MedicalEncounter] {
        let fetchRequest: NSFetchRequest<EncounterEntity> = EncounterEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status IN %@", ["inProgress", "paused"])
        
        do {
            let entities = try container.viewContext.fetch(fetchRequest)
            return entities.compactMap { convertToEncounter($0) }
        } catch {
            print("Failed to fetch active encounters: \(error)")
            return []
        }
    }
    
    private func convertToEncounter(_ entity: EncounterEntity) -> MedicalEncounter? {
        guard let id = entity.id,
              let roomNumber = entity.roomNumber,
              let roomName = entity.roomName,
              let chiefComplaint = entity.chiefComplaint,
              let statusString = entity.status,
              let status = EncounterManager.EncounterStatus(rawValue: statusString),
              let startTime = entity.startTime else {
            return nil
        }
        
        let room = Room(
            number: roomNumber,
            type: .examRoom,
            floor: 1
        )
        
        var encounter = MedicalEncounter(
            room: room,
            chiefComplaint: chiefComplaint,
            status: status,
            startTime: startTime
        )
        
        encounter.endTime = entity.endTime
        encounter.transcription = entity.transcription ?? ""
        if let notesData = entity.notesData {
            encounter.notes = (try? JSONDecoder().decode(String.self, from: notesData)) ?? ""
        }
        
        return encounter
    }
    
    // MARK: - Transcript Management
    
    func saveTranscript(_ transcript: String, for encounterId: UUID) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<TranscriptEntity> = TranscriptEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "encounterId == %@", encounterId as CVarArg)
        
        do {
            let results = try context.fetch(fetchRequest)
            let entity = results.first ?? TranscriptEntity(context: context)
            
            entity.encounterId = encounterId
            entity.content = transcript
            entity.timestamp = Date()
            entity.wordCount = Int32(transcript.split(separator: " ").count)
            
            try context.save()
        } catch {
            print("Failed to save transcript: \(error)")
        }
    }
    
    // MARK: - Note Management
    
    func saveGeneratedNote(_ note: String, type: String, for encounterId: UUID) {
        let context = container.viewContext
        let entity = NoteEntity(context: context)
        
        entity.id = UUID()
        entity.encounterId = encounterId
        entity.content = note
        entity.noteType = type
        entity.generatedAt = Date()
        entity.wordCount = Int32(note.split(separator: " ").count)
        
        do {
            try context.save()
        } catch {
            print("Failed to save generated note: \(error)")
        }
    }
    
    func fetchNotes(for encounterId: UUID) -> [NoteEntity] {
        let fetchRequest: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "encounterId == %@", encounterId as CVarArg)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "generatedAt", ascending: false)]
        
        do {
            return try container.viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch notes: \(error)")
            return []
        }
    }
    
    // MARK: - Cleanup
    
    func deleteOldEncounters(olderThan days: Int = 90) {
        let context = container.viewContext
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = EncounterEntity.fetchRequest()
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        fetchRequest.predicate = NSPredicate(format: "startTime < %@", cutoffDate as CVarArg)
        
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
            if let objectIDs = result?.result as? [NSManagedObjectID] {
                let changes = [NSDeletedObjectsKey: objectIDs]
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
            }
        } catch {
            print("Failed to delete old encounters: \(error)")
        }
    }
    
    // MARK: - Error Handling
    
    private func handlePersistenceError(_ error: Error) {
        // In production, this would send telemetry and attempt recovery
        print("Persistence error: \(error)")
        
        // Attempt to recover by removing corrupted store
        if let storeURL = container.persistentStoreDescriptions.first?.url {
            do {
                try FileManager.default.removeItem(at: storeURL)
                // Reload stores
                container.loadPersistentStores { _, error in
                    if let error = error {
                        print("Failed to recover from persistence error: \(error)")
                    }
                }
            } catch {
                print("Failed to remove corrupted store: \(error)")
            }
        }
    }
}