import Foundation
import SwiftUI

/// Clinical Decision Tool Suggestion Engine
/// Suggests relevant calculators, scores, and guidelines based on patient presentation
/// This is NOT diagnosis - just suggesting validated tools doctors already use
class ClinicalDecisionToolEngine {
    
    // MARK: - Clinical Tool Types
    
    enum ToolType {
        case calculator
        case score
        case criteria
        case guideline
        case scale
        
        var icon: String {
            switch self {
            case .calculator: return "function"
            case .score: return "chart.bar.fill"
            case .criteria: return "checklist"
            case .guideline: return "doc.text.fill"
            case .scale: return "slider.horizontal.3"
            }
        }
    }
    
    struct ClinicalTool {
        let name: String
        let abbreviation: String?
        let type: ToolType
        let description: String
        let useCase: String
        let inputs: [String]
        let outputInterpretation: String
        let url: String?  // Link to MDCalc or official calculator
        let specialty: CoreAppState.MedicalSpecialty
        let keywords: [String]  // Triggers for suggestion
    }
    
    // MARK: - Clinical Tools Database
    
    static let clinicalTools: [ClinicalTool] = [
        // Cardiology Tools
        ClinicalTool(
            name: "HEART Score",
            abbreviation: "HEART",
            type: .score,
            description: "Risk stratification for chest pain in emergency department",
            useCase: "Chest pain evaluation for major cardiac events risk",
            inputs: ["History", "ECG", "Age", "Risk factors", "Troponin"],
            outputInterpretation: "0-3: Low risk (1.7%), 4-6: Moderate (16.6%), 7-10: High (50.1%)",
            url: "https://www.mdcalc.com/heart-score-major-cardiac-events",
            specialty: .cardiology,
            keywords: ["chest pain", "cardiac", "heart", "mi", "acs", "angina"]
        ),
        
        ClinicalTool(
            name: "CHA2DS2-VASc Score",
            abbreviation: "CHA2DS2-VASc",
            type: .score,
            description: "Stroke risk in atrial fibrillation",
            useCase: "Determine anticoagulation need in AFib patients",
            inputs: ["CHF history", "Hypertension", "Age ≥75", "Diabetes", "Stroke/TIA/TE", "Vascular disease", "Age 65-74", "Sex"],
            outputInterpretation: "0: Low risk, 1: Moderate, ≥2: High - consider anticoagulation",
            url: "https://www.mdcalc.com/cha2ds2-vasc-score-atrial-fibrillation-stroke-risk",
            specialty: .cardiology,
            keywords: ["afib", "atrial fibrillation", "stroke risk", "anticoagulation"]
        ),
        
        ClinicalTool(
            name: "Wells Score for PE",
            abbreviation: "Wells",
            type: .criteria,
            description: "Pre-test probability of pulmonary embolism",
            useCase: "Risk stratify patients with suspected PE",
            inputs: ["Clinical signs of DVT", "PE likely diagnosis", "Heart rate >100", "Immobilization/surgery", "Previous PE/DVT", "Hemoptysis", "Malignancy"],
            outputInterpretation: "<2: Low risk, 2-6: Moderate, >6: High risk",
            url: "https://www.mdcalc.com/wells-criteria-pulmonary-embolism",
            specialty: .emergency,
            keywords: ["pulmonary embolism", "pe", "shortness of breath", "chest pain", "dvt"]
        ),
        
        // Emergency Medicine Tools
        ClinicalTool(
            name: "NEXUS Criteria",
            abbreviation: "NEXUS",
            type: .criteria,
            description: "C-spine imaging in trauma",
            useCase: "Determine need for cervical spine imaging",
            inputs: ["Focal neurologic deficit", "Midline spinal tenderness", "Altered consciousness", "Intoxication", "Distracting injury"],
            outputInterpretation: "If all negative → No imaging needed (99.8% sensitive)",
            url: "https://www.mdcalc.com/nexus-criteria-c-spine-imaging",
            specialty: .emergency,
            keywords: ["neck pain", "trauma", "fall", "mvc", "motor vehicle", "cervical"]
        ),
        
        ClinicalTool(
            name: "Canadian Head CT Rule",
            abbreviation: "CCHR",
            type: .criteria,
            description: "Head CT for minor head injury",
            useCase: "Determine need for head CT in minor trauma",
            inputs: ["GCS <15 at 2h", "Suspected skull fracture", "Vomiting ≥2", "Age ≥65", "Amnesia before impact >30min", "Dangerous mechanism"],
            outputInterpretation: "Any high-risk factor → CT needed",
            url: "https://www.mdcalc.com/canadian-ct-head-injury-trauma-rule",
            specialty: .emergency,
            keywords: ["head injury", "trauma", "fall", "concussion", "tbi"]
        ),
        
        ClinicalTool(
            name: "PERC Rule",
            abbreviation: "PERC",
            type: .criteria,
            description: "Rule out PE in low-risk patients",
            useCase: "Avoid unnecessary testing for PE",
            inputs: ["Age ≥50", "HR ≥100", "O2 sat <95%", "Unilateral leg swelling", "Hemoptysis", "Recent surgery", "Previous PE/DVT", "Hormone use"],
            outputInterpretation: "All negative + low risk → <2% chance of PE",
            url: "https://www.mdcalc.com/perc-rule-pulmonary-embolism",
            specialty: .emergency,
            keywords: ["pulmonary embolism", "pe", "chest pain", "dyspnea"]
        ),
        
        // Infectious Disease Tools
        ClinicalTool(
            name: "qSOFA Score",
            abbreviation: "qSOFA",
            type: .score,
            description: "Quick sepsis screening",
            useCase: "Identify patients at risk for sepsis",
            inputs: ["Respiratory rate ≥22", "Altered mentation", "Systolic BP ≤100"],
            outputInterpretation: "≥2 points: High risk for poor outcome",
            url: "https://www.mdcalc.com/qsofa-quick-sofa-score-sepsis",
            specialty: .emergency,
            keywords: ["sepsis", "infection", "fever", "hypotension", "altered mental status"]
        ),
        
        ClinicalTool(
            name: "Centor Score",
            abbreviation: "Centor",
            type: .score,
            description: "Strep pharyngitis probability",
            useCase: "Determine need for strep testing/antibiotics",
            inputs: ["Fever", "Tonsillar exudates", "Tender anterior cervical lymphadenopathy", "Absence of cough", "Age"],
            outputInterpretation: "0-1: No testing, 2-3: Test, 4-5: Treat empirically",
            url: "https://www.mdcalc.com/centor-score-modified-strep-pharyngitis",
            specialty: .generalPractice,
            keywords: ["sore throat", "pharyngitis", "strep", "throat pain"]
        ),
        
        // Pediatric Tools
        ClinicalTool(
            name: "PECARN Head Injury Rule",
            abbreviation: "PECARN",
            type: .criteria,
            description: "Pediatric head CT decision",
            useCase: "CT indication for pediatric head trauma",
            inputs: ["GCS", "Altered mental status", "Skull fracture signs", "LOC duration", "Vomiting", "Headache severity", "Mechanism"],
            outputInterpretation: "Very low risk if criteria negative (<0.02% risk)",
            url: "https://www.mdcalc.com/pecarn-pediatric-head-injury-trauma-algorithm",
            specialty: .pediatrics,
            keywords: ["pediatric", "head injury", "child", "fall", "trauma"]
        ),
        
        ClinicalTool(
            name: "Pediatric Asthma Score",
            abbreviation: "PAS",
            type: .scale,
            description: "Asthma severity in children",
            useCase: "Assess asthma exacerbation severity",
            inputs: ["Respiratory rate", "Oxygen requirement", "Auscultation", "Retractions", "Dyspnea"],
            outputInterpretation: "5-7: Mild, 8-11: Moderate, 12-15: Severe",
            url: "https://www.mdcalc.com/pediatric-asthma-score-pas",
            specialty: .pediatrics,
            keywords: ["asthma", "wheezing", "breathing", "pediatric", "respiratory"]
        ),
        
        // Psychiatry Tools
        ClinicalTool(
            name: "PHQ-9",
            abbreviation: "PHQ-9",
            type: .scale,
            description: "Depression screening",
            useCase: "Screen and monitor depression severity",
            inputs: ["9 questions about depression symptoms over past 2 weeks"],
            outputInterpretation: "0-4: Minimal, 5-9: Mild, 10-14: Moderate, 15-19: Moderately severe, 20-27: Severe",
            url: "https://www.mdcalc.com/phq-9-patient-health-questionnaire-9",
            specialty: .psychiatry,
            keywords: ["depression", "mood", "sad", "psychiatric", "mental health"]
        ),
        
        ClinicalTool(
            name: "GAD-7",
            abbreviation: "GAD-7",
            type: .scale,
            description: "Anxiety screening",
            useCase: "Screen for generalized anxiety disorder",
            inputs: ["7 questions about anxiety symptoms over past 2 weeks"],
            outputInterpretation: "0-5: Mild, 6-10: Moderate, 11-15: Moderately severe, 16-21: Severe",
            url: "https://www.mdcalc.com/gad-7-general-anxiety-disorder-7",
            specialty: .psychiatry,
            keywords: ["anxiety", "panic", "worry", "nervous", "psychiatric"]
        ),
        
        // General/Primary Care Tools
        ClinicalTool(
            name: "FRAX Score",
            abbreviation: "FRAX",
            type: .calculator,
            description: "10-year fracture risk",
            useCase: "Osteoporosis screening and treatment decisions",
            inputs: ["Age", "Sex", "Weight", "Height", "Previous fracture", "Parent hip fracture", "Smoking", "Glucocorticoids", "RA", "Alcohol"],
            outputInterpretation: ">3% hip or >20% major: Consider treatment",
            url: "https://www.sheffield.ac.uk/FRAX/tool.aspx",
            specialty: .generalPractice,
            keywords: ["osteoporosis", "fracture", "bone", "fall risk", "bone density"]
        ),
        
        ClinicalTool(
            name: "ASCVD Risk Calculator",
            abbreviation: "ASCVD",
            type: .calculator,
            description: "10-year cardiovascular risk",
            useCase: "Statin therapy decisions",
            inputs: ["Age", "Sex", "Race", "Total cholesterol", "HDL", "Systolic BP", "BP treatment", "Diabetes", "Smoking"],
            outputInterpretation: "<5%: Low, 5-7.5%: Borderline, 7.5-20%: Intermediate, >20%: High",
            url: "https://tools.acc.org/ascvd-risk-estimator-plus",
            specialty: .generalPractice,
            keywords: ["cholesterol", "cardiac risk", "lipids", "statin", "prevention"]
        ),
        
        ClinicalTool(
            name: "Ottawa Ankle Rules",
            abbreviation: "Ottawa",
            type: .criteria,
            description: "Ankle X-ray necessity",
            useCase: "Determine need for ankle/foot X-ray",
            inputs: ["Bone tenderness", "Inability to bear weight", "Location of pain"],
            outputInterpretation: "If criteria met → X-ray indicated",
            url: "https://www.mdcalc.com/ottawa-ankle-rule",
            specialty: .emergency,
            keywords: ["ankle", "foot", "injury", "sprain", "trauma"]
        )
    ]
    
    // MARK: - Suggestion Engine
    
    /// Analyze transcription and suggest relevant clinical tools
    static func suggestTools(for transcription: String, specialty: CoreAppState.MedicalSpecialty? = nil) -> [ClinicalTool] {
        let lower = transcription.lowercased()
        var suggestedTools: [ClinicalTool] = []
        var matchScores: [(tool: ClinicalTool, score: Int)] = []
        
        // Check if tool suggestions are enabled
        guard CoreAppState.shared.isClinicalToolSuggestionsEnabled else {
            return []
        }
        
        for tool in clinicalTools {
            // Filter by specialty if specified
            if let specialty = specialty, tool.specialty != specialty && tool.specialty != .generalPractice {
                continue
            }
            
            // Calculate relevance score based on keyword matches
            var score = 0
            for keyword in tool.keywords {
                if lower.contains(keyword) {
                    score += keyword.split(separator: " ").count // Multi-word matches score higher
                }
            }
            
            if score > 0 {
                matchScores.append((tool: tool, score: score))
            }
        }
        
        // Sort by relevance and take top 5
        matchScores.sort { $0.score > $1.score }
        suggestedTools = Array(matchScores.prefix(5).map { $0.tool })
        
        return suggestedTools
    }
    
    // MARK: - Tool Recommendation View
    
    struct ToolSuggestionView: View {
        let tools: [ClinicalTool]
        @State private var expandedTool: ClinicalTool?
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "function")
                        .foregroundColor(.blue)
                    Text("Suggested Clinical Tools")
                        .font(.headline)
                    Spacer()
                    Text("\(tools.count)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)
                }
                
                ForEach(tools, id: \.name) { tool in
                    ToolRow(tool: tool, isExpanded: expandedTool?.name == tool.name) {
                        withAnimation {
                            expandedTool = expandedTool?.name == tool.name ? nil : tool
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    struct ToolRow: View {
        let tool: ClinicalTool
        let isExpanded: Bool
        let onTap: () -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: tool.type.icon)
                        .foregroundColor(.blue)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(tool.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if let abbr = tool.abbreviation {
                                Text("(\(abbr))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Text(tool.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Use Case:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(tool.useCase)
                            .font(.caption)
                        
                        Text("Inputs:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        ForEach(tool.inputs, id: \.self) { input in
                            Text("• \(input)")
                                .font(.caption)
                        }
                        
                        Text("Interpretation:")
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(tool.outputInterpretation)
                            .font(.caption)
                        
                        if let url = tool.url {
                            Link(destination: URL(string: url)!) {
                                HStack {
                                    Text("Open Calculator")
                                        .font(.caption)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.leading, 28)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Integration Helper
    
    /// Get formatted suggestion text for display
    static func getFormattedSuggestions(for tools: [ClinicalTool]) -> String {
        guard !tools.isEmpty else { return "" }
        
        var output = "📊 SUGGESTED CLINICAL TOOLS:\n"
        
        for tool in tools {
            if let abbr = tool.abbreviation {
                output += "\n• \(tool.name) (\(abbr))"
            } else {
                output += "\n• \(tool.name)"
            }
            output += "\n  → \(tool.description)"
        }
        
        output += "\n\n💡 These are validated clinical decision tools. Use clinical judgment."
        
        return output
    }
}