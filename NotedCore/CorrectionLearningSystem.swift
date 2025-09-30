import Foundation
import CoreData
import NaturalLanguage
#if os(iOS)
import UIKit
#endif

/// Learning system that improves transcription accuracy based on user corrections
/// Stores patterns and applies them to future transcriptions
@MainActor
class CorrectionLearningSystem: ObservableObject {
    static let shared = CorrectionLearningSystem()
    
    // MARK: - Published Properties
    @Published var totalCorrections = 0
    @Published var accuracyImprovement: Float = 0.0
    @Published var personalizedTerms: [String: String] = [:]
    
    // MARK: - Correction Storage
    private var correctionHistory: [CorrectionEntry] = []
    private var phraseCorrections: [String: String] = [:]
    private var contextualCorrections: [ContextualCorrection] = []
    private var userVocabulary: Set<String> = []
    
    // MARK: - ML Components
    #if os(iOS)
    private let textChecker = UITextChecker()
    #else
    private let textChecker: Any? = nil
    #endif
    // NLLanguageModel not available on all platforms
    private var personalLanguageModel: Any? // NLLanguageModel when available
    
    // MARK: - Persistence
    private let userDefaults = UserDefaults.standard
    private let correctionsKey = "medical_transcription_corrections"
    private let vocabularyKey = "user_medical_vocabulary"
    
    private init() {
        loadCorrections()
        initializeLanguageModel()
    }
    
    // MARK: - Learning from Corrections
    
    func learnCorrection(original: String, corrected: String, context: String? = nil) {
        // Store the correction
        let entry = CorrectionEntry(
            original: original.lowercased(),
            corrected: corrected,
            context: context,
            timestamp: Date(),
            confidence: calculateCorrectionConfidence(original: original, corrected: corrected)
        )
        
        correctionHistory.append(entry)
        totalCorrections += 1
        
        // Learn patterns
        learnPhrasePattern(original: original, corrected: corrected)
        learnContextualPattern(original: original, corrected: corrected, context: context)
        extractMedicalTerms(from: corrected)
        
        // Update accuracy improvement metric
        updateAccuracyMetrics()
        
        // Persist
        saveCorrections()
    }
    
    // MARK: - Pattern Learning
    
    private func learnPhrasePattern(original: String, corrected: String) {
        let originalWords = original.lowercased().split(separator: " ").map(String.init)
        let correctedWords = corrected.split(separator: " ").map(String.init)
        
        // Learn word-level corrections
        if originalWords.count == correctedWords.count {
            for (orig, corr) in zip(originalWords, correctedWords) {
                if orig != corr.lowercased() {
                    // Track frequency of this correction
                    let key = orig
                    if phraseCorrections[key] == nil {
                        phraseCorrections[key] = corr
                    } else if phraseCorrections[key] == corr {
                        // Reinforce this correction
                        personalizedTerms[orig] = corr
                    }
                }
            }
        }
        
        // Learn multi-word phrases
        if originalWords.count >= 2 {
            for i in 0..<(originalWords.count - 1) {
                let phrase = originalWords[i...i+1].joined(separator: " ")
                let correctedPhrase = correctedWords.count > i+1 ? 
                    correctedWords[i...i+1].joined(separator: " ") : ""
                
                if !correctedPhrase.isEmpty && phrase != correctedPhrase.lowercased() {
                    phraseCorrections[phrase] = correctedPhrase
                }
            }
        }
    }
    
    private func learnContextualPattern(original: String, corrected: String, context: String?) {
        guard let context = context, !context.isEmpty else { return }
        
        // Extract key context words
        let contextWords = extractKeyWords(from: context)
        
        let correction = ContextualCorrection(
            original: original.lowercased(),
            corrected: corrected,
            contextKeywords: contextWords,
            frequency: 1
        )
        
        // Check if similar correction exists
        if let existingIndex = contextualCorrections.firstIndex(where: {
            $0.original == correction.original &&
            $0.corrected == correction.corrected &&
            !$0.contextKeywords.intersection(contextWords).isEmpty
        }) {
            // Increase frequency
            contextualCorrections[existingIndex].frequency += 1
            contextualCorrections[existingIndex].contextKeywords.formUnion(contextWords)
        } else {
            contextualCorrections.append(correction)
        }
    }
    
    // MARK: - Medical Term Extraction
    
    private func extractMedicalTerms(from text: String) {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, 
                            unit: .word, 
                            scheme: .lexicalClass, 
                            options: options) { tag, tokenRange in
            let word = String(text[tokenRange])
            
            // Check if it's a medical term (not in standard dictionary)
            if isMedicalTerm(word) {
                userVocabulary.insert(word.lowercased())
            }
            
            return true
        }
    }
    
    private func isMedicalTerm(_ word: String) -> Bool {
        // Check if it's not a common English word
        #if os(iOS)
        let range = NSRange(location: 0, length: word.count)
        let misspellings = textChecker.rangeOfMisspelledWord(
            in: word,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        
        // If spell checker thinks it's misspelled, might be medical term
        #else
        // On macOS, we can't use UITextChecker, so check medical patterns directly
        #endif
        
        // Additional checks for medical patterns
        let medicalPatterns = [
            "itis$", "osis$", "emia$", "pathy$", "ectomy$",
            "otomy$", "ostomy$", "plasty$", "pexy$", "tripsy$"
        ]
        
        for pattern in medicalPatterns {
            if let _ = word.range(of: pattern, options: .regularExpression) {
                return true
            }
        }
        
        #if os(iOS)
        return misspellings.location != NSNotFound && word.count > 4
        #else
        // On macOS, just check if it matches medical patterns or is long enough
        return word.count > 4
        #endif
    }
    
    // MARK: - Apply Corrections
    
    func applyLearnedCorrections(to text: String, context: String? = nil) -> (corrected: String, changes: [CorrectionChange]) {
        var correctedText = text
        var changes: [CorrectionChange] = []
        
        // Apply phrase corrections
        for (original, correction) in phraseCorrections {
            if let range = correctedText.lowercased().range(of: original) {
                let originalSubstring = String(correctedText[range])
                correctedText.replaceSubrange(range, with: correction)
                
                changes.append(CorrectionChange(
                    original: originalSubstring,
                    corrected: correction,
                    confidence: 0.9,
                    source: .learned
                ))
            }
        }
        
        // Apply contextual corrections
        if let context = context {
            let contextKeywords = extractKeyWords(from: context)
            
            for contextCorrection in contextualCorrections.sorted(by: { $0.frequency > $1.frequency }) {
                // Check if context matches
                if !contextCorrection.contextKeywords.intersection(contextKeywords).isEmpty {
                    if let range = correctedText.lowercased().range(of: contextCorrection.original) {
                        let originalSubstring = String(correctedText[range])
                        correctedText.replaceSubrange(range, with: contextCorrection.corrected)
                        
                        let confidence = min(1.0, 0.7 + Float(contextCorrection.frequency) * 0.05)
                        changes.append(CorrectionChange(
                            original: originalSubstring,
                            corrected: contextCorrection.corrected,
                            confidence: confidence,
                            source: .contextual
                        ))
                    }
                }
            }
        }
        
        // Apply personalized terms
        for (original, correction) in personalizedTerms {
            if let range = correctedText.lowercased().range(of: original) {
                let originalSubstring = String(correctedText[range])
                correctedText.replaceSubrange(range, with: correction)
                
                changes.append(CorrectionChange(
                    original: originalSubstring,
                    corrected: correction,
                    confidence: 0.95,
                    source: .personalized
                ))
            }
        }
        
        return (correctedText, changes)
    }
    
    // MARK: - Helper Functions
    
    private func extractKeyWords(from text: String) -> Set<String> {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var keywords = Set<String>()
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                            unit: .word,
                            scheme: .lexicalClass,
                            options: options) { tag, tokenRange in
            if let tag = tag {
                // Include nouns and verbs as keywords
                if tag == .noun || tag == .verb {
                    let word = String(text[tokenRange]).lowercased()
                    if word.count > 3 { // Skip short words
                        keywords.insert(word)
                    }
                }
            }
            return true
        }
        
        return keywords
    }
    
    private func calculateCorrectionConfidence(original: String, corrected: String) -> Float {
        // Calculate Levenshtein distance
        let distance = levenshteinDistance(original, corrected)
        let maxLength = max(original.count, corrected.count)
        
        // Convert to confidence (closer = higher confidence in correction)
        let similarity = 1.0 - Float(distance) / Float(maxLength)
        
        // Check if correction exists in user vocabulary
        let vocabularyBoost: Float = userVocabulary.contains(corrected.lowercased()) ? 0.1 : 0
        
        return min(1.0, similarity + vocabularyBoost)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { matrix[i][0] = i }
        for j in 0...n { matrix[0][j] = j }
        
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        
        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,
                    matrix[i][j-1] + 1,
                    matrix[i-1][j-1] + cost
                )
            }
        }
        
        return matrix[m][n]
    }
    
    // MARK: - Metrics
    
    private func updateAccuracyMetrics() {
        // Calculate improvement based on correction patterns
        let uniqueCorrections = Set(correctionHistory.map { $0.original })
        let consistentCorrections = phraseCorrections.count + personalizedTerms.count
        
        // Estimate accuracy improvement
        let baseImprovement = Float(consistentCorrections) / Float(max(1, uniqueCorrections.count))
        let frequencyBoost = Float(correctionHistory.count) / 100.0 // More corrections = better learning
        
        accuracyImprovement = min(0.3, baseImprovement * 0.2 + frequencyBoost * 0.1)
    }
    
    // MARK: - Language Model
    
    private func initializeLanguageModel() {
        // Initialize with medical corpus if available
        // This would ideally load a pre-trained medical language model
    }
    
    // MARK: - Persistence
    
    private func saveCorrections() {
        // Save phrase corrections
        userDefaults.set(phraseCorrections, forKey: correctionsKey)
        
        // Save vocabulary
        userDefaults.set(Array(userVocabulary), forKey: vocabularyKey)
        
        // Save personalized terms
        userDefaults.set(personalizedTerms, forKey: "personalized_medical_terms")
    }
    
    private func loadCorrections() {
        // Load phrase corrections
        if let saved = userDefaults.dictionary(forKey: correctionsKey) as? [String: String] {
            phraseCorrections = saved
        }
        
        // Load vocabulary
        if let saved = userDefaults.array(forKey: vocabularyKey) as? [String] {
            userVocabulary = Set(saved)
        }
        
        // Load personalized terms
        if let saved = userDefaults.dictionary(forKey: "personalized_medical_terms") as? [String: String] {
            personalizedTerms = saved
        }
    }
    
    // MARK: - Export/Import
    
    func exportCorrections() -> Data? {
        let export = CorrectionExport(
            phraseCorrections: phraseCorrections,
            personalizedTerms: personalizedTerms,
            vocabulary: Array(userVocabulary),
            totalCorrections: totalCorrections
        )
        
        return try? JSONEncoder().encode(export)
    }
    
    func importCorrections(from data: Data) {
        guard let imported = try? JSONDecoder().decode(CorrectionExport.self, from: data) else { return }
        
        phraseCorrections.merge(imported.phraseCorrections) { _, new in new }
        personalizedTerms.merge(imported.personalizedTerms) { _, new in new }
        userVocabulary.formUnion(imported.vocabulary)
        totalCorrections += imported.totalCorrections
        
        saveCorrections()
        updateAccuracyMetrics()
    }
}

// MARK: - Data Models

struct CorrectionEntry {
    let original: String
    let corrected: String
    let context: String?
    let timestamp: Date
    let confidence: Float
}

struct ContextualCorrection {
    let original: String
    let corrected: String
    var contextKeywords: Set<String>
    var frequency: Int
}

struct CorrectionChange {
    let original: String
    let corrected: String
    let confidence: Float
    let source: CorrectionSource
}

enum CorrectionSource {
    case learned
    case contextual
    case personalized
}

struct CorrectionExport: Codable {
    let phraseCorrections: [String: String]
    let personalizedTerms: [String: String]
    let vocabulary: [String]
    let totalCorrections: Int
}