import Foundation
import SwiftData

/// One-time migration of the legacy `saved_encounters` UserDefaults JSON (an array of the
/// old `MedicalEncounter` Codable struct) into durable SwiftData `Encounter` rows.
///
/// Preserves the original `id` so nothing loses identity. Runs at most once (guarded by a
/// done-flag). Historical encounters are migrated as terminal/read-only phases so they
/// never re-enter the generation queue. The legacy blob is left in place (non-destructive);
/// the app may clear it after a successful, verified migration.
public enum LegacyMigration {

    public static let legacyDefaultsKey = "saved_encounters"
    public static let migrationDoneKey = "notedcorekit.legacyMigration.v1.done"

    public struct Outcome: Equatable {
        public let migrated: Int
        public let alreadyDone: Bool
    }

    /// Run once. If the done-flag is set, does nothing. Otherwise decodes the legacy blob,
    /// inserts rows, saves, and sets the done-flag. Safe to call on every launch.
    @discardableResult
    public static func runIfNeeded(
        context: ModelContext,
        defaults: UserDefaults = .standard
    ) throws -> Outcome {
        if defaults.bool(forKey: migrationDoneKey) {
            return Outcome(migrated: 0, alreadyDone: true)
        }
        guard let data = defaults.data(forKey: legacyDefaultsKey), !data.isEmpty else {
            defaults.set(true, forKey: migrationDoneKey) // nothing to migrate; don't re-scan
            return Outcome(migrated: 0, alreadyDone: false)
        }

        let encounters = try encounters(fromLegacyJSON: data)
        for encounter in encounters {
            context.insert(encounter)
        }
        try context.save()
        defaults.set(true, forKey: migrationDoneKey)
        return Outcome(migrated: encounters.count, alreadyDone: false)
    }

    /// Pure mapping: legacy JSON data -> `Encounter` rows. No UserDefaults, no context —
    /// this is the unit-testable core. Unparseable rows are skipped, not fatal.
    public static func encounters(fromLegacyJSON data: Data) throws -> [Encounter] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([LegacyEncounterDTO].self, from: data)
        return dtos.map { $0.toEncounter() }
    }
}

/// Minimal mirror of the legacy `MedicalEncounter` JSON. Only the fields worth carrying
/// forward are decoded; complex nested types (room, structuredNote, actionItems) are ignored.
/// Every field is tolerant of absence so old/partial blobs still migrate.
private struct LegacyEncounterDTO: Decodable {
    let id: UUID?
    let chiefComplaint: String?
    let transcription: String?
    let notes: String?
    let startTime: Date?
    let endTime: Date?
    let lastUpdated: Date?

    private enum CodingKeys: String, CodingKey {
        case id, chiefComplaint, transcription, notes, startTime, endTime, lastUpdated
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id)
        chiefComplaint = try c.decodeIfPresent(String.self, forKey: .chiefComplaint)
        transcription = try c.decodeIfPresent(String.self, forKey: .transcription)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        startTime = try c.decodeIfPresent(Date.self, forKey: .startTime)
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        lastUpdated = try c.decodeIfPresent(Date.self, forKey: .lastUpdated)
    }

    func toEncounter() -> Encounter {
        let created = startTime ?? lastUpdated ?? Date()
        let e = Encounter(
            id: id ?? UUID(),
            chiefComplaint: chiefComplaint ?? "",
            phase: .captured,
            createdAt: created
        )
        let transcript = (transcription?.isEmpty == false) ? transcription : nil
        let note = (notes?.isEmpty == false) ? notes : nil
        e.transcript = transcript
        e.noteText = note

        // Derive a terminal-ish phase from content so migrated history doesn't re-queue.
        if note != nil {
            e.phaseRaw = EncounterPhase.signed.rawValue
            e.signedAt = lastUpdated ?? endTime ?? created
        } else if transcript != nil {
            e.phaseRaw = EncounterPhase.transcribed.rawValue
        } else {
            e.phaseRaw = EncounterPhase.captured.rawValue
        }
        e.updatedAt = lastUpdated ?? created
        return e
    }
}
