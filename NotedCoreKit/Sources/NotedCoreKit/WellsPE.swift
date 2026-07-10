import Foundation

/// Wells Criteria for Pulmonary Embolism — pretest-probability score for suspected PE. Seven
/// weighted items summed 0–12.5. Reports BOTH published risk models from the same score:
///   • three-tier: < 2 low, 2–6 moderate, > 6 high;
///   • two-tier:   ≤ 4 "PE unlikely", > 4 "PE likely".
/// The two-tier model is the usual pathway driver (unlikely → D-dimer to exclude; likely → CTPA).
///
/// This is an ADDITIVE calculator following the `ClinicalCalculator` / HEART pattern. Decision
/// support only — it computes pretest probability and suggests a testing pathway; the clinician
/// confirms each item and sets disposition. Criteria per Wells et al. (cross-check MDCalc).
public struct WellsPE: ClinicalCalculator {

    public init() {}

    public let id = "wells_pe"
    public let name = "Wells Criteria for PE"
    public let citation = "Wells PS, Anderson DR, et al. Thromb Haemost 2000; Ann Intern Med 2001. Wells criteria for pulmonary embolism. (cross-check MDCalc)"

    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "dvt_signs", label: "Clinical signs and symptoms of DVT", field: .options([
            Option("No", 0),
            Option("Yes", 3),
        ]), help: "Minimum of leg swelling and pain with palpation of the deep veins."),
        CalculatorInput(id: "pe_most_likely", label: "PE is the #1 diagnosis, or equally likely", field: .options([
            Option("No", 0),
            Option("Yes", 3),
        ]), help: "Clinical gestalt — is PE at least as likely as any alternative diagnosis?"),
        CalculatorInput(id: "hr_over_100", label: "Heart rate > 100", field: .options([
            Option("No", 0),
            Option("Yes", 1.5),
        ])),
        CalculatorInput(id: "immobilization", label: "Immobilization ≥ 3 days or surgery in the previous 4 weeks", field: .options([
            Option("No", 0),
            Option("Yes", 1.5),
        ]), help: "Immobilization for at least 3 consecutive days, or surgery under general/regional anesthesia in the prior 4 weeks."),
        CalculatorInput(id: "prior_pe_dvt", label: "Previous, objectively diagnosed PE or DVT", field: .options([
            Option("No", 0),
            Option("Yes", 1.5),
        ])),
        CalculatorInput(id: "hemoptysis", label: "Hemoptysis", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ])),
        CalculatorInput(id: "malignancy", label: "Malignancy with treatment within 6 months, or palliative", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ])),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "chest pain", "pleuritic", "dyspnea", "shortness of breath", "short of breath",
            "hemoptysis", "pulmonary embolism", "suspected pe", "rule out pe", "r/o pe",
        ]) else { return nil }
        return "Chest pain / dyspnea — Wells estimates pretest probability of PE when PE is being considered."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // HR > 100 is the one objective, reliably grounded item.
        if let hr = facts.vitalValue("HR") {
            out["hr_over_100"] = .option(hr > 100 ? 1 : 0)
        }
        // A documented prior PE/DVT in the PMH satisfies the "previously, objectively diagnosed" item.
        let pmh = facts.pastMedicalHistory.joined(separator: " ").lowercased()
        if ["pulmonary embolism", "deep vein thrombosis", "dvt", " pe ", "(pe)", "prior pe", "history of pe"]
            .contains(where: { pmh.contains($0) }) {
            out["prior_pe_dvt"] = .option(1)
        }
        // DVT signs, gestalt (PE most likely), immobilization, hemoptysis, and the "treatment within
        // 6 months / palliative" malignancy qualifier are subjective or not reliably grounded → left
        // for the clinician.
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        let score = CalculatorMath.sumPoints(answers, inputs: inputs)

        // Three-tier model → RiskLevel.
        let level: RiskLevel
        let tier3: String
        switch score {
        case ..<2:
            level = .low; tier3 = "low risk"
        case 2...6:
            level = .moderate; tier3 = "moderate risk"
        default:
            level = .high; tier3 = "high risk"
        }

        // Two-tier model → pathway driver.
        let peLikely = score > 4
        let twoTier = peLikely ? "PE likely" : "PE unlikely"
        let recommendation = peLikely
            ? "PE likely by the two-tier Wells — consider CT pulmonary angiography; a D-dimer alone does not exclude PE at high pretest probability."
            : "PE unlikely by the two-tier Wells — consider a D-dimer to exclude PE (or PERC in a low-risk patient), per your local pathway."

        var breakdown: [String] = []
        for input in inputs {
            guard case let .options(options) = input.field,
                  case let .option(idx)? = answers[input.id],
                  options.indices.contains(idx) else {
                breakdown.append("\(input.label): (not entered)")
                continue
            }
            let o = options[idx]
            breakdown.append("\(input.label): \(o.label) (+\(Self.fmt(o.points)))")
        }

        let scoreText = Self.fmt(score)
        return CalculatorResult(
            score: score,
            level: level,
            interpretation: "Wells PE \(scoreText) — \(tier3) (three-tier); \(twoTier) (two-tier).",
            recommendation: recommendation,
            breakdown: breakdown
        )
    }

    /// Format a half-point weight/score without a trailing ".0" (3 → "3", 1.5 → "1.5").
    private static func fmt(_ p: Double) -> String {
        p == p.rounded() ? String(Int(p)) : String(p)
    }
}
