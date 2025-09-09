import Foundation

// MARK: - Core Medical Types

// MARK: Encounter Types
enum EncounterType: String, CaseIterable, Codable {
    case emergency = "Emergency"
    case urgent = "Urgent Care"
    case routine = "Routine Visit"
    case followUp = "Follow-up"
    case telehealth = "Telehealth"
    case specialty = "Specialty Consultation"
    case procedure = "Procedure"
    case surgery = "Surgery"
    case general = "General"
}

enum EncounterPhase: String, Codable {
    case initial = "Initial Assessment"
    case ongoing = "Ongoing Care"
    case followup = "Follow-up"
    case discharge = "Discharge"
}

// MARK: Audio & Transcription
struct AudioBuffer {
    private var buffer: Data
    private let maxSize: Int
    
    init(maxSize: Int = 10 * 1024 * 1024) { // 10MB default
        self.buffer = Data()
        self.maxSize = maxSize
    }
    
    mutating func append(_ data: Data) {
        buffer.append(data)
        if buffer.count > maxSize {
            buffer = buffer.suffix(maxSize)
        }
    }
    
    var data: Data { buffer }
    var isEmpty: Bool { buffer.isEmpty }
}

struct CircularAudioBuffer {
    private var buffer: [Float]
    private let maxDuration: TimeInterval
    private let sampleRate: Double
    private var writeIndex: Int = 0
    
    init(maxDuration: TimeInterval, sampleRate: Double = 16000) {
        self.maxDuration = maxDuration
        self.sampleRate = sampleRate
        let bufferSize = Int(maxDuration * sampleRate)
        self.buffer = Array(repeating: 0, count: bufferSize)
    }
    
    mutating func append(_ samples: [Float]) {
        for sample in samples {
            buffer[writeIndex] = sample
            writeIndex = (writeIndex + 1) % buffer.count
        }
    }
}

struct TranscriptionBuffer {
    private var transcriptions: [TranscriptionResult] = []
    private let maxCount: Int
    
    init(maxCount: Int = 100) {
        self.maxCount = maxCount
    }
    
    mutating func append(_ result: TranscriptionResult) {
        transcriptions.append(result)
        if transcriptions.count > maxCount {
            transcriptions.removeFirst()
        }
    }
    
    var latest: TranscriptionResult {
        transcriptions.last ?? TranscriptionResult(text: "", confidence: 0, segments: [], processingTime: 0)
    }
    
    var full: TranscriptionResult {
        let combinedText = transcriptions.map { $0.text }.joined(separator: " ")
        let avgConfidence = transcriptions.map { $0.confidence }.reduce(0, +) / Double(max(transcriptions.count, 1))
        let allSegments = transcriptions.flatMap { $0.segments }
        
        return TranscriptionResult(
            text: combinedText,
            confidence: avgConfidence,
            segments: allSegments,
            processingTime: 0
        )
    }
}

// MARK: Clinical Components
struct PatientProfile {
    var id: String?
    var age: Int?
    var gender: String?
    var medicalHistory: [String] = []
    var medications: [Medication] = []
    var allergies: [Allergy] = []
    var vitalSigns: VitalSigns?
    var riskFactors: [String] = []
}

struct Medication {
    let name: String
    let dosage: String
    let frequency: String
    let route: String
    let startDate: Date?
    let endDate: Date?
    let prescriber: String?
}

struct Allergy {
    let allergen: String
    let reaction: String
    let severity: AllergySeverity
    let onsetDate: Date?
}

enum AllergySeverity: String, Codable {
    case mild, moderate, severe, lifeThreatening
}

struct VitalSigns {
    let bloodPressure: BloodPressure?
    let heartRate: Int?
    let respiratoryRate: Int?
    let temperature: Double?
    let oxygenSaturation: Int?
    let weight: Double?
    let height: Double?
    let bmi: Double?
    let timestamp: Date
}

struct BloodPressure {
    let systolic: Int
    let diastolic: Int
    
    var category: String {
        if systolic < 120 && diastolic < 80 {
            return "Normal"
        } else if systolic < 130 && diastolic < 80 {
            return "Elevated"
        } else if systolic < 140 || diastolic < 90 {
            return "Stage 1 Hypertension"
        } else {
            return "Stage 2 Hypertension"
        }
    }
}

// MARK: Clinical Timeline
struct ClinicalTimeline {
    private var events: [ClinicalEvent] = []
    
    mutating func addEvent(_ event: ClinicalEvent) {
        events.append(event)
        events.sort { $0.timestamp < $1.timestamp }
    }
    
    var earliestEvent: ClinicalEvent? {
        events.first
    }
    
    var latestEvent: ClinicalEvent? {
        events.last
    }
    
    var totalDuration: TimeInterval {
        guard let first = earliestEvent, let last = latestEvent else { return 0 }
        return last.timestamp.timeIntervalSince(first.timestamp)
    }
}

struct ClinicalEvent {
    let entity: MedicalEntity
    let timestamp: Date
    let duration: TimeInterval?
    let frequency: String?
}

struct TemporalInfo {
    let timeline: ClinicalTimeline
    let onsetTime: Date?
    let duration: TimeInterval?
    let progression: ProgressionType
}

enum ProgressionType {
    case acute, gradual, chronic, intermittent, worsening, improving, stable
}

struct TimeExpression {
    let text: String
    let range: Range<String.Index>
    let resolvedTime: Date
    let duration: TimeInterval?
    let frequency: String?
}

// MARK: Clinical Insights
struct ClinicalInsight {
    let type: InsightType
    let description: String
    let evidence: [String]
    let confidence: Double
    let actionable: Bool
}

enum InsightType {
    case diagnostic, therapeutic, prognostic, preventive
}

struct RedFlag {
    let condition: String
    let severity: Severity
    let description: String
    let recommendedActions: [String]
}

struct ClinicalAction {
    let description: String
    let rationale: String
    let priority: Priority
    let timeframe: String?
}

struct RiskFactor {
    let factor: String
    let category: String
    let modifiable: Bool
    let impact: Double
}

// MARK: Symptoms
struct SymptomCluster {
    let name: String
    let symptoms: [String]
    let possibleDiagnoses: [String]
    let urgency: Priority
}

// MARK: Diagnostics
struct Diagnostic {
    let diagnosis: String
    let icd10Code: String?
    let confidence: Double
    let evidence: [String]
    let ruledOut: [String]
}

struct DiagnosticTest {
    let name: String
    let type: TestType
    let rationale: String
    let urgency: Priority
    let expectedResults: [String]
}

enum TestType {
    case laboratory, imaging, functional, genetic, other
}

// MARK: Treatment
struct Recommendation {
    let type: RecommendationType
    let description: String
    let priority: Priority
    let evidence: String?
}

enum RecommendationType {
    case diagnostic, treatment, referral, followUp, lifestyle
}

enum EvidenceLevel: String {
    case levelA = "Level A - Multiple RCTs"
    case levelB = "Level B - Single RCT or observational"
    case levelC = "Level C - Expert opinion"
    case levelD = "Level D - Limited evidence"
}

// MARK: Care Planning
struct OrderSet {
    let name: String
    let orders: [Order]
    let indication: String
    let evidenceLevel: EvidenceLevel
}

struct Order {
    let type: OrderType
    let description: String
    let priority: Priority
    let frequency: String?
}

enum OrderType {
    case medication, laboratory, imaging, procedure, consultation, nursing
}

struct ClinicalPathway {
    let name: String
    let diagnosis: String
    let steps: [PathwayStep]
    let expectedDuration: TimeInterval
    let outcomes: [String]
}

struct PathwayStep {
    let sequence: Int
    let name: String
    let actions: [String]
    let criteria: [String]
    let duration: TimeInterval
}

struct CarePlan {
    let goals: [CareGoal]
    let interventions: [Intervention]
    let timeline: String
    let followUpSchedule: [FollowUp]
}

struct CareGoal {
    let description: String
    let measurable: Bool
    let timeframe: String
    let metrics: [String]
}

struct Intervention {
    let type: InterventionType
    let description: String
    let frequency: String
    let duration: String
}

enum InterventionType {
    case medical, nursing, therapy, education, social
}

struct FollowUp {
    let type: String
    let timeframe: String
    let provider: String?
    let reason: String
}

// MARK: Critical Actions
struct CriticalAction {
    let action: String
    let timeframe: String
    let rationale: String
    let consequences: String?
}

struct CriticalFinding {
    let finding: String
    let severity: Severity
    let immediateActions: [String]
    let notificationRequired: Bool
}

// MARK: Quality
struct QualityIssue {
    let type: QualityIssueType
    let description: String
    let impact: String
    let recommendation: String
}

enum QualityIssueType {
    case documentation, safety, compliance, efficiency, patientSatisfaction
}

// MARK: Feedback
struct ClinicalFeedback {
    let sessionID: UUID
    let actualDiagnosis: String?
    let outcomeQuality: Int // 1-5 scale
    let accuracyRating: Int // 1-5 scale
    let comments: String?
    let timestamp: Date
}

// MARK: Helper Functions
func resolveTimeExpression(_ text: String) -> Date {
    // Simplified time resolution
    let now = Date()
    
    if text.contains("ago") {
        if let match = text.firstMatch(of: /(\d+) (days?|weeks?|months?|years?) ago/) {
            let value = Int(match.1) ?? 0
            let unit = String(match.2)
            
            switch unit {
            case "day", "days":
                return now.addingTimeInterval(-Double(value) * 86400)
            case "week", "weeks":
                return now.addingTimeInterval(-Double(value) * 604800)
            case "month", "months":
                return now.addingTimeInterval(-Double(value) * 2592000)
            case "year", "years":
                return now.addingTimeInterval(-Double(value) * 31536000)
            default:
                return now
            }
        }
    }
    
    return now
}

func extractDuration(from text: String) -> TimeInterval? {
    if let match = text.firstMatch(of: /for (\d+) (days?|weeks?|months?)/) {
        let value = Double(match.1) ?? 0
        let unit = String(match.2)
        
        switch unit {
        case "day", "days":
            return value * 86400
        case "week", "weeks":
            return value * 604800
        case "month", "months":
            return value * 2592000
        default:
            return nil
        }
    }
    
    return nil
}

func extractFrequency(from text: String) -> String? {
    let frequencyPatterns = [
        "daily", "twice daily", "three times daily",
        "weekly", "monthly", "as needed", "continuous",
        "intermittent", "occasional", "frequent"
    ]
    
    for pattern in frequencyPatterns {
        if text.lowercased().contains(pattern) {
            return pattern
        }
    }
    
    return nil
}

func findAssociatedSymptoms(_ symptom: MedicalEntity, in symptoms: [MedicalEntity]) -> [String] {
    // Find symptoms that appear near this symptom
    symptoms.filter { $0.text != symptom.text }.map { $0.text }
}

func calculateOverallSeverity(_ symptoms: [SymptomDetail]) -> Double {
    guard !symptoms.isEmpty else { return 0 }
    return symptoms.map { $0.severity }.reduce(0, +) / Double(symptoms.count)
}

func identifySymptomClusters(_ symptoms: [SymptomDetail]) -> [SymptomCluster] {
    // Simplified clustering - in production use ML clustering
    var clusters: [SymptomCluster] = []
    
    // Check for common symptom patterns
    let symptomNames = Set(symptoms.map { $0.name.lowercased() })
    
    if symptomNames.contains("chest pain") && symptomNames.contains("shortness of breath") {
        clusters.append(SymptomCluster(
            name: "Cardiac Symptoms",
            symptoms: ["chest pain", "shortness of breath"],
            possibleDiagnoses: ["ACS", "PE", "Pneumonia"],
            urgency: .urgent
        ))
    }
    
    if symptomNames.contains("fever") && symptomNames.contains("cough") {
        clusters.append(SymptomCluster(
            name: "Respiratory Infection",
            symptoms: ["fever", "cough"],
            possibleDiagnoses: ["URI", "Pneumonia", "COVID-19"],
            urgency: .high
        ))
    }
    
    return clusters
}

func analyzeProgression(_ timeline: ClinicalTimeline) -> ProgressionType {
    // Analyze the timeline to determine progression pattern
    // Simplified logic - in production use more sophisticated analysis
    
    if timeline.totalDuration < 86400 { // Less than 24 hours
        return .acute
    } else if timeline.totalDuration < 604800 { // Less than 1 week
        return .gradual
    } else {
        return .chronic
    }
}