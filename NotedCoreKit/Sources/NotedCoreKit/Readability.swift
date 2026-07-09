import Foundation

/// Reading-level scoring for the patient-facing discharge rendering. LLMs land patient text at
/// grade 7–9 unprompted; the patient version targets grade 6 with a hard ceiling of 8, so a
/// rendering is gated on this score and regenerated-under-a-simplify-constraint if it fails.
public enum Readability {

    /// Flesch–Kincaid grade level. Lower = easier. ~6 is the target for patient instructions.
    public static func fleschKincaidGrade(_ text: String) -> Double {
        let sentences = max(1, countSentences(text))
        let words = words(in: text)
        let wordCount = max(1, words.count)
        let syllables = max(wordCount, words.reduce(0) { $0 + syllables(in: $1) })

        let wordsPerSentence = Double(wordCount) / Double(sentences)
        let syllablesPerWord = Double(syllables) / Double(wordCount)
        return 0.39 * wordsPerSentence + 11.8 * syllablesPerWord - 15.59
    }

    /// Does the text read at or below `ceiling` grade?
    public static func meetsGrade(_ text: String, ceiling: Double = 8.0) -> Bool {
        fleschKincaidGrade(text) <= ceiling
    }

    // MARK: - Counting

    static func countSentences(_ text: String) -> Int {
        let enders = CharacterSet(charactersIn: ".!?")
        let count = text.unicodeScalars.reduce(into: 0) { acc, scalar in
            if enders.contains(scalar) { acc += 1 }
        }
        return max(count, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    static func words(in text: String) -> [String] {
        text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.contains(where: { $0.isLetter }) }
    }

    /// Vowel-group syllable heuristic with a silent-trailing-"e" adjustment. Not perfect, but
    /// stable and monotonic — good enough to gate a rendering.
    static func syllables(in word: String) -> Int {
        let w = word.lowercased()
        guard !w.isEmpty else { return 0 }
        let vowels = Set("aeiouy")
        var count = 0
        var prevWasVowel = false
        for ch in w {
            let isVowel = vowels.contains(ch)
            if isVowel && !prevWasVowel { count += 1 }
            prevWasVowel = isVowel
        }
        if w.hasSuffix("e") && count > 1 { count -= 1 } // silent e
        return max(1, count)
    }
}
