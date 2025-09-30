import Foundation

class PatternTransformationEngine {

    // Master pattern dictionary from all 18 examples
    private let masterPatterns: [String: String] = [
        // CRITICAL MEDICAL UPGRADES
        "blue": "cyanotic",
        "can't breathe": "dyspnea",
        "passed out": "lost consciousness",
        "heart racing": "tachycardia",
        "pressure up": "hypertension",
        "sugar high": "hyperglycemia",
        "can't pee": "urinary retention",
        "throwing up": "vomiting",
        "yellow stuff": "purulent",
        "swollen": "edema",

        // TIME CLARIFICATIONS
        "the other day": "recently",
        "a while ago": "previously",
        "couple days": "2-3 days",
        "last week": "one week ago",

        // REMOVE COMPLETELY
        "fucking": "",
        "shit": "",
        "damn": "",
        "um": "",
        "uh": "",
        "you know": "",

        // PAIN DESCRIPTIONS
        "hurts bad": "severe pain",
        "killing me": "severe pain",
        "10 out of 10": "10/10",
        "like childbirth": "10/10",

        // PROCEDURAL
        "put tube in": "placed catheter",
        "drain it": "perform drainage",
        "stuck me": "IV placed"
    ]

    func transformTranscript(_ input: String) -> String {
        var result = input

        // Apply all transformations
        for (pattern, replacement) in masterPatterns {
            result = result.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: [.caseInsensitive]
            )
        }

        // Clean up extra spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)

        return result
    }
}