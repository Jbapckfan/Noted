import Foundation

/// Automated medical billing code suggestion engine based on CMS guidelines
/// Generates ICD-10 diagnosis codes and CPT procedure codes with E/M level optimization
class MedicalBillingCodeEngine {
    
    // MARK: - E/M Level Determination (2021 CMS Guidelines)
    
    enum EMLevel: Int {
        case level1_99211 = 99211  // Minimal problem, 5 minutes
        case level2_99212 = 99212  // Straightforward, 10-19 min
        case level3_99213 = 99213  // Low complexity, 20-29 min
        case level4_99214 = 99214  // Moderate complexity, 30-39 min
        case level5_99215 = 99215  // High complexity, 40-54 min
        
        var timeRange: String {
            switch self {
            case .level1_99211: return "5 minutes"
            case .level2_99212: return "10-19 minutes"
            case .level3_99213: return "20-29 minutes"
            case .level4_99214: return "30-39 minutes"
            case .level5_99215: return "40-54 minutes"
            }
        }
        
        var reimbursement: Double {
            // 2024 Medicare rates (approximate)
            switch self {
            case .level1_99211: return 23.87
            case .level2_99212: return 57.90
            case .level3_99213: return 93.51
            case .level4_99214: return 133.48
            case .level5_99215: return 185.96
            }
        }
    }
    
    // MARK: - Medical Decision Making (MDM) Components
    
    struct MDMComponents {
        let problemsAddressed: ProblemComplexity
        let dataReviewed: DataComplexity
        let riskLevel: RiskLevel
        
        var mdmLevel: MDMLevel {
            // Need 2 of 3 components at a level to qualify
            let levels = [problemsAddressed.level, dataReviewed.level, riskLevel.level]
            let sorted = levels.sorted()
            return MDMLevel(rawValue: sorted[1]) ?? .straightforward
        }
    }
    
    enum ProblemComplexity {
        case minimal           // 1 self-limited problem
        case low              // 2+ self-limited, 1 stable chronic
        case moderate         // 1+ chronic with exacerbation, 2+ stable chronic
        case high             // 1+ chronic with severe exacerbation
        
        var level: Int {
            switch self {
            case .minimal: return 1
            case .low: return 2
            case .moderate: return 3
            case .high: return 4
            }
        }
    }
    
    enum DataComplexity {
        case minimal          // No data review
        case limited         // Review of 1 test
        case moderate        // Review of 2+ tests, external records
        case extensive       // Review of 3+ tests, discussion with other provider
        
        var level: Int {
            switch self {
            case .minimal: return 1
            case .limited: return 2
            case .moderate: return 3
            case .extensive: return 4
            }
        }
    }
    
    enum RiskLevel {
        case minimal         // OTC drugs, rest
        case low            // Prescription meds, minor surgery
        case moderate       // Prescription with monitoring, minor surgery with risk
        case high           // Drug therapy requiring intensive monitoring, emergency surgery
        
        var level: Int {
            switch self {
            case .minimal: return 1
            case .low: return 2
            case .moderate: return 3
            case .high: return 4
            }
        }
    }
    
    enum MDMLevel: Int {
        case straightforward = 1
        case low = 2
        case moderate = 3
        case high = 4
        
        var emCode: EMLevel {
            switch self {
            case .straightforward: return .level2_99212
            case .low: return .level3_99213
            case .moderate: return .level4_99214
            case .high: return .level5_99215
            }
        }
    }
    
    // MARK: - ICD-10 Diagnosis Codes
    
    struct ICD10Code {
        let code: String
        let description: String
        let specificity: Specificity
        let category: DiagnosisCategory
        
        enum Specificity {
            case vague           // Needs more detail
            case acceptable      // Meets minimum requirements
            case optimal         // Maximum specificity
        }
        
        enum DiagnosisCategory {
            case primary         // Chief complaint
            case secondary       // Comorbidities
            case supplementary   // Z codes (history, screening)
        }
    }
    
    // MARK: - Core Analysis Functions
    
    /// Analyze transcription and suggest billing codes
    static func analyzeBillingCodes(from transcription: String, visitDuration: Int? = nil) -> BillingAnalysis {
        
        // 1. Extract medical entities
        let problems = extractProblems(from: transcription)
        let testsOrdered = extractTests(from: transcription)
        let medications = extractMedications(from: transcription)
        let procedures = extractProcedures(from: transcription)
        
        // 2. Calculate MDM components
        let problemComplexity = calculateProblemComplexity(problems)
        let dataComplexity = calculateDataComplexity(testsOrdered, transcription: transcription)
        let riskLevel = calculateRiskLevel(medications: medications, procedures: procedures)
        
        let mdm = MDMComponents(
            problemsAddressed: problemComplexity,
            dataReviewed: dataComplexity,
            riskLevel: riskLevel
        )
        
        // 3. Determine E/M level
        var emLevel: EMLevel
        
        if let duration = visitDuration {
            // Time-based billing (often more profitable)
            emLevel = determineEMLevelByTime(minutes: duration)
        } else {
            // MDM-based billing
            emLevel = mdm.mdmLevel.emCode
        }
        
        // 4. Generate ICD-10 codes
        let icd10Codes = generateICD10Codes(for: problems)
        
        // 5. Generate CPT procedure codes
        let cptCodes = generateCPTCodes(for: procedures)
        
        // 6. Check for optimization opportunities
        let optimizations = findOptimizations(
            currentLevel: emLevel,
            mdm: mdm,
            problems: problems,
            duration: visitDuration
        )
        
        // 7. Verify medical necessity
        let medicalNecessity = verifyMedicalNecessity(
            diagnoses: icd10Codes,
            procedures: cptCodes,
            emLevel: emLevel
        )
        
        return BillingAnalysis(
            emLevel: emLevel,
            mdmComponents: mdm,
            icd10Codes: icd10Codes,
            cptCodes: cptCodes,
            optimizations: optimizations,
            medicalNecessity: medicalNecessity,
            estimatedReimbursement: calculateReimbursement(emLevel: emLevel, cptCodes: cptCodes)
        )
    }
    
    // MARK: - Problem Extraction and Complexity
    
    static func extractProblems(from text: String) -> [MedicalProblem] {
        var problems = [MedicalProblem]()
        let lower = text.lowercased()
        
        // Acute problems
        if lower.contains("chest pain") {
            problems.append(MedicalProblem(
                description: "Chest pain",
                icd10: "R07.9",
                complexity: lower.contains("acute") || lower.contains("severe") ? .acute_complicated : .acute_uncomplicated
            ))
        }
        
        if lower.contains("myocardial infarction") || lower.contains("stemi") {
            problems.append(MedicalProblem(
                description: "STEMI",
                icd10: "I21.9",
                complexity: .acute_lifeThreatening
            ))
        }
        
        // Chronic conditions
        if lower.contains("diabetes") {
            let isControlled = lower.contains("controlled") || lower.contains("stable")
            problems.append(MedicalProblem(
                description: "Diabetes mellitus",
                icd10: "E11.9",
                complexity: isControlled ? .chronic_stable : .chronic_exacerbation
            ))
        }
        
        if lower.contains("hypertension") {
            problems.append(MedicalProblem(
                description: "Essential hypertension",
                icd10: "I10",
                complexity: .chronic_stable
            ))
        }
        
        // Symptoms
        if lower.contains("shortness of breath") || lower.contains("dyspnea") {
            problems.append(MedicalProblem(
                description: "Dyspnea",
                icd10: "R06.02",
                complexity: .acute_uncomplicated
            ))
        }
        
        return problems
    }
    
    static func calculateProblemComplexity(_ problems: [MedicalProblem]) -> ProblemComplexity {
        let acuteComplicated = problems.filter { $0.complexity == .acute_complicated }.count
        let chronicExacerbation = problems.filter { $0.complexity == .chronic_exacerbation }.count
        let chronicStable = problems.filter { $0.complexity == .chronic_stable }.count
        let lifeThreatening = problems.filter { $0.complexity == .acute_lifeThreatening }.count
        
        if lifeThreatening > 0 || chronicExacerbation >= 2 {
            return .high
        } else if acuteComplicated > 0 || chronicExacerbation == 1 || chronicStable >= 2 {
            return .moderate
        } else if problems.count >= 2 || chronicStable == 1 {
            return .low
        } else {
            return .minimal
        }
    }
    
    // MARK: - Data Complexity Calculation
    
    static func calculateDataComplexity(_ tests: [String], transcription: String) -> DataComplexity {
        let lower = transcription.lowercased()
        
        var dataPoints = 0
        
        // Count tests
        dataPoints += tests.count
        
        // Check for external record review
        if lower.contains("reviewed records") || lower.contains("outside hospital") {
            dataPoints += 2
        }
        
        // Check for discussion with other providers
        if lower.contains("discussed with") || lower.contains("consulted") {
            dataPoints += 1
        }
        
        // Check for independent interpretation
        if lower.contains("interpreted") || lower.contains("personally reviewed") {
            dataPoints += 2
        }
        
        if dataPoints >= 3 {
            return .extensive
        } else if dataPoints == 2 {
            return .moderate
        } else if dataPoints == 1 {
            return .limited
        } else {
            return .minimal
        }
    }
    
    // MARK: - Risk Level Calculation
    
    static func calculateRiskLevel(medications: [String], procedures: [String]) -> RiskLevel {
        // Check for high-risk medications
        let highRiskMeds = ["warfarin", "insulin", "chemotherapy", "immunosuppressant"]
        let hasHighRiskMed = medications.contains { med in
            highRiskMeds.contains { highRisk in
                med.lowercased().contains(highRisk)
            }
        }
        
        // Check for procedures
        let hasEmergencyProcedure = procedures.contains { $0.lowercased().contains("emergency") }
        let hasSurgery = procedures.contains { $0.lowercased().contains("surgery") }
        
        if hasHighRiskMed || hasEmergencyProcedure {
            return .high
        } else if medications.count >= 2 || hasSurgery {
            return .moderate
        } else if medications.count == 1 {
            return .low
        } else {
            return .minimal
        }
    }
    
    // MARK: - Time-Based E/M Level
    
    static func determineEMLevelByTime(minutes: Int) -> EMLevel {
        switch minutes {
        case 0..<10:
            return .level1_99211
        case 10..<20:
            return .level2_99212
        case 20..<30:
            return .level3_99213
        case 30..<40:
            return .level4_99214
        default:
            return .level5_99215
        }
    }
    
    // MARK: - ICD-10 Code Generation
    
    static func generateICD10Codes(for problems: [MedicalProblem]) -> [ICD10Code] {
        var codes = [ICD10Code]()
        
        for (index, problem) in problems.enumerated() {
            // Map to specific ICD-10 codes with maximum specificity
            var code = problem.icd10
            var specificity = ICD10Code.Specificity.acceptable
            
            // Add laterality if applicable
            if problem.description.lowercased().contains("left") {
                code = addLaterality(to: code, side: "left")
                specificity = .optimal
            } else if problem.description.lowercased().contains("right") {
                code = addLaterality(to: code, side: "right")
                specificity = .optimal
            }
            
            // Add episode of care
            if problem.complexity == .acute_complicated || problem.complexity == .acute_lifeThreatening {
                code = addEpisodeOfCare(to: code, episode: "initial")
                specificity = .optimal
            }
            
            codes.append(ICD10Code(
                code: code,
                description: problem.description,
                specificity: specificity,
                category: index == 0 ? .primary : .secondary
            ))
        }
        
        return codes
    }
    
    // MARK: - CPT Code Generation
    
    static func generateCPTCodes(for procedures: [String]) -> [CPTCode] {
        var codes = [CPTCode]()
        
        for procedure in procedures {
            let lower = procedure.lowercased()
            
            if lower.contains("ekg") || lower.contains("ecg") {
                codes.append(CPTCode(code: "93000", description: "Electrocardiogram, complete", rvu: 0.97))
            }
            
            if lower.contains("chest x-ray") || lower.contains("cxr") {
                codes.append(CPTCode(code: "71046", description: "Chest X-ray, 2 views", rvu: 1.18))
            }
            
            if lower.contains("troponin") {
                codes.append(CPTCode(code: "84484", description: "Troponin, quantitative", rvu: 0.0))
            }
            
            if lower.contains("injection") || lower.contains("vaccine") {
                codes.append(CPTCode(code: "90471", description: "Immunization administration", rvu: 0.61))
            }
        }
        
        return codes
    }
    
    // MARK: - Optimization Suggestions
    
    static func findOptimizations(
        currentLevel: EMLevel,
        mdm: MDMComponents,
        problems: [MedicalProblem],
        duration: Int?
    ) -> [BillingOptimization] {
        var optimizations = [BillingOptimization]()
        
        // Check if time-based would be better
        if let minutes = duration {
            let timeBasedLevel = determineEMLevelByTime(minutes: minutes)
            if timeBasedLevel.rawValue > currentLevel.rawValue {
                optimizations.append(BillingOptimization(
                    suggestion: "Use time-based billing (\(minutes) minutes) for \(timeBasedLevel)",
                    impact: timeBasedLevel.reimbursement - currentLevel.reimbursement,
                    requirement: "Document total time spent"
                ))
            }
        }
        
        // Check if one more data point would increase level
        if mdm.dataReviewed.level < 3 {
            optimizations.append(BillingOptimization(
                suggestion: "Review one more test or external record",
                impact: 40.0, // Approximate increase from 99213 to 99214
                requirement: "Document test review or external records"
            ))
        }
        
        // Check for missing ROS (Review of Systems)
        if currentLevel.rawValue < EMLevel.level4_99214.rawValue {
            optimizations.append(BillingOptimization(
                suggestion: "Add Review of Systems (10+ systems)",
                impact: 40.0,
                requirement: "Document ROS for constitutional, cardiovascular, respiratory, etc."
            ))
        }
        
        // Check for missing social history
        if problems.contains(where: { $0.description.contains("smoking") || $0.description.contains("alcohol") }) {
            optimizations.append(BillingOptimization(
                suggestion: "Add Z-codes for social determinants",
                impact: 0.0,
                requirement: "Document Z87.891 (nicotine dependence) or F10.10 (alcohol use)"
            ))
        }
        
        return optimizations
    }
    
    // MARK: - Medical Necessity Verification
    
    static func verifyMedicalNecessity(
        diagnoses: [ICD10Code],
        procedures: [CPTCode],
        emLevel: EMLevel
    ) -> MedicalNecessityCheck {
        var issues = [String]()
        var isValid = true
        
        // Check if diagnosis supports E/M level
        let hasSeriousDiagnosis = diagnoses.contains { code in
            code.code.hasPrefix("I") || // Circulatory
            code.code.hasPrefix("C") || // Neoplasms
            code.code.hasPrefix("J")    // Respiratory
        }
        
        if emLevel.rawValue >= EMLevel.level4_99214.rawValue && !hasSeriousDiagnosis {
            issues.append("High E/M level may require more serious diagnosis")
            isValid = false
        }
        
        // Check if procedures are supported by diagnoses
        for procedure in procedures {
            if procedure.code == "93000" { // EKG
                let hasCardiacDx = diagnoses.contains { $0.code.hasPrefix("I") || $0.code == "R07.9" }
                if !hasCardiacDx {
                    issues.append("EKG requires cardiac-related diagnosis")
                    isValid = false
                }
            }
        }
        
        return MedicalNecessityCheck(
            isValid: isValid,
            issues: issues,
            recommendations: issues.isEmpty ? ["Documentation supports medical necessity"] : issues
        )
    }
    
    // MARK: - Reimbursement Calculation
    
    static func calculateReimbursement(emLevel: EMLevel, cptCodes: [CPTCode]) -> Double {
        var total = emLevel.reimbursement
        
        for cpt in cptCodes {
            total += cpt.rvu * 38.89 // 2024 Medicare conversion factor
        }
        
        return total
    }
    
    // MARK: - Helper Functions
    
    static func extractTests(from text: String) -> [String] {
        var tests = [String]()
        let lower = text.lowercased()
        
        let testKeywords = ["ekg", "ecg", "x-ray", "cxr", "ct", "mri", "blood", "troponin", "bnp", "d-dimer", "cbc", "bmp", "urinalysis"]
        
        for keyword in testKeywords {
            if lower.contains(keyword) {
                tests.append(keyword)
            }
        }
        
        return tests
    }
    
    static func extractMedications(from text: String) -> [String] {
        var medications = [String]()
        
        // Simple pattern matching for medications
        let pattern = #"(\w+)\s+(\d+\s*mg)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            for match in matches {
                if let range = Range(match.range, in: text) {
                    medications.append(String(text[range]))
                }
            }
        }
        
        return medications
    }
    
    static func extractProcedures(from text: String) -> [String] {
        var procedures = [String]()
        let lower = text.lowercased()
        
        if lower.contains("injection") { procedures.append("injection") }
        if lower.contains("suture") { procedures.append("suture") }
        if lower.contains("i&d") || lower.contains("incision") { procedures.append("I&D") }
        if lower.contains("splint") { procedures.append("splint") }
        
        return procedures
    }
    
    static func addLaterality(to code: String, side: String) -> String {
        // Add laterality suffix if applicable
        if code == "M79.3" { // Panniculitis
            return side == "left" ? "M79.3L" : "M79.3R"
        }
        return code
    }
    
    static func addEpisodeOfCare(to code: String, episode: String) -> String {
        // Add 7th character for episode of care
        if code.hasPrefix("S") || code.hasPrefix("T") { // Injury codes
            return code + "A" // Initial encounter
        }
        return code
    }
}

// MARK: - Supporting Types

struct MedicalProblem {
    let description: String
    let icd10: String
    let complexity: ProblemType
    
    enum ProblemType {
        case self_limited
        case acute_uncomplicated
        case acute_complicated
        case acute_lifeThreatening
        case chronic_stable
        case chronic_exacerbation
    }
}

struct CPTCode {
    let code: String
    let description: String
    let rvu: Double // Relative Value Unit for reimbursement calculation
}

struct BillingOptimization {
    let suggestion: String
    let impact: Double // Potential revenue increase
    let requirement: String // What needs to be documented
}

struct MedicalNecessityCheck {
    let isValid: Bool
    let issues: [String]
    let recommendations: [String]
}

struct BillingAnalysis {
    let emLevel: MedicalBillingCodeEngine.EMLevel
    let mdmComponents: MedicalBillingCodeEngine.MDMComponents
    let icd10Codes: [MedicalBillingCodeEngine.ICD10Code]
    let cptCodes: [CPTCode]
    let optimizations: [BillingOptimization]
    let medicalNecessity: MedicalNecessityCheck
    let estimatedReimbursement: Double
    
    var summary: String {
        """
        === BILLING CODE ANALYSIS ===
        
        E/M Level: \(emLevel) (\(emLevel.timeRange))
        MDM Level: \(mdmComponents.mdmLevel)
        Estimated Reimbursement: $\(String(format: "%.2f", estimatedReimbursement))
        
        PRIMARY DIAGNOSIS:
        \(icd10Codes.first?.code ?? "None") - \(icd10Codes.first?.description ?? "")
        
        SECONDARY DIAGNOSES:
        \(icd10Codes.dropFirst().map { "• \($0.code) - \($0.description)" }.joined(separator: "\n"))
        
        PROCEDURES:
        \(cptCodes.map { "• \($0.code) - \($0.description)" }.joined(separator: "\n"))
        
        OPTIMIZATION OPPORTUNITIES:
        \(optimizations.map { "💰 \($0.suggestion) (+$\(String(format: "%.2f", $0.impact)))" }.joined(separator: "\n"))
        
        MEDICAL NECESSITY: \(medicalNecessity.isValid ? "✅ Valid" : "⚠️ Review needed")
        """
    }
}