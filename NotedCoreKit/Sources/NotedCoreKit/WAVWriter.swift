import Foundation

/// Streams 16-bit PCM to a `.wav` file **incrementally**, so a crash or force-kill mid-record
/// leaves a file that is playable/transcribable up to the last flushed buffer.
///
/// The trick: a 44-byte header is written up front with PLACEHOLDER sizes, PCM frames are
/// appended as they arrive, and `finalize()` seeks back to patch the RIFF/`data` chunk sizes.
/// If the app dies before `finalize()`, the header still says size 0 — so `WAVWriter.repair(at:)`
/// recomputes the sizes from the actual file length and makes the partial recording valid.
///
/// Thread-safe: `append` runs on the real-time audio thread while `finalize` may run on the
/// capture actor; an internal lock guards the file handle.
public final class WAVWriter: @unchecked Sendable {

    public let url: URL
    public let format: AudioFormat

    private let lock = NSLock()
    private var handle: FileHandle?
    private var dataBytes: Int = 0
    private var finalized = false

    private static let headerSize = 44

    public init(url: URL, format: AudioFormat) throws {
        self.url = url
        self.format = format
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let h = try FileHandle(forWritingTo: url)
        self.handle = h
        h.write(Self.header(format: format, dataBytes: 0)) // placeholder sizes
    }

    /// Bytes of PCM written so far (excludes the 44-byte header).
    public var bytesWritten: Int {
        lock.lock(); defer { lock.unlock() }
        return dataBytes
    }

    public var duration: TimeInterval {
        format.byteRate > 0 ? Double(bytesWritten) / Double(format.byteRate) : 0
    }

    /// Append raw PCM (matching `format`). Cheap, non-throwing — safe to call from an audio tap.
    public func append(_ pcm: Data) {
        lock.lock(); defer { lock.unlock() }
        guard let h = handle, !finalized, !pcm.isEmpty else { return }
        h.seekToEndOfFile()
        h.write(pcm)
        dataBytes += pcm.count
    }

    /// Patch the header sizes and close the file. Returns the recording duration.
    @discardableResult
    public func finalize() -> TimeInterval {
        lock.lock(); defer { lock.unlock() }
        guard let h = handle, !finalized else { return duration }
        Self.patchSizes(handle: h, dataBytes: dataBytes)
        try? h.synchronize()
        try? h.close()
        handle = nil
        finalized = true
        return format.byteRate > 0 ? Double(dataBytes) / Double(format.byteRate) : 0
    }

    // MARK: - Crash recovery

    /// Repair a WAV whose header was never finalized (app died mid-record): recompute the
    /// chunk sizes from the real file length so the file becomes valid + playable.
    /// Returns the recovered duration. A file too short to hold a header is left untouched.
    @discardableResult
    public static func repair(at url: URL) throws -> TimeInterval {
        let h = try FileHandle(forUpdating: url)
        defer { try? h.close() }
        let size = Int(try h.seekToEnd())
        guard size >= headerSize else { return 0 }

        let dataBytes = size - headerSize
        try h.seek(toOffset: 4)
        h.write(le32(UInt32(size - 8)))          // RIFF chunk size
        try h.seek(toOffset: 40)
        h.write(le32(UInt32(dataBytes)))         // data chunk size
        try? h.synchronize()

        // byteRate lives at offset 28 in the fmt chunk — use it to report duration.
        try h.seek(toOffset: 28)
        let byteRateData = try h.read(upToCount: 4) ?? Data()
        let byteRate = byteRateData.count == 4 ? Int(le32Value(byteRateData)) : 0
        return byteRate > 0 ? Double(dataBytes) / Double(byteRate) : 0
    }

    // MARK: - Header

    private static func header(format: AudioFormat, dataBytes: Int) -> Data {
        var d = Data()
        let byteRate = UInt32(Int(format.sampleRate) * format.channels * (format.bitDepth / 8))
        let blockAlign = UInt16(format.channels * (format.bitDepth / 8))

        d.append(contentsOf: Array("RIFF".utf8))
        d.append(le32(UInt32(36 + dataBytes)))
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8))
        d.append(le32(16))                        // PCM fmt chunk size
        d.append(le16(1))                         // audioFormat = PCM
        d.append(le16(UInt16(format.channels)))
        d.append(le32(UInt32(format.sampleRate)))
        d.append(le32(byteRate))
        d.append(le16(blockAlign))
        d.append(le16(UInt16(format.bitDepth)))
        d.append(contentsOf: Array("data".utf8))
        d.append(le32(UInt32(dataBytes)))
        return d
    }

    private static func patchSizes(handle: FileHandle, dataBytes: Int) {
        try? handle.seek(toOffset: 4)
        handle.write(le32(UInt32(36 + dataBytes)))
        try? handle.seek(toOffset: 40)
        handle.write(le32(UInt32(dataBytes)))
    }

    private static func le16(_ v: UInt16) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff)])
    }
    private static func le32(_ v: UInt32) -> Data {
        Data([UInt8(v & 0xff), UInt8((v >> 8) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 24) & 0xff)])
    }
    private static func le32Value(_ d: Data) -> UInt32 {
        let b = [UInt8](d)
        return UInt32(b[0]) | (UInt32(b[1]) << 8) | (UInt32(b[2]) << 16) | (UInt32(b[3]) << 24)
    }
}
