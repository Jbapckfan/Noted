import XCTest
@testable import NotedCoreKit

final class WAVWriterTests: XCTestCase {

    private func tempURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notedcorekit-wav", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rec.wav")
    }

    private func bytes(_ data: Data) -> [UInt8] { [UInt8](data) }
    private func le32(_ b: [UInt8], _ off: Int) -> UInt32 {
        UInt32(b[off]) | (UInt32(b[off+1]) << 8) | (UInt32(b[off+2]) << 16) | (UInt32(b[off+3]) << 24)
    }
    private func ascii(_ b: [UInt8], _ off: Int, _ len: Int) -> String {
        String(bytes: b[off..<off+len], encoding: .ascii) ?? ""
    }

    func testWriteAppendFinalizeProducesValidWAV() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let writer = try WAVWriter(url: url, format: .whisper)
        let pcm1 = Data(repeating: 0x11, count: 320)
        let pcm2 = Data(repeating: 0x22, count: 640)
        writer.append(pcm1)
        writer.append(pcm2)
        let duration = writer.finalize()

        let file = try Data(contentsOf: url)
        let b = bytes(file)
        let dataBytes = pcm1.count + pcm2.count

        XCTAssertEqual(ascii(b, 0, 4), "RIFF")
        XCTAssertEqual(ascii(b, 8, 4), "WAVE")
        XCTAssertEqual(ascii(b, 12, 4), "fmt ")
        XCTAssertEqual(ascii(b, 36, 4), "data")
        XCTAssertEqual(Int(le32(b, 4)), 36 + dataBytes, "RIFF chunk size patched")
        XCTAssertEqual(Int(le32(b, 40)), dataBytes, "data chunk size patched")
        XCTAssertEqual(file.count, 44 + dataBytes, "header + all PCM present")
        XCTAssertEqual(Array(b[44..<44+320]), Array(pcm1), "PCM streamed intact")
        XCTAssertEqual(Array(b[(44+320)..<(44+dataBytes)]), Array(pcm2))
        XCTAssertEqual(duration, Double(dataBytes) / Double(AudioFormat.whisper.byteRate), accuracy: 1e-9)
    }

    func testRepairFixesUnfinalizedHeaderAfterCrash() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // Write header + PCM but never finalize — simulating a crash mid-record.
        let pcm = Data(repeating: 0x33, count: 3200)
        do {
            let writer = try WAVWriter(url: url, format: .whisper)
            writer.append(pcm)
            // no finalize(); drop the writer so its handle closes (process "died")
        }

        // Before repair: header still claims 0 data bytes.
        let before = bytes(try Data(contentsOf: url))
        XCTAssertEqual(Int(le32(before, 40)), 0, "unfinalized header has placeholder size")
        XCTAssertEqual(before.count, 44 + pcm.count, "the PCM bytes DID survive on disk")

        let recoveredDuration = try WAVWriter.repair(at: url)

        let after = bytes(try Data(contentsOf: url))
        XCTAssertEqual(Int(le32(after, 40)), pcm.count, "data size rebuilt from file length")
        XCTAssertEqual(Int(le32(after, 4)), 36 + pcm.count, "RIFF size rebuilt")
        XCTAssertEqual(Array(after[44..<44+pcm.count]), Array(pcm), "recovered PCM intact")
        XCTAssertEqual(recoveredDuration, Double(pcm.count) / Double(AudioFormat.whisper.byteRate), accuracy: 1e-9)
    }

    func testRepairIgnoresTooShortFile() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try Data([0x01, 0x02]).write(to: url) // shorter than a header
        let dur = try WAVWriter.repair(at: url)
        XCTAssertEqual(dur, 0)
    }
}
