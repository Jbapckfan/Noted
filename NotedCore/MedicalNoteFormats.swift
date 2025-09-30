import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Structured Medical Note Formats for Apple Intelligence

#if canImport(FoundationModels)
@available(iOS 18.0, macOS 15.0, *)

// MARK: - SOAP Note Format
// @Generable - Disabled for iOS compatibility
struct SOAPNote {
    // @Guide("Patient's reported symptoms, complaints, and history as told by them")
    let subjective: SubjectiveSection
    
    // @Guide("Observable and measurable findings from physical examination and tests")
    let objective: ObjectiveSection
    
    // @Guide("Clinical judgment about the diagnosis or differential diagnoses")
    let assessment: AssessmentSection
    
    // @Guide("Treatment plan including medications, tests, referrals, and follow-up")
    let plan: PlanSection
}

// @Generable - Disabled for iOS compatibility
struct SubjectiveSection {
    // @Guide("Primary reason for visit in patient's words")
    let chiefComplaint: String
    
    // @Guide("Detailed history of the presenting illness including onset, duration, quality")
    let historyOfPresentIllness: String
    
    // @Guide("Relevant past medical conditions")
    let pastMedicalHistory: [String]
    
    // @Guide("Current medications with dosages")
    let medications: [Medication]
    
    // @Guide("Known drug allergies")
    let allergies: [String]
    
    // @Guide("Pain level from 0-10 if applicable")
    let painScale: Int?
}

// @Generable - Disabled for iOS compatibility
struct ObjectiveSection {
    // @Guide("Blood pressure, heart rate, temperature, respiratory rate, oxygen saturation")
    let vitalSigns: VitalSigns
    
    // @Guide("Physical examination findings by body system")
    let physicalExam: [PhysicalExamFinding]
    
    // @Guide("Laboratory test results if available")
    let labResults: [LabResult]?
    
    // @Guide("Imaging findings if available")
    let imagingResults: [String]?
}

// @Generable - Disabled for iOS compatibility
struct AssessmentSection {
    // @Guide("Primary diagnosis or working diagnosis")
    let primaryDiagnosis: String
    
    // @Guide("Alternative diagnoses being considered")
    let differentialDiagnoses: [String]
    
    // @Guide("Clinical reasoning for the diagnosis")
    let clinicalReasoning: String
    
    // @Guide("Risk stratification (low, moderate, high)")
    let riskLevel: RiskLevel
}

// @Generable - Disabled for iOS compatibility
struct PlanSection {
    // @Guide("Medications prescribed or changed")
    let medications: [MedicationPlan]
    
    // @Guide("Diagnostic tests ordered")
    let diagnosticTests: [String]
    
    // @Guide("Referrals to specialists")
    let referrals: [String]
    
    // @Guide("Follow-up instructions and timeline")
    let followUp: String
    
    // @Guide("Patient education provided")
    let patientEducation: [String]
    
    // @Guide("Disposition (admit, discharge, observe)")
    let disposition: Disposition
}

// MARK: - Supporting Types

// Commented out - using Medication from MedicalTypes.swift instead
/*
// @Generable - Disabled for iOS compatibility
struct Medication {
    let name: String
    let dosage: String
    let frequency: String
}
*/

// // @Generable - Disabled for iOS compatibility - Disabled for iOS compatibility
// Commented out - using VitalSigns from MedicalTypes.swift instead
/*
struct VitalSigns: Codable {
    // @Guide("Systolic/Diastolic in mmHg")
    let bloodPressure: String
    
    // @Guide("Beats per minute")
    let heartRate: Int
    
    // @Guide("Degrees Fahrenheit")
    let temperature: Double
    
    // @Guide("Breaths per minute")
    let respiratoryRate: Int
}
*/

// @Generable - Disabled for iOS compatibility
struct PhysicalExamFinding {
    let system: String
    let finding: String
    let abnormal: Bool
}

// @Generable - Disabled for iOS compatibility
struct LabResult {
    let testName: String
    let value: String
    let units: String
    let isAbnormal: Bool
}

// @Generable - Disabled for iOS compatibility
struct MedicationPlan {
    let medication: String
    let dosage: String
    let route: String
    let frequency: String
    let duration: String
}

// @Generable - Disabled for iOS compatibility
enum RiskLevel: String {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case critical = "Critical"
}

// @Generable - Disabled for iOS compatibility
enum Disposition: String {
    case discharge = "Discharge home"
    case admit = "Admit to hospital"
    case observe = "Observation"
    case transfer = "Transfer to higher care"
    case ama = "Left against medical advice"
}

// MARK: - Emergency Department Note Format

// @Generable - Disabled for iOS compatibility
struct EDNote {
    // @Guide("Time of arrival and mode of transport")
    let arrival: ArrivalInfo
    
    // @Guide("Triage assessment and category")
    let triage: TriageAssessment
    
    // @Guide("Chief complaint and HPI")
    let presentation: PresentationInfo
    
    // @Guide("Medical decision making process")
    let mdm: MedicalDecisionMaking
    
    // @Guide("Procedures performed")
    let procedures: [Procedure]
    
    // @Guide("Final disposition and instructions")
    let disposition: EDDisposition
}

// @Generable - Disabled for iOS compatibility
struct ArrivalInfo {
    let arrivalTime: String
    let modeOfArrival: String // EMS, Walk-in, Private vehicle
    let triageTime: String
}

// @Generable - Disabled for iOS compatibility
struct TriageAssessment {
    // @Guide("ESI level 1-5")
    let esiLevel: Int
    
    let vitalSigns: VitalSigns
    let chiefComplaint: String
}

// @Generable - Disabled for iOS compatibility
struct PresentationInfo {
    let historyOfPresentIllness: String
    let reviewOfSystems: [String]
    let pertinentNegatives: [String]
}

// @Generable - Disabled for iOS compatibility
struct MedicalDecisionMaking {
    let differentialDiagnosis: [String]
    let workupPerformed: [String]
    let resultsInterpretation: String
    let riskStratification: String
}

// @Generable - Disabled for iOS compatibility
struct Procedure {
    let name: String
    let indication: String
    let performedBy: String
    let complications: String?
}

// @Generable - Disabled for iOS compatibility
struct EDDisposition {
    let decision: Disposition
    let admittingService: String?
    let dischargeInstructions: [String]
    let followUpPlan: String
    let returnPrecautions: [String]
}

// MARK: - Progress Note Format

// @Generable - Disabled for iOS compatibility
struct ProgressNote {
    // @Guide("Time period since last note")
    let interval: String
    
    // @Guide("Significant events in the interval")
    let events: [String]
    
    // @Guide("Current patient status")
    let currentStatus: PatientStatus
    
    // @Guide("Updated assessment")
    let assessment: String
    
    // @Guide("Modified or continued plan")
    let plan: [String]
}

// @Generable - Disabled for iOS compatibility
// Commented out - using PatientStatus from ClinicalModels.swift
/*
struct PatientStatus {
    let condition: String
    let trend: String
    let lastAssessment: Date
}
*/

// @Generable - Disabled for iOS compatibility
struct SymptomStatus {
    let symptom: String
    let trend: String // Resolved, Improving, Unchanged, Worsening
}

// MARK: - Procedure Note Format

// @Generable - Disabled for iOS compatibility
struct ProcedureNote {
    // @Guide("Procedure performed")
    let procedureName: String
    
    // @Guide("Clinical indication")
    let indication: String
    
    // @Guide("Patient consent documentation")
    let consent: ConsentInfo
    
    // @Guide("Step-by-step procedure description")
    let technique: [String]
    
    // @Guide("Findings during procedure")
    let findings: [String]
    
    // @Guide("Any complications")
    let complications: String?
    
    // @Guide("Post-procedure care")
    let postProcedureCare: [String]
}

// @Generable - Disabled for iOS compatibility
struct ConsentInfo {
    let risks: [String]
    let benefits: [String]
    let alternatives: [String]
    let questionsAnswered: Bool
}

#endif

// MARK: - Training Examples for Better Formatting

struct MedicalNoteExamples {
    static let soapExamples = [
        """
        SUBJECTIVE:
        Chief Complaint: Chest pain x 3 hours
        HPI: 58-year-old female presents with substernal chest pressure that began 3 hours ago while climbing stairs. Pain is 7/10, pressure-like quality, non-radiating. Took Tylenol without relief.
        PMH: Hypertension, Type 2 Diabetes
        Medications: Lisinopril 10mg daily, Metformin 1000mg BID
        Allergies: NKDA
        
        OBJECTIVE:
        Vitals: BP 165/95, HR 92, T 98.6°F, RR 18, SpO2 97% RA
        Physical Exam:
        - General: Alert, uncomfortable appearing
        - Cardiac: RRR, no murmurs/rubs/gallops
        - Lungs: Clear to auscultation bilaterally
        - Extremities: No edema
        
        ASSESSMENT:
        Acute coronary syndrome vs unstable angina. High risk given diabetes, hypertension, and typical anginal symptoms.
        
        PLAN:
        1. EKG stat
        2. Troponin, CBC, BMP, lipid panel
        3. Aspirin 325mg PO x1
        4. Cardiology consult
        5. NPO pending possible cardiac catheterization
        """,
        
        """
        SUBJECTIVE:
        Chief Complaint: Lower back pain
        HPI: 45-year-old male with acute onset severe lower back pain after lifting boxes yesterday. Sharp pain radiating to left leg, 8/10 severity. Ibuprofen provides minimal relief.
        PMH: Hypertension
        Medications: Amlodipine 5mg daily
        
        OBJECTIVE:
        Vitals: BP 140/88, HR 78, afebrile
        Physical Exam:
        - Back: Tenderness over L4-L5, positive SLR left at 30°
        - Neuro: Strength 5/5, DTRs 2+ symmetric
        
        ASSESSMENT:
        Likely L4-L5 disc herniation with radiculopathy
        
        PLAN:
        1. Cyclobenzaprine 10mg TID
        2. Continue NSAIDs
        3. Physical therapy referral
        4. MRI if no improvement in 2 weeks
        5. Light duty work note provided
        """
    ]
    
    static let edExamples = [
        """
        EMERGENCY DEPARTMENT NOTE
        
        Arrival: 14:32 via EMS
        Triage: ESI Level 2 at 14:35
        
        Chief Complaint: Chest pain
        
        HPI: 58F with HTN, DM presents with 3 hours of substernal chest pressure. Started with exertion, now at rest. Associated with dyspnea. Denies N/V, diaphoresis.
        
        MDM: Differential includes ACS, PE, aortic dissection. High risk given multiple cardiac risk factors.
        
        Procedures: None
        
        Workup: EKG shows NSR without acute changes. Initial troponin negative. CXR clear.
        
        Disposition: Admit to cardiology for serial enzymes and stress testing
        Return precautions: Worsening chest pain, shortness of breath
        """
    ]
}

// MARK: - Format Trainer

class MedicalNoteFormatTrainer {
    
    // FoundationModels not available - commented out for compatibility
    /*
    #if canImport(FoundationModels)
    @available(iOS 18.0, macOS 15.0, *)
    static func generateFormattedNote<T: Decodable>(
        transcription: String,
        format: T.Type,
        examples: [String] = []
    ) async throws -> T {
        let model = try await FoundationModel()
        
        // Build prompt with examples (few-shot learning)
        var prompt = """
        Convert the following medical transcription into a structured note.
        
        """
        
        if !examples.isEmpty {
            prompt += "Here are examples of properly formatted notes:

"
            for example in examples.prefix(2) {
                prompt += example + "

---

"
            }
        }
        
        prompt += """
        Now, structure this transcription:
        
        \(transcription)
        
        Focus on medical accuracy and completeness.
        """
        
        // Use guided generation with the structured type
        return try await model.generate(
            prompt: prompt,
            maxTokens: 800,
            temperature: 0.3,
            guidedGeneration: .structured(format)
        )
    }
    #endif
    */
    
    // Custom prompts for specific formats
    static func getFormatPrompt(for noteType: String) -> String {
        switch noteType {
        case "SOAP":
            return """
            Structure as SOAP note with:
            - Subjective: Patient's story and symptoms
            - Objective: Measurable findings and exam
            - Assessment: Clinical judgment and diagnosis
            - Plan: Treatment and follow-up
            """
            
        case "ED":
            return """
            Structure as Emergency Department note with:
            - Arrival and triage information
            - Chief complaint and HPI
            - Medical decision making
            - Procedures and workup
            - Disposition and instructions
            """
            
        case "Progress":
            return """
            Structure as Progress note with:
            - Interval events since last note
            - Current status and symptom trends
            - Updated assessment
            - Modified or continued plan
            """
            
        default:
            return "Structure as a clear, organized medical note"
        }
    }
}