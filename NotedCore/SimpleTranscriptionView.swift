import SwiftUI
import Speech
import AVFoundation

struct SimpleTranscriptionView: View {
    @State private var isRecording = false
    @State private var transcriptionText = ""
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    @State private var hasPermission = false
    @State private var audioLevel: Float = 0.0
    @State private var recordingDuration: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var confidence: Float = 0.0
    @State private var wordCount: Int = 0
    @State private var isProcessing = false
    @State private var generatedNote: String = ""
    @State private var isGeneratingNote = false
    @State private var selectedNoteType: NoteType = .edNote
    @State private var showingNoteOptions = false
    
    private var phi3Service = Phi3MLXService.shared
    
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Professional medical background
                LinearGradient(
                    colors: [Color(.systemGray6), Color(.systemGray5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with status
                    headerSection
                    
                    // Main content
                    VStack(spacing: 32) {
                        // Audio visualization and recording controls
                        recordingSection
                        
                        // Enhanced transcription display
                        transcriptionSection
                        
                        // AI Note Generation Section
                        if !transcriptionText.isEmpty {
                            aiNoteSectionView
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            requestPermissions()
        }
        .onChange(of: isRecording) { _, recording in
            if recording {
                startRecordingTimer()
            } else {
                stopRecordingTimer()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Medical Transcription")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Circle()
                        .fill(hasPermission ? .green : .orange)
                        .frame(width: 8, height: 8)
                    
                    Text(hasPermission ? "Ready" : "Requesting Permissions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isRecording {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(recordingDuration))
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.medium)
                    
                    HStack(spacing: 8) {
                        Text("\(wordCount) words")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if confidence > 0 {
                            Text("\(Int(confidence * 100))% confidence")
                                .font(.caption)
                                .foregroundColor(confidenceColor)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Recording Section
    private var recordingSection: some View {
        VStack(spacing: 24) {
            // Audio waveform visualization
            if isRecording {
                audioWaveform
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Enhanced recording button
            Button(action: toggleRecording) {
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(isRecording ? Color.red : Color.blue, lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(isRecording ? 1.15 : 1.0)
                        .opacity(isRecording ? 0.4 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), 
                                  value: isRecording)
                    
                    // Main button
                    Circle()
                        .fill(isRecording ? Color.red : Color.blue)
                        .frame(width: 100, height: 100)
                        .overlay {
                            if isProcessing {
                                ProgressView()
                                    .scaleEffect(1.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
            .disabled(!hasPermission || isProcessing)
            .scaleEffect(hasPermission ? 1.0 : 0.9)
            .opacity(hasPermission ? 1.0 : 0.6)
            
            // Status text
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Live Transcription")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !transcriptionText.isEmpty {
                    Button("Clear") {
                        withAnimation {
                            transcriptionText = ""
                            wordCount = 0
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if transcriptionText.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "waveform.badge.mic")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray.opacity(0.4))
                                
                                Text(isRecording ? "Listening for speech..." : "Press the microphone to begin")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            Text(transcriptionText)
                                .font(.body)
                                .lineSpacing(6)
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding(20)
                                .id("transcriptionEnd")
                            
                            // Live typing indicator
                            if isRecording {
                                HStack {
                                    Rectangle()
                                        .fill(.blue)
                                        .frame(width: 3, height: 20)
                                        .opacity(0.8)
                                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), 
                                                  value: isRecording)
                                    
                                    Spacer()
                                }
                                .padding(.leading, 20)
                            }
                        }
                    }
                }
                .onChange(of: transcriptionText) { _, _ in
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("transcriptionEnd", anchor: .bottom)
                    }
                }
            }
            .frame(maxHeight: 350)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
    
    // MARK: - Audio Waveform
    private var audioWaveform: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        colors: [.blue.opacity(0.3), .blue],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 4)
                    .frame(height: waveformHeight(for: index))
                    .animation(.easeOut(duration: 0.15), value: audioLevel)
            }
        }
        .frame(height: 40)
    }
    
    // MARK: - AI Note Generation Section
    private var aiNoteSectionView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🤖 Offline AI Medical Assistant")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Generate structured medical notes using Phi-3 AI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Note type selector
                Button(action: { showingNoteOptions.toggle() }) {
                    HStack(spacing: 4) {
                        Text(selectedNoteType.rawValue)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
                .popover(isPresented: $showingNoteOptions) {
                    noteTypeSelector
                }
            }
            
            // Generate button
            Button(action: generateMedicalNote) {
                HStack(spacing: 8) {
                    if isGeneratingNote {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "brain.head.profile")
                            .font(.title3)
                    }
                    
                    Text(isGeneratingNote ? "Generating Note..." : "Generate \(selectedNoteType.rawValue)")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canGenerateNote ? .blue : .gray)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .disabled(!canGenerateNote || isGeneratingNote)
            
            // Generated note display
            if !generatedNote.isEmpty {
                generatedNoteDisplay
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Note Type Selector
    private var noteTypeSelector: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(NoteType.allCases, id: \.self) { noteType in
                Button(action: {
                    selectedNoteType = noteType
                    showingNoteOptions = false
                }) {
                    HStack {
                        Text(noteType.rawValue)
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedNoteType == noteType {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(selectedNoteType == noteType ? .blue.opacity(0.1) : .clear)
                }
                .buttonStyle(.plain)
                
                if noteType != NoteType.allCases.last {
                    Divider()
                }
            }
        }
        .frame(minWidth: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Generated Note Display
    private var generatedNoteDisplay: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("📋 Generated \(selectedNoteType.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Copy") {
                        UIPasteboard.general.string = generatedNote
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    
                    Button("Clear") {
                        withAnimation {
                            generatedNote = ""
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
            
            ScrollView {
                Text(generatedNote)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .frame(maxHeight: 250)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Properties
    private var statusText: String {
        if !hasPermission {
            return "Microphone access required for transcription"
        } else if isProcessing {
            return "Processing audio..."
        } else if isRecording {
            return "Speak clearly into your microphone"
        } else {
            return "Tap to start recording"
        }
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
    
    private var canGenerateNote: Bool {
        !transcriptionText.isEmpty && !isGeneratingNote && wordCount > 5
    }
    
    // MARK: - Helper Functions
    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxHeight: CGFloat = 40
        let level = audioLevel
        
        // Create realistic waveform pattern
        let variation = sin(Double(index) * 0.8) * 0.4 + 1.0
        let height = baseHeight + (maxHeight - baseHeight) * CGFloat(level) * variation
        
        return max(4, min(maxHeight, height))
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func startRecordingTimer() {
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        DispatchQueue.main.async {
                            hasPermission = granted
                        }
                    }
                }
            }
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognizer not available")
            return
        }
        
        isProcessing = true
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session for optimal speech recognition
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use optimized settings for speech recognition
            try audioSession.setCategory(.playAndRecord, mode: .measurement, 
                                       options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Set optimal sample rate for speech recognition
            try audioSession.setPreferredSampleRate(44100)
            try audioSession.setPreferredIOBufferDuration(0.005) // Low latency
            
        } catch {
            print("Audio session error: \(error)")
            isProcessing = false
            return
        }
        
        // Create enhanced recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Could not create recognition request")
            isProcessing = false
            return
        }
        
        // Enhanced recognition settings for better accuracy
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false // Use server for best accuracy
        recognitionRequest.contextualStrings = [
            // Medical terminology for better recognition
            "patient", "diagnosis", "symptoms", "treatment", "medication", "prescription",
            "blood pressure", "heart rate", "temperature", "pain scale", "medical history",
            "allergies", "consultation", "examination", "assessment", "plan"
        ]
        
        // Add task hint for medical dictation
        if #available(iOS 16.0, *) {
            recognitionRequest.addsPunctuation = true
            recognitionRequest.taskHint = .dictation
        }
        
        // Set up audio engine with enhanced settings
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Enhanced audio processing with level monitoring
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            
            // Calculate audio level for visualization
            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            
            if let data = channelData {
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += abs(data[i])
                }
                let averageLevel = sum / Float(frameLength)
                
                DispatchQueue.main.async {
                    audioLevel = min(averageLevel * 10, 1.0) // Scale for visualization
                }
            }
            
            // Send to speech recognition
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine start error: \(error)")
            isProcessing = false
            return
        }
        
        // Start enhanced recognition with better error handling
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            
            DispatchQueue.main.async {
                if let result = result {
                    let newText = result.bestTranscription.formattedString
                    
                    // Update transcription with animation
                    withAnimation(.easeOut(duration: 0.2)) {
                        transcriptionText = newText
                        wordCount = newText.components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }.count
                    }
                    
                    // Calculate and display confidence
                    if let segments = result.bestTranscription.segments.last {
                        confidence = segments.confidence
                    }
                    
                    // Enhanced logging for debugging
                    if result.isFinal {
                        print("✅ Final transcription: \"\(newText)\"")
                        print("📊 Confidence: \(confidence)")
                        print("📝 Word count: \(wordCount)")
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    // Don't treat normal cancellation as an error
                    if nsError.code != 301 { // Speech recognition was cancelled
                        print("❌ Recognition error: \(error)")
                        // Note: Can't call stopRecording() from here due to SwiftUI structure
                    }
                }
            }
        }
        
        isRecording = true
        isProcessing = false
        
        print("🎙️ Started enhanced recording with medical context")
    }
    
    private func stopRecording() {
        isProcessing = true
        
        // Gracefully stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Complete recognition gracefully
        recognitionRequest?.endAudio()
        
        // Give a moment for final processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            
            isRecording = false
            isProcessing = false
            audioLevel = 0.0
            
            print("🛑 Stopped recording - Final text: \"\(transcriptionText)\"")
            print("📊 Final stats: \(wordCount) words, \(Int(confidence * 100))% confidence")
        }
    }
    
    // MARK: - AI Note Generation
    private func generateMedicalNote() {
        guard !transcriptionText.isEmpty else { return }
        
        isGeneratingNote = true
        generatedNote = ""
        
        print("🤖 Starting offline AI note generation...")
        print("📝 Transcription length: \(transcriptionText.count) chars")
        print("🏥 Note type: \(selectedNoteType.rawValue)")
        
        Task {
            do {
                let note = await phi3Service.generateMedicalNote(
                    from: transcriptionText,
                    noteType: selectedNoteType,
                    customInstructions: nil
                )
                
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.5)) {
                        generatedNote = note
                        isGeneratingNote = false
                    }
                    
                    print("✅ AI note generated successfully")
                    print("📄 Generated note length: \(note.count) chars")
                }
                
            } catch {
                await MainActor.run {
                    isGeneratingNote = false
                    print("❌ AI note generation failed: \(error)")
                    
                    // Show error to user
                    generatedNote = "Error generating note: \(error.localizedDescription)\n\nPlease try again with a longer transcription."
                }
            }
        }
    }
}

#Preview {
    SimpleTranscriptionView()
}