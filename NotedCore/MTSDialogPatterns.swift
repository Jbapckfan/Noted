// Learned Patterns from MTS-Dialog Dataset
// Generated: 2025-09-01 14:00:33 +0000

import Foundation

/// Pattern-based improvements for RealConversationAnalyzer
extension RealConversationAnalyzer {
    
    static let mtsDialogPatterns: [String: String] = [
        // disposition patterns

        // chiefComplaint patterns
        " right arm.": "Burn",

        // demographics patterns
        "age mention": "The patient is a 76-year-old",
        "age mention": "The patient is a 25-year-old",
        "age mention": "The patient is a 22-year-old",

        // allergies patterns

        // symptoms patterns

        // examination patterns

        // onset patterns
        "suddenly": "sudden onset",

        // assessment patterns

        // medications patterns
        " prn; and Fluticasone nasal inhaler. The patient was taking no over the counter or alternative medic": "Prescribed medications were Salmeterol inhaler",
    ]
    
    /// Apply MTS-Dialog patterns to improve extraction
    static func applyMTSDialogPatterns(to text: String) -> [String: String] {
        var improvements: [String: String] = [:]
        
        for (pattern, output) in mtsDialogPatterns {
            if text.lowercased().contains(pattern.lowercased()) {
                improvements[pattern] = output
            }
        }
        
        return improvements
    }
}