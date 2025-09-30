import Foundation

struct MedicalNote {
    var chiefComplaint: String = ""
    var hpi: String = ""
    var pmh: String = ""
    var psh: String = ""
    var medications: String = ""
    var allergies: String = ""
    var socialHistory: String = ""
    var familyHistory: String = ""
    var reviewOfSystems: String = ""
    var physicalExam: String = ""
    var labs: String = ""
    var mdm: String = ""
    var plan: String = ""
    var impression: String = ""

    func formatted() -> String {
        var sections: [String] = []

        if !chiefComplaint.isEmpty {
            sections.append("Chief Complaint: \(chiefComplaint)")
        }

        if !hpi.isEmpty {
            sections.append("HPI: \(hpi)")
        }

        if !pmh.isEmpty {
            sections.append("PMH: \(pmh)")
        }

        if !psh.isEmpty {
            sections.append("PSH: \(psh)")
        }

        if !medications.isEmpty {
            sections.append("Medications: \(medications)")
        }

        if !allergies.isEmpty {
            sections.append("Allergies: \(allergies)")
        }

        if !socialHistory.isEmpty {
            sections.append("Social History: \(socialHistory)")
        }

        if !familyHistory.isEmpty {
            sections.append("Family History: \(familyHistory)")
        }

        if !reviewOfSystems.isEmpty {
            sections.append("Review of Systems:\n\(reviewOfSystems)")
        }

        if !physicalExam.isEmpty {
            sections.append("PHYSICAL EXAM:\n\(physicalExam)")
        }

        if !labs.isEmpty {
            sections.append("Pertinent Labs, Imaging, and other study results:\n\(labs)")
        }

        if !mdm.isEmpty {
            sections.append("MDM:\n\(mdm)")
        }

        if !plan.isEmpty {
            sections.append("Plan:\n\(plan)")
        }

        if !impression.isEmpty {
            sections.append("Impression:\n\(impression)")
        }

        return sections.joined(separator: "\n\n")
    }
}