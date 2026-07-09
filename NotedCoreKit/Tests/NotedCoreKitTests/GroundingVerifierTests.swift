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

    // MARK: - Narrative (prose) grounding — the fabricated-HPI case

    func testFabricatedHPINarrativeIsRemoved() {
        // Transcript is only the clinician's opening question — the patient never spoke.
        let transcript = "So can you tell me what brought you into the hospital today, the nurse was telling me that you're having some chest pain."
        var facts = ClinicalFacts(chiefComplaint: "chest pain")
        facts.hpi = "I was at work when I started feeling a tightness in my chest, it was like a squeezing sensation, and it's been getting worse over the past hour, I've also been experiencing shortness of breath."
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.hpi, "a fabricated HPI (nothing the patient said) must be removed, not rendered")
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedNarrative })
    }

    func testGroundedHPINarrativeSurvives() {
        let transcript = "Patient: I was at work and I started feeling tightness in my chest, a squeezing sensation, getting worse over the past hour, and I've had shortness of breath."
        var facts = ClinicalFacts()
        facts.hpi = "Started feeling tightness in the chest, a squeezing sensation getting worse over the past hour, with shortness of breath."
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNotNil(grounded.hpi, "an HPI grounded in the patient's own words must survive")
    }

    func testApprovedPrecautionPassesClean() {
        let allowed: Set<String> = ["Return for worsening chest pain"]
        let facts = ClinicalFacts(returnPrecautions: ["return for worsening chest pain"])
        let report = GroundingVerifier(transcript: "t", allowedPrecautions: allowed).verify(facts)
        XCTAssertTrue(report.isClean)
    }

    // MARK: - Unit-aware numeric grounding (Safety Kernel v1a)

    /// The lethal case: transcript says micrograms, the draft claims milligrams (a 1000x error).
    /// The number matches; the unit must not be ignored.
    func testFentanylMicrogramVsMilligramIsCaught() {
        let transcript = "We gave fentanyl 50 micrograms IV for pain."
        let facts = ClinicalFacts(medications: [Medication(drug: "fentanyl", dose: "50 mg", route: "IV")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedDose },
                      "50 mg must not ground against '50 micrograms': \(report.flags)")
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.dose, nil,
                       "the mismatched dose must be stripped, the drug kept")
        XCTAssertEqual(grounded.medications.first?.drug, "fentanyl")
    }

    /// Lab units: potassium 3.2 mEq/L must not launder a claimed 3.2 mg/dL.
    func testLabValueUnitMismatchIsRemoved() {
        let transcript = "The potassium came back at 3.2 mEq/L."
        let inValue = ClinicalFacts(labs: [LabResult(test: "potassium", value: "3.2 mg/dL")])
        let inField = ClinicalFacts(labs: [LabResult(test: "potassium", value: "3.2", unit: "mg/dL")])
        for facts in [inValue, inField] {
            let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
            XCTAssertTrue(grounded.labs.isEmpty, "a wrong-unit lab value must be removed: \(report.flags)")
            XCTAssertEqual(report.flags.first?.kind, .ungroundedLabValue)
        }
    }

    /// The matching unit still grounds — no over-rejection of a correct value.
    func testCorrectUnitStillGrounds() {
        let transcript = "Give aspirin 324 mg to chew now."
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: "324 mg")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "324 mg matches 324 mg: \(report.flags)")
    }

    /// Spoken long-form unit grounds a short-form claim ("milligrams" grounds "mg").
    func testSpokenUnitLongFormGroundsShortForm() {
        let transcript = "Start ibuprofen 400 milligrams."
        let facts = ClinicalFacts(medications: [Medication(drug: "ibuprofen", dose: "400 mg")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "400 milligrams should ground 400 mg: \(report.flags)")
    }

    /// Policy: a claimed unit with NO unit spoken near the number is allowed (unverifiable, not
    /// a mismatch) — we only reject a CONFLICTING unit, so we don't strip "4 mg" from "gave 4 of morphine".
    func testClaimedUnitWithNoTranscriptUnitIsAllowed() {
        let transcript = "We gave morphine 4 in the field."
        let facts = ClinicalFacts(medications: [Medication(drug: "morphine", dose: "4 mg")])
        let report = GroundingVerifier(transcript: transcript).verify(facts)
        XCTAssertTrue(report.isClean, "no spoken unit → allow the number: \(report.flags)")
    }

    // MARK: - Per-field medication pruning (route / frequency)

    /// A fabricated route is stripped from the medication, but the (grounded) drug survives.
    func testFabricatedRouteIsBlankedNotKept() {
        let transcript = "Give ceftriaxone IV now."
        let facts = ClinicalFacts(medications: [Medication(drug: "ceftriaxone", route: "PO")])
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.drug, "ceftriaxone", "the drug was said; keep it")
        XCTAssertNil(grounded.medications.first?.route, "PO was never said; strip the route")
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedRoute })
    }

    func testGroundedRouteSurvives() {
        let transcript = "Give ceftriaxone IV now."
        let facts = ClinicalFacts(medications: [Medication(drug: "ceftriaxone", route: "IV")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.route, "IV")
    }

    /// A fabricated frequency ("ten times daily") is neither flagged nor removed today — it must be.
    func testFabricatedFrequencyIsBlanked() {
        let transcript = "Start ibuprofen 400 mg."
        let facts = ClinicalFacts(medications: [Medication(drug: "ibuprofen", dose: "400 mg", frequency: "ten times daily")])
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.frequency, "an unsaid frequency must be stripped")
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedFrequency })
    }

    func testGroundedFrequencySurvives() {
        let transcript = "Start ibuprofen 400 mg twice daily."
        let facts = ClinicalFacts(medications: [Medication(drug: "ibuprofen", dose: "400 mg", frequency: "twice daily")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.frequency, "twice daily")
    }

    // MARK: - Comparator laundering (bounded result → exact value)

    /// "troponin less than 0.01" (below assay) must NOT be laundered into an exact "0.01".
    func testBoundedResultNotLaunderedToExactValue() {
        let transcript = "The troponin is less than 0.01."
        let facts = ClinicalFacts(labs: [LabResult(test: "troponin", value: "0.01")])
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertTrue(grounded.labs.isEmpty, "an exact value must not ground against a '<' bound: \(report.flags)")
    }

    // MARK: - Adversarial hardening (found by an adversary attacking v1a)

    /// D1: a route must not ground on a substring of an unrelated word ("iv" inside "give").
    func testRouteNotGroundedBySubstringOfUnrelatedWord() {
        let transcript = "Give aspirin 324 mg PO." // "give" contains "iv"
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: "324 mg", route: "IV")])
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.route, "IV must not ground on the 'iv' inside 'give'")
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedRoute })
    }

    func testRoutePOGroundsAsWholeWord() {
        let transcript = "Give aspirin 324 mg PO now."
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin", dose: "324 mg", route: "PO")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.route, "PO")
    }

    /// D2: a range dose whose unit trails the second number must still be unit-checked.
    func testRangeDoseUnitMismatchIsCaught() {
        let transcript = "Give hydromorphone 1 to 2 mg IV."
        let facts = ClinicalFacts(medications: [Medication(drug: "hydromorphone", dose: "1-2 mcg", route: "IV")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.dose, "1-2 mcg must not ground against '1 to 2 mg'")
    }

    /// D3: Greek small mu (U+03BC) must be recognized as micrograms, not slip past the unit check.
    func testGreekMuMicrogramVsMilligramIsCaught() {
        let transcript = "We gave fentanyl 50 \u{03BC}g IV."
        let facts = ClinicalFacts(medications: [Medication(drug: "fentanyl", dose: "50 mg", route: "IV")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.dose, "50 mg must not ground against 50 μg (greek mu)")
    }

    /// D4: a per-kg/per-min rate must not be laundered into a flat dose (and vice-versa).
    func testDripRateNotLaunderedToFlatDose() {
        let transcript = "Start norepinephrine 0.1 mcg/kg/min."
        let facts = ClinicalFacts(medications: [Medication(drug: "norepinephrine", dose: "0.1 mcg")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.dose, "a per-kg/min rate must not ground a flat mcg dose")
    }

    func testWeightBasedDoseNotLaunderedToAbsolute() {
        let transcript = "Vancomycin 15 mg/kg IV."
        let facts = ClinicalFacts(medications: [Medication(drug: "vancomycin", dose: "15 mg", route: "IV")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.dose, "15 mg/kg must not render as a flat 15 mg")
    }

    /// The correctly-stated rate still grounds — no over-rejection.
    func testDripRateGroundsWhenClaimedWithRate() {
        let transcript = "Start norepinephrine 0.1 mcg/kg/min."
        let facts = ClinicalFacts(medications: [Medication(drug: "norepinephrine", dose: "0.1 mcg/kg/min")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.dose, "0.1 mcg/kg/min")
    }

    /// D5: the "under"/"below" comparator vocabulary must also block laundering a bound to an exact value.
    func testUnderComparatorNotLaundered() {
        for phrase in ["under", "below"] {
            let transcript = "The troponin is \(phrase) 0.01."
            let facts = ClinicalFacts(labs: [LabResult(test: "troponin", value: "0.01")])
            let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
            XCTAssertTrue(grounded.labs.isEmpty, "'\(phrase) 0.01' must not ground exact 0.01")
        }
    }

    /// D6: a fabricated frequency must not ground on an unrelated word ("TID" inside "tidal").
    func testFabricatedFrequencyNotGroundedByUnrelatedWord() {
        let transcript = "Tidal volume was 500 on the vent; give ceftriaxone 1 g IV."
        let facts = ClinicalFacts(medications: [Medication(drug: "ceftriaxone", dose: "1 g", route: "IV", frequency: "TID")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.medications.first?.frequency, "TID must not ground on 'tidal'")
    }

    /// FN1: an abbreviated frequency stated in long form should ground (q4h ↔ "every 4 hours").
    func testAbbreviatedFrequencyGroundsAgainstLongForm() {
        let transcript = "Give ondansetron 4 mg IV every 4 hours."
        let facts = ClinicalFacts(medications: [Medication(drug: "ondansetron", dose: "4 mg", route: "IV", frequency: "q4h")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.medications.first?.frequency, "q4h")
    }

    // MARK: - Category grounding (v1b) — CC/PMH/allergies/diagnosis/differential/disposition

    /// The headline v1b case: a transcript unrelated to the extracted labels yields NOTHING —
    /// no fabricated chief complaint, diagnosis, differential, or disposition.
    func testUnrelatedTranscriptRemovesAllFabricatedLabels() {
        let transcript = "Patient here for a medication refill on their blood pressure pills; feeling well."
        var facts = ClinicalFacts(chiefComplaint: "stroke", diagnosis: "STEMI", disposition: "admit to the ICU")
        facts.pastMedicalHistory = ["end stage renal disease"]
        facts.differential = ["aortic dissection", "pulmonary embolism"]
        let (grounded, report) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertNil(grounded.chiefComplaint)
        XCTAssertNil(grounded.diagnosis)
        XCTAssertNil(grounded.disposition)
        XCTAssertTrue(grounded.pastMedicalHistory.isEmpty)
        XCTAssertTrue(grounded.differential.isEmpty)
        XCTAssertTrue(report.flags.contains { $0.kind == .ungroundedField })
    }

    func testGroundedChiefComplaintAndDiagnosisSurvive() {
        let transcript = "The patient reports crushing chest pain; this looks like a STEMI, activating the cath lab."
        let facts = ClinicalFacts(chiefComplaint: "chest pain", diagnosis: "STEMI")
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertEqual(grounded.chiefComplaint, "chest pain")
        XCTAssertEqual(grounded.diagnosis, "STEMI")
    }

    func testFabricatedAllergyIsRemoved() {
        let transcript = "No mention of allergies here; we discussed the chest pain."
        let facts = ClinicalFacts(allergies: ["penicillin"])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertTrue(grounded.allergies.isEmpty, "a penicillin allergy never stated must be removed")
    }

    // MARK: - NKDA is asserted only when actually stated (v1b)

    func testNKDAAssertedOnlyWhenStated() {
        let stated = GroundingVerifier(transcript: "She has no known drug allergies.").filtered(ClinicalFacts(chiefComplaint: "cough")).facts
        XCTAssertEqual(stated.allergies, ["No known drug allergies"], "an explicit NKDA statement grounds the assertion")

        let silent = GroundingVerifier(transcript: "We talked about her cough.").filtered(ClinicalFacts(chiefComplaint: "cough")).facts
        XCTAssertTrue(silent.allergies.isEmpty, "no allergy discussion → no NKDA assertion (empty, not fabricated)")
    }

    /// NKDA must NOT be asserted when the same transcript also documents a real allergy.
    func testNKDANotAssertedWhenAllergyAlsoPresent() {
        let t = "No allergies listed in the old chart, but she is allergic to sulfa."
        let facts = GroundingVerifier(transcript: t).filtered(ClinicalFacts(chiefComplaint: "rash")).facts
        XCTAssertFalse(facts.allergies.contains("No known drug allergies"), "a contradicting 'allergic to sulfa' must block the NKDA assertion")
    }

    // MARK: - Adversarial hardening round 2 (v1b/v1c) — 2-letter, negation, attribution

    /// A 2-letter diagnosis abbreviation must not get a free pass (it has no content words).
    func testTwoLetterDiagnosisRequiresWholeWordPresence() {
        let unrelated = GroundingVerifier(transcript: "Patient here for a medication refill; feeling well.")
        XCTAssertNil(unrelated.filtered(ClinicalFacts(diagnosis: "PE")).facts.diagnosis, "PE with no support must be removed")
        let stated = GroundingVerifier(transcript: "CT confirms a PE in the right lower lobe.")
        XCTAssertEqual(stated.filtered(ClinicalFacts(diagnosis: "PE")).facts.diagnosis, "PE", "PE stated as a word grounds")
    }

    func testNegatedDiagnosisIsRemoved() {
        let facts = GroundingVerifier(transcript: "We ruled out STEMI on the ECG.").filtered(ClinicalFacts(diagnosis: "STEMI")).facts
        XCTAssertNil(facts.diagnosis, "a ruled-OUT STEMI must not become the diagnosis")
    }

    func testFamilyHistoryNotLaunderedIntoPatientPMH() {
        let facts = GroundingVerifier(transcript: "Her mother had a stroke in her sixties.").filtered({ var f = ClinicalFacts(); f.pastMedicalHistory = ["stroke"]; return f }()).facts
        XCTAssertTrue(facts.pastMedicalHistory.isEmpty, "a family-history stroke must not become the patient's PMH")
    }

    func testHalfOverlapTwoWordDiagnosisIsRemoved() {
        let facts = GroundingVerifier(transcript: "The aortic valve is normal on the echo.").filtered(ClinicalFacts(diagnosis: "aortic dissection")).facts
        XCTAssertNil(facts.diagnosis, "one incidental word ('aortic') must not ground 'aortic dissection'")
    }

    // MARK: - Negated / allergen / discontinued drugs (shared root cause)

    func testNegatedDrugIsNotGrounded() {
        let transcript = "We are stopping his aspirin today; he is allergic to penicillin."
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin"), Medication(drug: "penicillin")])
        let (grounded, _) = GroundingVerifier(transcript: transcript).filtered(facts)
        XCTAssertTrue(grounded.medications.isEmpty, "a discontinued drug and an allergen must not be recorded as active meds")
    }

    func testDrugNameSubstringOfAWordIsNotGrounded() {
        let facts = ClinicalFacts(medications: [Medication(drug: "iron")])
        let (grounded, _) = GroundingVerifier(transcript: "Treated in a controlled environment.").filtered(facts)
        XCTAssertTrue(grounded.medications.isEmpty, "'iron' must not ground on 'environment'")
    }

    func testAffirmativelyGivenDrugStillGrounds() {
        let facts = ClinicalFacts(medications: [Medication(drug: "aspirin")])
        let (grounded, _) = GroundingVerifier(transcript: "We gave him aspirin in triage.").filtered(facts)
        XCTAssertEqual(grounded.medications.first?.drug, "aspirin")
    }
}
