import Foundation
import SwiftUI

// MARK: - Template Models
struct MedicalTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let category: TemplateCategory
    let specialty: MedicalSpecialty
    let content: String
    let parameters: [TemplateParameter]
    let voiceCommands: [String]
    let author: String
    let rating: Double
    let downloads: Int
    let isVerified: Bool
    let createdDate: Date
    let tags: [String]
    
    var formattedContent: String {
        var result = content
        for parameter in parameters {
            let placeholder = "{\(parameter.key)}"
            result = result.replacingOccurrences(of: placeholder, with: parameter.defaultValue)
        }
        return result
    }
    
    func applyParameters(_ values: [String: String]) -> String {
        var result = content
        for (key, value) in values {
            let placeholder = "{\(key)}"
            result = result.replacingOccurrences(of: placeholder, with: value)
        }
        return result
    }
}

struct TemplateParameter: Codable {
    let key: String
    let displayName: String
    let type: ParameterType
    let defaultValue: String
    let options: [String]?
    let isRequired: Bool
    
    enum ParameterType: String, Codable {
        case text
        case number
        case selection
        case multiLine
        case measurement
        case anatomicalLocation
        case medication
        case time
    }
}

enum TemplateCategory: String, CaseIterable, Codable {
    case procedures = "Procedures"
    case criticalCare = "Critical Care"
    case emergency = "Emergency"
    case psychiatric = "Psychiatric"
    case pediatrics = "Pediatrics"
    case admission = "Admission"
    case discharge = "Discharge"
    case consultation = "Consultation"
    
    var icon: String {
        switch self {
        case .procedures: return "scissors"
        case .criticalCare: return "heart.text.square"
        case .emergency: return "bolt.heart"
        case .psychiatric: return "brain"
        case .pediatrics: return "figure.child"
        case .admission: return "door.left.hand.open"
        case .discharge: return "door.right.hand.closed"
        case .consultation: return "person.2"
        }
    }
    
    var color: Color {
        switch self {
        case .procedures: return .blue
        case .criticalCare: return .red
        case .emergency: return .orange
        case .psychiatric: return .purple
        case .pediatrics: return .pink
        case .admission: return .green
        case .discharge: return .teal
        case .consultation: return .indigo
        }
    }
}

enum MedicalSpecialty: String, CaseIterable, Codable {
    case emergencyMedicine = "Emergency Medicine"
    case surgery = "Surgery"
    case internalMedicine = "Internal Medicine"
    case familyMedicine = "Family Medicine"
    case pediatrics = "Pediatrics"
    case obstetrics = "OB/GYN"
    case psychiatry = "Psychiatry"
    case cardiology = "Cardiology"
    case anesthesiology = "Anesthesiology"
    case radiology = "Radiology"
    case general = "General"
}

// MARK: - Sample Templates
extension MedicalTemplate {
    static let sampleTemplates = [
        // Laceration Repair Template
        MedicalTemplate(
            id: UUID(),
            name: "Laceration Repair",
            category: .procedures,
            specialty: .emergencyMedicine,
            content: """
            PROCEDURE: Laceration Repair
            
            INDICATION: {size} {shape} laceration to the {location}
            
            CONSENT: Risks, benefits, and alternatives discussed with patient including bleeding, infection, scarring, need for revision, and nerve/vessel injury. Patient expressed understanding and consented to procedure.
            
            TIMEOUT: Performed with patient identity and site verification
            
            ANESTHESIA: Local anesthesia with {anesthetic_type} - {anesthetic_amount}mL
            
            PREPARATION: Area cleansed with chlorhexidine. Sterile drapes applied.
            
            EXPLORATION: Wound explored - no foreign bodies identified. No tendon involvement. Neurovascular exam intact distally.
            
            IRRIGATION: Copious irrigation with {irrigation_amount}mL normal saline.
            
            REPAIR: {suture_count} interrupted sutures placed using {suture_type}. Good approximation achieved. Hemostasis confirmed.
            
            DRESSING: Antibiotic ointment and sterile dressing applied.
            
            DISPOSITION: Patient tolerated procedure well. Wound care instructions provided. Return in {return_days} days for suture removal or sooner if signs of infection.
            """,
            parameters: [
                TemplateParameter(key: "size", displayName: "Size", type: .measurement, defaultValue: "3cm", options: nil, isRequired: true),
                TemplateParameter(key: "shape", displayName: "Shape", type: .selection, defaultValue: "linear", options: ["linear", "curved", "stellate", "irregular"], isRequired: true),
                TemplateParameter(key: "location", displayName: "Location", type: .anatomicalLocation, defaultValue: "forearm", options: nil, isRequired: true),
                TemplateParameter(key: "anesthetic_type", displayName: "Anesthetic", type: .selection, defaultValue: "lidocaine 1% with epinephrine", options: ["lidocaine 1%", "lidocaine 1% with epinephrine", "bupivacaine 0.5%"], isRequired: true),
                TemplateParameter(key: "anesthetic_amount", displayName: "Anesthetic Amount (mL)", type: .number, defaultValue: "5", options: nil, isRequired: true),
                TemplateParameter(key: "irrigation_amount", displayName: "Irrigation Amount (mL)", type: .number, defaultValue: "500", options: nil, isRequired: true),
                TemplateParameter(key: "suture_count", displayName: "Number of Sutures", type: .number, defaultValue: "5", options: nil, isRequired: true),
                TemplateParameter(key: "suture_type", displayName: "Suture Type", type: .selection, defaultValue: "4-0 nylon", options: ["3-0 nylon", "4-0 nylon", "5-0 nylon", "4-0 vicryl", "5-0 vicryl"], isRequired: true),
                TemplateParameter(key: "return_days", displayName: "Return in Days", type: .number, defaultValue: "7", options: nil, isRequired: true)
            ],
            voiceCommands: [
                "laceration repair",
                "lac repair",
                "suture note"
            ],
            author: "Dr. Emergency",
            rating: 4.8,
            downloads: 1523,
            isVerified: true,
            createdDate: Date(),
            tags: ["procedure", "laceration", "sutures", "emergency"]
        ),
        
        // Intubation Template
        MedicalTemplate(
            id: UUID(),
            name: "Endotracheal Intubation",
            category: .criticalCare,
            specialty: .emergencyMedicine,
            content: """
            PROCEDURE: Endotracheal Intubation
            
            INDICATION: {indication}
            
            CONSENT: {consent_type}
            
            TIMEOUT: Performed with verification of patient, procedure, and equipment
            
            PRE-OXYGENATION: {preoxygenation_method} for {preoxygenation_time} minutes
            
            MEDICATIONS:
            - Induction: {induction_agent} {induction_dose}mg IV
            - Paralytic: {paralytic_agent} {paralytic_dose}mg IV
            
            EQUIPMENT:
            - Laryngoscope: {laryngoscope_type} blade
            - ETT: {ett_size}mm cuffed endotracheal tube
            
            PROCEDURE: Direct laryngoscopy performed. {cormack_grade} view obtained. ETT passed through vocal cords on {attempt_number} attempt. 
            
            CONFIRMATION:
            - Direct visualization of tube passing through cords
            - Bilateral breath sounds present
            - Absence of epigastric sounds
            - ETCO2 waveform confirmed
            - CXR ordered for tube position
            
            TUBE POSITION: {tube_depth}cm at the lips
            
            POST-INTUBATION:
            - Sedation: {post_sedation}
            - Ventilator settings: {vent_settings}
            
            COMPLICATIONS: {complications}
            
            Physician performed procedure.
            """,
            parameters: [
                TemplateParameter(key: "indication", displayName: "Indication", type: .selection, defaultValue: "Respiratory failure", options: ["Respiratory failure", "Airway protection", "Cardiac arrest", "Severe acidosis", "Procedural"], isRequired: true),
                TemplateParameter(key: "consent_type", displayName: "Consent", type: .selection, defaultValue: "Emergent - implied consent", options: ["Informed consent obtained", "Emergent - implied consent"], isRequired: true),
                TemplateParameter(key: "preoxygenation_method", displayName: "Preoxygenation", type: .selection, defaultValue: "NRB mask at 15L", options: ["NRB mask at 15L", "BVM", "NIPPV", "High-flow nasal cannula"], isRequired: true),
                TemplateParameter(key: "preoxygenation_time", displayName: "Preoxygenation Time", type: .number, defaultValue: "3", options: nil, isRequired: true),
                TemplateParameter(key: "induction_agent", displayName: "Induction Agent", type: .selection, defaultValue: "Etomidate", options: ["Etomidate", "Propofol", "Ketamine", "Midazolam"], isRequired: true),
                TemplateParameter(key: "induction_dose", displayName: "Induction Dose", type: .number, defaultValue: "20", options: nil, isRequired: true),
                TemplateParameter(key: "paralytic_agent", displayName: "Paralytic", type: .selection, defaultValue: "Rocuronium", options: ["Rocuronium", "Succinylcholine", "None"], isRequired: true),
                TemplateParameter(key: "paralytic_dose", displayName: "Paralytic Dose", type: .number, defaultValue: "100", options: nil, isRequired: true),
                TemplateParameter(key: "laryngoscope_type", displayName: "Laryngoscope", type: .selection, defaultValue: "MAC 3", options: ["MAC 3", "MAC 4", "Miller 3", "Miller 4", "Video laryngoscope"], isRequired: true),
                TemplateParameter(key: "ett_size", displayName: "ETT Size", type: .selection, defaultValue: "7.5", options: ["7.0", "7.5", "8.0", "8.5"], isRequired: true),
                TemplateParameter(key: "cormack_grade", displayName: "Cormack-Lehane", type: .selection, defaultValue: "Grade 1", options: ["Grade 1", "Grade 2", "Grade 3", "Grade 4"], isRequired: true),
                TemplateParameter(key: "attempt_number", displayName: "Attempt", type: .selection, defaultValue: "first", options: ["first", "second", "third"], isRequired: true),
                TemplateParameter(key: "tube_depth", displayName: "Tube Depth (cm)", type: .number, defaultValue: "22", options: nil, isRequired: true),
                TemplateParameter(key: "post_sedation", displayName: "Post Sedation", type: .text, defaultValue: "Propofol infusion started", options: nil, isRequired: true),
                TemplateParameter(key: "vent_settings", displayName: "Vent Settings", type: .text, defaultValue: "AC/VC, TV 450, RR 16, PEEP 5, FiO2 100%", options: nil, isRequired: true),
                TemplateParameter(key: "complications", displayName: "Complications", type: .selection, defaultValue: "None", options: ["None", "Hypotension - treated", "Desaturation - resolved", "Multiple attempts required"], isRequired: true)
            ],
            voiceCommands: [
                "intubation note",
                "intubation",
                "airway note"
            ],
            author: "Dr. Critical Care",
            rating: 4.9,
            downloads: 2341,
            isVerified: true,
            createdDate: Date(),
            tags: ["critical care", "intubation", "airway", "procedure"]
        ),
        
        // Critical Care Time Template
        MedicalTemplate(
            id: UUID(),
            name: "Critical Care Time",
            category: .criticalCare,
            specialty: .emergencyMedicine,
            content: """
            CRITICAL CARE TIME DOCUMENTATION
            
            DATE: {date}
            TOTAL CRITICAL CARE TIME: {total_time} minutes
            TIME EXCLUDING PROCEDURES: {care_time} minutes
            
            CRITICAL CARE PROVIDED:
            The patient required critical care services due to {primary_condition}. The patient's condition was life-threatening requiring frequent physician assessment and intervention.
            
            CRITICAL INTERVENTIONS PROVIDED:
            {interventions}
            
            TIME BREAKDOWN:
            - Initial assessment and stabilization: {initial_time} minutes
            - Ongoing reassessments and interventions: {ongoing_time} minutes
            - Family discussion: {family_time} minutes
            - Care coordination: {coordination_time} minutes
            
            The above time excludes separately billable procedures.
            
            Physician directly provided critical care services for the time documented above.
            """,
            parameters: [
                TemplateParameter(key: "date", displayName: "Date", type: .text, defaultValue: "Today", options: nil, isRequired: true),
                TemplateParameter(key: "total_time", displayName: "Total Time (min)", type: .number, defaultValue: "45", options: nil, isRequired: true),
                TemplateParameter(key: "care_time", displayName: "Care Time (min)", type: .number, defaultValue: "40", options: nil, isRequired: true),
                TemplateParameter(key: "primary_condition", displayName: "Primary Condition", type: .text, defaultValue: "septic shock", options: nil, isRequired: true),
                TemplateParameter(key: "interventions", displayName: "Interventions", type: .multiLine, defaultValue: "- Hemodynamic monitoring and titration of vasopressors\n- Ventilator management\n- Fluid resuscitation\n- Antibiotic selection and dosing", options: nil, isRequired: true),
                TemplateParameter(key: "initial_time", displayName: "Initial Time", type: .number, defaultValue: "15", options: nil, isRequired: true),
                TemplateParameter(key: "ongoing_time", displayName: "Ongoing Time", type: .number, defaultValue: "20", options: nil, isRequired: true),
                TemplateParameter(key: "family_time", displayName: "Family Time", type: .number, defaultValue: "5", options: nil, isRequired: true),
                TemplateParameter(key: "coordination_time", displayName: "Coordination Time", type: .number, defaultValue: "5", options: nil, isRequired: true)
            ],
            voiceCommands: [
                "critical care time",
                "critical care",
                "ICU time"
            ],
            author: "Dr. Billing Expert",
            rating: 5.0,
            downloads: 3892,
            isVerified: true,
            createdDate: Date(),
            tags: ["critical care", "billing", "time", "documentation"]
        )
    ]
}