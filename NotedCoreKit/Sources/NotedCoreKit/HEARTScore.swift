import Foundation

/// HEART Score for major cardiac events in ED chest-pain patients. Five components (History, ECG,
/// Age, Risk factors, Troponin), each 0–2, summed 0–10. This is the reference implementation of the
/// `ClinicalCalculator` pattern; the others follow its shape.
///
/// Criteria per the original Six/Backus HEART score (cross-check MDCalc). Decision support only —
/// it estimates 6-week MACE risk and suggests a pathway; the clinician sets disposition.
public struct HEARTScore: ClinicalCalculator {

    public init() {}

    public let id = "heart"
    public let name = "HEART Score (chest pain)"
    public let citation = "Six AJ, Backus BE, Kelder JC. Neth Heart J 2008. HEART score. (cross-check MDCalc)"

    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "history", label: "History", field: .options([
            Option("Slightly suspicious", 0),
            Option("Moderately suspicious", 1),
            Option("Highly suspicious", 2),
        ]), help: "Clinical gestalt for the story of the chest pain."),
        CalculatorInput(id: "ecg", label: "ECG", field: .options([
            Option("Normal", 0),
            Option("Non-specific repolarization disturbance", 1),
            Option("Significant ST deviation", 2),
        ]), help: "LBBB / paced / LVH with repolarization count as non-specific."),
        CalculatorInput(id: "age", label: "Age", field: .options([
            Option("< 45", 0),
            Option("45–64", 1),
            Option("≥ 65", 2),
        ])),
        CalculatorInput(id: "risk_factors", label: "Risk factors", field: .options([
            Option("No known risk factors", 0),
            Option("1–2 risk factors", 1),
            Option("≥ 3 risk factors, or history of atherosclerotic disease", 2),
        ]), help: "HTN, hypercholesterolemia, DM, obesity, smoking, family history of CAD; atherosclerotic disease = prior MI/PCI/CABG, CVA/TIA, or PAD."),
        CalculatorInput(id: "troponin", label: "Initial troponin", field: .options([
            Option("≤ normal limit", 0),
            Option("1–3× normal limit", 1),
            Option("> 3× normal limit", 2),
        ]), help: "Relative to your assay's 99th-percentile upper reference limit."),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: ["chest pain", "chest pressure", "chest tightness", "chest discomfort", "chest heaviness"]) else { return nil }
        let age = facts.ageYears.map { " (age \($0))" } ?? ""
        return "Chest pain\(age) — HEART estimates 6-week MACE for undifferentiated chest pain."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]
        // Age → band (the most reliably grounded input).
        if let age = facts.ageYears {
            out["age"] = .option(age < 45 ? 0 : (age < 65 ? 1 : 2))
        }
        // Risk factors → count documented categories; atherosclerotic disease forces the top band.
        let pmh = facts.pastMedicalHistory.joined(separator: " ").lowercased()
        let hpi = (facts.hpi ?? "").lowercased()
        let text = pmh + " " + hpi
        let atherosclerotic = ["prior mi", "myocardial infarction", "coronary artery disease", "cad",
                               "stent", "pci", "cabg", "bypass", "stroke", "cva", "tia",
                               "peripheral arterial", "peripheral vascular", "pad"]
        let riskCategories: [[String]] = [
            ["hypertension", "htn", "high blood pressure"],
            ["hyperlipidemia", "hypercholesterolemia", "high cholesterol", "dyslipidemia"],
            ["diabetes", "dm", "diabetic"],
            ["obese", "obesity"],
            ["smok", "tobacco", "nicotine"],
            ["family history of cad", "family history of coronary", "fh of cad", "father", "mother"], // conservative
        ]
        if atherosclerotic.contains(where: { text.contains($0) }) {
            out["risk_factors"] = .option(2)
        } else {
            let count = riskCategories.filter { group in group.contains { text.contains($0) } }.count
            out["risk_factors"] = .option(count == 0 ? 0 : (count <= 2 ? 1 : 2))
        }
        // History, ECG, troponin are subjective / assay-relative → left for the clinician.
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        let score = CalculatorMath.sumPoints(answers, inputs: inputs)
        let level: RiskLevel
        let mace: String
        let recommendation: String
        switch score {
        case ..<4:
            level = .low; mace = "0.9–1.7% 6-week MACE"
            recommendation = "Low risk — consider discharge with shared decision-making and follow-up, per your local pathway."
        case 4..<7:
            level = .moderate; mace = "12–16.6% 6-week MACE"
            recommendation = "Moderate risk — consider observation with serial troponin / further testing."
        default:
            level = .high; mace = "50–65% 6-week MACE"
            recommendation = "High risk — consider admission and early cardiology involvement."
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
            interpretation: "HEART score \(n) — \(level.rawValue) risk (\(mace)).",
            recommendation: recommendation,
            breakdown: breakdown
        )
    }
}
