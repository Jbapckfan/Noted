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
            // A self-consistent demo encounter so the whole offline pipeline produces a full,
            // grounded note in the simulator (the real MLX engine replaces this on device).
            out.transcript = """
            Doctor: What brings you in today?
            Patient: I've had chest pain for about two hours. It's a pressure, right in the middle, \
            and it goes into my left arm. I feel a little short of breath and sweaty.
            Doctor: Any history of heart problems? Blood pressure, cholesterol?
            Patient: I have high blood pressure and high cholesterol.
            Doctor: Your blood pressure is 148 over 92, heart rate 96, and your oxygen is 98% on room air. \
            I'm going to give you aspirin 324 milligrams to chew now. Your first troponin came back at 0.02.
            Doctor: I'm going to keep you for observation and have cardiology see you.
            """

        case .extract:
            out.extractionJSON = """
            {"chief_complaint":"Chest pain","hpi":"Patient reports two hours of substernal chest \
            pressure radiating to the left arm, with mild shortness of breath and diaphoresis.",\
            "review_of_systems":"Positive for chest pain, shortness of breath, and diaphoresis.",\
            "past_medical_history":["hypertension","high cholesterol"],"allergies":[],\
            "medications":[{"drug":"aspirin","dose":"324 milligrams","route":"chew","frequency":"now"}],\
            "vitals":[{"name":"blood pressure","value":"148 over 92"},{"name":"heart rate","value":"96"},\
            {"name":"oxygen","value":"98% on room air"}],\
            "physical_exam":"","labs":[{"test":"troponin","value":"0.02","unit":""}],\
            "mdm":"Acute coronary syndrome considered given exertional chest pressure with radiation; \
            initial troponin negative. Aspirin given; serial troponins and cardiology consultation planned.",\
            "diagnosis":"Chest pain, rule out acute coronary syndrome",\
            "differential":["ACS","pulmonary embolism","aortic dissection","GERD"],\
            "disposition":"Observation with serial troponins and cardiology evaluation",\
            "return_precautions":[]}
            """

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
