import Foundation

@MainActor
final class EncounterController: ObservableObject {
    static let shared = EncounterController()
    
    private let audioService = AudioCaptureService()
    
    func start(room: String? = nil, complaint: String? = nil) async {
        if let room = room { CoreAppState.shared.currentRoom = room }
        if let complaint = complaint { CoreAppState.shared.currentChiefComplaint = complaint }
        // TranscriptionEnsembler.shared.reset() // TODO: Re-enable when available
        do {
            try await audioService.start()
            try? await SpeechRecognitionService.shared.startTranscription()
            CoreAppState.shared.isRecording = true
        } catch {
            print("Encounter start error: \(error)")
        }
    }
    
    func stop() {
        audioService.stop()
        Task {
            await SpeechRecognitionService.shared.stopTranscription()
        }
        _ = RealtimeMedicalProcessor.shared.finalizeNote()
        CoreAppState.shared.isRecording = false
    }
    
    func bookmark(_ label: String) {
        KeyUtteranceTracker.shared.processSegment("[BOOKMARK] \(label)")
    }
}

