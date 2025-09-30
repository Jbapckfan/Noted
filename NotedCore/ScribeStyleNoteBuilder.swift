import Foundation

@MainActor
struct ScribeStyleNoteBuilder {
    func buildNote(noteType: NoteType, context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        // Drive by specialty preset first, then fall back to noteType
        let specialty = CoreAppState.shared.specialty
        switch specialty {
        case .emergency, .urgentCare:
            return buildEDNote(context: context, transcription: transcription)
        case .hospitalMedicine:
            return buildSOAPLikeNote(context: context, transcription: transcription, title: "Hospital Medicine")
        case .clinic:
            return buildSOAPLikeNote(context: context, transcription: transcription, title: "Clinic")
        default:
            break
        }
        // Fallback by note type
        switch noteType {
        case .edNote:
            return buildEDNote(context: context, transcription: transcription)
        default:
            return buildSOAPLikeNote(context: context, transcription: transcription, title: noteType.rawValue)
        }
    }
    
    private func buildEDNote(context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        let room = CoreAppState.shared.currentRoom
        let ccDisplay = CoreAppState.shared.currentChiefComplaint.isEmpty ? chiefComplaint(from: context, transcription: transcription) : CoreAppState.shared.currentChiefComplaint

        let cc = ccDisplay
        let hpi = hpiOLDCARTS(context: context, transcription: transcription)
        let ros = reviewOfSystems(context: context)
        let pmh = sectionFromConditions(context: context)
        let meds = sectionFromMeds(context: context)
        let exam = defaultPE(context: context)
        let mdm = mdmSection(context: context, transcription: transcription)
        let plan = planSection(context: context)
        let dispo = dispositionSection(context: context, transcription: transcription)

        return """
        Room \(room.isEmpty ? "—" : room) | \(cc)

        HPI
        \(hpi)

        ROS
        \(ros)

        PMH
        \(pmh)

        MEDS
        \(meds)

        EXAM
        \(exam)

        MDM
        \(mdm)

        PLAN
        \(plan)

        DISPO
        \(dispo)
        """
    }
    
    private func buildSOAPLikeNote(context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String, title: String) -> String {
        let ts = Date().formatted(date: .abbreviated, time: .shortened)
        let cc = chiefComplaint(from: context, transcription: transcription)
        let hpi = hpiOLDCARTS(context: context, transcription: transcription)
        let meds = sectionFromMeds(context: context)
        let pmh = sectionFromConditions(context: context)
        let ros = reviewOfSystems(context: context)
        let vitals = sectionFromVitals(context: context)
        let exam = defaultPE(context: context)
        let assessmentPlan = mdmSection(context: context, transcription: transcription) + "\n\n" + planSection(context: context)
        
        return """
        \(title.uppercased()) NOTE — Generated: \(ts)

        SUBJECTIVE
        Chief Complaint: \(cc)
        HPI: \(hpi)
        ROS: \(ros)

        OBJECTIVE
        Vitals: \(vitals)
        Exam: \(exam)

        ASSESSMENT & PLAN
        \(assessmentPlan)
        """
    }
    
    // MARK: - Section Builders
    private func chiefComplaint(from context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        if let first = context.symptoms.first(where: { !$0.isNegated }) {
            if let duration = first.duration { return "\(first.name.capitalized) \(duration)" }
            return first.name.capitalized
        }
        if transcription.lowercased().contains("chest pain") { return "Chest pain" }
        return "Undifferentiated complaint"
    }
    
    private func hpiOLDCARTS(context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        // Choose one primary non-negated symptom
        let primary = context.symptoms.first(where: { !$0.isNegated })
        let onset = primary?.onset?.value != nil && primary?.onset?.unit != nil ? "Onset \(primary!.onset!.value!) \(String(describing: primary!.onset!.unit!))." : nil
        let location = primary?.location != nil ? "Location: \(primary!.location!)." : nil
        let duration = primary?.duration != nil ? "Duration: \(primary!.duration!)." : nil
        let character = primary?.quality != nil ? "Character: \(primary!.quality!)." : nil
        let severity = primary?.severity != nil ? "Severity: \(primary!.severity!)." : nil
        let associated = associatedFindings(context: context)
        let negatives = pertinentNegatives(context: context)
        
        let parts = [onset, location, duration, character, severity, associated, negatives].compactMap { $0 }
        return parts.isEmpty ? "Patient reports symptoms consistent with \(chiefComplaint(from: context, transcription: transcription).lowercased())." : parts.joined(separator: " ")
    }
    
    private func associatedFindings(context: EnhancedMedicalAnalyzer.MedicalContext) -> String? {
        let assoc = context.symptoms.filter { !$0.isNegated }.map { $0.name }.uniqued().prefix(4)
        guard !assoc.isEmpty else { return nil }
        return "Associated: " + assoc.joined(separator: ", ") + "."
    }
    
    private func pertinentNegatives(context: EnhancedMedicalAnalyzer.MedicalContext) -> String? {
        let neg = context.negations.map { $0.finding }.uniqued().prefix(4)
        guard !neg.isEmpty else { return nil }
        return "Denies: " + neg.joined(separator: ", ") + "."
    }
    
    private func sectionFromConditions(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        if context.conditions.isEmpty { return "PMH: none reported." }
        let list = context.conditions.map { $0.name.capitalized }.uniqued().joined(separator: ", ")
        return "PMH: \(list)."
    }
    
    private func sectionFromMeds(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        if context.medications.isEmpty { return "Meds: none reported." }
        let meds = context.medications.map { med in
            var s = med.name.capitalized
            if let dose = med.dose { s += " \(dose)" }
            if let freq = med.frequency { s += " \(freq)" }
            switch med.status {
            case .discontinued(let when): s += " (stopped\(when != nil ? " \(when!)" : ""))"
            case .allergic: s += " (allergy)"
            default: break
            }
            return s
        }.uniqued().joined(separator: "; ")
        return "Meds: \(meds)."
    }
    
    private func sectionFromVitals(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        if context.vitals.isEmpty { return "Not recorded." }
        return context.vitals.map { v in
            if let unit = v.unit { return "\(v.type): \(v.value) \(unit)" }
            return "\(v.type): \(v.value)"
        }.joined(separator: ", ")
    }
    
    private func defaultPE(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        // Focused, non-verbatim
        var lines: [String] = []
        lines.append("General: Alert, oriented, no acute distress.")
        lines.append("Cardiac: Regular rate and rhythm.")
        lines.append("Lungs: Clear to auscultation bilaterally.")
        if context.symptoms.contains(where: { $0.location == "abdomen" }) {
            lines.append("Abdomen: Soft, non-distended; focal tenderness per HPI.")
        } else {
            lines.append("Abdomen: Soft, non-tender.")
        }
        return "• " + lines.joined(separator: "\n• ")
    }
    
    private func mdmSection(context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        var parts: [String] = []
        let cc = chiefComplaint(from: context, transcription: transcription).lowercased()
        
        // Working differential tailored to common ED presentations
        var ddx: [String] = []
        if cc.contains("chest pain") {
            ddx = ["Acute coronary syndrome", "Pulmonary embolism", "Aortic dissection", "Pneumothorax", "Pneumonia", "GERD"]
        } else if cc.contains("shortness of breath") {
            ddx = ["CHF exacerbation", "COPD exacerbation", "Asthma", "Pneumonia", "PE"]
        } else if cc.contains("abdominal") {
            ddx = ["Appendicitis", "Cholecystitis", "Pancreatitis", "Bowel obstruction", "Gastroenteritis"]
        } else if cc.contains("headache") {
            ddx = ["Migraine", "Tension headache", "SAH", "Meningitis"]
        }
        if !ddx.isEmpty { parts.append("Differential: " + ddx.prefix(6).joined(separator: ", ") + ".") }
        
        // Risk factors from context
        if context.conditions.contains(where: { $0.name.contains("diabetes") }) && cc.contains("chest") {
            parts.append("Risk: Diabetes increases atypical ACS risk.")
        }
        if context.medications.contains(where: { med in
            if case .discontinued = med.status {
                let name = med.name.lowercased()
                return name.contains("anticoag") || name.contains("apix") || name.contains("rivarox")
            }
            return false
        }) {
            parts.append("Risk: Recent anticoagulation discontinuation → elevated VTE risk.")
        }
        
        // Decision rationale
        parts.append("MDM focuses on ruling out life‑threatening causes first, then symptom control and safe disposition.")
        return parts.joined(separator: " ")
    }
    
    private func planSection(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        var orders: [String] = []

        // Only include specific orders mentioned or clearly indicated
        if context.symptoms.contains(where: { $0.name.lowercased().contains("chest") }) {
            orders.append("EKG")
            orders.append("Troponin")
        }
        if context.symptoms.contains(where: { $0.name.contains("nausea") }) {
            orders.append("Antiemetic")
        }
        if context.symptoms.contains(where: { $0.name.contains("pain") }) {
            orders.append("Analgesia")
        }

        return orders.isEmpty ? "Per protocol." : orders.joined(separator: ", ")
    }
    
    private func dispositionSection(context: EnhancedMedicalAnalyzer.MedicalContext, transcription: String) -> String {
        return "See orders and plan."
    }
    
    private func reviewOfSystems(context: EnhancedMedicalAnalyzer.MedicalContext) -> String {
        var ros: [String] = []
        
        // Check for common symptoms
        if context.symptoms.contains(where: { $0.name.lowercased().contains("chest pain") }) {
            ros.append("Cardiovascular: positive for chest pain")
        }
        if context.symptoms.contains(where: { $0.name.lowercased().contains("shortness") || $0.name.lowercased().contains("dyspnea") }) {
            ros.append("Respiratory: positive for dyspnea")
        }
        if context.symptoms.contains(where: { $0.name.lowercased().contains("nausea") || $0.name.lowercased().contains("vomiting") }) {
            ros.append("GI: positive for nausea/vomiting")
        }
        if context.symptoms.contains(where: { $0.name.lowercased().contains("headache") }) {
            ros.append("Neurological: positive for headache")
        }
        
        if ros.isEmpty {
            return "ROS: Ten-point review of systems otherwise negative."
        }
        
        return "ROS: " + ros.joined(separator: "; ") + ". Otherwise negative."
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
