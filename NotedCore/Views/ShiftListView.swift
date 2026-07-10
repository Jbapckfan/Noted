//  ShiftListView.swift
//  The app's real root (the offline rearchitecture UI): the shift board + a record→note→sign flow,
//  driven by NotedCoreKit. Thin SwiftUI shell over the tested logic (ShiftBoard, CaptureController,
//  GenerationWorker). In the Simulator the engine is the deterministic mock and audio is synthetic,
//  so the whole pipeline runs end-to-end without a GPU or a mic.

import SwiftUI
import SwiftData
import NotedCoreKit

@MainActor
@Observable
final class ShiftViewModel {
    let container: ModelContainer
    private let context: ModelContext
    private let capture: CaptureController
    private let worker: GenerationWorker
    private let engine: NoteEngine

    /// On-device model download/load state (shows a banner on first run).
    let modelHost = ModelHost.shared

    private(set) var encounters: [Encounter] = []
    var isRecording = false
    var isProcessing = false
    private var currentEncounterID: UUID?

    init() {
        let support = URL.applicationSupportDirectory.appending(path: "NotedCore", directoryHint: .isDirectory)
        let storeURL = support.appending(path: "encounters.store")
        let audioDir = support.appending(path: "audio", directoryHint: .isDirectory)

        self.container = (try? EncounterStore.makeContainer(at: storeURL))
            ?? (try! EncounterStore.inMemoryContainer())
        self.context = ModelContext(container)
        try? LegacyMigration.runIfNeeded(context: context)

        #if targetEnvironment(simulator)
        let input: AudioInput = SimulatorAudioInput()
        #else
        let input: AudioInput = AVAudioEngineInput()
        #endif
        self.capture = CaptureController(audioDirectory: audioDir, input: input)

        let engine = NoteEngineFactory.make(audioDirectory: audioDir)
        self.engine = engine
        self.worker = GenerationWorker(container: container, engine: engine)

        reload()
        Task {
            _ = await worker.recoverAndDrain()
            reload()
            #if targetEnvironment(simulator)
            modelHost.update(.ready)   // no download in the simulator (mock)
            await seedDemoIfEmpty()
            #elseif canImport(MLXLLM)
            // Start the model download/load early so the first note isn't blocked.
            if let onDevice = engine as? OnDeviceNoteEngine { await onDevice.warmup() }
            #endif
        }
    }

    /// Delete an encounter (swipe-to-delete) and its audio file. Irreversible.
    func delete(_ encounter: Encounter) {
        if let rel = encounter.audioFileRelPath {
            let url = URL.applicationSupportDirectory
                .appending(path: "NotedCore/audio", directoryHint: .isDirectory)
                .appending(path: rel)
            try? FileManager.default.removeItem(at: url)
        }
        try? ShiftBoard.delete(encounter, in: context)
        reload()
    }

    /// Simulator only: run one demo encounter through the pipeline on first launch so the board
    /// isn't empty and the offline flow is visible end-to-end.
    private func seedDemoIfEmpty() async {
        guard encounters.isEmpty else { return }
        let e = Encounter(chiefComplaint: "Chest pain", phase: .captured)
        e.audioFileRelPath = "\(e.id.uuidString).wav"
        context.insert(e)
        try? context.save()
        try? GenerationQueue.startNotePipeline(for: e, in: context)
        await worker.drain()
        reload()
    }

    func reload() {
        encounters = (try? ShiftBoard.fetchAllForDisplay(in: context)) ?? []
    }

    func toggleRecording() {
        Task { isRecording ? await stopRecording() : await startRecording() }
    }

    private func startRecording() async {
        let e = Encounter(chiefComplaint: "Recording…", phase: .recording)
        context.insert(e)
        try? context.save()
        currentEncounterID = e.id
        do {
            _ = try await capture.begin(encounterID: e.id)
            isRecording = true
        } catch {
            context.delete(e)
            try? context.save()
        }
        reload()
    }

    private func stopRecording() async {
        isRecording = false
        guard let id = currentEncounterID else { return }
        currentEncounterID = nil
        isProcessing = true
        defer { isProcessing = false }

        if let result = try? await capture.end(), let e = fetch(id) {
            e.audioFileRelPath = result.audioFileRelPath
            e.recordingDuration = result.duration
            e.chiefComplaint = "Encounter " + Self.time.string(from: Date())
            e.transition(to: .captured)
            try? context.save()
            try? GenerationQueue.startNotePipeline(for: e, in: context)
        }
        reload()
        await worker.drain()   // mock runs transcribe→extract→note
        reload()
    }

    func sign(_ e: Encounter) {
        _ = try? ShiftBoard.sign(e, in: context)
        reload()
    }

    func dictateDisposition(for e: Encounter) {
        Task {
            isProcessing = true
            defer { isProcessing = false }
            e.dispositionTranscript = "Patient reassessed and improved; discharge home with follow-up."
            e.resultsTrayJSON = "{}"
            e.transition(to: .dispositionCaptured)
            try? context.save()
            try? GenerationQueue.startDischargePipeline(for: e, in: context)
            await worker.drain()
            reload()
        }
    }

    /// Create an encounter directly from typed/pasted transcript text and run the summarizer
    /// (extract → grounded note), skipping audio capture. This is the manual test path: drop in a
    /// transcript, get the note the LLM + grounding produce from it.
    func generateFromTranscript(_ text: String, chiefComplaint: String = "Pasted transcript") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            isProcessing = true
            defer { isProcessing = false }
            let e = Encounter(chiefComplaint: chiefComplaint, phase: .transcribed, source: .manualTest)
            e.transcript = trimmed
            context.insert(e)
            try? context.save()
            try? GenerationQueue.enqueue(.extract, for: e, in: context)   // extract → note
            reload()
            await worker.drain()
            reload()
        }
    }

    /// Re-run the summarizer on an encounter's (possibly hand-edited) transcript. Overwrites the
    /// prior note with a fresh extract → grounded note from the current transcript text.
    func regenerateNote(for e: Encounter) {
        guard let t = e.transcript, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            isProcessing = true
            defer { isProcessing = false }
            e.transition(to: .transcribed)
            e.updatedAt = Date()
            try? context.save()
            try? GenerationQueue.enqueue(.extract, for: e, in: context)
            reload()
            await worker.drain()
            reload()
        }
    }

    private func fetch(_ id: UUID) -> Encounter? {
        try? context.fetch(FetchDescriptor<Encounter>(predicate: #Predicate { $0.id == id })).first
    }

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()
}

struct ShiftListView: View {
    let model: ShiftViewModel
    @State private var showPaste = false

    var body: some View {
        NavigationStack {
            Group {
                if model.encounters.isEmpty {
                    emptyState
                } else {
                    board
                }
            }
            .navigationTitle("Shift")
            .safeAreaInset(edge: .top) { banner }
            .safeAreaInset(edge: .bottom) { actionDock }
            .sheet(isPresented: $showPaste) {
                TranscriptEntryView { model.generateFromTranscript($0) }
            }
            .navigationDestination(for: UUID.self) { id in
                if let encounter = model.encounters.first(where: { $0.id == id }) {
                    EncounterDetailView(
                        encounter: encounter,
                        onSign: { model.sign(encounter) },
                        onDictateDisposition: { model.dictateDisposition(for: encounter) },
                        onRegenerate: { model.regenerateNote(for: encounter) }
                    )
                }
            }
        }
        .tint(Theme.accent)
    }

    // Grouped by the clinical action each encounter needs — scannable at a glance.
    private var board: some View {
        List {
            ForEach(BoardSection.allCases, id: \.self) { section in
                let items = model.encounters.filter { BoardSection.of($0) == section }
                if !items.isEmpty {
                    Section(section.title) {
                        ForEach(items, id: \.id) { encounter in
                            NavigationLink(value: encounter.id) {
                                EncounterRow(encounter: encounter)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    model.delete(encounter)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No encounters this shift", systemImage: "waveform")
        } description: {
            Text("Record at the bedside. Audio, transcripts, and notes stay on this iPhone.")
        }
    }

    @ViewBuilder private var banner: some View {
        if let banner = model.modelHost.banner {
            Label(banner, systemImage: "lock.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.s2)
                .background(.thinMaterial)
        }
    }

    // Persistent bottom dock: recording is the dominant bedside action; paste-test is subordinate.
    private var actionDock: some View {
        VStack(spacing: Theme.s2) {
            if model.isProcessing {
                Label {
                    Text("Processing on device…")
                } icon: {
                    ProgressView().controlSize(.mini)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: Theme.s3) {
                Button(action: model.toggleRecording) {
                    Label(model.isRecording ? "Stop recording" : "Record encounter",
                          systemImage: model.isRecording ? "stop.fill" : "mic.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isRecording ? Theme.recording : Theme.accent)
                .accessibilityIdentifier("recordButton")
                .disabled(model.isProcessing && !model.isRecording)

                Button {
                    showPaste = true
                } label: {
                    Label("Paste test", systemImage: "doc.on.clipboard")
                        .frame(minHeight: Theme.primaryControlHeight)
                        .padding(.horizontal, Theme.s2)
                }
                .buttonStyle(.bordered)
                .tint(Theme.accent)
                .disabled(model.isProcessing)
            }
        }
        .padding(.horizontal, Theme.s4)
        .padding(.top, Theme.s3)
        .padding(.bottom, Theme.s2)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }
}

/// The shift board's buckets — every encounter falls in exactly one, ordered by attention.
private enum BoardSection: CaseIterable {
    case needsAction, inProgress, test, completed

    var title: String {
        switch self {
        case .needsAction: return "Needs action"
        case .inProgress:  return "In progress"
        case .test:        return "Test inputs"
        case .completed:   return "Completed"
        }
    }

    static func of(_ e: Encounter) -> BoardSection {
        if e.phase == .signed { return .completed }
        if e.source == .manualTest { return .test }
        return ShiftBoard.status(for: e.phase).needsAttention ? .needsAction : .inProgress
    }
}

private struct EncounterRow: View {
    let encounter: Encounter

    var body: some View {
        let status = ShiftBoard.status(for: encounter.phase)
        HStack(spacing: Theme.s3) {
            VStack(alignment: .leading, spacing: Theme.s1) {
                Text(encounter.chiefComplaint.isEmpty ? "New encounter" : encounter.chiefComplaint)
                    .font(.body.weight(.semibold))
                    .lineLimit(2)
                HStack(spacing: Theme.s2) {
                    Text(encounter.createdAt, format: .dateTime.hour().minute())
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if encounter.source == .manualTest {
                        Text("TEST")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 4))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            Spacer(minLength: Theme.s2)
            StatusBadgeView(status: status)
        }
        .padding(.vertical, Theme.s1)
        .frame(minHeight: Theme.rowMinHeight)
    }
}

private struct StatusBadgeView: View {
    let status: EncounterStatus

    var body: some View {
        if status.badge == .working {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text(status.label).font(.caption)
            }
            .foregroundStyle(.secondary)
        } else {
            Label(status.label, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .padding(.horizontal, Theme.s2).padding(.vertical, 4)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: Theme.badgeRadius))
        }
    }

    // "Ready to sign" is an available action, not a warning → accent, not orange.
    private var tint: Color {
        switch status.badge {
        case .recording:           return Theme.recording
        case .working:             return .secondary
        case .readyToSign:         return Theme.accent
        case .awaitingDisposition: return Theme.caution
        case .signed:              return Theme.signed
        case .failed:              return Theme.recording
        }
    }

    private var symbol: String {
        switch status.badge {
        case .recording:           return "record.circle.fill"
        case .working:             return "hourglass"
        case .readyToSign:         return "signature"
        case .awaitingDisposition: return "clock"
        case .signed:              return "checkmark.seal.fill"
        case .failed:              return "exclamationmark.circle.fill"
        }
    }
}

/// Drop-in test path: paste/type a transcript and push it straight to the on-device summarizer,
/// bypassing audio capture. Lets you exercise the LLM + grounding on arbitrary transcripts.
struct TranscriptEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var confirmDiscard = false
    var onGenerate: (String) -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("TEST INPUT · ON DEVICE", systemImage: "lock.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    PasteButton(payloadType: String.self) { strings in
                        if let s = strings.first { text = s }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, Theme.s4)
                .padding(.vertical, Theme.s2)
                Divider()
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $text)
                        .font(.body)
                        .textInputAutocapitalization(.sentences)
                        .padding(Theme.s3)
                        .scrollContentBackground(.hidden)
                    if text.isEmpty {
                        Text("Paste or type an ED transcript, then Generate to run the on-device summarizer on it — no recording needed.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, Theme.s4)
                            .padding(.vertical, Theme.s4 + 4)
                            .allowsHitTesting(false)
                    }
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("Test transcript")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { trimmed.isEmpty ? dismiss() : (confirmDiscard = true) }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onGenerate(trimmed)
                    dismiss()
                } label: {
                    Label("Generate note", systemImage: "doc.text")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(trimmed.isEmpty)
                .padding(.horizontal, Theme.s4)
                .padding(.vertical, Theme.s2)
                .background(.bar)
            }
            .confirmationDialog("Discard this transcript?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
        }
    }
}
