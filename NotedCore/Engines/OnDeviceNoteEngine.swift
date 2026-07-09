//  OnDeviceNoteEngine.swift
//  Composes the two real engines into one NoteEngine so PR3's serial GenerationWorker runs
//  unchanged: `.transcribe` goes to WhisperKit (ANE/CPU); the generative stages go to MLX (GPU).
//  Plus the factory seam that selects the deterministic MockNoteEngine in the simulator and the
//  real stack on device — this is what finally lets the whole app run in the simulator (PR3's payoff).
//
//  NOTE on overlap: routing transcription through the same worker keeps things simple and correct;
//  it does serialize transcribe with generation. The important overlap (capture of N+1 via
//  CaptureController while N generates) already holds. A dedicated ANE TranscriptionWorker for
//  transcribe∥generate is a later optimization (PR7 governance), not needed for v1 correctness.

import Foundation
import NotedCoreKit

#if canImport(MLX) && canImport(WhisperKit)
public struct OnDeviceNoteEngine: NoteEngine {
    let transcriber: WhisperTranscriber
    let mlx: MLXNoteEngine

    public init(transcriber: WhisperTranscriber, mlx: MLXNoteEngine) {
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
/// pipeline runs and is demoable without Metal), the real MLX + WhisperKit stack on device.
public enum NoteEngineFactory {
    public static func make(audioDirectory: URL, modelPath: String) -> NoteEngine {
        #if targetEnvironment(simulator)
        return MockNoteEngine()
        #else
        return OnDeviceNoteEngine(
            transcriber: WhisperTranscriber(audioDirectory: audioDirectory),
            mlx: MLXNoteEngine(modelPath: modelPath)
        )
        #endif
    }
}
