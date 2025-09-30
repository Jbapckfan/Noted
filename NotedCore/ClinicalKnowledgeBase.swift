import Foundation

/// Comprehensive clinical knowledge base for offline differential diagnosis
/// and emergency medicine recognition
struct ClinicalKnowledgeBase {

    // MARK: - Symptom to Differential Diagnosis Mapping

    static let symptomToDifferentials: [String: [DifferentialDiagnosis]] = [
        // Chest Pain
        "chest pain": [
            DifferentialDiagnosis(diagnosis: "Acute Coronary Syndrome", urgency: .emergent, workup: ["EKG", "Troponin", "CXR"], redFlags: ["radiation to jaw/arm", "diaphoresis", "nausea"]),
            DifferentialDiagnosis(diagnosis: "Pulmonary Embolism", urgency: .emergent, workup: ["D-dimer", "CT PE protocol", "Wells score"], redFlags: ["sudden onset", "dyspnea", "tachycardia"]),
            DifferentialDiagnosis(diagnosis: "Aortic Dissection", urgency: .emergent, workup: ["CT angiography", "ECG", "CXR"], redFlags: ["tearing pain", "radiation to back", "blood pressure differential"]),
            DifferentialDiagnosis(diagnosis: "Pneumothorax", urgency: .urgent, workup: ["CXR", "Ultrasound"], redFlags: ["sudden dyspnea", "decreased breath sounds"]),
            DifferentialDiagnosis(diagnosis: "GERD", urgency: .nonUrgent, workup: ["Trial of PPI", "Upper endoscopy if persistent"], redFlags: []),
            DifferentialDiagnosis(diagnosis: "Costochondritis", urgency: .nonUrgent, workup: ["Clinical diagnosis"], redFlags: [])
        ],

        // Headache
        "headache": [
            DifferentialDiagnosis(diagnosis: "Subarachnoid Hemorrhage", urgency: .emergent, workup: ["Non-contrast CT head", "LP if CT negative"], redFlags: ["thunderclap onset", "worst headache of life", "syncope"]),
            DifferentialDiagnosis(diagnosis: "Meningitis", urgency: .emergent, workup: ["LP", "Blood cultures", "CT head"], redFlags: ["fever", "neck stiffness", "photophobia", "altered mental status"]),
            DifferentialDiagnosis(diagnosis: "Temporal Arteritis", urgency: .urgent, workup: ["ESR", "CRP", "Temporal artery biopsy"], redFlags: ["age >50", "jaw claudication", "vision changes"]),
            DifferentialDiagnosis(diagnosis: "Migraine", urgency: .nonUrgent, workup: ["Clinical diagnosis", "MRI if atypical"], redFlags: []),
            DifferentialDiagnosis(diagnosis: "Tension Headache", urgency: .nonUrgent, workup: ["Clinical diagnosis"], redFlags: [])
        ],

        // Abdominal Pain
        "abdominal pain": [
            DifferentialDiagnosis(diagnosis: "Acute Appendicitis", urgency: .urgent, workup: ["CT abdomen/pelvis", "CBC", "Surgical consult"], redFlags: ["RLQ pain", "periumbilical migration", "fever"]),
            DifferentialDiagnosis(diagnosis: "Perforated Viscus", urgency: .emergent, workup: ["Upright CXR", "CT abdomen/pelvis", "Surgical consult"], redFlags: ["sudden onset", "peritoneal signs", "free air"]),
            DifferentialDiagnosis(diagnosis: "Bowel Obstruction", urgency: .urgent, workup: ["CT abdomen/pelvis", "Surgical consult"], redFlags: ["distension", "no bowel movement", "vomiting"]),
            DifferentialDiagnosis(diagnosis: "Ectopic Pregnancy", urgency: .emergent, workup: ["β-hCG", "Pelvic ultrasound"], redFlags: ["female of childbearing age", "missed period", "vaginal bleeding"]),
            DifferentialDiagnosis(diagnosis: "AAA", urgency: .emergent, workup: ["CT angiography", "Ultrasound", "Vascular surgery consult"], redFlags: ["age >60", "pulsatile mass", "back pain"])
        ],

        // Shortness of Breath
        "shortness of breath": [
            DifferentialDiagnosis(diagnosis: "Acute MI", urgency: .emergent, workup: ["EKG", "Troponin", "CXR"], redFlags: ["chest pain", "diaphoresis", "nausea"]),
            DifferentialDiagnosis(diagnosis: "Pulmonary Embolism", urgency: .emergent, workup: ["D-dimer", "CT PE", "Wells score"], redFlags: ["sudden onset", "pleuritic pain", "hypoxia"]),
            DifferentialDiagnosis(diagnosis: "CHF Exacerbation", urgency: .urgent, workup: ["BNP", "CXR", "Echo"], redFlags: ["orthopnea", "PND", "edema"]),
            DifferentialDiagnosis(diagnosis: "Pneumonia", urgency: .urgent, workup: ["CXR", "CBC", "Blood cultures"], redFlags: ["fever", "productive cough", "pleuritic pain"]),
            DifferentialDiagnosis(diagnosis: "Asthma/COPD Exacerbation", urgency: .urgent, workup: ["CXR", "ABG if severe"], redFlags: ["wheezing", "prolonged expiration"])
        ],

        // Altered Mental Status
        "altered mental status": [
            DifferentialDiagnosis(diagnosis: "Hypoglycemia", urgency: .emergent, workup: ["Fingerstick glucose"], redFlags: ["diabetes", "diaphoresis", "tachycardia"]),
            DifferentialDiagnosis(diagnosis: "Stroke/TIA", urgency: .emergent, workup: ["Non-contrast CT head", "Neurology consult"], redFlags: ["focal deficits", "sudden onset", "facial droop"]),
            DifferentialDiagnosis(diagnosis: "Sepsis", urgency: .emergent, workup: ["Blood cultures", "CBC", "Lactic acid"], redFlags: ["fever", "hypotension", "tachycardia"]),
            DifferentialDiagnosis(diagnosis: "Intracranial Hemorrhage", urgency: .emergent, workup: ["Non-contrast CT head"], redFlags: ["trauma", "anticoagulation", "severe headache"])
        ]
    ]

    // MARK: - Emergency Medicine Medications

    static let emergencyMedications: [String: MedicationInfo] = [
        // Cardiac
        "aspirin": MedicationInfo(class: "Antiplatelet", indication: "ACS, Stroke", dosing: "324mg PO (chewed)"),
        "nitroglycerin": MedicationInfo(class: "Nitrate", indication: "Chest pain, CHF", dosing: "0.4mg SL q5min x3"),
        "morphine": MedicationInfo(class: "Opioid", indication: "Pain, pulmonary edema", dosing: "2-4mg IV q5-15min"),
        "heparin": MedicationInfo(class: "Anticoagulant", indication: "ACS, PE", dosing: "Bolus 60 units/kg (max 4000)"),
        "lovenox": MedicationInfo(class: "LMWH", indication: "ACS, PE, DVT", dosing: "1mg/kg SC q12h"),
        "metoprolol": MedicationInfo(class: "Beta blocker", indication: "HTN, tachycardia, ACS", dosing: "5mg IV q5min x3 or 25-50mg PO"),

        // Respiratory
        "albuterol": MedicationInfo(class: "Beta agonist", indication: "Asthma, COPD", dosing: "2.5mg nebulized q20min x3"),
        "ipratropium": MedicationInfo(class: "Anticholinergic", indication: "COPD exacerbation", dosing: "0.5mg nebulized with albuterol"),
        "solumedrol": MedicationInfo(class: "Steroid", indication: "Asthma, COPD, anaphylaxis", dosing: "125mg IV"),
        "methylprednisolone": MedicationInfo(class: "Steroid", indication: "Asthma, COPD", dosing: "125mg IV"),

        // Neurologic
        "keppra": MedicationInfo(class: "Antiepileptic", indication: "Seizures", dosing: "1000-1500mg IV load"),
        "ativan": MedicationInfo(class: "Benzodiazepine", indication: "Seizures, agitation", dosing: "2-4mg IV/IM"),
        "lorazepam": MedicationInfo(class: "Benzodiazepine", indication: "Seizures, agitation", dosing: "2-4mg IV/IM"),
        "tpa": MedicationInfo(class: "Thrombolytic", indication: "Acute ischemic stroke", dosing: "0.9mg/kg IV (max 90mg)"),

        // Pain/Sedation
        "fentanyl": MedicationInfo(class: "Opioid", indication: "Severe pain", dosing: "50-100mcg IV q5min"),
        "dilaudid": MedicationInfo(class: "Opioid", indication: "Severe pain", dosing: "0.5-2mg IV q2-3h"),
        "hydromorphone": MedicationInfo(class: "Opioid", indication: "Severe pain", dosing: "0.5-2mg IV q2-3h"),
        "toradol": MedicationInfo(class: "NSAID", indication: "Pain", dosing: "15-30mg IV/IM"),
        "ketorolac": MedicationInfo(class: "NSAID", indication: "Pain", dosing: "15-30mg IV/IM"),

        // GI
        "zofran": MedicationInfo(class: "Antiemetic", indication: "Nausea/vomiting", dosing: "4-8mg IV/PO"),
        "ondansetron": MedicationInfo(class: "Antiemetic", indication: "Nausea/vomiting", dosing: "4-8mg IV/PO"),
        "reglan": MedicationInfo(class: "Antiemetic", indication: "Nausea, migraine", dosing: "10mg IV"),
        "metoclopramide": MedicationInfo(class: "Antiemetic", indication: "Nausea, migraine", dosing: "10mg IV"),

        // Antibiotics
        "vancomycin": MedicationInfo(class: "Antibiotic", indication: "MRSA coverage", dosing: "15-20mg/kg IV"),
        "rocephin": MedicationInfo(class: "Cephalosporin", indication: "Broad spectrum", dosing: "1-2g IV"),
        "ceftriaxone": MedicationInfo(class: "Cephalosporin", indication: "Broad spectrum", dosing: "1-2g IV"),
        "zosyn": MedicationInfo(class: "Beta-lactam", indication: "Broad spectrum", dosing: "3.375-4.5g IV q6h"),
        "levaquin": MedicationInfo(class: "Fluoroquinolone", indication: "Pneumonia, UTI", dosing: "500-750mg IV/PO"),

        // Resuscitation
        "epinephrine": MedicationInfo(class: "Vasopressor", indication: "Anaphylaxis, cardiac arrest", dosing: "0.3-0.5mg IM (anaphylaxis), 1mg IV (ACLS)"),
        "narcan": MedicationInfo(class: "Opioid antagonist", indication: "Opioid overdose", dosing: "0.4-2mg IN/IV/IM"),
        "naloxone": MedicationInfo(class: "Opioid antagonist", indication: "Opioid overdose", dosing: "0.4-2mg IN/IV/IM"),
        "dextrose": MedicationInfo(class: "Sugar", indication: "Hypoglycemia", dosing: "25-50g IV (D50)"),
        "calcium": MedicationInfo(class: "Electrolyte", indication: "Hyperkalemia, hypocalcemia", dosing: "1g calcium chloride IV")
    ]

    // MARK: - Common EM Abbreviations

    static let commonEMAbbreviations: [String: String] = [
        "sob": "shortness of breath",
        "cp": "chest pain",
        "abd": "abdominal",
        "n/v": "nausea and vomiting",
        "loc": "loss of consciousness",
        "ams": "altered mental status",
        "h/o": "history of",
        "s/p": "status post",
        "rlq": "right lower quadrant",
        "llq": "left lower quadrant",
        "ruq": "right upper quadrant",
        "luq": "left upper quadrant",
        "pnd": "paroxysmal nocturnal dyspnea"
    ]

    // MARK: - Clinical Decision Tools

    static func recommendClinicalTools(for symptoms: [String], entities: MedicalEntities) -> [ClinicalTool] {
        var tools: [ClinicalTool] = []

        let symptomsLower = symptoms.map { $0.lowercased() }

        // Chest pain tools
        if symptomsLower.contains(where: { $0.contains("chest") || $0.contains("pain") }) {
            tools.append(ClinicalTool(
                name: "HEART Score",
                purpose: "Risk stratify chest pain for ACS",
                components: ["History", "EKG", "Age", "Risk factors", "Troponin"],
                interpretation: "0-3: Low risk, 4-6: Moderate, ≥7: High risk"
            ))
            tools.append(ClinicalTool(
                name: "TIMI Score",
                purpose: "Risk stratify ACS",
                components: ["Age ≥65", "≥3 CAD risk factors", "Known CAD", "ASA use", "Severe angina", "↑Cardiac markers", "ST deviation"],
                interpretation: "Score 0-7, higher = increased risk"
            ))
        }

        // PE tools
        if symptomsLower.contains(where: { $0.contains("breath") || $0.contains("dyspnea") }) {
            tools.append(ClinicalTool(
                name: "Wells Criteria (PE)",
                purpose: "Probability of pulmonary embolism",
                components: ["Clinical signs of DVT", "PE most likely diagnosis", "HR >100", "Immobilization", "Previous DVT/PE", "Hemoptysis", "Malignancy"],
                interpretation: "<2: Low risk, 2-6: Moderate, >6: High risk"
            ))
            tools.append(ClinicalTool(
                name: "PERC Rule",
                purpose: "Rule out PE without testing",
                components: ["Age <50", "HR <100", "O2 sat ≥95%", "No hemoptysis", "No estrogen", "No surgery/trauma", "No prior DVT/PE", "No unilateral leg swelling"],
                interpretation: "All negative = PE very unlikely"
            ))
        }

        // Stroke tools
        if symptomsLower.contains(where: { $0.contains("weakness") || $0.contains("stroke") || $0.contains("altered") }) {
            tools.append(ClinicalTool(
                name: "NIHSS",
                purpose: "Stroke severity assessment",
                components: ["LOC", "Gaze", "Visual fields", "Facial palsy", "Motor arm/leg", "Ataxia", "Sensory", "Language", "Dysarthria", "Extinction"],
                interpretation: "0: No stroke, 1-4: Minor, 5-15: Moderate, >15: Severe"
            ))
        }

        // Pneumonia tools
        if symptomsLower.contains(where: { $0.contains("cough") || $0.contains("pneumonia") }) {
            tools.append(ClinicalTool(
                name: "CURB-65",
                purpose: "Pneumonia severity",
                components: ["Confusion", "Urea >20mg/dL", "RR ≥30", "BP <90/60", "Age ≥65"],
                interpretation: "0-1: Outpatient, 2: Consider admission, 3-5: ICU"
            ))
        }

        // Appendicitis
        if symptomsLower.contains(where: { $0.contains("abdominal") || $0.contains("abd") }) {
            tools.append(ClinicalTool(
                name: "Alvarado Score",
                purpose: "Appendicitis likelihood",
                components: ["Migration of pain", "Anorexia", "Nausea/vomiting", "RLQ tenderness", "Rebound", "Fever", "Leukocytosis", "Left shift"],
                interpretation: "0-4: Unlikely, 5-6: Possible, 7-10: Probable"
            ))
        }

        return tools
    }
}

// MARK: - Supporting Types

struct DifferentialDiagnosis {
    let diagnosis: String
    let urgency: DiagnosisUrgency
    let workup: [String]
    let redFlags: [String]
}

enum DiagnosisUrgency {
    case emergent  // Life-threatening, immediate intervention
    case urgent    // Needs rapid evaluation
    case nonUrgent // Can be evaluated routinely

    var displayText: String {
        switch self {
        case .emergent: return "🔴 EMERGENT"
        case .urgent: return "🟡 URGENT"
        case .nonUrgent: return "🟢 NON-URGENT"
        }
    }
}

struct MedicationInfo {
    let `class`: String
    let indication: String
    let dosing: String
}

struct ClinicalTool {
    let name: String
    let purpose: String
    let components: [String]
    let interpretation: String
}