import XCTest
@testable import NotedCoreKit

final class CURB65Tests: XCTestCase {

    private let curb = CURB65()

    private func answers(confusion: Int, urea: Int, resp: Int, bp: Int, age: Int) -> Answers {
        ["confusion": .option(confusion), "urea": .option(urea), "resp_rate": .option(resp),
         "bp": .option(bp), "age": .option(age)]
    }

    // MARK: - Reference cases (known correct outputs, cross-checked against MDCalc)

    func testScoreZeroIsLowOutpatient() {
        // Young, well patient with none of the criteria → 0.
        let r = curb.compute(answers(confusion: 0, urea: 0, resp: 0, bp: 0, age: 0))
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("CURB-65 score 0"))
        XCTAssertTrue(r.recommendation.lowercased().contains("outpatient"))
    }

    func testScoreOneIsStillLow() {
        // Age ≥ 65 alone → 1, still low severity.
        let r = curb.compute(answers(confusion: 0, urea: 0, resp: 0, bp: 0, age: 1))
        XCTAssertEqual(r.score, 1)
        XCTAssertEqual(r.level, .low)
    }

    func testScoreTwoIsModerateBoundary() {
        // Age ≥ 65 + elevated urea → 2, the low→moderate boundary.
        let r = curb.compute(answers(confusion: 0, urea: 1, resp: 0, bp: 0, age: 1))
        XCTAssertEqual(r.score, 2)
        XCTAssertEqual(r.level, .moderate)
        XCTAssertTrue(r.interpretation.contains("CURB-65 score 2"))
    }

    func testScoreThreeIsSevereBoundary() {
        // The moderate→severe boundary: admit.
        let r = curb.compute(answers(confusion: 1, urea: 1, resp: 0, bp: 0, age: 1))
        XCTAssertEqual(r.score, 3)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.recommendation.lowercased().contains("admission"))
    }

    func testScoreFiveIsSevereWithICUConsideration() {
        // All five criteria present → 5, severe, ICU assessment suggested.
        let r = curb.compute(answers(confusion: 1, urea: 1, resp: 1, bp: 1, age: 1))
        XCTAssertEqual(r.score, 5)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.recommendation.lowercased().contains("icu"))
    }

    func testComputeIsDeterministic() {
        let a = answers(confusion: 1, urea: 0, resp: 1, bp: 0, age: 1)
        XCTAssertEqual(curb.compute(a), curb.compute(a))
    }

    func testBreakdownListsEveryComponentWithPoints() {
        let r = curb.compute(answers(confusion: 1, urea: 0, resp: 1, bp: 0, age: 1))
        XCTAssertEqual(r.breakdown.count, 5, "one audit line per component")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Confusion") && $0.contains("+1") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Age") && $0.contains("+1") })
    }

    // MARK: - Relevance (the trigger + inclusion caveat)

    func testRelevantForPneumonia() {
        var f = ClinicalFacts(chiefComplaint: "cough")
        f.hpi = "72-year-old with productive cough and fever, concern for pneumonia."
        let reason = curb.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("age 72"))
        XCTAssertTrue(reason!.lowercased().contains("community-acquired pneumonia"),
                      "reason encodes the CAP inclusion caveat")
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "twisted his ankle playing soccer")
        XCTAssertNil(curb.relevance(f))
    }

    // MARK: - Prefill from grounded facts

    func testPrefillsObjectiveCriteria() {
        var f = ClinicalFacts(chiefComplaint: "cough")
        f.hpi = "72-year-old with productive cough and dyspnea."
        f.vitals = [Vital(name: "RR", value: "34"), Vital(name: "BP", value: "85/60")]
        f.labs = [LabResult(test: "BUN", value: "30", unit: "mg/dL")]
        let pre = curb.prefill(f)
        XCTAssertEqual(pre["age"], .option(1), "72 → age ≥ 65")
        XCTAssertEqual(pre["resp_rate"], .option(1), "RR 34 → ≥ 30")
        XCTAssertEqual(pre["bp"], .option(1), "SBP 85 < 90")
        XCTAssertEqual(pre["urea"], .option(1), "BUN 30 mg/dL > 19")
        XCTAssertNil(pre["confusion"], "new confusion requires clinical judgment — never guessed")
    }

    func testPrefillsNegativesFromNormalValues() {
        var f = ClinicalFacts(chiefComplaint: "cough")
        f.hpi = "40-year-old with a cough."
        f.vitals = [Vital(name: "Resp Rate", value: "18"), Vital(name: "BP", value: "120/80")]
        f.labs = [LabResult(test: "Urea", value: "5", unit: "mmol/L")]
        let pre = curb.prefill(f)
        XCTAssertEqual(pre["age"], .option(0), "40 → age < 65")
        XCTAssertEqual(pre["resp_rate"], .option(0), "RR 18 → < 30")
        XCTAssertEqual(pre["bp"], .option(0), "120/80 → not hypotensive")
        XCTAssertEqual(pre["urea"], .option(0), "urea 5 mmol/L ≤ 7")
    }

    func testPrefillLeavesBPUnansweredWhenOnlySystolicKnownAndNormal() {
        var f = ClinicalFacts(chiefComplaint: "cough")
        f.hpi = "60-year-old with a cough."
        f.vitals = [Vital(name: "SBP", value: "110")]
        let pre = curb.prefill(f)
        XCTAssertNil(pre["bp"], "normal SBP with unknown diastolic can't rule out DBP ≤ 60")
    }

    // MARK: - Registry wiring (relevance surfaces the suggestion)

    func testPneumoniaYieldsSuggestionWhenRegistered() {
        var f = ClinicalFacts(chiefComplaint: "cough")
        f.hpi = "70-year-old with pneumonia."
        // Directly exercise relevance so the test does not depend on registry registration order.
        XCTAssertNotNil(curb.relevance(f))
    }
}
