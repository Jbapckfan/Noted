import XCTest
@testable import NotedCoreKit

final class NEXUSCSpineTests: XCTestCase {

    private let nexus = NEXUSCSpine()

    /// index 0 = "No" (finding absent, criterion met); index 1 = "Yes" (finding present, criterion not met).
    private func answers(tenderness: Int, deficit: Int, alertness: Int, intoxication: Int, distracting: Int) -> Answers {
        ["tenderness": .option(tenderness), "deficit": .option(deficit), "alertness": .option(alertness),
         "intoxication": .option(intoxication), "distracting": .option(distracting)]
    }

    // MARK: - Reference cases (known correct outputs)

    /// Clear-low: all five low-risk criteria met → cleared without imaging.
    func testAllCriteriaMetClearsWithoutImaging() {
        let r = nexus.compute(answers(tenderness: 0, deficit: 0, alertness: 0, intoxication: 0, distracting: 0))
        XCTAssertNil(r.score, "rule-out instrument has no numeric score")
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("imaging not required by NEXUS"),
                      "interpretation must state the action: \(r.interpretation)")
    }

    /// Clear-high / rule fails: a positive finding (midline tenderness) → cannot clear.
    func testMidlineTendernessFailsRule() {
        let r = nexus.compute(answers(tenderness: 1, deficit: 0, alertness: 0, intoxication: 0, distracting: 0))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("obtain c-spine imaging"),
                      "interpretation must state the action: \(r.interpretation)")
    }

    /// Boundary: exactly one of five criteria not met (distracting injury) still fails the rule —
    /// ALL five must be negative to clear.
    func testSingleFailingCriterionIsHigh() {
        let r = nexus.compute(answers(tenderness: 0, deficit: 0, alertness: 0, intoxication: 0, distracting: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("1 of 5"))
        XCTAssertTrue(r.interpretation.contains("criterion"), "singular noun for one failure")
    }

    func testMultipleFailingCriteria() {
        let r = nexus.compute(answers(tenderness: 1, deficit: 1, alertness: 1, intoxication: 0, distracting: 0))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("3 of 5"))
        XCTAssertTrue(r.interpretation.contains("criteria"), "plural noun for multiple failures")
    }

    /// Incomplete inputs → indeterminate, never a clearance.
    func testIncompleteAssessmentIsIndeterminate() {
        let partial: Answers = ["tenderness": .option(0), "deficit": .option(0), "alertness": .option(0)]
        let r = nexus.compute(partial)
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertTrue(r.interpretation.contains("2 of 5"), "two criteria unassessed: \(r.interpretation)")
    }

    func testComputeIsDeterministic() {
        let a = answers(tenderness: 0, deficit: 1, alertness: 0, intoxication: 1, distracting: 0)
        XCTAssertEqual(nexus.compute(a), nexus.compute(a))
    }

    func testBreakdownListsEveryCriterion() {
        let r = nexus.compute(answers(tenderness: 1, deficit: 0, alertness: 0, intoxication: 0, distracting: 0))
        XCTAssertEqual(r.breakdown.count, 5, "one audit line per criterion")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Posterior midline") && $0.contains("NOT met") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Focal neurologic deficit") && $0.contains("criterion met") })
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForNeckPainAfterMVC() {
        var f = ClinicalFacts(chiefComplaint: "neck pain")
        f.hpi = "28-year-old restrained driver in a motor vehicle collision with neck pain."
        let reason = nexus.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.lowercased().contains("blunt trauma"), "reason encodes the inclusion caveat")
    }

    func testRelevantForFall() {
        var f = ClinicalFacts(chiefComplaint: "fall")
        f.hpi = "70-year-old who fell down the stairs with cervical spine tenderness."
        XCTAssertNotNil(nexus.relevance(f))
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "chest pain", hpi: "2 hours of substernal chest pressure.")
        XCTAssertNil(nexus.relevance(f))
    }

    // MARK: - Prefill (never guess subjective/exam inputs)

    func testPrefillNeverGuessesExamFindings() {
        var f = ClinicalFacts(chiefComplaint: "neck pain")
        f.hpi = "34-year-old after a fall with neck pain."
        XCTAssertTrue(nexus.prefill(f).isEmpty, "all five NEXUS criteria are clinician-assessed; none may be prefilled")
    }
}
