import SwiftUI
import WatchConnectivity
#if os(watchOS)
import WatchKit
#endif

struct ContentView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var voiceHandler = VoiceCommandHandler.shared
    @State private var showingVoiceCommands = false
    @State private var selectedRoom = "Emergency Dept"
    @State private var chiefComplaint = ""
    @State private var showingSettings = false
    
    private let rooms = [
        "Emergency Dept",
        "Room 101",
        "Room 102",
        "Room 103",
        "ICU",
        "OR 1",
        "OR 2",
        "Clinic"
    ]
    
    private let gradientColors = [
        Color(red: 0.2, green: 0.4, blue: 0.8),
        Color(red: 0.3, green: 0.5, blue: 0.9)
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Status Card
                        statusCard
                        
                        // Quick Actions
                        quickActionsCard
                        
                        // Room Selection
                        if !sessionManager.isRecording {
                            roomSelectionCard
                        }
                        
                        // Voice Commands
                        voiceCommandsCard
                        
                        // Settings Button
                        settingsButton
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("NotedCore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            setupVoiceHandler()
        }
    }
    
    private var statusCard: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: sessionManager.isRecording ? "mic.circle.fill" : "mic.circle")
                    .foregroundColor(sessionManager.isRecording ? .red : .white)
                    .font(.title2)
                
                Text(sessionManager.isRecording ? "Recording" : "Ready")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if sessionManager.isRecording {
                    Text(formatDuration(sessionManager.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            
            if sessionManager.isReachable {
                HStack {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.caption)
                    Text("Connected to iPhone")
                        .font(.caption)
                }
                .foregroundColor(.green)
            } else {
                HStack {
                    Image(systemName: "iphone.slash")
                        .font(.caption)
                    Text("iPhone not connected")
                        .font(.caption)
                }
                .foregroundColor(.orange)
            }
            
            if voiceHandler.bluetoothConnected {
                HStack {
                    Image(systemName: "airpodspro")
                        .font(.caption)
                    Text("Bluetooth mic connected")
                        .font(.caption)
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var quickActionsCard: some View {
        VStack(spacing: 8) {
            if sessionManager.isRecording {
                // Recording controls
                HStack(spacing: 12) {
                    Button(action: pauseRecording) {
                        VStack {
                            Image(systemName: "pause.circle.fill")
                                .font(.title)
                            Text("Pause")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(color: .orange))
                    
                    Button(action: stopRecording) {
                        VStack {
                            Image(systemName: "stop.circle.fill")
                                .font(.title)
                            Text("End")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(color: .red))
                    
                    Button(action: addBookmark) {
                        VStack {
                            Image(systemName: "bookmark.circle.fill")
                                .font(.title)
                            Text("Mark")
                                .font(.caption2)
                        }
                    }
                    .buttonStyle(ActionButtonStyle(color: .purple))
                }
            } else {
                // Start recording button
                Button(action: startRecording) {
                    HStack {
                        Image(systemName: "mic.circle.fill")
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Recording")
                                .font(.headline)
                            Text("Room: \(selectedRoom)")
                                .font(.caption)
                                .opacity(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.green, .green.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private var roomSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            Picker("Room", selection: $selectedRoom) {
                ForEach(rooms, id: \.self) { room in
                    Text(room).tag(room)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.2))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var voiceCommandsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mic.badge.plus")
                    .font(.caption)
                Text("Voice Commands")
                    .font(.caption)
                Spacer()
                Toggle("", isOn: $voiceHandler.isListening)
                    .labelsHidden()
            }
            .foregroundColor(.white.opacity(0.9))
            
            if voiceHandler.isListening {
                VStack(alignment: .leading, spacing: 4) {
                    if !voiceHandler.lastCommand.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                            Text(voiceHandler.lastCommand)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    
                    Text("Say: Start, Stop, Pause, Resume, Bookmark")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.3))
        )
    }
    
    private var settingsButton: some View {
        Button(action: { showingSettings = true }) {
            HStack {
                Image(systemName: "gear")
                    .font(.caption)
                Text("Settings")
                    .font(.caption)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.3))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
    
    // MARK: - Actions
    
    private func setupVoiceHandler() {
        voiceHandler.setSessionManager(sessionManager)
        if voiceHandler.isListening {
            voiceHandler.enableAlwaysListening()
        }
    }
    
    private func startRecording() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.start)
        #endif
        sessionManager.startRecording(room: selectedRoom)
    }
    
    private func stopRecording() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.stop)
        #endif
        sessionManager.stopRecording()
    }
    
    private func pauseRecording() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
        sessionManager.pauseRecording()
    }
    
    private func addBookmark() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
        let bookmarkNumber = Int.random(in: 1...999)
        sessionManager.addBookmark(label: "Manual Mark", number: bookmarkNumber)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Button Styles

struct ActionButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var enableVoiceCommands = true
    @State private var hapticFeedback = true
    @State private var alwaysListening = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Voice Control") {
                    Toggle("Enable Voice Commands", isOn: $enableVoiceCommands)
                    Toggle("Always Listening", isOn: $alwaysListening)
                        .disabled(!enableVoiceCommands)
                }
                
                Section("Feedback") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Connection")
                        Spacer()
                        Text(WatchSessionManager.shared.isReachable ? "Connected" : "Disconnected")
                            .foregroundColor(WatchSessionManager.shared.isReachable ? .green : .orange)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}