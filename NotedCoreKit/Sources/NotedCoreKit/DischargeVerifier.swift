import Foundation

public struct DischargeVerificationReport: Equatable, Sendable {
    /// Copy-slot / grounding violations (reused from `GroundingVerifier`).
    public let groundingFlags: [VerificationFlag]
    /// Structural problems (missing required sections, unmapped pending results).
    public let structuralIssues: [String]
    public var isClean: Bool { groundingFlags.isEmpty && structuralIssues.isEmpty }
    public init(groundingFlags: [VerificationFlag], structuralIssues: [String]) {
        self.groundingFlags = groundingFlags
        self.structuralIssues = structuralIssues
    }
}

/// Verifies a discharge summary against its three source layers before it can be signed.
///
///  - Every prescribed drug/dose/route and every explained result must be grounded in Layer A
///    (HPI facts), Layer B (results tray), or Layer C (disposition dictation) — same digit-exact
///    grounding as the note verifier.
///  - Every return precaution must be a `ReturnPrecautionLibrary` entry for the final diagnosis.
///  - Pending results must reference tests that were actually ordered (present in the sources).
///  - Required sections (diagnosis, clinical course, follow-up, return precautions) must be present.
public struct DischargeVerifier {

    private let sourceText: String
    private let normalizedSource: String

    /// - Parameters:
    ///   - hpiGroundTruth: Layer A — the encounter TRANSCRIPT (ground truth), NOT the raw
    ///     extraction JSON. Grounding against the model's own unfiltered extraction would let a
    ///     hallucinated value launder itself into the discharge; the transcript is the real source.
    ///   - resultsTrayJSON: Layer B — physician-confirmed discrete results.
    ///   - dispositionTranscript: Layer C — the disposition dictation.
    public init(hpiGroundTruth: String?, resultsTrayJSON: String?, dispositionTranscript: String?) {
        // Layer B is JSON — flatten to its leaf values so "troponin"/"0.02" become adjacent tokens
        // the grounding matcher can bind. Layers A and C are already free text (fall through
        // flattenJSON unchanged when not JSON).
        let combined = [
            Self.flattenJSON(hpiGroundTruth),
            Self.flattenJSON(resultsTrayJSON),
            dispositionTranscript,
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
        self.sourceText = combined
        self.normalizedSource = combined.lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    /// Collect every leaf string/number value from a JSON document into a flat, space-joined
    /// stream (falls back to the raw text if it isn't valid JSON).
    static func flattenJSON(_ json: String?) -> String? {
        guard let json, !json.isEmpty else { return nil }
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        else { return json }
        var leaves: [String] = []
        collectLeaves(obj, into: &leaves)
        return leaves.joined(separator: " ")
    }

    private static func collectLeaves(_ value: Any, into leaves: inout [String]) {
        switch value {
        case let dict as [String: Any]:
            for (_, v) in dict { collectLeaves(v, into: &leaves) }
        case let array as [Any]:
            for v in array { collectLeaves(v, into: &leaves) }
        case let s as String:
            leaves.append(s)
        case let n as NSNumber:
            leaves.append(n.stringValue)
        default:
            break
        }
    }

    public func verify(_ s: DischargeSummary) -> DischargeVerificationReport {
        // Copy-slot grounding: map the discharge's meds/results onto ClinicalFacts and reuse the
        // note verifier against the combined A+B+C source, with precautions gated by the library.
        var facts = ClinicalFacts(
            medications: s.medicationsPrescribed.map {
                Medication(drug: $0.drug,
                           dose: $0.dose.isEmpty ? nil : $0.dose,
                           route: $0.route.isEmpty ? nil : $0.route)
            },
            labs: s.resultsExplained.map { LabResult(test: $0.test, value: $0.resultValueVerbatim) }
        )
        facts.returnPrecautions = s.returnPrecautions

        let allowed = ReturnPrecautionLibrary.approvedSet(forDiagnosis: s.finalDiagnosis)
        let grounding = GroundingVerifier(transcript: sourceText, allowedPrecautions: allowed).verify(facts)

        // Structural checks.
        var issues: [String] = []
        if s.finalDiagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("final diagnosis is missing")
        }
        if s.briefClinicalCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("brief clinical course is missing")
        }
        if s.followUp.isEmpty {
            issues.append("follow-up is missing")
        }
        if s.returnPrecautions.isEmpty {
            issues.append("return precautions are missing")
        }
        for p in s.pendingResults where !mentionsTest(p.test) {
            issues.append("pending result '\(p.test)' was not an ordered test in this encounter")
        }

        return DischargeVerificationReport(groundingFlags: grounding.flags, structuralIssues: issues)
    }

    /// GATE the discharge (symmetric with the note path's `GroundingVerifier.filtered`): return a
    /// summary with every ungrounded prescribed dose/route/frequency/duration/quantity blanked, each
    /// ungrounded explained-result dropped, and each out-of-library precaution removed — so nothing
    /// unsupported can reach the rendered clinician/patient text. Structural issues are still
    /// reported (missing sections don't get invented, only flagged).
    public func filtered(_ s: DischargeSummary) -> (summary: DischargeSummary, report: DischargeVerificationReport) {
        var kept = s
        var flags: [VerificationFlag] = []
        let allowed = ReturnPrecautionLibrary.approvedSet(forDiagnosis: s.finalDiagnosis)
        let verifier = GroundingVerifier(transcript: sourceText, allowedPrecautions: allowed)

        // Prescribed meds: drop a med whose drug wasn't said; blank any ungrounded sub-field.
        kept.medicationsPrescribed = s.medicationsPrescribed.compactMap { med in
            let one = ClinicalFacts(medications: [Medication(
                drug: med.drug,
                dose: med.dose.isEmpty ? nil : med.dose,
                route: med.route.isEmpty ? nil : med.route,
                frequency: med.frequency.isEmpty ? nil : med.frequency)])
            let (f, r) = verifier.filtered(one)
            flags.append(contentsOf: r.flags)
            guard let gm = f.medications.first else { return nil } // drug not said → drop the prescription
            var out = med
            out.dose = gm.dose ?? ""
            out.route = gm.route ?? ""
            out.frequency = gm.frequency ?? ""
            if !out.duration.isEmpty, !numberNearKeyword(out.duration, keywords: Self.durationKeywords) {
                flags.append(.init(kind: .ungroundedDose, claim: "\(med.drug) duration \(out.duration)", detail: "removed — duration not said in the encounter"))
                out.duration = ""
            }
            if !out.quantity.isEmpty, !numberNearKeyword(out.quantity, keywords: Self.quantityKeywords) {
                flags.append(.init(kind: .ungroundedDose, claim: "\(med.drug) quantity \(out.quantity)", detail: "removed — quantity not said in the encounter"))
                out.quantity = ""
            }
            return out
        }

        // Explained results: drop any whose value isn't grounded (same unit/comparator gate as notes).
        kept.resultsExplained = s.resultsExplained.filter { rex in
            let one = ClinicalFacts(labs: [LabResult(test: rex.test, value: rex.resultValueVerbatim)])
            let (f, r) = verifier.filtered(one)
            flags.append(contentsOf: r.flags)
            return !f.labs.isEmpty
        }

        // Return precautions: keep only library-approved (reuse the note gate's precaution filter).
        var pf = ClinicalFacts(); pf.returnPrecautions = s.returnPrecautions
        let (pff, pr) = verifier.filtered(pf)
        kept.returnPrecautions = pff.returnPrecautions
        flags.append(contentsOf: pr.flags.filter { $0.kind == .fabricatedPrecaution })

        // Structural checks run on the FILTERED summary.
        var issues: [String] = []
        if kept.finalDiagnosis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("final diagnosis is missing") }
        if kept.briefClinicalCourse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { issues.append("brief clinical course is missing") }
        if kept.followUp.isEmpty { issues.append("follow-up is missing") }
        if kept.returnPrecautions.isEmpty { issues.append("return precautions are missing") }
        for p in kept.pendingResults where !mentionsTest(p.test) {
            issues.append("pending result '\(p.test)' was not an ordered test in this encounter")
        }

        return (kept, DischargeVerificationReport(groundingFlags: flags, structuralIssues: issues))
    }

    private static let durationKeywords = ["day", "days", "week", "weeks", "month", "months",
                                           "hour", "hours", "night", "nights", "dose", "doses"]
    private static let quantityKeywords = ["tablet", "tablets", "capsule", "capsules", "pill", "pills",
                                           "dose", "doses", "count", "ml", "#", "dispense"]

    /// Each number in `text` appears in the source ADJACENT to a matching keyword. Prevents a
    /// fabricated duration/quantity ("for 30 days", "#30") from grounding on an unrelated "30"
    /// elsewhere in the source (an age, a time, a different value). No number → nothing to verify.
    private func numberNearKeyword(_ text: String, keywords: [String]) -> Bool {
        let toks = GroundingVerifier.numericTokens(in: text)
        if toks.isEmpty { return true }
        let ns = normalizedSource as NSString
        return toks.allSatisfy { num in
            guard let re = try? NSRegularExpression(pattern: "(?<![0-9.])\(NSRegularExpression.escapedPattern(for: num))(?![0-9.])") else { return false }
            var ok = false
            re.enumerateMatches(in: normalizedSource, range: NSRange(location: 0, length: ns.length)) { m, _, stop in
                guard let m = m else { return }
                let lo = max(0, m.range.location - 12)
                let hi = min(ns.length, m.range.location + m.range.length + 16)
                let window = ns.substring(with: NSRange(location: lo, length: hi - lo))
                if keywords.contains(where: { window.contains($0) }) { ok = true; stop.pointee = true }
            }
            return ok
        }
    }

    private func mentionsTest(_ test: String) -> Bool {
        let n = test.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return false }
        return normalizedSource.contains(n)
    }
}
