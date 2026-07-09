//  MLXNoteEngine.swift
//  The real on-device generation engine (PR4). Conforms to NotedCoreKit.NoteEngine so it drops
//  straight into the serial GenerationWorker verified in PR3. Handles the GPU stages
//  (extract / note / discharge*). Transcription is WhisperTranscriber; the two are composed by
//  OnDeviceNoteEngine.
//
//  DEVICE-ONLY. MLX needs a Metal GPU, so this is neither compiled nor unit-tested on macOS /
//  in the package suite. The MLX API here is grafted from EDScribePro/MLXRunner.swift (a working
//  runner on the same mlx-swift pin). Verify on device: model loads from the bundled 4-bit dir,
//  generation streams, memory gating fires under pressure. The *pipeline logic* it plugs into
//  (queue, serial drain, retry, crash recovery) is already covered by NotedCoreKit's tests.
//
//  Requires the `com.apple.developer.kernel.increased-memory-limit` entitlement (owner step) so
//  the ~2 GB 4-bit model fits inside the jetsam budget.

import Foundation
import NotedCoreKit

// Requires MLXLLM/MLXLMCommon from the `mlx-swift-examples` package. When it isn't linked (e.g. a
// simulator build that only needs the mock engine), this whole file compiles out and the factory
// falls back to MockNoteEngine.
#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon

public actor MLXNoteEngine: NoteEngine {

    public enum EngineError: Error {
        case unsupportedKind(GenerationJobKind)
        case insufficientMemory(freeMB: UInt64)
        case notLoaded
        case emptyGeneration
    }

    private let modelId: String                          // HuggingFace repo id OR a local model dir
    private let adapterPaths: [GenerationJobKind: String] // per-stage LoRA adapters (PR5/PR9)
    private let minFreeBytesToLoad: UInt64
    private var container: ModelContainer?

    public init(
        modelId: String,
        adapterPaths: [GenerationJobKind: String] = [:],
        minFreeMBToLoad: UInt64 = 900
    ) {
        self.modelId = modelId
        self.adapterPaths = adapterPaths
        self.minFreeBytesToLoad = minFreeMBToLoad * 1_000_000
    }

    /// Kick the model load/download early (call on launch) so the first note isn't blocked on the
    /// ~1.8 GB first-run download. Progress is reported via ModelHost.
    public func warmup() async {
        try? await ensureLoaded()
    }

    // MARK: NoteEngine

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        switch input.kind {
        case .extract, .dischargeExtract:
            break // model stages — the LLM extracts structured facts
        case .transcribe:
            throw EngineError.unsupportedKind(.transcribe)   // -> WhisperTranscriber
        case .note, .dischargeRender:
            // DETERMINISTIC stages — the GenerationWorker renders these from extracted facts via
            // NoteTemplate / DischargeRenderer and never calls the model for them.
            throw EngineError.unsupportedKind(input.kind)
        }

        try await ensureLoaded()
        let prompt = Self.prompt(for: input)
        let text = try await generate(prompt: prompt, maxTokens: Self.maxTokens(for: input.kind))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EngineError.emptyGeneration
        }
        return Self.output(kind: input.kind, text: text)
    }

    // MARK: Model lifecycle

    private func ensureLoaded() async throws {
        if container != nil { return }

        // Memory gate: don't attempt to load if we're already near the jetsam limit.
        #if !targetEnvironment(simulator)
        let free = os_proc_available_memory()
        if free > 0 && UInt64(free) < minFreeBytesToLoad {
            let mb = UInt64(free) / 1_000_000
            await MainActor.run { ModelHost.shared.update(.failed("low memory (\(mb) MB free)")) }
            throw EngineError.insufficientMemory(freeMB: mb)
        }
        MLX.GPU.set(cacheLimit: 256 * 1024 * 1024) // bound Metal cache; Metal is unavailable in sim
        #endif

        await MainActor.run { ModelHost.shared.update(.downloading(0)) }
        do {
            // ModelConfiguration(id:) accepts a HuggingFace repo id — first run downloads (~1.8 GB)
            // and caches it; later runs load from cache. Progress drives the UI banner.
            container = try await LLMModelFactory.shared.loadContainer(
                configuration: MLXLMCommon.ModelConfiguration(id: modelId)
            ) { progress in
                Task { @MainActor in ModelHost.shared.update(.downloading(progress.fractionCompleted)) }
            }
            await MainActor.run { ModelHost.shared.update(.ready) }
        } catch {
            await MainActor.run { ModelHost.shared.update(.failed(error.localizedDescription)) }
            throw error
        }
        // LoRA fusion per stage is wired in PR5/PR9; base model runs the constrained schema until then.
    }

    /// Release the model under memory pressure (called by the governor in PR7). Dropping the
    /// container releases its weights; matches EDScribePro/MLXRunner.unloadModel().
    public func unload() {
        container = nil
    }

    // MARK: Generation

    private func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard let container else { throw EngineError.notLoaded }
        var full = ""
        try await container.perform { context in
            let lmInput = try await context.processor.prepare(input: .init(prompt: prompt))
            let stream = try MLXLMCommon.generate(
                input: lmInput,
                parameters: GenerateParameters(maxTokens: maxTokens, temperature: 0.3, topP: 0.9),
                context: context
            )
            for try await generation in stream {
                if let chunk = generation.chunk { full += chunk }
            }
        }
        return full
    }

    // MARK: Prompts (minimal; PR5 replaces these with constrained/grammar decoding)

    private static func maxTokens(for kind: GenerationJobKind) -> Int {
        switch kind {
        case .extract, .dischargeExtract: return 768
        case .note, .dischargeRender:     return 1200
        case .transcribe:                 return 0
        }
    }

    private static func prompt(for input: GenerationInput) -> String {
        switch input.kind {
        case .extract:
            return """
            You are an emergency medicine scribe. Extract the clinical facts from this ED \
            transcript as a single JSON object with EXACTLY these keys:
            {"chief_complaint": string, "hpi": string, "review_of_systems": string,
             "past_medical_history": [string], "allergies": [string],
             "medications": [{"drug","dose","route","frequency"}],
             "vitals": [{"name","value"}], "physical_exam": string,
             "labs": [{"test","value","unit"}], "mdm": string, "diagnosis": string,
             "differential": [string], "disposition": string, "return_precautions": [string]}

            Rules: quote every number, dose, and result VERBATIM as spoken; never invent a value, a \
            medication, a dose, or a result. Omit anything not stated. The HPI must be a fluent \
            narrative in complete sentences; the MDM must state the reasoning and what was ruled out.

            Transcript:
            \(input.transcript ?? "")
            """
        case .note:
            return """
            Write a concise emergency department HPI and MDM note from these extracted facts. \
            Use only facts present below; do not add findings.

            Facts (JSON):
            \(input.extractionJSON ?? "{}")
            """
        case .dischargeExtract:
            return """
            From the HPI facts, the results tray, and the disposition dictation, produce the \
            discharge JSON (final_diagnosis, brief_clinical_course, results_explained, \
            treatments_given_in_ED, medications_prescribed, follow_up, return_precautions). \
            Copy drugs/doses/results verbatim.

            HPI facts: \(input.extractionJSON ?? "{}")
            Results: \(input.resultsTrayJSON ?? "{}")
            Disposition: \(input.dispositionTranscript ?? "")
            """
        case .dischargeRender:
            return """
            Render the discharge summary in a clinical register from this discharge JSON, \
            preserving every drug, dose, and result value exactly.

            Discharge JSON:
            \(input.extractionJSON ?? "{}")
            """
        case .transcribe:
            return ""
        }
    }

    private static func output(kind: GenerationJobKind, text: String) -> GenerationOutput {
        var out = GenerationOutput()
        switch kind {
        case .extract:          out.extractionJSON = text
        case .note:             out.noteText = text
        case .dischargeExtract: out.dischargeJSON = text
        case .dischargeRender:  out.dischargeClinicianText = text
        case .transcribe:       break
        }
        return out
    }
}
#endif
