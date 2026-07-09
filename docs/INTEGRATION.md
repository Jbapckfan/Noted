# NotedCore — Integration Guide

The offline rearchitecture (PR0–PR9) landed the whole clinical pipeline as a tested Swift package
(`NotedCoreKit`, 87 passing tests) plus device-only glue in the app target. This guide is the
one-sitting Xcode pass that wires it into a running app.

**Do it in order.** After step 4 you can run the *entire* pipeline in the Simulator with the mock
engine — record → queue → note → discharge → sign — before touching MLX. That's the checkpoint.

---

## 0. Security (do this first, on GitHub)

A GitHub PAT is in this repo's git history (commits `0bdc25a`, `3a5d739`). **Revoke it**:
GitHub → Settings → Developer settings → Personal access tokens → revoke the token for
`Jbapckfan/Noted`. Revoking is the real fix (it's inert everywhere once revoked). The local remote
was already reset to tokenless in PR0.

## 1. Add NotedCoreKit to the app target

Xcode → **File → Add Package Dependencies… → Add Local…** → select the `NotedCoreKit/` folder →
add the `NotedCoreKit` library product to the **NotedCore** target (and the Watch target if it
needs it). Build. `import NotedCoreKit` now resolves in the app.

## 2. Entitlements, Info.plist, capabilities

- **Increased memory limit**: target → Signing & Capabilities → **+ Capability → Increased Memory
  Limit** (adds `com.apple.developer.kernel.increased-memory-limit`). The ~2 GB 4-bit model needs it.
- **Background audio**: Signing & Capabilities → Background Modes → check **Audio**. (Lets capture
  survive backgrounding.)
- **Bluetooth mic**: handled in code — `AVAudioEngineInput` uses `.allowBluetooth` (HFP input
  profile), prefers a connected BT mic via the tested `AudioRoutePolicy`, and rebuilds the tap on
  route changes so a BT device connecting/dropping mid-encounter doesn't break capture. Verify on
  device with your actual BT mic; if you need to force the built-in mic, set
  `AVAudioEngineInput(manualPreference: .builtIn)`.
- **iOS 26 background generation** (optional, best-effort): Background Modes → **Background
  processing**; register the `BGContinuedProcessingTask` in step 6.
- **Info.plist**: `NSMicrophoneUsageDescription` (mic), and `NSSpeechRecognitionUsageDescription`
  if you keep Apple Speech as the STT fallback.

## 3. Bundle the model

Drop the 4-bit MLX model directory (e.g. `Llama-3.2-3B-Instruct-4bit/`) into the app bundle (Copy
Bundle Resources), or wire a first-run download. `MLXNoteEngine(modelPath:)` takes the on-disk path
(`Bundle.main.path(...)`). Adapters (extraction/note/discharge `.safetensors`) go alongside once
trained — do NOT fuse them.

## 4. Construct the pipeline once, at app root

In `NotedCoreApp` (or a small composition root), build these once and inject:

```swift
import NotedCoreKit

// Durable store (non-destructive recovery built in)
let container = try EncounterStore.makeContainer(at: storeURL)   // e.g. App Support/encounters.store
let context = ModelContext(container)

// One-time migration off the legacy saved_encounters UserDefaults
try? LegacyMigration.runIfNeeded(context: context)

// Audio directory for per-encounter WAVs
let audioDir = URL.applicationSupportDirectory.appending(path: "audio")

// Capture (the ONE engine) — real mic on device, feeds CaptureController
let capture = CaptureController(audioDirectory: audioDir, input: AVAudioEngineInput())

// Engine: mock in the Simulator, real MLX+Whisper on device
let engine = NoteEngineFactory.make(audioDirectory: audioDir, modelPath: modelPath)

// Serial worker + governor
let worker = GenerationWorker(container: container, engine: engine, governor: SystemGovernor())

// Shift UI
ShiftListView(model: EncounterListModel(context: context))
```

**At this point, build for the Simulator and run.** `NoteEngineFactory` returns `MockNoteEngine`
there, so the full flow works with no GPU: record (fake audio), watch jobs drain to `.noteDrafted`,
sign in any order, dictate a disposition → discharge. This is the "see it work" moment.

### Driving the flow
- **New encounter / stop→next**: `let url = try await capture.begin(encounterID: e.id)` … then a
  single `try await capture.endAndBegin(nextEncounterID: next.id)` for the one-tap handoff. On `end`,
  set `e.audioFileRelPath = result.audioFileRelPath`, `e.transition(to: .captured)`, and
  `try GenerationQueue.startNotePipeline(for: e, in: context)`, then `await worker.drain()`.
- **Disposition (hours later)**: from `EncounterDetailView`'s "Dictate disposition", capture into
  `e.dispositionAudioRelPath` / `e.dispositionTranscript`, then
  `GenerationQueue.startDischargePipeline(for: e, in: context)` → `worker.drain()`.
- **Launch recovery**: on startup call `await worker.recoverAndDrain()` and, for any encounter left
  `.recording`, `capture.recoverPartialRecording(relPath:)`.

## 5. Cut over the legacy code (retire, don't fork)

- Route the app's **six** `AVAudioEngine` owners (`AudioCaptureService`,
  `LiveTranscriptionImplementation`, `SpeechRecognitionService`, `VoiceCommandService`,
  `VoiceCommandProcessor`, `RealTimeBluetoothAudioManager`) through the single `CaptureController` /
  `AVAudioEngineInput`. Delete the redundant engines.
- Replace `EncounterManager` / `EncounterSessionManager` persistence with the SwiftData store; drop
  the `saved_encounters` UserDefaults path (the one-time migrator carries old data forward).
- Retire `PersistenceController` (the CoreData path is non-functional — its delete-bomb was already
  defanged in PR1, but the store itself is dead scaffolding).
- Make the root view `ShiftListView`.

## 6. Lifecycle wiring (in `NotedCoreApp`)

- Observe `scenePhase`; on `.background` wrap in-flight stage commits with `beginBackgroundTask`.
- iOS 26: register a `BGContinuedProcessingTask` (with GPU resource) to keep a generation going
  after backgrounding; kick `worker.drain()` from it.
- Replace the old main-run-loop `Timer`s (0.2 s transcription, 1 s duration, 30 s autosave) — the
  actors own their own cadence now.
- Add a `MetricKit` subscriber (`MXMetricManager`) to log jetsam/thermal/crash diagnostics locally.
- On a memory-pressure event, call `SystemGovernor.modelActionNow()` and unload accordingly
  (`MLXNoteEngine.unload()` / `WhisperTranscriber.unload()`), then `clearMemoryPressure()`.

## 7. Offline + secret guards (CI / pre-push)

- `sh Scripts/offline-guard.sh` — fails if any network egress reappears in engine sources
  (currently PASS). Wire it into CI / a pre-push hook.
- `git config core.hooksPath .githooks` on a fresh clone activates the secret-scan pre-commit hook.
  `brew install gitleaks` upgrades the scan.

## 8. Training track (separate repo `notedcore-training`, off the critical path)

- Data plumbing for ACI-Bench / MTS-Dialog / PriMock57 (already in `MedicalDatasets/`) +
  synthetic ED generation; James's real pairs via `TrainingFlywheel.pairs(from:)` → **Philter →
  Presidio → 100% manual review** before any training (raw audio never leaves the device).
- Train extraction → note → discharge adapters (`mlx_lm.lora`, QLoRA on the 4-bit base).
- Gate every adapter with `AdapterGate` on the held-out real-ED split; re-run the gate on the
  QUANTIZED artifact. Ship only `AdapterManifest.shippable(...)` bundles.
- Adversarial negatives are ready: `NotedCoreKit/Tests/.../Fixtures/verifier-test-matrix.json`.

---

## What's proven vs. what needs the device

**Proven here (87 `swift test` cases, no GPU):** durable store + non-destructive recovery + ID
stability, capture file-streaming + partial-recording repair + one-tap handoff, serial queue +
crash recovery + retry, extraction schema + deterministic template + grounding verifier (digit-exact,
anti-laundering) + golden ED cases, shift ordering/sign, discharge schema + copy-slot verifier +
two renderings + reading-level gate, governor policy, adapter gate + flywheel.

**Needs your device (correct-by-construction, verify on hardware):** `AVAudioEngineInput` (mic,
session, route changes), `MLXNoteEngine` (model load + generation + memory gating), `WhisperTranscriber`
(WhisperKit `transcribe(audioPath:)` — confirm against the pinned revision; `FixedWhisperService`
used `audioArray:`), and the app-root lifecycle wiring in step 6.
