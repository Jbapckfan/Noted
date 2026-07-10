import XCTest
@testable import NotedCoreKit

final class NoteTemplateTests: XCTestCase {

    func testRenderIsDeterministicAndContainsFacts() {
        let facts = ClinicalFacts(
            chiefComplaint: "chest pain",
            hpi: "57M with 2 hours of substernal chest pressure.",
            medications: [Medication(drug: "aspirin", dose: "324 mg", route: "PO", frequency: "once")],
            labs: [LabResult(test: "troponin", value: "0.04", unit: "ng/mL")],
            diagnosis: "STEMI",
            differential: ["ACS", "PE", "aortic dissection"]
        )
        let a = NoteTemplate.renderHPIandMDM(facts)
        let b = NoteTemplate.renderHPIandMDM(facts)
        XCTAssertEqual(a, b, "same facts must render identically")
        XCTAssertTrue(a.contains("CHIEF COMPLAINT: chest pain"))
        XCTAssertTrue(a.contains("aspirin 324 mg PO once"))
        XCTAssertTrue(a.contains("troponin: 0.04 ng/mL"))
        XCTAssertTrue(a.contains("Diagnosis: STEMI"))
        XCTAssertTrue(a.contains("ACS, PE, aortic dissection"))
    }

    func testEmptyFactsRenderEmpty() {
        XCTAssertEqual(NoteTemplate.renderHPIandMDM(ClinicalFacts()), "")
    }
}

final class ClinicalFactsTests: XCTestCase {

    func testParsesSnakeCaseExtractionJSON() throws {
        let json = """
        {
          "chief_complaint": "chest pain",
          "medications": [{"drug":"aspirin","dose":"324 mg","route":"PO","frequency":"once"}],
          "labs": [{"test":"potassium","value":"3.2","unit":"mEq/L"}],
          "return_precautions": ["return for worsening chest pain"]
        }
        """
        let facts = try ClinicalFacts.parse(json)
        XCTAssertEqual(facts.chiefComplaint, "chest pain")
        XCTAssertEqual(facts.medications.first?.drug, "aspirin")
        XCTAssertEqual(facts.medications.first?.dose, "324 mg")
        XCTAssertEqual(facts.labs.first?.value, "3.2")
        XCTAssertEqual(facts.returnPrecautions, ["return for worsening chest pain"])
    }

    func testLenientWithMissingFields() throws {
        let facts = try ClinicalFacts.parse("{}")
        XCTAssertNil(facts.chiefComplaint)
        XCTAssertTrue(facts.medications.isEmpty)
        XCTAssertTrue(facts.labs.isEmpty)
        XCTAssertTrue(facts.returnPrecautions.isEmpty)
    }

    /// A small base model drifts from the schema — "" / "none" for empty lists, a bare string for a
    /// single item. Parsing must tolerate all of it rather than throw (found by the real-LLM eval).
    func testTolerantOfSmallModelSchemaDrift() throws {
        let json = #"{"chief_complaint":"chest pain","allergies":"","past_medical_history":"none","medications":"none","differential":["ACS"],"return_precautions":"return if worse"}"#
        let f = try ClinicalFacts.parse(json)
        XCTAssertEqual(f.chiefComplaint, "chest pain")
        XCTAssertTrue(f.allergies.isEmpty)
        XCTAssertTrue(f.pastMedicalHistory.isEmpty)
        XCTAssertTrue(f.medications.isEmpty)
        XCTAssertEqual(f.differential, ["ACS"])
        XCTAssertEqual(f.returnPrecautions, ["return if worse"])
    }

    func testRoundTripsToExtractionJSONAndVerifies() throws {
        // The end-to-end contract: extractionJSON string -> facts -> verify against transcript.
        let transcript = "Gave aspirin 324 mg. Potassium 3.2."
        let json = #"{"medications":[{"drug":"aspirin","dose":"324 mg"}],"labs":[{"test":"potassium","value":"3.2"}]}"#
        let facts = try ClinicalFacts.parse(json)
        XCTAssertTrue(GroundingVerifier(transcript: transcript).verify(facts).isClean)
    }
}
