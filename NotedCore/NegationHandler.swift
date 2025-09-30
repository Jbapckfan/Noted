import Foundation

/// Detects negated symptoms and findings in medical transcripts
/// Prevents false positives like extracting "chest pain" when patient "denies chest pain"
class NegationHandler {

    // MARK: - Negation Terms
    private static let negationTerms = [
        "no", "not", "denies", "denying", "denied",
        "without", "negative for", "absent", "never",
        "none", "doesn't", "don't", "didn't", "hasn't",
        "haven't", "isn't", "aren't", "wasn't", "weren't",
        "can't", "cannot", "won't", "wouldn't", "couldn't"
    ]

    // Window size: how many words before the keyword to check for negation
    private static let negationWindow = 5

    // MARK: - Main Negation Detection

    /// Check if a keyword appears in negated context in the text
    /// - Parameters:
    ///   - keyword: The medical term to check (e.g., "chest pain")
    ///   - text: The full transcript text
    /// - Returns: True if the keyword is negated, false otherwise
    static func isNegated(_ keyword: String, in text: String) -> Bool {
        let lowercaseText = text.lowercased()
        let lowercaseKeyword = keyword.lowercased()

        // Find all occurrences of the keyword
        var searchRange = lowercaseText.startIndex..<lowercaseText.endIndex
        var keywordRanges: [Range<String.Index>] = []

        while let range = lowercaseText.range(of: lowercaseKeyword, range: searchRange) {
            keywordRanges.append(range)
            searchRange = range.upperBound..<lowercaseText.endIndex
        }

        // Check each occurrence for negation
        for keywordRange in keywordRanges {
            // Get preceding text (up to negationWindow words)
            let precedingText = getPrecedingText(before: keywordRange, in: lowercaseText, wordCount: negationWindow)

            // Check if any negation term appears in preceding text
            for negationTerm in negationTerms {
                if precedingText.contains(negationTerm) {
                    return true // Found negation
                }
            }
        }

        return false // No negation found
    }

    /// Extract keyword with negation status
    /// - Parameters:
    ///   - keyword: The medical term to check
    ///   - text: The full transcript text
    /// - Returns: Tuple with (found: whether keyword exists, negated: whether it's negated)
    static func extractWithNegation(_ keyword: String, in text: String) -> (found: Bool, negated: Bool) {
        let lowercaseText = text.lowercased()
        let lowercaseKeyword = keyword.lowercased()

        let found = lowercaseText.contains(lowercaseKeyword)
        let negated = found ? isNegated(keyword, in: text) : false

        return (found: found, negated: negated)
    }

    /// Check if keyword is present AND not negated (safe extraction)
    /// - Parameters:
    ///   - keyword: The medical term to check
    ///   - text: The full transcript text
    /// - Returns: True if keyword is present and NOT negated
    static func safelyContains(_ keyword: String, in text: String) -> Bool {
        let result = extractWithNegation(keyword, in: text)
        return result.found && !result.negated
    }

    // MARK: - Helper Functions

    /// Get preceding text before a keyword up to N words
    private static func getPrecedingText(before range: Range<String.Index>, in text: String, wordCount: Int) -> String {
        let startIndex = text.startIndex
        let precedingText = String(text[startIndex..<range.lowerBound])

        // Get last N words from preceding text
        let words = precedingText.split(separator: " ")
        let lastWords = words.suffix(wordCount)
        return lastWords.joined(separator: " ").lowercased()
    }

    // MARK: - Batch Processing

    /// Check multiple keywords at once and return only non-negated ones
    /// - Parameters:
    ///   - keywords: Array of keywords to check
    ///   - text: The full transcript text
    /// - Returns: Array of keywords that are present and NOT negated
    static func filterNonNegated(keywords: [String], in text: String) -> [String] {
        return keywords.filter { keyword in
            safelyContains(keyword, in: text)
        }
    }

    /// Get negation status for multiple keywords
    /// - Parameters:
    ///   - keywords: Array of keywords to check
    ///   - text: The full transcript text
    /// - Returns: Dictionary mapping keyword to its negation status
    static func getNegationStatus(for keywords: [String], in text: String) -> [String: (found: Bool, negated: Bool)] {
        var results: [String: (found: Bool, negated: Bool)] = [:]

        for keyword in keywords {
            results[keyword] = extractWithNegation(keyword, in: text)
        }

        return results
    }

    // MARK: - Context-Aware Extraction

    /// Extract a medical finding with context about whether it's affirmed or denied
    /// - Parameters:
    ///   - finding: The medical finding to extract (e.g., "chest pain")
    ///   - text: The full transcript text
    /// - Returns: Optional string with context ("Present", "Denied", or nil if not mentioned)
    static func extractWithContext(_ finding: String, in text: String) -> String? {
        let result = extractWithNegation(finding, in: text)

        if !result.found {
            return nil // Not mentioned at all
        }

        return result.negated ? "Denied" : "Present"
    }

    // MARK: - Clinical Application Helpers

    /// Generate ROS-style documentation with proper negation
    /// - Parameters:
    ///   - findings: Array of findings to check (e.g., ["fever", "chills", "cough"])
    ///   - text: The full transcript text
    /// - Returns: Formatted ROS string with positives and negatives
    static func generateROSDocumentation(for findings: [String], in text: String) -> String {
        var positives: [String] = []
        var negatives: [String] = []

        for finding in findings {
            let result = extractWithNegation(finding, in: text)
            if result.found {
                if result.negated {
                    negatives.append(finding)
                } else {
                    positives.append(finding)
                }
            }
        }

        var documentation = ""
        if !positives.isEmpty {
            documentation += "Positive for: \(positives.joined(separator: ", ")). "
        }
        if !negatives.isEmpty {
            documentation += "Denies: \(negatives.joined(separator: ", ")). "
        }

        return documentation.trimmingCharacters(in: .whitespaces)
    }
}
