import AVFoundation
import Accelerate

#if targetEnvironment(simulator)
import Foundation
#endif

final class AudioCaptureService: NSObject, ObservableObject {
    static let shared = AudioCaptureService()
    @Published var level: Float = 0.0
    @Published var isRecording: Bool = false
    @Published var error: AudioError?
    
    // Enhanced services (will be initialized in init)
    var pauseDetection: PauseDetectionService!
    var speakerIdentification: SpeakerIdentificationService!
    
    private let engine = AVAudioEngine()
    private var audioBuffer: CircularBuffer<Float>
    private var recordingStartTime: TimeInterval = 0
    
    // Audio processing constants - INSTANT PROCESSING
    private let sampleRate: Double = 16000  // WhisperKit native
    private let bufferSize: AVAudioFrameCount = 2048  // Balanced for quality
    private let channelCount: UInt32 = 1
    
    // DSP components
    private var noiseGate: NoiseGate
    private var levelMeter: AudioLevelProcessor
    
    // VAD state
    private var vadIsVoice = false
    private var vadSpeechFrames = 0
    private var vadSilenceFrames = 0
    private let vadRmsThreshold: Float = 0.005 // tuned for 16k amplified audio
    private let vadMaxThreshold: Float = 0.02
    private let vadEnterFrames = 3   // require N consecutive speech frames
    private let vadExitFrames = 8    // require N consecutive silence frames
    
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
        // Buffer for 16kHz sampling - direct WhisperKit compatibility
        self.audioBuffer = CircularBuffer<Float>(capacity: Int(sampleRate * 60), defaultValue: 0.0)
        // Optimized noise gate for medical conversations
        self.noiseGate = NoiseGate(threshold: -45.0)  // Better noise rejection
        self.levelMeter = AudioLevelProcessor()
        super.init()
        
        // Initialize enhanced services on main thread
        Task { @MainActor in
            self.pauseDetection = PauseDetectionService()
            self.speakerIdentification = SpeakerIdentificationService()
        }
        
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
            #if os(iOS)
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
            #else
            // macOS doesn't use AVAudioSession, permissions handled differently
            print("✅ macOS audio permissions handled by system")
            #endif
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
            
            #if os(iOS)
            // Let's also check if the input node is actually getting any input
            let session = AVAudioSession.sharedInstance()
            print("📊 Session input available: \(session.isInputAvailable)")
            print("📊 Session input gain: \(session.inputGain)")
            print("📊 Session input number of channels: \(session.inputNumberOfChannels)")
            #else
            print("📊 macOS: Input node status check - using AVAudioEngine directly")
            #endif
            
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
        
        // Reset enhanced services
        Task { @MainActor in
            pauseDetection.reset()
            speakerIdentification.reset()
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
        #if os(iOS)
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
                mode: .spokenAudio,  // Optimized for speech
                options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker, .mixWithOthers]
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
        #else
        // macOS: AVAudioSession is not available, audio configuration handled by AVAudioEngine
        print("🍎 macOS: Audio session configuration not needed - using AVAudioEngine directly")
        print("✅ macOS audio configuration complete")
        #endif
    }
    
    private func prioritizeBluetoothMicrophone() {
        #if os(iOS)
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
        #else
        // macOS: Bluetooth microphone selection handled differently
        print("🍎 macOS: Bluetooth microphone selection handled by system preferences")
        Task { @MainActor in
            CoreAppState.shared.activeMicrophone = .builtIn
            CoreAppState.shared.isBluetoothAvailable = false
        }
        #endif
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
        guard let channelData = buffer.floatChannelData?[0] else { 
            print("❌ No channel data in audio buffer")
            return 
        }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { 
            print("❌ Empty audio buffer (0 frames)")
            return 
        }
        print("🎤 Processing audio buffer with \(frameCount) frames")
        
        // Calculate audio level efficiently using vDSP
        var rawSum: Float = 0.0
        vDSP_sve(channelData, 1, &rawSum, vDSP_Length(frameCount))
        let simpleLevel = min(1.0, (rawSum / Float(frameCount)) * 100.0)
        
        // Enhanced processing
        let currentTime = Date().timeIntervalSince1970 - recordingStartTime
        
        // Pause detection - TEMPORARILY DISABLED DUE TO CRASH
        // Will fix buffer access bounds checking
        /*
        Task { @MainActor in
            pauseDetection.processAudioBuffer(buffer, at: currentTime)
            
            // Speaker identification
            let _ = speakerIdentification.analyzeAudioBuffer(buffer, at: currentTime)
        }
        */
        
        // DEBUG: Check if we're getting actual audio data
        let maxValue = channelData.withMemoryRebound(to: Float.self, capacity: frameCount) { ptr in
            return (0..<frameCount).map { abs(ptr[$0]) }.max() ?? 0
        }
        
        // Calculate RMS for better voice activity detection
        var rms: Float = 0
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameCount))
        
        // Simple VAD state machine
        let speechLike = (rms > vadRmsThreshold) || (maxValue > vadMaxThreshold)
        if speechLike {
            vadSpeechFrames += 1
            vadSilenceFrames = 0
        } else {
            vadSilenceFrames += 1
            vadSpeechFrames = 0
        }
        if !vadIsVoice && vadSpeechFrames >= vadEnterFrames { vadIsVoice = true }
        if vadIsVoice && vadSilenceFrames >= vadExitFrames { vadIsVoice = false }
        
        // Get the actual sample rate of the input buffer
        let inputSampleRate = buffer.format.sampleRate
        print("📊 Input sample rate: \(inputSampleRate)Hz, target: \(sampleRate)Hz")
        
        // Convert to array for processing
        let rawAudio = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // Resample to 16kHz if needed (WhisperKit requirement)
        let resampledAudio: [Float]
        if abs(inputSampleRate - sampleRate) > 1.0 {
            print("🔄 Resampling from \(inputSampleRate)Hz to \(sampleRate)Hz")
            resampledAudio = AudioResampler.resampleForWhisperKit(rawAudio, fromRate: inputSampleRate)
            print("📏 Resampled: \(frameCount) samples → \(resampledAudio.count) samples")
        } else {
            resampledAudio = rawAudio
        }
        
        // Apply smart amplification with medical speech optimization
        let maxAmplitude = resampledAudio.map { abs($0) }.max() ?? 0.001
        
        // Dynamic amplification based on signal strength
        let amplificationFactor: Float
        if maxAmplitude < 0.001 {
            // Very quiet - likely ambient noise, amplify moderately
            amplificationFactor = 5.0
        } else if maxAmplitude < 0.01 {
            // Quiet speech - amplify significantly
            amplificationFactor = min(30.0, 0.3 / maxAmplitude)
        } else if maxAmplitude < 0.1 {
            // Normal speech - moderate amplification
            amplificationFactor = min(10.0, 0.5 / maxAmplitude)
        } else {
            // Loud speech - minimal amplification
            amplificationFactor = min(3.0, 0.7 / maxAmplitude)
        }
        
        print("🎚️ Amplification: \(amplificationFactor)x for max amplitude \(maxAmplitude)")
        let amplifiedAudio = resampledAudio.map { $0 * amplificationFactor }
        
        // CRITICAL FIX: Use the actual count of resampled audio
        let actualSampleCount = amplifiedAudio.count
        
        // Store raw audio in circular buffer 
        audioBuffer.write(channelData, count: frameCount)
        
        // Apply free audio optimizations for better quality
        if let pcmBuffer = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 1)!, frameCapacity: AVAudioFrameCount(actualSampleCount)) {
            pcmBuffer.frameLength = AVAudioFrameCount(actualSampleCount)
            
            // Copy data to PCM buffer - USE ACTUAL SAMPLE COUNT
            if let channelDataPtr = pcmBuffer.floatChannelData?[0] {
                for i in 0..<actualSampleCount {
                    channelDataPtr[i] = amplifiedAudio[i]
                }
            }
            
            // Simplified audio processing
            // Voice activity detection and noise reduction would go here
        }
        
        // INSTANT MULTI-PIPELINE with VAD gating
        if vadIsVoice {
            Task {
                // DISABLED SimpleWhisperService to prevent duplicate transcription
                // await SimpleWhisperService.shared.processAudio(amplifiedAudio)
                
                // Use ProductionWhisperService as the primary transcription service
                await ProductionWhisperService.shared.enqueueAudio(amplifiedAudio, frameCount: actualSampleCount)
                
                // Identify speaker in parallel
                await MainActor.run {
                    _ = VoiceIdentificationEngine.shared.identifySpeaker(
                        from: amplifiedAudio,
                        sampleRate: Float(sampleRate)
                    )
                    GeniusMedicalBrain.shared.processInstant(amplifiedAudio)
                }
            }
            
            // DISABLED: Apple Speech Recognizer - Using WhisperKit for offline capability
            // Task { @MainActor in
            //     SpeechRecognitionService.shared.processAudioBuffer(buffer)
            // }
        }
        
        // Update UI level
        Task { @MainActor in
            self.level = simpleLevel
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        #if os(iOS)
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
        #else
        // macOS: Audio session notifications not available
        print("🍎 macOS: Audio session notifications not needed")
        #endif
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        #if os(iOS)
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
        #else
        // macOS: Audio session interruptions not applicable
        print("🍎 macOS: Audio session interruption handling not needed")
        #endif
    }
    
    @objc private func handleAudioSessionRouteChange(_ notification: Notification) {
        print("🔄 Audio route changed")
        prioritizeBluetoothMicrophone()
    }
}
