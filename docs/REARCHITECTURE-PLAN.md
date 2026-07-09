# NotedCore Rearchitecture — Build-Ready Plan

Builds on the accepted engine plan (MLX-Swift, Llama 3.2 3B + ED LoRA, 4-bit, grafted from EDScribePro; extraction -> deterministic template -> deterministic verification; WhisperKit STT; sim mock engine). Everything below is fully offline.

---

## 1. App structure — the encounter queue

### Core principle
The app stops being "one session at a time" (today's `EncounterSessionManager.currentSession: EncounterSession?`) and becomes **a durable queue of Encounter records plus a single serial generation worker**. Capture is foreground-exclusive and real-time; generation is a deferred compute job. The disk is the source of truth; RAM holds nothing that can't be rebuilt.

### Types (new module `NotedCoreKit`)

```swift
// SwiftData @Model — the ONE aggregate. Replaces EncounterSession,
// MedicalEncounter, and CoreAppState's scalar fields.
@Model final class Encounter {
    @Attribute(.unique) var id: UUID          // STORED, set once at insert —
                                              // fixes the `let id = UUID()` decode-regeneration bug
    var createdAt: Date
    var label: String                         // "Rm 12 — chest pain" (physician-entered, no PHI required)
    var phaseRaw: String                      // EncounterPhase raw value — persisted state machine
    // Capture artifacts (file references, never blobs in the store)
    var audioFileRelPath: String?             // per-encounter .caf in Application Support/Audio/<id>/
    var transcript: String?
    // First generative task
    var extractionJSON: Data?                 // schema-constrained facts
    var noteText: String?
    var verificationReport: Data?             // flagged spans, grounding results
    // Discharge layer (Section 4)
    var dispositionAudioRelPath: String?
    var dispositionTranscript: String?
    var resultsTrayJSON: Data?                // physician-confirmed labs/imaging/meds — ground truth
    var dischargeJSON: Data?
    var dischargeClinicianText: String?
    var dischargePatientText: String?
    var signedAt: Date?
    var lastError: String?
}

enum EncounterPhase: String, Codable {
    case recording, captured, transcribing, transcribed,
         extracting, noteDrafted,                 // reviewable — HPI/MDM note ready
         awaitingDisposition,                     // patient still in ED, hours may pass
         dispositionCaptured, dischargeExtracting,
         dischargeDrafted,                        // reviewable — discharge ready
         signed, failed
}

// SwiftData @Model — persisted job queue. Survives kill/jetsam/reboot.
@Model final class GenerationJob {
    @Attribute(.unique) var id: UUID
    var encounterID: UUID
    var kindRaw: String        // transcribe | extract | assembleNote |
                               // dischargeExtract | dischargeRender
    var stateRaw: String       // pending | running | done | failed
    var priority: Int          // live-adjacent work > backlog drain
    var attempts: Int          // >=3 failures => encounter.phase = .failed, surface to UI
    var createdAt: Date
    var startedAt: Date?
}
```

### Actors (replace the @MainActor singleton pile)

```swift
@MainActor final class EncounterListModel: ObservableObject   // UI only — @Query-driven, no engine refs

actor CaptureController {
    // Owns THE one AVAudioEngine (today there are three).
    // .playAndRecord session + "audio" background mode.
    // Writes PCM straight to disk per encounter; NO ML in the tap callback.
    func start(encounter: UUID) throws
    func stop() async -> URL          // finalizes file, flips phase .recording -> .captured,
                                      // enqueues .transcribe job, returns immediately
}

actor GenerationWorker {
    // THE single serial consumer. One GPU => one job at a time, ever.
    // Drains GenerationJob by priority then FIFO.
    // Pipeline per job: gate (thermal+memory) -> load/bind adapter ->
    //   run -> commit result to Encounter -> checkpoint -> next.
    func kick()                       // called on: job enqueued, app foregrounded, gates clear
}

actor TranscriptionWorker {
    // WhisperKit on ANE/CPU — MAY overlap GenerationWorker (GPU) but is
    // paused by EngineGovernor if memory headroom < threshold.
}

final class EngineGovernor {          // Section 3 — thermal/memory/battery gates
final class MockNoteEngine: NoteEngine   // Simulator/dev — MLX cannot run without Metal
```

### How "record N+1 while N summarizes" works
1. James taps **Stop** on patient N. `CaptureController.stop()` finalizes N's audio file, sets `.captured`, enqueues a `transcribe` job. This takes milliseconds.
2. He immediately taps **New encounter** for N+1. `CaptureController.start()` opens a fresh audio file. The mic pipeline is CPU-trivial and independent of the GPU.
3. Meanwhile `GenerationWorker` picks up N: WhisperKit transcribe (ANE/CPU) -> extraction pass (MLX/GPU) -> deterministic Swift template -> deterministic verifier -> `noteDrafted`. Each stage commits to SwiftData before the next starts, so a kill loses at most one stage, never the encounter.
4. Concurrency contract: **capture of N+1 (CPU/ANE) overlaps generation of N (GPU); two GPU generations never overlap.** This is not a limitation to hide — it's the design: one 3B model on one Metal GPU is serial by physics.
5. Backgrounding mid-generation: default policy is "resume on next foreground" (the durable queue makes this free). On iOS 26, additionally submit a `BGContinuedProcessingTask` with Background GPU Access (query `BGTaskScheduler.shared.supportedResources`) so the job can finish with a visible system progress pill — treated as a bonus, never depended on.

### Deferred / out-of-order finalization (see 3, chart 3 later)
This falls out of the model for free: encounters at `.noteDrafted` / `.dischargeDrafted` just sit in the store. The home screen is an **encounter list sorted by "needs me" state** with per-row badges (Recording, Processing, Note ready, Awaiting dispo, Discharge ready, Signed, Failed). James taps any row in any order, reviews, edits, signs. No caps: the 10-encounter `suffix(10)`/`removeFirst()` truncation in `CoreAppState`/`EncounterSessionManager` is deleted; a shift holds 25+ encounters trivially (each is ~KB of text + one audio file; audio is deleted on sign or after a configurable retention window).

### What gets deleted/replaced (file-level)
- **Delete:** `NotedCore_disabled_files/` (~40 files), `GroqService.swift`, all Anthropic/online paths in `MedicalAIService.swift` (`checkOnlineAvailability`, `.auto` preference), `EncounterSessionManager.swift`, `CoreAppState` scalar session fields, two of the three AVAudioEngine owners (`AudioCaptureService`, `EncounterController`'s engine).
- **Keep + rewire:** `EncounterManager`'s multi-encounter/room concepts fold into `Encounter`; `ProfessionalEncounterView` rebinds to `EncounterListModel`.
- **Persistence:** SwiftData replaces both the UserDefaults JSON blobs (`saved_encounters`, `RecentEncounterSessions`) and the broken CoreData path (`PersistenceController.saveEncounter` writes nothing its own `convertToEncounter` can read). One-time migrator imports whatever is salvageable from UserDefaults, then those keys are retired.

---

## 2. Engine

### Decision restated (unchanged from prior plan)
- **Runtime:** MLX-Swift, grafted from EDScribePro (`MLXRunner.swift`, `AdvancedLLMPipeline.swift`) — NotedCore's current "AI" is keyword templating and is discarded.
- **Model:** Llama 3.2 3B Instruct, 4-bit (~1.8–2 GB), one resident base + small hot-swappable task-LoRA adapters (extraction / note-assembly / discharge, ~10–50 MB each). Never a second base model.
- **STT:** WhisperKit (resolve the swift-transformers 1.0.0 pin against MLX-Swift's requirement; fallback Apple `SFSpeechRecognizer` with on-device flag — Decision #1).
- **Not Apple Foundation Models** as primary (4096-token context, guardrail refusals on ED content, version-locked adapters). Optional later: use it only for the low-stakes patient-language simplification pass, never for clinical facts.
- **Simulator:** `NoteEngine` protocol with `MockNoteEngine` — MLX requires Metal and will never run in the sim. This ends the "simulator model-loading" pain by design.

### Pipeline inside the worker (per job, per encounter)
1. **Extraction (LLM, GPU):** transcript -> fixed fact-JSON under **grammar-constrained decoding** (token-mask logit processor compiled from the schema — Outlines/XGrammar-style masks ported to the MLX sampler). Chunk long transcripts; extraction prompt bounded to ~8K tokens so KV cache stays predictable.
2. **Template (deterministic Swift):** facts JSON -> HPI/MDM note. The model never authors a number — doses, vitals, values are copy slots filled from extraction JSON only.
3. **Verification (deterministic Swift, NOT LLM self-critique):** every numeric/drug token string-matched back to the transcript/extraction; ungrounded spans flagged in `verificationReport` and highlighted in the review UI. Draft is never auto-finalized.

Each stage is a separate committed checkpoint on the `Encounter`, so a crash between extraction and templating resumes at templating.

### Memory strategy (the binding constraint)
Hard numbers: **~6144 MB per-app ceiling** on iPhone 16 Pro Max (jetsam at ~50–67% of 8 GB). Budget: 3B 4-bit base ~2.0 GB + KV cache (bounded prompts: ~0.3–0.8 GB) + WhisperKit (~0.6 GB for small; ~1 GB for medium) + app/UI/audio ~0.5 GB => **~3.5–4.3 GB steady state, ~2 GB headroom.**

Policy (**"resident while working, shed under pressure"** — not naive load/unload per job, and not permanently resident):
- Load the base **once** on first job; keep it resident while the queue is nonempty or a shift is active (model load from disk is seconds; paying it 25× per shift for nothing wastes battery and adds latency).
- **Unload triggers:** memory-warning notification (shed LLM first, then Whisper), `os_proc_available_memory()` below ~1 GB before a job (defer the job instead of loading), queue empty + app backgrounded, thermal `.critical`.
- Between jobs: clear MLX GPU buffer cache (`MLX.GPU.clearCache()` equivalent) and drop the KV cache; swap only the LoRA adapter tensors, not the base.
- Never resident simultaneously at full size unless headroom allows: if Whisper-medium is chosen, serialize STT and LLM phases within the worker (they already run in one pipeline, so this costs nothing).
- Add `com.apple.developer.kernel.increased-memory-limit` entitlement; gate every model load on `os_proc_available_memory()` at runtime.
- Queued encounters live on disk as audio+text — **zero** in-RAM model state per queued encounter.

Throughput expectation: ~20–30 tok/s cool, plan for a **23.7 tok/s hot-state floor**; a bounded extraction + template design keeps per-note generation to roughly 1,000–2,000 output tokens, i.e. ~1–2 minutes worst case, well under inter-patient gaps.

---

## 3. Stability + performance over a 12-hour, 20–25-note shift

### Memory / jetsam
- Everything in Section 2's memory policy, plus: register `DispatchSource.makeMemoryPressureSource`; on `.warning` unload LLM, on `.critical` also unload Whisper and pause the queue. Recording is protected: the mic path holds no models, so a shed never kills an in-progress capture.
- **Remove the data-loss bomb:** `PersistenceController.handlePersistenceError()` currently deletes the entire store on any load failure. Replace with: lightweight migration only, and on genuine load failure **rename the store aside** (`store.corrupt-<timestamp>`), start fresh, and surface a persistent banner — never `removeItem`. One migration slip must not wipe a shift.

### Thermal duty-cycling
- `EngineGovernor` observes `ProcessInfo.thermalState` (+ `thermalStateDidChangeNotification`).
- `.nominal/.fair`: drain queue normally. Naturally spaced encounters (minutes apart) generate from a cool device at near-peak speed — the common case is fine.
- `.serious`: insert cool-down gaps (~60–90 s) between backlog jobs, cap max tokens, greedy decode. This targets the one pathological pattern: draining 3+ deferred notes back-to-back at the computer (measured: sustained load drops 40.5 -> 23.7 tok/s with no recovery in tight gaps).
- `.critical`: pause queue, show a quiet "cooling down — N queued" state. Capture continues regardless.
- **Default scheduling bias:** generate opportunistically the moment each recording stops (spread across the shift, cool SoC) rather than batching — the queue does this automatically since transcribe/extract jobs enqueue at stop-time.

### Battery
Measured ~5%/20 generations => 20–25 notes ≈ 6–8% of battery for LLM work; STT and screen dominate. No special handling beyond: skip opportunistic backlog drain when Low Power Mode is on and battery <20% (drain on demand instead).

### Crash / OOM / relaunch recovery (watchdog)
- On every launch: any `GenerationJob` in `running` older than a staleness threshold is reset to `pending` (attempts+1); the worker kicks automatically. Because every pipeline stage commits before advancing, recovery re-runs at most one stage.
- `attempts >= 3` => job `failed`, encounter `.failed` with `lastError`, red badge in the list — never a silent drop, never a retry loop that cooks the device.
- Any encounter stuck in `.recording` at launch (app died mid-capture) is finalized from the partial audio file (PCM was streamed to disk, so it's playable/transcribable up to the crash instant).
- `MetricKit` subscriber logs jetsam/crash/thermal diagnostics locally for post-shift inspection.

### Lifecycle wiring (all missing today)
- `scenePhase` observation in `NotedCoreApp`; `beginBackgroundTask` around stage commits; iOS 26 `BGContinuedProcessingTask` (+ GPU resource) when backgrounded mid-generation; replace the main-run-loop `Timer`s (0.2 s transcription, 1 s duration, 30 s autosave) with async sequences owned by the actors — they currently freeze on suspension.

### Streamlining fixes (one-time cleanup PR)
Delete `NotedCore_disabled_files/`; excise Anthropic/Groq online paths (the app currently calls `api.anthropic.com` on launch — an offline-guarantee violation); collapse three audio engines to one and three-plus generator singletons to the one worker; **PAT:** no key literal exists in current source — treat as a git-history scrub (`git filter-repo` on the offending blob + revoke the token at the provider) plus a pre-commit secret scan (gitleaks) to keep it that way; add an **offline CI guard**: a test target that fails if the binary links/symbols reference URLSession-to-network in engine paths (allowlist empty), so "fully offline" is enforced, not asserted.

---

## 4. Discharge summary — the second generative task

### Inputs: three layers, one `Encounter`, no new pipeline
- **Layer A — carried-forward HPI facts:** the already-verified `extractionJSON` from the first task (chief complaint, HPI, PMH/meds/allergies, exam, differential). Inherited, never re-derived from audio — the discharge task starts from verified facts.
- **Layer B — results tray:** `resultsTrayJSON` — labs, imaging reads, ED meds given, procedures, entered/dictated and **physician-confirmed** discrete values. Ground truth; never paraphrased by the model.
- **Layer C — disposition dictation:** James returns to the encounter (possibly hours later), taps "Dictate disposition," speaks the results/treatments/course discussion. Same `CaptureController` + WhisperKit; stored as `dispositionAudioRelPath`/`dispositionTranscript`. This is the narrative source.

Tie-back to the right encounter is structural: the dictation is captured **from within that encounter's detail view**, so it's bound to the persisted `Encounter.id` — no matching heuristics, and the hours-old gap is just the `.awaitingDisposition` phase persisting on disk across backgrounding/relaunch.

### Schema (fixed discharge JSON, second grammar)
`{final_diagnosis, differential_ruled_out[], brief_clinical_course, results_explained[{test, result_value_verbatim, plain_language_meaning}], treatments_given_in_ED[], medications_prescribed[{drug, dose, route, frequency, duration, quantity — all verbatim copy slots}], medications_changed_or_stopped[], follow_up[{who, when, why}], return_precautions[], activity_diet_work_restrictions[], patient_instructions[], pending_results[{test, how_communicated}]}`

Rules:
- Drugs, doses, result values = **copy slots** under constrained decoding — only tokens present in layers A/B/C can fill them; a med not ordered literally cannot be emitted.
- `return_precautions` are **selected** from a curated per-diagnosis Swift library (head injury, chest pain, abd pain, etc.), never invented — this is where hallucinated advice is most dangerous.
- Only `brief_clinical_course` and the plain-language explanations are free text, entailment-checked clause-by-clause against the Layer C transcript.

### Two renderings, one fact set
- **Clinician rendering:** clinical register, deterministic template — goes in the chart.
- **Patient rendering:** second-person, abbreviations expanded, drug plain-names added; gated by an on-device **Flesch-Kincaid/SMOG check** (target grade 6, hard ceiling 8) with a bounded regenerate-under-"simplify"-constraint loop, because LLMs land at grade 7–9 unprompted. Simplification is a style transform over locked facts — copy slots pass through byte-identical.

### Verification and workflow
Same deterministic checker, extended: every med/result string-matches Layer B; diagnosis consistent with Layer A differential; pending results map to actually-ordered tests; required sections (precautions, follow-up, meds) non-empty; review-and-sign draft with ungrounded spans flagged. (Evidence basis: clinician-review-gated drafts are what keep measured harm near zero despite 42% raw hallucination rates in ED-summary evals.)

### Engine integration
A **mode, not a model**: `dischargeExtract` and `dischargeRender` are just two more `GenerationJob` kinds on the same serial worker — same resident 4-bit base, the **discharge LoRA adapter** bound per job (adapters are tens of MB; keep both resident if swap latency annoys). Priority sits below live-encounter transcribe/extract so a discharge draft never contends with an active patient. Memory stays flat; batched out-of-order dispositions are just more rows in the queue.

---

## 5. Training — ordered LoRA recipe

**Topology: three per-task adapters** (extraction / note-assembly / discharge), not one multi-task adapter — independent iteration, no cross-task interference, hot-swap over one base. Base: **Llama 3.2 3B Instruct** (consistent with EDScribePro's existing fine-tune; 128K context covers hour-later discharge synthesis). License note: Qwen2.5-**3B** is Qwen-Research, **not** Apache-2.0 — the real hedges are Qwen2.5-1.5B (Apache, quality drop) or 7B (Apache, too big at 4-bit). Llama's 700M-MAU cap is irrelevant for solo deployment; keep the pipeline model-agnostic (same JSONL, same `mlx_lm.lora`) as the hedge.

> **SAMPLE SCOPE (locked 2026-07-08):** v1 trains/evals on samples already in-repo — synthetic (PHI-free) ED transcripts + PriMock57 + MTS-Dialog — plus new synthetic ED generation. No real-shift audio yet; the Decision-3 real-voice batch stays parked until James records one. In-repo assets: `MedicalDatasets/primock57/` (57 consults, 115 transcripts + 115 audio), `MedicalDatasets/MTS-Dialog/`, and the hand-built ED set (`TEST_TRANSCRIPTS_DOCUMENTATION.md` — 5×10-min ED cases WITH gold-extraction blocks, `FULL_LENGTH_ED_TRANSCRIPTS.md`, `REAL_ED_TRANSCRIPTS.md`, `test_10min_ed_encounter.txt`, `test_chest_pain.txt`). The 5 gold-paired ED cases double as the PR5 golden-transcript regression fixtures.

Ordered recipe (runs on the Mac Studio/Mini; cloud permissible only because the corpus is synthetic + de-identified — no PHI ever leaves a device pre-scrub):

1. **Data plumbing:** converters for ACI-Bench (207 conversations), MTS-Dialog (~1,700 pairs), PriMock57 (57), MedSynth (10k+ SOAP pairs) into one JSONL chat schema with a task tag. These seed style; they are ED-thin.
2. **Synthetic ED generator** (cloud LLM, zero PHI): ~5–10k paired rows `{ED dialogue, gold extraction JSON, gold HPI/MDM note, gold discharge summary}` across the ED complaint distribution, with injected distractors, negations, and interruptions to match ambient audio.
3. **James's real pairs** (highest-value rows): WhisperKit STT locally -> **Philter** (Safe Harbor, ~99.5% recall) -> **Presidio** surrogate substitution (natural text, no `[REDACTED]` holes) -> **100% human review** of every row. Hold a slice out as the honest ED test set — never trained on. Raw audio and pre-scrub transcripts never leave the device.
4. **Assemble three task datasets:** ~60% synthetic ED / 20% public / 20% James's rows (upsampled 2–3×); train/valid/test splits each.
5. **Freeze schemas** (fact JSON, note template, discharge JSON) and compile them into decode-time grammars used identically in eval and the shipped runtime.
6. `mlx_lm.convert --hf-path meta-llama/Llama-3.2-3B-Instruct -q` once (4-bit base; pointing `mlx_lm.lora` at it auto-engages QLoRA).
7. **Train extraction first** (the factual backbone everything copies from): `mlx_lm.lora --model ./Llama-3.2-3B-Instruct-4bit --train --data ./data/extraction -c extraction.yaml` — start `lora_layers` 16, rank 8–16, alpha 16–32, batch 2–4, ~1000–2000 iters watching valid loss.
8. Train **note-assembly**, then **discharge**, against frozen extraction outputs.
9. **Eval gates per adapter** (CREOLA-style fact-level, deterministic grounding, on the held-out real-ED split): hallucination ≤1.47%, omission ≤3.45% (the ED-dangerous error — gate hard), factual correctness on supported facts, structure validity ~100% (constrained decoding should force this).
10. **Ship shape:** one shared 4-bit base (~1.8–2 GB) + three adapter files (do **not** fuse — fusing triples shipped weight). Re-run the full eval on the quantized shipped artifact (quantization can move error rates — gate on numbers, not "it loaded"). Bundle base+tokenizer+adapters as first-run download or app resources.
11. **Flywheel:** James's corrected/signed notes accumulate as new de-identified pairs; periodic re-fine-tune pulls the adapters toward his voice.

---

## 6. Build sequence — ordered PRs (each shippable/testable)

**Critical path: PR0 -> PR1 -> PR2 -> PR3 -> PR4 -> PR5.** PR6–PR9 layer on; T1–T3 (training) run in parallel off the critical path.

- **PR0 — Scorched earth + offline guarantee.** Delete `NotedCore_disabled_files/`, GroqService, all Anthropic/online paths; git-history PAT scrub (`git filter-repo`) + token revoke + gitleaks pre-commit; pin/resolve deps (swift-transformers conflict spike happens here — outcome feeds Decision #1); add offline CI guard test. *Test: app builds, launches, zero network egress, keyword-template note still produces output.*
- **PR1 — Durable store.** `NotedCoreKit` with `Encounter` + `GenerationJob` SwiftData models, phase state machine, non-destructive error recovery (rename-aside, never delete), one-time UserDefaults migrator, retire `PersistenceController`'s broken encounter path. *Test: create 30 encounters, kill app, all 30 reload with stable IDs.*
- **PR2 — Capture layer.** Single `CaptureController` actor, per-encounter audio files streamed to disk, `.playAndRecord` + audio background mode, stop->new-encounter in one tap, partial-file recovery on crash. Delete the two extra AVAudioEngines and `EncounterSessionManager`'s teardown-on-start behavior. *Test: record 3 encounters back-to-back; kill mid-recording; partial audio survives.*
- **PR3 — Queue + serial worker + mock engine.** `GenerationWorker`, `NoteEngine` protocol, `MockNoteEngine` (sim), job lifecycle, launch-time stale-job recovery, attempts/failed handling. *Test (simulator, mock): enqueue 5 encounters, jobs drain serially, kill mid-job, resumes correctly.*
- **PR4 — MLX graft.** Port EDScribePro's `MLXRunner.swift` + `AdvancedLLMPipeline.swift` behind `NoteEngine`; WhisperKit (or fallback per Decision #1) in `TranscriptionWorker`; model load/unload + `os_proc_available_memory` gating + increased-memory-limit entitlement. Device-only target. *Test (device): full transcript -> raw model note on real audio; record N+1 while N generates.*
- **PR5 — Quality pipeline.** Extraction grammar (token-mask sampler), fact JSON, deterministic HPI/MDM template, deterministic verifier, flagged-span review UI, staged checkpoints. First trained extraction adapter (T-track) slots in here when ready; until then the base model runs the same constrained schema. *Test: golden-transcript suite; verifier catches injected wrong-dose mutations.*
- **PR6 — Shift UI.** Encounter list with status badges, out-of-order review/edit/sign, remove all 10-encounter caps, disposition entry point on encounter detail. *Test: 25 encounters in mixed phases, sign in random order.*
- **PR7 — Governance.** `EngineGovernor` (thermal duty-cycling, memory-pressure shedding, battery bias), scenePhase + `beginBackgroundTask` + iOS 26 `BGContinuedProcessingTask` w/ GPU resource, MetricKit logging, timer replacement. *Test: instrumented backlog-drain on device from Hot state; memory-warning shed leaves recording untouched.*
- **PR8 — Discharge summary.** Results tray, disposition capture, discharge schema/grammar, precautions library, two renderings, FK/SMOG gate + simplify loop, cross-layer verifier, discharge jobs on the queue. *Test: HPI note -> hours-later dispo dictation -> both renderings; unordered-med injection blocked by verifier.*
- **PR9 — Adapter shipping + flywheel.** Adapter hot-swap in `MLXRunner`, first-run model download, eval-gated adapter versioning, corrected-note export pipeline (on-device, pre-scrub never leaves).
- **T1–T3 (parallel, separate repo `notedcore-training`):** T1 data plumbing + synthetic ED generator + de-id pipeline; T2 three adapter training runs + eval harness; T3 quantized-artifact re-eval + packaging. T2's extraction adapter is the only training deliverable on the app's quality-critical path (lands in PR5+).

---

## 7. Decisions James must make first

> **RESOLVED 2026-07-08:**
> 1. **STT** — decide by PR0 spike. Fight for WhisperKit; if the swift-transformers 1.0.0 pin won't resolve cleanly, ship Apple Speech (`SFSpeechRecognizer`, on-device) for v1 and revisit. Extraction+verification tolerate moderate STT noise.
> 2. **Deployment target** — **iOS 26.** His own iPhone 16 Pro Max, single user. Take the modern background/GPU APIs.
> 3. **Real-data training** — **small first batch, then decide.** Run 25–50 real encounters through the de-id loop (WhisperKit → Philter → Presidio → 100% manual review) in one sitting, train, measure the quality delta vs synthetic-only, then decide on the recurring flywheel (PR9).


1. **STT engine: fight for WhisperKit, or take Apple Speech?** The swift-transformers 1.0.0 pin conflict with MLX-Swift is the gating unknown (PR0 spike). WhisperKit = better medical-vocabulary accuracy + a model you control, but ~0.6–1 GB of the memory budget and the dep fight; Apple `SFSpeechRecognizer` (on-device mode) = zero memory/dep cost, weaker on drug names, Apple-controlled. **Recommendation: spike the dep conflict in PR0 for one day; if unresolvable via version pinning/forking, ship Apple Speech for v1 and revisit — extraction+verification downstream tolerates moderate STT noise, and this de-risks the critical path.**
2. **Minimum deployment target: iOS 26 or iOS 18?** iOS 26 unlocks `BGContinuedProcessingTask` + Background GPU Access (the only legitimate keep-generating-after-backgrounding path) and current SwiftData. iOS 18 keeps his device options open but the background story degrades to "resume on foreground" only. **Recommendation: iOS 26 — it's his own iPhone 16 Pro Max, single-user; take the modern APIs.**
3. **Real-data training commitment: will he run the de-identification loop?** The 20% James-voice slice (Philter -> Presidio -> 100% manual review of every row) is what makes the adapters *his* — but it's recurring personal effort per batch of notes. If no: adapters train on synthetic+public only (still good, generic voice) and the flywheel PR9 shrinks. **Recommendation: commit to a small first batch (25–50 encounters, one review sitting) before the first note-assembly training run; decide on the recurring flywheel after seeing the quality delta.**

Supporting decision already made for him unless he objects: model stays **resident while the queue is active, shed under pressure** (Section 2) — the alternative (load/unload per job) costs seconds and battery 25×/shift for headroom he doesn't need with bounded KV caches.