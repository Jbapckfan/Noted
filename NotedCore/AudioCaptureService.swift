import AVFoundation
import Accelerate

#if targetEnvironment(simulator)
import Foundation
#endif

final class AudioCaptureService: NSObject, ObservableObject {
    @Published var level: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var error: AudioError?
    
    private let engine = AVAudioEngine()
    private var audioBuffer: CircularBuffer<Float>
    
    // Audio processing constants - PRODUCTION OPTIMIZED
    private let sampleRate: Double = 48000  // Higher quality for medical terminology
    private let bufferSize: AVAudioFrameCount = 4096  // Larger buffer for better processing
    private let channelCount: UInt32 = 1
    
    // DSP components
    private var noiseGate: NoiseGate
    private var levelMeter: AudioLevelProcessor
    
    enum AudioError: Error, LocalizedError {
        case permissionDenied
        case sessionConfigurationFailed
        case engineStartFailed
        case bluetoothConnectionFailed
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "Microphone permission denied"
            case .sessionConfigurationFailed:
                return "Audio session configuration failed"
            case .engineStartFailed:
                return "Audio engine failed to start"
            case .bluetoothConnectionFailed:
                return "Bluetooth microphone connection failed"
            }
        }
    }
    
    override init() {
        // Increased buffer capacity for 48kHz sampling
        self.audioBuffer = CircularBuffer<Float>(capacity: Int(sampleRate * 60), defaultValue: 0.0)
        // Less aggressive noise gate for medical conversations
        self.noiseGate = NoiseGate(threshold: -50.0)
        self.levelMeter = AudioLevelProcessor()
        super.init()
        
        setupNotificationObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Public Interface
    
    func requestPermission() async throws {
        // Use iOS 17+ API if available, fallback to older API
        if #available(iOS 17.0, *) {
            let currentStatus = AVAudioApplication.shared.recordPermission
            print("🔒 Current permission status: \(currentStatus)")
            
            switch currentStatus {
            case .granted:
                print("✅ Permission already granted")
                return
            case .denied:
                print("❌ Permission previously denied")
                throw AudioError.permissionDenied
            case .undetermined:
                print("❓ Permission undetermined, requesting...")
                let permission = await withCheckedContinuation { continuation in
                    AVAudioApplication.requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                if !permission {
                    print("❌ Permission denied by user")
                    throw AudioError.permissionDenied
                }
                print("✅ Permission granted by user")
            @unknown default:
                print("❓ Unknown permission status")
                throw AudioError.permissionDenied
            }
        } else {
            // Fallback for iOS < 17
            let currentStatus = AVAudioSession.sharedInstance().recordPermission
            print("🔒 Current permission status: \(currentStatus)")
            
            switch currentStatus {
            case .granted:
                print("✅ Permission already granted")
                return
            case .denied:
                print("❌ Permission previously denied")
                throw AudioError.permissionDenied
            case .undetermined:
                print("❓ Permission undetermined, requesting...")
                let permission = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
                if !permission {
                    print("❌ Permission denied by user")
                    throw AudioError.permissionDenied
                }
                print("✅ Permission granted by user")
            @unknown default:
                print("❓ Unknown permission status")
                throw AudioError.permissionDenied
            }
        }
    }
    
    func start() async throws {
        print("🎙️ Starting audio capture...")
        
        do {
            try await requestPermission()
            print("✅ Permission granted")
        } catch {
            print("❌ Permission denied: \(error)")
            throw error
        }
        
        do {
            try configureAudioSession()
            print("✅ Audio session configured")
        } catch {
            print("❌ Audio session configuration failed: \(error)")
            throw error
        }
        
        do {
            try setupAudioEngine()
            print("✅ Audio engine setup complete")
        } catch {
            print("❌ Audio engine setup failed: \(error)")
            throw error
        }
        
        do {
            try engine.start()
            print("✅ Audio engine started successfully")
            print("📊 Engine is running: \(engine.isRunning)")
            print("📊 Input node has tap: \(engine.inputNode.numberOfOutputs > 0)")
            print("📊 Input node format: \(engine.inputNode.outputFormat(forBus: 0))")
            print("📊 Engine manual render mode: \(engine.isInManualRenderingMode)")
            
            // Let's also check if the input node is actually getting any input
            let session = AVAudioSession.sharedInstance()
            print("📊 Session input available: \(session.isInputAvailable)")
            print("📊 Session input gain: \(session.inputGain)")
            print("📊 Session input number of channels: \(session.inputNumberOfChannels)")
            
            await MainActor.run {
                self.isRecording = true
                self.error = nil
            }
        } catch {
            print("❌ Audio engine start failed: \(error)")
            throw AudioError.engineStartFailed
        }
    }
    
    func stop() {
        print("🛑 Stopping audio capture...")
        
        // PRODUCTION: Finalize with enhanced service
        Task {
            await ProductionWhisperService.shared.finalizeCurrentSession()
        }
        
        if engine.isRunning {
            engine.stop()
            print("✅ Audio engine stopped")
        }
        
        // Only remove tap if it was installed
        if engine.inputNode.numberOfOutputs > 0 {
            engine.inputNode.removeTap(onBus: 0)
            print("✅ Input node tap removed")
        }
        
        Task { @MainActor in
            self.isRecording = false
            self.level = 0.0
        }
    }
    
    // MARK: - Audio Session Configuration
    
    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        do {
            print("🔧 Configuring audio session...")
            print("📊 Available inputs: \(session.availableInputs?.map { $0.portName } ?? [])")
            print("📊 Current input: \(session.currentRoute.inputs.map { $0.portName })")
            
            #if targetEnvironment(simulator)
            print("🤖 Running in iOS Simulator")
            // On simulator, try playAndRecord category for better compatibility
            try session.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.allowBluetooth]
            )
            #else
            print("📱 Running on physical device")
            // Configure for high-quality recording with Bluetooth priority
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
            )
            #endif
            print("✅ Audio session category set to: \(session.category)")
            
            // Set preferred sample rate
            try session.setPreferredSampleRate(sampleRate)
            print("✅ Sample rate set to \(sampleRate)")
            
            try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
            print("✅ Buffer duration set")
            
            // Activate session
            try session.setActive(true)
            print("✅ Audio session activated")
            
            // Log current session settings
            print("📊 Current sample rate: \(session.sampleRate)")
            print("📊 Current IO buffer duration: \(session.ioBufferDuration)")
            print("📊 Current input gain: \(session.inputGain)")
            print("📊 Input available: \(session.isInputAvailable)")
            print("📊 Input gain settable: \(session.isInputGainSettable)")
            print("📊 Current route inputs: \(session.currentRoute.inputs.map { "\($0.portName) (\($0.portType))" })")
            
            // Prioritize Bluetooth microphone if available
            prioritizeBluetoothMicrophone()
            
        } catch {
            print("❌ Audio session configuration failed: \(error)")
            throw AudioError.sessionConfigurationFailed
        }
    }
    
    private func prioritizeBluetoothMicrophone() {
        let session = AVAudioSession.sharedInstance()
        
        // Find Bluetooth HFP input
        if let bluetoothInput = session.availableInputs?.first(where: {
            $0.portType == .bluetoothHFP
        }) {
            do {
                try session.setPreferredInput(bluetoothInput)
                Task { @MainActor in
                    CoreAppState.shared.activeMicrophone = .bluetooth(name: bluetoothInput.portName)
                    CoreAppState.shared.isBluetoothAvailable = true
                }
                print("✅ Bluetooth microphone set: \(bluetoothInput.portName)")
            } catch {
                print("❌ Failed to set Bluetooth input: \(error)")
            }
        } else {
            print("ℹ️ No Bluetooth microphone available")
        }
    }
    
    // MARK: - Audio Engine Setup
    
    private func setupAudioEngine() throws {
        print("🔧 Setting up audio engine...")
        
        // Clean up any existing setup
        if engine.isRunning {
            print("⚠️ Stopping existing engine")
            engine.stop()
        }
        
        // Remove any existing tap from input node
        if engine.inputNode.numberOfOutputs > 0 {
            print("⚠️ Removing existing tap from input node")
            engine.inputNode.removeTap(onBus: 0)
        }
        
        // Reset the engine
        print("🔄 Resetting audio engine")
        engine.reset()
        
        guard let format = AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        ) else {
            print("❌ Failed to create audio format")
            throw AudioError.engineStartFailed
        }
        
        print("✅ Audio format created: \(format)")
        
        // Get the input node's actual format
        let inputFormat = engine.inputNode.outputFormat(forBus: 0)
        print("📊 Input node format: \(inputFormat)")
        
        // Install tap directly on input node with its native format (nil = use input node's format)
        print("🎯 Installing tap on input node")
        print("📊 Input node format before tap: \(inputFormat)")
        print("📊 Input node number of inputs: \(engine.inputNode.numberOfInputs)")
        print("📊 Input node number of outputs: \(engine.inputNode.numberOfOutputs)")
        
        engine.inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: nil) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, at: time)
        }
        print("✅ Tap installed successfully")
        print("📊 Input node outputs after tap: \(engine.inputNode.numberOfOutputs)")
        
        print("⚡ Preparing audio engine")
        engine.prepare()
        
        print("✅ Audio engine setup complete")
    }
    
    // MARK: - Real-time Audio Processing
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }
        
        // Calculate audio level efficiently using vDSP
        var rawSum: Float = 0.0
        vDSP_sve(channelData, 1, &rawSum, vDSP_Length(frameCount))
        let simpleLevel = min(1.0, (rawSum / Float(frameCount)) * 100.0)
        
        // Apply conservative gain for WhisperKit (prevent distortion)
        let gainFactor: Float = 2.0 // Reduced from 5.0 to prevent clipping
        var amplifiedAudio = Array<Float>(repeating: 0.0, count: frameCount)
        var gainFactorArray = [gainFactor]
        vDSP_vsmul(channelData, 1, &gainFactorArray, &amplifiedAudio, 1, vDSP_Length(frameCount))
        
        // Apply soft limiting to prevent clipping
        for i in 0..<frameCount {
            if amplifiedAudio[i] > 1.0 {
                amplifiedAudio[i] = 1.0
            } else if amplifiedAudio[i] < -1.0 {
                amplifiedAudio[i] = -1.0
            }
        }
        
        // Store raw audio in circular buffer 
        audioBuffer.write(channelData, count: frameCount)
        
        // Apply free audio optimizations for better quality
        if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!, frameCapacity: AVAudioFrameCount(frameCount)) {
            pcmBuffer.frameLength = AVAudioFrameCount(frameCount)
            
            // Copy data to PCM buffer
            if let channelDataPtr = pcmBuffer.floatChannelData?[0] {
                for i in 0..<frameCount {
                    channelDataPtr[i] = amplifiedAudio[i]
                }
            }
            
            // Apply noise reduction and voice activity detection
            if OptimizedAudioProcessor.detectVoiceActivity(in: pcmBuffer) {
                // Apply noise reduction and normalization
                if let processedBuffer = OptimizedAudioProcessor.reduceNoise(from: pcmBuffer) {
                    if let normalizedBuffer = OptimizedAudioProcessor.normalizeAudioLevel(audioBuffer: processedBuffer) {
                        // Use optimized audio
                        if let optimizedData = normalizedBuffer.floatChannelData?[0] {
                            for i in 0..<frameCount {
                                amplifiedAudio[i] = optimizedData[i]
                            }
                        }
                    }
                }
            }
        }
        
        // ZERO-LATENCY: Send to revolutionary streaming engine
        Task {
            // Use zero-latency triple-pipeline for instant transcription
            await CoreAppState.shared.zeroLatencyEngine.processAudioStream(amplifiedAudio, sampleRate: Float(sampleRate))
            
            // Revolutionary features:
            // - <100ms text appearance via fast pipeline
            // - 2s accurate refinement via base model
            // - Real-time medical correction and validation
            // - Streaming display with confidence indicators
            // - Zero additional costs - only open source components
        }
        
        // Update UI level
        Task { @MainActor in
            self.level = simpleLevel
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔇 Audio session interrupted")
            stop()
        case .ended:
            print("🔊 Audio session interruption ended")
            // Optionally restart recording
            break
        @unknown default:
            break
        }
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        print("🔄 Audio route changed")
        prioritizeBluetoothMicrophone()
    }
}
