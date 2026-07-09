import Foundation
import SwiftData

/// A coarse status for the encounter list — drives the badge and whether the row needs the
/// clinician's attention. Kept separate from `EncounterPhase` so the UI has a small, stable
/// vocabulary (many phases collapse to "working").
public enum EncounterBadge: String, Sendable, Equatable {
    case recording
    case working          // transcribing / extracting / rendering — no action needed yet
    case readyToSign      // a draft is waiting for review + signature
    case awaitingDisposition
    case signed
    case failed
}

public struct EncounterStatus: Sendable, Equatable {
    public let badge: EncounterBadge
    public let label: String
    public let needsAttention: Bool
}

/// Pure list logic for the shift view: ordering, status, and out-of-order sign. No 10-encounter
/// cap anywhere — a 12-hour shift's worth of encounters all live here. The app's @MainActor
/// list view is a thin shell over these functions.
public enum ShiftBoard {

    public static func status(for phase: EncounterPhase) -> EncounterStatus {
        switch phase {
        case .recording:
            return .init(badge: .recording, label: "Recording", needsAttention: true)
        case .captured, .transcribing, .transcribed, .extracting,
             .dispositionCaptured, .dischargeExtracting:
            return .init(badge: .working, label: "Working…", needsAttention: false)
        case .noteDrafted:
            return .init(badge: .readyToSign, label: "Ready to sign", needsAttention: true)
        case .awaitingDisposition:
            return .init(badge: .awaitingDisposition, label: "Awaiting disposition", needsAttention: true)
        case .dischargeDrafted:
            return .init(badge: .readyToSign, label: "Discharge ready", needsAttention: true)
        case .signed:
            return .init(badge: .signed, label: "Signed", needsAttention: false)
        case .failed:
            return .init(badge: .failed, label: "Needs attention", needsAttention: true)
        }
    }

    /// A draft the clinician can sign right now.
    public static func isSignable(_ encounter: Encounter) -> Bool {
        encounter.phase == .noteDrafted || encounter.phase == .dischargeDrafted
    }

    /// Delete an encounter (swipe-to-delete). Cascade-deletes its jobs; the app also removes the
    /// audio file. Irreversible.
    public static func delete(_ encounter: Encounter, in context: ModelContext) throws {
        context.delete(encounter)
        try context.save()
    }

    /// Sign a drafted encounter — allowed in ANY order, independent of other encounters.
    /// Returns false if the encounter isn't in a signable phase.
    @discardableResult
    public static func sign(_ encounter: Encounter, in context: ModelContext, at date: Date = Date()) throws -> Bool {
        guard isSignable(encounter) else { return false }
        encounter.signedAt = date
        encounter.transition(to: .signed)
        try context.save()
        return true
    }

    /// All encounters, ordered for the shift list — NO cap. Attention-needing rows first
    /// (recording, ready-to-sign, awaiting-disposition, failed), then in-progress, then signed;
    /// within a group, most-recently-updated first.
    public static func fetchAllForDisplay(in context: ModelContext) throws -> [Encounter] {
        let all = try context.fetch(FetchDescriptor<Encounter>())
        return displaySorted(all)
    }

    public static func displaySorted(_ encounters: [Encounter]) -> [Encounter] {
        encounters.sorted { a, b in
            let ra = attentionRank(a.phase), rb = attentionRank(b.phase)
            if ra != rb { return ra < rb }
            return a.updatedAt > b.updatedAt
        }
    }

    /// Lower sorts earlier. Groups: needs-action (0), in-progress (1), terminal (2).
    private static func attentionRank(_ phase: EncounterPhase) -> Int {
        let s = status(for: phase)
        if s.needsAttention { return 0 }
        if phase == .signed || phase == .failed { return 2 }
        return 1
    }
}
