import Foundation
import SwiftUI

/// Clinical Alert Engine for red flags and contraindications
/// Provides real-time alerts for critical conditions and drug interactions
class ClinicalAlertEngine: ObservableObject {
    
    @Published var activeAlerts: [ClinicalAlert] = []
    @Published var alertHistory: [ClinicalAlert] = []
    
    // MARK: - Alert Types
    
    enum AlertType {
        case redFlag           // Life-threatening conditions
        case contraindication  // Drug interactions, allergies
        case documentation     // Missing critical documentation
        case malpractice      // Liability risks
        
        var color: Color {
            switch self {
            case .redFlag: return .red
            case .contraindication: return .orange
            case .documentation: return .yellow
            case .malpractice: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .redFlag: return "exclamationmark.triangle.fill"
            case .contraindication: return "pills.circle.fill"
            case .documentation: return "doc.text.fill"
            case .malpractice: return "shield.slash.fill"
            }
        }
    }
    
    enum Severity: Int, Comparable {
        case low = 1
        case medium = 2
        case high = 3
        case critical = 4
        
        static func < (lhs: Severity, rhs: Severity) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
    }
    

    
    // MARK: - Documentation and Billing Alerts Only
    
    // Focus on documentation quality and billing optimization, not medical diagnosis
    
    // MARK: - Drug Interaction Database
    
    struct DrugInteraction {
        let drug1: String
        let drug2: String
        let severity: Severity
        let effect: String
        let recommendation: String
    }
    
    static let drugInteractionDatabase: [DrugInteraction] = [
        DrugInteraction(
            drug1: "warfarin",
            drug2: "aspirin",
            severity: .high,
            effect: "Increased bleeding risk",
            recommendation: "Monitor INR closely, consider PPI for GI protection"
        ),
        DrugInteraction(
            drug1: "metformin",
            drug2: "contrast",
            severity: .medium,
            effect: "Risk of lactic acidosis",
            recommendation: "Hold metformin 48 hours before and after contrast"
        ),
        DrugInteraction(
            drug1: "ssri",
            drug2: "tramadol",
            severity: .high,
            effect: "Serotonin syndrome risk",
            recommendation: "Avoid combination or monitor closely for symptoms"
        ),
        DrugInteraction(
            drug1: "ace inhibitor",
            drug2: "potassium",
            severity: .medium,
            effect: "Hyperkalemia risk",
            recommendation: "Monitor potassium levels regularly"
        ),
        DrugInteraction(
            drug1: "statin",
            drug2: "clarithromycin",
            severity: .high,
            effect: "Rhabdomyolysis risk",
            recommendation: "Hold statin during antibiotic course"
        )
    ]
    
    // MARK: - Allergy Database
    
    struct AllergyAlert {
        let allergen: String
        let alternativeClasses: [String]
        let crossReactivity: [String]
        let severity: Severity
    }
    
    static let allergyDatabase: [AllergyAlert] = [
        AllergyAlert(
            allergen: "penicillin",
            alternativeClasses: ["cephalosporin", "beta-lactam"],
            crossReactivity: ["amoxicillin", "ampicillin", "cephalexin"],
            severity: .high
        ),
        AllergyAlert(
            allergen: "sulfa",
            alternativeClasses: ["sulfonamide"],
            crossReactivity: ["bactrim", "sulfamethoxazole"],
            severity: .medium
        ),
        AllergyAlert(
            allergen: "nsaid",
            alternativeClasses: ["cox inhibitor"],
            crossReactivity: ["ibuprofen", "naproxen", "ketorolac"],
            severity: .medium
        )
    ]
    
    // MARK: - Core Analysis Functions
    
    /// Analyze transcription for clinical alerts
    static func analyzeForAlerts(transcription: String, patientContext: PatientContext? = nil) -> [ClinicalAlert] {
        var alerts = [ClinicalAlert]()
        let lower = transcription.lowercased()
        
        // Only check if alerts are enabled
        let appState = CoreAppState.shared
        
        // 1. Check for contraindications (if enabled)
        if appState.isContraindicationAlertsEnabled {
            let medications = extractMedications(from: transcription)
            
            // Check drug interactions
            for interaction in drugInteractionDatabase {
                let hasDrug1 = medications.contains { $0.lowercased().contains(interaction.drug1) }
                let hasDrug2 = medications.contains { $0.lowercased().contains(interaction.drug2) }
                
                if hasDrug1 && hasDrug2 {
                    alerts.append(ClinicalAlert(
                        type: .contraindication,
                        severity: interaction.severity,
                        title: "💊 DRUG INTERACTION",
                        message: "\(interaction.drug1.capitalized) + \(interaction.drug2.capitalized): \(interaction.effect)",
                        recommendation: interaction.recommendation,
                        requiresAcknowledgment: interaction.severity >= .high,
                        clinicalContext: nil
                    ))
                }
            }
            
            // Check allergies
            if let allergies = patientContext?.allergies {
                for allergy in allergies {
                    for allergyAlert in allergyDatabase {
                        if allergy.lowercased().contains(allergyAlert.allergen) {
                            for medication in medications {
                                if allergyAlert.crossReactivity.contains(where: { medication.lowercased().contains($0) }) {
                                    alerts.append(ClinicalAlert(
                                        type: .contraindication,
                                        severity: allergyAlert.severity,
                                        title: "🚫 ALLERGY ALERT",
                                        message: "Patient allergic to \(allergyAlert.allergen). Prescribed \(medication) has cross-reactivity!",
                                        recommendation: "STOP medication. Consider alternatives not in \(allergyAlert.alternativeClasses.joined(separator: ", ")) class",
                                        requiresAcknowledgment: true,
                                        clinicalContext: nil
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 3. Check for documentation issues (if enabled)
        if appState.clinicalAlertPreferences.showMissingDocumentation {
            let documentationIssues = checkDocumentation(transcription)
            alerts.append(contentsOf: documentationIssues)
        }
        
        // 4. Check for malpractice risks (if enabled)
        if appState.clinicalAlertPreferences.showMalpracticeRisks {
            let malpracticeRisks = checkMalpracticeRisks(transcription)
            alerts.append(contentsOf: malpracticeRisks)
        }
        
        // Sort by severity
        return alerts.sorted { $0.severity > $1.severity }
    }
    
    // MARK: - Helper Functions
    
    static func extractMedications(from text: String) -> [String] {
        var medications = [String]()
        
        // Common medication patterns
        let patterns = [
            #"(\w+)\s+\d+\s*mg"#,  // "aspirin 325mg"
            #"(\w+)\s+\d+\s*mcg"#, // "levothyroxine 50mcg"
            #"(\w+)\s+\d+\s*units"# // "insulin 10 units"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        medications.append(String(text[range]))
                    }
                }
            }
        }
        
        return medications
    }
    
    struct ClinicalContext {
        let relatedDiagnoses: [String]
        let relatedMedications: [String]
        let vitalSigns: [String: String]
        let labValues: [String: String]
    }
    
    static func extractContext(from text: String) -> ClinicalContext {
        // Extract vital signs
        var vitals = [String: String]()
        if let bpMatch = text.range(of: #"\d{2,3}/\d{2,3}"#, options: .regularExpression) {
            vitals["BP"] = String(text[bpMatch])
        }
        if let hrMatch = text.range(of: #"hr\s*\d{2,3}|heart rate\s*\d{2,3}"#, options: [.regularExpression, .caseInsensitive]) {
            let hr = String(text[hrMatch])
            vitals["HR"] = hr.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }
        
        return ClinicalContext(
            relatedDiagnoses: [],
            relatedMedications: extractMedications(from: text),
            vitalSigns: vitals,
            labValues: [:]
        )
    }
    
    static func checkDocumentation(_ text: String) -> [ClinicalAlert] {
        var alerts = [ClinicalAlert]()
        let lower = text.lowercased()
        
        // Check for missing informed consent
        if lower.contains("procedure") && !lower.contains("consent") {
            alerts.append(ClinicalAlert(
                type: .documentation,
                severity: .medium,
                title: "📝 Missing Informed Consent",
                message: "Procedure mentioned without documented consent",
                recommendation: "Document informed consent including risks, benefits, alternatives",
                requiresAcknowledgment: false,
                clinicalContext: nil
            ))
        }
        
        // Check for missing allergy review
        if lower.contains("medication") && !lower.contains("allerg") {
            alerts.append(ClinicalAlert(
                type: .documentation,
                severity: .low,
                title: "📝 Missing Allergy Review",
                message: "Medications prescribed without allergy documentation",
                recommendation: "Document allergy review: NKDA or specific allergies",
                requiresAcknowledgment: false,
                clinicalContext: nil
            ))
        }
        
        return alerts
    }
    
    static func checkMalpracticeRisks(_ text: String) -> [ClinicalAlert] {
        var alerts = [ClinicalAlert]()
        let lower = text.lowercased()
        
        // Check for high-risk scenarios without proper documentation
        if lower.contains("chest pain") && !lower.contains("ekg") && !lower.contains("ecg") {
            alerts.append(ClinicalAlert(
                type: .malpractice,
                severity: .high,
                title: "⚖️ Malpractice Risk",
                message: "Chest pain without documented EKG",
                recommendation: "Document EKG results or reason for deferral",
                requiresAcknowledgment: true,
                clinicalContext: nil
            ))
        }
        
        if lower.contains("head injury") && !lower.contains("ct") && !lower.contains("neurological exam") {
            alerts.append(ClinicalAlert(
                type: .malpractice,
                severity: .medium,
                title: "⚖️ Documentation Gap",
                message: "Head injury without imaging or neuro exam documentation",
                recommendation: "Document neurological exam and clinical decision-making for imaging",
                requiresAcknowledgment: false,
                clinicalContext: nil
            ))
        }
        
        return alerts
    }
}

