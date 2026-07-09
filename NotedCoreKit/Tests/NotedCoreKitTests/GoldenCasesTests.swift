import XCTest
@testable import NotedCoreKit

/// Golden-transcript regression: the deterministic verifier run against REAL ED dialogue and the
/// adversarial mutations mined from the 5 gold cases (see Fixtures/verifier-test-matrix.json —
/// 29 traps / 21 rules). Encoded here as the strongest, real-conversation subset (cases 1 & 3,
/// the ones with spoken transcripts). Each `mustCatch` mutation must produce a flag; each grounded
/// fact set must verify clean (the no-false-positive contract).
final class GoldenCasesTests: XCTestCase {

    // MARK: Case 3 — Acute appendicitis (conversational)

    /// Verbatim load-bearing lines from the appendicitis case.
    private let case3 = """
    Doctor: Your blood pressure is 118 over 76, heart rate 102, temp 101.2, respiratory rate 16, \
    and your O2 sat is 99% on room air.
    Doctor: I'm going to start you on ciprofloxacin and metronidazole through your IV.
    Doctor: You told me you're allergic to penicillin — you break out in hives.
    Patient: The pain, it's like an 8. Maybe even a 9.
    Doctor: We'll send a complete blood count, a metabolic panel, and a pregnancy test, and get a \
    CT scan of your abdomen and pelvis with IV contrast.
    """

    func testCase3GroundedFactsVerifyClean() {
        let facts = ClinicalFacts(
            medications: [
                Medication(drug: "ciprofloxacin", dose: nil, route: "IV"),
                Medication(drug: "metronidazole", dose: nil, route: "IV"),
            ],
            vitals: [
                Vital(name: "temp", value: "101.2"),
                Vital(name: "O2 sat", value: "99% on room air"),
                Vital(name: "heart rate", value: "102"),
            ]
        )
        let report = GroundingVerifier(transcript: case3).verify(facts)
        XCTAssertTrue(report.isClean, "all values are spoken in the transcript: \(report.flags)")
    }

    func testCase3FabricatedPotassiumCaught() {
        // Labs were ORDERED only — no result value was ever spoken (R8).
        let facts = ClinicalFacts(labs: [LabResult(test: "potassium", value: "7.2")])
        let report = GroundingVerifier(transcript: case3).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedLabValue })
    }

    func testCase3OxygenSatDigitSwapCaught() {
        // Grounded 99%; a swap to 89% falsely implies hypoxia (R9 — vitals count).
        let facts = ClinicalFacts(vitals: [Vital(name: "O2 sat", value: "89% on room air")])
        let report = GroundingVerifier(transcript: case3).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedVitalValue })
    }

    func testCase3AntibioticRouteDowngradeCaught() {
        // Transcript says "through your IV"; a PO downgrade is ungrounded (R7).
        let facts = ClinicalFacts(medications: [Medication(drug: "ciprofloxacin", dose: nil, route: "PO")])
        let report = GroundingVerifier(transcript: case3).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedRoute })
    }

    func testCase3PenicillinClassHallucinationCaught() {
        // Patient is PCN-allergic and physician chose non-penicillin agents; piperacillin is
        // never spoken (R10 spirit — here caught as a plain hallucinated medication).
        let facts = ClinicalFacts(medications: [Medication(drug: "piperacillin-tazobactam", dose: "3.375 g", route: "IV")])
        let report = GroundingVerifier(transcript: case3).verify(facts)
        XCTAssertEqual(report.flags.first?.kind, .ungroundedMedication)
    }

    // MARK: Case 1 — Chest pain (no aspirin dose spoken)

    private let case1 = """
    Doctor: I'm going to give you some aspirin to chew now.
    Doctor: We're going to rule out a heart attack.
    """

    func testCase1AspirinWithoutDoseVerifiesClean() {
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: nil)])
        XCTAssertTrue(GroundingVerifier(transcript: case1).verify(facts).isClean)
    }

    func testCase1InferredAspirinDoseCaught() {
        // No dose was spoken; "324 mg" comes from a documentation file, not the encounter (R14/R20).
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: "324 mg")])
        let report = GroundingVerifier(transcript: case1).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedDose })
    }

    func testCase1FabricatedDischargePrecautionCaught() {
        // Cardiac rule-out heading to admission — no discharge precautions were given (R13).
        let allowed: Set<String> = [] // nothing approved for this encounter
        let facts = ClinicalFacts(returnPrecautions: ["Return to the ED if your chest pain worsens"])
        let report = GroundingVerifier(transcript: case1, allowedPrecautions: allowed).verify(facts)
        XCTAssertEqual(report.flags.first?.kind, .fabricatedPrecaution)
    }
}
