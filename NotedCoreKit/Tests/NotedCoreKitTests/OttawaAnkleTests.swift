import XCTest
@testable import NotedCoreKit

final class OttawaAnkleTests: XCTestCase {

    private let rule = OttawaAnkle()

    /// 0 = No, 1 = Yes for each finding. Pass `nil` to leave a finding unanswered.
    private func answers(malleolarPain: Int? = 0, lateral: Int? = 0, medial: Int? = 0,
                         midfootPain: Int? = 0, fifthMT: Int? = 0, navicular: Int? = 0,
                         unableBearWeight: Int? = 0) -> Answers {
        var a: Answers = [:]
        if let malleolarPain { a["malleolar_pain"] = .option(malleolarPain) }
        if let lateral { a["lateral_malleolus"] = .option(lateral) }
        if let medial { a["medial_malleolus"] = .option(medial) }
        if let midfootPain { a["midfoot_pain"] = .option(midfootPain) }
        if let fifthMT { a["fifth_metatarsal"] = .option(fifthMT) }
        if let navicular { a["navicular"] = .option(navicular) }
        if let unableBearWeight { a["unable_bear_weight"] = .option(unableBearWeight) }
        return a
    }

    // MARK: - Reference cases (known correct outputs)

    /// Clear-low: no zone pain and no criteria → neither series indicated. No numeric score.
    func testAllNegativeClearsWithoutImaging() {
        let r = rule.compute(answers())
        XCTAssertNil(r.score, "rule-out logic has no numeric score")
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("no ankle or foot x-ray required"), r.interpretation)
    }

    /// Clear-high, ankle branch: malleolar-zone pain + lateral malleolus tenderness → ankle x-ray.
    func testAnkleBranchIndicatesAnkleXray() {
        let r = rule.compute(answers(malleolarPain: 1, lateral: 1))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("ankle x-ray indicated"), r.interpretation)
        XCTAssertTrue(r.recommendation.contains("ankle radiograph"), r.recommendation)
    }

    /// Clear-high, foot branch: midfoot-zone pain + base-of-5th-metatarsal tenderness → foot x-ray.
    func testFootBranchIndicatesFootXray() {
        let r = rule.compute(answers(midfootPain: 1, fifthMT: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("foot x-ray indicated"), r.interpretation)
        XCTAssertFalse(r.interpretation.contains("ankle x-ray"), r.interpretation)
    }

    /// Inability to bear weight is a shared criterion — with malleolar-zone pain it drives the ankle
    /// branch; with midfoot-zone pain it drives the foot branch.
    func testInabilityToBearWeightDrivesAnkleBranch() {
        let r = rule.compute(answers(malleolarPain: 1, unableBearWeight: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("ankle x-ray indicated"), r.interpretation)
    }

    func testInabilityToBearWeightDrivesFootBranch() {
        let r = rule.compute(answers(midfootPain: 1, unableBearWeight: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("foot x-ray indicated"), r.interpretation)
    }

    /// Both zones positive → both series indicated.
    func testBothBranchesIndicateBothXrays() {
        let r = rule.compute(answers(malleolarPain: 1, lateral: 1, midfootPain: 1, navicular: 1))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("ankle and foot x-rays indicated"), r.interpretation)
    }

    // MARK: - Boundaries (the AND-gate is the whole rule)

    /// Boundary: zone pain WITHOUT any bony tenderness or inability to bear weight → no x-ray. Pain
    /// alone does not satisfy the rule.
    func testZonePainAloneDoesNotRequireXray() {
        let r = rule.compute(answers(malleolarPain: 1, midfootPain: 1))
        XCTAssertEqual(r.level, .low, "zone pain with all criteria absent clears")
        XCTAssertNil(r.score)
    }

    /// Boundary: a positive bony-tenderness / weight-bearing criterion WITHOUT pain in that zone does
    /// NOT indicate a film — the zone-pain precondition gates every branch.
    func testTendernessWithoutZonePainDoesNotRequireXray() {
        let r = rule.compute(answers(malleolarPain: 0, lateral: 1, medial: 1,
                                     midfootPain: 0, fifthMT: 1, navicular: 1, unableBearWeight: 1))
        XCTAssertEqual(r.level, .low)
    }

    /// Boundary: a positive criterion with zone pain short-circuits to x-ray even when the other
    /// criteria (and the other zone) are UNANSWERED.
    func testPositiveBranchShortCircuitsWithUnansweredInputs() {
        let r = rule.compute(answers(malleolarPain: 1, lateral: 1, medial: nil,
                                     midfootPain: nil, fifthMT: nil, navicular: nil, unableBearWeight: nil))
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("ankle x-ray indicated"), r.interpretation)
    }

    // MARK: - Incomplete → indeterminate

    /// Zone pain present but its criteria unassessed, and no other branch positive → cannot clear.
    func testIncompleteWithoutPositivesIsIndeterminate() {
        let r = rule.compute(answers(malleolarPain: 1, lateral: nil, medial: nil,
                                     midfootPain: 0, fifthMT: 0, navicular: 0, unableBearWeight: nil))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertTrue(r.interpretation.contains("incomplete"), r.interpretation)
    }

    /// No answers at all → both zones unassessed → indeterminate.
    func testEmptyAnswersIsIndeterminate() {
        let r = rule.compute([:])
        XCTAssertEqual(r.level, .indeterminate)
    }

    // MARK: - Breakdown & determinism

    func testBreakdownHasOneLinePerComponentPlusBranchConclusions() {
        let r = rule.compute(answers(malleolarPain: 1, lateral: 1))
        // 7 component lines + 2 zone-gated branch conclusions.
        XCTAssertEqual(r.breakdown.count, 9)
        XCTAssertTrue(r.breakdown.contains { $0.contains("Pain in the malleolar zone") && $0.contains("Yes") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("posterior edge or tip of the lateral malleolus") && $0.contains("Yes") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Ankle series") && $0.contains("x-ray indicated") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Foot series") && $0.contains("not indicated") })
    }

    func testComputeIsDeterministic() {
        let a = answers(malleolarPain: 1, lateral: 0, medial: 1, midfootPain: 0, unableBearWeight: 0)
        XCTAssertEqual(rule.compute(a), rule.compute(a))
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForAnkleInjury() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury",
                              hpi: "28-year-old who rolled his ankle stepping off a curb, with ankle pain and swelling.")
        let reason = rule.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.lowercased().contains("ankle"), reason ?? "")
    }

    func testRelevantForFootInjury() {
        let f = ClinicalFacts(chiefComplaint: "foot pain", hpi: "40-year-old with midfoot pain after a twisting injury.")
        XCTAssertNotNil(rule.relevance(f))
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "chest pain", hpi: "62-year-old with substernal chest pain.")
        XCTAssertNil(rule.relevance(f))
    }

    // MARK: - Prefill (all inputs are clinician-assessed exam findings)

    func testPrefillIsEmpty() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "34-year-old with a twisted ankle and ankle pain.")
        XCTAssertTrue(rule.prefill(f).isEmpty, "zone pain, bony tenderness and weight-bearing are never guessed")
    }
}
