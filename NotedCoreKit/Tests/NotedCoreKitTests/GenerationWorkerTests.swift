import XCTest
import SwiftData
@testable import NotedCoreKit

/// Tracks how many engine calls are in flight at once — the serial guarantee is `maxConcurrent == 1`.
private actor CallTracker {
    private(set) var current = 0
    private(set) var maxConcurrent = 0
    private(set) var total = 0
    func enter() { current += 1; maxConcurrent = max(maxConcurrent, current); total += 1 }
    func exit() { current -= 1 }
}

/// Consumes a budget of injected failures per job kind (fail N times, then succeed).
private actor FailBudget {
    private var remaining: [GenerationJobKind: Int]
    init(_ r: [GenerationJobKind: Int]) { remaining = r }
    func consume(_ k: GenerationJobKind) -> Bool {
        if let n = remaining[k], n > 0 { remaining[k] = n - 1; return true }
        return false
    }
}

private struct InjectedError: Error {}

/// A test engine that tracks concurrency and can inject transient/permanent failures,
/// delegating successful outputs to the deterministic `MockNoteEngine`.
private struct InstrumentedEngine: NoteEngine {
    let tracker: CallTracker
    let delay: Duration
    let failBudget: FailBudget
    let alwaysFail: Bool

    func run(_ input: GenerationInput) async throws -> GenerationOutput {
        await tracker.enter()
        if delay != .zero { try? await Task.sleep(for: delay) }
        let budgetedFailure = await failBudget.consume(input.kind)
        let shouldFail = alwaysFail || budgetedFailure
        if shouldFail {
            await tracker.exit()
            throw InjectedError()
        }
        let out = try await MockNoteEngine().run(input)
        await tracker.exit()
        return out
    }
}

final class GenerationWorkerTests: XCTestCase {

    private func tempStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("notedcorekit-worker", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("store.sqlite")
    }
    private func cleanup(_ url: URL) { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

    private func firstEncounter(_ container: ModelContainer) throws -> Encounter? {
        try ModelContext(container).fetch(FetchDescriptor<Encounter>()).first
    }

    // MARK: - The headline PR3 test

    func testFiveEncountersDrainSeriallyToNoteDrafted() async throws {
        let url = tempStoreURL(); defer { cleanup(url) }
        let container = try EncounterStore.makeContainer(at: url)
        let ctx = ModelContext(container)
        for i in 0..<5 {
            let e = Encounter(chiefComplaint: "cc-\(i)", phase: .captured)
            e.audioFileRelPath = "\(e.id.uuidString).wav"
            ctx.insert(e)
            try GenerationQueue.startNotePipeline(for: e, in: ctx)
        }

        let tracker = CallTracker()
        let engine = InstrumentedEngine(tracker: tracker, delay: .milliseconds(2),
                                        failBudget: FailBudget([:]), alwaysFail: false)
        let worker = GenerationWorker(container: container, engine: engine)

        let processed = await worker.drain()

        XCTAssertEqual(processed, 15, "5 encounters × 3 stages (transcribe→extract→note)")
        let maxC = await tracker.maxConcurrent
        XCTAssertEqual(maxC, 1, "two generations must NEVER overlap")

        let readCtx = ModelContext(container)
        let all = try readCtx.fetch(FetchDescriptor<Encounter>())
        XCTAssertEqual(all.count, 5)
        for e in all {
            XCTAssertEqual(e.phase, .noteDrafted)
            XCTAssertNotNil(e.transcript)
            XCTAssertNotNil(e.extractionJSON)
            XCTAssertNotNil(e.noteText)
        }
        let jobs = try readCtx.fetch(FetchDescriptor<GenerationJob>())
        XCTAssertEqual(jobs.count, 15)
        XCTAssertTrue(jobs.allSatisfy { $0.state == .done })
    }

    // MARK: - Crash mid-job → resume

    func testKillMidJobResumesAndCompletes() async throws {
        let url = tempStoreURL(); defer { cleanup(url) }
        let container = try EncounterStore.makeContainer(at: url)
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .transcribing)
        e.audioFileRelPath = "\(e.id.uuidString).wav"
        ctx.insert(e)
        // A crash left this job `running` 10 minutes ago.
        let job = GenerationJob(kind: .transcribe, encounter: e)
        job.state = .running
        job.startedAt = Date(timeIntervalSinceNow: -600)
        ctx.insert(job)
        try ctx.save()

        let worker = GenerationWorker(container: container, engine: MockNoteEngine())
        let processed = await worker.recoverAndDrain(staleAfter: 300)

        XCTAssertGreaterThanOrEqual(processed, 3, "recovered transcribe, then extract + note")
        let reloaded = try firstEncounter(container)
        XCTAssertEqual(reloaded?.phase, .noteDrafted)
        XCTAssertNotNil(reloaded?.noteText)
    }

    // MARK: - Retry policy

    func testJobRetriesTransientFailureThenSucceeds() async throws {
        let url = tempStoreURL(); defer { cleanup(url) }
        let container = try EncounterStore.makeContainer(at: url)
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .captured)
        ctx.insert(e)
        try GenerationQueue.startNotePipeline(for: e, in: ctx)

        let engine = InstrumentedEngine(tracker: CallTracker(), delay: .zero,
                                        failBudget: FailBudget([.transcribe: 2]), alwaysFail: false)
        let worker = GenerationWorker(container: container, engine: engine, maxAttempts: 5)
        _ = await worker.drain()

        let readCtx = ModelContext(container)
        let reloaded = try readCtx.fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.phase, .noteDrafted, "completes after 2 transient failures")
        let transcribeJob = try readCtx.fetch(FetchDescriptor<GenerationJob>()).first { $0.kind == .transcribe }
        XCTAssertEqual(transcribeJob?.state, .done)
        XCTAssertEqual(transcribeJob?.attempts, 2)
    }

    func testJobFailsPermanentlyAfterMaxAttempts() async throws {
        let url = tempStoreURL(); defer { cleanup(url) }
        let container = try EncounterStore.makeContainer(at: url)
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .captured)
        ctx.insert(e)
        try GenerationQueue.startNotePipeline(for: e, in: ctx)

        let engine = InstrumentedEngine(tracker: CallTracker(), delay: .zero,
                                        failBudget: FailBudget([:]), alwaysFail: true)
        let worker = GenerationWorker(container: container, engine: engine, maxAttempts: 3)
        _ = await worker.drain()

        let readCtx = ModelContext(container)
        let reloaded = try readCtx.fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.phase, .failed, "encounter surfaced as failed, never silently dropped")
        let job = try readCtx.fetch(FetchDescriptor<GenerationJob>()).first
        XCTAssertEqual(job?.state, .failed)
        XCTAssertEqual(job?.attempts, 3)
        XCTAssertNotNil(reloaded?.lastError)
    }

    func testDrainIsReentrantSafe() async throws {
        let url = tempStoreURL(); defer { cleanup(url) }
        let container = try EncounterStore.makeContainer(at: url)
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .captured)
        ctx.insert(e)
        try GenerationQueue.startNotePipeline(for: e, in: ctx)

        let tracker = CallTracker()
        let engine = InstrumentedEngine(tracker: tracker, delay: .milliseconds(3),
                                        failBudget: FailBudget([:]), alwaysFail: false)
        let worker = GenerationWorker(container: container, engine: engine)

        // Fire two drains concurrently — the second must not double-process jobs.
        async let a = worker.drain()
        async let b = worker.drain()
        _ = await (a, b)

        let maxC = await tracker.maxConcurrent
        XCTAssertEqual(maxC, 1)
        let jobs = try ModelContext(container).fetch(FetchDescriptor<GenerationJob>())
        XCTAssertEqual(jobs.count, 3, "each stage enqueued exactly once — no duplication")
        XCTAssertTrue(jobs.allSatisfy { $0.state == .done })
    }
}
