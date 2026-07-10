import Foundation

/// Canadian C-Spine Rule (CCR) for cervical-spine radiography in ALERT (GCS 15) and STABLE adult
/// blunt-trauma patients with neck concern. This is a rule-out decision instrument, not an additive
/// score, so `compute` implements the published three-step boolean logic and `score` is nil.
///
/// Step 1 — any HIGH-RISK factor (age ≥65; a dangerous mechanism; paresthesias in the extremities)?
///          If yes → imaging.
/// Step 2 — any LOW-RISK factor that permits safe range-of-motion testing (simple rear-end MVC;
///          sitting position in the ED; ambulatory at any time; delayed onset of neck pain; absence
///          of midline cervical-spine tenderness)? If none → imaging.
/// Step 3 — able to actively rotate the neck 45° left AND right? If unable → imaging; if able → no
///          imaging.
///
/// Criteria per Stiell et al., JAMA 2001 (cross-check MDCalc). Decision support only — it computes
/// whether the rule mandates imaging; the clinician sets disposition. The rule does NOT apply to
/// non-trauma neck pain, GCS <15, unstable vitals, age <16, acute paralysis, known vertebral
/// disease, or prior cervical-spine surgery.
public struct CanadianCSpine: ClinicalCalculator {

    public init() {}

    public let id = "canadian_cspine"
    public let name = "Canadian C-Spine Rule"
    public let citation = "Stiell IG, Wells GA, Vandemheen KL, et al. The Canadian C-Spine Rule for radiography in alert and stable trauma patients. JAMA 2001;286(15):1841-8. (cross-check MDCalc)"

    // Every criterion is a No/Yes toggle: index 0 = No (absent), index 1 = Yes (present).
    private static let yesNo: [Option] = [Option("No", 0), Option("Yes", 1)]

    // Grouped for the three-step logic.
    private let highRiskIDs = ["age_65", "dangerous_mechanism", "paresthesias"]
    private let lowRiskIDs = ["rear_end", "sitting", "ambulatory", "delayed_pain", "no_midline_tenderness"]
    private let rotationID = "rotation"

    public let inputs: [CalculatorInput] = [
        // Step 1 — high-risk factors that mandate imaging.
        CalculatorInput(id: "age_65", label: "Age ≥ 65 years",
                        field: .options(CanadianCSpine.yesNo),
                        help: "High-risk factor."),
        CalculatorInput(id: "dangerous_mechanism", label: "Dangerous mechanism",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Fall ≥1 m / 5 stairs; axial load to the head (e.g. diving); high-speed MVC (>100 km/h), rollover, or ejection; motorized recreational vehicle; bicycle collision."),
        CalculatorInput(id: "paresthesias", label: "Paresthesias in extremities",
                        field: .options(CanadianCSpine.yesNo),
                        help: "High-risk factor."),
        // Step 2 — low-risk factors that permit safe range-of-motion testing.
        CalculatorInput(id: "rear_end", label: "Simple rear-end motor vehicle collision",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Excludes: pushed into oncoming traffic, hit by bus/large truck, rollover, hit by high-speed vehicle."),
        CalculatorInput(id: "sitting", label: "Sitting position in the ED",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Low-risk factor permitting safe range-of-motion testing."),
        CalculatorInput(id: "ambulatory", label: "Ambulatory at any time",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Walking at any point since the injury."),
        CalculatorInput(id: "delayed_pain", label: "Delayed onset of neck pain",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Neck pain that was not immediate."),
        CalculatorInput(id: "no_midline_tenderness", label: "Absence of midline C-spine tenderness",
                        field: .options(CanadianCSpine.yesNo),
                        help: "No tenderness on palpation of the posterior midline cervical spine."),
        // Step 3 — active range of motion.
        CalculatorInput(id: "rotation", label: "Able to actively rotate neck 45° left AND right",
                        field: .options(CanadianCSpine.yesNo),
                        help: "Assessed only after a low-risk factor confirms it is safe to test."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "neck pain", "neck injury", "neck trauma", "cervical spine", "c-spine", "cspine",
            "cervical tenderness", "whiplash",
        ]) else { return nil }
        return "Neck concern in trauma — the Canadian C-Spine Rule decides whether cervical-spine imaging is needed, but applies ONLY to alert (GCS 15), stable blunt-trauma patients ≥16 years; it does not apply to non-trauma neck pain, obtunded/unstable patients, or those with acute paralysis or known vertebral disease."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // Only the age criterion is objectively grounded; mechanism, symptoms, exam, and range of
        // motion are clinician-assessed and never guessed.
        if let age = facts.ageYears {
            out["age_65"] = .option(age >= 65 ? 1 : 0)
        }
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        let breakdown = inputs.map { input -> String in
            "\(input.label): \(answerLabel(input, answers))"
        }

        // Step 1 — any high-risk factor present → imaging.
        if highRiskIDs.contains(where: { isYes($0, answers) == true }) {
            let hits = highRiskIDs.compactMap { id in isYes(id, answers) == true ? label(for: id) : nil }
            return CalculatorResult(
                score: nil,
                level: .high,
                interpretation: "High-risk factor present (\(hits.joined(separator: ", "))) — cervical-spine imaging indicated by the Canadian C-Spine Rule.",
                recommendation: "Consider cervical-spine imaging (radiography, or CT if high-risk mechanism) per the Canadian C-Spine Rule.",
                breakdown: breakdown
            )
        }
        // To safely pass Step 1, every high-risk factor must be answered "No".
        guard highRiskIDs.allSatisfy({ isYes($0, answers) != nil }) else {
            return indeterminate(breakdown, missing: "high-risk factors")
        }

        // Step 2 — need at least one low-risk factor to permit safe range-of-motion testing.
        if !lowRiskIDs.contains(where: { isYes($0, answers) == true }) {
            // No low-risk factor present. Confirm every low-risk factor is answered "No" before
            // concluding the rule mandates imaging.
            guard lowRiskIDs.allSatisfy({ isYes($0, answers) != nil }) else {
                return indeterminate(breakdown, missing: "low-risk factors")
            }
            return CalculatorResult(
                score: nil,
                level: .high,
                interpretation: "No low-risk factor to permit safe range-of-motion testing — cervical-spine imaging indicated by the Canadian C-Spine Rule.",
                recommendation: "Consider cervical-spine imaging (radiography) per the Canadian C-Spine Rule.",
                breakdown: breakdown
            )
        }

        // Step 3 — active rotation of 45° left and right.
        guard let canRotate = isYes(rotationID, answers) else {
            return indeterminate(breakdown, missing: "active neck rotation")
        }
        if canRotate {
            return CalculatorResult(
                score: nil,
                level: .low,
                interpretation: "No high-risk factor, a low-risk factor permits safe assessment, and the neck rotates 45° left and right — cervical-spine imaging not required by the Canadian C-Spine Rule.",
                recommendation: "Consider clinical clearance of the cervical spine without imaging in this alert, stable patient, per the Canadian C-Spine Rule.",
                breakdown: breakdown
            )
        }
        return CalculatorResult(
            score: nil,
            level: .high,
            interpretation: "Unable to actively rotate the neck 45° left and right — cervical-spine imaging indicated by the Canadian C-Spine Rule.",
            recommendation: "Consider cervical-spine imaging (radiography) per the Canadian C-Spine Rule.",
            breakdown: breakdown
        )
    }

    // MARK: - Helpers

    /// Tri-state read of a No/Yes toggle: nil = not entered, true = Yes (present), false = No (absent).
    private func isYes(_ id: String, _ answers: Answers) -> Bool? {
        guard case let .option(idx)? = answers[id] else { return nil }
        return idx == 1
    }

    private func label(for id: String) -> String {
        inputs.first { $0.id == id }?.label ?? id
    }

    private func answerLabel(_ input: CalculatorInput, _ answers: Answers) -> String {
        guard case let .options(options) = input.field,
              case let .option(idx)? = answers[input.id],
              options.indices.contains(idx) else { return "(not entered)" }
        return options[idx].label
    }

    private func indeterminate(_ breakdown: [String], missing: String) -> CalculatorResult {
        CalculatorResult(
            score: nil,
            level: .indeterminate,
            interpretation: "Cannot apply the Canadian C-Spine Rule — \(missing) not fully entered.",
            recommendation: "Complete the outstanding criteria to apply the Canadian C-Spine Rule.",
            breakdown: breakdown
        )
    }
}
