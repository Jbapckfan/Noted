import Foundation

/// The lifecycle of a single patient encounter. Persisted as a raw string on
/// `Encounter` so it survives relaunch and is predicate-friendly. The pipeline
/// advances an encounter forward through these phases; every stage commits before
/// advancing, so a crash resumes at most one stage back.
public enum EncounterPhase: String, Codable, CaseIterable, Sendable {
    case recording            // audio actively streaming to disk
    case captured             // recording stopped, audio file finalized
    case transcribing         // WhisperKit running
    case transcribed          // transcript ready
    case extracting           // fact-extraction model running
    case noteDrafted          // HPI/MDM note assembled + verified, awaiting review/sign
    case awaitingDisposition  // note signed-or-parked; waiting for the (possibly hours-later) disposition dictation
    case dispositionCaptured  // disposition audio finalized
    case dischargeExtracting  // discharge fact-extraction running
    case dischargeDrafted     // discharge summary assembled + verified, awaiting review/sign
    case signed               // clinician signed off — terminal success
    case failed               // exhausted retries — terminal failure, surfaced in the list

    /// Terminal phases never re-enter the generation queue.
    public var isTerminal: Bool { self == .signed || self == .failed }

    /// A stage is mid-flight (a worker is or was operating on it) — used by launch
    /// recovery to detect work interrupted by a crash/kill.
    public var isInFlight: Bool {
        switch self {
        case .transcribing, .extracting, .dischargeExtracting:
            return true
        default:
            return false
        }
    }
}
