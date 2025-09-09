import Foundation

/// Generates differential diagnoses based on presenting symptoms
class DifferentialDiagnosisGenerator {
    
    struct DifferentialDiagnosis {
        let condition: String
        let icd10Code: String
        let probability: String // High, Medium, Low
        let supportingFeatures: [String]
        let redFlags: [String]
        let workup: [String] // Suggested tests
    }
    
    /// Common chief complaint to differential diagnosis mapping
    static let differentialDatabase: [String: [DifferentialDiagnosis]] = [
        
        // Abdominal Pain Differentials
        "abdominal pain": [
            DifferentialDiagnosis(
                condition: "Acute appendicitis",
                icd10Code: "K35.80",
                probability: "High",
                supportingFeatures: ["RLQ pain", "Migration from periumbilical", "Fever", "Anorexia", "Rebound tenderness"],
                redFlags: ["Rigidity", "Hypotension", "Tachycardia"],
                workup: ["CBC with differential", "CMP", "Urinalysis", "CT abdomen/pelvis", "Pregnancy test (if applicable)"]
            ),
            DifferentialDiagnosis(
                condition: "Gastroenteritis",
                icd10Code: "K52.9",
                probability: "Medium",
                supportingFeatures: ["Nausea/vomiting", "Diarrhea", "Diffuse cramping", "Recent sick contacts"],
                redFlags: ["Blood in stool", "Severe dehydration", "High fever"],
                workup: ["CBC", "BMP", "Stool studies if indicated"]
            ),
            DifferentialDiagnosis(
                condition: "Urinary tract infection",
                icd10Code: "N39.0",
                probability: "Medium",
                supportingFeatures: ["Dysuria", "Frequency", "Suprapubic tenderness", "Hematuria"],
                redFlags: ["Flank pain", "High fever", "Altered mental status"],
                workup: ["Urinalysis", "Urine culture", "CBC if systemic symptoms"]
            ),
            DifferentialDiagnosis(
                condition: "Kidney stone",
                icd10Code: "N20.0",
                probability: "Low",
                supportingFeatures: ["Colicky pain", "Flank pain", "Hematuria", "Unable to find comfortable position"],
                redFlags: ["Fever", "Anuria", "Bilateral pain"],
                workup: ["Urinalysis", "BMP", "CT abdomen/pelvis without contrast"]
            )
        ],
        
        // Chest Pain Differentials
        "chest pain": [
            DifferentialDiagnosis(
                condition: "Acute coronary syndrome",
                icd10Code: "I20.9",
                probability: "High",
                supportingFeatures: ["Crushing/pressure", "Radiation to jaw/arm", "Diaphoresis", "Dyspnea", "Risk factors"],
                redFlags: ["ST elevation", "Troponin elevation", "Hypotension", "New murmur"],
                workup: ["ECG", "Troponin", "CXR", "CBC", "BMP", "PT/INR"]
            ),
            DifferentialDiagnosis(
                condition: "Pulmonary embolism",
                icd10Code: "I26.99",
                probability: "Medium",
                supportingFeatures: ["Pleuritic pain", "Dyspnea", "Tachycardia", "Risk factors (immobility, OCP, cancer)"],
                redFlags: ["Hypoxia", "Hemoptysis", "Hypotension", "Right heart strain"],
                workup: ["D-dimer", "CTA chest", "ECG", "Troponin", "BNP"]
            ),
            DifferentialDiagnosis(
                condition: "Gastroesophageal reflux",
                icd10Code: "K21.9",
                probability: "Medium",
                supportingFeatures: ["Burning", "Post-prandial", "Relief with antacids", "Sour taste"],
                redFlags: ["Weight loss", "Dysphagia", "Anemia"],
                workup: ["ECG to rule out cardiac", "Consider GI cocktail trial"]
            ),
            DifferentialDiagnosis(
                condition: "Costochondritis",
                icd10Code: "M94.0",
                probability: "Low",
                supportingFeatures: ["Reproducible with palpation", "Sharp pain", "Movement-related", "Recent URI or exercise"],
                redFlags: ["Fever", "Trauma history"],
                workup: ["ECG to rule out cardiac", "CXR if respiratory symptoms"]
            )
        ],
        
        // Headache Differentials
        "headache": [
            DifferentialDiagnosis(
                condition: "Migraine",
                icd10Code: "G43.909",
                probability: "High",
                supportingFeatures: ["Unilateral", "Pulsating", "Photophobia", "Phonophobia", "Nausea", "Aura"],
                redFlags: ["Thunderclap onset", "Fever", "Neurological deficits", "Papilledema"],
                workup: ["Neurological exam", "Consider CT/MRI if red flags"]
            ),
            DifferentialDiagnosis(
                condition: "Tension headache",
                icd10Code: "G44.209",
                probability: "High",
                supportingFeatures: ["Bilateral", "Band-like", "Pressure", "Stress-related", "Neck tension"],
                redFlags: ["Sudden onset", "Worst headache of life", "Fever"],
                workup: ["Clinical diagnosis", "Neurological exam"]
            ),
            DifferentialDiagnosis(
                condition: "Subarachnoid hemorrhage",
                icd10Code: "I60.9",
                probability: "Low",
                supportingFeatures: ["Thunderclap onset", "Worst headache of life", "Neck stiffness", "LOC", "Nausea/vomiting"],
                redFlags: ["Neurological deficits", "Altered mental status", "Seizure"],
                workup: ["CT head without contrast", "LP if CT negative", "CTA if SAH confirmed"]
            ),
            DifferentialDiagnosis(
                condition: "Meningitis",
                icd10Code: "G03.9",
                probability: "Low",
                supportingFeatures: ["Fever", "Neck stiffness", "Photophobia", "Altered mental status", "Rash"],
                redFlags: ["Petechial rash", "Hypotension", "Seizures"],
                workup: ["CBC", "Blood cultures", "LP", "CT head before LP if indicated"]
            )
        ],
        
        // Shortness of Breath Differentials
        "shortness of breath": [
            DifferentialDiagnosis(
                condition: "Pneumonia",
                icd10Code: "J18.9",
                probability: "High",
                supportingFeatures: ["Fever", "Productive cough", "Pleuritic pain", "Crackles on exam"],
                redFlags: ["Hypoxia", "Hypotension", "Altered mental status"],
                workup: ["CXR", "CBC", "BMP", "Blood cultures if severe", "Procalcitonin"]
            ),
            DifferentialDiagnosis(
                condition: "Congestive heart failure exacerbation",
                icd10Code: "I50.9",
                probability: "Medium",
                supportingFeatures: ["Orthopnea", "PND", "Lower extremity edema", "Weight gain", "JVD"],
                redFlags: ["Hypotension", "Altered mental status", "Pink frothy sputum"],
                workup: ["CXR", "BNP", "Troponin", "ECG", "Echo if new diagnosis"]
            ),
            DifferentialDiagnosis(
                condition: "Asthma exacerbation",
                icd10Code: "J45.901",
                probability: "Medium",
                supportingFeatures: ["Wheezing", "Trigger exposure", "Previous asthma history", "Response to bronchodilators"],
                redFlags: ["Silent chest", "Cyanosis", "Altered mental status", "Exhaustion"],
                workup: ["Peak flow", "CXR", "ABG if severe"]
            ),
            DifferentialDiagnosis(
                condition: "Pulmonary embolism",
                icd10Code: "I26.99",
                probability: "Low",
                supportingFeatures: ["Pleuritic pain", "Tachycardia", "Risk factors", "Hemoptysis"],
                redFlags: ["Hypoxia", "Hypotension", "Right heart strain"],
                workup: ["D-dimer", "CTA chest", "V/Q scan if contraindication to CTA"]
            )
        ]
    ]
    
    /// Generate differential diagnosis based on chief complaint and symptoms
    static func generateDifferential(
        chiefComplaint: String,
        symptoms: [String],
        vitalSigns: [String: String]? = nil
    ) -> [DifferentialDiagnosis] {
        
        // Normalize chief complaint
        let normalizedComplaint = chiefComplaint.lowercased()
        
        // Get base differentials for chief complaint
        var differentials = differentialDatabase[normalizedComplaint] ?? []
        
        // If no exact match, try to find partial matches
        if differentials.isEmpty {
            for (key, value) in differentialDatabase {
                if normalizedComplaint.contains(key) || key.contains(normalizedComplaint) {
                    differentials.append(contentsOf: value)
                    break
                }
            }
        }
        
        // Adjust probabilities based on presenting symptoms
        differentials = adjustProbabilities(differentials: differentials, presentingSymptoms: symptoms)
        
        // Sort by probability (High > Medium > Low)
        differentials.sort { diff1, diff2 in
            let order = ["High": 3, "Medium": 2, "Low": 1]
            return (order[diff1.probability] ?? 0) > (order[diff2.probability] ?? 0)
        }
        
        return differentials
    }
    
    /// Adjust differential probabilities based on symptoms present
    private static func adjustProbabilities(
        differentials: [DifferentialDiagnosis],
        presentingSymptoms: [String]
    ) -> [DifferentialDiagnosis] {
        
        return differentials.map { diff in
            var matchCount = 0
            let symptomsLower = presentingSymptoms.map { $0.lowercased() }
            
            // Count matching supporting features
            for feature in diff.supportingFeatures {
                for symptom in symptomsLower {
                    if symptom.contains(feature.lowercased()) || feature.lowercased().contains(symptom) {
                        matchCount += 1
                        break
                    }
                }
            }
            
            // Adjust probability based on match count
            let adjustedProbability: String
            if matchCount >= 3 {
                adjustedProbability = "High"
            } else if matchCount >= 2 {
                adjustedProbability = diff.probability == "Low" ? "Medium" : diff.probability
            } else {
                adjustedProbability = diff.probability
            }
            
            return DifferentialDiagnosis(
                condition: diff.condition,
                icd10Code: diff.icd10Code,
                probability: adjustedProbability,
                supportingFeatures: diff.supportingFeatures,
                redFlags: diff.redFlags,
                workup: diff.workup
            )
        }
    }
    
    /// Format differential diagnosis for clinical note
    static func formatDifferentialForNote(_ differentials: [DifferentialDiagnosis]) -> String {
        guard !differentials.isEmpty else {
            return "Differential diagnosis pending further evaluation"
        }
        
        var formattedDiff = "**DIFFERENTIAL DIAGNOSIS:**\n\n"
        
        for (index, diff) in differentials.enumerated() {
            formattedDiff += "\(index + 1). \(diff.condition) (ICD-10: \(diff.icd10Code))\n"
            formattedDiff += "   - Clinical probability: \(diff.probability)\n"
            
            // Only show supporting features for high probability
            if diff.probability == "High" && !diff.supportingFeatures.isEmpty {
                formattedDiff += "   - Supporting features: \(diff.supportingFeatures.joined(separator: ", "))\n"
            }
            
            // Always show red flags if present in symptoms
            if !diff.redFlags.isEmpty {
                formattedDiff += "   - Red flags to monitor: \(diff.redFlags.joined(separator: ", "))\n"
            }
            
            formattedDiff += "\n"
        }
        
        // Add recommended workup based on highest probability diagnosis
        if let primary = differentials.first {
            formattedDiff += "**RECOMMENDED WORKUP:**\n"
            formattedDiff += primary.workup.joined(separator: ", ")
        }
        
        return formattedDiff
    }
    
    /// Generate ICD-10 code list for billing
    static func generateICD10List(_ differentials: [DifferentialDiagnosis]) -> String {
        guard !differentials.isEmpty else { return "" }
        
        var icdList = "**ICD-10 CODES:**\n"
        
        // Primary diagnosis
        if let primary = differentials.first {
            icdList += "Primary: \(primary.icd10Code) - \(primary.condition)\n"
        }
        
        // Secondary diagnoses (up to 3 more)
        let secondaries = differentials.dropFirst().prefix(3)
        if !secondaries.isEmpty {
            icdList += "Secondary:\n"
            for diff in secondaries {
                icdList += "  • \(diff.icd10Code) - \(diff.condition)\n"
            }
        }
        
        return icdList
    }
}