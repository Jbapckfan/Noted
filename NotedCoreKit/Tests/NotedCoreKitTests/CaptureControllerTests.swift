import XCTest
@testable import NotedCoreKit

/// A fake mic: stores the capture callback and lets tests push synthetic PCM synchronously.
private final class FakeAudioInput: AudioInput, @unchecked Sendable {
    let format: AudioFormat
    private let lock = NSLock()
    private var sink: (@Sendable (Data) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(format: AudioFormat = .whisper) { self.format = format }

    func start(onBuffer: @escaping @Sendable (Data) -> Void) throws {
        lock.lock(); sink = onBuffer; startCount += 1; lock.unlock()
    }
    func stop() {
        lock.lock(); sink = nil; stopCount += 1; lock.unlock()
    }
    /// Deliver a synthetic audio buffer as if from the real-time audio thread.
    func push(_ data: Data) {
        lock.lock(); let s = sink; lock.unlock(); s?(data)
    }
}

final class CaptureControllerTests: XCTestCase {

    private func tempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("notedcorekit-capture", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return dir
    }
    private func dataSize(ofWAV url: URL) throws -> Int {
        let b = [UInt8](try Data(contentsOf: url))
        return Int(UInt32(b[40]) | (UInt32(b[41]) << 8) | (UInt32(b[42]) << 16) | (UInt32(b[43]) << 24))
    }

    func testRecordThreeEncountersBackToBack() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fake = FakeAudioInput()
        let controller = CaptureController(audioDirectory: dir, input: fake)

        var results: [RecordingResult] = []
        for i in 0..<3 {
            let id = UUID()
            _ = try await controller.begin(encounterID: id)
            fake.push(Data(repeating: UInt8(i + 1), count: 320))
            fake.push(Data(repeating: UInt8(i + 1), count: 320))
            let r = try await controller.end()
            XCTAssertEqual(r.encounterID, id)
            XCTAssertEqual(r.audioFileRelPath, "\(id.uuidString).wav")
            XCTAssertEqual(r.byteCount, 640, "both buffers streamed to this encounter's file")
            results.append(r)
        }

        XCTAssertEqual(Set(results.map(\.audioFileRelPath)).count, 3, "three distinct files")
        for r in results {
            let url = dir.appendingPathComponent(r.audioFileRelPath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertEqual(try dataSize(ofWAV: url), 640, "each file finalized with its own audio")
        }
        XCTAssertEqual(fake.startCount, 3)
        XCTAssertEqual(fake.stopCount, 3)
    }

    func testOneTapHandoff() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fake = FakeAudioInput()
        let controller = CaptureController(audioDirectory: dir, input: fake)

        let id1 = UUID(), id2 = UUID()
        _ = try await controller.begin(encounterID: id1)
        fake.push(Data(repeating: 0xA1, count: 320))
        let (finished, nextURL) = try await controller.endAndBegin(nextEncounterID: id2)
        fake.push(Data(repeating: 0xB2, count: 640))
        let second = try await controller.end()

        XCTAssertEqual(finished.encounterID, id1)
        XCTAssertEqual(finished.byteCount, 320)
        XCTAssertEqual(second.encounterID, id2)
        XCTAssertEqual(second.byteCount, 640)
        XCTAssertEqual(nextURL.lastPathComponent, "\(id2.uuidString).wav")
        XCTAssertEqual(try dataSize(ofWAV: dir.appendingPathComponent(finished.audioFileRelPath)), 320)
        XCTAssertEqual(try dataSize(ofWAV: dir.appendingPathComponent(second.audioFileRelPath)), 640)
    }

    func testCannotBeginWhileAlreadyRecording() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let controller = CaptureController(audioDirectory: dir, input: FakeAudioInput())

        let id1 = UUID()
        _ = try await controller.begin(encounterID: id1)
        do {
            _ = try await controller.begin(encounterID: UUID())
            XCTFail("second concurrent begin must throw")
        } catch let CaptureController.CaptureError.alreadyRecording(who) {
            XCTAssertEqual(who, id1)
        }
    }

    func testEndWithoutBeginThrows() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let controller = CaptureController(audioDirectory: dir, input: FakeAudioInput())
        do {
            _ = try await controller.end()
            XCTFail("end without an active recording must throw")
        } catch CaptureController.CaptureError.notRecording {
            // expected
        }
    }

    /// Push audio, then DON'T end (simulate the app being killed mid-record). The partial
    /// file must already hold the streamed audio, and recovery must make it a valid WAV.
    func testKillMidRecordingLeavesRepairablePartial() async throws {
        let dir = tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fake = FakeAudioInput()
        let controller = CaptureController(audioDirectory: dir, input: fake)

        let id = UUID()
        let url = try await controller.begin(encounterID: id)
        fake.push(Data(repeating: 0x7F, count: 1600))
        fake.push(Data(repeating: 0x7F, count: 1600))
        // ...app dies here — no end(), header never finalized.

        // The audio survived on disk even though the header isn't finalized.
        let onDisk = try Data(contentsOf: url)
        XCTAssertEqual(onDisk.count, 44 + 3200, "streamed PCM is on disk before any finalize")

        let recovered = await controller.recoverPartialRecording(relPath: "\(id.uuidString).wav")
        XCTAssertNotNil(recovered, "partial recording is recoverable")
        XCTAssertEqual(recovered!, 3200.0 / Double(AudioFormat.whisper.byteRate), accuracy: 1e-9)
        XCTAssertEqual(try dataSize(ofWAV: url), 3200, "recovery rebuilt the data-chunk size")
    }
}
