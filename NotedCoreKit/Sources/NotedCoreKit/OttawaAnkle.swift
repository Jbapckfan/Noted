import Foundation

/// Ottawa Ankle Rule — a rule-OUT decision instrument for acute ankle/midfoot injury. It answers
/// two separate questions: is an ANKLE radiograph series indicated, and is a FOOT radiograph series
/// indicated. Each is a gated decision — a series is indicated only if there is pain in that zone
/// AND at least one bony-tenderness / inability-to-bear-weight criterion for that zone is present.
/// If neither series is indicated the rule clears the patient and imaging is not required. There is
/// no numeric score — the output is a boolean decision (`score = nil`).
///
/// Criteria per Stiell et al. (cross-check MDCalc):
///  - Ankle x-ray if malleolar-zone pain AND any of: bony tenderness at the posterior edge/tip of
///    the lateral malleolus; bony tenderness at the posterior edge/tip of the medial malleolus;
///    inability to bear weight (4 steps) both immediately and in the ED.
///  - Foot x-ray if midfoot-zone pain AND any of: bony tenderness at the base of the 5th metatarsal;
///    bony tenderness at the navicular; inability to bear weight.
///
/// Decision support only — it identifies which acute ankle/foot injuries warrant x-ray and shows its
/// work; the clinician sets disposition.
public struct OttawaAnkle: ClinicalCalculator {

    public init() {}

    public let id = "ottawa_ankle"
    public let name = "Ottawa Ankle Rule (ankle/foot injury)"
    public let citation = "Stiell IG, Greenberg GH, McKnight RD, et al. Ann Emerg Med 1992; JAMA 1993/1994. Ottawa Ankle Rules. (cross-check MDCalc)"

    /// Each item is a Yes/No finding. Points are cosmetic here (No = 0, Yes = 1); the decision is
    /// driven by the custom zone-gated boolean logic in `compute`, not by summing points. Inability
    /// to bear weight is a single shared finding — it satisfies the ankle branch, the foot branch, or
    /// both, depending on where the patient has zone pain.
    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "malleolar_pain", label: "Pain in the malleolar zone", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Malleolar zone = the region around the medial and lateral malleoli."),
        CalculatorInput(id: "lateral_malleolus", label: "Bony tenderness at the posterior edge or tip of the lateral malleolus", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Distal 6 cm of the posterior edge of the fibula, or the tip of the lateral malleolus."),
        CalculatorInput(id: "medial_malleolus", label: "Bony tenderness at the posterior edge or tip of the medial malleolus", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Distal 6 cm of the posterior edge of the tibia, or the tip of the medial malleolus."),
        CalculatorInput(id: "midfoot_pain", label: "Pain in the midfoot zone", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Midfoot zone = the region over the tarsals and metatarsal bases."),
        CalculatorInput(id: "fifth_metatarsal", label: "Bony tenderness at the base of the 5th metatarsal", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ])),
        CalculatorInput(id: "navicular", label: "Bony tenderness at the navicular", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ])),
        CalculatorInput(id: "unable_bear_weight", label: "Inability to bear weight (4 steps) both immediately and in the ED", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Unable to take four steps (transfer weight twice onto each foot, regardless of limping) both immediately after the injury and in the ED."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "ankle pain", "ankle injury", "ankle trauma", "ankle swelling",
            "twisted ankle", "rolled ankle", "sprained ankle", "hurt ankle", "injured ankle",
            "foot pain", "foot injury", "foot fracture",
            "malleol", "midfoot", "ankle", "foot"
        ]) else { return nil }
        return "Ankle/foot injury — the Ottawa Ankle Rule identifies which acute ankle and midfoot injuries need radiographs (applies to acute injury in alert, cooperative patients; use caution with intoxication, distracting injury, diminished leg sensation, or young children, and it does not apply to isolated soft-tissue or chronic pain)."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        // Every Ottawa Ankle criterion is a clinician-assessed exam finding (zone pain, bony
        // tenderness, weight-bearing). None can be grounded from the transcript, so nothing is
        // pre-filled — the model never guesses subjective/exam items.
        [:]
    }

    /// The state of one radiograph branch after applying its zone-gated logic.
    private enum BranchState {
        case indicated   // zone pain present AND ≥ 1 criterion present → x-ray indicated
        case cleared     // definitively not indicated (no zone pain, or zone pain with all criteria absent)
        case incomplete  // not enough answered to decide this branch

        var auditLabel: String {
            switch self {
            case .indicated:  return "x-ray indicated"
            case .cleared:    return "not indicated"
            case .incomplete: return "not assessed"
            }
        }
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        // Read each criterion as an optional Bool (nil = not entered).
        func value(_ id: String) -> Bool? {
            guard case let .option(idx)? = answers[id] else { return nil }
            return idx == 1
        }

        // A branch needs zone pain AND at least one of its criteria. It is definitively cleared when
        // there is no zone pain, or zone pain with every criterion answered and absent.
        func branch(zonePain: Bool?, criteria: [Bool?]) -> BranchState {
            switch zonePain {
            case .some(false):
                return .cleared
            case .none:
                return .incomplete
            case .some(true):
                if criteria.contains(where: { $0 == true }) { return .indicated }
                if criteria.allSatisfy({ $0 == false }) { return .cleared }
                return .incomplete
            }
        }

        // Inability to bear weight is shared by both branches.
        let ubw = value("unable_bear_weight")
        let ankle = branch(zonePain: value("malleolar_pain"),
                           criteria: [value("lateral_malleolus"), value("medial_malleolus"), ubw])
        let foot = branch(zonePain: value("midfoot_pain"),
                          criteria: [value("fifth_metatarsal"), value("navicular"), ubw])

        let ankleXray = ankle == .indicated
        let footXray = foot == .indicated

        let level: RiskLevel
        let interpretation: String
        let recommendation: String
        if ankleXray || footXray {
            // Any positive branch → radiograph indicated, regardless of the other answers.
            level = .high
            let series: String
            let phrase: String
            if ankleXray && footXray {
                series = "ankle and foot x-rays indicated"
                phrase = "ankle and foot radiographs"
            } else if ankleXray {
                series = "ankle x-ray indicated"
                phrase = "an ankle radiograph series"
            } else {
                series = "foot x-ray indicated"
                phrase = "a foot radiograph series"
            }
            interpretation = "Ottawa Ankle Rule positive — \(series)."
            recommendation = "Consider \(phrase) per the Ottawa Ankle Rule."
        } else if ankle == .cleared && foot == .cleared {
            // Both branches definitively negative → rule clears.
            level = .low
            interpretation = "Ottawa Ankle Rule negative — no ankle or foot x-ray required by the rule."
            recommendation = "Consider clinical management without ankle/foot radiographs, with return precautions and reassessment as clinically indicated."
        } else {
            // No branch indicated yet, but at least one zone/criterion is unassessed → cannot clear.
            level = .indeterminate
            interpretation = "Ottawa Ankle Rule incomplete — zone pain or tenderness/weight-bearing findings not assessed; cannot clear for no imaging."
            recommendation = "Consider completing the malleolar-zone and midfoot-zone Ottawa Ankle criteria before deciding on imaging."
        }

        // One audit line per component (the raw finding), then the two zone-gated branch conclusions.
        var breakdown: [String] = []
        for input in inputs {
            switch value(input.id) {
            case .some(true):  breakdown.append("\(input.label): Yes")
            case .some(false): breakdown.append("\(input.label): No")
            case .none:        breakdown.append("\(input.label): (not entered)")
            }
        }
        breakdown.append("Ankle series (malleolar-zone pain + lateral/medial malleolus tenderness or inability to bear weight): \(ankle.auditLabel)")
        breakdown.append("Foot series (midfoot-zone pain + 5th-metatarsal/navicular tenderness or inability to bear weight): \(foot.auditLabel)")

        return CalculatorResult(
            score: nil,
            level: level,
            interpretation: interpretation,
            recommendation: recommendation,
            breakdown: breakdown
        )
    }
}
