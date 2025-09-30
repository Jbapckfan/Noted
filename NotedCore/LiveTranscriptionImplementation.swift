import SwiftUI
import Speech
import AVFoundation

// ACTUAL WORKING LIVE TRANSCRIPTION
class LiveTranscriptionEngine: NSObject, ObservableObject {
    static let shared = LiveTranscriptionEngine()
    
    @Published var liveText: String = ""
    @Published var isTranscribing = false
    @Published var segments: [TranscriptionSegment] = []
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Medical context for better recognition
    private let medicalTerms = [
        "chest pain", "shortness of breath", "abdominal pain",
        "hypertension", "diabetes", "tachycardia", "bradycardia",
        "EKG", "troponin", "CBC", "BMP", "chest x-ray",
        "discharge", "admission", "consultation"
    ]
    
    override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    func startLiveTranscription() {
        // Request permissions first
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    self.beginTranscription()
                }
            }
        }
    }
    
    private func beginTranscription() {
        // Stop if already running
        if audioEngine.isRunning {
            stopTranscription()
        }
        
        do {
            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Create request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = true // 100% OFFLINE!
            recognitionRequest.contextualStrings = medicalTerms
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            // Install tap on audio input
            inputNode.installTap(onBus: 0, bufferSize: 256, format: recordingFormat) { buffer, _ in
                recognitionRequest.append(buffer)
            }
            
            // Prepare and start audio engine
            audioEngine.prepare()
            try audioEngine.start()
            
            isTranscribing = true
            
            // Start recognition task
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    DispatchQueue.main.async {
                        // UPDATE LIVE TEXT - THIS IS WHAT USER SEES!
                        self.liveText = result.bestTranscription.formattedString
                        
                        // Create segment for display
                        let segment = TranscriptionSegment(
                            id: UUID(),
                            text: result.bestTranscription.formattedString,
                            start: 0,
                            end: Date().timeIntervalSince1970,
                            confidence: Float(result.bestTranscription.segments.first?.confidence ?? 0.8),
                            timestamp: Date()
                        )
                        
                        // Update segments (keep last 10 for display)
                        if self.segments.isEmpty || result.isFinal {
                            self.segments.append(segment)
                            if self.segments.count > 10 {
                                self.segments.removeFirst()
                            }
                        } else {
                            // Update last segment if partial
                            self.segments[self.segments.count - 1] = segment
                        }
                        
                        // Send to watch
                        self.sendToWatch(self.liveText)
                    }
                }
                
                if error != nil {
                    self.stopTranscription()
                }
            }
        } catch {
            print("Error starting transcription: \(error)")
        }
    }
    
    func stopTranscription() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        isTranscribing = false
    }
    
    func pauseTranscription() {
        if audioEngine.isRunning {
            audioEngine.pause()
        }
    }
    
    func resumeTranscription() {
        if !audioEngine.isRunning {
            try? audioEngine.start()
        }
    }
    
    private func sendToWatch(_ text: String) {
        // TODO: Implement watch connectivity
        // WatchConnectivityManager.shared.sendMessage([
        //     "action": "transcriptionText",
        //     "text": text
        // ])
    }
}

extension LiveTranscriptionEngine: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        print("Speech recognizer availability: \(available)")
    }
}

// LIVE TRANSCRIPTION VIEW WITH VISIBLE TEXT
struct LiveTranscriptionView: View {
    @StateObject private var engine = LiveTranscriptionEngine.shared
    @State private var showingText = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(engine.isTranscribing ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                
                Text(engine.isTranscribing ? "RECORDING" : "STOPPED")
                    .font(.caption)
                    .fontWeight(.bold)
                
                Spacer()
                
                Toggle("Show Live Text", isOn: $showingText)
                    .toggleStyle(SwitchToggleStyle())
            }
            .padding(.horizontal)
            
            if showingText {
                // LIVE TRANSCRIPTION DISPLAY - WHAT YOU WANT TO SEE!
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(engine.segments) { segment in
                                HStack(alignment: .top) {
                                    Text(segment.timestamp, style: .time)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60)
                                    
                                    VStack(alignment: .leading) {
                                        Text(segment.text)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundColor(segment.confidence < 0.7 ? .orange : .primary)
                                        
                                        // Confidence indicator
                                        HStack {
                                            Text("Confidence: \(Int(segment.confidence * 100))%")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                            
                                            if segment.text.contains(where: { medicalTermDetected(in: String($0)) }) {
                                                Label("Medical", systemImage: "stethoscope")
                                                    .font(.caption2)
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                .id(segment.id)
                            }
                            
                            // Current live text (partial)
                            if !engine.liveText.isEmpty && engine.isTranscribing {
                                HStack(alignment: .top) {
                                    Image(systemName: "mic.fill")
                                        .foregroundColor(.red)
                                        .frame(width: 60)
                                    
                                    Text(engine.liveText)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .id("live")
                                }
                                .padding(.horizontal)
                                .background(Color.yellow.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .onChange(of: engine.liveText) { _ in
                            withAnimation {
                                proxy.scrollTo("live", anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Control buttons
            HStack(spacing: 30) {
                Button(action: {
                    if engine.isTranscribing {
                        engine.stopTranscription()
                    } else {
                        engine.startLiveTranscription()
                    }
                }) {
                    Image(systemName: engine.isTranscribing ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 80, height: 80)
                        .foregroundColor(engine.isTranscribing ? .red : .green)
                }
                
                Button(action: {
                    engine.pauseTranscription()
                }) {
                    Image(systemName: "pause.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.orange)
                }
                .disabled(!engine.isTranscribing)
                
                Button(action: {
                    engine.resumeTranscription()
                }) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
                .disabled(!engine.isTranscribing)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func medicalTermDetected(in text: String) -> Bool {
        let medicalKeywords = ["pain", "mg", "ml", "pressure", "rate", "fever", "cough"]
        return medicalKeywords.contains { text.lowercased().contains($0) }
    }
}

// Add this to the EncounterWorkflowView to show live transcription
extension EncounterWorkflowView {
    var liveTranscriptionSection: some View {
        LiveTranscriptionView()
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 2)
    }
}