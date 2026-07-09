#if os(iOS)
import Foundation
import AVFAudio
import NotedCoreKit

/// The real microphone: the ONE `AVAudioEngine` for the whole app (replacing the six competing
/// engine owners). Installs a single input tap, converts the hardware format to the target
/// `AudioFormat` (16 kHz mono 16-bit LE PCM), and streams the bytes to `CaptureController`.
///
/// Bluetooth-aware: `.allowBluetooth` enables the HFP input profile, a connected BT mic is
/// PREFERRED (via the unit-tested `AudioRoutePolicy`), and route changes are handled — if a BT
/// device connects or drops MID-recording, the tap is rebuilt against the new hardware format so
/// capture keeps going instead of silently dying.
///
/// DEVICE-ONLY — excluded from the macOS build/tests. The input-SELECTION logic it relies on is
/// tested in NotedCoreKit (`AudioRoutePolicyTests`); verify actual BT routing on device with your mic.
public final class AVAudioEngineInput: AudioInput, @unchecked Sendable {

    public let format: AudioFormat
    /// Optional manual override (e.g. a Settings toggle); honored when still available.
    public var manualPreference: AudioInputKind?

    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat
    private let lock = NSLock()
    private var sink: (@Sendable (Data) -> Void)?
    private var routeObserver: NSObjectProtocol?

    public init(format: AudioFormat = .whisper, manualPreference: AudioInputKind? = nil) {
        self.format = format
        self.manualPreference = manualPreference
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(format.channels),
            interleaved: true
        )!
    }

    public func start(onBuffer: @escaping @Sendable (Data) -> Void) throws {
        lock.lock(); sink = onBuffer; lock.unlock()

        let session = AVAudioSession.sharedInstance()
        // `.default` mode (not `.measurement`) routes reliably to Bluetooth HFP; `.allowBluetooth`
        // is the HFP INPUT profile (A2DP is output-only). Trade-off: `.default` applies light input
        // processing vs `.measurement`'s raw signal — acceptable for a BT scribe.
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        try selectPreferredInput(session)
        observeRouteChanges(session)
        try installTapAndStart()
    }

    public func stop() {
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver); self.routeObserver = nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.lock(); sink = nil; lock.unlock()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Input selection

    private func selectPreferredInput(_ session: AVAudioSession) throws {
        let ports = session.availableInputs ?? []
        let options = ports.map { AudioInputOption(name: $0.portName, kind: kind(for: $0.portType)) }
        let manual = manualPreference.flatMap { pref in options.first { $0.kind == pref } }
        guard let chosen = AudioRoutePolicy.preferred(from: options, manual: manual),
              let port = ports.first(where: { $0.portName == chosen.name }) else { return }
        try? session.setPreferredInput(port)
    }

    private func kind(for portType: AVAudioSession.Port) -> AudioInputKind {
        switch portType {
        case .bluetoothHFP:
            return .bluetooth
        case .headsetMic, .usbAudio, .lineIn, .carAudio:
            return .wired
        case .builtInMic:
            return .builtIn
        default:
            return .other
        }
    }

    // MARK: - Tap

    private func installTapAndStart() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0) // idempotent — safe to call before (re)install
        let hwFormat = input.outputFormat(forBus: 0)
        guard hwFormat.sampleRate > 0,
              let converter = AVAudioConverter(from: hwFormat, to: outputFormat) else {
            throw CocoaError(.featureUnsupported)
        }
        let outFormat = outputFormat
        let deliver: (@Sendable (Data) -> Void)? = { [lock] data in
            lock.lock(); let s = self.sink; lock.unlock(); s?(data)
        }

        input.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { buffer, _ in
            let ratio = outFormat.sampleRate / hwFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
            guard capacity > 0, let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
            var consumed = false
            var convErr: NSError?
            converter.convert(to: out, error: &convErr) { _, status in
                if consumed { status.pointee = .noDataNow; return nil }
                consumed = true
                status.pointee = .haveData
                return buffer
            }
            guard convErr == nil, out.frameLength > 0, let samples = out.int16ChannelData else { return }
            let byteCount = Int(out.frameLength) * Int(outFormat.channelCount) * MemoryLayout<Int16>.size
            deliver?(Data(bytes: samples[0], count: byteCount))
        }

        engine.prepare()
        try engine.start()
    }

    // MARK: - Route changes (Bluetooth connect/disconnect mid-recording)

    private func observeRouteChanges(_ session: AVAudioSession) {
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: nil
        ) { [weak self] note in
            guard let self,
                  let raw = note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
            switch reason {
            case .newDeviceAvailable, .oldDeviceUnavailable, .override, .routeConfigurationChange:
                // A mic (often Bluetooth) appeared or dropped — re-pick the input and rebuild the
                // tap against the new hardware format so recording continues uninterrupted.
                self.engine.stop()
                try? self.selectPreferredInput(session)
                try? self.installTapAndStart()
            default:
                break
            }
        }
    }
}
#endif
