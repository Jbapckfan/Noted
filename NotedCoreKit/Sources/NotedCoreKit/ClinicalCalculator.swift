import Foundation

/// A validated clinical decision instrument (HEART, Wells, PERC, NEXUS, CURB-65, …) as a PURE,
/// deterministic unit. The model never "estimates" a score — that would be a fabrication; a
/// calculator computes it from inputs the clinician confirmed, and shows its work. Adding a new
/// instrument is one file conforming to this protocol plus its reference-case tests — nothing else
/// in the app changes (see `CalculatorRegistry`).
///
/// Clinical criteria follow the standard published definitions (cross-check against MDCalc). The
/// content is decision SUPPORT: it suggests and computes; it never sets disposition on its own.
public protocol ClinicalCalculator: Sendable {
    /// Stable identifier, e.g. "heart".
    var id: String { get }
    /// Display name, e.g. "HEART Score (chest pain)".
    var name: String { get }
    /// Source/citation + version so the content is auditable and updatable.
    var citation: String { get }
    /// The inputs the clinician answers (some may be pre-filled from grounded facts).
    var inputs: [CalculatorInput] { get }

    /// A short reason the instrument is relevant to THIS encounter, or nil if it isn't. Encodes the
    /// instrument's inclusion criteria conservatively — it suggests, it does not auto-run.
    func relevance(_ facts: ClinicalFacts) -> String?

    /// Best-effort pre-fill of inputs from facts already grounded in the transcript (age, HR,
    /// documented risk factors). Subjective/unknown inputs are left for the clinician. Never guesses.
    func prefill(_ facts: ClinicalFacts) -> Answers

    /// Deterministically compute the result from a full set of answers.
    func compute(_ answers: Answers) -> CalculatorResult
}

// MARK: - Inputs & answers

public struct CalculatorInput: Sendable, Equatable {
    public enum Field: Sendable, Equatable {
        case options([Option])        // single-select; the answer is the chosen index
        case number(unit: String?)    // a raw numeric value the calculator bins itself
    }
    public let id: String
    public let label: String
    public let field: Field
    public let help: String?

    public init(id: String, label: String, field: Field, help: String? = nil) {
        self.id = id; self.label = label; self.field = field; self.help = help
    }
}

public struct Option: Sendable, Equatable {
    public let label: String
    public let points: Double
    public init(_ label: String, _ points: Double) { self.label = label; self.points = points }
}

public enum Answer: Sendable, Equatable {
    case option(Int)     // chosen index into a `.options` input
    case number(Double)  // a `.number` input
}

public typealias Answers = [String: Answer]

// MARK: - Result

public enum RiskLevel: String, Sendable, Equatable, Codable {
    case low, moderate, high, indeterminate
}

public struct CalculatorResult: Sendable, Equatable {
    public let score: Double?          // nil for pure rule-out logic (PERC/NEXUS)
    public let level: RiskLevel
    public let interpretation: String  // e.g. "HEART 4 — moderate risk (12–16.6% 6-week MACE)"
    public let recommendation: String  // decision SUPPORT, phrased as "consider …", never a directive
    public let breakdown: [String]     // one audit line per component
    /// A single line the clinician can insert into the MDM — attributable and grounded.
    public var noteLine: String { interpretation }

    public init(score: Double?, level: RiskLevel, interpretation: String,
                recommendation: String, breakdown: [String]) {
        self.score = score; self.level = level; self.interpretation = interpretation
        self.recommendation = recommendation; self.breakdown = breakdown
    }
}

// MARK: - Registry + suggestions

public struct CalculatorSuggestion: Sendable, Equatable {
    public let id: String
    public let name: String
    public let reason: String
    public init(id: String, name: String, reason: String) { self.id = id; self.name = name; self.reason = reason }
}

/// The single place every instrument is registered. The suggestion engine runs each calculator's
/// `relevance` over the extracted facts and returns the ones worth offering the clinician.
public enum CalculatorRegistry {

    public static let all: [ClinicalCalculator] = [
        HEARTScore(),
    ]

    public static func calculator(id: String) -> ClinicalCalculator? {
        all.first { $0.id == id }
    }

    public static func suggestions(for facts: ClinicalFacts) -> [CalculatorSuggestion] {
        all.compactMap { c in
            c.relevance(facts).map { CalculatorSuggestion(id: c.id, name: c.name, reason: $0) }
        }
    }
}

// MARK: - Fact helpers (shared by calculators)

extension ClinicalFacts {

    /// Case-insensitive keyword hit across the narrative fields, CC, differential, and PMH.
    public func mentions(anyOf keywords: [String]) -> Bool {
        let hay = ([chiefComplaint, hpi, reviewOfSystems, physicalExam, mdm, diagnosis]
                    .compactMap { $0 } + differential + pastMedicalHistory)
            .joined(separator: " ").lowercased()
        return keywords.contains { hay.contains($0.lowercased()) }
    }

    /// The first numeric value of a vital whose name contains `name` (e.g. "HR" → 112).
    public func vitalValue(_ name: String) -> Double? {
        for v in vitals where v.name.lowercased().contains(name.lowercased()) {
            if let d = Self.firstNumber(in: v.value) { return d }
        }
        return nil
    }

    /// The first numeric value of a lab whose test name contains `test`.
    public func labValue(_ test: String) -> Double? {
        for l in labs where l.test.lowercased().contains(test.lowercased()) {
            if let d = Self.firstNumber(in: l.value) { return d }
        }
        return nil
    }

    /// Patient age in years, parsed from the HPI/CC ("62-year-old", "62 yo", "62 y/o", "62yo").
    public var ageYears: Int? {
        let text = [chiefComplaint, hpi].compactMap { $0 }.joined(separator: " ").lowercased()
        guard let re = try? NSRegularExpression(pattern: "(\\d{1,3})\\s*[- ]?\\s*(?:year|yo\\b|y/o|y\\.o|yr)") else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges > 1 else { return nil }
        return Int(ns.substring(with: m.range(at: 1)))
    }

    static func firstNumber(in s: String) -> Double? {
        guard let re = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?") else { return nil }
        let ns = s as NSString
        guard let m = re.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Double(ns.substring(with: m.range))
    }
}

// MARK: - Shared compute helpers

public enum CalculatorMath {
    /// Sum the points of the chosen options for a set of `.options` inputs. Missing answers count 0.
    public static func sumPoints(_ answers: Answers, inputs: [CalculatorInput]) -> Double {
        var total = 0.0
        for input in inputs {
            guard case let .options(options) = input.field,
                  case let .option(idx)? = answers[input.id],
                  options.indices.contains(idx) else { continue }
            total += options[idx].points
        }
        return total
    }
}
