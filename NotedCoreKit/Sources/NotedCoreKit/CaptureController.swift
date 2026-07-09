import Foundation

/// The result of one finished recording. `audioFileRelPath` is RELATIVE to the capture
/// directory (never absolute — absolute paths break when the app container is relocated on
/// restore/reinstall). This is what an `Encounter.audioFileRelPath` is set to.
public struct RecordingResult: Equatable, Sendable {
    public let encounterID: UUID
    public let audioFileRelPath: String
    public let duration: TimeInterval
    public let byteCount: Int
}

/// The single owner of the microphone and the current recording file.
///
/// Replaces the app's six competing `AVAudioEngine` owners with one actor: exactly one
/// recording is active at a time, each encounter's audio streams to its own file, and
/// "stop this patient, start the next" is one call (`endAndBegin`) — the flow that makes
/// seeing three patients in a row before returning to the computer actually work.
public actor CaptureController {

    public enum CaptureError: Error, Equatable {
        case alreadyRecording(UUID)
        case notRecording
    }

    private let audioDirectory: URL
    private let input: AudioInput
    private let format: AudioFormat

    private struct Active {
        let encounterID: UUID
        let url: URL
        let writer: WAVWriter
    }
    private var active: Active?

    public init(audioDirectory: URL, input: AudioInput) {
        self.audioDirectory = audioDirectory
        self.input = input
        self.format = input.format
    }

    public var isRecording: Bool { active != nil }
    public var currentEncounterID: UUID? { active?.encounterID }

    /// The absolute file URL an encounter's audio lives at (from its stored relative path).
    public func fileURL(forRelPath relPath: String) -> URL {
        audioDirectory.appendingPathComponent(relPath)
    }

    /// Begin recording a new encounter. Opens its file and starts the mic.
    @discardableResult
    public func begin(encounterID: UUID) throws -> URL {
        if let active { throw CaptureError.alreadyRecording(active.encounterID) }
        try FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        let url = audioDirectory.appendingPathComponent("\(encounterID.uuidString).wav")
        let writer = try WAVWriter(url: url, format: format)
        // The hot path: the audio tap writes straight to the thread-safe writer — no actor hop.
        try input.start(onBuffer: { data in writer.append(data) })
        active = Active(encounterID: encounterID, url: url, writer: writer)
        return url
    }

    /// Stop the mic, finalize the current file, and return the result.
    @discardableResult
    public func end() throws -> RecordingResult {
        guard let active else { throw CaptureError.notRecording }
        input.stop()                          // no further onBuffer callbacks after this returns
        let duration = active.writer.finalize()
        let result = RecordingResult(
            encounterID: active.encounterID,
            audioFileRelPath: active.url.lastPathComponent,
            duration: duration,
            byteCount: active.writer.bytesWritten
        )
        self.active = nil
        return result
    }

    /// One-tap handoff: finalize the current encounter and immediately begin the next.
    @discardableResult
    public func endAndBegin(nextEncounterID: UUID) throws -> (finished: RecordingResult, nextURL: URL) {
        let finished = try end()
        let nextURL = try begin(encounterID: nextEncounterID)
        return (finished, nextURL)
    }

    /// Recover a recording interrupted by a crash: if an encounter was left `.recording`, its
    /// partial WAV is repaired (header rebuilt from the bytes on disk) so it's playable and
    /// transcribable. Returns the recovered duration, or nil if the file is missing/too short.
    public func recoverPartialRecording(relPath: String) -> TimeInterval? {
        let url = audioDirectory.appendingPathComponent(relPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? WAVWriter.repair(at: url)
    }
}
