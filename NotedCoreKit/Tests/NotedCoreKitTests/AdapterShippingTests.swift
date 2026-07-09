import XCTest
@testable import NotedCoreKit

final class AdapterGateTests: XCTestCase {

    private let good = AdapterEvalMetrics(hallucinationRate: 0.010, omissionRate: 0.030, structureValidity: 1.0)

    func testPassingMetricsClearTheGate() {
        XCTAssertTrue(AdapterGate.passes(good))
        XCTAssertTrue(AdapterGate.failures(good).isEmpty)
    }

    func testHallucinationOverThresholdFails() {
        let m = AdapterEvalMetrics(hallucinationRate: 0.02, omissionRate: 0.01, structureValidity: 1.0)
        XCTAssertFalse(AdapterGate.passes(m))
        XCTAssertTrue(AdapterGate.failures(m).contains { $0.contains("hallucination") })
    }

    func testOmissionOverThresholdFails() {
        let m = AdapterEvalMetrics(hallucinationRate: 0.001, omissionRate: 0.05, structureValidity: 1.0)
        XCTAssertTrue(AdapterGate.failures(m).contains { $0.contains("omission") })
    }

    func testLowStructureValidityFails() {
        let m = AdapterEvalMetrics(hallucinationRate: 0.001, omissionRate: 0.001, structureValidity: 0.90)
        XCTAssertTrue(AdapterGate.failures(m).contains { $0.contains("structure") })
    }

    func testManifestGatePassedReflectsMetrics() {
        let pass = AdapterManifest(task: "extraction", version: "1", fileName: "e.safetensors", baseModel: "llama-3.2-3b-4bit", metrics: good)
        XCTAssertTrue(pass.gatePassed)
        let failMetrics = AdapterEvalMetrics(hallucinationRate: 0.5, omissionRate: 0.5, structureValidity: 0.5)
        let fail = AdapterManifest(task: "note", version: "1", fileName: "n.safetensors", baseModel: "llama-3.2-3b-4bit", metrics: failMetrics)
        XCTAssertFalse(fail.gatePassed)
    }

    func testBundleShippableOnlyWhenAllPass() {
        let a = AdapterManifest(task: "extraction", version: "1", fileName: "e", baseModel: "b", metrics: good)
        let b = AdapterManifest(task: "note", version: "1", fileName: "n", baseModel: "b", metrics: good)
        XCTAssertTrue(AdapterManifest.shippable([a, b]))
        let bad = AdapterManifest(task: "discharge", version: "1", fileName: "d", baseModel: "b",
                                  metrics: AdapterEvalMetrics(hallucinationRate: 0.9, omissionRate: 0.0, structureValidity: 1.0))
        XCTAssertFalse(AdapterManifest.shippable([a, b, bad]))
        XCTAssertFalse(AdapterManifest.shippable([]))
    }
}

final class TrainingFlywheelTests: XCTestCase {

    private func signedEncounter() -> Encounter {
        let e = Encounter(chiefComplaint: "chest pain", phase: .signed)
        e.transcript = "Doctor: chest pain for two hours."
        e.extractionJSON = #"{"chief_complaint":"chest pain"}"#
        e.noteText = "HPI: chest pain x2h."
        return e
    }

    func testSignedEncounterYieldsExtractionAndNotePairs() {
        let pairs = TrainingFlywheel.pairs(from: signedEncounter())
        XCTAssertEqual(pairs.map(\.task), ["extraction", "note"])
        XCTAssertEqual(pairs.first?.input, "Doctor: chest pain for two hours.")
    }

    func testDischargeAddsThirdPair() {
        let e = signedEncounter()
        e.resultsTrayJSON = #"{"labs":[]}"#
        e.dispositionTranscript = "Home with follow-up."
        e.dischargeJSON = #"{"final_diagnosis":"chest pain"}"#
        let pairs = TrainingFlywheel.pairs(from: e)
        XCTAssertEqual(pairs.map(\.task), ["extraction", "note", "discharge"])
    }

    func testUnsignedEncounterExportsNothing() {
        let e = signedEncounter()
        e.transition(to: .noteDrafted) // not signed
        XCTAssertTrue(TrainingFlywheel.pairs(from: e).isEmpty)
    }

    func testJSONLLinesEachParse() throws {
        let jsonl = TrainingFlywheel.jsonl(TrainingFlywheel.pairs(from: signedEncounter()))
        let lines = jsonl.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        for line in lines {
            let pair = try JSONDecoder().decode(TrainingPair.self, from: Data(line.utf8))
            XCTAssertFalse(pair.task.isEmpty)
        }
    }
}
