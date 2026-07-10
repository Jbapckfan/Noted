import XCTest
@testable import NotedCoreKit

final class HEARTScoreTests: XCTestCase {

    private let heart = HEARTScore()

    private func answers(history: Int, ecg: Int, age: Int, risk: Int, trop: Int) -> Answers {
        ["history": .option(history), "ecg": .option(ecg), "age": .option(age),
         "risk_factors": .option(risk), "troponin": .option(trop)]
    }

    func testLowRiskScore() {
        let r = heart.compute(answers(history: 0, ecg: 0, age: 0, risk: 0, trop: 0))
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("HEART score 0"))
    }

    func testModerateRiskScore() {
        // 45–64 (1) + moderately suspicious (1) + non-specific ECG (1) + 1–2 RF (1) + trop normal (0) = 4
        let r = heart.compute(answers(history: 1, ecg: 1, age: 1, risk: 1, trop: 0))
        XCTAssertEqual(r.score, 4)
        XCTAssertEqual(r.level, .moderate)
    }

    func testHighRiskScore() {
        let r = heart.compute(answers(history: 2, ecg: 2, age: 2, risk: 2, trop: 2))
        XCTAssertEqual(r.score, 10)
        XCTAssertEqual(r.level, .high)
    }

    func testBandBoundaries() {
        XCTAssertEqual(heart.compute(answers(history: 2, ecg: 1, age: 0, risk: 0, trop: 0)).level, .low, "3 is low")
        XCTAssertEqual(heart.compute(answers(history: 2, ecg: 2, age: 0, risk: 0, trop: 0)).level, .moderate, "4 is moderate")
        XCTAssertEqual(heart.compute(answers(history: 2, ecg: 2, age: 2, risk: 1, trop: 0)).level, .high, "7 is high")
    }

    func testComputeIsDeterministic() {
        let a = answers(history: 1, ecg: 1, age: 1, risk: 1, trop: 1)
        XCTAssertEqual(heart.compute(a), heart.compute(a))
    }

    func testBreakdownListsEveryComponentWithPoints() {
        let r = heart.compute(answers(history: 2, ecg: 0, age: 1, risk: 0, trop: 0))
        XCTAssertTrue(r.breakdown.contains { $0.contains("History") && $0.contains("+2") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Age") && $0.contains("+1") })
        XCTAssertEqual(r.breakdown.count, 5, "one audit line per component")
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForChestPain() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "62-year-old man with 2 hours of substernal chest pain."
        let reason = heart.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("age 62"))
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "twisted his ankle playing soccer")
        XCTAssertNil(heart.relevance(f))
    }

    // MARK: - Prefill from grounded facts

    func testPrefillsAgeAndRiskFactors() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "62-year-old man with chest pain."
        f.pastMedicalHistory = ["hypertension", "diabetes"]
        let pre = heart.prefill(f)
        XCTAssertEqual(pre["age"], .option(1), "62 → 45–64 band")
        XCTAssertEqual(pre["risk_factors"], .option(1), "HTN + DM = 2 risk factors")
        XCTAssertNil(pre["history"], "subjective inputs are not guessed")
        XCTAssertNil(pre["troponin"], "assay-relative troponin is left for the clinician")
    }

    func testAtheroscleroticDiseaseForcesTopRiskBand() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "58-year-old with chest pain."
        f.pastMedicalHistory = ["prior MI with stent"]
        XCTAssertEqual(heart.prefill(f)["risk_factors"], .option(2))
    }

    func testAgeBandsPrefill() {
        for (hpi, expected) in [("40-year-old", 0), ("55 yo", 1), ("70 y/o", 2)] {
            var f = ClinicalFacts(chiefComplaint: "chest pain"); f.hpi = "\(hpi) with chest pain."
            XCTAssertEqual(heart.prefill(f)["age"], .option(expected), "\(hpi)")
        }
    }
}

final class CalculatorRegistryTests: XCTestCase {

    func testChestPainYieldsHeartSuggestion() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "55-year-old with chest pressure radiating to the arm."
        let suggestions = CalculatorRegistry.suggestions(for: f)
        XCTAssertTrue(suggestions.contains { $0.id == "heart" })
    }

    func testUnrelatedEncounterYieldsNoSuggestions() {
        let f = ClinicalFacts(chiefComplaint: "medication refill", hpi: "here for a refill of blood pressure pills.")
        XCTAssertTrue(CalculatorRegistry.suggestions(for: f).isEmpty)
    }

    func testLookupById() {
        XCTAssertEqual(CalculatorRegistry.calculator(id: "heart")?.name, "HEART Score (chest pain)")
        XCTAssertNil(CalculatorRegistry.calculator(id: "nope"))
    }
}
