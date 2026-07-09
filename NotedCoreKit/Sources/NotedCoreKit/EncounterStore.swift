import Foundation
import SwiftData

/// Factory + recovery for the encounter store.
///
/// The cardinal rule here is the fix for the legacy data-loss bomb
/// (`PersistenceController.handlePersistenceError` used to `removeItem` the entire store
/// on ANY load failure, wiping a whole shift). This store NEVER deletes: on a genuine
/// load failure it RENAMES the corrupt store aside (`<name>.corrupt-<epoch>`), starts a
/// fresh store, and lets the caller surface a banner. One migration slip must not erase data.
public enum EncounterStore {

    public static let schema = Schema([Encounter.self, GenerationJob.self])

    /// Result of opening a file-backed store, so the app can banner a recovery event.
    public struct OpenResult {
        public let container: ModelContainer
        public let recoveredFromCorruption: Bool
        /// Where the corrupt store was moved (nil if none / move failed).
        public let corruptStoreURL: URL?
    }

    /// Open (or create) the store at `url`. Non-destructive: a corrupt store is moved
    /// aside, never deleted, and a fresh store is opened in its place.
    public static func open(at url: URL) throws -> OpenResult {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let config = ModelConfiguration(schema: schema, url: url)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            return OpenResult(container: container, recoveredFromCorruption: false, corruptStoreURL: nil)
        } catch {
            // Non-destructive recovery: move the bad store (and SQLite sidecars) aside,
            // then open a fresh one. If THIS also throws, we let it propagate — but we
            // have still preserved the user's bytes on disk for manual recovery.
            let movedTo = renameAside(url: url)
            let container = try ModelContainer(for: schema, configurations: config)
            return OpenResult(container: container, recoveredFromCorruption: true, corruptStoreURL: movedTo)
        }
    }

    /// Convenience: just the container.
    public static func makeContainer(at url: URL) throws -> ModelContainer {
        try open(at: url).container
    }

    /// In-memory container for tests and previews.
    public static func inMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Launch-time crash recovery (watchdog)

    /// Reset jobs left `running` by a crash/kill back to `pending` so the worker re-runs
    /// them. A job that has already been retried `maxAttempts` times is marked `failed`
    /// (and its encounter `failed`) — never a silent drop, never a retry loop that cooks
    /// the device. Returns the number of jobs acted on.
    @discardableResult
    public static func recoverInterruptedJobs(
        in context: ModelContext,
        staleAfter threshold: TimeInterval = 300,
        maxAttempts: Int = 3,
        now: Date = Date()
    ) throws -> Int {
        let runningRaw = GenerationJobState.running.rawValue
        let running = try context.fetch(
            FetchDescriptor<GenerationJob>(predicate: #Predicate { $0.stateRaw == runningRaw })
        )
        var acted = 0
        for job in running {
            let since = job.startedAt ?? job.createdAt
            guard now.timeIntervalSince(since) >= threshold else { continue }
            job.attempts += 1
            if job.attempts >= maxAttempts {
                job.state = .failed
                job.finishedAt = now
                job.lastError = "generation interrupted; failed after \(maxAttempts) attempts"
                job.encounter?.fail("generation failed after \(maxAttempts) attempts")
            } else {
                job.state = .pending
                job.startedAt = nil
            }
            acted += 1
        }
        if acted > 0 { try context.save() }
        return acted
    }

    // MARK: - Non-destructive move

    /// Move the store file and its SQLite sidecars to `<name>.corrupt-<epoch>`.
    /// Returns the destination of the primary file, or nil if it wasn't present/movable.
    @discardableResult
    static func renameAside(url: URL) -> URL? {
        let fm = FileManager.default
        let stamp = Int(Date().timeIntervalSince1970)
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        let destName = ext.isEmpty ? "\(base).corrupt-\(stamp)" : "\(base).corrupt-\(stamp).\(ext)"
        let dest = dir.appendingPathComponent(destName)

        var movedPrimary = false
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: dest.path + suffix)
            do {
                try fm.moveItem(at: src, to: dst)
                if suffix.isEmpty { movedPrimary = true }
            } catch {
                // Best-effort: if a sidecar can't move, keep going; never delete.
            }
        }
        return movedPrimary ? dest : nil
    }
}
