import Foundation

// MARK: - Core Medical Types

// Missing basic enums
enum Severity: String, Codable {
    case mild, moderate, severe, critical
    
    var numericValue: Double {
        switch self {
        case .mild: return 1.0
        case .moderate: return 2.0
        case .severe: return 3.0
        case .critical: return 4.0
        }
    }
}

enum Priority: String, Codable {
    case low, medium, high, urgent, emergency
}

struct MedicalEntity: Codable {
    let text: String
    let type: String
    let confidence: Double
}

struct SymptomDetail: Codable {
    let name: String
    let severity: Severity
    let duration: String?
    let characteristics: [String]
}

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

enum EncounterPhase: String, Codable, Hashable {
    case initial = "Initial Assessment"
    case ongoing = "Ongoing Care"
    case followup = "Follow-up"
    case followUp = "FollowUp"  // Different raw value for compatibility
    case discharge = "Discharge"
    
    var icon: String {
        switch self {
        case .initial: return "stethoscope"
        case .ongoing: return "waveform.path.ecg"
        case .followup, .followUp: return "arrow.clockwise"
        case .discharge: return "checkmark.circle"
        }
    }
}

// MARK: Audio & Transcription

// Local TranscriptionResult type (distinct from WhisperKit's)
struct LocalTranscriptionResult {
    let text: String
    let segments: [TranscriptionSegment]
    let language: String?
    let timings: TranscriptionTimings?
    let confidence: Double
    let processingTime: Double
    
    init(text: String, segments: [TranscriptionSegment] = [], language: String? = nil, timings: TranscriptionTimings? = nil, confidence: Double = 0.0, processingTime: Double = 0.0) {
        self.text = text
        self.segments = segments
        self.language = language
        self.timings = timings
        self.confidence = confidence
        self.processingTime = processingTime
    }
}

struct TranscriptionSegment: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let start: Double
    let end: Double
    var confidence: Float = 0.5
    var source: TranscriptionSource = .unknown
    var speaker: Speaker?
    var timestamp: Date
    var isEdited: Bool = false
    
    init(id: UUID = UUID(), text: String, start: Double, end: Double, confidence: Float = 0.5, source: TranscriptionSource = .unknown, speaker: Speaker? = nil, timestamp: Date = Date(), isEdited: Bool = false) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.confidence = confidence
        self.source = source
        self.speaker = speaker
        self.timestamp = timestamp
        self.isEdited = isEdited
    }
    
    enum TranscriptionSource: String, Codable, Equatable {
        case whisper
        case appleSpeech
        case ensemble
        case unknown
    }
}

struct Speaker: Codable, Equatable {
    let id: String
    let label: String
}

struct TranscriptionTimings {
    let tokensPerSecond: Double?
    let audioProcessingTime: Double?
}
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
    private var transcriptions: [LocalTranscriptionResult] = []
    private let maxCount: Int
    
    init(maxCount: Int = 100) {
        self.maxCount = maxCount
    }
    
    mutating func append(_ result: LocalTranscriptionResult) {
        transcriptions.append(result)
        if transcriptions.count > maxCount {
            transcriptions.removeFirst()
        }
    }
    
    var latest: LocalTranscriptionResult {
        transcriptions.last ?? LocalTranscriptionResult(text: "", segments: [], language: nil, timings: nil, confidence: 0, processingTime: 0)
    }
    
    var full: LocalTranscriptionResult {
        let combinedText = transcriptions.map { $0.text }.joined(separator: " ")
        let avgConfidence = transcriptions.map { $0.confidence }.reduce(0, +) / Double(max(transcriptions.count, 1))
        let allSegments = transcriptions.flatMap { $0.segments }
        
        return LocalTranscriptionResult(
            text: combinedText,
            segments: allSegments,
            language: nil,
            timings: nil,
            confidence: avgConfidence,
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

struct VitalSigns: Codable {
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

struct BloodPressure: Codable {
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
    return symptoms.map { $0.severity.numericValue }.reduce(0, +) / Double(symptoms.count)
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

// MARK: - Patient Management

struct Patient: Identifiable, Codable {
    let id: UUID
    let medicalRecordNumber: String
    let firstName: String
    let lastName: String
    let dateOfBirth: Date
    let gender: String
    let primaryInsurance: String?
    let emergencyContact: String?
    let allergies: [String]
    let medications: [String]
    let medicalHistory: [String]
    let chartLevel: ChartLevel
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    init(id: UUID = UUID(), medicalRecordNumber: String, firstName: String, lastName: String, dateOfBirth: Date, gender: String, primaryInsurance: String? = nil, emergencyContact: String? = nil, allergies: [String] = [], medications: [String] = [], medicalHistory: [String] = [], chartLevel: ChartLevel) {
        self.id = id
        self.medicalRecordNumber = medicalRecordNumber
        self.firstName = firstName
        self.lastName = lastName
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.primaryInsurance = primaryInsurance
        self.emergencyContact = emergencyContact
        self.allergies = allergies
        self.medications = medications
        self.medicalHistory = medicalHistory
        self.chartLevel = chartLevel
    }
}
struct ChartLevel: Codable {
    let currentLevel: Int
    let maxLevel: Int
    let missingElements: [String]
    let completedElements: [String]
    
    var completionPercentage: Double {
        let total = missingElements.count + completedElements.count
        guard total > 0 else { return 0 }
        return Double(completedElements.count) / Double(total)
    }
}

struct RevenueOpportunity: Identifiable {
    let id: UUID
    let type: OpportunityType
    let description: String
    let potentialRevenue: Double
    let effort: EffortLevel
    let priority: Priority
    
    enum OpportunityType: String, CaseIterable {
        case documentation = "Documentation Improvement"
        case coding = "Coding Optimization"
        case billing = "Billing Enhancement"
        case compliance = "Compliance Gap"
    }
    
    enum EffortLevel: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
}
// MARK: - Clinical Intelligence

struct ClinicalAlert: Identifiable {
    let id: UUID
    let severity: Severity
    let category: AlertCategory
    let message: String
    let timestamp: Date
    let isAcknowledged: Bool
    
    enum AlertCategory: String, CaseIterable {
        case cardiac = "Cardiac"
        case respiratory = "Respiratory"
        case neurologic = "Neurologic"
        case endocrine = "Endocrine"
        case diagnostic = "Diagnostic"
        case medication = "Medication"
        case preventive = "Preventive"
        case safety = "Safety"
    }
    
    init(severity: Severity, category: AlertCategory, message: String, isAcknowledged: Bool = false) {
        self.id = UUID()
        self.severity = severity
        self.category = category
        self.message = message
        self.timestamp = Date()
        self.isAcknowledged = isAcknowledged
    }
}

struct DetectedProcedure: Identifiable {
    let id: UUID
    let name: String
    let cptCode: String?
    let confidence: Double
    let timestamp: Date
    let context: String
    let billable: Bool
    
    init(name: String, cptCode: String? = nil, confidence: Double, context: String, billable: Bool = true) {
        self.id = UUID()
        self.name = name
        self.cptCode = cptCode
        self.confidence = confidence
        self.timestamp = Date()
        self.context = context
        self.billable = billable
    }
}

struct ShiftMetrics {
    let totalEncounters: Int
    let averageEncounterDuration: TimeInterval
    let transcriptionAccuracy: Double
    let revenueGenerated: Double
}
enum AlertUrgency: String, CaseIterable { case low, medium, high, critical }
struct PatientStatus { let status: String; let timestamp: Date }
struct DosageAlert: Identifiable { let id = UUID(); let severity: Severity; let message: String }
struct ClinicalContext { let patientAge: Int; let allergies: [String]; let conditions: [String]; let medications: [String] }
struct EncounterSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    let patientId: String
    let transcript: String
    var currentPhase: EncounterPhase
    var phases: [EncounterPhaseType: String]
    var transcriptionSegments: [TranscriptionSegment]
    var isResumable: Bool
    var selectedNoteType: NoteType
    var activeDuration: TimeInterval
    
    init(id: UUID = UUID(), startTime: Date = Date(), patientId: String, transcript: String = "", isResumable: Bool = true, selectedNoteType: NoteType = .soap, activeDuration: TimeInterval = 0) {
        self.id = id
        self.startTime = startTime
        self.patientId = patientId
        self.transcript = transcript
        self.currentPhase = .initial
        self.phases = [:]
        self.transcriptionSegments = []
        self.isResumable = isResumable
        self.selectedNoteType = selectedNoteType
        self.activeDuration = activeDuration
    }
}
enum EncounterPhaseType: String, CaseIterable, Codable, Hashable {
    case intake, examination, assessment, plan
    
    var icon: String {
        switch self {
        case .intake: return "person.text.rectangle"
        case .examination: return "stethoscope"
        case .assessment: return "brain.head.profile"
        case .plan: return "list.bullet.clipboard"
        }
    }
}
    
