import XCTest
@testable import NotedCoreKit

final class AlvaradoScoreTests: XCTestCase {

    private let alvarado = AlvaradoScore()

    /// Build a full answer set from the eight present/absent findings (index 1 = "Yes").
    private func answers(migration: Bool = false, anorexia: Bool = false, nausea: Bool = false,
                         tenderness: Bool = false, rebound: Bool = false, temperature: Bool = false,
                         leukocytosis: Bool = false, leftShift: Bool = false) -> Answers {
        func a(_ present: Bool) -> Answer { .option(present ? 1 : 0) }
        return [
            "migration": a(migration), "anorexia": a(anorexia), "nausea": a(nausea),
            "tenderness": a(tenderness), "rebound": a(rebound), "temperature": a(temperature),
            "leukocytosis": a(leukocytosis), "left_shift": a(leftShift),
        ]
    }

    // MARK: - Reference cases (known correct outputs)

    func testAllNegativeIsZeroLow() {
        let r = alvarado.compute(answers())
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("Alvarado score 0/10"))
    }

    func testAllPositiveIsMaxHigh() {
        // 1+1+1+2+1+1+2+1 = 10
        let r = alvarado.compute(answers(migration: true, anorexia: true, nausea: true,
                                         tenderness: true, rebound: true, temperature: true,
                                         leukocytosis: true, leftShift: true))
        XCTAssertEqual(r.score, 10)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("high"))
    }

    func testClassicHighCaseScoreSeven() {
        // Migration(1) + anorexia(1) + nausea(1) + tenderness(2) + leukocytosis(2) = 7 → high
        let r = alvarado.compute(answers(migration: true, anorexia: true, nausea: true,
                                         tenderness: true, leukocytosis: true))
        XCTAssertEqual(r.score, 7)
        XCTAssertEqual(r.level, .high)
    }

    func testHeavyWeightedItemsCountTwo() {
        XCTAssertEqual(alvarado.compute(answers(tenderness: true)).score, 2, "RLQ tenderness = 2")
        XCTAssertEqual(alvarado.compute(answers(leukocytosis: true)).score, 2, "Leukocytosis = 2")
        XCTAssertEqual(alvarado.compute(answers(migration: true)).score, 1, "Migration = 1")
    }

    // MARK: - Band boundaries

    func testBandBoundaries() {
        // 3 → low, 4 → moderate, 6 → moderate, 7 → high
        XCTAssertEqual(alvarado.compute(answers(nausea: true, tenderness: true)).score, 3)
        XCTAssertEqual(alvarado.compute(answers(nausea: true, tenderness: true)).level, .low, "3 is low")
        XCTAssertEqual(alvarado.compute(answers(tenderness: true, leukocytosis: true)).score, 4)
        XCTAssertEqual(alvarado.compute(answers(tenderness: true, leukocytosis: true)).level, .moderate, "4 is moderate")
        XCTAssertEqual(alvarado.compute(answers(migration: true, nausea: true, tenderness: true, leukocytosis: true)).score, 6)
        XCTAssertEqual(alvarado.compute(answers(migration: true, nausea: true, tenderness: true, leukocytosis: true)).level, .moderate, "6 is moderate")
        XCTAssertEqual(alvarado.compute(answers(migration: true, anorexia: true, nausea: true, tenderness: true, leukocytosis: true)).score, 7)
        XCTAssertEqual(alvarado.compute(answers(migration: true, anorexia: true, nausea: true, tenderness: true, leukocytosis: true)).level, .high, "7 is high")
    }

    func testComputeIsDeterministic() {
        let a = answers(migration: true, tenderness: true, leukocytosis: true)
        XCTAssertEqual(alvarado.compute(a), alvarado.compute(a))
    }

    func testBreakdownListsEveryComponentWithPoints() {
        let r = alvarado.compute(answers(tenderness: true, leukocytosis: true))
        XCTAssertEqual(r.breakdown.count, 8, "one audit line per component")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Tenderness in RLQ") && $0.contains("+2") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Migration") && $0.contains("+0") })
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForRLQAbdominalPain() {
        var f = ClinicalFacts(chiefComplaint: "abdominal pain")
        f.hpi = "24-year-old with periumbilical pain that migrated to the RLQ."
        let reason = alvarado.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("age 24"))
        XCTAssertTrue(reason!.lowercased().contains("appendicitis"))
    }

    func testRelevantWhenAppendicitisInDifferential() {
        var f = ClinicalFacts(chiefComplaint: "belly pain")
        f.differential = ["acute appendicitis", "gastroenteritis"]
        XCTAssertNotNil(alvarado.relevance(f))
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "twisted his ankle playing soccer")
        XCTAssertNil(alvarado.relevance(f))
    }

    // MARK: - Prefill from grounded facts

    func testPrefillsObjectiveVitalsAndLabsOnly() {
        var f = ClinicalFacts(chiefComplaint: "abdominal pain")
        f.hpi = "24-year-old with RLQ pain."
        f.vitals = [Vital(name: "Temp", value: "38.1")]           // °C, febrile
        f.labs = [LabResult(test: "WBC", value: "14.2", unit: "10^3/uL"),
                  LabResult(test: "Neutrophils", value: "82", unit: "%")]
        let pre = alvarado.prefill(f)
        XCTAssertEqual(pre["temperature"], .option(1), "38.1 °C ≥ 37.3 → yes")
        XCTAssertEqual(pre["leukocytosis"], .option(1), "WBC 14.2 ×10³ > 10,000 → yes")
        XCTAssertEqual(pre["left_shift"], .option(1), "neutrophils 82% > 75% → yes")
        // Subjective symptom/exam findings are never guessed.
        XCTAssertNil(pre["migration"])
        XCTAssertNil(pre["anorexia"])
        XCTAssertNil(pre["nausea"])
        XCTAssertNil(pre["tenderness"])
        XCTAssertNil(pre["rebound"])
    }

    func testPrefillHandlesFahrenheitAndNegativeLabs() {
        var f = ClinicalFacts(chiefComplaint: "RLQ pain")
        f.vitals = [Vital(name: "Temperature", value: "98.6 F")]  // 37.0 °C, afebrile
        f.labs = [LabResult(test: "WBC", value: "8000", unit: "/uL"),
                  LabResult(test: "Neutrophils", value: "60", unit: "%")]
        let pre = alvarado.prefill(f)
        XCTAssertEqual(pre["temperature"], .option(0), "98.6 °F = 37.0 °C < 37.3 → no")
        XCTAssertEqual(pre["leukocytosis"], .option(0), "WBC 8,000 ≤ 10,000 → no")
        XCTAssertEqual(pre["left_shift"], .option(0), "neutrophils 60% ≤ 75% → no")
    }

    func testPrefillIsEmptyWhenNoObjectiveData() {
        var f = ClinicalFacts(chiefComplaint: "abdominal pain")
        f.hpi = "24-year-old with RLQ pain, no labs yet."
        XCTAssertTrue(alvarado.prefill(f).isEmpty)
    }
}
