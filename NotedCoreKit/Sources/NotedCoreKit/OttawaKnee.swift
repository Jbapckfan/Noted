import Foundation

/// Ottawa Knee Rule — a rule-OUT decision instrument for acute knee injury. A knee radiograph
/// series is indicated if ANY one of five criteria is present; if none are present the rule
/// clears the patient and imaging is not required. There is no numeric score — the output is a
/// boolean decision (`score = nil`).
///
/// Criteria per Stiell et al. (cross-check MDCalc). Decision support only — it identifies which
/// acute knee injuries warrant x-ray and shows its work; the clinician sets disposition.
public struct OttawaKnee: ClinicalCalculator {

    public init() {}

    public let id = "ottawa_knee"
    public let name = "Ottawa Knee Rule (knee injury)"
    public let citation = "Stiell IG, Greenberg GH, Wells GA, et al. Ann Emerg Med 1995; JAMA 1996. Ottawa Knee Rule. (cross-check MDCalc)"

    /// Each criterion is a Yes/No item. Points are cosmetic here (No = 0, Yes = 1); the decision is
    /// driven by the custom boolean logic in `compute`, not by summing points.
    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "age", label: "Age ≥ 55 years", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Patient is 55 years of age or older."),
        CalculatorInput(id: "patella", label: "Isolated tenderness of the patella", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Tenderness of the patella with no other bony knee tenderness."),
        CalculatorInput(id: "fibula", label: "Tenderness at the head of the fibula", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ])),
        CalculatorInput(id: "flex90", label: "Inability to flex to 90°", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Unable to actively flex the knee to 90 degrees."),
        CalculatorInput(id: "weightbear", label: "Inability to bear weight (4 steps) both immediately and in the ED", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Unable to take 4 steps (transfer weight twice onto each leg, regardless of limping) both immediately after the injury and in the ED."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "knee pain", "knee injury", "knee trauma", "knee swelling",
            "twisted knee", "hurt knee", "injured knee", "knee"
        ]) else { return nil }
        return "Knee injury/pain — the Ottawa Knee Rule identifies which acute knee injuries need radiographs (applies to acute knee trauma; not validated for isolated soft-tissue or chronic knee pain)."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // Age is the only grounded criterion; the four exam findings are clinician-assessed and are
        // never guessed.
        if let age = facts.ageYears {
            out["age"] = .option(age >= 55 ? 1 : 0)
        }
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        // Read each criterion as an optional Bool (nil = not entered).
        func value(_ id: String) -> Bool? {
            guard case let .option(idx)? = answers[id] else { return nil }
            return idx == 1
        }

        var breakdown: [String] = []
        var positives: [String] = []
        var answeredCount = 0
        for input in inputs {
            switch value(input.id) {
            case .some(true):
                answeredCount += 1
                positives.append(input.label)
                breakdown.append("\(input.label): Yes → x-ray indicated")
            case .some(false):
                answeredCount += 1
                breakdown.append("\(input.label): No")
            case .none:
                breakdown.append("\(input.label): (not entered)")
            }
        }

        let anyPositive = !positives.isEmpty
        let allAnswered = answeredCount == inputs.count

        let level: RiskLevel
        let interpretation: String
        let recommendation: String
        if anyPositive {
            // Any positive criterion → radiograph indicated, regardless of the other answers.
            level = .high
            interpretation = "Ottawa Knee Rule positive (\(positives.joined(separator: "; "))) — knee x-ray indicated."
            recommendation = "Consider a knee radiograph series per the Ottawa Knee Rule."
        } else if allAnswered {
            // All five criteria assessed and none present → rule clears.
            level = .low
            interpretation = "Ottawa Knee Rule negative — no criteria met; knee x-ray not required by the rule."
            recommendation = "Consider clinical management without knee radiographs, with return precautions and reassessment as clinically indicated."
        } else {
            // No positive yet, but not every criterion has been assessed — cannot clear.
            level = .indeterminate
            interpretation = "Ottawa Knee Rule incomplete — remaining criteria not assessed; cannot clear for no imaging."
            recommendation = "Consider completing all five Ottawa Knee criteria before deciding on imaging."
        }

        return CalculatorResult(
            score: nil,
            level: level,
            interpretation: interpretation,
            recommendation: recommendation,
            breakdown: breakdown
        )
    }
}
