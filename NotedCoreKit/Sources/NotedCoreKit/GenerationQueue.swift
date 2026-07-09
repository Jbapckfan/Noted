import Foundation
import SwiftData

/// Helpers for putting work on the durable queue. Enqueuing a job is just inserting a
/// `GenerationJob` row — it survives relaunch, so nothing is lost if the app dies before the
/// worker gets to it.
public enum GenerationQueue {

    /// Enqueue a single job for an encounter.
    @discardableResult
    public static func enqueue(
        _ kind: GenerationJobKind,
        for encounter: Encounter,
        in context: ModelContext
    ) throws -> GenerationJob {
        let job = GenerationJob(kind: kind, encounter: encounter)
        context.insert(job)
        try context.save()
        return job
    }

    /// Kick off the note pipeline for a freshly-captured encounter: it starts at `transcribe`,
    /// and each stage enqueues the next as it completes (transcribe → extract → note).
    @discardableResult
    public static func startNotePipeline(
        for encounter: Encounter,
        in context: ModelContext
    ) throws -> GenerationJob {
        try enqueue(.transcribe, for: encounter, in: context)
    }

    /// Kick off the discharge pipeline (dischargeExtract → dischargeRender) once a disposition
    /// has been captured.
    @discardableResult
    public static func startDischargePipeline(
        for encounter: Encounter,
        in context: ModelContext
    ) throws -> GenerationJob {
        try enqueue(.dischargeExtract, for: encounter, in: context)
    }
}
