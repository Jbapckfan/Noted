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

        let modelPath = Bundle.main.path(forResource: "Llama-3.2-3B-Instruct-4bit", ofType: nil) ?? ""
        self.worker = GenerationWorker(
            container: container,
            engine: NoteEngineFactory.make(audioDirectory: audioDir, modelPath: modelPath)
        )

        reload()
        Task {
            _ = await worker.recoverAndDrain()
            reload()
            #if targetEnvironment(simulator)
            await seedDemoIfEmpty()
            #endif
        }
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

    private func fetch(_ id: UUID) -> Encounter? {
        try? context.fetch(FetchDescriptor<Encounter>(predicate: #Predicate { $0.id == id })).first
    }

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; return f
    }()
}

struct ShiftListView: View {
    let model: ShiftViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                if model.encounters.isEmpty {
                    ContentUnavailableView(
                        "No encounters yet",
                        systemImage: "waveform",
                        description: Text("Tap the mic to record your first encounter.")
                    )
                } else {
                    List {
                        ForEach(model.encounters, id: \.id) { encounter in
                            NavigationLink(value: encounter.id) {
                                EncounterRow(encounter: encounter)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .safeAreaPadding(.bottom, 120)
                }
                recordControl
            }
            .navigationTitle("Shift")
            .navigationDestination(for: UUID.self) { id in
                if let encounter = model.encounters.first(where: { $0.id == id }) {
                    EncounterDetailView(
                        encounter: encounter,
                        onSign: { model.sign(encounter) },
                        onDictateDisposition: { model.dictateDisposition(for: encounter) }
                    )
                }
            }
        }
    }

    private var recordControl: some View {
        VStack(spacing: 8) {
            if model.isProcessing {
                Label("Generating note…", systemImage: "sparkles")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button(action: model.toggleRecording) {
                Image(systemName: model.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(model.isRecording ? Color.red : Color.blue, in: Circle())
                    .shadow(radius: 10, y: 4)
            }
            .accessibilityIdentifier("recordButton")
            .disabled(model.isProcessing)
            Text(model.isRecording ? "Recording — tap to stop" : "Tap to record")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.bottom, 20)
    }
}

private struct EncounterRow: View {
    let encounter: Encounter

    var body: some View {
        let status = ShiftBoard.status(for: encounter.phase)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: status.badge))
                .frame(width: 4, height: 38)
            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.chiefComplaint.isEmpty ? "New encounter" : encounter.chiefComplaint)
                    .font(.headline).lineLimit(1)
                Text(encounter.updatedAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
            ShiftRowBadge(status: status)
        }
        .padding(.vertical, 4)
    }
}

private struct ShiftRowBadge: View {
    let status: EncounterStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(color(for: status.badge).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: status.badge))
    }
}

private func color(for badge: EncounterBadge) -> Color {
    switch badge {
    case .recording:           return .blue
    case .working:             return .secondary
    case .readyToSign:         return .orange
    case .awaitingDisposition: return .orange
    case .signed:              return .green
    case .failed:              return .red
    }
}
