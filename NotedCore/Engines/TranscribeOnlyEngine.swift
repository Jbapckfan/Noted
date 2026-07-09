//  TranscribeOnlyEngine.swift
//  DEVICE fallback when NO on-device AI model is installed. It does REAL speech-to-text (Apple
//  Speech) so you see your actual words — but it NEVER fabricates a clinical note. The "note" is an
//  explicit placeholder containing only the real transcript, clearly marked as not a clinical note.
//
//  This exists specifically so the app can never show realistic-but-fake clinical content on a real
//  device. Real notes require a bundled model (OnDeviceNoteEngine).

import Foundation
import NotedCoreKit

#if canImport(Speech)
public struct TranscribeOnlyEngine: NoteEngine {
    let transcriber: SpeechTranscriber

    public init(transcriber: SpeechTranscriber) {
        self.transcriber = transcriber
    }

    public func run(_ input: GenerationInput) async throws -> GenerationOutput {
        switch input.kind {
        case .transcribe:
            // Real on-device transcription of what was actually said.
            return try await transcriber.run(input)

        case .extract:
            // Do NOT extract or invent facts. Emit a note that is unmistakably a placeholder and
            // contains only the real transcript. (The .note stage renders this deterministically.)
            let transcript = (input.transcript ?? "")
                .replacingOccurrences(of: "\\", with: " ")
                .replacingOccurrences(of: "\"", with: "'")
            var out = GenerationOutput()
            out.extractionJSON = """
            {"chief_complaint":"NO AI MODEL INSTALLED — raw transcript only, NOT a clinical note",\
            "hpi":"\(transcript)"}
            """
            return out

        case .note, .dischargeExtract, .dischargeRender:
            // Nothing generated without a model.
            return GenerationOutput()
        }
    }
}
#endif
