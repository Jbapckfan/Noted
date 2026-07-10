import Foundation

/// CURB-65 severity score for community-acquired pneumonia. Five one-point criteria (Confusion,
/// Urea, Respiratory rate, Blood pressure, age ≥ 65), summed 0–5, stratifying 30-day mortality to
/// guide the admit-vs-outpatient decision. Additive instrument built on the `ClinicalCalculator`
/// pattern (see `HEARTScore`).
///
/// Criteria per Lim WS et al., Thorax 2003 (cross-check MDCalc). Decision support only — it
/// estimates mortality and suggests a care setting; the clinician sets disposition.
public struct CURB65: ClinicalCalculator {

    public init() {}

    public let id = "curb65"
    public let name = "CURB-65 (pneumonia severity)"
    public let citation = "Lim WS, van der Eerden MM, Laing R, et al. Thorax 2003;58:377–382. CURB-65. (cross-check MDCalc)"

    public let inputs: [CalculatorInput] = [
        CalculatorInput(id: "confusion", label: "Confusion (new)", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "New-onset disorientation to person, place, or time (or AMT ≤ 8) — not chronic baseline confusion."),
        CalculatorInput(id: "urea", label: "Urea > 7 mmol/L (BUN > 19 mg/dL)", field: .options([
            Option("No", 0),
            Option("Yes", 1),
        ]), help: "Serum urea > 7 mmol/L, equivalently blood urea nitrogen (BUN) > 19 mg/dL."),
        CalculatorInput(id: "resp_rate", label: "Respiratory rate ≥ 30", field: .options([
            Option("< 30", 0),
            Option("≥ 30", 1),
        ]), help: "Respiratory rate of 30 breaths/min or greater."),
        CalculatorInput(id: "bp", label: "Blood pressure (SBP < 90 or DBP ≤ 60)", field: .options([
            Option("SBP ≥ 90 and DBP > 60", 0),
            Option("SBP < 90 or DBP ≤ 60", 1),
        ]), help: "Systolic BP < 90 mmHg or diastolic BP ≤ 60 mmHg."),
        CalculatorInput(id: "age", label: "Age ≥ 65", field: .options([
            Option("< 65", 0),
            Option("≥ 65", 1),
        ])),
    ]

    public func relevance(_ facts: ClinicalFacts) -> String? {
        guard facts.mentions(anyOf: [
            "pneumonia", "cough", "dyspnea", "shortness of breath", "difficulty breathing",
            "respiratory infection", "productive cough", "lower respiratory",
        ]) else { return nil }
        let age = facts.ageYears.map { " (age \($0))" } ?? ""
        return "Pneumonia / respiratory infection\(age) — CURB-65 estimates 30-day mortality to guide admit vs outpatient care. Apply to suspected community-acquired pneumonia."
    }

    public func prefill(_ facts: ClinicalFacts) -> Answers {
        var out: Answers = [:]

        // Age ≥ 65 (the most reliably grounded input).
        if let age = facts.ageYears {
            out["age"] = .option(age >= 65 ? 1 : 0)
        }

        // Respiratory rate ≥ 30, from a documented vital.
        if let rr = respRate(facts) {
            out["resp_rate"] = .option(rr >= 30 ? 1 : 0)
        }

        // Blood pressure: SBP < 90 or DBP ≤ 60. Only mark negative when BOTH values are documented,
        // since a low diastolic alone satisfies the criterion.
        let bp = bloodPressure(facts)
        if let sbp = bp.sbp {
            if sbp < 90 {
                out["bp"] = .option(1)
            } else if let dbp = bp.dbp {
                out["bp"] = .option(dbp <= 60 ? 1 : 0)
            }
            // SBP ≥ 90 with no diastolic → leave for the clinician (DBP could still trigger).
        } else if let dbp = bp.dbp, dbp <= 60 {
            out["bp"] = .option(1)
        }

        // Urea / BUN, unit-aware (mmol/L → threshold 7; mg/dL → threshold 19).
        if let positive = ureaPositive(facts) {
            out["urea"] = .option(positive ? 1 : 0)
        }

        // Confusion requires a baseline comparison (is it NEW?) → subjective, left for the clinician.
        return out
    }

    public func compute(_ answers: Answers) -> CalculatorResult {
        let score = CalculatorMath.sumPoints(answers, inputs: inputs)
        let n = Int(score)

        let level: RiskLevel
        let severity: String
        switch n {
        case 0, 1: level = .low; severity = "low severity"
        case 2:    level = .moderate; severity = "moderate severity"
        default:   level = .high; severity = "severe"
        }

        let mortality: String
        switch n {
        case 0:  mortality = "0.6% 30-day mortality"
        case 1:  mortality = "2.7% 30-day mortality"
        case 2:  mortality = "6.8% 30-day mortality"
        case 3:  mortality = "14.0% 30-day mortality"
        default: mortality = "27.8% 30-day mortality"   // 4–5
        }

        let recommendation: String
        switch n {
        case 0, 1:
            recommendation = "Low severity — consider outpatient treatment with oral antibiotics, per your local pathway."
        case 2:
            recommendation = "Moderate severity — consider a short inpatient admission or hospital-supervised outpatient (observation) management."
        case 3:
            recommendation = "Severe — consider hospital admission for inpatient treatment."
        default:
            recommendation = "Severe — consider hospital admission and assessment for ICU-level care (score 4–5)."
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

        return CalculatorResult(
            score: score,
            level: level,
            interpretation: "CURB-65 score \(n) — \(severity) (\(mortality)).",
            recommendation: recommendation,
            breakdown: breakdown
        )
    }

    // MARK: - Grounded prefill helpers

    /// First documented respiratory-rate vital, if any.
    private func respRate(_ facts: ClinicalFacts) -> Double? {
        for v in facts.vitals {
            let n = v.name.lowercased()
            if n.contains("resp") || n == "rr" {
                if let d = Self.numbers(in: v.value).first { return d }
            }
        }
        return nil
    }

    /// Systolic / diastolic blood pressure parsed from vitals (combined "120/80" or split SBP/DBP).
    private func bloodPressure(_ facts: ClinicalFacts) -> (sbp: Double?, dbp: Double?) {
        var sbp: Double? = nil
        var dbp: Double? = nil
        for v in facts.vitals {
            let n = v.name.lowercased()
            let nums = Self.numbers(in: v.value)
            if n.contains("systolic") || n.contains("sbp") {
                sbp = sbp ?? nums.first
            } else if n.contains("diastolic") || n.contains("dbp") {
                dbp = dbp ?? nums.first
            } else if n.contains("bp") || n.contains("blood pressure") {
                if nums.count >= 2 {
                    sbp = sbp ?? nums[0]
                    dbp = dbp ?? nums[1]
                } else if let f = nums.first {
                    sbp = sbp ?? f
                }
            }
        }
        return (sbp, dbp)
    }

    /// Whether a documented urea/BUN lab exceeds the CURB threshold, or nil if none is documented.
    private func ureaPositive(_ facts: ClinicalFacts) -> Bool? {
        for l in facts.labs {
            let t = l.test.lowercased()
            guard t.contains("bun") || t.contains("urea") else { continue }
            guard let v = Self.numbers(in: l.value).first else { continue }
            let unit = (l.unit ?? "").lowercased()
            if unit.contains("mmol") { return v > 7 }
            if unit.contains("mg") { return v > 19 }
            // No/ambiguous unit → fall back to conventional units by name.
            if t.contains("bun") || t.contains("nitrogen") { return v > 19 } // BUN, mg/dL
            return v > 7                                                      // urea, mmol/L
        }
        return nil
    }

    private static func numbers(in s: String) -> [Double] {
        guard let re = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?") else { return [] }
        let ns = s as NSString
        let matches = re.matches(in: s, range: NSRange(location: 0, length: ns.length))
        return matches.compactMap { Double(ns.substring(with: $0.range)) }
    }
}
