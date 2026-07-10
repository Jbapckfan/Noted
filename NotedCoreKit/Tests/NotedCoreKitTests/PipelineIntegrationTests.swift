import XCTest
import SwiftData
@testable import NotedCoreKit

/// A stub engine that returns caller-supplied JSON for the extraction stages, so a test can drive
/// the DETERMINISTIC note/discharge stages (template + verifier) with known facts.
private struct StubEngine: NoteEngine {
    var extraction: String? = nil
    var discharge: String? = nil
    func run(_ input: GenerationInput) async throws -> GenerationOutput {
        var out = GenerationOutput()
        switch input.kind {
        case .extract: out.extractionJSON = extraction
        case .dischargeExtract: out.dischargeJSON = discharge
        default: break
        }
        return out
    }
}

final class PipelineIntegrationTests: XCTestCase {

    private func tempStore() throws -> ModelContainer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("store.sqlite")
        return try EncounterStore.makeContainer(at: url)
    }

    /// The note stage renders deterministically from the extracted facts AND runs the grounding
    /// verifier: an extracted med that isn't in the transcript is flagged in the report.
    func testNoteStageRendersDeterministicallyAndFlagsUngroundedMed() async throws {
        let container = try tempStore()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "chest pain", phase: .transcribed)
        e.transcript = "Doctor: I'm going to give you some aspirin to chew."
        ctx.insert(e)
        // Extraction claims aspirin (grounded) AND morphine 4 mg (NOT in the transcript).
        let extraction = #"{"chief_complaint":"chest pain","medications":[{"drug":"aspirin"},{"drug":"morphine","dose":"4 mg"}]}"#
        try GenerationQueue.enqueue(.extract, for: e, in: ctx)

        let worker = GenerationWorker(container: container, engine: StubEngine(extraction: extraction))
        _ = await worker.drain()

        let reloaded = try ModelContext(container).fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.phase, .noteDrafted)
        let note = try XCTUnwrap(reloaded?.noteText)
        XCTAssertTrue(note.contains("aspirin"), "deterministic template rendered the med")
        let report = try XCTUnwrap(reloaded?.verificationReport)
        XCTAssertTrue(report.contains("ungroundedMedication"), "morphine (not in transcript) flagged: \(report)")
    }

    /// A manual-test encounter keeps its source, and a freshly generated note clears the
    /// "edited after grounding" flag (the grounding check applies to the new draft).
    func testManualTestNoteGenerationClearsEditedFlag() async throws {
        let container = try tempStore()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "chest pain", phase: .transcribed, source: .manualTest)
        e.transcript = "Doctor: I'm going to give you some aspirin to chew."
        e.noteEditedAfterGrounding = true   // pretend a prior draft was hand-edited
        ctx.insert(e)
        try GenerationQueue.enqueue(.extract, for: e, in: ctx)

        let extraction = #"{"chief_complaint":"chest pain","medications":[{"drug":"aspirin"}]}"#
        let worker = GenerationWorker(container: container, engine: StubEngine(extraction: extraction))
        _ = await worker.drain()

        let reloaded = try ModelContext(container).fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.source, .manualTest, "source persists")
        XCTAssertNotNil(reloaded?.noteText)
        XCTAssertEqual(reloaded?.noteEditedAfterGrounding, false, "a freshly generated draft is unedited since grounding")
    }

    /// The discharge-render stage produces BOTH renderings from the verified discharge JSON, and
    /// the patient version expands abbreviations.
    func testDischargeRenderStageProducesBothRenderings() async throws {
        let container = try tempStore()
        let ctx = ModelContext(container)
        let e = Encounter(chiefComplaint: "chest pain", phase: .dispositionCaptured)
        // The transcript is the grounding source (not the raw extraction). It must contain what the
        // discharge copies: metoprolol and its dose/route/frequency.
        e.transcript = "We're sending you home on metoprolol 25 mg by mouth twice a day, follow up with cardiology in a week. Your troponin was negative."
        e.resultsTrayJSON = #"{"labs":[{"test":"troponin","value":"0.02"}]}"#
        e.dispositionTranscript = "Home on metoprolol 25 mg by mouth twice a day, follow up with cardiology."
        ctx.insert(e)
        // return_precautions uses a real library entry (free-text precautions are gated out); it
        // also carries a FABRICATED extra precaution that must be removed.
        let discharge = #"""
        {"final_diagnosis":"chest pain, low risk","brief_clinical_course":"resolved","follow_up":[{"who":"cardiology"}],"return_precautions":["Return to the emergency department or call 911 if your symptoms get worse.","Return for sudden loss of vision in one eye."],"medications_prescribed":[{"drug":"metoprolol","dose":"25 mg","route":"PO","frequency":"BID"}]}
        """#
        try GenerationQueue.enqueue(.dischargeExtract, for: e, in: ctx)

        let worker = GenerationWorker(container: container, engine: StubEngine(discharge: discharge))
        _ = await worker.drain()

        let reloaded = try ModelContext(container).fetch(FetchDescriptor<Encounter>()).first
        XCTAssertEqual(reloaded?.phase, .dischargeDrafted)
        XCTAssertTrue(reloaded?.dischargeClinicianText?.contains("metoprolol 25 mg PO BID") == true)
        let patient = try XCTUnwrap(reloaded?.dischargePatientText)
        XCTAssertTrue(patient.contains("by mouth"), "PO expanded for the patient version")
        XCTAssertTrue(patient.contains("emergency department"), "the library precaution flowed through the gate")
        XCTAssertFalse(patient.contains("vision in one eye"), "the fabricated (non-library) precaution was gated out")
    }
}
