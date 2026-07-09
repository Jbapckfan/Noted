import XCTest
@testable import NotedCoreKit

final class GroundingVerifierTests: XCTestCase {

    // MARK: - Clean pass

    func testFullyGroundedFactsVerifyClean() {
        let transcript = """
        Doctor: I'm going to give you aspirin 324 mg to chew now.
        The potassium came back at 3.2 and the troponin is 0.04.
        """
        let facts = ClinicalFacts(
            medications: [Medication(drug: "aspirin", dose: "324 mg", route: nil, frequency: nil)],
            labs: [LabResult(test: "potassium", value: "3.2"), LabResult(test: "troponin", value: "0.04")]
        )
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "every value is present verbatim: \(report.flags)")
    }

    // MARK: - The core safety cases

    func testSwappedPotassiumValueIsCaught() {
        // Transcript says 3.2; the draft claims a lethal 7.2.
        let transcript = "The potassium came back at 3.2 today."
        let facts = ClinicalFacts(labs: [LabResult(test: "potassium", value: "7.2")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.flags.first?.kind, .ungroundedLabValue)
    }

    func testWrongDoseIsCaught() {
        let transcript = "Give aspirin 324 mg now."
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: "81 mg")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedDose })
    }

    func testHallucinatedMedicationIsCaught() {
        let transcript = "We gave aspirin and nitroglycerin."
        let facts = ClinicalFacts(medications: [Medication(drug: "morphine", dose: "4 mg")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertEqual(report.flags.first?.kind, .ungroundedMedication)
    }

    /// The laundering case: 7.2 exists in the transcript, but for a DIFFERENT test.
    /// A claimed potassium of 7.2 must still be flagged — it isn't the number next to "potassium".
    func testAdjacentValueBindingPreventsLaundering() {
        let transcript = "Labs: glucose 7.2, potassium 3.2, magnesium 2.0."
        let facts = ClinicalFacts(labs: [LabResult(test: "potassium", value: "7.2")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertFalse(report.isClean, "7.2 belongs to glucose, not potassium — must not launder")
        XCTAssertEqual(report.flags.first?.kind, .ungroundedLabValue)
    }

    // MARK: - Numeric boundary correctness

    func testDecimalIsNotMatchedInsideALargerNumber() {
        // "3.2" must NOT be considered grounded just because "13.2" appears.
        let transcript = "The glucose is 13.2 this morning."
        let facts = ClinicalFacts(labs: [LabResult(test: "glucose", value: "3.2")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertFalse(report.isClean, "3.2 is not present; 13.2 is a different value")
    }

    func testValueBeforeNameStillGrounds() {
        let transcript = "Her sodium of 138 is normal."
        let facts = ClinicalFacts(labs: [LabResult(test: "sodium", value: "138")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "value immediately before the test name is grounded: \(report.flags)")
    }

    func testMultiTokenDoseGrounds() {
        let transcript = "Prescribed Percocet 5/325 for pain."
        let facts = ClinicalFacts(medications: [Medication(drug: "Percocet", dose: "5/325")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "both 5 and 325 present next to Percocet: \(report.flags)")
    }

    // MARK: - Routes and precautions

    func testWrongRouteIsCaught() {
        let transcript = "Give ceftriaxone IV now." // route stated as IV
        let facts = ClinicalFacts(medications: [Medication(drug: "ceftriaxone", dose: nil, route: "PO")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedRoute }, "PO not in transcript")
    }

    func testFabricatedReturnPrecautionIsCaught() {
        let allowed: Set<String> = ["return for worsening chest pain", "return for shortness of breath"]
        let facts = ClinicalFacts(returnPrecautions: ["return for sudden vision loss"])
        let report = GroundingVerifier(transcript: "any transcript", allowedPrecautions: allowed).verify(facts)
        XCTAssertEqual(report.flags.first?.kind, .fabricatedPrecaution)
    }

    func testApprovedPrecautionPassesClean() {
        let allowed: Set<String> = ["Return for worsening chest pain"]
        let facts = ClinicalFacts(returnPrecautions: ["return for worsening chest pain"])
        let report = GroundingVerifier(transcript: "t", allowedPrecautions: allowed).verify(facts)
        XCTAssertTrue(report.isClean)
    }
}
