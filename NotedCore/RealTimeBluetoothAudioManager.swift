#if os(iOS)
import AVFoundation
import CoreBluetooth
import Combine

/// Manages real Bluetooth audio device connections for medical transcription
@MainActor
class RealTimeBluetoothAudioManager: NSObject, ObservableObject {
    static let shared = RealTimeBluetoothAudioManager()
    
    // MARK: - Published Properties
    @Published var connectedDevice: AVAudioSessionPortDescription?
    @Published var isBluetoothConnected = false
    @Published var availableDevices: [AVAudioSessionPortDescription] = []
    @Published var currentAudioLevel: Float = 0.0
    @Published var isReceivingAudio = false
    
    // MARK: - Audio Session
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()
    private var inputNode: AVAudioInputNode?
    private var audioLevelTimer: Timer?
    
    // MARK: - Audio Processing
    private let audioBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!, frameCapacity: 1024)
    
    // Callbacks for real audio data
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    
    override private init() {
        super.init()
        setupAudioSession()
        setupNotifications()
    }
    
    // MARK: - Audio Session Setup
    
    private func setupAudioSession() {
        do {
            // Configure for Bluetooth audio input
            try audioSession.setCategory(.playAndRecord, 
                                        mode: .measurement,
                                        options: [.allowBluetooth, .allowBluetoothA2DP])
            
            // Set preferred input to Bluetooth if available
            updateBluetoothDevices()
            
            // Activate session
            try audioSession.setActive(true)
            
            // Setup audio engine
            setupAudioEngine()
            
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        inputNode = audioEngine.inputNode
        
        guard let inputNode = inputNode else { return }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap to get real audio data
        inputNode.installTap(onBus: 0, 
                           bufferSize: 1024,
                           format: recordingFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }
    }
    
    // MARK: - Bluetooth Management
    
    func updateBluetoothDevices() {
        availableDevices = audioSession.availableInputs ?? []
        
        // Find Bluetooth devices
        let bluetoothDevices = availableDevices.filter { portDesc in
            portDesc.portType == .bluetoothHFP ||
            portDesc.portType == .bluetoothA2DP ||
            portDesc.portType == .bluetoothLE
        }
        
        if let bluetoothDevice = bluetoothDevices.first {
            connectToDevice(bluetoothDevice)
        } else {
            // Fallback to built-in mic
            if let builtInMic = availableDevices.first(where: { $0.portType == .builtInMic }) {
                connectToDevice(builtInMic)
            }
        }
    }
    
    func connectToDevice(_ device: AVAudioSessionPortDescription) {
        do {
            try audioSession.setPreferredInput(device)
            connectedDevice = device
            isBluetoothConnected = (device.portType == .bluetoothHFP || 
                                   device.portType == .bluetoothA2DP ||
                                   device.portType == .bluetoothLE)
            
            print("Connected to audio device: \(device.portName) (\(device.portType.rawValue))")
            
        } catch {
            print("Failed to connect to device: \(error)")
        }
    }
    
    // MARK: - Real Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        // Calculate real audio level
        let level = calculateAudioLevel(samples)
        
        DispatchQueue.main.async { [weak self] in
            self?.currentAudioLevel = level
            self?.isReceivingAudio = level > 0.001
            
            // Send to callbacks
            self?.onAudioLevel?(level)
            self?.onAudioBuffer?(buffer)
        }
    }
    
    private func calculateAudioLevel(_ samples: [Float]) -> Float {
        // Calculate RMS (Root Mean Square) for accurate level
        let sumOfSquares = samples.reduce(0) { $0 + $1 * $1 }
        let rms = sqrt(sumOfSquares / Float(samples.count))
        
        // Convert to dB
        let db = 20 * log10(max(rms, 0.00001))
        
        // Normalize to 0-1 range
        let normalizedLevel = (db + 60) / 60 // -60dB to 0dB range
        
        return max(0, min(1, normalizedLevel))
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        do {
            try startRecordingInternal()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }
    
    private func startRecordingInternal() throws {
        if !audioEngine.isRunning {
            try audioEngine.start()
            startAudioLevelMonitoring()
        }
    }
    
    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            stopAudioLevelMonitoring()
        }
    }
    
    private func startAudioLevelMonitoring() {
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            // Audio level is updated in real-time via the tap
            // This timer can be used for additional processing if needed
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        currentAudioLevel = 0
        isReceivingAudio = false
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        // Audio route changes (device connected/disconnected)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: audioSession
        )
        
        // Audio interruptions
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioInterrupted),
            name: AVAudioSession.interruptionNotification,
            object: audioSession
        )
    }
    
    @objc private func audioRouteChanged(_ notification: Notification) {
        updateBluetoothDevices()
        
        if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt {
            let changeReason = AVAudioSession.RouteChangeReason(rawValue: reason)
            
            switch changeReason {
            case .newDeviceAvailable:
                print("New audio device available")
                updateBluetoothDevices()
                
            case .oldDeviceUnavailable:
                print("Audio device disconnected")
                updateBluetoothDevices()
                
            default:
                break
            }
        }
    }
    
    @objc private func audioInterrupted(_ notification: Notification) {
        if let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
           let type = AVAudioSession.InterruptionType(rawValue: typeValue) {
            
            switch type {
            case .began:
                // Pause recording
                if audioEngine.isRunning {
                    audioEngine.pause()
                }
                
            case .ended:
                // Resume recording
                if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        try? audioEngine.start()
                    }
                }
                
            @unknown default:
                break
            }
        }
    }
    
    // MARK: - Device Information
    
    func getDeviceInfo() -> String {
        guard let device = connectedDevice else {
            return "No device connected"
        }
        
        var info = "Device: \(device.portName)\n"
        info += "Type: \(device.portType.rawValue)\n"
        
        if let dataSources = device.dataSources {
            info += "Data Sources: \(dataSources.map { $0.dataSourceName }.joined(separator: ", "))\n"
        }
        
        if let channels = device.channels {
            info += "Channels: \(channels.count)\n"
        }
        
        return info
    }
    
    // MARK: - Public API
    
    func listAvailableDevices() -> [String] {
        return availableDevices.map { device in
            "\(device.portName) (\(device.portType.rawValue))"
        }
    }
    
    func selectDevice(named deviceName: String) {
        if let device = availableDevices.first(where: { $0.portName == deviceName }) {
            connectToDevice(device)
        }
    }
    
    func getAudioFormat() -> AVAudioFormat? {
        return inputNode?.outputFormat(forBus: 0)
    }
}

#else
// MARK: - macOS Stub Implementation
import Foundation
import Combine
import AVFoundation

@MainActor
class RealTimeBluetoothAudioManager: NSObject, ObservableObject {
    static let shared = RealTimeBluetoothAudioManager()
    
    @Published var connectedDevice: String? = nil
    @Published var isBluetoothConnected = false
    @Published var availableDevices: [String] = []
    @Published var currentAudioLevel: Float = 0.0
    @Published var isReceivingAudio = false
    
    private override init() {
        super.init()
    }
    
    var onAudioBuffer: ((AVAudioPCMBuffer) -> Void)?
    var onAudioLevel: ((Float) -> Void)?
    
    func connectToDevice(_ device: Any) {}
    func updateBluetoothDevices() {}
    func startMonitoring() {}
    func stopMonitoring() {}
    func getCurrentAudioLevel() -> Float { return 0.0 }
    func startRecording() {}
    func stopRecording() {}
}
#endif
