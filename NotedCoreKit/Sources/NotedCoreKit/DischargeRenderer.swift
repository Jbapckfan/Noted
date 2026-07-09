import Foundation

/// Two renderings, one fact set. The clinician rendering is a clinical-register deterministic
/// template (goes in the chart). The patient rendering is a style transform over the SAME locked
/// facts: second person, abbreviations expanded to plain words — but drugs, doses, and result
/// values pass through BYTE-IDENTICAL (copy slots never get "simplified").
public enum DischargeRenderer {

    // MARK: - Clinician

    public static func renderClinician(_ s: DischargeSummary) -> String {
        var out: [String] = []
        out.append("FINAL DIAGNOSIS: \(s.finalDiagnosis)")
        if !s.differentialRuledOut.isEmpty {
            out.append("DIFFERENTIAL RULED OUT: \(s.differentialRuledOut.joined(separator: ", "))")
        }
        if !s.briefClinicalCourse.isEmpty {
            out.append("CLINICAL COURSE:\n\(s.briefClinicalCourse)")
        }
        if !s.resultsExplained.isEmpty {
            out.append("RESULTS:\n" + s.resultsExplained.map { "  - \($0.test): \($0.resultValueVerbatim)" }.joined(separator: "\n"))
        }
        if !s.treatmentsGivenInED.isEmpty {
            out.append("TREATMENTS IN ED:\n" + s.treatmentsGivenInED.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !s.medicationsPrescribed.isEmpty {
            out.append("MEDICATIONS PRESCRIBED:\n" + s.medicationsPrescribed.map { "  - \(clinicianMedLine($0))" }.joined(separator: "\n"))
        }
        if !s.medicationsChangedOrStopped.isEmpty {
            out.append("MEDICATIONS CHANGED/STOPPED:\n" + s.medicationsChangedOrStopped.map { "  - \($0)" }.joined(separator: "\n"))
        }
        if !s.followUp.isEmpty {
            out.append("FOLLOW-UP:\n" + s.followUp.map { "  - \($0.who)\($0.when.isEmpty ? "" : " (\($0.when))")\($0.why.isEmpty ? "" : " — \($0.why)")" }.joined(separator: "\n"))
        }
        if !s.pendingResults.isEmpty {
            out.append("PENDING RESULTS:\n" + s.pendingResults.map { "  - \($0.test)\($0.howCommunicated.isEmpty ? "" : " — \($0.howCommunicated)")" }.joined(separator: "\n"))
        }
        if !s.returnPrecautions.isEmpty {
            out.append("RETURN PRECAUTIONS:\n" + s.returnPrecautions.map { "  - \($0)" }.joined(separator: "\n"))
        }
        return out.joined(separator: "\n\n")
    }

    private static func clinicianMedLine(_ m: PrescribedMedication) -> String {
        [m.drug, m.dose, m.route, m.frequency, m.duration.isEmpty ? "" : "x \(m.duration)", m.quantity.isEmpty ? "" : "(#\(m.quantity))"]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Patient

    public static func renderPatient(_ s: DischargeSummary) -> String {
        var out: [String] = []
        out.append("Your visit summary")
        out.append("You were seen for \(plain(s.finalDiagnosis)).")

        if !s.medicationsPrescribed.isEmpty {
            out.append("Your medicines:")
            for m in s.medicationsPrescribed { out.append("  - \(patientMedLine(m))") }
        }
        if !s.followUp.isEmpty {
            out.append("Follow-up:")
            for f in s.followUp {
                var line = "  - See \(f.who)"
                if !f.when.isEmpty { line += " \(f.when)" }
                if !f.why.isEmpty { line += " so they can \(plain(f.why))" }
                out.append(line + ".")
            }
        }
        if !s.activityDietWorkRestrictions.isEmpty {
            out.append("What to do and not do:")
            for r in s.activityDietWorkRestrictions { out.append("  - \(expandAbbreviations(r))") }
        }
        if !s.patientInstructions.isEmpty {
            for i in s.patientInstructions { out.append(expandAbbreviations(i)) }
        }
        if !s.pendingResults.isEmpty {
            out.append("Tests still pending:")
            for p in s.pendingResults {
                out.append("  - Your \(p.test) is not back yet.\(p.howCommunicated.isEmpty ? "" : " We will \(plain(p.howCommunicated)).")")
            }
        }
        if !s.returnPrecautions.isEmpty {
            out.append("Come back to the ER if:")
            for r in s.returnPrecautions { out.append("  - \(expandAbbreviations(r))") }
        }
        return out.joined(separator: "\n")
    }

    /// Copy slots (drug, dose, quantity) pass through unchanged; only route/frequency abbreviations
    /// are expanded to plain words.
    private static func patientMedLine(_ m: PrescribedMedication) -> String {
        var line = "Take \(m.drug)"
        if !m.dose.isEmpty { line += " \(m.dose)" }              // copy slot — byte-identical
        if !m.route.isEmpty { line += " \(expandAbbreviations(m.route))" }
        if !m.frequency.isEmpty { line += " \(expandAbbreviations(m.frequency))" }
        if !m.duration.isEmpty { line += " for \(m.duration)" }
        if !m.quantity.isEmpty { line += " (you were given \(m.quantity))" } // copy slot
        return line + "."
    }

    private static func plain(_ text: String) -> String { expandAbbreviations(text) }

    static let abbreviations: [(String, String)] = [
        (#"\bPO\b"#, "by mouth"),
        (#"\bIV\b"#, "through a vein"),
        (#"\bIM\b"#, "as a shot in the muscle"),
        (#"\bSL\b"#, "under the tongue"),
        (#"\bBID\b"#, "twice a day"),
        (#"\bTID\b"#, "three times a day"),
        (#"\bQID\b"#, "four times a day"),
        (#"\bQHS\b"#, "at bedtime"),
        (#"\bPRN\b"#, "as needed"),
        (#"\bq(\d+)h\b"#, "every $1 hours"),
        (#"\bqday\b"#, "once a day"),
        (#"\bdaily\b"#, "once a day"),
        (#"\bPCP\b"#, "primary care doctor"),
        (#"\bED\b"#, "emergency room"),
        (#"\bER\b"#, "emergency room"),
    ]

    static func expandAbbreviations(_ text: String) -> String {
        var result = text
        for (pattern, replacement) in abbreviations {
            result = result.replacingOccurrences(
                of: pattern, with: replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }
}
