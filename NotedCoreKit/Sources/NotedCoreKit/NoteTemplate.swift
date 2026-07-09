import Foundation

/// Renders a note DETERMINISTICALLY from verified facts. The model extracts structured facts;
/// this template — not the model — assembles the prose. Same facts always produce the same note,
/// so there is no second opportunity for the model to hallucinate during "writing": every value
/// on the page is a value that already passed the `GroundingVerifier`.
///
/// The layout follows a full attending-grade ED note (CC, HPI, ROS, PMH, allergies, meds, vitals,
/// exam, results, MDM, impression, disposition, precautions) — the structure a cloud scribe emits,
/// but assembled from grounded facts so it can't drift or fabricate.
public enum NoteTemplate {

    /// Emergency-department HPI + MDM note.
    public static func renderHPIandMDM(_ facts: ClinicalFacts) -> String {
        // Nothing extracted yet → empty note (don't emit a lone "NKDA").
        let hasContent = facts.chiefComplaint?.isEmpty == false
            || facts.hpi?.isEmpty == false
            || !facts.medications.isEmpty || !facts.labs.isEmpty || !facts.vitals.isEmpty
            || facts.physicalExam?.isEmpty == false
            || facts.diagnosis?.isEmpty == false || !facts.differential.isEmpty
        guard hasContent else { return "" }

        var sections: [String] = []

        if let cc = facts.chiefComplaint, !cc.isEmpty {
            sections.append("CHIEF COMPLAINT: \(cc)")
        }
        if let hpi = facts.hpi, !hpi.isEmpty {
            sections.append("HISTORY OF PRESENT ILLNESS:\n\(hpi)")
        }
        if let ros = facts.reviewOfSystems, !ros.isEmpty {
            sections.append("REVIEW OF SYSTEMS:\n\(ros)")
        }
        if !facts.pastMedicalHistory.isEmpty {
            sections.append("PAST MEDICAL HISTORY: \(facts.pastMedicalHistory.joined(separator: ", "))")
        }
        sections.append("ALLERGIES: \(facts.allergies.isEmpty ? "No known drug allergies" : facts.allergies.joined(separator: ", "))")
        if !facts.medications.isEmpty {
            var block = "MEDICATIONS:"
            for m in facts.medications {
                var line = "  - \(m.drug)"
                if let d = m.dose, !d.isEmpty { line += " \(d)" }
                if let r = m.route, !r.isEmpty { line += " \(r)" }
                if let f = m.frequency, !f.isEmpty { line += " \(f)" }
                block += "\n\(line)"
            }
            sections.append(block)
        }
        if !facts.vitals.isEmpty {
            sections.append("VITALS: " + facts.vitals.map { "\($0.name) \($0.value)" }.joined(separator: ", "))
        }
        if let exam = facts.physicalExam, !exam.isEmpty {
            sections.append("PHYSICAL EXAM:\n\(exam)")
        }
        if !facts.labs.isEmpty {
            var block = "RESULTS:"
            for l in facts.labs {
                let unit = l.unit.map { " \($0)" } ?? ""
                block += "\n  - \(l.test): \(l.value)\(unit)"
            }
            sections.append(block)
        }

        var mdm = "MEDICAL DECISION MAKING:"
        if let reasoning = facts.mdm, !reasoning.isEmpty {
            mdm += "\n\(reasoning)"
        }
        if !facts.differential.isEmpty {
            mdm += "\n  Differential considered: \(facts.differential.joined(separator: ", "))"
        }
        if mdm != "MEDICAL DECISION MAKING:" {
            sections.append(mdm)
        }

        if let dx = facts.diagnosis, !dx.isEmpty {
            sections.append("CLINICAL IMPRESSION:\n  Diagnosis: \(dx)")
        }
        if let dispo = facts.disposition, !dispo.isEmpty {
            sections.append("DISPOSITION: \(dispo)")
        }
        if !facts.returnPrecautions.isEmpty {
            sections.append("RETURN PRECAUTIONS:\n" + facts.returnPrecautions.map { "  - \($0)" }.joined(separator: "\n"))
        }

        return sections.joined(separator: "\n\n")
    }
}
