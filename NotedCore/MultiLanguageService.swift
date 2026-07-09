#if canImport(WhisperKit)
import Foundation
import WhisperKit

// MARK: - Multi-Language Service
// Handles language detection and multi-lingual transcription

@MainActor
class MultiLanguageService: ObservableObject {
    // MARK: - Published Properties
    @Published var detectedLanguage: Language = .english
    @Published var isDetecting = false
    @Published var languageConfidence: Float = 0
    @Published var supportedLanguages: [Language] = Language.medicalLanguages
    @Published var preferredLanguages: [Language] = [.english, .spanish]
    
    // MARK: - Language Model
    enum Language: String, CaseIterable {
        // Most common medical encounter languages
        case english = "en"
        case spanish = "es"
        case mandarin = "zh"
        case hindi = "hi"
        case french = "fr"
        case arabic = "ar"
        case portuguese = "pt"
        case russian = "ru"
        case japanese = "ja"
        case german = "de"
        case korean = "ko"
        case vietnamese = "vi"
        case italian = "it"
        case turkish = "tr"
        case polish = "pl"
        
        var displayName: String {
            switch self {
            case .english: return "English"
            case .spanish: return "Español"
            case .mandarin: return "中文"
            case .hindi: return "हिन्दी"
            case .french: return "Français"
            case .arabic: return "العربية"
            case .portuguese: return "Português"
            case .russian: return "Русский"
            case .japanese: return "日本語"
            case .german: return "Deutsch"
            case .korean: return "한국어"
            case .vietnamese: return "Tiếng Việt"
            case .italian: return "Italiano"
            case .turkish: return "Türkçe"
            case .polish: return "Polski"
            }
        }
        
        var flag: String {
            switch self {
            case .english: return "🇺🇸"
            case .spanish: return "🇪🇸"
            case .mandarin: return "🇨🇳"
            case .hindi: return "🇮🇳"
            case .french: return "🇫🇷"
            case .arabic: return "🇸🇦"
            case .portuguese: return "🇵🇹"
            case .russian: return "🇷🇺"
            case .japanese: return "🇯🇵"
            case .german: return "🇩🇪"
            case .korean: return "🇰🇷"
            case .vietnamese: return "🇻🇳"
            case .italian: return "🇮🇹"
            case .turkish: return "🇹🇷"
            case .polish: return "🇵🇱"
            }
        }
        
        // Common medical languages in US healthcare
        static var medicalLanguages: [Language] {
            return [.english, .spanish, .mandarin, .vietnamese, .korean, .arabic, .russian]
        }
        
        // Medical terminology support level
        var medicalTerminologySupport: MedicalSupport {
            switch self {
            case .english: return .excellent
            case .spanish: return .excellent
            case .mandarin: return .good
            case .french: return .good
            case .german: return .good
            case .japanese: return .good
            default: return .basic
            }
        }
        
        enum MedicalSupport {
            case excellent  // Full medical terminology
            case good      // Most medical terms
            case basic     // Common terms only
        }
    }
    
    // MARK: - Configuration
    private var whisperKit: WhisperKit?
    private let detectionDuration: TimeInterval = 5.0  // Seconds of audio for detection
    private var languageScores: [Language: Float] = [:]
    
    // MARK: - Language Detection
    
    func detectLanguage(from audioPath: String) async -> Language {
        isDetecting = true
        defer { isDetecting = false }
        
        // Use WhisperKit's language detection
        guard let whisperKit = whisperKit else {
            print("⚠️ WhisperKit not initialized, defaulting to English")
            return .english
        }
        
        do {
            // Configure detection options
            let options = DecodingOptions(
                task: .transcribe,
                language: nil,  // Auto-detect
                detectLanguage: true
            )
            
            // Run detection on audio sample
            let results = try await whisperKit.transcribe(
                audioPath: audioPath,
                decodeOptions: options
            )
            
            // Parse detected language from first result
            if let firstResult = results.first {
                let detectedLang = firstResult.language
                if let language = Language(rawValue: detectedLang) {
                    self.detectedLanguage = language
                    self.languageConfidence = 0.8  // WhisperKit doesn't expose avgLogprob
                    return language
                }
            }
            
        } catch {
            print("❌ Language detection error: \(error)")
        }
        
        // Fallback to user's preferred language
        return preferredLanguages.first ?? .english
    }
    
    // MARK: - Multi-Language Transcription
    
    func transcribeMultilingual(
        audioPath: String,
        primaryLanguage: Language? = nil,
        allowMixedLanguages: Bool = false
    ) async throws -> MultilingualTranscription {
        
        guard let whisperKit = whisperKit else {
            throw MultiLanguageError.whisperNotInitialized
        }
        
        let language = primaryLanguage ?? detectedLanguage
        
        // Configure for multilingual if needed
        let options = DecodingOptions(
            task: .transcribe,
            language: allowMixedLanguages ? nil : language.rawValue,
            detectLanguage: allowMixedLanguages
        )
        
        let results = try await whisperKit.transcribe(
            audioPath: audioPath,
            decodeOptions: options
        )
        
        // Process segments with language tags
        var segments: [MultilingualSegment] = []
        var fullText = ""
        
        for result in results {
            // Combine text from all results
            fullText += result.text
            
            // Create segments from each result
            let resultSegments = result.segments
            for segment in resultSegments {
                let multiSegment = MultilingualSegment(
                    text: segment.text,
                    language: Language(rawValue: result.language) ?? language,
                    startTime: TimeInterval(segment.start),
                    endTime: TimeInterval(segment.end),
                    confidence: 0.8  // Default confidence
                )
                segments.append(multiSegment)
            }
        }
        
        return MultilingualTranscription(
            fullText: fullText,
            segments: segments,
            primaryLanguage: language,
            detectedLanguages: detectLanguagesInSegments(segments)
        )
    }
    
    // MARK: - Language Switching Detection
    
    private func detectLanguagesInSegments(_ segments: [MultilingualSegment]) -> Set<Language> {
        var languages = Set<Language>()
        for segment in segments {
            languages.insert(segment.language)
        }
        return languages
    }
    
    // MARK: - Medical Translation Support
    
    func translateMedicalTerms(
        text: String,
        from sourceLanguage: Language,
        to targetLanguage: Language
    ) -> String {
        // This would integrate with a medical translation service
        // For now, we'll mark terms that need translation
        
        guard sourceLanguage != targetLanguage else { return text }
        
        // Common medical terms dictionary (simplified example)
        let medicalTerms: [String: [Language: String]] = [
            "pain": [
                .spanish: "dolor",
                .french: "douleur",
                .german: "Schmerz",
                .mandarin: "疼痛"
            ],
            "fever": [
                .spanish: "fiebre",
                .french: "fièvre",
                .german: "Fieber",
                .mandarin: "发烧"
            ],
            "medication": [
                .spanish: "medicación",
                .french: "médicament",
                .german: "Medikament",
                .mandarin: "药物"
            ]
        ]
        
        var translatedText = text
        
        // Simple term replacement (production would use proper NLP)
        for (englishTerm, translations) in medicalTerms {
            if let translation = translations[targetLanguage] {
                translatedText = translatedText.replacingOccurrences(
                    of: englishTerm,
                    with: "\(englishTerm) [\(translation)]",
                    options: [.caseInsensitive]
                )
            }
        }
        
        return translatedText
    }
    
    // MARK: - Language-Specific Medical Formatting
    
    func formatMedicalNote(
        _ note: String,
        for language: Language,
        noteType: NoteType
    ) -> String {
        
        switch language {
        case .spanish:
            return formatSpanishMedicalNote(note, type: noteType)
        case .mandarin:
            return formatChineseMedicalNote(note, type: noteType)
        default:
            return note  // Use default formatting
        }
    }
    
    private func formatSpanishMedicalNote(_ note: String, type: NoteType) -> String {
        // Spanish medical note formatting
        var formatted = note
        
        // Replace section headers
        formatted = formatted
            .replacingOccurrences(of: "SUBJECTIVE:", with: "SUBJETIVO:")
            .replacingOccurrences(of: "OBJECTIVE:", with: "OBJETIVO:")
            .replacingOccurrences(of: "ASSESSMENT:", with: "EVALUACIÓN:")
            .replacingOccurrences(of: "PLAN:", with: "PLAN:")
            .replacingOccurrences(of: "CHIEF COMPLAINT:", with: "MOTIVO DE CONSULTA:")
            .replacingOccurrences(of: "HISTORY OF PRESENT ILLNESS:", with: "HISTORIA DE ENFERMEDAD ACTUAL:")
        
        return formatted
    }
    
    private func formatChineseMedicalNote(_ note: String, type: NoteType) -> String {
        // Chinese medical note formatting
        var formatted = note
        
        // Replace section headers
        formatted = formatted
            .replacingOccurrences(of: "SUBJECTIVE:", with: "主观:")
            .replacingOccurrences(of: "OBJECTIVE:", with: "客观:")
            .replacingOccurrences(of: "ASSESSMENT:", with: "评估:")
            .replacingOccurrences(of: "PLAN:", with: "计划:")
            .replacingOccurrences(of: "CHIEF COMPLAINT:", with: "主诉:")
            .replacingOccurrences(of: "HISTORY OF PRESENT ILLNESS:", with: "现病史:")
        
        return formatted
    }
    
    // MARK: - WhisperKit Integration
    
    func initializeWhisper(_ whisperKit: WhisperKit) {
        self.whisperKit = whisperKit
    }
    
    // MARK: - User Preferences
    
    func setPreferredLanguages(_ languages: [Language]) {
        preferredLanguages = languages
        UserDefaults.standard.set(
            languages.map { $0.rawValue },
            forKey: "preferred_languages"
        )
    }
    
    func loadPreferences() {
        if let saved = UserDefaults.standard.stringArray(forKey: "preferred_languages") {
            preferredLanguages = saved.compactMap { Language(rawValue: $0) }
        }
    }
    
    // MARK: - Statistics
    
    func getLanguageStatistics() -> LanguageStatistics {
        return LanguageStatistics(
            detectedLanguage: detectedLanguage,
            confidence: languageConfidence,
            supportedCount: Language.allCases.count,
            medicalSupportLevel: detectedLanguage.medicalTerminologySupport
        )
    }
    
    struct LanguageStatistics {
        let detectedLanguage: Language
        let confidence: Float
        let supportedCount: Int
        let medicalSupportLevel: Language.MedicalSupport
    }
}

// MARK: - Models

struct MultilingualTranscription {
    let fullText: String
    let segments: [MultilingualSegment]
    let primaryLanguage: MultiLanguageService.Language
    let detectedLanguages: Set<MultiLanguageService.Language>
    
    var isMixedLanguage: Bool {
        detectedLanguages.count > 1
    }
}

struct MultilingualSegment {
    let text: String
    let language: MultiLanguageService.Language
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

// MARK: - Errors

enum MultiLanguageError: LocalizedError {
    case whisperNotInitialized
    case languageNotSupported
    case detectionFailed
    
    var errorDescription: String? {
        switch self {
        case .whisperNotInitialized:
            return "WhisperKit not initialized for language detection"
        case .languageNotSupported:
            return "Language not supported for medical transcription"
        case .detectionFailed:
            return "Failed to detect language from audio"
        }
    }
}#endif
