import SwiftUI
import AVFoundation
import Combine

struct EncounterWorkflowView: View {
    @StateObject private var sessionManager = EncounterSessionManager.shared
    @StateObject private var liveTranscription = LiveTranscriptionEngine.shared
    @StateObject private var voiceCommands = VoiceCommandProcessor.shared
    @StateObject private var encounterManager = EncounterManager.shared
    @StateObject private var audioService = AudioCaptureService.shared
    
    @State private var selectedRoom: Room?
    @State private var chiefComplaint: String = ""
    @State private var showRoomPicker = false
    @State private var showNotePreview = false
    @State private var editMode = false
    @State private var showPhaseMenu = false
    @State private var showSessionHistory = false
    @State private var transcriptScrollProxy: ScrollViewProxy?
    @State private var selectedTextRange: NSRange?
    @State private var showAIAssistant = false
    @State private var currentWordCount = 0
    @State private var autoScrollEnabled = true
    
    // Advanced Features
    @State private var showTemplates = false
    @State private var showMacros = false
    @State private var showVoiceCommands = false
    @State private var confidenceThreshold: Double = 0.7
    @State private var showRedFlags = false
    
    var body: some View {
        NavigationView {
            if sessionManager.currentSession != nil {
                activeSessionView
            } else if showSessionHistory {
                sessionHistoryView
            } else {
                startSessionView
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Start Session View
    
    var startSessionView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "stethoscope.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                    .symbolRenderingMode(.hierarchical)
                
                Text("Start New Encounter")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Advanced Medical Documentation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            
            // Room Selection
            VStack(alignment: .leading, spacing: 12) {
                Label("Select Room", systemImage: "door.left.hand.open")
                    .font(.headline)
                
                Button(action: { showRoomPicker = true }) {
                    HStack {
                        Image(systemName: selectedRoom?.type.icon ?? "questionmark.circle")
                        Text(selectedRoom?.displayName ?? "Choose Room")
                        Spacer()
                        Image(systemName: "chevron.down")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding(.horizontal)
            
            // Chief Complaint
            VStack(alignment: .leading, spacing: 12) {
                Label("Chief Complaint", systemImage: "text.bubble")
                    .font(.headline)
                
                TextEditor(text: $chiefComplaint)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .frame(minHeight: 100)
                
                // Smart Suggestions
                if !chiefComplaint.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(getSmartSuggestions(), id: \.self) { suggestion in
                                Button(action: {
                                    chiefComplaint += " " + suggestion
                                }) {
                                    Text(suggestion)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Recent Sessions
            if !sessionManager.sessionHistory.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Recent Sessions", systemImage: "clock.arrow.circlepath")
                            .font(.headline)
                        Spacer()
                        Button("View All") {
                            showSessionHistory = true
                        }
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(sessionManager.sessionHistory.prefix(3)) { session in
                                RecentSessionCard(session: session) {
                                    sessionManager.resumeSession(session)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            Spacer()
            
            // Start Button
            Button(action: startNewEncounter) {
                Label("Start Recording", systemImage: "mic.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
            .padding()
            .disabled(selectedRoom == nil || chiefComplaint.isEmpty)
        }
        .sheet(isPresented: $showRoomPicker) {
            RoomPickerView(selectedRoom: $selectedRoom)
        }
        .sheet(isPresented: $showSessionHistory) {
            SessionHistoryView()
        }
    }
    
    // MARK: - Active Session View
    
    var activeSessionView: some View {
        VStack(spacing: 0) {
            // Session Header
            sessionHeaderView
            
            // Phase Indicator
            phaseIndicatorView
            
            // Main Content
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Transcription Panel
                    transcriptionPanel
                        .frame(width: geometry.size.width * (showNotePreview ? 0.5 : 1.0))
                    
                    // Note Preview Panel
                    if showNotePreview {
                        Divider()
                        notePreviewPanel
                            .frame(width: geometry.size.width * 0.5)
                    }
                }
            }
            
            // Control Bar
            controlBar
        }
        .navigationBarHidden(true)
    }
    
    var sessionHeaderView: some View {
        HStack {
            // Session Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: sessionManager.currentSession?.currentPhase.icon ?? "stethoscope")
                        .foregroundColor(.blue)
                    Text(sessionManager.currentSession?.currentPhase.rawValue ?? "")
                        .font(.headline)
                    
                    if sessionManager.isPaused {
                        Label("PAUSED", systemImage: "pause.circle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                HStack {
                    Text("Room: \(selectedRoom?.displayName ?? "")")
                    Text("•")
                    Text("Duration: \(formatDuration(sessionManager.currentSession?.activeDuration ?? 0))")
                    Text("•")
                    Text("\(currentWordCount) words")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Quick Actions
            HStack(spacing: 12) {
                // AI Assistant
                Button(action: { showAIAssistant.toggle() }) {
                    Image(systemName: "sparkles")
                        .foregroundColor(showAIAssistant ? .purple : .secondary)
                }
                
                // Red Flags
                Button(action: { showRedFlags.toggle() }) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(showRedFlags ? .red : .secondary)
                }
                
                // Templates
                Button(action: { showTemplates.toggle() }) {
                    Image(systemName: "doc.text")
                }
                
                // Note Preview Toggle
                Button(action: { withAnimation { showNotePreview.toggle() } }) {
                    Image(systemName: showNotePreview ? "sidebar.right" : "sidebar.left")
                }
                
                // End Session
                Button(action: { showEndSessionConfirmation() }) {
                    Image(systemName: "stop.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    var phaseIndicatorView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(EncounterPhaseType.allCases, id: \.self) { phase in
                    PhaseButton(
                        phase: phase,
                        isActive: sessionManager.currentPhase == phase,
                        isCompleted: sessionManager.currentSession?.phases[phase] != nil
                    ) {
                        sessionManager.transitionToPhase(phase)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemBackground))
    }
    
    var transcriptionPanel: some View {
        VStack(spacing: 0) {
            // Transcript Header
            HStack {
                Label("Live Transcript", systemImage: "waveform")
                    .font(.headline)
                
                Spacer()
                
                // Confidence Indicator
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield")
                    Text("\(Int(confidenceThreshold * 100))%")
                        .font(.caption)
                }
                .foregroundColor(.green)
                
                Toggle("Edit", isOn: $editMode)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                    .scaleEffect(0.8)
                
                Toggle("Auto-scroll", isOn: $autoScrollEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .scaleEffect(0.8)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Transcript Content
            ScrollViewReader { proxy in
                ScrollView {
                    if editMode {
                        TextEditor(text: $sessionManager.editableTranscript)
                            .padding()
                            .onChange(of: sessionManager.editableTranscript) { _ in
                                currentWordCount = sessionManager.editableTranscript.split(separator: " ").count
                            }
                    } else {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(sessionManager.currentSession?.transcriptionSegments ?? []) { segment in
                                TranscriptSegmentView(
                                    segment: segment,
                                    onEdit: { newText in
                                        updateSegment(segment, with: newText)
                                    }
                                )
                                .id(segment.id)
                            }
                            
                            // Live transcription text
                            if !liveTranscription.liveText.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "waveform.circle.fill")
                                            .foregroundColor(.blue)
                                            // Animation only available in iOS 17+
                                        Text("Live Transcription")
                                            .font(.caption)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    Text(liveTranscription.liveText)
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.blue.opacity(0.1))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                        )
                                }
                                .id("live-text")
                            }
                            
                            // Live indicator
                            if sessionManager.isRecording || liveTranscription.isTranscribing {
                                HStack {
                                    EncounterPulsingDot()
                                    Text(liveTranscription.isTranscribing ? "Transcribing..." : "Listening...")
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                                .id("live-indicator")
                            }
                        }
                        .padding()
                        .onChange(of: sessionManager.currentSession?.transcriptionSegments) { _ in
                            if autoScrollEnabled {
                                withAnimation {
                                    proxy.scrollTo("live-indicator", anchor: .bottom)
                                }
                            }
                        }
                    }
                }
                .onAppear {
                    transcriptScrollProxy = proxy
                }
            }
            
            // Smart Actions Bar
            if showAIAssistant {
                smartActionsBar
            }
        }
    }
    
    var notePreviewPanel: some View {
        VStack(spacing: 0) {
            // Note Type Selector
            HStack {
                Label("Note Format", systemImage: "doc.richtext")
                    .font(.headline)
                
                Spacer()
                
                Picker("Note Type", selection: $sessionManager.selectedNoteType) {
                    ForEach(NoteType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: sessionManager.selectedNoteType) { _ in
                    sessionManager.regenerateNoteWithType(sessionManager.selectedNoteType)
                }
                
                Button("Regenerate") {
                    sessionManager.generateNote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            
            Divider()
            
            // Generated Note
            ScrollView {
                if let note = sessionManager.generatedNote {
                    Text(note)
                        .padding()
                        .textSelection(.enabled)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        
                        Text("Note will appear here")
                            .foregroundColor(.secondary)
                        
                        Button("Generate Note") {
                            sessionManager.generateNote()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            
            // Export Options
            HStack {
                Button(action: copyToClipboard) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                
                Button(action: exportNote) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                
                Button(action: sendToEHR) {
                    Label("Send to EHR", systemImage: "paperplane")
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }
    
    var controlBar: some View {
        HStack(spacing: 20) {
            // Record/Pause Button
            Button(action: toggleRecording) {
                Image(systemName: sessionManager.isPaused ? "play.circle.fill" : "pause.circle.fill")
                    .font(.system(size: 44))
                    .foregroundColor(sessionManager.isPaused ? .green : .orange)
            }
            
            // Phase Navigation
            Button(action: { showPhaseMenu.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.title2)
                    Text("Next Phase")
                        .font(.caption)
                }
            }
            
            // Voice Commands
            Button(action: { 
                showVoiceCommands.toggle()
                if showVoiceCommands {
                    voiceCommands.startListening()
                } else {
                    voiceCommands.stopListening()
                }
            }) {
                VStack(spacing: 4) {
                    Image(systemName: voiceCommands.isListening ? "mic.fill" : "mic.badge.plus")
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)
                    Text("Commands")
                        .font(.caption)
                }
            }
            .foregroundColor(voiceCommands.isListening ? .blue : .primary)
            
            // Macros
            Button(action: { showMacros.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: "command")
                        .font(.title2)
                    Text("Macros")
                        .font(.caption)
                }
            }
            
            Spacer()
            
            // Audio Level Indicator
            AudioLevelIndicator(level: sessionManager.transcriptionBuffer.isEmpty ? 0 : 0.7)
            
            // Save Progress
            Button(action: saveProgress) {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.title2)
                    Text("Save")
                        .font(.caption)
                }
            }
            .foregroundColor(.green)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 1)
    }
    
    var smartActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                SmartActionButton(title: "Summarize", icon: "text.justify") {
                    // AI summarization
                }
                
                SmartActionButton(title: "Extract Meds", icon: "pills") {
                    // Extract medications
                }
                
                SmartActionButton(title: "Find Red Flags", icon: "flag") {
                    // Identify red flags
                }
                
                SmartActionButton(title: "Suggest DDx", icon: "list.bullet.indent") {
                    // Differential diagnosis
                }
                
                SmartActionButton(title: "Code Suggestions", icon: "number") {
                    // ICD/CPT codes
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.tertiarySystemBackground))
    }
    
    // MARK: - Helper Functions
    
    func startNewEncounter() {
        guard let room = selectedRoom else { return }
        
        let encounter = encounterManager.startNewEncounter(
            room: room,
            chiefComplaint: chiefComplaint
        )
        
        sessionManager.startNewSession(
            encounterId: encounter.id,
            patientId: nil
        )
        
        // Start REAL live transcription
        Task {
            await LiveTranscriptionEngine.shared.startLiveTranscription()
        }
    }
    
    func toggleRecording() {
        if sessionManager.isPaused {
            sessionManager.unpauseSession()
            // Resume live transcription
            Task {
                await liveTranscription.resumeTranscription()
            }
        } else {
            sessionManager.pauseSession()
            // Pause live transcription
            Task {
                await liveTranscription.pauseTranscription()
            }
        }
    }

// MARK: - Supporting Views

    
    func updateSegment(_ segment: TranscriptionSegment, with newText: String) {
        // Update segment text
    }
    
    func saveProgress() {
        sessionManager.saveEditedTranscript(sessionManager.editableTranscript)
    }
    
    func copyToClipboard() {
        #if canImport(UIKit)
        if let note = sessionManager.generatedNote {
            UIPasteboard.general.string = note
        }
        #endif
    }
    
    func exportNote() {
        // Export functionality
    }
    
    func sendToEHR() {
        // EHR integration
    }
    
    func showEndSessionConfirmation() {
        // Show confirmation dialog
        sessionManager.endSession()
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
    
    func getSmartSuggestions() -> [String] {
        // AI-powered suggestions based on partial complaint
        return ["chest pain", "shortness of breath", "abdominal pain", "headache"]
    }
    
    // MARK: - Session History View
    
    var sessionHistoryView: some View {
        NavigationView {
            List(sessionManager.sessionHistory) { session in
                SessionHistoryRow(session: session) {
                    sessionManager.resumeSession(session)
                }
            }
            .navigationTitle("Session History")
            .navigationBarItems(trailing: Button("Done") {
                showSessionHistory = false
            })
        }
    }
}

struct PhaseButton: View {
    let phase: EncounterPhaseType
    let isActive: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: phase.icon)
                    .font(.title3)
                Text(phase.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.blue : (isCompleted ? Color.green.opacity(0.2) : Color(.systemGray6)))
            )
            .foregroundColor(isActive ? .white : (isCompleted ? .green : .primary))
            .overlay(
                isCompleted ?
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                    .offset(x: 30, y: -20)
                : nil
            )
        }
    }
}

struct TranscriptSegmentView: View {
    let segment: TranscriptionSegment
    let onEdit: (String) -> Void
    @State private var isEditing = false
    @State private var editText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let speaker = segment.speaker {
                    Label(speaker.label, systemImage: "person.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Text(segment.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if segment.confidence < 0.7 {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                if !isEditing {
                    Button(action: { 
                        editText = segment.text
                        isEditing = true 
                    }) {
                        Image(systemName: "pencil")
                            .font(.caption)
                    }
                }
            }
            
            if isEditing {
                HStack {
                    TextEditor(text: $editText)
                        .frame(minHeight: 40)
                    
                    VStack {
                        Button("Save") {
                            onEdit(editText)
                            isEditing = false
                        }
                        Button("Cancel") {
                            isEditing = false
                        }
                    }
                }
            } else {
                Text(segment.text)
                    .foregroundColor(segment.confidence < 0.7 ? .orange : .primary)
                    .opacity(Double(segment.confidence))
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray6))
                .opacity(segment.isEdited ? 0.5 : 0.3)
        )
    }
}

struct RecentSessionCard: View {
    let session: EncounterSession
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text(session.startTime, style: .date)
                        .font(.caption)
                }
                
                Text("\(session.transcriptionSegments.count) segments")
                    .font(.caption2)
                
                if session.isResumable {
                    Label("Resumable", systemImage: "play.circle")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .frame(width: 150)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SessionHistoryRow: View {
    let session: EncounterSession
    let resumeAction: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.startTime, style: .date)
                        .font(.headline)
                    Text("\(session.transcriptionSegments.count) segments • \(session.selectedNoteType.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if session.isResumable {
                    Button("Resume") {
                        resumeAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RoomPickerView: View {
    @Binding var selectedRoom: Room?
    @Environment(\.dismiss) var dismiss
    @StateObject private var encounterManager = EncounterManager.shared
    
    var body: some View {
        NavigationView {
            List(encounterManager.availableRooms) { room in
                Button(action: {
                    selectedRoom = room
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: room.type.icon)
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text(room.displayName)
                                .font(.headline)
                            Text(room.type.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedRoom?.id == room.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .foregroundColor(.primary)
            }
            .navigationTitle("Select Room")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
        }
    }
}

struct SmartActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }
}

struct EncounterPulsingDot: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 8, height: 8)
            .scaleEffect(isAnimating ? 1.2 : 1.0)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct AudioLevelIndicator: View {
    let level: Double
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Double(i) < level * 5 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 3, height: CGFloat(8 + i * 2))
            }
        }
    }
}
