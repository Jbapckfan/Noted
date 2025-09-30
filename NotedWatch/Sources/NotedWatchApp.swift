import SwiftUI

@available(watchOS 10.0, *)
@main
struct WatchTestApp: App {
    var body: some Scene {
        WindowGroup {
            NotedWatchView()
        }
    }
}

@available(watchOS 10.0, *)
struct NotedWatchView: View {
    @State private var isRecording = false
    @State private var currentRoom = "Emergency Dept"
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    let rooms = ["Emergency Dept", "ICU", "OR", "Recovery", "Clinic", "Radiology"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Header
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title3)
                            .foregroundColor(.blue)
                        Text("NotedCore")
                            .font(.headline)
                    }
                    
                    // Room Selection
                    Picker("Room", selection: $currentRoom) {
                        ForEach(rooms, id: \.self) { room in
                            Text(room).tag(room)
                        }
                    }
                    .pickerStyle(.menu)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    
                    // Recording Button
                    Button(action: toggleRecording) {
                        VStack(spacing: 4) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(isRecording ? .red : .blue)
                            
                            Text(isRecording ? "Stop" : "Record")
                                .font(.caption)
                            
                            if isRecording {
                                Text(formatDuration(recordingDuration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding()
                    
                    // Quick Actions
                    if !isRecording {
                        VStack(spacing: 8) {
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "bookmark")
                                    Text("Add Bookmark")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button(action: {}) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("History")
                                }
                                .font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        // Pause/Resume during recording
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Image(systemName: "pause.circle")
                                    .font(.title2)
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {}) {
                                Image(systemName: "bookmark.circle")
                                    .font(.title2)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    private func toggleRecording() {
        isRecording.toggle()
        
        if isRecording {
            recordingDuration = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                recordingDuration += 1
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NotedWatchView()
}