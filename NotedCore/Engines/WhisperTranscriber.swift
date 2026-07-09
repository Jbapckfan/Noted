//  WhisperTranscriber.swift
//  The transcription half of the on-device engine (PR4): WhisperKit on the ANE/CPU, so it can run
//  independently of the GPU note generation. Conforms to NotedCoreKit.NoteEngine and handles only
//  the `.transcribe` stage; OnDeviceNoteEngine composes it with MLXNoteEngine.
//
//  DEVICE-ONLY. Not compiled/tested on macOS. The WhisperKit API here matches NotedCore's existing
//  FixedWhisperService (same pinned WhisperKit revision, 3a38043). Verify on device: model loads,
//  a captured WAV transcribes to text. Reads the per-encounter WAV that CaptureController wrote.

import Foundation
import NotedCoreKit

#if canImport(WhisperKit)
import WhisperKit

public actor WhisperTranscriber: NoteEngine {

    public enum TranscriberError: Error {
        case unsupportedKind(GenerationJobKind)
        case missingAudio
        case notReady
    }

    private let audioDirectory: URL
    private let modelName: String
    private let modelRepo: String
    private var whisper: WhisperKit?

    public init(
        audioDirectory: URL,
        modelName: String = "openai_whisper-base.en",
        modelRepo: String = "argmaxinc/whisperkit-coreml"
    ) {
        self.audioDirectory = audioDirectory
        self.modelName = modelName
        self.modelRepo = modelRepo
    }

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        guard input.kind == .transcribe else { throw TranscriberError.unsupportedKind(input.kind) }
        guard let relPath = input.audioFileRelPath else { throw TranscriberError.missingAudio }

        let url = audioDirectory.appendingPathComponent(relPath)
        let whisper = try await ensureLoaded()

        let options = DecodingOptions(
            language: "en",
            temperature: 0.0,
            temperatureFallbackCount: 0,
            skipSpecialTokens: true,
            withoutTimestamps: true
        )
        let results = try await whisper.transcribe(audioPath: url.path, decodeOptions: options)
        let text = results
            .map { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var out = GenerationOutput()
        out.transcript = text
        return out
    }

    private func ensureLoaded() async throws -> WhisperKit {
        if let whisper { return whisper }
        let w = try await WhisperKit(
            model: modelName,
            modelRepo: modelRepo,
            verbose: false,
            logLevel: .error,
            prewarm: true,
            load: true,
            download: true
        )
        whisper = w
        return w
    }

    public func unload() {
        whisper = nil
    }
}
#endif
