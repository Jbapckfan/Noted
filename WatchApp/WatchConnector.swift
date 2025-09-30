// This file is intended for the watchOS app target.
#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

final class WatchConnector: NSObject, ObservableObject, WCSessionDelegate {
    static let shared = WatchConnector()
    @Published var isReachable = false
    
    private override init() { super.init(); activate() }
    
    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }
    
    func startEncounter(room: String?, chiefComplaint: String?) {
        send(["action":"start", "room": room ?? "", "chiefComplaint": chiefComplaint ?? ""]) }
    func stopEncounter() { send(["action":"stop"]) }
    func bookmark(label: String) { send(["action":"bookmark", "label": label]) }
    
    private func send(_ message: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
    }
    
    // MARK: WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionReachabilityDidChange(_ session: WCSession) { DispatchQueue.main.async { self.isReachable = session.isReachable } }
}

#endif
