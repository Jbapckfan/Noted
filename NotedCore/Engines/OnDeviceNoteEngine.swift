//  OnDeviceNoteEngine.swift
//  Composes the two real engines so PR3's serial GenerationWorker runs unchanged: `.transcribe`
//  goes to Apple Speech (on-device); the generative stages go to MLX. If the model isn't available
//  (still downloading is awaited; a genuine failure falls back to transcript-only) it NEVER
//  fabricates a note. Plus the factory that selects mock (simulator) vs the real stack (device).

import Foundation
import NotedCoreKit

#if canImport(MLXLLM)
public struct OnDeviceNoteEngine: NoteEngine {
    let transcriber: SpeechTranscriber
    let mlx: MLXNoteEngine

    public init(transcriber: SpeechTranscriber, mlx: MLXNoteEngine) {
        self.transcriber = transcriber
        self.mlx = mlx
    }

    /// Start the model download/load early (on launch) so the first note isn't blocked.
    public func warmup() async { await mlx.warmup() }

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        switch input.kind {
        case .transcribe:
            // Always real, on-device transcription of what was actually said.
            return try await transcriber.run(input)

        case .extract, .dischargeExtract:
            do {
                // Blocks (awaited) while the model is still downloading; produces real facts once ready.
                return try await mlx.run(input)
            } catch {
                // Model genuinely unavailable (offline first-run / load error): DO NOT fabricate —
                // fall back to a transcript-only extraction so the encounter shows the real words.
                if input.kind == .extract {
                    return Self.transcriptOnlyExtraction(input)
                }
                throw error
            }

        case .note, .dischargeRender:
            return GenerationOutput() // deterministic in the worker
        }
    }

    /// A safe, non-fabricated extraction: the note becomes the real transcript under a loud header.
    static func transcriptOnlyExtraction(_ input: GenerationInput) -> GenerationOutput {
        let transcript = (input.transcript ?? "")
            .replacingOccurrences(of: "\\", with: " ")
            .replacingOccurrences(of: "\"", with: "'")
        var out = GenerationOutput()
        out.extractionJSON = """
        {"chief_complaint":"AI MODEL UNAVAILABLE — raw transcript only, NOT a clinical note",\
        "hpi":"\(transcript)"}
        """
        return out
    }
}
#endif

public enum NoteEngineFactory {
    /// The default on-device base model — downloaded on first run, cached, then LoRA-adapted.
    /// Phone-safe 3B; swap for a 7B once benchmarked on device.
    public static let defaultModelID = "mlx-community/Llama-3.2-3B-Instruct-4bit"

    public static func make(audioDirectory: URL, modelId: String = defaultModelID) -> NoteEngine {
        #if targetEnvironment(simulator)
        return MockNoteEngine()
        #elseif canImport(MLXLLM) && canImport(Speech)
        return OnDeviceNoteEngine(
            transcriber: SpeechTranscriber(audioDirectory: audioDirectory),
            mlx: MLXNoteEngine(modelId: modelId)
        )
        #elseif canImport(Speech)
        return TranscribeOnlyEngine(transcriber: SpeechTranscriber(audioDirectory: audioDirectory))
        #else
        return MockNoteEngine()
        #endif
    }
}
