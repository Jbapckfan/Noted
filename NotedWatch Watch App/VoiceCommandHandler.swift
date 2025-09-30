import Foundation
import AVFoundation
import SwiftUI
import WatchConnectivity
import Combine
#if os(watchOS)
import WatchKit
#endif

/// Voice command handler for Apple Watch - supports both on-device and Bluetooth mic
class VoiceCommandHandler: NSObject, ObservableObject {
    static let shared = VoiceCommandHandler()
    
    @Published var isListening = false
    @Published var recognizedCommand: String = ""
    @Published var bluetoothConnected = false
    @Published var lastCommand: String = ""
    @Published var isUsingBluetooth: Bool = false
    @Published var lastCommandTime = Date()

    private var sessionManager: WatchSessionManager?
    // Simplified watch app - uses button presses instead of speech recognition
    private var audioRecorder: AVAudioRecorder?
    private let audioEngine = AVAudioEngine()
    
    // Bluetooth audio support
    private var bluetoothRoute: AVAudioSessionPortDescription?
    
    // Simple command patterns for watch
    private let commands: [String: CommandAction] = [
        "start encounter": .startEncounter,
        "start": .startEncounter,
        "begin": .startEncounter,
        "end encounter": .endEncounter,
        "end": .endEncounter,
        "stop": .endEncounter,
        "pause": .pause,
        "pause recording": .pause,
        "resume": .resume,
        "resume recording": .resume,
        "bookmark": .bookmark,
        "mark": .bookmark
    ]
    
    enum CommandAction {
        case startEncounter
        case endEncounter
        case pause
        case resume
        case bookmark
        
        var description: String {
            switch self {
            case .startEncounter: return "Start Encounter"
            case .endEncounter: return "End Encounter"
            case .pause: return "Pause"
            case .resume: return "Resume"
            case .bookmark: return "Bookmark"
            }
        }
    }
    
    private override init() {
        super.init()
        setupAudioSession()
        requestAuthorization()
        monitorBluetoothConnection()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        #if os(watchOS)
        // WatchOS doesn't use AVAudioSession
        // Audio is handled differently on watchOS
        #else
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .default, 
                                        options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        #endif
    }
    
    private func preferBluetoothInput() {
        #if !os(watchOS)
        let audioSession = AVAudioSession.sharedInstance()
        
        // Find Bluetooth HFP input
        if let bluetoothInput = audioSession.availableInputs?.first(where: { 
            $0.portType == .bluetoothHFP || $0.portType == .bluetoothA2DP 
        }) {
            do {
                try audioSession.setPreferredInput(bluetoothInput)
                bluetoothRoute = bluetoothInput
                bluetoothConnected = true
                print("✅ Bluetooth mic connected: \(bluetoothInput.portName)")
                
                // Haptic feedback for connection
                #if os(watchOS)
                WKInterfaceDevice.current().play(.success)
                #endif
            } catch {
                print("Failed to set Bluetooth input: \(error)")
            }
        }
        #else
        // On watchOS, we can't set preferred input
        bluetoothConnected = false
        print("Bluetooth input selection not available on watchOS")
        #endif
    }
    
    private func monitorBluetoothConnection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func audioRouteChanged(notification: Notification) {
        let audioSession = AVAudioSession.sharedInstance()
        let currentRoute = audioSession.currentRoute
        
        var foundBluetooth = false
        for output in currentRoute.outputs {
            if output.portType == .bluetoothA2DP || 
               output.portType == .bluetoothHFP ||
               output.portType == .bluetoothLE {
                bluetoothRoute = output
                foundBluetooth = true
                break
            }
        }
        
        DispatchQueue.main.async {
            self.bluetoothConnected = foundBluetooth
            self.isUsingBluetooth = foundBluetooth
        }
    }
    
    private func requestAuthorization() {
        // For watchOS, we'll use button commands instead of speech recognition
        print("✅ Watch app configured for button-based commands")
    }

    // MARK: - Session Manager Integration
    
    func setSessionManager(_ manager: WatchSessionManager) {
        self.sessionManager = manager
    }
    
    // MARK: - Voice Recognition
    
    func startListening() {
        guard !isListening else { return }

        // Simplified for Watch - just set listening state
        isListening = true
        recognizedCommand = "Listening for button commands..."

        // Haptic feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.start)
        #endif

        print("🎤 Watch ready for button commands")
    }
    
    func stopListening() {
        isListening = false
        recognizedCommand = "Commands ready"

        // Haptic feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.stop)
        #endif
    }
    
    // MARK: - Command Processing

    // Public method for button-triggered commands
    func executeButtonCommand(_ action: CommandAction) {
        executeCommand(action)
    }

    private func processCommand(_ transcript: String) {
        // Look for command matches
        for (phrase, action) in commands {
            if transcript.contains(phrase) {
                executeCommand(action)
                lastCommandTime = Date()
                
                // Stop listening after command recognized
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.stopListening()
                }
                break
            }
        }
    }
    
    private func executeCommand(_ action: CommandAction) {
        // Haptic feedback
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
        
        // Update last command
        DispatchQueue.main.async {
            self.lastCommand = action.description
            self.lastCommandTime = Date()
        }
        
        switch action {
        case .startEncounter:
            sessionManager?.startRecording(room: "Emergency Dept")
            announceCommand("Starting encounter")
            
        case .endEncounter:
            sessionManager?.stopRecording()
            announceCommand("Ending encounter")
            
        case .pause:
            sessionManager?.pauseRecording()
            announceCommand("Pausing")
            
        case .resume:
            sessionManager?.resumeRecording()
            announceCommand("Resuming")
            
        case .bookmark:
            sessionManager?.addBookmark(label: "Voice Mark", number: Int.random(in: 1...999))
            announceCommand("Bookmark added")
        }
    }
    
    private func announceCommand(_ message: String) {
        // Provide audio feedback
        if bluetoothConnected {
            // If Bluetooth connected, we can provide richer feedback
            playConfirmationSound()
        }
        
        // Update UI
        recognizedCommand = message
    }
    
    private func playConfirmationSound() {
        // Play system sound for confirmation
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
    
    // MARK: - Continuous Listening Mode
    
    func enableAlwaysListening() {
        // Set up continuous listening with wake word
        startContinuousListening()
    }
    
    private func startContinuousListening() {
        // Simplified for Watch - button-based commands
        isListening = true
        recognizedCommand = "Button commands active"
        print("🎧 Button command mode active")
    }
    
    private func restartListening() {
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startContinuousListening()
        }
    }
    
    private func extractAfterWakeWord(_ transcript: String) -> String {
        let wakeWords = ["hey noted", "noted core"]
        for wakeWord in wakeWords {
            if let range = transcript.range(of: wakeWord) {
                return String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return transcript
    }
}