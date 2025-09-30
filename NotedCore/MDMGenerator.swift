import Foundation
import NaturalLanguage

/// Generates Medical Decision Making (MDM) sections for billing and documentation compliance
@MainActor
class MDMGenerator: ObservableObject {
    static let shared = MDMGenerator()
    
    // MARK: - Published Properties
    @Published var mdmComplexity: MDMComplexity = .straightforward
    @Published var dataReviewed: [DataPoint] = []
    @Published var riskLevel: RiskLevel = .minimal
    @Published var generatedMDM: String = ""
    @Published var billingLevel: BillingLevel = .level2
    
    // MARK: - MDM Complexity Levels
    enum MDMComplexity: String, CaseIterable {
        case straightforward = "Straightforward"
        case lowComplexity = "Low Complexity"
        case moderateComplexity = "Moderate Complexity" 
        case highComplexity = "High Complexity"
        
        var description: String {
            switch self {
            case .straightforward:
                return "Minimal number of diagnoses, minimal data, minimal risk"
            case .lowComplexity:
                return "Limited number of diagnoses, limited data, low risk"
            case .moderateComplexity:
                return "Multiple diagnoses, moderate amount of data, moderate risk"
            case .highComplexity:
                return "Extensive diagnoses, extensive data, high risk"
            }
        }
        
        var points: Int {
            switch self {
            case .straightforward: return 1
            case .lowComplexity: return 2
            case .moderateComplexity: return 3
            case .highComplexity: return 4
            }
        }
    }
    
    // MARK: - Risk Levels
    enum RiskLevel: String, CaseIterable {
        case minimal = "Minimal"
        case low = "Low"
        case moderate = "Moderate"
        case high = "High"
        
        var points: Int {
            switch self {
            case .minimal: return 1
            case .low: return 2
            case .moderate: return 3
            case .high: return 4
            }
        }
    }
    
    // MARK: - Billing Levels
    enum BillingLevel: String, CaseIterable {
        case level1 = "99201/99211"
        case level2 = "99202/99212" 
        case level3 = "99203/99213"
        case level4 = "99204/99214"
        case level5 = "99205/99215"
        
        var description: String {
            switch self {
            case .level1: return "Level 1 - Straightforward"
            case .level2: return "Level 2 - Low complexity"
            case .level3: return "Level 3 - Moderate complexity"
            case .level4: return "Level 4 - Moderate to high complexity"
            case .level5: return "Level 5 - High complexity"
            }
        }
    }
    
    // MARK: - Data Types
    enum DataType: String, CaseIterable {
        case labResults = "Lab Results"
        case imagingResults = "Imaging Results"
        case oldRecords = "Old Medical Records"
        case consultation = "Specialist Consultation"
        case independentVisualization = "Independent Image Review"
        case externalNotes = "External Notes"
        case medicationList = "Medication Reconciliation"
        case familyHistory = "Family History"
    }
    
    struct DataPoint: Identifiable {
        let id = UUID()
        let type: DataType
        let description: String
        let points: Int
    }
    
    // MARK: - Risk Categories
    private let riskFactors: [String: (category: String, risk: RiskLevel)] = [
        // Minimal Risk
        "routine followup": ("Management", .minimal),
        "stable condition": ("Management", .minimal),
        "minor problem": ("Presenting Problem", .minimal),
        
        // Low Risk
        "over the counter drugs": ("Management", .low),
        "prescription drug management": ("Management", .low),
        "minor surgery": ("Management", .low),
        "self limited problem": ("Presenting Problem", .low),
        
        // Moderate Risk
        "prescription drug management": ("Management", .moderate),
        "minor surgery with risk factors": ("Management", .moderate),
        "acute illness": ("Presenting Problem", .moderate),
        "chronic illness": ("Presenting Problem", .moderate),
        "undiagnosed new problem": ("Presenting Problem", .moderate),
        
        // High Risk
        "drug therapy requiring monitoring": ("Management", .high),
        "major surgery": ("Management", .high),
        "life threatening illness": ("Presenting Problem", .high),
        "acute or chronic illness": ("Presenting Problem", .high)
    ]
    
    private init() {}
    
    // MARK: - Main Analysis Function
    
    func analyzeTranscriptionForMDM(_ transcription: String, diagnosis: String = "", assessment: String = "") -> String {
        
        // Reset values
        dataReviewed.removeAll()
        
        // Analyze data reviewed
        analyzeDataReviewed(from: transcription)
        
        // Analyze risk factors
        analyzeRiskFactors(from: transcription, diagnosis: diagnosis, assessment: assessment)
        
        // Calculate complexity
        calculateMDMComplexity()
        
        // Generate MDM narrative
        generatedMDM = generateMDMNarrative()
        
        // Determine billing level
        determineBillingLevel()
        
        return generatedMDM
    }
    
    // MARK: - Data Analysis
    
    private func analyzeDataReviewed(from text: String) {
        let lowercaseText = text.lowercased()
        
        // Lab results
        if lowercaseText.contains("lab") || lowercaseText.contains("blood work") || 
           lowercaseText.contains("cbc") || lowercaseText.contains("bmp") ||
           lowercaseText.contains("glucose") || lowercaseText.contains("hemoglobin") {
            dataReviewed.append(DataPoint(type: .labResults, description: "Laboratory results reviewed", points: 1))
        }
        
        // Imaging
        if lowercaseText.contains("x-ray") || lowercaseText.contains("ct scan") ||
           lowercaseText.contains("mri") || lowercaseText.contains("ultrasound") ||
           lowercaseText.contains("imaging") {
            dataReviewed.append(DataPoint(type: .imagingResults, description: "Imaging studies reviewed", points: 1))
        }
        
        // Previous records
        if lowercaseText.contains("previous") || lowercaseText.contains("prior") ||
           lowercaseText.contains("last visit") || lowercaseText.contains("old records") {
            dataReviewed.append(DataPoint(type: .oldRecords, description: "Previous medical records reviewed", points: 1))
        }
        
        // Consultations
        if lowercaseText.contains("specialist") || lowercaseText.contains("cardiology") ||
           lowercaseText.contains("neurology") || lowercaseText.contains("consultation") {
            dataReviewed.append(DataPoint(type: .consultation, description: "Specialist consultation notes reviewed", points: 1))
        }
        
        // Medications
        if lowercaseText.contains("taking") || lowercaseText.contains("medication") ||
           lowercaseText.contains("prescribe") || lowercaseText.contains("drug") {
            dataReviewed.append(DataPoint(type: .medicationList, description: "Medication list reviewed and reconciled", points: 1))
        }
        
        // Family history
        if lowercaseText.contains("family history") || lowercaseText.contains("mother had") ||
           lowercaseText.contains("father had") || lowercaseText.contains("runs in family") {
            dataReviewed.append(DataPoint(type: .familyHistory, description: "Family history reviewed", points: 1))
        }
        
        // Independent image interpretation
        if lowercaseText.contains("reviewed the") && (lowercaseText.contains("x-ray") || lowercaseText.contains("scan")) {
            dataReviewed.append(DataPoint(type: .independentVisualization, description: "Independent interpretation of imaging", points: 2))
        }
    }
    
    // MARK: - Risk Analysis
    
    private func analyzeRiskFactors(from text: String, diagnosis: String, assessment: String) {
        let combinedText = "\(text) \(diagnosis) \(assessment)".lowercased()
        var identifiedRisks: [RiskLevel] = [.minimal] // Start with minimal
        
        // Check for various risk factors
        let riskPatterns = [
            // High Risk
            ("chest pain", RiskLevel.high),
            ("shortness of breath", RiskLevel.high),
            ("life threatening", RiskLevel.high),
            ("emergency", RiskLevel.high),
            ("acute", RiskLevel.high),
            ("severe", RiskLevel.high),
            ("critical", RiskLevel.high),
            ("unstable", RiskLevel.high),
            
            // Moderate Risk
            ("chronic", RiskLevel.moderate),
            ("multiple medications", RiskLevel.moderate),
            ("surgery", RiskLevel.moderate),
            ("uncontrolled", RiskLevel.moderate),
            ("monitoring required", RiskLevel.moderate),
            ("followup needed", RiskLevel.moderate),
            ("abnormal", RiskLevel.moderate),
            
            // Low Risk
            ("stable", RiskLevel.low),
            ("mild", RiskLevel.low),
            ("routine", RiskLevel.low),
            ("maintenance", RiskLevel.low),
            ("followup", RiskLevel.low),
            
            // Medication-related risks
            ("warfarin", RiskLevel.high),
            ("chemotherapy", RiskLevel.high),
            ("insulin", RiskLevel.moderate),
            ("steroid", RiskLevel.moderate)
        ]
        
        for (pattern, risk) in riskPatterns {
            if combinedText.contains(pattern) {
                identifiedRisks.append(risk)
            }
        }
        
        // Take the highest risk level identified
        riskLevel = identifiedRisks.max { $0.points < $1.points } ?? .minimal
    }
    
    // MARK: - Complexity Calculation
    
    private func calculateMDMComplexity() {
        // Calculate based on 2021 CMS guidelines
        let dataPoints = dataReviewed.reduce(0) { $0 + $1.points }
        
        // Determine complexity based on data reviewed and risk
        if riskLevel == .high || dataPoints >= 4 {
            mdmComplexity = .highComplexity
        } else if riskLevel == .moderate || dataPoints >= 3 {
            mdmComplexity = .moderateComplexity
        } else if riskLevel == .low || dataPoints >= 2 {
            mdmComplexity = .lowComplexity
        } else {
            mdmComplexity = .straightforward
        }
    }
    
    // MARK: - MDM Narrative Generation
    
    private func generateMDMNarrative() -> String {
        var narrative = "MEDICAL DECISION MAKING:\n\n"
        
        // Data reviewed section
        if !dataReviewed.isEmpty {
            narrative += "Data Reviewed:\n"
            for data in dataReviewed {
                narrative += "• \(data.description)\n"
            }
            narrative += "\n"
        }
        
        // Risk assessment
        narrative += "Risk Assessment:\n"
        narrative += "• Risk level: \(riskLevel.rawValue)\n"
        narrative += "• Risk factors considered in management plan\n"
        narrative += "• Patient counseled on risks and benefits\n\n"
        
        // Complexity justification
        narrative += "Complexity of Medical Decision Making:\n"
        narrative += "• Level: \(mdmComplexity.rawValue)\n"
        narrative += "• Rationale: \(mdmComplexity.description)\n"
        
        if !dataReviewed.isEmpty {
            let dataCount = dataReviewed.count
            narrative += "• \(dataCount) category(ies) of data reviewed and analyzed\n"
        }
        
        narrative += "• Risk of complications: \(riskLevel.rawValue)\n"
        narrative += "• Management options considered\n"
        narrative += "• Patient education provided\n\n"
        
        // Time spent (if complex)
        if mdmComplexity.points >= 3 {
            narrative += "Total encounter time: Appropriate for complexity level\n"
            narrative += "Time spent in counseling and coordination of care: >50% when applicable\n"
        }
        
        return narrative
    }
    
    // MARK: - Billing Level Determination
    
    private func determineBillingLevel() {
        switch mdmComplexity {
        case .straightforward:
            billingLevel = .level2
        case .lowComplexity:
            billingLevel = .level3
        case .moderateComplexity:
            billingLevel = .level4
        case .highComplexity:
            billingLevel = .level5
        }
    }
    
    // MARK: - Billing Code Generation
    
    func generateBillingJustification() -> String {
        var justification = "BILLING LEVEL JUSTIFICATION\n\n"
        
        justification += "Recommended E&M Code: \(billingLevel.rawValue)\n"
        justification += "Level: \(billingLevel.description)\n\n"
        
        justification += "MDM Complexity: \(mdmComplexity.rawValue)\n"
        justification += "• \(mdmComplexity.description)\n\n"
        
        if !dataReviewed.isEmpty {
            let totalPoints = dataReviewed.reduce(0) { $0 + $1.points }
            justification += "Data Categories Reviewed: \(dataReviewed.count) (\(totalPoints) points)\n"
            for data in dataReviewed {
                justification += "• \(data.description)\n"
            }
            justification += "\n"
        }
        
        justification += "Risk Level: \(riskLevel.rawValue)\n"
        justification += "• Risk assessment performed\n"
        justification += "• Management plan addresses identified risks\n\n"
        
        // Additional requirements
        if mdmComplexity.points >= 3 {
            justification += "Additional Requirements Met:\n"
            justification += "• Detailed history and examination performed\n"
            justification += "• Complex medical decision making documented\n"
            justification += "• Patient counseling and education provided\n"
        }
        
        return justification
    }
    
    // MARK: - Quality Measures
    
    func generateQualityMetrics() -> [String: Any] {
        return [
            "mdm_complexity": mdmComplexity.rawValue,
            "data_points_reviewed": dataReviewed.count,
            "risk_level": riskLevel.rawValue,
            "billing_level": billingLevel.rawValue,
            "complexity_score": mdmComplexity.points,
            "risk_score": riskLevel.points,
            "data_categories": dataReviewed.map { $0.type.rawValue }
        ]
    }
    
    // MARK: - Clinical Decision Support
    
    func suggestAdditionalData() -> [String] {
        var suggestions: [String] = []
        
        if mdmComplexity.points >= 3 && dataReviewed.count < 2 {
            suggestions.append("Consider reviewing additional data sources to support complexity level")
        }
        
        if riskLevel.points >= 3 && !dataReviewed.contains(where: { $0.type == .labResults }) {
            suggestions.append("Lab results review may be appropriate for this risk level")
        }
        
        if !dataReviewed.contains(where: { $0.type == .medicationList }) {
            suggestions.append("Medication reconciliation documentation would strengthen MDM")
        }
        
        if mdmComplexity == .highComplexity && dataReviewed.count < 3 {
            suggestions.append("High complexity MDM typically requires 3+ data categories")
        }
        
        return suggestions
    }
    
    // MARK: - Template Generation
    
    func generateMDMTemplate() -> String {
        var template = "ASSESSMENT AND PLAN:\n\n"
        
        template += "After review of the available data including "
        
        let dataDescriptions = dataReviewed.map { $0.description.lowercased() }
        if dataDescriptions.isEmpty {
            template += "the patient history and examination"
        } else {
            template += dataDescriptions.joined(separator: ", ")
        }
        
        template += ", my assessment is as follows:\n\n"
        
        template += "[DIAGNOSIS/ASSESSMENT]\n\n"
        
        template += "Given the \(riskLevel.rawValue.lowercased()) risk nature of this condition and "
        template += "after consideration of multiple treatment options, "
        template += "the plan includes:\n\n"
        
        template += "[TREATMENT PLAN]\n\n"
        
        template += "The patient was counseled regarding the diagnosis, treatment options, "
        template += "risks and benefits of the recommended treatment, and expected course. "
        template += "All questions were answered. The patient expressed understanding and "
        template += "agreed with the treatment plan.\n\n"
        
        if riskLevel.points >= 3 {
            template += "Given the \(riskLevel.rawValue.lowercased()) risk nature of this condition, "
            template += "close monitoring and follow-up are essential.\n\n"
        }
        
        template += "Medical Decision Making: \(mdmComplexity.rawValue)\n"
        
        return template
    }
}

// MARK: - Extensions for Integration

extension MDMGenerator {
    func updateFromStructuredNote(_ structuredNote: StructuredMedicalNote) {
        let combinedText = """
        \(structuredNote.historyOfPresentIllness)
        \(structuredNote.assessment)
        \(structuredNote.plan)
        """
        
        analyzeTranscriptionForMDM(combinedText, 
                                 diagnosis: structuredNote.assessment,
                                 assessment: structuredNote.plan)
    }
}