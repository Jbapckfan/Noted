import Foundation

/// PERC Rule (Pulmonary Embolism Rule-out Criteria) for a patient in whom PE is being considered.
/// Eight yes/no criteria; the rule is a pure BOOLEAN gate, not an additive score, so `score` is
/// always nil. PERC is PERC-NEGATIVE only when ALL eight criteria are absent — and it is only valid
/// once the clinician has ALREADY judged pretest probability low (gestalt <15%). In that setting a
/// PERC-negative patient has <2% probability of PE, so PE can be excluded without D-dimer or imaging.
/// A SINGLE positive criterion means PE cannot be excluded by PERC.
///
/// Criteria per Kline's original PERC derivation/validation (cross-check MDCalc). Decision support
/// only — it clears or fails a rule-out; the clinician sets disposition.
public struct PERCRule: ClinicalCalculator {

    public init() {}

    public let id = "perc"
    public let name = "PERC Rule (rule out PE)"
    public let citation = "Kline JA, et al. J Thromb Haemost 2004;2:1247. Multicenter validation Kline 2008. PERC rule. (cross-check MDCalc)"

    /// Each criterion is a 2-option gate: "No" (absent, 0) / "Yes" (present, 1). The points are only
    /// used to read the chosen direction; there is no numeric PERC score.
    private static func criterion(_ id: String, _ label: String, help: String? = nil) -> CalculatorInput {
        CalculatorInput(id: id, label: label, field: .options([Option("No", 0), Option("Yes", 1)]), help: help)
    }

    public let inputs: [CalculatorInput] = [
        PERCRule.criterion("age50", "Age ≥ 50"),
        PERCRule.criterion("hr100", "Heart rate ≥ 100"),
        PERCRule.criterion("sao2", "SaO₂ < 95% on room air",
                           help: "Uses the room-air pulse-ox; a value on supplemental O₂ does not satisfy this criterion."),
        PERCRule.criterion("leg_swelling", "Unilateral leg swelling",
                           help: "Asymmetric calf/leg swelling suggestive of DVT."),
        PERCRule.criterion("hemoptysis", "Hemoptysis"),
        PERCRule.criterion("surgery_trauma", "Recent surgery or trauma",
                           help: "Surgery or trauma within the past 4 weeks requiring hospitalization or treatment under general anesthesia."),
        PERCRule.criterion("prior_pe_dvt", "Prior PE or DVT"),
        PERCRule.criterion("hormone", "Hormone use (estrogen)",
                           help: "Oral contraceptives, hormone replacement, or estrogenic hormones."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "chest pain", "pleuritic", "dyspnea", "shortness of breath", "short of breath",
            "pulmonary embolism", "suspected pe", "hemoptysis"
        ]) else { return nil }
        return "Suspected PE (chest pain / dyspnea) — PERC can exclude PE without any testing, but only once your pretest probability is already low (gestalt <15%)."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // Age is unconditional and objective → prefill both directions.
        if let age = facts.ageYears {
            out["age50"] = .option(age >= 50 ? 1 : 0)
        }
        // Heart rate is an objective vital → prefill both directions.
        if let hr = facts.vitalValue("HR") {
            out["hr100"] = .option(hr >= 100 ? 1 : 0)
        }
        // SaO₂ carries a room-air condition a bare vital can't confirm. Only prefill the POSITIVE
        // (hypoxic) direction — the safe direction toward more testing — and leave a normal reading
        // for the clinician to confirm was on room air. Prefer specific sat vital names.
        for name in ["SpO2", "SaO2", "oxygen saturation", "O2 sat", "pulse ox"] {
            if let sat = facts.vitalValue(name) {
                if sat < 95 { out["sao2"] = .option(1) }
                break
            }
        }
        // Unilateral leg swelling, hemoptysis, recent surgery/trauma, prior PE/DVT, and hormone use
        // are history/exam items — never guessed; the clinician confirms each.
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        var breakdown: [String] = []
        var presentLabels: [String] = []
        var answeredCount = 0
        var anyYes = false

        for input in inputs {
            guard case let .options(options) = input.field else { continue }
            if case let .option(idx)? = answers[input.id], options.indices.contains(idx) {
                answeredCount += 1
                let isYes = options[idx].points > 0
                if isYes { anyYes = true; presentLabels.append(input.label) }
                breakdown.append("\(input.label): \(options[idx].label)\(isYes ? " (criterion present)" : "")")
            } else {
                breakdown.append("\(input.label): (not entered)")
            }
        }

        let total = inputs.count
        let level: RiskLevel
        let interpretation: String
        let recommendation: String

        if anyYes {
            // A single positive criterion means PERC cannot exclude PE — short-circuits even if the
            // remaining criteria are unanswered.
            level = .high
            interpretation = "PERC positive — \(presentLabels.count) of \(total) criteria present (\(presentLabels.joined(separator: ", "))); PE cannot be excluded by PERC and warrants further evaluation."
            recommendation = "Cannot rule out PE by PERC — consider an age-adjusted D-dimer and further workup guided by your pretest probability."
        } else if answeredCount == total {
            level = .low
            interpretation = "PERC negative — all \(total) criteria absent; with a low pretest probability (gestalt <15%), PE probability is <2% and PE can be excluded without D-dimer or imaging."
            recommendation = "Consider excluding PE without D-dimer or imaging, provided your pretest probability was already low (gestalt <15%)."
        } else {
            level = .indeterminate
            interpretation = "PERC incomplete — \(answeredCount) of \(total) criteria answered, none positive yet; answer all \(total) to apply the rule."
            recommendation = "Consider completing all \(total) PERC criteria; a single positive criterion means PE cannot be excluded by PERC."
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
