import SwiftUI

struct VoiceControlledMedicalAppView: View {
    @StateObject private var encounterManager = EncounterManager()
    @StateObject private var environmentManager = EDEnvironmentManager()
    @StateObject private var voiceCommandService = VoiceCommandService()
    // PRODUCTION: Using enhanced services
    @StateObject private var summarizerService = EnhancedMedicalSummarizerService()
    @StateObject private var whisperService = ProductionWhisperService.shared
    @StateObject private var redFlagService = MedicalRedFlagService.shared
    @StateObject private var liveTranscriptionService = LiveTranscriptionService.shared
    @StateObject private var audioCaptureService = AudioCaptureService()
    
    @State private var selectedTab = 0
    @State private var isRecording = false
    @State private var showingEnvironmentBuilder = false
    @State private var showingEncounterHistory = false
    @State private var selectedNoteType: NoteType = .edNote
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // MAIN CLINICAL TAB
            mainClinicalView
                .tabItem {
                    Image(systemName: "stethoscope")
                    Text("Clinical")
                }
                .tag(0)
            
            // ENCOUNTER HISTORY TAB (Enhanced Multi-Patient)
            EnhancedEncountersView(
                encounterManager: encounterManager,
                environmentManager: environmentManager
            )
            .tabItem {
                Image(systemName: "folder")
                Text("Encounters")
            }
            .tag(1)
            
            // ENVIRONMENT SETUP TAB
            EDEnvironmentBuilderView()
                .environmentObject(environmentManager)
                .tabItem {
                    Image(systemName: "building.2")
                    Text("Environment")
                }
                .tag(2)
            
            // AI Training removed - patterns are now pre-trained and compiled into the app
            // See Scripts/train_patterns.swift for development-time training
        }
                .onAppear {
            setupVoiceCommands()
            // Initialize WhisperKit for transcription
            whisperService.loadModelWithRetry()
        }
        .onChange(of: encounterManager.currentEncounter?.transcription) { _, newTranscription in
            if let text = newTranscription, !text.isEmpty {
                // Auto-save as user types/records
                if let encounter = encounterManager.currentEncounter {
                    encounterManager.saveEncounter(encounter)
                }
            }
        }
    }
    
    // MARK: - Main Clinical View
    private var mainClinicalView: some View {
        VStack(spacing: 0) {
            // PRODUCTION: Red Flag Alerts at the top
            if redFlagService.hasActiveCriticalFlags {
                RedFlagAlertView()
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // HEADER with Voice Status & Current Encounter
            clinicalHeaderView
            
            // MAIN CONTENT
            ScrollView {
                VStack(spacing: 16) {
                    // Current Encounter Info & Bed Selection
                    currentEncounterSection
                    
                    // Transcription Area
                    transcriptionSection
                        .frame(minHeight: 200, idealHeight: 250, maxHeight: 300)
                    
                    // Note Generation Controls
                    noteControlsSection
                    
                    // Generated Note Area
                    generatedNoteSection
                        .frame(minHeight: 400)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Clinical Header
    private var clinicalHeaderView: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "cross.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    
                    Text("Noted")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                }
                
                Spacer()
            }
            
            // Professional Command Status
            if !voiceCommandService.commandStatus.isEmpty && voiceCommandService.commandStatus != "Ready" {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text(voiceCommandService.commandStatus)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
    
    // MARK: - Encounter Info View
    private var encounterInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let encounter = encounterManager.currentEncounter {
                Text(encounter.displayTitle)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("Started \(encounter.timeAgo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if encounterManager.isEncounterActive {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text("No Active Encounter")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                if encounterManager.activeEncounters.count > 0 {
                    Text("\(encounterManager.activeEncounters.count) active patient\(encounterManager.activeEncounters.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else {
                    Text("Tap 'New Patient' to start")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Encounter Actions View
    private var encounterActionsView: some View {
        HStack(spacing: 10) {
            // Active Patient Switcher (if multiple patients)
            if encounterManager.activeEncounters.count > 1 {
                Menu {
                    ForEach(encounterManager.activeEncounters) { encounter in
                        Button(action: {
                            encounterManager.currentEncounter = encounter
                            encounterManager.selectedBed = encounter.bed ?? ""
                        }) {
                            Label(encounter.displayTitle, systemImage: encounter.id == encounterManager.currentEncounter?.id ? "checkmark.circle.fill" : "circle")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                        Text("Switch (\(encounterManager.activeEncounters.count))")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Spacer()
            
            // Primary Actions
            HStack(spacing: 10) {
                Button(action: {
                    if let environment = environmentManager.currentEnvironment {
                        let availableBed = environment.bedLocations.first { bed in
                            encounterManager.getBedStatus(bed.displayName) == .available
                        }
                        startNewEncounter(bed: availableBed?.displayName)
                    } else {
                        startNewEncounter()
                    }
                }) {
                    Label("New Patient", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                if encounterManager.currentEncounter != nil {
                    Button(action: {
                        if let encounter = encounterManager.currentEncounter {
                            encounterManager.completeEncounter(encounter)
                        }
                    }) {
                        Label("Complete", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .tint(.green)
                }
            }
        }
    }
    
    // MARK: - Current Encounter Section
    private var currentEncounterSection: some View {
        VStack(spacing: 12) {
            // Top row: Encounter info and bed selection
            HStack {
                encounterInfoView
                
                Spacer()
                
                // Bed Selection (more prominent)
                if let environment = environmentManager.currentEnvironment {
                    bedSelectionView(environment: environment)
                }
            }
            
            // Bottom row: Action buttons (better spacing for mobile)
            encounterActionsView
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Bed Selection View
    private func bedSelectionView(environment: EDEnvironment) -> some View {
        Menu {
            ForEach(BedCategory.allCases, id: \.self) { category in
                let bedsInCategory = environment.bedLocations.filter { $0.category == category }
                if !bedsInCategory.isEmpty {
                    Section(category.displayName) {
                        ForEach(bedsInCategory) { bed in
                            Button(action: { selectBed(bed) }) {
                                HStack {
                                    Text(bed.displayName)
                                    Spacer()
                                    
                                    // Show bed status indicator
                                    let status = encounterManager.getBedStatus(bed.displayName)
                                    Circle()
                                        .fill(status.color)
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                if let selectedBed = environmentManager.selectedBed {
                    Image(systemName: selectedBed.category.icon)
                        .foregroundColor(selectedBed.category.color)
                    Text(selectedBed.shortName)
                        .font(.caption)
                        .fontWeight(.medium)
                } else {
                    Image(systemName: "bed.double")
                    Text("Select Bed")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(.systemBackground))
            .cornerRadius(6)
        }
    }
    
    // MARK: - Helper Methods
    
    private func qualityColor(for score: Float) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .orange
        default: return .red
        }
    }
    
    // MARK: - Transcription Quality View
    private var transcriptionQualityView: some View {
        HStack(spacing: 8) {
            // Audio quality
            Label(String(format: "%.0f%%", summarizerService.audioQuality * 100), systemImage: "waveform")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Transcription quality
            if whisperService.modelQuality != .notLoaded {
                Label(whisperService.modelQuality.displayName, systemImage: "brain")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Overall quality score
            if summarizerService.overallQualityScore > 0 {
                let score = summarizerService.overallQualityScore
                let percentage = Int(score * 100)
                Label("\(percentage)%", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(qualityColor(for: score))
            }
        }
    }
    
    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("Live Transcription")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Live indicator
                    if liveTranscriptionService.isTranscribing {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .scaleEffect(liveTranscriptionService.audioLevel > 0.3 ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.2), value: liveTranscriptionService.audioLevel)
                            Text("LIVE")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                // Recording Control Button
                Button(action: toggleRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                            .font(.title2)
                        Text(isRecording ? "Stop Recording" : "Start Recording")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isRecording ? Color.red : Color.blue)
                    .cornerRadius(10)
                }
                
                // PRODUCTION: Recording Status with Quality Indicators
                if isRecording {
                    VStack(alignment: .trailing, spacing: 4) {
                        // Recording indicator with WPM
                        HStack(spacing: 8) {
                            // Audio level meter
                            HStack(spacing: 2) {
                                ForEach(0..<5) { i in
                                    Rectangle()
                                        .fill(liveTranscriptionService.audioLevel > Float(i) * 0.2 ? Color.green : Color.gray.opacity(0.3))
                                        .frame(width: 3, height: CGFloat(8 + i * 2))
                                }
                            }
                            
                            // WPM if available
                            if liveTranscriptionService.wordsPerMinute > 0 {
                                Text("\(liveTranscriptionService.wordsPerMinute) WPM")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // Recording status
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                Text("RECORDING")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                        }
                        
                        // Quality indicators
                        transcriptionQualityView
                    }
                }
                
                Button(action: clearTranscription) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Clear")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Editable live transcription
            TextEditor(text: $liveTranscriptionService.editableTranscript)
                .font(.system(.body, design: .default))
                .padding(12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(liveTranscriptionService.isTranscribing ? Color.green.opacity(0.5) : Color(.systemGray4), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                .overlay(
                    Group {
                        if liveTranscriptionService.editableTranscript.isEmpty {
                            VStack {
                                HStack {
                                    Text("🎙️ Live transcription will appear here as you speak...")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .padding(12)
                            .allowsHitTesting(false)
                        }
                    }
                )
                .overlay(
                    // Last update indicator
                    VStack {
                        HStack {
                            Spacer()
                            if liveTranscriptionService.isTranscribing {
                                Text("Last update: \(liveTranscriptionService.lastUpdateTime, formatter: timeFormatter)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(4)
                                    .background(Color(.systemBackground).opacity(0.9))
                                    .cornerRadius(4)
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                )
        }
    }
    
    // MARK: - Note Controls Section
    private var noteControlsSection: some View {
        VStack(spacing: 12) {
            // Instructions
            if !liveTranscriptionService.editableTranscript.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("You can edit the transcript above before generating the medical note")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
            }
            
            HStack {
                Text("Note Type:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Note Type", selection: $selectedNoteType) {
                    ForEach(NoteType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            HStack(spacing: 12) {
                // Submit to LLM button
                Button(action: submitTranscriptionToLLM) {
                    HStack {
                        if summarizerService.isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Processing...")
                        } else {
                            Image(systemName: "sparkles")
                            Text("Submit to AI")
                            Image(systemName: "arrow.right")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canSubmit ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .fontWeight(.semibold)
                    .cornerRadius(10)
                }
                .disabled(!canSubmit || summarizerService.isGenerating)
                
                if !summarizerService.generatedNote.isEmpty {
                    Button(action: copyNote) {
                        HStack {
                            Image(systemName: "doc.on.clipboard")
                            Text("Copy")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            
            // Status message
            if summarizerService.isGenerating {
                HStack {
                    Text("AI is generating your \(selectedNoteType.rawValue) note...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    // MARK: - Generated Note Section
    private var generatedNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                Text("Generated Medical Note")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Show issue indicators
                if redFlagService.hasContradictions {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(redFlagService.postGenerationIssues.count) Issues")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
                
                if !summarizerService.generatedNote.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Ready")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            // Show post-generation issues if any
            if !redFlagService.postGenerationIssues.isEmpty {
                PostGenerationIssuesView(issues: redFlagService.postGenerationIssues)
                    .padding(.vertical, 8)
            }
            
            // Content without ScrollView since parent is now scrollable
            VStack(alignment: .leading, spacing: 8) {
                if summarizerService.generatedNote.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Medical note will appear here")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Submit the transcript above to generate a medical note")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    // Note with highlighted issues
                    Text(summarizerService.generatedNote)
                        .font(.system(.body, design: .default))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(16)
                    
                    // Show inline issue markers if there are issues
                    if redFlagService.hasContradictions {
                        Divider()
                            .padding(.horizontal, 16)
                        Text("⚠️ Issues detected - Review highlighted sections above")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(redFlagService.hasContradictions ? Color.orange.opacity(0.5) : Color(.systemGray4), lineWidth: 1.5)
                    )
            )
        }
    }
    
    // MARK: - Encounter History View
    private var encounterHistoryView: some View {
        NavigationView {
            List {
                ForEach(encounterManager.savedEncounters) { encounter in
                    EncounterRowView(encounter: encounter) {
                        encounterManager.loadEncounter(encounter)
                        selectedTab = 0 // Switch to clinical tab
                    }
                }
                .onDelete(perform: deleteEncounters)
            }
            .navigationTitle("Encounter History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("New Encounter") {
                        startNewEncounter()
                        selectedTab = 0
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    private var canGenerate: Bool {
        return !(encounterManager.currentEncounter?.transcription.isEmpty ?? true) && !summarizerService.isGenerating
    }
    
    private var canSubmit: Bool {
        return !liveTranscriptionService.editableTranscript.isEmpty && !summarizerService.isGenerating
    }
    
    // MARK: - Actions
    private func setupVoiceCommands() {
        voiceCommandService.delegate = self
        
        Task {
            await voiceCommandService.startListeningForCommands()
        }
    }
    
    private func toggleVoiceCommands() {
        if voiceCommandService.isListeningForCommands {
            voiceCommandService.stopListeningForCommands()
        } else {
            Task {
                await voiceCommandService.startListeningForCommands()
            }
        }
    }
    
    private func startNewEncounter(bed: String? = nil, chiefComplaint: String? = nil) {
        if let bedLocation = bed {
            // Use enhanced multi-patient workflow
            let encounter = encounterManager.createNewEncounter(
                bedLocation: bedLocation,
                chiefComplaint: chiefComplaint ?? "To be determined"
            )
            encounterManager.currentEncounter = encounter
        } else {
            // Fallback to original method
            encounterManager.startNewEncounter(bed: bed, chiefComplaint: chiefComplaint)
        }
        summarizerService.generatedNote = ""
    }
    
    private func saveCurrentEncounter() {
        if let encounter = encounterManager.currentEncounter {
            encounterManager.saveEncounter(encounter)
        }
    }
    
    private func selectBed(_ bed: BedLocation) {
        environmentManager.selectBed(bed)
        
        // Switch to this bed using multi-patient workflow
        encounterManager.switchToBed(bed.displayName)
    }
    
        private func toggleRecording() {
        if isRecording {
            // Stop recording
            audioCaptureService.stop()
            isRecording = false
        } else {
            // Start recording
            Task {
                do {
                    // Ensure we have an encounter
                    if encounterManager.currentEncounter == nil {
                        startNewEncounter()
                    }
                    
                    // Ensure WhisperKit is loaded
                    if whisperService.modelQuality == .notLoaded {
                        whisperService.loadModelWithRetry()
                        // Wait a moment for model to start loading
                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                    }
                    
                    try await audioCaptureService.start()
                    await MainActor.run {
                        self.isRecording = true
                    }
                } catch {
                    print("Failed to start recording: \(error)")
                    await MainActor.run {
                        self.isRecording = false
                    }
                }
            }
        }
    }
    
    private func clearTranscription() {
        liveTranscriptionService.clearTranscription()
        encounterManager.updateCurrentEncounterTranscription("")
        summarizerService.generatedNote = ""
    }
    
    private func submitTranscriptionToLLM() {
        // Get the edited transcript from the live service
        let finalTranscript = liveTranscriptionService.finalizeTranscript()
        guard !finalTranscript.isEmpty else { 
            print("❌ No transcript to submit")
            return 
        }
        
        print("📝 Submitting transcript: \(finalTranscript.prefix(100))...")
        
        // Store in encounter manager
        encounterManager.updateCurrentEncounterTranscription(finalTranscript)
        
        Task {
            print("🤖 Starting medical note generation...")
            // Generate medical note with AI
            await summarizerService.generateRealMedicalNote(
                from: finalTranscript,
                noteType: selectedNoteType
            )
            print("✅ Note generation complete. Note: \(summarizerService.generatedNote.prefix(100))...")
            
            // After generation, check for red flags and contradictions
            await performPostGenerationChecks()
            
            // Update encounter with generated note
            encounterManager.updateCurrentEncounterNote(
                summarizerService.generatedNote,
                type: selectedNoteType
            )
        }
    }
    
    private func performPostGenerationChecks() async {
        // This will be called AFTER note generation to check for issues
        // The red flag service will analyze the final note for contradictions
        await redFlagService.analyzeGeneratedNote(summarizerService.generatedNote)
    }
    
    private func generateNote() {
        guard let transcription = encounterManager.currentEncounter?.transcription,
              !transcription.isEmpty else { return }
        
        Task {
            await summarizerService.generateRealMedicalNote(
                from: transcription,
                noteType: selectedNoteType
            )
            
            encounterManager.updateCurrentEncounterNote(
                summarizerService.generatedNote,
                type: selectedNoteType
            )
        }
    }
    
    private func copyNote() {
        UIPasteboard.general.string = summarizerService.generatedNote
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func deleteEncounters(at offsets: IndexSet) {
        for index in offsets {
            encounterManager.deleteEncounter(encounterManager.savedEncounters[index])
        }
    }
}

// MARK: - Formatters
private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter
}()

// MARK: - Voice Command Delegate
extension VoiceControlledMedicalAppView: VoiceCommandDelegate {
    func executeVoiceCommand(_ command: VoiceCommand) {
        switch command {
        case .newEncounter:
            startNewEncounter()
            
        case .stopEncounter:
            encounterManager.stopCurrentEncounter()
            
        case .newPatientOnBed(let bedIdentifier, let complaint):
            // Find the bed
            if let bed = environmentManager.getBedByVoiceCommand(bedIdentifier) {
                environmentManager.selectBed(bed)
                startNewEncounter(bed: bed.displayName, chiefComplaint: complaint)
            } else {
                startNewEncounter(bed: bedIdentifier, chiefComplaint: complaint)
            }
        }
    }
}

// MARK: - Encounter Row View
struct EncounterRowView: View {
    let encounter: MedicalEncounter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(encounter.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(encounter.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !encounter.transcription.isEmpty {
                        Text(encounter.transcription.prefix(100) + "...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(encounter.status.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(encounter.status == .active ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(4)
                    
                    if !encounter.generatedNote.isEmpty {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}

// MARK: - Post-Generation Issues View
struct PostGenerationIssuesView: View {
    let issues: [MedicalRedFlagService.PostGenerationIssue]
    @State private var expandedIssues: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Quality Check Results")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(issues) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Text(issue.type.icon)
                            .font(.caption)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(issue.type.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(issue.severity.color)
                            
                            Text(issue.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if expandedIssues.contains(issue.id.uuidString) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location: \(issue.location)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Suggestion: \(issue.suggestion)")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .padding(.top, 4)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedIssues.contains(issue.id.uuidString) {
                                    expandedIssues.remove(issue.id.uuidString)
                                } else {
                                    expandedIssues.insert(issue.id.uuidString)
                                }
                            }
                        }) {
                            Image(systemName: expandedIssues.contains(issue.id.uuidString) ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                    .background(issue.severity.color.opacity(0.05))
                    .cornerRadius(6)
                }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}