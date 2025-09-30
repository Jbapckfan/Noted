import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Encounter Model
struct WatchEncounter: Identifiable, Codable {
    let id: String
    let room: String
    let chiefComplaint: String
    let startTime: Date
    var endTime: Date?
    var duration: TimeInterval { 
        (endTime ?? Date()).timeIntervalSince(startTime) 
    }
    var bookmarkCount: Int = 0
    var isPaused: Bool = false
    var isSaved: Bool = false
    var confirmationCode: String = ""
}

// MARK: - Encounter State
enum EncounterState: String {
    case idle = "Ready to Record"
    case connecting = "Connecting..."
    case starting = "Starting Encounter..."
    case recording = "Recording"
    case paused = "Paused"
    case ending = "Saving Encounter..."
    case saved = "Encounter Saved"
    case error = "Connection Error"
}

// MARK: - Watch Encounter Manager
@MainActor
final class WatchEncounterManager: NSObject, ObservableObject {
    static let shared = WatchEncounterManager()
    
    // MARK: Published Properties
    @Published var isConnected = false
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentRoom = "1"
    @Published var currentComplaint = "General"
    @Published var currentEncounter: WatchEncounter?
    @Published var recordingDuration = "00:00"
    @Published var statusMessage = "Ready to Record"
    @Published var state: EncounterState = .idle
    @Published var lastConfirmationCode = ""
    @Published var encounterHistory: [WatchEncounter] = []
    
    // MARK: Private Properties
    private var session: WCSession?
    private var recordingTimer: Timer?
    private var connectionTimer: Timer?
    private var pendingStartRequest = false
    private var startTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: Computed Properties
    var isReadyToRecord: Bool {
        isConnected && !isRecording && state == .idle
    }
    
    // MARK: - Initialization
    private override init() {
        super.init()
        setupWatchConnectivity()
        setupStateObservers()
        loadEncounterHistory()
    }
    
    // MARK: - Setup
    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
        
        // Start connection monitoring
        startConnectionMonitoring()
    }
    
    private func setupStateObservers() {
        // Observe state changes
        $state
            .sink { [weak self] newState in
                self?.updateStatusMessage(for: newState)
            }
            .store(in: &cancellables)
        
        // Observe recording state
        $isRecording
            .sink { [weak self] recording in
                if recording {
                    self?.startRecordingTimer()
                } else {
                    self?.stopRecordingTimer()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection Management
    private func startConnectionMonitoring() {
        connectionTimer?.invalidate()
        connectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }
    
    private func checkConnection() {
        guard let session = session else { return }
        
        Task { @MainActor in
            let wasConnected = isConnected
            isConnected = session.isReachable
            
            // Connection state changed
            if isConnected != wasConnected {
                if isConnected {
                    requestStatus()
                    state = .idle
                } else {
                    state = .error
                }
            }
        }
    }
    
    // MARK: - Encounter Management
    func startNewEncounter() {
        guard isReadyToRecord else { return }
        
        state = .starting
        pendingStartRequest = true
        
        // Create new encounter
        let encounter = WatchEncounter(
            id: UUID().uuidString,
            room: currentRoom,
            chiefComplaint: currentComplaint,
            startTime: Date()
        )
        
        currentEncounter = encounter
        
        // Send start command with confirmation request
        let message: [String: Any] = [
            "action": "start",
            "room": currentRoom,
            "chiefComplaint": currentComplaint,
            "encounterId": encounter.id,
            "requireConfirmation": true,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message) { [weak self] response in
            self?.handleStartResponse(response)
        }
        
        // Timeout handler
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            if self?.pendingStartRequest == true {
                self?.handleStartTimeout()
            }
        }
    }
    
    func endEncounter() {
        guard isRecording, let encounter = currentEncounter else { return }
        
        state = .ending
        isRecording = false
        
        // Update encounter
        var updatedEncounter = encounter
        updatedEncounter.endTime = Date()
        currentEncounter = updatedEncounter
        
        // Send end command with save confirmation
        let message: [String: Any] = [
            "action": "end",
            "encounterId": encounter.id,
            "room": encounter.room,
            "duration": encounter.duration,
            "bookmarkCount": encounter.bookmarkCount,
            "requireSaveConfirmation": true,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message) { [weak self] response in
            self?.handleEndResponse(response, encounter: updatedEncounter)
        }
    }
    
    func togglePause() {
        guard isRecording else { return }
        
        isPaused.toggle()
        state = isPaused ? .paused : .recording
        
        let message: [String: Any] = [
            "action": isPaused ? "pause" : "resume",
            "encounterId": currentEncounter?.id ?? "",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
        
        // Haptic feedback
        WKInterfaceDevice.current().play(isPaused ? .stop : .start)
    }
    
    func addBookmark(label: String = "Important") {
        guard isRecording, let encounter = currentEncounter else { return }
        
        var updatedEncounter = encounter
        updatedEncounter.bookmarkCount += 1
        currentEncounter = updatedEncounter
        
        let message: [String: Any] = [
            "action": "bookmark",
            "encounterId": encounter.id,
            "label": label,
            "timestamp": Date().timeIntervalSince1970,
            "bookmarkNumber": updatedEncounter.bookmarkCount
        ]
        
        sendMessage(message)
        
        // Visual feedback
        WKInterfaceDevice.current().play(.notification)
    }
    
    // MARK: - Response Handlers
    private func handleStartResponse(_ response: [String: Any]?) {
        pendingStartRequest = false
        
        guard let response = response,
              let confirmed = response["confirmed"] as? Bool,
              let confirmationCode = response["confirmationCode"] as? String else {
            handleStartTimeout()
            return
        }
        
        if confirmed {
            // Success!
            isRecording = true
            state = .recording
            startTime = Date()
            lastConfirmationCode = confirmationCode
            
            if var encounter = currentEncounter {
                encounter.confirmationCode = confirmationCode
                currentEncounter = encounter
            }
            
            // Strong haptic for successful start
            WKInterfaceDevice.current().play(.success)
            
            // Show confirmation
            statusMessage = "Recording Started - Code: \(confirmationCode)"
        } else {
            // Failed to start
            handleStartFailure(response["error"] as? String)
        }
    }
    
    private func handleEndResponse(_ response: [String: Any]?, encounter: WatchEncounter) {
        guard let response = response,
              let saved = response["saved"] as? Bool,
              let saveCode = response["saveCode"] as? String else {
            state = .error
            statusMessage = "Failed to save encounter"
            WKInterfaceDevice.current().play(.failure)
            return
        }
        
        if saved {
            // Successfully saved
            var savedEncounter = encounter
            savedEncounter.isSaved = true
            savedEncounter.confirmationCode = saveCode
            
            // Add to history
            encounterHistory.insert(savedEncounter, at: 0)
            saveEncounterHistory()
            
            // Clear current
            currentEncounter = nil
            state = .saved
            lastConfirmationCode = saveCode
            
            // Success feedback
            WKInterfaceDevice.current().play(.success)
            statusMessage = "Saved - Code: \(saveCode)"
            
            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.resetToIdle()
            }
        } else {
            state = .error
            statusMessage = response["error"] as? String ?? "Save failed"
            WKInterfaceDevice.current().play(.failure)
        }
    }
    
    private func handleStartTimeout() {
        pendingStartRequest = false
        state = .error
        statusMessage = "Connection timeout - Check iPhone/iPad"
        currentEncounter = nil
        WKInterfaceDevice.current().play(.failure)
    }
    
    private func handleStartFailure(_ error: String?) {
        state = .error
        statusMessage = error ?? "Failed to start recording"
        currentEncounter = nil
        WKInterfaceDevice.current().play(.failure)
    }
    
    // MARK: - Communication
    func requestStatus() {
        let message = ["action": "requestStatus"]
        sendMessage(message)
    }
    
    private func sendMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)? = nil) {
        guard let session = session, session.isReachable else {
            state = .error
            return
        }
        
        session.sendMessage(message, replyHandler: replyHandler) { error in
            print("Watch send error: \(error)")
        }
    }
    
    // MARK: - Timer Management
    private func startRecordingTimer() {
        stopRecordingTimer()
        startTime = Date()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRecordingDuration()
        }
    }
    
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = "00:00"
    }
    
    private func updateRecordingDuration() {
        guard let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        
        Task { @MainActor in
            recordingDuration = String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    // MARK: - State Management
    private func updateStatusMessage(for state: EncounterState) {
        statusMessage = state.rawValue
    }
    
    private func resetToIdle() {
        state = .idle
        isRecording = false
        isPaused = false
        currentEncounter = nil
        lastConfirmationCode = ""
    }
    
    // MARK: - Persistence
    private func loadEncounterHistory() {
        if let data = UserDefaults.standard.data(forKey: "WatchEncounterHistory"),
           let history = try? JSONDecoder().decode([WatchEncounter].self, from: data) {
            encounterHistory = history
        }
    }
    
    private func saveEncounterHistory() {
        // Keep only last 20 encounters
        let recentHistory = Array(encounterHistory.prefix(20))
        if let data = try? JSONEncoder().encode(recentHistory) {
            UserDefaults.standard.set(data, forKey: "WatchEncounterHistory")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchEncounterManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if activationState == .activated {
                isConnected = session.isReachable
                if isConnected {
                    requestStatus()
                }
            }
        }
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isConnected = session.isReachable
            if isConnected {
                requestStatus()
                state = .idle
            } else {
                state = .error
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            let response = handleReceivedMessage(message)
            replyHandler(response)
        }
    }
    
    @MainActor
    private func handleReceivedMessage(_ message: [String: Any]) -> [String: Any] {
        guard let action = message["action"] as? String else {
            return ["error": "Invalid message"]
        }
        
        switch action {
        case "statusUpdate":
            if let recording = message["isRecording"] as? Bool {
                isRecording = recording
                state = recording ? .recording : .idle
            }
            if let room = message["currentRoom"] as? String {
                currentRoom = room
            }
            if let duration = message["duration"] as? String {
                recordingDuration = duration
            }
            return ["received": true]
            
        case "confirmationReceived":
            // iPhone/iPad confirmed receipt
            if let code = message["code"] as? String {
                lastConfirmationCode = code
                WKInterfaceDevice.current().play(.notification)
            }
            return ["received": true]
            
        case "error":
            state = .error
            statusMessage = message["message"] as? String ?? "Error occurred"
            WKInterfaceDevice.current().play(.failure)
            return ["received": true]
            
        default:
            return ["error": "Unknown action"]
        }
    }
}

// MARK: - Watch App Integration
import WatchKit

extension WatchEncounterManager {
    func setupComplication() {
        // Update complication with current status
        let complicationServer = CLKComplicationServer.sharedInstance()
        for complication in complicationServer.activeComplications ?? [] {
            complicationServer.reloadTimeline(for: complication)
        }
    }
}