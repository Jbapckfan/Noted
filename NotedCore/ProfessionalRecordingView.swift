import SwiftUI
import AVFoundation

struct ProfessionalRecordingView: View {
    @StateObject private var audioService = AudioCaptureService()
    @ObservedObject var appState = CoreAppState.shared
    @State private var recordingMode: RecordingMode = .standard
    @State private var recordingTime: TimeInterval = 0
    @State private var recordingTimer: Timer?
    @State private var audioLevels: [Float] = Array(repeating: 0.0, count: 50)
    @State private var showingModeSelector = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Professional background
                professionalBackground
                
                VStack(spacing: 0) {
                    // Professional header
                    professionalHeader
                    
                    // Main recording cockpit
                    recordingCockpit
                        .frame(maxHeight: .infinity)
                    
                    // Mode selection and controls
                    recordingControls
                }
            }
        }
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            updateAudioVisualization()
        }
    }
    
    private var professionalBackground: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 0.0),
                .init(color: Color(red: 0.1, green: 0.1, blue: 0.15), location: 0.5),
                .init(color: Color(red: 0.05, green: 0.05, blue: 0.08), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var professionalHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(audioService.isRecording ? .red : .gray)
                        .frame(width: 12, height: 12)
                        .opacity(audioService.isRecording ? 1.0 : 0.5)
                        .scaleEffect(audioService.isRecording ? 1.5 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioService.isRecording)
                    
                    Text(audioService.isRecording ? "RECORDING LIVE" : "STANDBY")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundColor(audioService.isRecording ? .red : .gray)
                }
                
                Text(recordingMode.displayName)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if audioService.isRecording {
                    Text(formatTime(recordingTime))
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Text("Professional Audio Cockpit")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    private var recordingCockpit: some View {
        VStack(spacing: 32) {
            // 3D Waveform Visualization
            waveformVisualization
            
            // Speaker and Audio Analysis
            speakerAnalysis
            
            // Real-time Intelligence
            realtimeIntelligence
        }
        .padding(.horizontal, 24)
    }
    
    private var waveformVisualization: some View {
        VStack(spacing: 16) {
            Text("3D Audio Waveform Analysis")
                .font(.headline)
                .foregroundColor(.white)
            
            // Advanced 3D-style waveform
            HStack(spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    WaveformBar(
                        height: CGFloat(audioLevels[index]) * 100,
                        isActive: audioService.isRecording,
                        index: index
                    )
                }
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal)
        }
    }
    
    private var speakerAnalysis: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Active Speakers")
                    .font(.headline)
                    .foregroundColor(.white)
                
                SpeakerIndicator(
                    name: "Dr. Williams",
                    percentage: audioService.isRecording ? 68 : 0,
                    color: .blue,
                    isActive: audioService.isRecording
                )
                
                SpeakerIndicator(
                    name: "Patient",
                    percentage: audioService.isRecording ? 32 : 0,
                    color: .green,
                    isActive: audioService.isRecording
                )
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 8) {
                Text("Audio Quality")
                    .font(.headline)
                    .foregroundColor(.white)
                
                QualityIndicator(
                    title: "Signal Quality",
                    level: audioService.isRecording ? 5 : 3,
                    maxLevel: 5
                )
                
                QualityIndicator(
                    title: "Noise Level",
                    level: audioService.isRecording ? 1 : 0,
                    maxLevel: 5,
                    color: .red,
                    inverted: true
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var realtimeIntelligence: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Real-time Transcription Intelligence")
                .font(.headline)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                IntelligenceRow(
                    icon: "textformat.abc",
                    title: "Medical Terms",
                    value: audioService.isRecording ? "23 detected, 100% validated" : "Standby",
                    color: .blue
                )
                
                IntelligenceRow(
                    icon: "person.2.fill",
                    title: "Speaker Diarization",
                    value: audioService.isRecording ? "98.5% confidence" : "Ready",
                    color: .green
                )
                
                IntelligenceRow(
                    icon: "brain.head.profile",
                    title: "Clinical Relevance Score",
                    value: audioService.isRecording ? "9.2/10" : "Analyzing...",
                    color: .purple
                )
                
                IntelligenceRow(
                    icon: "highlighter",
                    title: "Auto-highlighting",
                    value: audioService.isRecording ? "Chief complaint identified" : "Standby",
                    color: .orange
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var recordingControls: some View {
        VStack(spacing: 20) {
            // Mode selector
            HStack(spacing: 12) {
                ForEach(RecordingMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: recordingMode == mode,
                        isEnabled: !audioService.isRecording
                    ) {
                        recordingMode = mode
                    }
                }
            }
            .padding(.horizontal)
            
            // Main recording button
            Button(action: toggleRecording) {
                ZStack {
                    Circle()
                        .fill(recordingButtonGradient)
                        .frame(width: 120, height: 120)
                        .shadow(color: recordingButtonColor.opacity(0.5), radius: audioService.isRecording ? 30 : 10)
                    
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: recordingButtonIcon)
                        .font(.system(size: 45, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .scaleEffect(audioService.isRecording ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioService.isRecording)
            
            Text(recordingButtonText)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Properties
    
    private var recordingButtonColor: Color {
        audioService.isRecording ? .red : .green
    }
    
    private var recordingButtonGradient: LinearGradient {
        if audioService.isRecording {
            return LinearGradient(
                colors: [.red, .red.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [.green, .green.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var recordingButtonIcon: String {
        audioService.isRecording ? "stop.fill" : "mic.fill"
    }
    
    private var recordingButtonText: String {
        audioService.isRecording ? "Stop Recording" : "Start Recording"
    }
    
    // MARK: - Helper Methods
    
    private func updateAudioVisualization() {
        if audioService.isRecording {
            // Simulate real-time audio levels with more sophisticated patterns
            for i in 0..<audioLevels.count {
                let baseLevel = audioService.level
                let variation = Float.random(in: -0.3...0.3)
                let frequency = sin(Float(Date().timeIntervalSince1970) * 2 + Float(i) * 0.1)
                audioLevels[i] = max(0, min(1, baseLevel + variation + frequency * 0.1))
            }
        } else {
            // Gradually decay levels when not recording
            for i in 0..<audioLevels.count {
                audioLevels[i] *= 0.95
            }
        }
    }
    
    private func toggleRecording() {
        if audioService.isRecording {
            audioService.stop()
            stopRecordingTimer()
        } else {
            Task {
                do {
                    try await audioService.start()
                    startRecordingTimer()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }
    
    private func startRecordingTimer() {
        recordingTime = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingTime += 1
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingTime = 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct WaveformBar: View {
    let height: CGFloat
    let isActive: Bool
    let index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: isActive ? [.blue, .cyan, .blue] : [.gray.opacity(0.3)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: max(2, height))
            .opacity(isActive ? 1.0 : 0.3)
            .animation(.easeInOut(duration: 0.1).delay(Double(index) * 0.01), value: height)
    }
}

struct SpeakerIndicator: View {
    let name: String
    let percentage: Int
    let color: Color
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(percentage)%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.white.opacity(0.1))
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(percentage) / 100, height: 6)
                        .cornerRadius(3)
                        .animation(.easeInOut(duration: 0.3), value: percentage)
                }
            }
            .frame(height: 6)
        }
    }
}

struct QualityIndicator: View {
    let title: String
    let level: Int
    let maxLevel: Int
    let color: Color
    let inverted: Bool
    
    init(title: String, level: Int, maxLevel: Int, color: Color = .green, inverted: Bool = false) {
        self.title = title
        self.level = level
        self.maxLevel = maxLevel
        self.color = color
        self.inverted = inverted
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(1...maxLevel, id: \.self) { index in
                    Circle()
                        .fill(shouldFillCircle(index) ? color : .white.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
    
    private func shouldFillCircle(_ index: Int) -> Bool {
        if inverted {
            return index <= (maxLevel - level)
        } else {
            return index <= level
        }
    }
}

struct IntelligenceRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ModeButton: View {
    let mode: RecordingMode
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(mode.shortName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .black : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? .white : .white.opacity(0.1))
                )
        }
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Recording Modes

enum RecordingMode: CaseIterable {
    case standard
    case handoff
    case rapidResponse
    
    var displayName: String {
        switch self {
        case .standard: return "Standard Recording Mode"
        case .handoff: return "Provider Handoff Mode"
        case .rapidResponse: return "Rapid Response Mode"
        }
    }
    
    var shortName: String {
        switch self {
        case .standard: return "Standard"
        case .handoff: return "Handoff"
        case .rapidResponse: return "Rapid Response"
        }
    }
}

#Preview {
    ProfessionalRecordingView()
}