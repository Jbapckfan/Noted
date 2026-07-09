#if os(iOS)
import Foundation
import AVFAudio

/// The real microphone: the ONE `AVAudioEngine` for the whole app (replacing the six
/// competing engine owners). Installs a single input tap, converts the hardware format to the
/// target `AudioFormat` (16 kHz mono 16-bit LE PCM), and streams the bytes to `CaptureController`.
///
/// DEVICE-ONLY — excluded from the macOS build, so it is NOT covered by the `swift test` suite.
/// Verify on device: mic-permission prompt, the `.playAndRecord` session + background-audio
/// capability, and route/interruption handling. The capture *logic* it feeds (CaptureController,
/// WAVWriter — file lifecycle, one-tap handoff, crash recovery) IS fully tested on macOS.
public final class AVAudioEngineInput: AudioInput, @unchecked Sendable {

    public let format: AudioFormat
    private let engine = AVAudioEngine()
    private let outputFormat: AVAudioFormat

    public init(format: AudioFormat = .whisper) {
        self.format = format
        // Interleaved 16-bit signed PCM at the target rate — matches WAVWriter's expectations.
        self.outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: format.sampleRate,
            channels: AVAudioChannelCount(format.channels),
            interleaved: true
        )!
    }

    public func start(onBuffer: @escaping @Sendable (Data) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let input = engine.inputNode
        let hwFormat = input.outputFormat(forBus: 0)
        let outFormat = outputFormat
        guard let converter = AVAudioConverter(from: hwFormat, to: outFormat) else {
            throw CocoaError(.featureUnsupported)
        }

        // The tap closure captures only locals + the sink (never `self`), so the engine→tap
        // retain does not cycle back through this object.
        input.installTap(onBus: 0, bufferSize: 4096, format: hwFormat) { buffer, _ in
            let ratio = outFormat.sampleRate / hwFormat.sampleRate
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 1)
            guard capacity > 0,
                  let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }

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
            onBuffer(Data(bytes: samples[0], count: byteCount))
        }

        engine.prepare()
        try engine.start()
    }

    public func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
