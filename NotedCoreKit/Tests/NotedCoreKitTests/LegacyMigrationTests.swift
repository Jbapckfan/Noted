import XCTest
import SwiftData
@testable import NotedCoreKit

final class LegacyMigrationTests: XCTestCase {

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        return f.string(from: date)
    }

    private func legacyJSON(_ rows: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: rows, options: [])
    }

    // MARK: - Pure mapping

    func testMigratorPreservesIDsAndMapsFields() throws {
        let id1 = UUID()
        let id2 = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let updated = Date(timeIntervalSince1970: 1_700_000_600)

        let data = legacyJSON([
            [
                "id": id1.uuidString,
                "chiefComplaint": "chest pain",
                "transcription": "doctor: what brings you in",
                "notes": "HPI: 57M with chest pain",
                "status": "completed",
                "startTime": iso(start),
                "lastUpdated": iso(updated),
            ],
            [
                "id": id2.uuidString,
                "chiefComplaint": "ankle sprain",
                "transcription": "",
                "notes": "",
                "status": "inProgress",
                "startTime": iso(start),
            ],
        ])

        let encounters = try LegacyMigration.encounters(fromLegacyJSON: data)
        XCTAssertEqual(encounters.count, 2)

        let byID = Dictionary(uniqueKeysWithValues: encounters.map { ($0.id, $0) })

        let e1 = try XCTUnwrap(byID[id1], "original id must be preserved")
        XCTAssertEqual(e1.chiefComplaint, "chest pain")
        XCTAssertEqual(e1.transcript, "doctor: what brings you in")
        XCTAssertEqual(e1.noteText, "HPI: 57M with chest pain")
        XCTAssertEqual(e1.phase, .signed, "an encounter with a note migrates as terminal (won't re-queue)")
        XCTAssertNotNil(e1.signedAt)

        let e2 = try XCTUnwrap(byID[id2])
        XCTAssertEqual(e2.chiefComplaint, "ankle sprain")
        XCTAssertNil(e2.transcript, "empty transcription maps to nil")
        XCTAssertNil(e2.noteText)
        XCTAssertEqual(e2.phase, .captured, "no transcript, no note → captured")
    }

    func testMigratorGeneratesIDWhenLegacyBlobHasNone() throws {
        let data = legacyJSON([[
            "chiefComplaint": "headache",
            "startTime": iso(Date(timeIntervalSince1970: 1_700_000_000)),
        ]])
        let encounters = try LegacyMigration.encounters(fromLegacyJSON: data)
        XCTAssertEqual(encounters.count, 1)
        XCTAssertEqual(encounters.first?.chiefComplaint, "headache")
        // a fresh id was assigned rather than crashing on the missing field
    }

    // MARK: - One-time guard

    func testRunIfNeededIsIdempotent() throws {
        let suite = "notedcorekit-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let id = UUID()
        defaults.set(legacyJSON([[
            "id": id.uuidString,
            "chiefComplaint": "x",
            "notes": "a note",
            "startTime": iso(Date()),
        ]]), forKey: LegacyMigration.legacyDefaultsKey)

        let container = try EncounterStore.inMemoryContainer()
        let ctx = ModelContext(container)

        let first = try LegacyMigration.runIfNeeded(context: ctx, defaults: defaults)
        XCTAssertEqual(first.migrated, 1)
        XCTAssertFalse(first.alreadyDone)

        let second = try LegacyMigration.runIfNeeded(context: ctx, defaults: defaults)
        XCTAssertTrue(second.alreadyDone, "second run is a no-op")
        XCTAssertEqual(second.migrated, 0)

        let all = try ctx.fetch(FetchDescriptor<Encounter>())
        XCTAssertEqual(all.count, 1, "migration must not duplicate rows on re-run")
    }

    func testRunIfNeededWithNoLegacyDataMarksDone() throws {
        let suite = "notedcorekit-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let container = try EncounterStore.inMemoryContainer()
        let ctx = ModelContext(container)

        let outcome = try LegacyMigration.runIfNeeded(context: ctx, defaults: defaults)
        XCTAssertEqual(outcome.migrated, 0)
        XCTAssertTrue(defaults.bool(forKey: LegacyMigration.migrationDoneKey),
                      "with nothing to migrate we still set the flag so we don't re-scan every launch")
    }
}
