import XCTest
@testable import NotedCoreKit

final class WellsPETests: XCTestCase {

    private let wells = WellsPE()

    /// Build a full answer set from the seven boolean criteria (index 0 = No, 1 = Yes).
    private func answers(
        dvt: Bool = false,
        peLikely: Bool = false,
        hr: Bool = false,
        immobilization: Bool = false,
        priorPEorDVT: Bool = false,
        hemoptysis: Bool = false,
        malignancy: Bool = false
    ) -> Answers {
        [
            "dvt_signs": .option(dvt ? 1 : 0),
            "pe_most_likely": .option(peLikely ? 1 : 0),
            "hr_over_100": .option(hr ? 1 : 0),
            "immobilization": .option(immobilization ? 1 : 0),
            "prior_pe_dvt": .option(priorPEorDVT ? 1 : 0),
            "hemoptysis": .option(hemoptysis ? 1 : 0),
            "malignancy": .option(malignancy ? 1 : 0),
        ]
    }

    // MARK: - Reference cases (known correct outputs, cross-checked against MDCalc)

    func testClearLowNothingPresent() {
        let r = wells.compute(answers())
        XCTAssertEqual(r.score, 0)
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("Wells PE 0"))
        XCTAssertTrue(r.interpretation.contains("low risk"))
        XCTAssertTrue(r.interpretation.contains("PE unlikely"))
    }

    func testClearHighAllCriteria() {
        // 3 + 3 + 1.5 + 1.5 + 1.5 + 1 + 1 = 12.5
        let r = wells.compute(answers(
            dvt: true, peLikely: true, hr: true, immobilization: true,
            priorPEorDVT: true, hemoptysis: true, malignancy: true))
        XCTAssertEqual(r.score, 12.5)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("high risk"))
        XCTAssertTrue(r.interpretation.contains("PE likely"))
    }

    func testHighWithThreeItems() {
        // DVT signs (3) + PE most likely (3) + HR>100 (1.5) = 7.5 → high, PE likely
        let r = wells.compute(answers(dvt: true, peLikely: true, hr: true))
        XCTAssertEqual(r.score, 7.5)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("PE likely"))
    }

    // MARK: - Three-tier boundaries (< 2 low, 2–6 moderate, > 6 high)

    func testThreeTierLowModerateBoundary() {
        // 1.5 (HR only) is still < 2 → low
        XCTAssertEqual(wells.compute(answers(hr: true)).level, .low, "1.5 is low")
        // hemoptysis (1) + malignancy (1) = exactly 2 → moderate
        let two = wells.compute(answers(hemoptysis: true, malignancy: true))
        XCTAssertEqual(two.score, 2)
        XCTAssertEqual(two.level, .moderate, "2 is moderate")
    }

    func testThreeTierModerateHighBoundary() {
        // DVT (3) + PE most likely (3) = exactly 6 → moderate
        let six = wells.compute(answers(dvt: true, peLikely: true))
        XCTAssertEqual(six.score, 6)
        XCTAssertEqual(six.level, .moderate, "6 is moderate")
        // PE most likely (3) + HR (1.5) + hemoptysis (1) + malignancy (1) = 6.5 → high
        let sixHalf = wells.compute(answers(peLikely: true, hr: true, hemoptysis: true, malignancy: true))
        XCTAssertEqual(sixHalf.score, 6.5)
        XCTAssertEqual(sixHalf.level, .high, "6.5 is high")
    }

    // MARK: - Two-tier boundary (≤ 4 unlikely, > 4 likely)

    func testTwoTierBoundaryAtFour() {
        // PE most likely (3) + hemoptysis (1) = exactly 4 → PE unlikely (still moderate three-tier)
        let four = wells.compute(answers(peLikely: true, hemoptysis: true))
        XCTAssertEqual(four.score, 4)
        XCTAssertEqual(four.level, .moderate)
        XCTAssertTrue(four.interpretation.contains("PE unlikely"), "4 is PE unlikely")
        XCTAssertTrue(four.recommendation.contains("D-dimer"))
    }

    func testTwoTierJustAboveFour() {
        // PE most likely (3) + HR>100 (1.5) = 4.5 → PE likely
        let fourHalf = wells.compute(answers(peLikely: true, hr: true))
        XCTAssertEqual(fourHalf.score, 4.5)
        XCTAssertTrue(fourHalf.interpretation.contains("PE likely"), "4.5 is PE likely")
        XCTAssertTrue(fourHalf.recommendation.contains("CT pulmonary angiography"))
    }

    // MARK: - Determinism & audit trail

    func testComputeIsDeterministic() {
        let a = answers(dvt: true, hr: true, malignancy: true)
        XCTAssertEqual(wells.compute(a), wells.compute(a))
    }

    func testBreakdownListsEveryComponentWithHalfPoints() {
        let r = wells.compute(answers(dvt: true, hr: true))
        XCTAssertEqual(r.breakdown.count, 7, "one audit line per component")
        XCTAssertTrue(r.breakdown.contains { $0.contains("DVT") && $0.contains("Yes") && $0.contains("+3") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Heart rate > 100") && $0.contains("+1.5") },
                      "half-point weights render as 1.5, not 1")
    }

    // MARK: - Relevance (the trigger)

    func testRelevantForDyspnea() {
        var f = ClinicalFacts(chiefComplaint: "shortness of breath")
        f.hpi = "54-year-old with acute dyspnea and pleuritic chest pain."
        XCTAssertNotNil(wells.relevance(f))
    }

    func testRelevantForSuspectedPE() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.mdm = "Working to rule out PE given pleuritic chest pain."
        XCTAssertNotNil(wells.relevance(f))
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "twisted his ankle playing soccer")
        XCTAssertNil(wells.relevance(f))
    }

    // MARK: - Prefill from grounded facts only

    func testPrefillsTachycardiaFromVitals() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "60-year-old with dyspnea."
        f.vitals = [Vital(name: "HR", value: "118")]
        let pre = wells.prefill(f)
        XCTAssertEqual(pre["hr_over_100"], .option(1), "HR 118 → tachycardia Yes")
        XCTAssertNil(pre["dvt_signs"], "subjective/exam items are not guessed")
        XCTAssertNil(pre["pe_most_likely"], "clinical gestalt is not guessed")
    }

    func testPrefillsNormalHeartRateAsNo() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.vitals = [Vital(name: "HR", value: "82")]
        XCTAssertEqual(wells.prefill(f)["hr_over_100"], .option(0), "HR 82 → tachycardia No")
    }

    func testPrefillsPriorPEfromHistory() {
        var f = ClinicalFacts(chiefComplaint: "dyspnea")
        f.pastMedicalHistory = ["prior pulmonary embolism 2019"]
        XCTAssertEqual(wells.prefill(f)["prior_pe_dvt"], .option(1))
    }

    func testDoesNotPrefillMalignancyQualifier() {
        var f = ClinicalFacts(chiefComplaint: "dyspnea")
        f.pastMedicalHistory = ["breast cancer"]
        // "treatment within 6 months / palliative" is not groundable → left for the clinician.
        XCTAssertNil(wells.prefill(f)["malignancy"])
    }
}
