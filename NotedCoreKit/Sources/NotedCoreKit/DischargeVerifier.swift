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
    ///   - extractionJSON: Layer A — verified HPI facts.
    ///   - resultsTrayJSON: Layer B — physician-confirmed discrete results.
    ///   - dispositionTranscript: Layer C — the disposition dictation.
    public init(extractionJSON: String?, resultsTrayJSON: String?, dispositionTranscript: String?) {
        // Layers A and B are JSON — flatten to their leaf values so "troponin"/"0.02" become
        // adjacent tokens the grounding matcher can bind (JSON punctuation would otherwise split
        // them). Layer C is already free text.
        let combined = [
            Self.flattenJSON(extractionJSON),
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

    private func mentionsTest(_ test: String) -> Bool {
        let n = test.lowercased().replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !n.isEmpty else { return false }
        return normalizedSource.contains(n)
    }
}
