import XCTest
@testable import NotedCoreKit

final class CanadianCSpineTests: XCTestCase {

    private let ccr = CanadianCSpine()

    // Build a full set of answers; each argument is a Bool (true = "Yes"/present).
    private func answers(
        age65: Bool = false,
        dangerousMechanism: Bool = false,
        paresthesias: Bool = false,
        rearEnd: Bool = false,
        sitting: Bool = false,
        ambulatory: Bool = false,
        delayedPain: Bool = false,
        noMidlineTenderness: Bool = false,
        rotation: Bool = false
    ) -> Answers {
        func o(_ b: Bool) -> Answer { .option(b ? 1 : 0) }
        return [
            "age_65": o(age65),
            "dangerous_mechanism": o(dangerousMechanism),
            "paresthesias": o(paresthesias),
            "rear_end": o(rearEnd),
            "sitting": o(sitting),
            "ambulatory": o(ambulatory),
            "delayed_pain": o(delayedPain),
            "no_midline_tenderness": o(noMidlineTenderness),
            "rotation": o(rotation),
        ]
    }

    // MARK: - Reference cases

    /// Clear-LOW: no high-risk factor, a low-risk factor (simple rear-end MVC) permits testing, and
    /// the patient rotates 45° both ways → no imaging required. Rule cleared.
    func testClearedNoImaging() {
        let r = ccr.compute(answers(rearEnd: true, ambulatory: true, rotation: true))
        XCTAssertNil(r.score, "rule-out logic has no numeric score")
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("not required"),
                      "interpretation must state the action: \(r.interpretation)")
    }

    /// Clear-HIGH (rule fails at Step 1): age ≥65 is a high-risk factor → imaging mandated regardless
    /// of any low-risk factors or intact rotation.
    func testHighRiskAgeForcesImaging() {
        let r = ccr.compute(answers(age65: true, rearEnd: true, sitting: true, ambulatory: true,
                                    delayedPain: true, noMidlineTenderness: true, rotation: true))
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("High-risk factor present"))
        XCTAssertTrue(r.interpretation.contains("imaging indicated"))
    }

    /// Rule fails at Step 2: no high-risk factor, but also NO low-risk factor to permit safe ROM
    /// testing → imaging mandated (rotation is not even assessed).
    func testNoLowRiskFactorForcesImaging() {
        let r = ccr.compute(answers()) // everything "No"
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("No low-risk factor"))
    }

    /// Boundary at Step 3: identical low-risk qualifying state, the ONLY difference is rotation.
    /// Unable to rotate → imaging; able → no imaging.
    func testRotationBoundaryFlipsResult() {
        let unable = ccr.compute(answers(sitting: true, rotation: false))
        XCTAssertEqual(unable.level, .high)
        XCTAssertTrue(unable.interpretation.contains("Unable to actively rotate"))

        let able = ccr.compute(answers(sitting: true, rotation: true))
        XCTAssertEqual(able.level, .low)
    }

    /// A high-risk factor short-circuits even when other high-risk inputs are unanswered.
    func testHighRiskShortCircuitsWithoutFullInput() {
        let r = ccr.compute(["paresthesias": .option(1)])
        XCTAssertEqual(r.level, .high)
    }

    /// Incomplete inputs (no high-risk factor confirmed absent, rotation unknown) → indeterminate.
    func testIndeterminateWhenIncomplete() {
        // High-risk factors not all answered → cannot even pass Step 1.
        let r = ccr.compute(["rear_end": .option(1)])
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertNil(r.score)
        XCTAssertTrue(r.interpretation.contains("Cannot apply"))
    }

    /// Passed Step 1 (all high-risk No) and a low-risk factor present, but rotation not entered.
    func testIndeterminateWhenRotationMissing() {
        var a = answers(sitting: true)
        a["rotation"] = nil
        let r = ccr.compute(a)
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertTrue(r.interpretation.contains("active neck rotation"))
    }

    func testBreakdownHasOneLinePerComponent() {
        let r = ccr.compute(answers(sitting: true, rotation: true))
        XCTAssertEqual(r.breakdown.count, ccr.inputs.count, "one audit line per component")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Sitting position") && $0.contains("Yes") })
    }

    func testComputeIsDeterministic() {
        let a = answers(rearEnd: true, rotation: true)
        XCTAssertEqual(ccr.compute(a), ccr.compute(a))
    }

    // MARK: - Relevance (the trigger + inclusion caveat)

    func testRelevantForNeckTrauma() {
        var f = ClinicalFacts(chiefComplaint: "neck pain after MVC")
        f.hpi = "28-year-old restrained driver with neck pain after a motor vehicle collision."
        let reason = ccr.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("GCS 15"), "reason must encode the alert/stable inclusion caveat")
        XCTAssertTrue(reason!.lowercased().contains("trauma"))
    }

    func testNotRelevantForNonNeckComplaint() {
        let f = ClinicalFacts(chiefComplaint: "chest pain", hpi: "substernal chest pressure")
        XCTAssertNil(ccr.relevance(f))
    }

    // MARK: - Prefill (grounded facts only)

    func testPrefillsAgeCriterionOnly() {
        var f = ClinicalFacts(chiefComplaint: "neck pain")
        f.hpi = "72-year-old with neck pain after a fall."
        let pre = ccr.prefill(f)
        XCTAssertEqual(pre["age_65"], .option(1), "72 → age ≥ 65 present")
        XCTAssertNil(pre["dangerous_mechanism"], "mechanism is clinician-assessed, not guessed")
        XCTAssertNil(pre["rotation"], "range of motion is never prefilled")
    }

    func testPrefillsAgeUnder65AsNo() {
        var f = ClinicalFacts(chiefComplaint: "neck pain")
        f.hpi = "40-year-old with neck pain after whiplash."
        XCTAssertEqual(ccr.prefill(f)["age_65"], .option(0))
    }
}
