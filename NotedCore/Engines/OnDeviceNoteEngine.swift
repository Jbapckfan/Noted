//  OnDeviceNoteEngine.swift
//  Composes the two real engines into one NoteEngine so PR3's serial GenerationWorker runs
//  unchanged: `.transcribe` goes to Apple Speech (on-device); the generative stages go to MLX.
//  Plus the factory that selects the deterministic MockNoteEngine in the simulator (or when no
//  model is bundled) and the real stack on device.

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

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        switch input.kind {
        case .transcribe:
            return try await transcriber.run(input)
        case .extract, .note, .dischargeExtract, .dischargeRender:
            return try await mlx.run(input)
        }
    }
}
#endif

/// Picks the engine for the current build: the GPU-free mock in the simulator (so the full
/// pipeline runs and is demoable without Metal), the real MLX + Apple Speech stack on device when
/// a model is actually bundled, and the mock otherwise (never crashes on a missing model).
public enum NoteEngineFactory {
    public static func make(audioDirectory: URL, modelPath: String) -> NoteEngine {
        #if targetEnvironment(simulator)
        return MockNoteEngine()
        #elseif canImport(MLXLLM)
        if !modelPath.isEmpty && FileManager.default.fileExists(atPath: modelPath) {
            return OnDeviceNoteEngine(
                transcriber: SpeechTranscriber(audioDirectory: audioDirectory),
                mlx: MLXNoteEngine(modelPath: modelPath)
            )
        }
        return MockNoteEngine()
        #else
        // mlx-swift-examples (MLXLLM/MLXLMCommon) not linked yet — deterministic mock until then.
        return MockNoteEngine()
        #endif
    }
}
