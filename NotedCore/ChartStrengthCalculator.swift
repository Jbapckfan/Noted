import Foundation

class ChartStrengthCalculator {

    enum EMLevel: Int {
        case level1 = 1
        case level2 = 2
        case level3 = 3
        case level4 = 4
        case level5 = 5

        var rvu: Double {
            switch self {
            case .level1: return 0.48
            case .level2: return 0.93
            case .level3: return 1.42
            case .level4: return 2.60
            case .level5: return 4.00
            }
        }
    }

    struct ChartStrength {
        let currentLevel: EMLevel
        let achievableLevel: EMLevel
        let completeness: Double
        let missingElements: [String]
        let suggestions: [String]
        let potentialRevenue: Double
    }

    func calculateStrength(for note: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> ChartStrength {
        var score = 0
        var maxScore = 0
        var missing: [String] = []

        // Check HPI elements
        let hpiElements = [
            "location", "quality", "severity", "duration",
            "timing", "context", "modifying", "associated"
        ]

        for element in hpiElements {
            maxScore += 1
            if noteContainsElement(note, element: element) {
                score += 1
            } else {
                missing.append("HPI: \(element)")
            }
        }

        // Check ROS
        let rosSystems = [
            "constitutional", "eyes", "ears", "nose", "throat",
            "cardiovascular", "respiratory", "gi", "gu",
            "musculoskeletal", "skin", "neurologic", "psychiatric"
        ]

        let rosCount = rosSystems.filter { note.lowercased().contains($0) }.count
        score += min(rosCount, 10)
        maxScore += 10

        if rosCount < 10 {
            missing.append("ROS: \(10 - rosCount) more systems needed")
        }

        // Check exam
        let examSystems = [
            "general", "heent", "neck", "respiratory", "cardiovascular",
            "abdomen", "musculoskeletal", "skin", "neurologic", "psychiatric"
        ]

        let examCount = examSystems.filter { note.lowercased().contains($0) }.count
        score += min(examCount, 8)
        maxScore += 8

        // Check MDM
        if note.contains("MDM:") || note.contains("differential") {
            score += 3
        } else {
            missing.append("MDM: Clinical reasoning needed")
        }
        maxScore += 3

        // Calculate level
        let completeness = Double(score) / Double(maxScore)
        let currentLevel = determineLevel(completeness: completeness)
        let achievableLevel = determineAchievableLevel(for: type)

        // Generate suggestions
        let suggestions = generateSuggestions(missing: missing, currentLevel: currentLevel)

        // Calculate revenue
        let currentRevenue = currentLevel.rvu * 35.0 // Assuming $35/RVU
        let potentialRevenue = achievableLevel.rvu * 35.0

        return ChartStrength(
            currentLevel: currentLevel,
            achievableLevel: achievableLevel,
            completeness: completeness,
            missingElements: missing,
            suggestions: suggestions,
            potentialRevenue: potentialRevenue - currentRevenue
        )
    }

    private func noteContainsElement(_ note: String, element: String) -> Bool {
        // Implement smart detection for each element type
        switch element {
        case "severity":
            return note.contains("/10") || note.contains("mild") ||
                   note.contains("moderate") || note.contains("severe")
        case "duration":
            return note.contains("hours") || note.contains("days") ||
                   note.contains("weeks") || note.contains("started")
        default:
            return note.lowercased().contains(element)
        }
    }

    private func determineLevel(completeness: Double) -> EMLevel {
        switch completeness {
        case 0..<0.3: return .level2
        case 0.3..<0.5: return .level3
        case 0.5..<0.7: return .level4
        case 0.7...1.0: return .level5
        default: return .level3
        }
    }

    private func determineAchievableLevel(for type: ChiefComplaintClassifier.ChiefComplaintType) -> EMLevel {
        switch type {
        case .neurological, .cardiovascular, .metabolic:
            return .level5
        case .respiratory, .gastrointestinal, .oncological:
            return .level4
        default:
            return .level4
        }
    }

    private func generateSuggestions(missing: [String], currentLevel: EMLevel) -> [String] {
        var suggestions: [String] = []

        if currentLevel.rawValue < 5 {
            suggestions.append("Add \(missing.prefix(3).joined(separator: ", ")) to reach Level \(currentLevel.rawValue + 1)")
        }

        if !missing.isEmpty {
            suggestions.append("Quick adds available: \(missing.count) elements")
        }

        return suggestions
    }
}