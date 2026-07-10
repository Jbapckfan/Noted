import XCTest
@testable import NotedCoreKit

final class PERCRuleTests: XCTestCase {

    private let perc = PERCRule()

    /// All eight criteria, keyed by id. Pass 0 (No) / 1 (Yes) for each.
    private func answers(age: Int, hr: Int, sao2: Int, leg: Int, hemo: Int,
                         surg: Int, prior: Int, hormone: Int) -> Answers {
        ["age50": .option(age), "hr100": .option(hr), "sao2": .option(sao2),
         "leg_swelling": .option(leg), "hemoptysis": .option(hemo),
         "surgery_trauma": .option(surg), "prior_pe_dvt": .option(prior),
         "hormone": .option(hormone)]
    }

    private func allNo() -> Answers {
        answers(age: 0, hr: 0, sao2: 0, leg: 0, hemo: 0, surg: 0, prior: 0, hormone: 0)
    }

    // MARK: - Reference cases

    /// Clear rule-out: every criterion absent → PERC negative, no numeric score.
    func testAllNegativeRulesOut() {
        let r = perc.compute(allNo())
        XCTAssertNil(r.score, "PERC is a boolean rule — no numeric score")
        XCTAssertEqual(r.level, .low)
        XCTAssertTrue(r.interpretation.contains("PERC negative"))
        XCTAssertTrue(r.interpretation.contains("<2%"))
    }

    /// Clear rule-failure: a single positive criterion (hormone use) → cannot rule out.
    func testSinglePositiveCannotRuleOut() {
        var a = allNo(); a["hormone"] = .option(1)
        let r = perc.compute(a)
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("PERC positive"))
        XCTAssertTrue(r.interpretation.contains("cannot be excluded"))
        XCTAssertTrue(r.interpretation.contains("Hormone use (estrogen)"))
    }

    /// Boundary: flipping exactly one criterion (HR ≥ 100) moves low → high.
    func testBoundaryOneCriterionFlips() {
        XCTAssertEqual(perc.compute(allNo()).level, .low)
        var a = allNo(); a["hr100"] = .option(1)
        XCTAssertEqual(perc.compute(a).level, .high)
    }

    /// A positive criterion short-circuits even when other criteria are unanswered.
    func testPositiveShortCircuitsWhenIncomplete() {
        let a: Answers = ["age50": .option(1)] // only one answered, and it's Yes
        let r = perc.compute(a)
        XCTAssertEqual(r.level, .high)
        XCTAssertTrue(r.interpretation.contains("PERC positive"))
    }

    /// Incomplete with no positive yet → indeterminate (cannot yet clear the rule).
    func testIncompleteWithoutPositiveIsIndeterminate() {
        var a = allNo(); a["hormone"] = nil // 7 answered No, one missing
        let r = perc.compute(a)
        XCTAssertNil(r.score)
        XCTAssertEqual(r.level, .indeterminate)
        XCTAssertTrue(r.interpretation.contains("incomplete"))
    }

    func testComputeIsDeterministic() {
        var a = allNo(); a["prior_pe_dvt"] = .option(1)
        XCTAssertEqual(perc.compute(a), perc.compute(a))
    }

    func testBreakdownHasOneLinePerCriterion() {
        var a = allNo(); a["hemoptysis"] = .option(1)
        let r = perc.compute(a)
        XCTAssertEqual(r.breakdown.count, 8, "one audit line per criterion")
        XCTAssertTrue(r.breakdown.contains { $0.contains("Hemoptysis") && $0.contains("criterion present") })
        XCTAssertTrue(r.breakdown.contains { $0.contains("Age ≥ 50") && $0.contains("No") })
    }

    // MARK: - Relevance (the trigger + inclusion caveat)

    func testRelevantForDyspnea() {
        var f = ClinicalFacts(chiefComplaint: "shortness of breath")
        f.hpi = "48-year-old with pleuritic chest pain and dyspnea."
        let reason = perc.relevance(f)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.lowercased().contains("pretest probability"),
                      "reason must encode the low-pretest-probability inclusion caveat")
    }

    func testNotRelevantForUnrelatedComplaint() {
        let f = ClinicalFacts(chiefComplaint: "ankle injury", hpi: "twisted his ankle playing soccer")
        XCTAssertNil(perc.relevance(f))
    }

    // MARK: - Prefill from grounded facts only

    func testPrefillsObjectiveVitals() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "62-year-old with pleuritic chest pain."
        f.vitals = [Vital(name: "HR", value: "112"), Vital(name: "SpO2", value: "92%")]
        let pre = perc.prefill(f)
        XCTAssertEqual(pre["age50"], .option(1), "62 ≥ 50")
        XCTAssertEqual(pre["hr100"], .option(1), "HR 112 ≥ 100")
        XCTAssertEqual(pre["sao2"], .option(1), "SpO₂ 92 < 95")
        XCTAssertNil(pre["hemoptysis"], "history/exam items are never guessed")
        XCTAssertNil(pre["leg_swelling"])
        XCTAssertNil(pre["surgery_trauma"])
        XCTAssertNil(pre["prior_pe_dvt"])
        XCTAssertNil(pre["hormone"])
    }

    func testPrefillsNegativeAgeAndHRButNotNormalSaO2() {
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "40-year-old with pleuritic chest pain."
        f.vitals = [Vital(name: "HR", value: "80"), Vital(name: "SpO2", value: "98%")]
        let pre = perc.prefill(f)
        XCTAssertEqual(pre["age50"], .option(0), "40 < 50")
        XCTAssertEqual(pre["hr100"], .option(0), "HR 80 < 100")
        XCTAssertNil(pre["sao2"], "a normal reading is left for the clinician to confirm was on room air")
    }

    func testPrefilledNormalPatientIsIndeterminateUntilCompleted() {
        // Prefill alone (age No, HR No) leaves the history/exam criteria unanswered → indeterminate.
        var f = ClinicalFacts(chiefComplaint: "chest pain")
        f.hpi = "40-year-old with pleuritic chest pain."
        f.vitals = [Vital(name: "HR", value: "80")]
        let r = perc.compute(perc.prefill(f))
        XCTAssertEqual(r.level, .indeterminate)
    }
}
