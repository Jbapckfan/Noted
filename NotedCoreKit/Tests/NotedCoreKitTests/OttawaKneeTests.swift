import XCTest
@testable import NotedCoreKit

final class OttawaKneeTests: XCTestCase {

    private let rule = OttawaKnee()

    /// 0 = No, 1 = Yes for each criterion. Pass `nil` to leave a criterion unanswered.
    private func answers(age: Int? = 0, patella: Int? = 0, fibula: Int? = 0,
                         flex90: Int? = 0, weightbear: Int? = 0) -> Answers {
        var a: Answers = [:]
        if let age { a["age"] = .option(age) }
        if let patella { a["patella"] = .option(patella) }
        if let fibula { a["fibula"] = .option(fibula) }
        if let flex90 { a["flex90"] = .option(flex90) }
        if let weightbear { a["weightbear"] = .option(weightbear) }
        return a
    }

    // MARK: - Reference cases (known correct outputs)

    /// Clear-low: all five criteria negative → rule clears, no imaging. No numeric score.
    func testAllNegativeClearsWithoutImaging() {
        let r = rule.compute(answers())
        XCTAssertNil(r.score, "rule-out logic has no numeric score")
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("not required"), r.interpretation)
    }

    /// Clear-high via the age criterion: 55-year-old, exam otherwise normal → x-ray indicated.
    func testAgeCriterionAloneIndicatesXray() {
        let r = rule.compute(answers(age: 1))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("x-ray indicated"), r.interpretation)
        XCTAssertTrue(r.interpretation.contains("Age ≥ 55 years"), r.interpretation)
    }

    /// Rule-fails via an exam finding: unable to bear weight → x-ray indicated.
    func testInabilityToBearWeightIndicatesXray() {
        let r = rule.compute(answers(weightbear: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("Inability to bear weight"), r.interpretation)
    }

    /// Boundary: a single positive criterion still forces x-ray even when the others are UNANSWERED
    /// (ANY positive → imaging; the rule short-circuits without needing the rest).
    func testSinglePositiveShortCircuitsEvenWithUnansweredCriteria() {
        let r = rule.compute(answers(age: nil, patella: 1, fibula: nil, flex90: nil, weightbear: nil))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("Isolated tenderness of the patella"), r.interpretation)
    }

    /// Boundary: no positives but not every criterion assessed → cannot clear → indeterminate.
    func testIncompleteWithoutPositivesIsIndeterminate() {
        let r = rule.compute(answers(age: 0, patella: 0, fibula: nil, flex90: nil, weightbear: nil))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertTrue(r.interpretation.contains("incomplete"), r.interpretation)
    }

    func testAllPositiveIndicatesXray() {
        let r = rule.compute(answers(age: 1, patella: 1, fibula: 1, flex90: 1, weightbear: 1))
        XCTAssertEqual(r.level, .high)
    }

    // MARK: - Breakdown & determinism

    func testBreakdownHasOneLinePerCriterion() {
        let r = rule.compute(answers(fibula: 1))
        XCTAssertEqual(r.breakdown.count, 5, "one audit line per criterion")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Tenderness at the head of the fibula") && $0.contains("Yes") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Age ≥ 55 years") && $0.contains("No") })
    }

    func testComputeIsDeterministic() {
        let a = answers(age: 1, patella: 0, fibula: 0, flex90: 1, weightbear: 0)
        XCTAssertEqual(rule.compute(a), rule.compute(a))
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForKneeInjury() {
        let f = ClinicalFacts(chiefComplaint: "knee injury",
                              hpi: "34-year-old who twisted his knee playing soccer with knee pain and swelling.")
        let reason = rule.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.lowercased().contains("knee"), reason ?? "")
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "chest pain", hpi: "62-year-old with substernal chest pain.")
        XCTAssertNil(rule.relevance(f))
    }

    // MARK: - Prefill from grounded facts

    func testPrefillsAgeCriterionBoundary() {
        var young = ClinicalFacts(chiefComplaint: "knee injury"); young.hpi = "54-year-old with knee pain."
        XCTAssertEqual(rule.prefill(young)["age"], .option(0), "54 → age criterion not met")

        var older = ClinicalFacts(chiefComplaint: "knee injury"); older.hpi = "55-year-old with knee pain."
        XCTAssertEqual(rule.prefill(older)["age"], .option(1), "55 → age criterion met")
    }

    func testPrefillNeverGuessesExamFindings() {
        var f = ClinicalFacts(chiefComplaint: "knee injury"); f.hpi = "60-year-old with knee pain."
        let pre = rule.prefill(f)
        XCTAssertEqual(pre["age"], .option(1))
        XCTAssertNil(pre["patella"], "exam findings are clinician-assessed, never guessed")
        XCTAssertNil(pre["fibula"])
        XCTAssertNil(pre["flex90"])
        XCTAssertNil(pre["weightbear"])
    }

    func testPrefillEmptyWhenNoAge() {
        let f = ClinicalFacts(chiefComplaint: "knee injury", hpi: "adult with knee pain after a fall.")
        XCTAssertTrue(rule.prefill(f).isEmpty)
    }
}
