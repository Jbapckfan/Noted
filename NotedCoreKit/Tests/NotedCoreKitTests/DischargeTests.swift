import XCTest
@testable import NotedCoreKit

final class DischargeVerifierTests: XCTestCase {

    // Layer A (HPI facts), Layer B (results tray), Layer C (disposition dictation).
    private let layerA = #"{"chief_complaint":"chest pain","differential":["ACS"]}"#
    private let layerB = #"{"labs":[{"test":"troponin","value":"0.02"}],"meds_given":["aspirin 324 mg"]}"#
    private let layerC = """
    We're sending you home on metoprolol 25 mg by mouth twice a day. Follow up with cardiology \
    in one week. Your chest pain has resolved and the troponin was negative.
    """

    private let cardiacPrecaution =
        "Return immediately or call 911 for chest pain, pressure, or tightness — especially if it spreads to your arm, jaw, or back."

    private func verifier() -> DischargeVerifier {
        DischargeVerifier(extractionJSON: layerA, resultsTrayJSON: layerB, dispositionTranscript: layerC)
    }

    private func groundedSummary() -> DischargeSummary {
        DischargeSummary(
            finalDiagnosis: "chest pain, low risk",
            briefClinicalCourse: "Your chest pain resolved and your heart tests were reassuring.",
            resultsExplained: [ResultExplanation(test: "troponin", resultValueVerbatim: "0.02", plainLanguageMeaning: "a heart test that was normal")],
            medicationsPrescribed: [PrescribedMedication(drug: "metoprolol", dose: "25 mg", route: "PO", frequency: "BID")],
            followUp: [FollowUp(who: "cardiology", when: "in one week")],
            returnPrecautions: [cardiacPrecaution]
        )
    }

    func testGroundedDischargeVerifiesClean() {
        let report = verifier().verify(groundedSummary())
        XCTAssertTrue(report.isClean, "grounding: \(report.groundingFlags) structural: \(report.structuralIssues)")
    }

    func testPrescribedDoseNotInSourceIsCaught() {
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "metoprolol", dose: "250 mg", route: "PO", frequency: "BID")]
        let report = verifier().verify(s)
        XCTAssertTrue(report.groundingFlags.contains { $0.kind == .ungroundedDose })
    }

    func testExplainedResultValueNotInSourceIsCaught() {
        var s = groundedSummary()
        s.resultsExplained = [ResultExplanation(test: "troponin", resultValueVerbatim: "0.20")]
        let report = verifier().verify(s)
        XCTAssertTrue(report.groundingFlags.contains { $0.kind == .ungroundedLabValue })
    }

    func testFabricatedPrecautionOutsideLibraryIsCaught() {
        var s = groundedSummary()
        s.returnPrecautions = ["Return for sudden loss of vision in one eye."]
        let report = verifier().verify(s)
        XCTAssertTrue(report.groundingFlags.contains { $0.kind == .fabricatedPrecaution })
    }

    func testMissingRequiredSectionsAreFlagged() {
        var s = groundedSummary()
        s.followUp = []
        s.returnPrecautions = []
        let report = verifier().verify(s)
        XCTAssertTrue(report.structuralIssues.contains { $0.contains("follow-up") })
        XCTAssertTrue(report.structuralIssues.contains { $0.contains("return precautions") })
    }

    func testPendingResultNotOrderedIsFlagged() {
        var s = groundedSummary()
        s.pendingResults = [PendingResult(test: "MRI brain", howCommunicated: "we will call you")]
        let report = verifier().verify(s)
        XCTAssertTrue(report.structuralIssues.contains { $0.contains("MRI brain") })
    }

    func testParsesSnakeCaseDischargeJSON() throws {
        let json = #"{"final_diagnosis":"STEMI","medications_prescribed":[{"drug":"aspirin","dose":"81 mg"}],"return_precautions":["x"],"pending_results":[{"test":"culture","how_communicated":"phone"}]}"#
        let s = try DischargeSummary.parse(json)
        XCTAssertEqual(s.finalDiagnosis, "STEMI")
        XCTAssertEqual(s.medicationsPrescribed.first?.dose, "81 mg")
        XCTAssertEqual(s.pendingResults.first?.howCommunicated, "phone")
    }
}

final class DischargeRendererTests: XCTestCase {

    private func summary() -> DischargeSummary {
        DischargeSummary(
            finalDiagnosis: "chest pain, low risk",
            briefClinicalCourse: "Chest pain resolved.",
            medicationsPrescribed: [PrescribedMedication(drug: "metoprolol", dose: "25 mg", route: "PO", frequency: "BID")],
            followUp: [FollowUp(who: "cardiology", when: "in one week")],
            returnPrecautions: ["Return to the ER if your chest pain comes back."]
        )
    }

    func testClinicianRenderContainsClinicalFacts() {
        let text = DischargeRenderer.renderClinician(summary())
        XCTAssertTrue(text.contains("FINAL DIAGNOSIS: chest pain, low risk"))
        XCTAssertTrue(text.contains("metoprolol 25 mg PO BID"))
        XCTAssertTrue(text.contains("cardiology"))
    }

    func testPatientRenderExpandsAbbreviationsAndKeepsCopySlots() {
        let text = DischargeRenderer.renderPatient(summary())
        XCTAssertTrue(text.contains("metoprolol 25 mg"), "drug + dose are copy slots — byte-identical")
        XCTAssertTrue(text.contains("by mouth"), "PO expanded")
        XCTAssertTrue(text.contains("twice a day"), "BID expanded")
        XCTAssertTrue(text.contains("emergency room"), "ER expanded")
        XCTAssertTrue(text.contains("Take metoprolol"), "second person")
        XCTAssertFalse(text.contains(" PO "), "no raw abbreviation left")
        XCTAssertFalse(text.contains("BID"))
    }
}

final class ReadabilityTests: XCTestCase {

    func testSimpleTextScoresLowerThanComplex() {
        let simple = "Come back to the ER if your pain gets worse."
        let complex = "The patient underwent comprehensive cardiovascular evaluation demonstrating unremarkable serial troponin concentrations."
        XCTAssertLessThan(Readability.fleschKincaidGrade(simple), Readability.fleschKincaidGrade(complex))
    }

    func testMeetsGradeGate() {
        let simple = "Take your medicine two times a day. Come back if you feel worse."
        XCTAssertTrue(Readability.meetsGrade(simple, ceiling: 8))
        let complex = "Subsequent electrocardiographic reassessment corroborated the absence of ischemic repolarization abnormalities."
        XCTAssertFalse(Readability.meetsGrade(complex, ceiling: 8))
    }
}

final class ReturnPrecautionLibraryTests: XCTestCase {

    func testCardiacDiagnosisYieldsCardiacPrecautions() {
        let approved = ReturnPrecautionLibrary.approved(forDiagnosis: "acute chest pain, ACS")
        XCTAssertTrue(approved.contains { $0.contains("911 for chest pain") })
        XCTAssertTrue(approved.count > ReturnPrecautionLibrary.universal.count)
    }

    func testUnknownDiagnosisYieldsUniversalOnly() {
        let approved = ReturnPrecautionLibrary.approved(forDiagnosis: "something unmapped")
        XCTAssertEqual(approved, ReturnPrecautionLibrary.universal)
    }
}
