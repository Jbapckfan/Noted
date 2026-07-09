import Foundation

/// Linear-PCM audio format for on-device capture. Default is Whisper-friendly:
/// 16 kHz, mono, 16-bit signed — small on disk, ideal for STT, no resample needed downstream.
public struct AudioFormat: Equatable, Sendable {
    public var sampleRate: Double
    public var channels: Int
    public var bitDepth: Int   // bits per sample

    public init(sampleRate: Double = 16_000, channels: Int = 1, bitDepth: Int = 16) {
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitDepth = bitDepth
    }

    /// Bytes for one frame (all channels, one sample each).
    public var bytesPerFrame: Int { channels * (bitDepth / 8) }

    /// Bytes per second of audio — used to derive duration from a file's data size.
    public var byteRate: Int { Int(sampleRate) * bytesPerFrame }

    public static let whisper = AudioFormat(sampleRate: 16_000, channels: 1, bitDepth: 16)
}
