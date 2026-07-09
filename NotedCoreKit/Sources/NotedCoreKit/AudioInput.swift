import Foundation

/// The seam between `CaptureController` and the actual microphone.
///
/// The app provides an `AVAudioEngine`-backed conformance on device; tests provide a fake that
/// pushes synthetic PCM. This is what lets the capture *logic* (file lifecycle, handoff, crash
/// recovery) be verified on macOS without a mic or an iOS simulator.
///
/// `onBuffer` may be invoked on a real-time audio thread, so it must be cheap and thread-safe
/// (it writes straight to a lock-guarded `WAVWriter`, never hopping onto an actor per buffer).
public protocol AudioInput: AnyObject {
    var format: AudioFormat { get }
    func start(onBuffer: @escaping @Sendable (Data) -> Void) throws
    func stop()
}
