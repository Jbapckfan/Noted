import XCTest
import SwiftData
@testable import NotedCoreKit

final class EncounterStoreTests: XCTestCase {

    /// Each test gets a fresh temp directory; the store file lives inside it.
    private func tempStoreURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notedcorekit-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return dir.appendingPathComponent("encounters.store")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    // MARK: - The headline PR1 guarantee

    /// Create 30 encounters, drop the container (simulating an app kill), reopen the
    /// store from disk — all 30 must return with their ORIGINAL ids (none regenerated).
    func testThirtyEncountersReloadWithStableIDs() throws {
        let url = tempStoreURL()
        defer { cleanup(url) }

        var ids: [UUID] = []
        var complaints: [UUID: String] = [:]
        do {
            let container = try EncounterStore.makeContainer(at: url)
            let ctx = ModelContext(container)
            for i in 0..<30 {
                let e = Encounter(chiefComplaint: "complaint-\(i)")
                ctx.insert(e)
                ids.append(e.id)
                complaints[e.id] = e.chiefComplaint
            }
            try ctx.save()
            // container + ctx deallocate here → the running app "dies"
        }

        let container2 = try EncounterStore.makeContainer(at: url)
        let ctx2 = ModelContext(container2)
        let reloaded = try ctx2.fetch(FetchDescriptor<Encounter>())

        XCTAssertEqual(reloaded.count, 30, "all 30 encounters must survive relaunch")
        XCTAssertEqual(Set(reloaded.map(\.id)), Set(ids), "ids must be stable across relaunch — none regenerated")
        for e in reloaded {
            XCTAssertEqual(e.chiefComplaint, complaints[e.id], "fields must round-trip with their id")
        }
    }

    func testPhasePersistsAcrossReopen() throws {
        let url = tempStoreURL()
        defer { cleanup(url) }

        var savedID = UUID()
        do {
            let container = try EncounterStore.makeContainer(at: url)
            let ctx = ModelContext(container)
            let e = Encounter(chiefComplaint: "x")
            e.transition(to: .noteDrafted)
            ctx.insert(e)
            savedID = e.id
            try ctx.save()
        }

        let container2 = try EncounterStore.makeContainer(at: url)
        let ctx2 = ModelContext(container2)
        let fetched = try ctx2.fetch(FetchDescriptor<Encounter>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, savedID)
        XCTAssertEqual(fetched.first?.phase, .noteDrafted, "phase must persist across relaunch")
    }

    // MARK: - Non-destructive recovery (the anti-delete-bomb)

    /// A corrupt store must be MOVED ASIDE (preserved), never deleted, and a fresh store
    /// opened in its place.
    func testCorruptStoreIsMovedAsideNotDeleted() throws {
        let url = tempStoreURL()
        defer { cleanup(url) }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        // Not a valid SQLite file → ModelContainer load fails.
        try Data("this is not a valid sqlite database".utf8).write(to: url)

        let result = try EncounterStore.open(at: url)

        XCTAssertTrue(result.recoveredFromCorruption, "load failure must trigger recovery")
        let moved = try XCTUnwrap(result.corruptStoreURL, "corrupt store must be moved aside")
        XCTAssertTrue(FileManager.default.fileExists(atPath: moved.path),
                      "the corrupt bytes must be PRESERVED, not deleted")
        XCTAssertTrue(moved.lastPathComponent.contains(".corrupt-"))

        // The fresh store is usable.
        let ctx = ModelContext(result.container)
        ctx.insert(Encounter(chiefComplaint: "after recovery"))
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<Encounter>()).count, 1)
    }

    // MARK: - Launch-time crash recovery (watchdog)

    func testStaleRunningJobResetToPending() throws {
        let container = try EncounterStore.inMemoryContainer()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "j")
        ctx.insert(e)
        let job = GenerationJob(kind: .note, encounter: e)
        job.state = .running
        job.startedAt = Date(timeIntervalSinceNow: -600) // interrupted 10 min ago
        ctx.insert(job)
        try ctx.save()

        let acted = try EncounterStore.recoverInterruptedJobs(in: ctx, staleAfter: 300)

        XCTAssertEqual(acted, 1)
        XCTAssertEqual(job.state, .pending, "stale running job resets to pending for re-run")
        XCTAssertEqual(job.attempts, 1)
        XCTAssertNil(job.startedAt)
    }

    func testStaleJobExhaustsToFailedNotRetryLoop() throws {
        let container = try EncounterStore.inMemoryContainer()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "j")
        ctx.insert(e)
        let job = GenerationJob(kind: .note, encounter: e)
        job.state = .running
        job.attempts = 2 // already retried twice
        job.startedAt = Date(timeIntervalSinceNow: -600)
        ctx.insert(job)
        try ctx.save()

        _ = try EncounterStore.recoverInterruptedJobs(in: ctx, staleAfter: 300, maxAttempts: 3)

        XCTAssertEqual(job.state, .failed, "3rd interruption is terminal, never an infinite retry")
        XCTAssertEqual(job.attempts, 3)
        XCTAssertEqual(e.phase, .failed, "the encounter is surfaced as failed, never silently dropped")
        XCTAssertNotNil(job.lastError)
    }

    func testFreshRunningJobIsNotTouched() throws {
        let container = try EncounterStore.inMemoryContainer()
        let ctx = ModelContext(container)
        let job = GenerationJob(kind: .transcribe)
        job.state = .running
        job.startedAt = Date(timeIntervalSinceNow: -5) // still actively running
        ctx.insert(job)
        try ctx.save()

        let acted = try EncounterStore.recoverInterruptedJobs(in: ctx, staleAfter: 300)

        XCTAssertEqual(acted, 0, "a job that is genuinely still running must not be disturbed")
        XCTAssertEqual(job.state, .running)
    }
}
