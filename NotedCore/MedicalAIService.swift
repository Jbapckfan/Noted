import Foundation

/// On-device medical note service — FULLY OFFLINE.
///
/// Note generation runs entirely on-device (MLX / Apple NLP via `MaximumQualityOfflineAI`).
/// No network, no API keys, no cloud fallback. The Anthropic/Claude "online" and "auto"
/// modes — including the `checkOnlineAvailability()` connectivity ping that fired on first
/// `.shared` access — were removed in the offline rearchitecture (PR0). This type is kept
/// (it's the entry point used by `EncounterSessionManager` and extended by
/// `TrainedModelSummarizer`); only its egress was excised.
@MainActor
class MedicalAIService: ObservableObject {
    static let shared = MedicalAIService()

    @Published var isOfflineModelLoaded: Bool = false

    private init() {}

    // MARK: - Main Entry Point

    /// Generate a note from an analyzed conversation. Always on-device.
    func generateMedicalNote(from conversation: ConversationAnalysis, noteType: NoteType) async -> String {
        return await generateWithMLX(conversation: conversation, noteType: noteType)
    }

    // MARK: - On-Device Generation

    private func generateWithMLX(conversation: ConversationAnalysis, noteType: NoteType) async -> String {
        // Maximum-quality offline generation leveraging the Apple Neural Engine,
        // NaturalLanguage embeddings, and on-device medical entity extraction.
        return await MaximumQualityOfflineAI.shared.generateProfessionalNote(
            from: conversation,
            noteType: noteType
        )
    }
}
