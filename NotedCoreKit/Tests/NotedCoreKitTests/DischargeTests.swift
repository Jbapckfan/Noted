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
        DischargeVerifier(hpiGroundTruth: layerA, resultsTrayJSON: layerB, dispositionTranscript: layerC)
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

    // MARK: - filtered() — the discharge gate (v1c), symmetric with the note path

    func testFilteredKeepsGroundedDischargeUnchanged() {
        let (clean, report) = verifier().filtered(groundedSummary())
        XCTAssertEqual(clean.medicationsPrescribed.first?.dose, "25 mg")
        XCTAssertEqual(clean.resultsExplained.first?.resultValueVerbatim, "0.02")
        XCTAssertTrue(report.groundingFlags.isEmpty, "grounded discharge should have no removals: \(report.groundingFlags)")
    }

    func testFilteredBlanksUngroundedPrescribedDose() {
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "metoprolol", dose: "250 mg", route: "PO", frequency: "BID")]
        let (clean, _) = verifier().filtered(s)
        XCTAssertEqual(clean.medicationsPrescribed.first?.drug, "metoprolol", "the drug was said; keep it")
        XCTAssertEqual(clean.medicationsPrescribed.first?.dose, "", "250 mg was never said; blank it")
    }

    func testFilteredDropsMedWhoseDrugWasNeverSaid() {
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "warfarin", dose: "5 mg", route: "PO", frequency: "daily")]
        let (clean, _) = verifier().filtered(s)
        XCTAssertTrue(clean.medicationsPrescribed.isEmpty, "warfarin was never in A/B/C — drop the whole prescription")
    }

    func testFilteredBlanksFabricatedQuantityAndDuration() {
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "metoprolol", dose: "25 mg", route: "PO", frequency: "BID", duration: "for 30 days", quantity: "#90")]
        let (clean, _) = verifier().filtered(s)
        XCTAssertEqual(clean.medicationsPrescribed.first?.duration, "", "30-day duration was never said")
        XCTAssertEqual(clean.medicationsPrescribed.first?.quantity, "", "#90 was never said")
    }

    func testFilteredDropsUngroundedExplainedResult() {
        var s = groundedSummary()
        s.resultsExplained = [ResultExplanation(test: "troponin", resultValueVerbatim: "0.20")]
        let (clean, _) = verifier().filtered(s)
        XCTAssertTrue(clean.resultsExplained.isEmpty, "0.20 was never a result in this encounter")
    }

    func testFilteredRemovesFabricatedPrecaution() {
        var s = groundedSummary()
        s.returnPrecautions = [cardiacPrecaution, "Return for sudden loss of vision in one eye."]
        let (clean, _) = verifier().filtered(s)
        XCTAssertEqual(clean.returnPrecautions, [cardiacPrecaution], "the out-of-library precaution is removed")
    }

    /// The laundering guard: a value present ONLY in the model's raw extraction (not the transcript)
    /// must not survive — grounding is against the real encounter, not the model's own output.
    func testFilteredGroundsAgainstTranscriptNotRawExtraction() {
        // hpiGroundTruth (the transcript) never mentions hydralazine; a raw extraction might.
        let v = DischargeVerifier(hpiGroundTruth: "Patient's chest pain resolved.", resultsTrayJSON: nil, dispositionTranscript: "Discharge home.")
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "hydralazine", dose: "25 mg", route: "PO")]
        let (clean, _) = v.filtered(s)
        XCTAssertTrue(clean.medicationsPrescribed.isEmpty, "a drug only in raw extraction, not the transcript, must be dropped")
    }

    /// A drug named only as an allergy or a discontinuation must not become a discharge prescription.
    func testFilteredDropsAllergenAndDiscontinuedDrug() {
        let v = DischargeVerifier(hpiGroundTruth: "She is allergic to penicillin. We are stopping her lisinopril.",
                                  resultsTrayJSON: nil, dispositionTranscript: "Discharge home.")
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "penicillin", dose: "500 mg"),
                                   PrescribedMedication(drug: "lisinopril", dose: "10 mg")]
        let (clean, _) = v.filtered(s)
        XCTAssertTrue(clean.medicationsPrescribed.isEmpty, "an allergen and a discontinued drug must not be prescribed")
    }

    /// Duration/quantity survive only when actually stated near a time/count word.
    func testFilteredKeepsGroundedDurationAndQuantity() {
        let v = DischargeVerifier(hpiGroundTruth: "Take amoxicillin 500 mg by mouth three times a day for 10 days; dispense 30 tablets.",
                                  resultsTrayJSON: nil, dispositionTranscript: "Discharge home.")
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "amoxicillin", dose: "500 mg", route: "PO", frequency: "TID", duration: "for 10 days", quantity: "30 tablets")]
        let (clean, _) = v.filtered(s)
        XCTAssertEqual(clean.medicationsPrescribed.first?.duration, "for 10 days")
        XCTAssertEqual(clean.medicationsPrescribed.first?.quantity, "30 tablets")
    }

    /// A duration whose number only appears elsewhere (an age) is blanked.
    func testFilteredBlanksDurationRidingUnrelatedNumber() {
        let v = DischargeVerifier(hpiGroundTruth: "This 30-year-old man had chest pain. Start metoprolol.",
                                  resultsTrayJSON: nil, dispositionTranscript: "Home on metoprolol.")
        var s = groundedSummary()
        s.medicationsPrescribed = [PrescribedMedication(drug: "metoprolol", duration: "for 30 days")]
        let (clean, _) = v.filtered(s)
        XCTAssertEqual(clean.medicationsPrescribed.first?.duration, "", "'for 30 days' must not ride the '30' in '30-year-old'")
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
