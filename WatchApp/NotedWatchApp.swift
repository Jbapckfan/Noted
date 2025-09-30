import SwiftUI
import WatchKit

@main
struct NotedWatchApp: App {
    @StateObject private var encounterManager = EncounterManager.shared
    @StateObject private var watchConnectivity = WatchConnectivityManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(encounterManager)
                .environmentObject(watchConnectivity)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var encounterManager: EncounterManager
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var selectedRoom: WatchRoom?
    @State private var showingChiefComplaintEntry = false
    @State private var isRecording = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // Header with current status
                headerView
                
                // Main content
                if let currentEncounter = encounterManager.currentEncounter {
                    ActiveEncounterView(encounter: currentEncounter)
                } else {
                    RoomSelectionView(onRoomSelected: { room in
                        selectedRoom = WatchRoom(
                            number: room.number,
                            type: room.type.rawValue,
                            isOccupied: room.isOccupied,
                            floor: room.floor,
                            hasActiveEncounter: room.currentEncounter != nil
                        )
                        showingChiefComplaintEntry = true
                    })
                }
            }
            .navigationTitle("NotedCore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingChiefComplaintEntry) {
            if let room = selectedRoom {
                ChiefComplaintEntryView(room: room) { chiefComplaint in
                    startNewEncounter(room: room, chiefComplaint: chiefComplaint)
                    showingChiefComplaintEntry = false
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Room Status")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(encounterManager.getActiveEncounters().count) Active")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            // Connection status
            Circle()
                .fill(watchConnectivity.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 4)
    }
    
    private func startNewEncounter(room: WatchRoom, chiefComplaint: String) {
        // Send data to phone
        let encounterData: [String: Any] = [
            "action": "startEncounter",
            "roomNumber": room.number,
            "chiefComplaint": chiefComplaint
        ]
        
        watchConnectivity.sendMessage(encounterData)
        
        // Start local encounter
        if let actualRoom = encounterManager.findRoom(by: room.number) {
            encounterManager.startNewEncounter(room: actualRoom, chiefComplaint: chiefComplaint)
        }
    }
}

// MARK: - Room Selection View

struct RoomSelectionView: View {
    let onRoomSelected: (Room) -> Void
    @EnvironmentObject var encounterManager: EncounterManager
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(encounterManager.getAvailableRooms()) { room in
                    RoomButton(room: room) {
                        onRoomSelected(room)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

struct RoomButton: View {
    let room: Room
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: room.type.icon)
                    .font(.title3)
                    .foregroundColor(room.isOccupied ? .secondary : .primary)
                
                Text(room.number)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(room.isOccupied ? .secondary : .primary)
                
                Text(room.type.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(room.isOccupied ? Color.secondary.opacity(0.2) : Color.blue.opacity(0.2))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(room.isOccupied ? Color.secondary : Color.blue, lineWidth: 1)
            )
        }
        .disabled(room.isOccupied)
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Chief Complaint Entry

struct ChiefComplaintEntryView: View {
    let room: WatchRoom
    let onComplete: (String) -> Void
    
    @State private var chiefComplaint = ""
    @State private var showingSuggestions = false
    @State private var isListeningForCC = false
    @EnvironmentObject var encounterManager: EncounterManager
    
    private let commonComplaints = [
        "Chest pain", "SOB", "Abdominal pain", "Headache", 
        "Back pain", "Fever", "N/V", "Dizziness",
        "Follow-up", "Medication refill"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Room info
                VStack(spacing: 4) {
                    Text("Room \(room.number)")
                        .font(.headline)
                    Text(room.type)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Chief complaint input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Chief Complaint")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        TextField("Enter complaint...", text: $chiefComplaint)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: {
                            isListeningForCC.toggle()
                            if isListeningForCC {
                                startVoiceRecognition()
                            }
                        }) {
                            Image(systemName: isListeningForCC ? "mic.fill" : "mic")
                                .foregroundColor(isListeningForCC ? .red : .blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // Quick suggestions
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(commonComplaints, id: \.self) { complaint in
                            Button(complaint) {
                                chiefComplaint = complaint
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.2))
                            )
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Skip") {
                        onComplete("")
                    }
                    .foregroundColor(.secondary)
                    
                    Button("Start") {
                        onComplete(chiefComplaint)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(chiefComplaint.isEmpty)
                }
            }
            .padding()
            .navigationTitle("New Encounter")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func startVoiceRecognition() {
        // Implementation for voice recognition would go here
        // This would use WatchKit's dictation capabilities
        
        presentTextInputController(withSuggestions: commonComplaints) { results in
            if let text = results?.first as? String {
                chiefComplaint = text
            }
            isListeningForCC = false
        }
    }
}

// MARK: - Active Encounter View

struct ActiveEncounterView: View {
    let encounter: MedicalEncounter
    @EnvironmentObject var watchConnectivity: WatchConnectivityManager
    @State private var isRecording = false
    @State private var transcriptionFeedback = ""
    @State private var audioLevels: [Float] = Array(repeating: 0, count: 20)
    @State private var lastTranscriptionTime = Date()
    
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Encounter info
                encounterHeader
                
                // Recording controls
                recordingControls
                
                // Live transcription feedback
                transcriptionFeedback
                
                // Audio visualization
                audioVisualization
                
                // Quick actions
                quickActions
            }
            .padding(.horizontal, 8)
        }
        .onReceive(timer) { _ in
            updateAudioVisualization()
        }
        .onReceive(watchConnectivity.$lastReceivedData) { data in
            handlePhoneData(data)
        }
    }
    
    private var encounterHeader: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Room \(encounter.room.number)")
                    .font(.headline)
                Spacer()
                Text(encounter.status.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !encounter.chiefComplaint.isEmpty {
                Text(encounter.chiefComplaint)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Text("Started: \(encounter.startTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var recordingControls: some View {
        VStack(spacing: 8) {
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                    Text(isRecording ? "Stop" : "Record")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isRecording ? Color.red : Color.blue)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if isRecording {
                recordingStatusView
            }
        }
    }
    
    private var recordingStatusView: some View {
        VStack(spacing: 4) {
            HStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 6, height: 6)
                    .scaleEffect(isRecording ? 1.0 : 0.5)
                    .animation(.easeInOut(duration: 1).repeatForever(), value: isRecording)
                
                Text("Recording")
                    .font(.caption)
                    .foregroundColor(.red)
                
                Spacer()
                
                Text(formatDuration(Date().timeIntervalSince(encounter.startTime)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Connection status
            HStack {
                Image(systemName: watchConnectivity.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(watchConnectivity.isConnected ? .green : .orange)
                    .font(.caption)
                
                Text(watchConnectivity.isConnected ? "Connected to iPhone" : "Reconnecting...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var transcriptionFeedback: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Live Transcription")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !transcriptionFeedback.isEmpty {
                    Text("Last: \(formatTimeSince(lastTranscriptionTime))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if transcriptionFeedback.isEmpty {
                Text(isRecording ? "Listening..." : "Not recording")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(transcriptionFeedback)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }
        }
    }
    
    private var audioVisualization: some View {
        VStack(spacing: 4) {
            Text("Audio Level")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            HStack(spacing: 1) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(audioLevels[index] > 0.3 ? Color.green : Color.secondary.opacity(0.3))
                        .frame(width: 2, height: CGFloat(audioLevels[index] * 20 + 2))
                }
            }
            .frame(height: 22)
        }
    }
    
    private var quickActions: some View {
        VStack(spacing: 8) {
            Text("Quick Actions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                QuickActionButton(title: "Pause", icon: "pause.fill") {
                    // Pause recording
                    pauseRecording()
                }
                
                QuickActionButton(title: "Note", icon: "note.text") {
                    // Add quick note
                    addQuickNote()
                }
                
                QuickActionButton(title: "Done", icon: "checkmark") {
                    // Complete encounter
                    completeEncounter()
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleRecording() {
        isRecording.toggle()
        
        let message: [String: Any] = [
            "action": isRecording ? "startRecording" : "stopRecording",
            "encounterId": encounter.id.uuidString
        ]
        
        watchConnectivity.sendMessage(message)
    }
    
    private func pauseRecording() {
        let message: [String: Any] = [
            "action": "pauseRecording",
            "encounterId": encounter.id.uuidString
        ]
        
        watchConnectivity.sendMessage(message)
    }
    
    private func addQuickNote() {
        // This would open dictation for a quick note
        presentTextInputController(withSuggestions: [
            "Patient stable",
            "Vital signs normal", 
            "Plan discussed",
            "Follow-up needed"
        ]) { results in
            if let note = results?.first as? String {
                let message: [String: Any] = [
                    "action": "addNote",
                    "encounterId": encounter.id.uuidString,
                    "note": note
                ]
                
                watchConnectivity.sendMessage(message)
            }
        }
    }
    
    private func completeEncounter() {
        let message: [String: Any] = [
            "action": "completeEncounter",
            "encounterId": encounter.id.uuidString
        ]
        
        watchConnectivity.sendMessage(message)
        
        // Update local state
        EncounterManager.shared.completeEncounter(encounter.id)
    }
    
    private func updateAudioVisualization() {
        // Simulate audio levels - in real implementation, this would come from actual audio data
        if isRecording {
            audioLevels = (0..<audioLevels.count).map { _ in
                Float.random(in: 0...1)
            }
        } else {
            audioLevels = Array(repeating: 0, count: audioLevels.count)
        }
    }
    
    private func handlePhoneData(_ data: [String: Any]?) {
        guard let data = data else { return }
        
        if let transcription = data["transcription"] as? String {
            transcriptionFeedback = transcription
            lastTranscriptionTime = Date()
        }
        
        if let status = data["recordingStatus"] as? String {
            isRecording = (status == "recording")
        }
        
        if let audioLevel = data["audioLevel"] as? Float {
            // Update audio visualization with real data
            updateAudioLevelFromPhone(audioLevel)
        }
    }
    
    private func updateAudioLevelFromPhone(_ level: Float) {
        // Shift existing levels and add new one
        audioLevels.removeFirst()
        audioLevels.append(level)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatTimeSince(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 {
            return "\(seconds)s ago"
        }
        return "\(seconds / 60)m ago"
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}