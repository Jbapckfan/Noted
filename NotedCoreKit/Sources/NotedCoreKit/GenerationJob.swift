import Foundation
import SwiftData

/// What a job asks the (single, serial) generation worker to do.
public enum GenerationJobKind: String, Codable, Sendable, CaseIterable {
    case transcribe       // WhisperKit / on-device STT (CPU/ANE)
    case extract          // fact extraction (GPU)
    case note             // HPI/MDM note assembly (GPU)
    case dischargeExtract // discharge fact extraction (GPU)
    case dischargeRender  // discharge summary rendering (GPU)

    /// Lower runs first. Live-encounter work outranks discharge so a discharge draft
    /// never contends with an active patient's note.
    public var defaultPriority: Int {
        switch self {
        case .transcribe, .extract, .note: return 0
        case .dischargeExtract, .dischargeRender: return 10
        }
    }
}

public enum GenerationJobState: String, Codable, Sendable, CaseIterable {
    case pending
    case running
    case done
    case failed
}

/// A durable queue entry. Because jobs live in the store (not in memory), a crash or
/// force-kill mid-generation is recoverable: on next launch a `running` job older than
/// the staleness threshold is reset to `pending` and re-run (at most one stage repeats).
@Model
public final class GenerationJob {
    @Attribute(.unique) public var id: UUID

    public var kindRaw: String
    public var stateRaw: String

    /// Lower = higher priority. Ties break by `createdAt`.
    public var priority: Int
    public var attempts: Int

    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    public var lastError: String?

    public var encounter: Encounter?

    public init(
        id: UUID = UUID(),
        kind: GenerationJobKind,
        encounter: Encounter? = nil,
        priority: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.stateRaw = GenerationJobState.pending.rawValue
        self.priority = priority ?? kind.defaultPriority
        self.attempts = 0
        self.createdAt = createdAt
        self.encounter = encounter
    }

    public var kind: GenerationJobKind {
        get { GenerationJobKind(rawValue: kindRaw) ?? .note }
        set { kindRaw = newValue.rawValue }
    }

    public var state: GenerationJobState {
        get { GenerationJobState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}
