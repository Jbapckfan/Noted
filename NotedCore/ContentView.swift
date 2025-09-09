import SwiftUI

struct ContentView: View {
    @StateObject private var appState = CoreAppState.shared
    @StateObject private var summarizerService = EnhancedMedicalSummarizerService()
    @StateObject private var audioService = AudioCaptureService()
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var voiceCommandService = VoiceCommandService()
    @StateObject private var encounterManager = EncounterManager()
    @StateObject private var humanScribeEngine = HumanScribeReplacementEngine()
    
    @State private var selectedNoteType: NoteType = .edNote
    @State private var customInstructions = ""
    @State private var showCopyFeedback = false
    @State private var isGenerating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // HEADER with Recording Controls and Voice Commands
            headerSection
            
            // ENCOUNTER MANAGEMENT BAR
            encounterManagementSection
            
            // MAIN CONTENT AREA
            GeometryReader { geometry in
                VStack(spacing: 16) {
                    // Transcription Area (Top Half)
                    transcriptionSection
                        .frame(height: geometry.size.height * 0.40)
                    
                    // Note Generation Controls
                    noteControlsSection
                    
                    // Generated Note Area (Bottom Half)
                    generatedNoteSection
                        .frame(height: geometry.size.height * 0.40)
                }
                .padding(.horizontal)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGroupedBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            setupVoiceCommands()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Medical Transcription")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Recording Status
                if appState.isRecording {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("Recording • \(appState.recordingDuration)s")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            // Recording Controls
            HStack(spacing: 20) {
                // Record Button
                Button(action: toggleRecording) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(appState.isRecording ? Color.red : Color.blue)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: appState.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            )
                        
                        Text(appState.isRecording ? "Stop Recording" : "Start Recording")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Quick Test Buttons (for development/demo)
                HStack(spacing: 8) {
                    ForEach(["Chest", "Abd", "SOB"], id: \.self) { test in
                        Button(test) {
                            loadQuickTest(test)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemBackground).opacity(0.95)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
    
    // MARK: - Encounter Management Section
    private var encounterManagementSection: some View {
        HStack {
            // Current Encounter Info
            if let encounter = encounterManager.currentEncounter {
                VStack(alignment: .leading, spacing: 2) {
                    Text(encounter.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Started \(encounter.timeAgo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("No active encounter")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Encounter Controls
            HStack(spacing: 12) {
                if encounterManager.isEncounterActive {
                    Button("End Encounter") {
                        encounterManager.stopCurrentEncounter()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                } else {
                    Button("New Encounter") {
                        encounterManager.startNewEncounter()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1))
                    .foregroundColor(.green)
                    .cornerRadius(8)
                }
                
                // Voice Command Status
                if voiceCommandService.isListeningForCommands {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Listening")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.systemGray4)),
            alignment: .bottom
        )
    }
    
    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Patient Conversation")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("Clear") {
                    appState.transcriptionText = ""
                    summarizerService.generatedNote = ""
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.1))
                .foregroundColor(.red)
                .cornerRadius(6)
            }
            
            ZStack(alignment: .topLeading) {
                // Main transcription editor
                TextEditor(text: Binding(
                    get: { 
                        // Show zero-latency transcription if available, otherwise stored text
                        if !appState.zeroLatencyEngine.medicalText.isEmpty {
                            return appState.zeroLatencyEngine.medicalText
                        } else if !appState.zeroLatencyEngine.refinedText.isEmpty {
                            return appState.zeroLatencyEngine.refinedText
                        } else if !appState.zeroLatencyEngine.instantText.isEmpty {
                            return appState.zeroLatencyEngine.instantText
                        } else {
                            return encounterManager.currentEncounter?.transcription ?? appState.transcriptionText
                        }
                    },
                    set: { newValue in
                        appState.transcriptionText = newValue
                        encounterManager.updateCurrentEncounterTranscription(newValue)
                    }
                ))
                
                // Live transcription overlay with confidence indicators
                if appState.zeroLatencyEngine.isProcessing {
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                                Text("Live")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                
                                if appState.zeroLatencyEngine.latencyMetrics.averageLatency > 0 {
                                    Text("\(String(format: "%.0f", appState.zeroLatencyEngine.latencyMetrics.averageLatency * 1000))ms")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .overlay(
                    Group {
                        if appState.transcriptionText.isEmpty {
                            VStack {
                                HStack {
                                    Text("📝 Paste patient conversation here or start recording")
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
        }
    }
    
    // MARK: - Note Controls Section
    private var noteControlsSection: some View {
        VStack(spacing: 12) {
            // Note Type Picker
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
            
            // Generate Button with Status
            HStack {
                Button(action: generateNote) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Generating...")
                        } else {
                            Image(systemName: "doc.text.fill")
                            Text("Generate \(selectedNoteType.rawValue)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canGenerate ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(!canGenerate || isGenerating)
                
                // Copy Button with Visual Feedback
                if !summarizerService.generatedNote.isEmpty {
                    Button(action: copyNote) {
                        HStack {
                            Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.clipboard")
                            Text(showCopyFeedback ? "Copied!" : "Copy")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(showCopyFeedback ? Color.green : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .animation(.easeInOut(duration: 0.2), value: showCopyFeedback)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        )
    }
    
    // MARK: - Generated Note Section
    private var generatedNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Generated Medical Note")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Quality indicator and status
                HStack(spacing: 8) {
                    if !summarizerService.generatedNote.isEmpty {
                        QualityDotsView(quality: calculateQualityScore())
                    }
                    
                    if !summarizerService.statusMessage.isEmpty && summarizerService.statusMessage != "Ready" {
                        Text(summarizerService.statusMessage)
                            .font(.caption)
                            .foregroundColor(summarizerService.statusMessage.contains("Error") ? .red : .secondary)
                    }
                }
            }
            
            ScrollView {
                if summarizerService.generatedNote.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("Medical note will appear here")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Record or paste a patient conversation, then generate a professional medical note")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 40)
                } else {
                    Text(summarizerService.generatedNote)
                        .font(.system(.body, design: .default))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Computed Properties
    private var canGenerate: Bool {
        let transcriptionText = encounterManager.currentEncounter?.transcription ?? appState.transcriptionText
        return !transcriptionText.isEmpty && !isGenerating
    }
    
    // MARK: - Actions
    private func toggleRecording() {
        if appState.isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        Task {
            try? await audioService.start()
            try? await speechService.startTranscription()
            appState.isRecording = true
        }
    }
    
    private func stopRecording() {
        Task {
            audioService.stop()
            speechService.stopTranscription()
            appState.isRecording = false
        }
    }
    
    private func generateNote() {
        let transcriptionText = encounterManager.currentEncounter?.transcription ?? appState.transcriptionText
        guard !transcriptionText.isEmpty else { return }
        
        isGenerating = true
        
        Task {
            // Use Ollama for REAL medical understanding
            if appState.ollamaSummarizer.modelStatus.isConnected {
                // Determine visit phase based on context
                let visitPhase: StructuredVisitWorkflow.VisitPhase = .initial
                
                // Generate medical note using Ollama LLM
                let summary = await appState.ollamaSummarizer.summarizeConversation(
                    transcriptionText,
                    visitPhase: visitPhase,
                    noteFormat: appState.selectedNoteFormat
                )
                
                await MainActor.run {
                    appState.medicalNote = summary
                    isGenerating = false
                }
                
                return
            }
            
            // Fallback to pattern-based if Ollama not available
            if encounterManager.isEncounterActive {
                // Start automated scribe session based on encounter type
                let encounterType: HumanScribeReplacementEngine.EncounterType = .emergencyDepartment
                await humanScribeEngine.startScribeSession(encounterType: encounterType)
                
                // Process transcription through human scribe replacement
                let audioData: [Float] = []
                await humanScribeEngine.processAudioForScribing(audioData, sampleRate: 48000)
                
                // Generate final scribe documentation
                let scribeResult = await humanScribeEngine.finalizeScribeSession()
                
                await MainActor.run {
                    summarizerService.generatedNote = scribeResult.finalDocumentation
                    encounterManager.updateCurrentEncounterNote(scribeResult.finalDocumentation, type: selectedNoteType)
                    isGenerating = false
                }
            } else {
                // Fallback to enhanced medical summarizer
                await summarizerService.generateRealMedicalNote(
                    from: transcriptionText,
                    noteType: selectedNoteType
                )
                
                await MainActor.run {
                    encounterManager.updateCurrentEncounterNote(summarizerService.generatedNote, type: selectedNoteType)
                    isGenerating = false
                }
            }
        }
    }
    
    private func copyNote() {
        UIPasteboard.general.string = summarizerService.generatedNote
        
        // Visual feedback
        showCopyFeedback = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Reset feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopyFeedback = false
        }
    }
    
    private func loadQuickTest(_ test: String) {
        let testText: String
        
        switch test {
        case "Chest":
            testText = """
            I heard that you're having some chest pain today. Can you tell me a little more about that like when did it start? What does it feel like does the pain radiate and what kind of medical problems do you have? Oh well I do have diabetes and high blood pressure and my pain started about two hours before coming. I've had a blood clot in my legs before but no problems with my heart. I used to take a blood thinner, but I ran out about six weeks ago and I have had a little bit of a cough. Do you have any other problems? Do you take any other prescribed medication? Have you ever had any major surgeries? No no other medications I did have an appendectomy and I used to smoke cigarettes, but I stopped two years ago and I drink alcohol a few times a week. I don't take any other prescriptions. OK well we are going to order some lab tests and EKG and chest x-ray and make sure that your heart is looking good and that there is no evidence of a blood clot and we will just go from there.
            """
        case "Abd":
            testText = """
            Tell me about this abdominal pain you're having. When did it start and where exactly is it? Well doctor, the pain started this morning around 8 AM. It's right here in my lower right side and it's really sharp. It started around my belly button and then moved down here. Have you had any nausea or vomiting? Yes I threw up twice and I feel nauseous. Any fever or chills? I felt hot earlier. Any changes in your bowel movements? No, I haven't gone since yesterday. Any past medical history or surgeries? No surgeries, just high blood pressure. I take lisinopril daily. Any family history of abdominal problems? My mom had her gallbladder out. OK we need to do some blood work and a CT scan to rule out appendicitis. We'll also check your white blood cell count and get some IV fluids started.
            """
        case "SOB":
            testText = """
            I understand you're having trouble breathing. When did this start? It started yesterday evening doctor. I was just sitting watching TV and suddenly I couldn't catch my breath. Any chest pain with it? A little bit, sharp pain when I breathe in. Any cough or fever? No cough, no fever. What medical problems do you have? I have COPD and I'm a former smoker. I quit 5 years ago but smoked for 30 years. Any recent travel or long car rides? Yes, I just got back from visiting my daughter in Florida. We drove back, took us 12 hours. Any swelling in your legs? Now that you mention it, my left leg has been swollen and sore. What medications are you on? I take my COPD inhalers and blood pressure medicine. We need to check for a blood clot in your lung. We'll do a CT scan and some blood work including a D-dimer.
            """
        default:
            testText = ""
        }
        
        appState.transcriptionText = testText
        summarizerService.generatedNote = ""
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Voice Command Functions
    private func setupVoiceCommands() {
        voiceCommandService.delegate = self
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
    
    // MARK: - Quality Assessment
    private func calculateQualityScore() -> Float {
        let note = summarizerService.generatedNote
        guard !note.isEmpty else { return 0.0 }
        
        var score: Float = 0.0
        
        // Completeness (25%)
        let hasChiefComplaint = note.contains("Chief Complaint") || note.contains("CC:")
        let hasHPI = note.contains("History of Present Illness") || note.contains("HPI:")
        let hasAssessment = note.contains("Assessment") || note.contains("A&P:")
        if hasChiefComplaint { score += 0.08 }
        if hasHPI { score += 0.08 }
        if hasAssessment { score += 0.09 }
        
        // Medical terminology (25%)
        let medicalTerms = ["shortness of breath", "hypertension", "diabetes", "chest pain", "abdominal pain", "nausea", "vomiting", "fever", "tachycardia", "dyspnea"]
        let termCount = medicalTerms.filter { note.lowercased().contains($0) }.count
        score += Float(min(termCount, 5)) * 0.05
        
        // Structure (25%)
        let hasProperSections = note.contains(":") || note.contains("•") || note.contains("-")
        let hasReasonableLength = note.count > 100 && note.count < 2000
        if hasProperSections { score += 0.125 }
        if hasReasonableLength { score += 0.125 }
        
        // Clinical relevance (25%)
        let hasDifferential = note.contains("differential") || note.contains("consider")
        let hasNextSteps = note.contains("plan") || note.contains("follow") || note.contains("return")
        if hasDifferential { score += 0.125 }
        if hasNextSteps { score += 0.125 }
        
        return min(score, 1.0)
    }
}

// MARK: - Voice Command Delegate
extension ContentView: VoiceCommandDelegate {
    func executeVoiceCommand(_ command: VoiceCommand) {
        switch command {
        case .newEncounter:
            encounterManager.startNewEncounter()
            
        case .stopEncounter:
            encounterManager.stopCurrentEncounter()
            
        case .newPatientOnBed(let bed, let complaint):
            encounterManager.startNewEncounter(bed: bed, chiefComplaint: complaint)
        }
        
        // Update transcription to encounter
        if encounterManager.currentEncounter != nil {
            encounterManager.updateCurrentEncounterTranscription(appState.transcriptionText)
        }
    }
}

// MARK: - Quality Dots View
struct QualityDotsView: View {
    let quality: Float
    
    private var color: Color {
        switch quality {
        case 0.8...1.0:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5) { index in
                Circle()
                    .fill(Float(index) / 5.0 <= quality ? color : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}