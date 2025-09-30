import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
import AVFoundation
import Combine

// MARK: - Encounter Confirmation
struct EncounterConfirmation: Equatable {
    let encounterId: String
    let room: String
    let confirmationCode: String
    let timestamp: Date
}

@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    
    // MARK: Published Properties
    @Published var isReachable = false
    @Published var lastReceivedRoom = ""
    @Published var lastReceivedComplaint = ""
    @Published var pendingEncounterConfirmation: EncounterConfirmation?
    @Published var isAwaitingWatchConfirmation = false
    
    // MARK: Private Properties
    private var activeEncounterId: String?
    private var encounterSaveConfirmations: [String: String] = [:] // encounterId: saveCode
    private var cancellables = Set<AnyCancellable>()
    
    private override init() { 
        super.init()
        setupObservers()
        activate()
    }
    
    private func setupObservers() {
        // Listen for recording state changes
        CoreAppState.shared.$isRecording
            .sink { [weak self] isRecording in
                self?.sendStatusUpdate()
            }
            .store(in: &cancellables)
    }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    // MARK: - Message Senders
    
    func sendStatusUpdate() {
        guard WCSession.default.isReachable else { return }
        
        let duration = formatDuration(TimeInterval(CoreAppState.shared.recordingDuration))
        
        let payload: [String: Any] = [
            "action": "statusUpdate",
            "isRecording": CoreAppState.shared.isRecording,
            "currentRoom": CoreAppState.shared.currentRoom,
            "duration": duration,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil) { error in
            print("Failed to send status: \(error)")
        }
    }
    
    func sendEncounterConfirmation(_ encounterId: String, code: String) {
        guard WCSession.default.isReachable else { return }
        
        let payload: [String: Any] = [
            "action": "confirmationReceived",
            "encounterId": encounterId,
            "code": code,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    func sendSaveConfirmation(_ encounterId: String, saveCode: String) {
        guard WCSession.default.isReachable else { return }
        
        encounterSaveConfirmations[encounterId] = saveCode
        
        let payload: [String: Any] = [
            "action": "saveConfirmed",
            "encounterId": encounterId,
            "saveCode": saveCode,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
    }
    
    func sendMessage(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send message: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - WCSessionDelegate
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { 
        WCSession.default.activate() 
    }
    
    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            if session.isReachable {
                self.sendStatusUpdate()
            }
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        Task { @MainActor in
            await self.handleMessage(message, replyHandler: nil)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        Task { @MainActor in
            await self.handleMessage(message, replyHandler: replyHandler)
        }
    }
    
    // MARK: - Message Handler
    
    @MainActor
    private func handleMessage(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) async {
        // Ensure transcription service is available
        let speechService = SpeechRecognitionService.shared
        let sessionManager = EncounterSessionManager.shared
        guard let action = message["action"] as? String else {
            replyHandler?(["error": "Invalid action"])
            return
        }
        
        switch action {
        case "start":
            await handleStartEncounter(message, replyHandler: replyHandler)
            
        case "end":
            await handleEndEncounter(message, replyHandler: replyHandler)
            
        case "pause":
            handlePauseEncounter()
            replyHandler?(["success": true])
            
        case "resume":
            handleResumeEncounter()
            replyHandler?(["success": true])
            
        case "bookmark":
            handleBookmark(message)
            replyHandler?(["success": true])
            
        case "requestStatus":
            sendStatusUpdate()
            replyHandler?(["success": true])
            
        default:
            replyHandler?(["error": "Unknown action"])
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleStartEncounter(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) async {
        let room = message["room"] as? String ?? "Unknown"
        let complaint = message["chiefComplaint"] as? String ?? "General"
        let encounterId = message["encounterId"] as? String ?? UUID().uuidString
        let requireConfirmation = message["requireConfirmation"] as? Bool ?? true
        
        // Update state
        CoreAppState.shared.currentRoom = room
        CoreAppState.shared.currentChiefComplaint = complaint
        CoreAppState.shared.currentSessionId = encounterId
        activeEncounterId = encounterId
        
        // Start a new encounter session
        EncounterSessionManager.shared.startNewSession(encounterId: UUID(uuidString: encounterId) ?? UUID(), patientId: room)
        
        // Generate confirmation code
        let confirmationCode = generateConfirmationCode()
        
        if requireConfirmation {
            // Store pending confirmation
            pendingEncounterConfirmation = EncounterConfirmation(
                encounterId: encounterId,
                room: room,
                confirmationCode: confirmationCode,
                timestamp: Date()
            )
            isAwaitingWatchConfirmation = true
        }
        
        // Start recording
        do {
            await EncounterController.shared.start(room: room, complaint: complaint)
            
            // Play sound to confirm
            AudioServicesPlaySystemSound(1054) // Tink sound
            
            // Send confirmation back to Watch
            let response: [String: Any] = [
                "confirmed": true,
                "confirmationCode": confirmationCode,
                "encounterId": encounterId,
                "timestamp": Date().timeIntervalSince1970
            ]
            
            replyHandler?(response)
            
            // Clear pending after success
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.isAwaitingWatchConfirmation = false
            }
        } catch {
            print("Failed to start encounter: \(error)")
            
            let response: [String: Any] = [
                "confirmed": false,
                "error": "Failed to start recording: \(error.localizedDescription)"
            ]
            
            replyHandler?(response)
            isAwaitingWatchConfirmation = false
            pendingEncounterConfirmation = nil
        }
    }
    
    private func handleEndEncounter(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) async {
        let encounterId = message["encounterId"] as? String ?? ""
        let room = message["room"] as? String ?? ""
        let requireSaveConfirmation = message["requireSaveConfirmation"] as? Bool ?? true
        
        // Stop recording
        EncounterController.shared.stop()
        
        // Generate save code
        let saveCode = generateSaveCode(for: encounterId)
        
        if requireSaveConfirmation {
            // Save encounter data
            await saveEncounterData(
                encounterId: encounterId,
                room: room,
                saveCode: saveCode
            )
        }
        
        // Play completion sound
        AudioServicesPlaySystemSound(1055) // Tweet sound
        
        // Send save confirmation
        let response: [String: Any] = [
            "saved": true,
            "saveCode": saveCode,
            "encounterId": encounterId,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        replyHandler?(response)
        
        // Clear active encounter
        activeEncounterId = nil
    }
    
    private func handlePauseEncounter() {
        // Implement pause logic
        print("Pausing encounter")
        // You might want to pause the audio capture here
    }
    
    private func handleResumeEncounter() {
        // Implement resume logic
        print("Resuming encounter")
        // You might want to resume the audio capture here
    }
    
    private func handleBookmark(_ message: [String: Any]) {
        let label = message["label"] as? String ?? "Bookmark"
        let bookmarkNumber = message["bookmarkNumber"] as? Int ?? 0
        
        EncounterController.shared.bookmark("\(label) #\(bookmarkNumber)")
        
        // Visual/audio feedback on iPhone/iPad
        AudioServicesPlaySystemSound(1057) // Tick sound
    }
    
    // MARK: - Helper Methods
    
    private func generateConfirmationCode() -> String {
        // Generate a 4-character confirmation code
        let letters = "ABCDEFGHJKLMNPQRSTUVWXYZ"
        let numbers = "23456789"
        
        var code = ""
        code += String(letters.randomElement()!)
        code += String(numbers.randomElement()!)
        code += String(letters.randomElement()!)
        code += String(numbers.randomElement()!)
        
        return code
    }
    
    private func generateSaveCode(for encounterId: String) -> String {
        // Generate save confirmation code
        let timestamp = Int(Date().timeIntervalSince1970) % 10000
        let idHash = encounterId.prefix(2).uppercased()
        return "S\(idHash)\(timestamp)"
    }
    
    private func saveEncounterData(encounterId: String, room: String, saveCode: String) async {
        // Save encounter to persistent storage
        // This would integrate with your existing data persistence
        
        let encounterData: [String: Any] = [
            "id": encounterId,
            "room": room,
            "saveCode": saveCode,
            "timestamp": Date().timeIntervalSince1970,
            "transcription": CoreAppState.shared.transcriptionText,
            "summary": CoreAppState.shared.medicalNote
        ]
        
        // Save to UserDefaults or CoreData
        var savedEncounters = UserDefaults.standard.array(forKey: "SavedEncounters") as? [[String: Any]] ?? []
        savedEncounters.insert(encounterData, at: 0)
        
        // Keep only last 50 encounters
        if savedEncounters.count > 50 {
            savedEncounters = Array(savedEncounters.prefix(50))
        }
        
        UserDefaults.standard.set(savedEncounters, forKey: "SavedEncounters")
        
        print("Encounter saved with code: \(saveCode)")
    }
}

#else
// MARK: - macOS Stub Implementation
import Foundation
import Combine

struct EncounterConfirmation: Equatable {
    let encounterId: String
    let room: String
    let confirmationCode: String
    let timestamp: Date
}

@MainActor
final class WatchConnectivityManager: ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var isReachable = false
    @Published var lastReceivedRoom = ""
    @Published var lastReceivedComplaint = ""
    @Published var pendingEncounterConfirmation: EncounterConfirmation?
    @Published var isAwaitingWatchConfirmation = false
    
    private init() {}
    
    func activate() {}
    func sendTranscription(_ text: String, speaker: String = "Unknown") {}
    func sendStatusUpdate() {}
    func saveEncounter(id: String, room: String, content: String, completion: @escaping (String) -> Void) {
        completion("STUB-CODE")
    }
}
#endif
