import SwiftUI
import WatchConnectivity

struct WatchMainView: View {
    @StateObject private var encounterManager = WatchEncounterManager.shared
    @State private var showingRoomSelection = false
    @State private var showingEndConfirmation = false
    @State private var pulseAnimation = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient based on state
                backgroundGradient
                
                VStack(spacing: 20) {
                    // Status header
                    statusHeader
                    
                    // Main control area
                    mainControls
                    
                    // Quick actions
                    if encounterManager.isRecording {
                        quickActions
                    }
                    
                    // Encounter info
                    if encounterManager.currentEncounter != nil {
                        encounterInfo
                    }
                }
                .padding()
            }
            .navigationTitle("Noted")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingRoomSelection) {
                RoomSelectionSheet()
            }
            .alert("End Encounter?", isPresented: $showingEndConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("End & Save", role: .destructive) {
                    encounterManager.endEncounter()
                }
            } message: {
                Text("This will save and end the current encounter for Room \(encounterManager.currentRoom).")
            }
            .onAppear {
                encounterManager.requestStatus()
            }
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        LinearGradient(
            colors: encounterManager.isRecording ? 
                [Color.red.opacity(0.3), Color.red.opacity(0.1)] :
                [Color.blue.opacity(0.3), Color.green.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Status Header
    private var statusHeader: some View {
        VStack(spacing: 8) {
            // Connection status
            HStack(spacing: 4) {
                Circle()
                    .fill(encounterManager.isConnected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(encounterManager.isConnected ? "Connected" : "Connecting...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Recording status with animation
            if encounterManager.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                    
                    Text("RECORDING")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text(encounterManager.recordingDuration)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }
    
    // MARK: - Main Controls
    private var mainControls: some View {
        VStack(spacing: 16) {
            // Room selection button
            Button(action: {
                if !encounterManager.isRecording {
                    showingRoomSelection = true
                }
            }) {
                HStack {
                    Image(systemName: "door.left.hand.open")
                    Text("Room: \(encounterManager.currentRoom)")
                        .fontWeight(.medium)
                    Spacer()
                    if !encounterManager.isRecording {
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(encounterManager.isRecording ? 
                              Color.gray.opacity(0.3) : 
                              Color.blue.opacity(0.2))
                )
            }
            .disabled(encounterManager.isRecording)
            
            // Main action button
            if encounterManager.isRecording {
                // End button
                Button(action: {
                    WKInterfaceDevice.current().play(.stop)
                    showingEndConfirmation = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 80, height: 80)
                        
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Start button
                Button(action: {
                    WKInterfaceDevice.current().play(.start)
                    encounterManager.startNewEncounter()
                }) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "mic.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!encounterManager.isReadyToRecord)
            }
            
            // Status text
            Text(encounterManager.statusMessage)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Quick Actions
    private var quickActions: some View {
        HStack(spacing: 12) {
            // Bookmark button
            Button(action: {
                WKInterfaceDevice.current().play(.click)
                encounterManager.addBookmark()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: "bookmark.fill")
                        .font(.title3)
                    Text("Mark")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(8)
            }
            
            // Pause/Resume button
            Button(action: {
                WKInterfaceDevice.current().play(.click)
                encounterManager.togglePause()
            }) {
                VStack(spacing: 4) {
                    Image(systemName: encounterManager.isPaused ? "play.fill" : "pause.fill")
                        .font(.title3)
                    Text(encounterManager.isPaused ? "Resume" : "Pause")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(8)
            }
        }
    }
    
    // MARK: - Encounter Info
    private var encounterInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let encounter = encounterManager.currentEncounter {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Encounter #\(encounter.id)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                if !encounter.chiefComplaint.isEmpty {
                    Text(encounter.chiefComplaint)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                if encounter.bookmarkCount > 0 {
                    HStack {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("\(encounter.bookmarkCount) bookmarks")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}

// MARK: - Room Selection Sheet
struct RoomSelectionSheet: View {
    @StateObject private var encounterManager = WatchEncounterManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRoom = ""
    @State private var selectedComplaint = ""
    @State private var customRoom = ""
    @State private var showingCustomRoomField = false
    
    // Predefined rooms
    let commonRooms = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10",
                       "Trauma 1", "Trauma 2", "Resus 1", "Resus 2",
                       "Fast Track", "Triage", "Procedure Room"]
    
    // Common chief complaints
    let commonComplaints = [
        "Chest pain",
        "Shortness of breath",
        "Abdominal pain",
        "Headache",
        "Dizziness",
        "Trauma",
        "Fever",
        "Back pain",
        "Extremity pain",
        "Laceration",
        "Other"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Room Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Select Room", systemImage: "door.left.hand.open")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 8) {
                            ForEach(commonRooms.prefix(9), id: \.self) { room in
                                roomButton(room)
                            }
                        }
                        
                        // More rooms
                        ForEach(commonRooms.dropFirst(9), id: \.self) { room in
                            roomButton(room)
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Custom room
                        Button(action: {
                            showingCustomRoomField.toggle()
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Custom Room")
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        if showingCustomRoomField {
                            TextField("Enter room", text: $customRoom)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    if !customRoom.isEmpty {
                                        selectedRoom = customRoom
                                        showingCustomRoomField = false
                                    }
                                }
                        }
                    }
                    
                    // Chief Complaint Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Chief Complaint", systemImage: "stethoscope")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(commonComplaints, id: \.self) { complaint in
                            complaintButton(complaint)
                        }
                    }
                    
                    // Confirm button
                    Button(action: confirmSelection) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Confirm & Start")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canConfirm ? Color.green : Color.gray.opacity(0.3))
                        )
                        .foregroundColor(canConfirm ? .white : .gray)
                    }
                    .disabled(!canConfirm)
                }
                .padding()
            }
            .navigationTitle("New Encounter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func roomButton(_ room: String) -> some View {
        Button(action: {
            selectedRoom = room
            WKInterfaceDevice.current().play(.click)
        }) {
            Text(room)
                .font(.callout)
                .fontWeight(selectedRoom == room ? .bold : .regular)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selectedRoom == room ? 
                              Color.blue : Color.blue.opacity(0.2))
                )
                .foregroundColor(selectedRoom == room ? .white : .primary)
        }
    }
    
    private func complaintButton(_ complaint: String) -> some View {
        Button(action: {
            selectedComplaint = complaint
            WKInterfaceDevice.current().play(.click)
        }) {
            HStack {
                Text(complaint)
                    .font(.callout)
                Spacer()
                if selectedComplaint == complaint {
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedComplaint == complaint ? 
                          Color.orange.opacity(0.3) : Color.gray.opacity(0.1))
            )
        }
    }
    
    private var canConfirm: Bool {
        !selectedRoom.isEmpty || !customRoom.isEmpty
    }
    
    private func confirmSelection() {
        let finalRoom = selectedRoom.isEmpty ? customRoom : selectedRoom
        guard !finalRoom.isEmpty else { return }
        
        // Heavy haptic for confirmation
        WKInterfaceDevice.current().play(.success)
        
        // Update encounter manager
        encounterManager.currentRoom = finalRoom
        encounterManager.currentComplaint = selectedComplaint.isEmpty ? "General" : selectedComplaint
        
        dismiss()
        
        // Auto-start if ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if encounterManager.isReadyToRecord {
                encounterManager.startNewEncounter()
            }
        }
    }
}

// MARK: - Watch Interface Device Extension
import WatchKit

extension WKInterfaceDevice {
    enum HapticFeedback {
        case success
        case failure
        case start
        case stop
        case click
        case notification
    }
    
    func play(_ feedback: HapticFeedback) {
        switch feedback {
        case .success:
            WKInterfaceDevice.current().play(.success)
        case .failure:
            WKInterfaceDevice.current().play(.failure)
        case .start:
            WKInterfaceDevice.current().play(.start)
        case .stop:
            WKInterfaceDevice.current().play(.stop)
        case .click:
            WKInterfaceDevice.current().play(.click)
        case .notification:
            WKInterfaceDevice.current().play(.notification)
        }
    }
}

#Preview {
    WatchMainView()
}