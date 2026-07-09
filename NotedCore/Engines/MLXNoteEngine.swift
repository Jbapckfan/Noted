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

#if canImport(MLX)
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

    private let modelPath: String                        // local bundled 4-bit model directory
    private let adapterPaths: [GenerationJobKind: String] // per-stage LoRA adapters (PR5/PR9)
    private let minFreeBytesToLoad: UInt64
    private var container: ModelContainer?

    public init(
        modelPath: String,
        adapterPaths: [GenerationJobKind: String] = [:],
        minFreeMBToLoad: UInt64 = 900
    ) {
        self.modelPath = modelPath
        self.adapterPaths = adapterPaths
        self.minFreeBytesToLoad = minFreeMBToLoad * 1_000_000
    }

    // MARK: NoteEngine

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        switch input.kind {
        case .transcribe:
            throw EngineError.unsupportedKind(.transcribe) // routed to WhisperTranscriber
        case .extract, .note, .dischargeExtract, .dischargeRender:
            break
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
            throw EngineError.insufficientMemory(freeMB: UInt64(free) / 1_000_000)
        }
        MLX.GPU.set(cacheLimit: 256 * 1024 * 1024) // bound Metal cache; Metal is unavailable in sim
        #endif

        container = try await LLMModelFactory.shared.loadContainer(
            configuration: MLXLMCommon.ModelConfiguration(id: modelPath)
        )
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
            Extract the clinical facts from this emergency department transcript as JSON \
            (chief_complaint, hpi, pmh, meds, allergies, exam, differential). Quote all numbers \
            verbatim; never invent values.

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
