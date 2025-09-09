import Foundation
import NaturalLanguage

/// BAYESIAN CLINICAL REASONING ENGINE
/// Real implementation using probabilistic medical reasoning
/// Uses only open source medical knowledge - no API calls or costs
@MainActor
final class BayesianClinicalReasoner: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentHypotheses: [MedicalHypothesis] = []
    @Published var evidenceChain: [EvidenceItem] = []
    @Published var clinicalAlerts: [ClinicalAlert] = []
    @Published var documentationGuidance: [DocumentationGuidance] = []
    @Published var qualityScore: Float = 0.0
    
    // MARK: - Clinical Knowledge Base (Open Source)
    private let medicalKnowledgeBase: MedicalKnowledgeBase
    private let clinicalDecisionRules: ClinicalDecisionRules
    private let bayesianEngine: BayesianInferenceEngine
    private let evidenceExtractor: ClinicalEvidenceExtractor
    
    init() {
        self.medicalKnowledgeBase = MedicalKnowledgeBase()
        self.clinicalDecisionRules = ClinicalDecisionRules()
        self.bayesianEngine = BayesianInferenceEngine()
        self.evidenceExtractor = ClinicalEvidenceExtractor()
    }
    
    // MARK: - Main Clinical Reasoning Interface
    func processConversationSegment(_ text: String) async {
        let startTime = CACurrentMediaTime()
        
        // 1. Extract clinical findings with confidence
        let findings = await evidenceExtractor.extractFindings(text)
        
        // 2. Update hypotheses using Bayesian inference
        let updatedHypotheses = await bayesianEngine.updateHypotheses(
            newFindings: findings,
            priorHypotheses: currentHypotheses
        )
        
        // 3. Check for critical alerts
        let alerts = await clinicalDecisionRules.checkForCriticalFindings(
            findings: findings,
            hypotheses: updatedHypotheses
        )
        
        // 4. Generate documentation guidance
        let guidance = await generateDocumentationGuidance(
            findings: findings,
            hypotheses: updatedHypotheses
        )
        
        // 5. Calculate quality score
        let quality = calculateClinicalQualityScore(
            findings: findings,
            hypotheses: updatedHypotheses,
            text: text
        )
        
        // Update published properties
        currentHypotheses = updatedHypotheses
        evidenceChain = findings
        clinicalAlerts = alerts
        documentationGuidance = guidance
        qualityScore = quality
        
        let processingTime = CACurrentMediaTime() - startTime
        print("🧠 Clinical reasoning completed in \(String(format: "%.2f", processingTime * 1000))ms")
    }
    
    // MARK: - Documentation Guidance Generation
    private func generateDocumentationGuidance(
        findings: [EvidenceItem],
        hypotheses: [MedicalHypothesis]
    ) async -> [DocumentationGuidance] {
        
        var guidance: [DocumentationGuidance] = []
        
        // Check for missing essential elements
        let hasChiefComplaint = findings.contains { $0.category == .chief_complaint }
        let hasHistory = findings.contains { $0.category == .history }
        let hasExamination = findings.contains { $0.category == .physical_exam }
        
        if !hasChiefComplaint {
            guidance.append(DocumentationGuidance(
                type: .missing_element,
                title: "Chief Complaint Missing",
                description: "Document the primary reason for the visit",
                priority: .high,
                suggestion: "Add: 'Chief Complaint: [patient's main concern]'"
            ))
        }
        
        if !hasHistory {
            guidance.append(DocumentationGuidance(
                type: .missing_element,
                title: "History of Present Illness Needed",
                description: "Document onset, duration, character, and associated symptoms",
                priority: .high,
                suggestion: "Include OLDCARTS: Onset, Location, Duration, Character, Aggravating factors, Relieving factors, Timing, Severity"
            ))
        }
        
        // Check for high-probability diagnoses needing specific documentation
        for hypothesis in hypotheses where hypothesis.probability > 0.7 {
            if let requiredDocumentation = medicalKnowledgeBase.getRequiredDocumentation(for: hypothesis.condition) {
                guidance.append(DocumentationGuidance(
                    type: .diagnosis_specific,
                    title: "Documentation for \(hypothesis.condition)",
                    description: requiredDocumentation.description,
                    priority: .medium,
                    suggestion: requiredDocumentation.template
                ))
            }
        }
        
        // Billing optimization guidance
        let highValueConditions = hypotheses.filter { 
            medicalKnowledgeBase.getBillingComplexity(for: $0.condition) == .high 
        }
        
        for condition in highValueConditions {
            guidance.append(DocumentationGuidance(
                type: .billing_optimization,
                title: "High-Value Documentation Opportunity",
                description: "Additional documentation could support higher-level billing",
                priority: .medium,
                suggestion: "Consider documenting: decision-making complexity, risk factors, comorbidities"
            ))
        }
        
        return guidance
    }
    
    // MARK: - Quality Scoring
    private func calculateClinicalQualityScore(
        findings: [EvidenceItem],
        hypotheses: [MedicalHypothesis],
        text: String
    ) -> Float {
        
        var score: Float = 0.0
        
        // Evidence completeness (30%)
        let evidenceCategories: [EvidenceCategory] = [.chief_complaint, .history, .physical_exam, .assessment]
        let presentCategories = Set(findings.map { $0.category })
        let completeness = Float(presentCategories.count) / Float(evidenceCategories.count)
        score += completeness * 0.3
        
        // Hypothesis quality (25%)
        let avgHypothesisProbability = hypotheses.isEmpty ? 0.0 : 
            hypotheses.map { $0.probability }.reduce(0, +) / Float(hypotheses.count)
        score += avgHypothesisProbability * 0.25
        
        // Medical terminology usage (25%)
        let medicalTermCount = medicalKnowledgeBase.countMedicalTerms(in: text)
        let medicalDensity = min(1.0, Float(medicalTermCount) / Float(text.components(separatedBy: .whitespaces).count) * 10)
        score += medicalDensity * 0.25
        
        // Clinical structure (20%)
        let hasStructure = text.contains(":") || text.contains("•") || text.contains("-")
        let appropriateLength = text.count > 50 && text.count < 3000
        let structureScore = (hasStructure ? 0.5 : 0.0) + (appropriateLength ? 0.5 : 0.0)
        score += structureScore * 0.2
        
        return min(1.0, score)
    }
}

// MARK: - Medical Hypothesis Structure
struct MedicalHypothesis: Identifiable {
    let id = UUID()
    let condition: String
    var probability: Float
    let supportingEvidence: [EvidenceItem]
    let contradictingEvidence: [EvidenceItem]
    let clinicalScore: Float
    let requiredWorkup: [DiagnosticAction]
    let timeToDecision: TimeInterval
    let icd10Code: String?
    
    var probabilityDescription: String {
        switch probability {
        case 0.8...1.0: return "Highly Likely"
        case 0.6..<0.8: return "Likely"
        case 0.4..<0.6: return "Possible"
        case 0.2..<0.4: return "Unlikely"
        default: return "Very Unlikely"
        }
    }
    
    var urgencyLevel: UrgencyLevel {
        switch timeToDecision {
        case 0..<300: return .immediate  // <5 minutes
        case 300..<1800: return .urgent  // <30 minutes  
        case 1800..<7200: return .priority // <2 hours
        default: return .routine
        }
    }
}

enum UrgencyLevel {
    case immediate, urgent, priority, routine
    
    var description: String {
        switch self {
        case .immediate: return "IMMEDIATE ACTION REQUIRED"
        case .urgent: return "Urgent"
        case .priority: return "Priority"
        case .routine: return "Routine"
        }
    }
    
    var color: String {
        switch self {
        case .immediate: return "red"
        case .urgent: return "orange" 
        case .priority: return "yellow"
        case .routine: return "green"
        }
    }
}

// MARK: - Evidence Item Structure
struct EvidenceItem: Identifiable {
    let id = UUID()
    let finding: String
    let category: EvidenceCategory
    let strength: EvidenceStrength
    let confidence: Float
    let clinicalSignificance: Float
    let timestamp: Date
    
    var strengthDescription: String {
        switch strength {
        case .pathognomonic: return "Pathognomonic (Diagnostic)"
        case .highly_suggestive: return "Highly Suggestive"
        case .supportive: return "Supportive"
        case .weakly_suggestive: return "Weakly Suggestive"
        case .contradictory: return "Contradictory"
        }
    }
}

enum EvidenceCategory {
    case chief_complaint
    case history
    case physical_exam
    case vital_signs
    case symptoms
    case assessment
    case medications
    case allergies
    case social_history
    case family_history
}

enum EvidenceStrength {
    case pathognomonic      // Diagnostic
    case highly_suggestive  // Strong evidence  
    case supportive         // Moderate evidence
    case weakly_suggestive  // Weak evidence
    case contradictory      // Against diagnosis
    
    var weight: Float {
        switch self {
        case .pathognomonic: return 1.0
        case .highly_suggestive: return 0.8
        case .supportive: return 0.6
        case .weakly_suggestive: return 0.3
        case .contradictory: return -0.5
        }
    }
}

// MARK: - Documentation Guidance Structure
struct DocumentationGuidance: Identifiable {
    let id = UUID()
    let type: GuidanceType
    let title: String
    let description: String
    let priority: Priority
    let suggestion: String
    
    enum GuidanceType {
        case missing_element
        case diagnosis_specific
        case billing_optimization
        case quality_improvement
        case legal_compliance
    }
    
    enum Priority {
        case high, medium, low
        
        var color: String {
            switch self {
            case .high: return "red"
            case .medium: return "orange"
            case .low: return "blue"
            }
        }
    }
}

// MARK: - Medical Knowledge Base (Open Source)
final class MedicalKnowledgeBase {
    
    // Open source medical knowledge from standard medical references
    private let conditionDatabase: [String: ConditionInfo] = [
        "myocardial infarction": ConditionInfo(
            symptoms: ["chest pain", "shortness of breath", "nausea", "diaphoresis"],
            riskFactors: ["diabetes", "hypertension", "smoking", "hyperlipidemia"],
            baseProbability: 0.02,
            timeToDecision: 300, // 5 minutes
            icd10: "I21.9",
            billingComplexity: .high
        ),
        "stroke": ConditionInfo(
            symptoms: ["weakness", "speech problems", "facial droop", "confusion"],
            riskFactors: ["hypertension", "atrial fibrillation", "diabetes"],
            baseProbability: 0.01,
            timeToDecision: 180, // 3 minutes
            icd10: "I63.9",
            billingComplexity: .high
        ),
        "pneumonia": ConditionInfo(
            symptoms: ["cough", "fever", "shortness of breath", "chest pain"],
            riskFactors: ["age > 65", "COPD", "immunocompromised"],
            baseProbability: 0.05,
            timeToDecision: 3600, // 1 hour
            icd10: "J18.9",
            billingComplexity: .medium
        ),
        "appendicitis": ConditionInfo(
            symptoms: ["abdominal pain", "nausea", "vomiting", "fever"],
            riskFactors: ["age 10-30", "male gender"],
            baseProbability: 0.008,
            timeToDecision: 1800, // 30 minutes
            icd10: "K35.9",
            billingComplexity: .high
        ),
        "pulmonary embolism": ConditionInfo(
            symptoms: ["shortness of breath", "chest pain", "cough", "leg swelling"],
            riskFactors: ["recent surgery", "immobilization", "cancer", "pregnancy"],
            baseProbability: 0.003,
            timeToDecision: 600, // 10 minutes
            icd10: "I26.9",
            billingComplexity: .high
        )
    ]
    
    private let medicalTerms: Set<String> = [
        "chest pain", "shortness of breath", "dyspnea", "tachycardia", "bradycardia",
        "hypertension", "hypotension", "diabetes", "myocardial infarction", "stroke",
        "pneumonia", "asthma", "copd", "heart failure", "arrhythmia", "syncope",
        "nausea", "vomiting", "diarrhea", "constipation", "abdominal pain",
        "headache", "dizziness", "fatigue", "weakness", "fever", "chills"
    ]
    
    func getConditionInfo(for condition: String) -> ConditionInfo? {
        return conditionDatabase[condition.lowercased()]
    }
    
    func getRequiredDocumentation(for condition: String) -> RequiredDocumentation? {
        guard let conditionInfo = getConditionInfo(for: condition) else { return nil }
        
        return RequiredDocumentation(
            description: "Document symptoms, timeline, and risk factors for \(condition)",
            template: generateDocumentationTemplate(for: conditionInfo)
        )
    }
    
    func getBillingComplexity(for condition: String) -> BillingComplexity {
        return getConditionInfo(for: condition)?.billingComplexity ?? .low
    }
    
    func countMedicalTerms(in text: String) -> Int {
        let lowercaseText = text.lowercased()
        return medicalTerms.filter { lowercaseText.contains($0) }.count
    }
    
    private func generateDocumentationTemplate(for condition: ConditionInfo) -> String {
        return """
        HPI: Document onset (\(condition.symptoms.joined(separator: ", "))), timeline, and severity
        Risk Factors: Address \(condition.riskFactors.joined(separator: ", "))
        Assessment: Consider \(condition.icd10 ?? "condition") with clinical reasoning
        Plan: Appropriate workup and management
        """
    }
}

// MARK: - Condition Information
struct ConditionInfo {
    let symptoms: [String]
    let riskFactors: [String]
    let baseProbability: Float
    let timeToDecision: TimeInterval
    let icd10: String?
    let billingComplexity: BillingComplexity
}

enum BillingComplexity {
    case low, medium, high
}

struct RequiredDocumentation {
    let description: String
    let template: String
}

// MARK: - Bayesian Inference Engine
final class BayesianInferenceEngine {
    
    func updateHypotheses(
        newFindings: [EvidenceItem],
        priorHypotheses: [MedicalHypothesis]
    ) async -> [MedicalHypothesis] {
        
        var updatedHypotheses: [MedicalHypothesis] = []
        
        // For each possible condition, calculate updated probability
        let medicalKnowledge = MedicalKnowledgeBase()
        
        for (condition, conditionInfo) in getConditionDatabase() {
            
            // Start with base probability
            var probability = conditionInfo.baseProbability
            
            // Find existing hypothesis for this condition
            let existingHypothesis = priorHypotheses.first { $0.condition == condition }
            if let existing = existingHypothesis {
                probability = existing.probability
            }
            
            // Update probability based on new evidence using Bayes' theorem
            for finding in newFindings {
                let likelihoodRatio = calculateLikelihoodRatio(
                    finding: finding,
                    condition: condition,
                    conditionInfo: conditionInfo
                )
                
                // Bayesian update: P(H|E) = P(E|H) * P(H) / P(E)
                let posteriorOdds = (probability / (1 - probability)) * likelihoodRatio
                probability = posteriorOdds / (1 + posteriorOdds)
            }
            
            // Only include hypotheses with reasonable probability
            if probability > 0.05 {
                let hypothesis = MedicalHypothesis(
                    condition: condition,
                    probability: min(0.99, probability),
                    supportingEvidence: newFindings.filter { 
                        isEvidence($0, supportive: true, for: condition, info: conditionInfo) 
                    },
                    contradictingEvidence: newFindings.filter { 
                        isEvidence($0, supportive: false, for: condition, info: conditionInfo) 
                    },
                    clinicalScore: calculateClinicalScore(condition, evidence: newFindings),
                    requiredWorkup: generateRequiredWorkup(for: condition),
                    timeToDecision: conditionInfo.timeToDecision,
                    icd10Code: conditionInfo.icd10
                )
                
                updatedHypotheses.append(hypothesis)
            }
        }
        
        // Sort by probability (highest first)
        return updatedHypotheses.sorted { $0.probability > $1.probability }
    }
    
    private func calculateLikelihoodRatio(
        finding: EvidenceItem,
        condition: String,
        conditionInfo: ConditionInfo
    ) -> Float {
        
        // Calculate how likely this finding is given the condition
        let findingText = finding.finding.lowercased()
        
        // Check if finding matches condition symptoms
        let matchingSymptoms = conditionInfo.symptoms.filter { symptom in
            findingText.contains(symptom.lowercased())
        }
        
        if !matchingSymptoms.isEmpty {
            // Positive evidence - increases probability
            return 2.0 + finding.strength.weight
        } else if conditionInfo.symptoms.contains(where: { symptom in
            // Check for contradictory evidence
            findingText.contains("no " + symptom.lowercased()) ||
            findingText.contains("denies " + symptom.lowercased())
        }) {
            // Negative evidence - decreases probability
            return 0.3
        } else {
            // Neutral evidence
            return 1.0
        }
    }
    
    private func isEvidence(
        _ evidence: EvidenceItem,
        supportive: Bool,
        for condition: String,
        info: ConditionInfo
    ) -> Bool {
        
        let findingText = evidence.finding.lowercased()
        let hasMatchingSymptom = info.symptoms.contains { symptom in
            findingText.contains(symptom.lowercased())
        }
        
        return supportive ? hasMatchingSymptom : !hasMatchingSymptom
    }
    
    private func calculateClinicalScore(_ condition: String, evidence: [EvidenceItem]) -> Float {
        // Implement clinical scoring rules (HEART, Wells, etc.)
        switch condition.lowercased() {
        case "myocardial infarction":
            return calculateHEARTScore(evidence)
        case "pulmonary embolism":
            return calculateWellsScore(evidence)
        default:
            return 0.5 // Default clinical score
        }
    }
    
    private func calculateHEARTScore(_ evidence: [EvidenceItem]) -> Float {
        var score: Float = 0.0
        
        // HEART Score calculation (simplified)
        let findings = evidence.map { $0.finding.lowercased() }
        
        // History (0-2 points)
        if findings.contains(where: { $0.contains("chest pain") }) {
            score += findings.contains(where: { $0.contains("typical") }) ? 2.0 : 1.0
        }
        
        // Age (0-2 points)
        if findings.contains(where: { $0.contains("age") }) {
            // Simplified age scoring
            score += 1.0
        }
        
        // Risk factors (0-2 points)
        let riskFactors = ["diabetes", "hypertension", "smoking", "family history"]
        let presentRiskFactors = riskFactors.filter { risk in
            findings.contains(where: { $0.contains(risk) })
        }
        score += min(2.0, Float(presentRiskFactors.count) * 0.5)
        
        return min(10.0, score) / 10.0  // Normalize to 0-1
    }
    
    private func calculateWellsScore(_ evidence: [EvidenceItem]) -> Float {
        var score: Float = 0.0
        
        // Wells Score for PE (simplified)
        let findings = evidence.map { $0.finding.lowercased() }
        
        if findings.contains(where: { $0.contains("leg swelling") }) { score += 3.0 }
        if findings.contains(where: { $0.contains("immobilization") || $0.contains("surgery") }) { score += 1.5 }
        if findings.contains(where: { $0.contains("tachycardia") }) { score += 1.5 }
        if findings.contains(where: { $0.contains("hemoptysis") }) { score += 1.0 }
        if findings.contains(where: { $0.contains("cancer") }) { score += 1.0 }
        
        return min(12.5, score) / 12.5  // Normalize to 0-1
    }
    
    private func generateRequiredWorkup(for condition: String) -> [DiagnosticAction] {
        switch condition.lowercased() {
        case "myocardial infarction":
            return [
                DiagnosticAction(action: "12-lead EKG", urgency: .immediate),
                DiagnosticAction(action: "Cardiac enzymes (troponin)", urgency: .immediate),
                DiagnosticAction(action: "Chest X-ray", urgency: .urgent),
                DiagnosticAction(action: "CBC, BMP", urgency: .urgent)
            ]
        case "stroke":
            return [
                DiagnosticAction(action: "CT head without contrast", urgency: .immediate),
                DiagnosticAction(action: "Blood glucose", urgency: .immediate),
                DiagnosticAction(action: "NIH Stroke Scale", urgency: .immediate)
            ]
        case "pulmonary embolism":
            return [
                DiagnosticAction(action: "D-dimer", urgency: .urgent),
                DiagnosticAction(action: "CT pulmonary angiogram", urgency: .urgent),
                DiagnosticAction(action: "Arterial blood gas", urgency: .urgent)
            ]
        default:
            return []
        }
    }
    
    private func getConditionDatabase() -> [String: ConditionInfo] {
        return [
            "myocardial infarction": ConditionInfo(
                symptoms: ["chest pain", "shortness of breath", "nausea", "diaphoresis"],
                riskFactors: ["diabetes", "hypertension", "smoking", "hyperlipidemia"],
                baseProbability: 0.02,
                timeToDecision: 300,
                icd10: "I21.9",
                billingComplexity: .high
            ),
            "stroke": ConditionInfo(
                symptoms: ["weakness", "speech problems", "facial droop", "confusion"],
                riskFactors: ["hypertension", "atrial fibrillation", "diabetes"],
                baseProbability: 0.01,
                timeToDecision: 180,
                icd10: "I63.9",
                billingComplexity: .high
            ),
            "pneumonia": ConditionInfo(
                symptoms: ["cough", "fever", "shortness of breath", "chest pain"],
                riskFactors: ["age > 65", "COPD", "immunocompromised"],
                baseProbability: 0.05,
                timeToDecision: 3600,
                icd10: "J18.9",
                billingComplexity: .medium
            )
        ]
    }
}

// MARK: - Diagnostic Action Structure
struct DiagnosticAction {
    let action: String
    let urgency: UrgencyLevel
    
    var description: String {
        return "\(action) (\(urgency.description))"
    }
}

// MARK: - Clinical Evidence Extractor
final class ClinicalEvidenceExtractor {
    
    func extractFindings(_ text: String) async -> [EvidenceItem] {
        var findings: [EvidenceItem] = []
        let timestamp = Date()
        
        // Extract symptoms
        let symptoms = extractSymptoms(from: text)
        findings.append(contentsOf: symptoms.map { symptom in
            EvidenceItem(
                finding: symptom,
                category: .symptoms,
                strength: .supportive,
                confidence: 0.8,
                clinicalSignificance: calculateSignificance(for: symptom),
                timestamp: timestamp
            )
        })
        
        // Extract vital signs
        let vitals = extractVitalSigns(from: text)
        findings.append(contentsOf: vitals)
        
        // Extract medications
        let medications = extractMedications(from: text)
        findings.append(contentsOf: medications)
        
        // Extract chief complaint
        if let chiefComplaint = extractChiefComplaint(from: text) {
            findings.append(chiefComplaint)
        }
        
        return findings
    }
    
    private func extractSymptoms(from text: String) -> [String] {
        let symptomKeywords = [
            "chest pain", "shortness of breath", "nausea", "vomiting", "dizziness",
            "headache", "fatigue", "weakness", "fever", "chills", "cough",
            "abdominal pain", "back pain", "leg pain", "swelling", "rash"
        ]
        
        let lowercaseText = text.lowercased()
        return symptomKeywords.filter { lowercaseText.contains($0) }
    }
    
    private func extractVitalSigns(from text: String) -> [EvidenceItem] {
        var vitals: [EvidenceItem] = []
        let timestamp = Date()
        
        // Extract blood pressure
        let bpRegex = try? NSRegularExpression(pattern: "\\b(\\d{2,3})/(\\d{2,3})\\b")
        if let bpMatch = bpRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(bpMatch.range, in: text) {
                let bp = String(text[range])
                vitals.append(EvidenceItem(
                    finding: "Blood pressure: \(bp)",
                    category: .vital_signs,
                    strength: .supportive,
                    confidence: 0.9,
                    clinicalSignificance: 0.8,
                    timestamp: timestamp
                ))
            }
        }
        
        // Extract heart rate
        let hrRegex = try? NSRegularExpression(pattern: "\\bheart rate\\s+(\\d{2,3})\\b")
        if let hrMatch = hrRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(hrMatch.range, in: text) {
                let hr = String(text[range])
                vitals.append(EvidenceItem(
                    finding: hr,
                    category: .vital_signs,
                    strength: .supportive,
                    confidence: 0.9,
                    clinicalSignificance: 0.7,
                    timestamp: timestamp
                ))
            }
        }
        
        return vitals
    }
    
    private func extractMedications(from text: String) -> [EvidenceItem] {
        let commonMedications = [
            "aspirin", "metformin", "lisinopril", "atorvastatin", "metoprolol",
            "amlodipine", "omeprazole", "levothyroxine", "warfarin", "insulin"
        ]
        
        let lowercaseText = text.lowercased()
        let foundMeds = commonMedications.filter { lowercaseText.contains($0) }
        
        return foundMeds.map { medication in
            EvidenceItem(
                finding: "Medication: \(medication)",
                category: .medications,
                strength: .supportive,
                confidence: 0.9,
                clinicalSignificance: 0.6,
                timestamp: Date()
            )
        }
    }
    
    private func extractChiefComplaint(from text: String) -> EvidenceItem? {
        // Look for chief complaint patterns
        let ccPatterns = [
            "chief complaint", "cc:", "presents with", "complains of", "c/o"
        ]
        
        let lowercaseText = text.lowercased()
        for pattern in ccPatterns {
            if lowercaseText.contains(pattern) {
                return EvidenceItem(
                    finding: "Chief complaint identified in conversation",
                    category: .chief_complaint,
                    strength: .supportive,
                    confidence: 0.8,
                    clinicalSignificance: 0.9,
                    timestamp: Date()
                )
            }
        }
        
        return nil
    }
    
    private func calculateSignificance(for symptom: String) -> Float {
        // Calculate clinical significance of symptoms
        let highSignificanceSymptoms = ["chest pain", "shortness of breath", "weakness", "confusion"]
        let mediumSignificanceSymptoms = ["nausea", "vomiting", "dizziness", "fatigue"]
        
        if highSignificanceSymptoms.contains(symptom.lowercased()) {
            return 0.9
        } else if mediumSignificanceSymptoms.contains(symptom.lowercased()) {
            return 0.6
        } else {
            return 0.4
        }
    }
    
    private func getConditionDatabase() -> [String: ConditionInfo] {
        return [
            "myocardial infarction": ConditionInfo(
                symptoms: ["chest pain", "shortness of breath", "nausea", "diaphoresis"],
                riskFactors: ["diabetes", "hypertension", "smoking"],
                baseProbability: 0.02,
                timeToDecision: 300,
                icd10: "I21.9",
                billingComplexity: .high
            ),
            "stroke": ConditionInfo(
                symptoms: ["weakness", "speech problems", "facial droop"],
                riskFactors: ["hypertension", "atrial fibrillation"],
                baseProbability: 0.01,
                timeToDecision: 180,
                icd10: "I63.9",
                billingComplexity: .high
            ),
            "pneumonia": ConditionInfo(
                symptoms: ["cough", "fever", "shortness of breath"],
                riskFactors: ["age > 65", "COPD"],
                baseProbability: 0.05,
                timeToDecision: 3600,
                icd10: "J18.9",
                billingComplexity: .medium
            )
        ]
    }
}

// MARK: - Clinical Decision Rules
final class ClinicalDecisionRules {
    
    func checkForCriticalFindings(
        findings: [EvidenceItem],
        hypotheses: [MedicalHypothesis]
    ) async -> [ClinicalAlert] {
        
        var alerts: [ClinicalAlert] = []
        
        // Check for time-sensitive conditions
        for hypothesis in hypotheses {
            if hypothesis.urgencyLevel == .immediate && hypothesis.probability > 0.3 {
                alerts.append(ClinicalAlert(
                    condition: hypothesis.condition,
                    urgency: .immediate,
                    timeToAction: hypothesis.timeToDecision,
                    recommendedActions: hypothesis.requiredWorkup.map { $0.action },
                    evidence: hypothesis.supportingEvidence,
                    clinicalRule: "High probability time-sensitive condition"
                ))
            }
        }
        
        // Check for specific clinical patterns
        let findingTexts = findings.map { $0.finding.lowercased() }
        
        // STEMI alert
        if findingTexts.contains(where: { $0.contains("chest pain") }) &&
           findingTexts.contains(where: { $0.contains("radiating") || $0.contains("left arm") }) {
            alerts.append(ClinicalAlert(
                condition: "Possible STEMI",
                urgency: .immediate,
                timeToAction: 300, // 5 minutes
                recommendedActions: ["12-lead EKG STAT", "Cardiology consult", "Cath lab activation"],
                evidence: findings.filter { $0.finding.lowercased().contains("chest") },
                clinicalRule: "Acute coronary syndrome protocol"
            ))
        }
        
        // Stroke alert
        if findingTexts.contains(where: { $0.contains("weakness") || $0.contains("facial droop") || $0.contains("speech") }) {
            alerts.append(ClinicalAlert(
                condition: "Possible Stroke",
                urgency: .immediate,
                timeToAction: 180, // 3 minutes
                recommendedActions: ["CT head STAT", "Neurology consult", "NIH stroke scale"],
                evidence: findings.filter { $0.finding.lowercased().contains("weakness") || $0.finding.lowercased().contains("speech") },
                clinicalRule: "Stroke protocol"
            ))
        }
        
        return alerts
    }
}