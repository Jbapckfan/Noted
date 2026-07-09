import Foundation

/// Renders a note DETERMINISTICALLY from verified facts. The model extracts structured facts;
/// this template — not the model — assembles the prose. Same facts always produce the same note,
/// so there is no second opportunity for the model to hallucinate during "writing": every value
/// on the page is a value that already passed the `GroundingVerifier`.
public enum NoteTemplate {

    /// Emergency-department HPI + MDM note.
    public static func renderHPIandMDM(_ facts: ClinicalFacts) -> String {
        var sections: [String] = []

        if let cc = facts.chiefComplaint, !cc.isEmpty {
            sections.append("CHIEF COMPLAINT: \(cc)")
        }
        if let hpi = facts.hpi, !hpi.isEmpty {
            sections.append("HISTORY OF PRESENT ILLNESS:\n\(hpi)")
        }
        if !facts.vitals.isEmpty {
            let line = facts.vitals.map { "\($0.name) \($0.value)" }.joined(separator: ", ")
            sections.append("VITALS: \(line)")
        }
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
        if !facts.labs.isEmpty {
            var block = "RESULTS:"
            for l in facts.labs {
                let unit = l.unit.map { " \($0)" } ?? ""
                block += "\n  - \(l.test): \(l.value)\(unit)"
            }
            sections.append(block)
        }

        var mdm = "MEDICAL DECISION MAKING:"
        if !facts.differential.isEmpty {
            mdm += "\n  Differential considered: \(facts.differential.joined(separator: ", "))"
        }
        if let dx = facts.diagnosis, !dx.isEmpty {
            mdm += "\n  Diagnosis: \(dx)"
        }
        if mdm != "MEDICAL DECISION MAKING:" {
            sections.append(mdm)
        }

        if !facts.returnPrecautions.isEmpty {
            let block = "RETURN PRECAUTIONS:\n" + facts.returnPrecautions.map { "  - \($0)" }.joined(separator: "\n")
            sections.append(block)
        }

        return sections.joined(separator: "\n\n")
    }
}
