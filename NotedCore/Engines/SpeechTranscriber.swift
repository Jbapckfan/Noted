//  SpeechTranscriber.swift
//  On-device transcription via Apple's Speech framework (SFSpeechRecognizer). Chosen over
//  WhisperKit so the app can link the real MLX LLM runner (mlx-swift-examples requires
//  swift-transformers 1.3+, which conflicts with WhisperKit's 0.1.x). Zero memory/dependency cost,
//  fully offline (requiresOnDeviceRecognition). Transcribes the per-encounter WAV that
//  CaptureController wrote. Conforms to NotedCoreKit.NoteEngine; handles only `.transcribe`.
//
//  Requires `NSSpeechRecognitionUsageDescription` in Info.plist. DEVICE-ONLY behaviour; verify
//  on-device recognition + authorization on hardware. STT roughness on drug names is low-stakes:
//  the GroundingVerifier catches any fabrication downstream, and the physician reviews every note.

import Foundation
import NotedCoreKit

#if canImport(Speech)
import Speech

public actor SpeechTranscriber: NoteEngine {

    public enum TranscriberError: Error {
        case unsupportedKind(GenerationJobKind)
        case missingAudio
        case notAuthorized
        case recognizerUnavailable
        case noTranscription
    }

    private let audioDirectory: URL
    private let localeIdentifier: String

    public init(audioDirectory: URL, localeIdentifier: String = "en-US") {
        self.audioDirectory = audioDirectory
        self.localeIdentifier = localeIdentifier
    }

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        guard input.kind == .transcribe else { throw TranscriberError.unsupportedKind(input.kind) }
        guard let relPath = input.audioFileRelPath else { throw TranscriberError.missingAudio }

        try await ensureAuthorized()
        let url = audioDirectory.appendingPathComponent(relPath)
        let text = try await transcribeFile(at: url)

        var out = GenerationOutput()
        out.transcript = text
        return out
    }

    private func ensureAuthorized() async throws {
        if SFSpeechRecognizer.authorizationStatus() == .authorized { return }
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else { throw TranscriberError.notAuthorized }
    }

    private func transcribeFile(at url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
              recognizer.isAvailable else {
            throw TranscriberError.recognizerUnavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        return try await withCheckedThrowingContinuation { cont in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !resumed else { return }
                if let error {
                    resumed = true
                    cont.resume(throwing: error)
                    return
                }
                if let result, result.isFinal {
                    resumed = true
                    cont.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
#endif
