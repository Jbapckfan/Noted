import Foundation

/// NEXUS Low-Risk Criteria for cervical-spine imaging in blunt trauma. A pure rule-out instrument:
/// the cervical spine can be cleared CLINICALLY, without imaging, only when ALL FIVE low-risk
/// criteria are satisfied (i.e. none of the five concerning findings is present). If any one finding
/// is present the rule cannot exclude injury and imaging is indicated.
///
/// The five low-risk criteria (all must be NEGATIVE to clear):
///   1. No posterior midline cervical-spine tenderness
///   2. No focal neurologic deficit
///   3. Normal alertness (no altered level of consciousness)
///   4. No evidence of intoxication
///   5. No painful distracting injury
///
/// There is no numeric score — the output is a boolean decision (`score == nil`). Criteria per the
/// original NEXUS study (Hoffman et al., NEJM 2000; cross-check MDCalc). Decision support only: it
/// applies the rule to findings the clinician confirmed; it never sets disposition on its own.
public struct NEXUSCSpine: ClinicalCalculator {

    public init() {}

    public let id = "nexus"
    public let name = "NEXUS C-Spine Criteria"
    public let citation = "Hoffman JR, Mower WR, Wolfson AB, et al. Validity of a set of clinical criteria to rule out injury to the cervical spine in patients with blunt trauma (NEXUS). N Engl J Med 2000;343:94-99. (cross-check MDCalc)"

    /// Each criterion is phrased as the presence of a CONCERNING finding. "No" (index 0) means the
    /// finding is absent — the low-risk criterion is met. "Yes" (index 1) means the finding is
    /// present — that criterion is NOT met, so the spine cannot be cleared clinically.
    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "tenderness", label: "Posterior midline cervical-spine tenderness", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Bony tenderness on palpation of the posterior midline of the cervical spine."),
        CalculatorInput(id: "deficit", label: "Focal neurologic deficit", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Any focal motor or sensory deficit referable to the spinal cord or nerve roots."),
        CalculatorInput(id: "alertness", label: "Altered level of alertness", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "GCS < 15, disorientation to person/place/time/events, delayed or inappropriate response, or inability to remember 3 objects at 5 minutes. Normal alertness is required to clear."),
        CalculatorInput(id: "intoxication", label: "Evidence of intoxication", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Recent intoxicant history, odor of alcohol, slurred speech, ataxia, dysmetria, or other behavioral/physical signs; or a confirming test."),
        CalculatorInput(id: "distracting", label: "Painful distracting injury", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Any injury that could distract from the pain of a cervical-spine injury — e.g. long-bone fracture, large laceration/degloving/crush, large burn, or visceral injury."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "neck pain", "neck injury", "cervical", "c-spine", "whiplash",
            "trauma", "mvc", "motor vehicle", "collision", "mva",
            "fall", "fell", "assault", "struck", "diving"
        ]) else { return nil }
        return "Blunt trauma / neck pain — NEXUS can clear the cervical spine without imaging when all 5 low-risk criteria are met; it applies only to blunt-trauma patients."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        // Every NEXUS criterion is a clinician-performed exam / judgment (midline tenderness, focal
        // deficit, alertness, intoxication, distracting injury). None can be reliably grounded from
        // the transcript without guessing, so all five are left for the clinician. Never guess
        // subjective/exam inputs — that would fabricate a clearance decision.
        return [:]
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        // Classify each criterion: present (finding, criterion NOT met), absent (met), or unassessed.
        var failed = 0        // findings present → low-risk criterion not met
        var unassessed = 0    // criterion not yet answered
        var breakdown: [String] = []

        for input in inputs {
            guard case let .options(options) = input.field else { continue }
            switch answers[input.id] {
            case let .option(idx)? where options.indices.contains(idx):
                if idx == 0 {
                    breakdown.append("\(input.label): No — criterion met")
                } else {
                    failed += 1
                    breakdown.append("\(input.label): Yes — criterion NOT met")
                }
            default:
                unassessed += 1
                breakdown.append("\(input.label): (not assessed)")
            }
        }

        // Incomplete input → the rule cannot be applied.
        if unassessed > 0 {
            return CalculatorResult(
                score: nil,
                level: .indeterminate,
                interpretation: "NEXUS C-Spine: \(unassessed) of 5 low-risk criteria not yet assessed — the rule cannot be applied.",
                recommendation: "Consider completing the cervical-spine exam to apply NEXUS; do not clear the c-spine on an incomplete assessment.",
                breakdown: breakdown
            )
        }

        if failed == 0 {
            return CalculatorResult(
                score: nil,
                level: .low,
                interpretation: "NEXUS C-Spine: all 5 low-risk criteria met — c-spine imaging not required by NEXUS.",
                recommendation: "Consider clinical clearance of the cervical spine without imaging per NEXUS, if the patient meets the rule's assumptions (blunt trauma).",
                breakdown: breakdown
            )
        }

        let noun = failed == 1 ? "criterion" : "criteria"
        return CalculatorResult(
            score: nil,
            level: .high,
            interpretation: "NEXUS C-Spine: \(failed) of 5 low-risk \(noun) not met — cannot clear the cervical spine clinically; obtain c-spine imaging.",
            recommendation: "Consider cervical-spine imaging (CT per your local pathway); NEXUS low-risk criteria are not all met.",
            breakdown: breakdown
        )
    }
}
