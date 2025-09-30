import Foundation
import WatchConnectivity
import Combine

@available(watchOS 2.0, *)
class WatchSessionManager: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchSessionManager()
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentRoom = "Emergency Dept"
    @Published var isReachable = false
    @Published var lastConfirmationCode = ""
    @Published var lastSaveCode = ""
    
    private override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    // MARK: - Control Messages
    
    func startRecording(room: String) {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }
        
        let message: [String: Any] = [
            "action": "start",
            "room": room,
            "chiefComplaint": "Watch-initiated encounter",
            "encounterId": UUID().uuidString,
            "requireConfirmation": true,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                if let confirmed = response["confirmed"] as? Bool, confirmed {
                    self?.isRecording = true
                    self?.recordingDuration = 0
                    if let code = response["confirmationCode"] as? String {
                        self?.lastConfirmationCode = code
                    }
                    print("Recording started with code: \(self?.lastConfirmationCode ?? "")")
                }
            }
        }) { error in
            print("Failed to start recording: \(error)")
        }
    }
    
    func stopRecording() {
        guard WCSession.default.isReachable else {
            print("iPhone not reachable")
            return
        }
        
        let message: [String: Any] = [
            "action": "end",
            "room": currentRoom,
            "encounterId": UUID().uuidString,
            "requireSaveConfirmation": true,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: { [weak self] response in
            DispatchQueue.main.async {
                if let saved = response["saved"] as? Bool, saved {
                    self?.isRecording = false
                    if let code = response["saveCode"] as? String {
                        self?.lastSaveCode = code
                    }
                    print("Recording stopped with save code: \(self?.lastSaveCode ?? "")")
                }
            }
        }) { error in
            print("Failed to stop recording: \(error)")
        }
    }
    
    func pauseRecording() {
        let message: [String: Any] = [
            "action": "pause",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to pause: \(error)")
        }
    }
    
    func resumeRecording() {
        let message: [String: Any] = [
            "action": "resume",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to resume: \(error)")
        }
    }
    
    func addBookmark(label: String, number: Int) {
        let message: [String: Any] = [
            "action": "bookmark",
            "label": label,
            "bookmarkNumber": number,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil) { error in
            print("Failed to add bookmark: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
        }
        
        if let error = error {
            print("WCSession activation failed: \(error)")
        } else {
            print("WCSession activated with state: \(activationState.rawValue)")
            
            // Request initial status
            if session.isReachable {
                requestStatus()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages that require a reply
        self.session(session, didReceiveMessage: message)
        replyHandler(["status": "received"])
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS only - handle session becoming inactive
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // iOS only - reactivate session
        session.activate()
    }
    
    func sessionWatchStateDidChange(_ session: WCSession) {
        // iOS only - handle watch state changes
    }
    #endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isReachable = session.isReachable
            if session.isReachable {
                self.requestStatus()
            }
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let action = message["action"] as? String else { return }
        
        DispatchQueue.main.async {
            switch action {
            case "statusUpdate":
                self.handleStatusUpdate(message)
                
            case "transcriptionText":
                // Handle live transcription text from iPhone
                if let text = message["text"] as? String {
                    print("Received transcription: \(text)")
                }
                
            case "confirmationReceived":
                if let code = message["code"] as? String {
                    self.lastConfirmationCode = code
                }
                
            case "saveConfirmed":
                if let code = message["saveCode"] as? String {
                    self.lastSaveCode = code
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func requestStatus() {
        let message: [String: Any] = [
            "action": "requestStatus",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    private func handleStatusUpdate(_ message: [String: Any]) {
        if let recording = message["isRecording"] as? Bool {
            self.isRecording = recording
        }
        
        if let room = message["currentRoom"] as? String {
            self.currentRoom = room
        }
        
        if let duration = message["duration"] as? String {
            // Parse duration string back to TimeInterval
            let components = duration.split(separator: ":").compactMap { Int($0) }
            if components.count == 2 {
                self.recordingDuration = TimeInterval(components[0] * 60 + components[1])
            }
        }
    }
}