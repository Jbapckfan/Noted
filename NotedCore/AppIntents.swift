import Foundation
#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct StartEncounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Encounter"
    static var description = IntentDescription("Start recording an encounter with optional room and chief complaint.")
    
    @Parameter(title: "Room") var room: String?
    @Parameter(title: "Chief Complaint") var chiefComplaint: String?
    
    func perform() async throws -> some IntentResult {
        await EncounterController.shared.start(room: room, complaint: chiefComplaint)
        return .result()
    }
}

@available(iOS 16.0, *)
struct StopEncounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Encounter"
    static var description = IntentDescription("Stop recording and finalize the note.")
    
    func perform() async throws -> some IntentResult {
        await EncounterController.shared.stop()
        return .result()
    }
}

@available(iOS 16.0, *)
struct BookmarkEncounterIntent: AppIntent {
    static var title: LocalizedStringResource = "Bookmark Encounter"
    static var description = IntentDescription("Insert a bookmark into the timeline.")
    
    @Parameter(title: "Label") var label: String
    
    func perform() async throws -> some IntentResult {
        await EncounterController.shared.bookmark(label)
        return .result()
    }
}
#endif
