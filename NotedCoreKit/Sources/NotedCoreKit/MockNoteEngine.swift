import Foundation

/// A deterministic, GPU-free `NoteEngine` for the simulator and the test suite.
///
/// This is the piece that lets the ENTIRE pipeline (capture → queue → generate → persist) run
/// and be verified without MLX or a Metal GPU. Each stage returns a stable, transcript-grounded
/// placeholder so the flow, phase transitions, and persistence can be exercised end-to-end. The
/// app selects it under `#if targetEnvironment(simulator)`; the real MLX engine (PR4) ships on device.
///
/// An optional `perCallDelay` widens the execution window so concurrency tests can catch any
/// accidental parallelism (the worker must be strictly serial).
public struct MockNoteEngine: NoteEngine {
    public var perCallDelay: Duration?

    public init(perCallDelay: Duration? = nil) {
        self.perCallDelay = perCallDelay
    }

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        if let perCallDelay {
            try? await Task.sleep(for: perCallDelay)
        }

        var out = GenerationOutput()
        let short = input.encounterID.uuidString.prefix(8)

        switch input.kind {
        case .transcribe:
            out.transcript = "[mock transcript for encounter \(short) from \(input.audioFileRelPath ?? "audio")]"

        case .extract:
            let src = (input.transcript ?? "").replacingOccurrences(of: "\"", with: "'")
            out.extractionJSON = #"{"chief_complaint":"mock","source_len":\#(src.count)}"#

        case .note:
            out.noteText = """
            MOCK NOTE — encounter \(short)
            HPI: generated from extraction \(input.extractionJSON ?? "{}")
            (deterministic placeholder; real note comes from the MLX engine)
            """
            out.verificationReport = #"{"grounded":true,"flagged_spans":[]}"#

        case .dischargeExtract:
            out.dischargeJSON = #"{"final_diagnosis":"mock","meds":[]}"#

        case .dischargeRender:
            out.dischargeClinicianText = "MOCK discharge (clinician) for \(short)"
            out.dischargePatientText = "MOCK discharge (patient) for \(short)"
        }
        return out
    }
}
