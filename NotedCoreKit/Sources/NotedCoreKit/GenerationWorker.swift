import Foundation
import SwiftData

/// The single, serial consumer of the generation queue.
///
/// There is exactly ONE drain loop, and it `await`s each job to completion before fetching the
/// next — so two generations never overlap (the GPU is never asked to run two models at once).
/// Meanwhile capture of the next encounter (CPU/ANE) runs independently in `CaptureController`,
/// which is the whole point: record patient N+1 while patient N's note generates.
///
/// Every state change commits before the next step, so a crash resumes at most one stage back
/// (see `recoverAndDrain`, which uses the launch-time stale-job watchdog from `EncounterStore`).
public actor GenerationWorker {

    private let container: ModelContainer
    private let engine: NoteEngine
    private let maxAttempts: Int
    private let context: ModelContext
    private var isDraining = false

    public init(container: ModelContainer, engine: NoteEngine, maxAttempts: Int = 3) {
        self.container = container
        self.engine = engine
        self.maxAttempts = maxAttempts
        self.context = ModelContext(container)
    }

    /// Recover any jobs a crash left `running`, then drain. Call this once at launch.
    @discardableResult
    public func recoverAndDrain(staleAfter threshold: TimeInterval = 300) async -> Int {
        _ = try? EncounterStore.recoverInterruptedJobs(in: context, staleAfter: threshold, maxAttempts: maxAttempts)
        return await drain()
    }

    /// Process pending jobs one at a time until none remain. Re-entrant calls no-op while a
    /// drain is already running. Returns the number of jobs processed.
    @discardableResult
    public func drain() async -> Int {
        if isDraining { return 0 }
        isDraining = true
        defer { isDraining = false }

        var processed = 0
        while let job = nextPendingJob() {
            await process(job)
            processed += 1
        }
        return processed
    }

    // MARK: - Internals

    private func nextPendingJob() -> GenerationJob? {
        let pending = GenerationJobState.pending.rawValue
        var desc = FetchDescriptor<GenerationJob>(
            predicate: #Predicate { $0.stateRaw == pending },
            sortBy: [SortDescriptor(\.priority), SortDescriptor(\.createdAt)]
        )
        desc.fetchLimit = 1
        return (try? context.fetch(desc))?.first
    }

    private func process(_ job: GenerationJob) async {
        // Mark running + commit BEFORE any await, so a crash during generation leaves a durable
        // `running` marker that launch recovery can reset.
        job.state = .running
        job.startedAt = Date()
        try? context.save()

        guard let encounter = job.encounter else {
            job.state = .failed
            job.finishedAt = Date()
            job.lastError = "job has no encounter"
            try? context.save()
            return
        }

        let stage = Self.stage(for: job.kind)
        encounter.transition(to: stage.running)
        try? context.save()

        do {
            switch job.kind {
            case .note:
                // DETERMINISTIC: the model extracted facts; the template writes the prose and the
                // grounding verifier checks it. No model call here — writing can't hallucinate.
                try applyNoteStage(encounter)
            case .dischargeRender:
                // DETERMINISTIC: render both versions from the verified discharge JSON.
                try applyDischargeRenderStage(encounter)
            case .transcribe, .extract, .dischargeExtract:
                let output = try await engine.run(snapshot(of: encounter, kind: job.kind))
                apply(output, to: encounter)
            }
            encounter.transition(to: stage.done)

            job.state = .done
            job.finishedAt = Date()
            try context.save()

            if let next = stage.next {
                _ = try? GenerationQueue.enqueue(next, for: encounter, in: context)
            }
        } catch {
            job.attempts += 1
            job.lastError = "\(error)"
            if job.attempts >= maxAttempts {
                job.state = .failed
                job.finishedAt = Date()
                encounter.fail("generation failed after \(maxAttempts) attempts: \(error)")
            } else {
                // Back to pending for another pass; no backoff here (thermal/backoff is PR7).
                job.state = .pending
                job.startedAt = nil
            }
            try? context.save()
        }
    }

    private func snapshot(of e: Encounter, kind: GenerationJobKind) -> GenerationInput {
        GenerationInput(
            encounterID: e.id,
            kind: kind,
            audioFileRelPath: e.audioFileRelPath,
            transcript: e.transcript,
            extractionJSON: e.extractionJSON,
            noteText: e.noteText,
            dispositionTranscript: e.dispositionTranscript,
            resultsTrayJSON: e.resultsTrayJSON
        )
    }

    enum StageError: Error { case missingInput(String) }

    /// `.note`: extracted facts -> deterministic HPI/MDM template + grounding verification.
    private func applyNoteStage(_ e: Encounter) throws {
        guard let extraction = e.extractionJSON, !extraction.isEmpty else {
            throw StageError.missingInput("extractionJSON")
        }
        let facts = try ClinicalFacts.parse(extraction)
        e.noteText = NoteTemplate.renderHPIandMDM(facts)
        let report = GroundingVerifier(transcript: e.transcript ?? "").verify(facts)
        e.verificationReport = Self.encode(report)
    }

    /// `.dischargeRender`: verified discharge JSON -> clinician + patient renderings, cross-layer
    /// verification, and the patient-version reading-level check.
    private func applyDischargeRenderStage(_ e: Encounter) throws {
        guard let dischargeJSON = e.dischargeJSON, !dischargeJSON.isEmpty else {
            throw StageError.missingInput("dischargeJSON")
        }
        let summary = try DischargeSummary.parse(dischargeJSON)
        e.dischargeClinicianText = DischargeRenderer.renderClinician(summary)
        e.dischargePatientText = DischargeRenderer.renderPatient(summary)
        let report = DischargeVerifier(
            extractionJSON: e.extractionJSON,
            resultsTrayJSON: e.resultsTrayJSON,
            dispositionTranscript: e.dispositionTranscript
        ).verify(summary)
        e.verificationReport = Self.encodeDischarge(report)
    }

    private static func encode(_ report: VerificationReport) -> String? {
        (try? JSONEncoder().encode(report)).flatMap { String(data: $0, encoding: .utf8) }
    }
    private static func encodeDischarge(_ report: DischargeVerificationReport) -> String? {
        // DischargeVerificationReport isn't Codable (structuralIssues are plain strings); serialize
        // the grounding flags + issues into a small JSON object.
        let flags = (try? JSONEncoder().encode(report.groundingFlags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let issues = (try? JSONEncoder().encode(report.structuralIssues)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        return "{\"flags\":\(flags),\"structuralIssues\":\(issues)}"
    }

    private func apply(_ out: GenerationOutput, to e: Encounter) {
        if let v = out.transcript { e.transcript = v }
        if let v = out.extractionJSON { e.extractionJSON = v }
        if let v = out.noteText { e.noteText = v }
        if let v = out.verificationReport { e.verificationReport = v }
        if let v = out.dischargeJSON { e.dischargeJSON = v }
        if let v = out.dischargeClinicianText { e.dischargeClinicianText = v }
        if let v = out.dischargePatientText { e.dischargePatientText = v }
    }

    // MARK: - Pipeline map

    private struct Stage {
        let running: EncounterPhase
        let done: EncounterPhase
        let next: GenerationJobKind?
    }

    private static func stage(for kind: GenerationJobKind) -> Stage {
        switch kind {
        case .transcribe:      return Stage(running: .transcribing,       done: .transcribed,       next: .extract)
        case .extract:         return Stage(running: .extracting,         done: .extracting,        next: .note)
        case .note:            return Stage(running: .extracting,         done: .noteDrafted,       next: nil)
        case .dischargeExtract:return Stage(running: .dischargeExtracting, done: .dischargeExtracting, next: .dischargeRender)
        case .dischargeRender: return Stage(running: .dischargeExtracting, done: .dischargeDrafted,   next: nil)
        }
    }
}
