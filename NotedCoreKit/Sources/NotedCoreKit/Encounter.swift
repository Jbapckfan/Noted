import Foundation
import SwiftData

/// How an encounter's source text was produced — so the UI can treat a bedside recording (whose
/// transcript is fixed source material) differently from a pasted test transcript (which the tester
/// edits and re-summarizes). Inferring this forever from `audioFileRelPath` is fragile.
public enum EncounterSource: String, Codable, Sendable, CaseIterable {
    case audio        // recorded + transcribed at the bedside — the transcript is read-only source
    case manualTest   // a transcript pasted/typed to exercise the summarizer — editable + re-runnable
}

/// One patient encounter — the durable unit of work.
///
/// Everything is committed to disk the moment it changes, so seeing 3 patients in a
/// row and returning to the computer later loses nothing: each encounter is a row that
/// persists across backgrounding, relaunch, and crash.
///
/// `id` is a STORED, unique attribute (not a computed `let id = UUID()`), which fixes the
/// legacy bug where the Codable struct regenerated its identity on every decode. IDs are
/// stable for the life of the encounter — that's what ties an hours-later disposition
/// dictation back to the right chart.
@Model
public final class Encounter {
    @Attribute(.unique) public var id: UUID

    public var createdAt: Date
    public var updatedAt: Date

    /// Short human label for the encounter list (e.g. "chest pain, rm 12").
    public var chiefComplaint: String

    /// Stored raw phase; use the `phase` computed accessor.
    public var phaseRaw: String

    /// Stored raw source; use the `source` computed accessor. Defaulted so existing rows migrate.
    public var sourceRaw: String = EncounterSource.audio.rawValue

    // MARK: Capture
    /// Path RELATIVE to the app's audio directory (never an absolute URL — absolute
    /// paths break when the app container is relocated on restore/reinstall).
    public var audioFileRelPath: String?
    public var recordingDuration: TimeInterval

    // MARK: Pipeline artifacts (the first generative task)
    public var transcript: String?
    public var extractionJSON: String?
    public var noteText: String?
    public var verificationReport: String?
    /// True once the clinician edits the note AFTER it was generated: the grounding check applied to
    /// the generated draft, not to later edits, so the UI must say so. Defaulted for row migration.
    public var noteEditedAfterGrounding: Bool = false

    // MARK: Disposition + discharge (the second generative task)
    public var dispositionAudioRelPath: String?
    public var dispositionTranscript: String?
    public var resultsTrayJSON: String?
    public var dischargeJSON: String?
    public var dischargeClinicianText: String?
    public var dischargePatientText: String?

    // MARK: Sign-off / diagnostics
    public var signedAt: Date?
    public var lastError: String?

    /// Durable per-encounter work items. Cascade-deleted with the encounter.
    @Relationship(deleteRule: .cascade, inverse: \GenerationJob.encounter)
    public var jobs: [GenerationJob]

    public init(
        id: UUID = UUID(),
        chiefComplaint: String = "",
        phase: EncounterPhase = .recording,
        source: EncounterSource = .audio,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.chiefComplaint = chiefComplaint
        self.phaseRaw = phase.rawValue
        self.sourceRaw = source.rawValue
        self.noteEditedAfterGrounding = false
        self.audioFileRelPath = nil
        self.recordingDuration = 0
        self.jobs = []
    }

    /// Typed phase accessor. Setting it stamps `updatedAt`.
    public var phase: EncounterPhase {
        get { EncounterPhase(rawValue: phaseRaw) ?? .failed }
        set {
            phaseRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    /// Typed source accessor.
    public var source: EncounterSource {
        get { EncounterSource(rawValue: sourceRaw) ?? .audio }
        set { sourceRaw = newValue.rawValue }
    }

    /// Advance the phase and touch `updatedAt` in one call.
    public func transition(to newPhase: EncounterPhase) {
        phase = newPhase
    }

    /// Mark terminal failure, recording the reason for the red badge in the list.
    public func fail(_ reason: String) {
        lastError = reason
        phase = .failed
    }
}
