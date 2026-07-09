import XCTest
import SwiftData
@testable import NotedCoreKit

final class EngineGovernorTests: XCTestCase {

    private let ok = PowerState(lowPowerMode: false, batteryFraction: 1.0)

    func testNominalDrainsNormally() {
        XCTAssertEqual(EngineGovernor.decision(thermal: .nominal, memory: .normal, power: ok), .drainNormally)
        XCTAssertEqual(EngineGovernor.decision(thermal: .fair, memory: .normal, power: ok), .drainNormally)
    }

    func testSeriousThermalInsertsCooldown() {
        XCTAssertEqual(
            EngineGovernor.decision(thermal: .serious, memory: .normal, power: ok),
            .coolDownBetweenJobs(seconds: 75)
        )
    }

    func testCriticalThermalPauses() {
        guard case .pauseQueue = EngineGovernor.decision(thermal: .critical, memory: .normal, power: ok) else {
            return XCTFail("critical thermal must pause")
        }
    }

    func testCriticalMemoryPausesEvenWhenCool() {
        guard case .pauseQueue = EngineGovernor.decision(thermal: .nominal, memory: .critical, power: ok) else {
            return XCTFail("critical memory must pause")
        }
    }

    func testLowPowerLowBatteryPauses() {
        let low = PowerState(lowPowerMode: true, batteryFraction: 0.15)
        guard case .pauseQueue = EngineGovernor.decision(thermal: .nominal, memory: .normal, power: low) else {
            return XCTFail("low power + low battery must pause opportunistic draining")
        }
    }

    func testLowPowerHealthyBatteryStillDrains() {
        let lp = PowerState(lowPowerMode: true, batteryFraction: 0.80)
        XCTAssertEqual(EngineGovernor.decision(thermal: .nominal, memory: .normal, power: lp), .drainNormally)
    }

    func testModelActionByMemoryPressure() {
        XCTAssertEqual(EngineGovernor.modelAction(memory: .normal), .keepLoaded)
        XCTAssertEqual(EngineGovernor.modelAction(memory: .warning), .unloadLLM)
        XCTAssertEqual(EngineGovernor.modelAction(memory: .critical), .unloadAll)
    }

    func testGenerationLimitsCapUnderThermalStress() {
        XCTAssertEqual(EngineGovernor.generationLimits(thermal: .nominal).maxTokens, nil)
        let serious = EngineGovernor.generationLimits(thermal: .serious)
        XCTAssertEqual(serious.maxTokens, 512)
        XCTAssertTrue(serious.greedy)
    }

    // MARK: - Worker integration

    private struct PausingGovernor: GenerationGovernor {
        func decisionNow() -> GovernorDecision { .pauseQueue(reason: "test") }
    }
    private struct CoolDownGovernor: GenerationGovernor {
        func decisionNow() -> GovernorDecision { .coolDownBetweenJobs(seconds: 0.001) }
    }

    private func store() throws -> ModelContainer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true).appendingPathComponent("s.sqlite")
        return try EncounterStore.makeContainer(at: url)
    }

    func testWorkerPausesWhenGovernorSaysPause() async throws {
        let container = try store()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .captured)
        e.audioFileRelPath = "a.wav"
        ctx.insert(e)
        try GenerationQueue.startNotePipeline(for: e, in: ctx)

        let worker = GenerationWorker(container: container, engine: MockNoteEngine(), governor: PausingGovernor())
        let processed = await worker.drain()

        XCTAssertEqual(processed, 0, "governor pause halts draining")
        let jobs = try ModelContext(container).fetch(FetchDescriptor<GenerationJob>())
        XCTAssertTrue(jobs.allSatisfy { $0.state == .pending }, "jobs remain pending for a later drain")
    }

    func testWorkerStillDrainsWithCooldown() async throws {
        let container = try store()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "x", phase: .captured)
        e.audioFileRelPath = "a.wav"
        ctx.insert(e)
        try GenerationQueue.startNotePipeline(for: e, in: ctx)

        let worker = GenerationWorker(container: container, engine: MockNoteEngine(), governor: CoolDownGovernor())
        let processed = await worker.drain()

        XCTAssertEqual(processed, 3, "cool-down slows but does not stop the pipeline")
        let reloaded = try ModelContext(container).fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.phase, .noteDrafted)
    }
}
