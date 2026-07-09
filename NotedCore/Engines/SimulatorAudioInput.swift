//  SimulatorAudioInput.swift
//  A mic stand-in for the iOS Simulator (which has no reliable microphone). Emits silent 16 kHz
//  PCM frames on a timer so CaptureController writes a real WAV and the full pipeline runs —
//  the mock engine produces the note regardless of audio content. On device, AVAudioEngineInput
//  is used instead.

#if targetEnvironment(simulator)
import Foundation
import NotedCoreKit

final class SimulatorAudioInput: AudioInput, @unchecked Sendable {
    let format = AudioFormat.whisper
    private var timer: DispatchSourceTimer?

    func start(onBuffer: @escaping @Sendable (Data) -> Void) throws {
        let t = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        t.schedule(deadline: .now() + 0.1, repeating: 0.1)
        // 100 ms of 16 kHz mono 16-bit silence = 16000 * 0.1 * 2 = 3200 bytes.
        t.setEventHandler { onBuffer(Data(count: 3200)) }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
#endif
