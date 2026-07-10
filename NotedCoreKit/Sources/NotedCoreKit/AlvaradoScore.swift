import Foundation

/// Alvarado Score (MANTRELS) for the likelihood of acute appendicitis in patients with abdominal /
/// right-lower-quadrant pain. Eight weighted findings — three symptoms, three signs, two lab
/// values — summed 0–10. Follows the reference `HEARTScore` shape as an additive instrument.
///
/// Criteria per Alvarado A, Ann Emerg Med 1986 (cross-check MDCalc). Decision support only — it
/// estimates the probability of appendicitis and suggests a pathway; the clinician sets disposition.
public struct AlvaradoScore: ClinicalCalculator {

    public init() {}

    public let id = "alvarado"
    public let name = "Alvarado Score (appendicitis)"
    public let citation = "Alvarado A. A practical score for the early diagnosis of acute appendicitis. Ann Emerg Med 1986;15(5):557–564. (cross-check MDCalc)"

    // Each finding is present/absent; the "Yes" option carries the finding's weight (MANTRELS: the
    // two heavily-weighted items are RLQ Tenderness = 2 and Leukocytosis = 2, everything else = 1).
    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "migration", label: "Migration of pain to RLQ", field: .options([
            Option("No", 0), Option("Yes", 1),
        ]), help: "Pain that began elsewhere (often periumbilical) and migrated to the right lower quadrant."),
        CalculatorInput(id: "anorexia", label: "Anorexia", field: .options([
            Option("No", 0), Option("Yes", 1),
        ]), help: "Loss of appetite (some versions also credit acetone in the urine)."),
        CalculatorInput(id: "nausea", label: "Nausea or vomiting", field: .options([
            Option("No", 0), Option("Yes", 1),
        ])),
        CalculatorInput(id: "tenderness", label: "Tenderness in RLQ", field: .options([
            Option("No", 0), Option("Yes", 2),
        ]), help: "Direct tenderness in the right lower quadrant on palpation."),
        CalculatorInput(id: "rebound", label: "Rebound tenderness", field: .options([
            Option("No", 0), Option("Yes", 1),
        ]), help: "Pain on release of palpation (rebound / percussion tenderness)."),
        CalculatorInput(id: "temperature", label: "Elevated temperature (≥ 37.3 °C / 99.1 °F)", field: .options([
            Option("No", 0), Option("Yes", 1),
        ])),
        CalculatorInput(id: "leukocytosis", label: "Leukocytosis (WBC > 10,000/µL)", field: .options([
            Option("No", 0), Option("Yes", 2),
        ])),
        CalculatorInput(id: "left_shift", label: "Left shift (neutrophils > 75%)", field: .options([
            Option("No", 0), Option("Yes", 1),
        ]), help: "Shift of the leukocyte count to the left, i.e. neutrophils > 75%."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "abdominal pain", "abd pain", "rlq", "right lower quadrant",
            "appendicitis", "appendiceal", "belly pain", "stomach pain",
        ]) else { return nil }
        let age = facts.ageYears.map { " (age \($0))" } ?? ""
        return "Abdominal / RLQ pain\(age) — Alvarado (MANTRELS) estimates the likelihood of acute appendicitis."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // Only objectively grounded vitals/labs are pre-filled. The six symptom/exam findings
        // (migration, anorexia, nausea, tenderness, rebound) are subjective and left for the clinician.
        if let tempC = groundedTemperatureCelsius(facts) {
            out["temperature"] = .option(tempC >= 37.3 ? 1 : 0)
        }
        if let wbc = facts.labValue("WBC") {
            // Accept both ×10³/µL (e.g. 12.5) and absolute counts (e.g. 12500).
            let thousands = wbc > 1000 ? wbc / 1000 : wbc
            out["leukocytosis"] = .option(thousands > 10 ? 1 : 0)
        }
        if let neut = facts.labValue("neutrophil") {
            // Accept both percent (82) and fraction (0.82).
            let pct = neut <= 1 ? neut * 100 : neut
            out["left_shift"] = .option(pct > 75 ? 1 : 0)
        }
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        let score = CalculatorMath.sumPoints(answers, inputs: inputs)
        let level: RiskLevel
        let probability: String
        let recommendation: String
        switch score {
        case ..<4:
            level = .low
            probability = "appendicitis unlikely"
            recommendation = "Low probability — consider discharge with return precautions or short observation per your local pathway; appendicitis is unlikely."
        case 4..<7:
            level = .moderate
            probability = "compatible with appendicitis"
            recommendation = "Moderate probability — consider observation with serial exams and abdominal imaging (CT or ultrasound)."
        default:
            level = .high
            probability = "appendicitis probable"
            recommendation = "High probability — consider surgical consultation and imaging per your local pathway."
        }

        var breakdown: [String] = []
        for input in inputs {
            guard case let .options(options) = input.field,
                  case let .option(idx)? = answers[input.id],
                  options.indices.contains(idx) else {
                breakdown.append("\(input.label): (not entered)")
                continue
            }
            let o = options[idx]
            breakdown.append("\(input.label): \(o.label) (+\(Int(o.points)))")
        }

        let n = Int(score)
        return CalculatorResult(
            score: score,
            level: level,
            interpretation: "Alvarado score \(n)/10 — \(level.rawValue) probability (\(probability)).",
            recommendation: recommendation,
            breakdown: breakdown
        )
    }

    /// Grounded temperature in °C, converting Fahrenheit readings (numerically far above any human
    /// Celsius temperature) so the ≥ 37.3 °C threshold is applied consistently. nil if not documented.
    private func groundedTemperatureCelsius(_ facts: ClinicalFacts) -> Double? {
        guard let t = facts.vitalValue("Temp") else { return nil }
        return t >= 50 ? (t - 32) * 5 / 9 : t
    }
}
