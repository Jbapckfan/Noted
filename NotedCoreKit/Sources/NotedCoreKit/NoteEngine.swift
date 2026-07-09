import Foundation

/// A Sendable value-snapshot of everything a generation stage needs. The worker builds this
/// from the SwiftData `Encounter` and hands it to the engine — so the (off-actor, GPU-bound)
/// engine never touches a non-Sendable model object.
public struct GenerationInput: Sendable {
    public let encounterID: UUID
    public let kind: GenerationJobKind
    public let audioFileRelPath: String?
    public let transcript: String?
    public let extractionJSON: String?
    public let noteText: String?
    public let dispositionTranscript: String?
    public let resultsTrayJSON: String?

    public init(
        encounterID: UUID,
        kind: GenerationJobKind,
        audioFileRelPath: String? = nil,
        transcript: String? = nil,
        extractionJSON: String? = nil,
        noteText: String? = nil,
        dispositionTranscript: String? = nil,
        resultsTrayJSON: String? = nil
    ) {
        self.encounterID = encounterID
        self.kind = kind
        self.audioFileRelPath = audioFileRelPath
        self.transcript = transcript
        self.extractionJSON = extractionJSON
        self.noteText = noteText
        self.dispositionTranscript = dispositionTranscript
        self.resultsTrayJSON = resultsTrayJSON
    }
}

/// What a stage produces. Only the fields a given stage generates are set; the worker persists
/// whichever are non-nil onto the `Encounter`.
public struct GenerationOutput: Sendable {
    public var transcript: String?
    public var extractionJSON: String?
    public var noteText: String?
    public var verificationReport: String?
    public var dischargeJSON: String?
    public var dischargeClinicianText: String?
    public var dischargePatientText: String?
    public init() {}
}

/// The single abstraction over on-device generation. The real conformance (PR4) wraps MLX and
/// runs on the GPU; `MockNoteEngine` gives a deterministic, GPU-free stand-in for the simulator
/// and the test suite. Implementations must tolerate being called serially, one job at a time.
public protocol NoteEngine: Sendable {
    func run(_ input: GenerationInput) async throws -> GenerationOutput
}
