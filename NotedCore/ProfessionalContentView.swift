import SwiftUI
import AVFoundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ProfessionalContentView: View {
    @EnvironmentObject private var appState: CoreAppState
    @StateObject private var processor = RealtimeMedicalProcessor.shared
    @StateObject private var audioService = AudioCaptureService()
    @StateObject private var whisperService = ProductionWhisperService.shared
    @ObservedObject private var tracker = KeyUtteranceTracker.shared
    @State private var isRecording = false
    @State private var recordingTime: TimeInterval = 0
    @State private var pulseAnimation = false
    @State private var transcriptionConfidence: Float = 0.0
    @State private var isEditingTranscript = false
    @State private var manualTranscript: String = ""
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Premium gradient background
            LinearGradient(
                colors: [Color(hex: "1a1c3d"), Color(hex: "2d3561")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Professional header
                headerView
                
                // Live transcription area + Editor toggle
                liveTranscriptionView
                    .animation(.easeInOut, value: processor.liveTranscript)
                // Reminder banner for due actions/commitments
                ReminderBannerView()
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                if isEditingTranscript {
                    transcriptEditor
                        .transition(.opacity)
                }
                
                // Speaker lanes
                SpeakerLanesView()
                    .padding(.top, 6)
                
                // Smart note preview
                if !processor.structuredNote.isEmpty {
                    smartNotePreview
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                
                Spacer()
                
                // Professional recording controls and test tools
                recordingControlsView
                testingToolsView
                actionChecklistView
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NotedCore")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        if !appState.currentRoom.isEmpty {
                            StatusPill(text: "Room \(appState.currentRoom)", color: .blue)
                        }
                        if !appState.currentChiefComplaint.isEmpty {
                            StatusPill(text: appState.currentChiefComplaint, color: .purple)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        // Status indicators
                        StatusPill(
                            text: whisperService.modelQuality.displayName,
                            color: whisperService.isLoading ? .orange : .green
                        )
                        
                        if isRecording {
                            StatusPill(
                                text: "Recording",
                                color: .red,
                                isPulsing: true
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Session timer
                if isRecording {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTime(recordingTime))
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                        Text("Session Time")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .onReceive(timer) { _ in
                        if isRecording {
                            recordingTime += 0.1
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
        }
        .background(
            Color.black.opacity(0.3)
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Live Transcription
    
    private var liveTranscriptionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Label("Live Transcription", systemImage: "waveform")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                    
                    Button(action: { isEditingTranscript.toggle() }) {
                        Image(systemName: isEditingTranscript ? "pencil.slash" : "pencil")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                
                // Current speaker indicator
                    if isRecording {
                        let speaker = VoiceIdentificationEngine.shared.activeSpeaker
                        HStack(spacing: 4) {
                            Text(speaker.icon)
                                .font(.system(size: 12))
                            Text(speaker.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color(hex: speaker.color))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(hex: speaker.color).opacity(0.2))
                        )
                    }
                }
                
                Spacer()
                
                // Confidence indicator
                if isRecording && whisperService.transcriptionQuality > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(confidenceColor(whisperService.transcriptionQuality))
                        
                        Text("\(Int(whisperService.transcriptionQuality * 100))%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(confidenceColor(whisperService.transcriptionQuality).opacity(0.2))
                    )
                }
                
                if isRecording {
                    HStack(spacing: 4) {
                        ForEach(0..<3) { i in
                            Circle()
                                .fill(Color.green)
                                .frame(width: 4, height: 4)
                                .opacity(pulseAnimation ? 1.0 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(i) * 0.2),
                                    value: pulseAnimation
                                )
                        }
                    }
                    .onAppear { pulseAnimation = true }
                    .onDisappear { pulseAnimation = false }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if processor.liveTranscript.isEmpty && !isRecording {
                            Text("Tap the microphone to begin dictation")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                                .italic()
                        } else {
                            Text(processor.liveTranscript)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white.opacity(0.9))
                                .lineSpacing(4)
                                .textSelection(.enabled)
                            
                            // Auto-scroll anchor
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .onChange(of: processor.liveTranscript) { _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: 250)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Transcript Editor
    private var transcriptEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Edit Transcript (Paste to test)", systemImage: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
                Button(action: {
                    manualTranscript = processor.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                }) {
                    Text("Load Live")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            }
            .padding(.horizontal, 20)
            
            TextEditor(text: $manualTranscript)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.white.opacity(0.95))
                .frame(minHeight: 120, maxHeight: 200)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 16)
            
            HStack(spacing: 12) {
                Button(action: {
                    #if os(iOS)
                    UIPasteboard.general.string = manualTranscript
                    #else
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(manualTranscript, forType: .string)
                    #endif
                }) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Button(action: runSummarizerOnManualTranscript) {
                    Label("Summarize", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }
    
    // MARK: - Smart Note Preview
    
    private var smartNotePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Medical Note", systemImage: "doc.text.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                Button(action: copyNote) {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            ScrollView {
                Text(processor.structuredNote)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Recording Controls
    
    private var recordingControlsView: some View {
        VStack(spacing: 20) {
            // Main recording button
            Button(action: toggleRecording) {
                ZStack {
                    // Outer ring animation
                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 3)
                            .frame(width: 100, height: 100)
                            .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                            .opacity(pulseAnimation ? 0.0 : 1.0)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                                value: pulseAnimation
                            )
                    }
                    
                    // Main button
                    Circle()
                        .fill(isRecording ? Color.red : Color.white)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(isRecording ? .white : Color(hex: "1a1c3d"))
                        )
                        .shadow(color: isRecording ? .red.opacity(0.5) : .white.opacity(0.3),
                               radius: 15, x: 0, y: 5)
                }
            }
            .scaleEffect(isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3), value: isRecording)
            
            // Status text
            Text(isRecording ? "Listening..." : "Tap to start")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            
            // Quick actions
            HStack(spacing: 40) {
                ProfessionalQuickActionButton(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Previous",
                    action: {}
                )
                .disabled(true)
                .opacity(0.5)
                
                ProfessionalQuickActionButton(
                    icon: "square.and.arrow.up",
                    label: "Export",
                    action: exportNote
                )
                .disabled(processor.structuredNote.isEmpty)
                .opacity(processor.structuredNote.isEmpty ? 0.5 : 1.0)
                
                ProfessionalQuickActionButton(
                    icon: "ellipsis.circle",
                    label: "More",
                    action: {}
                )
            }
            .padding(.top, 10)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Testing Tools / Status
    private var testingToolsView: some View {
        VStack(spacing: 8) {
            // Status ribbon
            HStack(spacing: 8) {
                StatusPill(
                    text: ProductionWhisperService.shared.getModelStatus(),
                    color: .purple
                )
                StatusPill(
                    text: ProductionMedicalSummarizerService.shared.statusMessage,
                    color: .blue
                )
                StatusPill(
                    text: "Quality: \(Int(ProductionMedicalSummarizerService.shared.overallQualityScore * 100))%",
                    color: .green
                )
                StatusPill(
                    text: ProductionWhisperService.shared.getPerformanceSummary(),
                    color: .orange
                )
                StatusPill(text: appState.activeMicrophone.displayName, color: .gray)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
            
            // Specialty preset picker (default ED)
            HStack {
                Text("Specialty")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                Picker("Specialty", selection: $appState.specialty) {
                    Text("ED").tag(CoreAppState.MedicalSpecialty.emergency)
                    Text("Hospital Medicine").tag(CoreAppState.MedicalSpecialty.hospitalMedicine)
                    Text("Clinic").tag(CoreAppState.MedicalSpecialty.clinic)
                    Text("Urgent Care").tag(CoreAppState.MedicalSpecialty.urgentCare)
                }
                .pickerStyle(.segmented)
                .colorScheme(.dark)
                Spacer()
                Button(action: summarizeNow) {
                    Label("Summarize Now", systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 4)
        }
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        withAnimation(.spring()) {
            if isRecording {
                audioService.stop()
                processor.finalizeNote()
                isRecording = false
                // Stop Apple Speech recognition in parallel
                Task { @MainActor in
                    await SpeechRecognitionService.shared.stopTranscription()
                }
            } else {
                Task {
                    processor.reset()
                    // TranscriptionEnsembler.shared.reset() // TODO: Re-enable when TranscriptionEnsembler is available
                    recordingTime = 0
                    do {
                        try await audioService.start()
                        isRecording = true
                        // Start Apple Speech recognition in parallel
                        try? await SpeechRecognitionService.shared.startTranscription()
                    } catch {
                        print("Error starting recording: \(error)")
                    }
                }
            }
        }
    }
    
    private func copyNote() {
        #if os(iOS)
        UIPasteboard.general.string = processor.structuredNote
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(processor.structuredNote, forType: .string)
        #endif
    }
    
    private func exportNote() {
        // Export functionality
        copyNote() // For now just copy
    }
    
    private func runSummarizerOnManualTranscript() {
        let text = manualTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await ProductionMedicalSummarizerService.shared.generateComprehensiveMedicalNote(
                from: text,
                noteType: .edNote
            )
            await MainActor.run {
                self.processor.structuredNote = ProductionMedicalSummarizerService.shared.generatedNote
            }
        }
    }

    private func summarizeNow() {
        let text = processor.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            await ProductionMedicalSummarizerService.shared.generateComprehensiveMedicalNote(
                from: text,
                noteType: .edNote
            )
            await MainActor.run {
                self.processor.structuredNote = ProductionMedicalSummarizerService.shared.generatedNote
            }
        }
    }

    // MARK: - Orders & Actions Panel (grouped)
    private var actionChecklistView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Orders & Actions", systemImage: "list.bullet.rectangle.portrait")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal, 20)
            
            let groups = Dictionary(grouping: tracker.items.filter{ !$0.completed }) { $0.kind }
            let kinds: [KeyUtteranceTracker.ActionItem.Kind] = [.order, .medication, .imaging, .consult, .instruction, .commitment]
            ForEach(kinds, id: \.self) { kind in
                if let items = groups[kind], !items.isEmpty {
                    HStack {
                        Text(kind.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.75))
                        Text("\(items.count)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            Image(systemName: item.completed ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.completed ? .green : .white.opacity(0.6))
                                .onTapGesture { KeyUtteranceTracker.shared.markCompleted(item) }
                            Text(item.title)
                                .foregroundColor(.white.opacity(0.92))
                                .font(.system(size: 13))
                                .lineLimit(1)
                            if let d = item.detail { Text("— \(d)").foregroundColor(.white.opacity(0.6)).font(.system(size: 12)) }
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .yellow
        case 0.4..<0.6:
            return .orange
        default:
            return .red
        }
    }
}

// MARK: - Supporting Views

struct StatusPill: View {
    let text: String
    let color: Color
    var isPulsing: Bool = false
    
    var body: some View {
        HStack(spacing: 4) {
            if isPulsing {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
            }
            
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(color.opacity(0.4), lineWidth: 1)
                )
        )
    }
}

struct ProfessionalQuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(label)
                    .font(.system(size: 11))
            }
            .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Color Extension

// Color extension moved to ColorExtensions.swift
