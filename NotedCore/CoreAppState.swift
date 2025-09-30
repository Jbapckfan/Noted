import Foundation
import Combine

@MainActor
final class CoreAppState: ObservableObject {
    @Published var recordingStatus: RecordingStatus = .idle
    @Published var transcription: String = ""
    @Published var transcriptionText: String = ""
    @Published var medicalNote: String = ""
    @Published var selectedNoteFormat: NoteType = .edNote
    @Published var audioLevel: Float = 0.0
    @Published var activeMicrophone: AudioSource = .builtIn
    @Published var isBluetoothAvailable: Bool = false
    @Published var isRecording: Bool = false
    @Published var recordingDuration: Int = 0
    @Published var currentRoom: String = ""
    @Published var currentChiefComplaint: String = ""
    
    // Specialty preset (default ED)
    @Published var specialty: MedicalSpecialty = .emergency
    
    // Session management
    @Published var currentSessionId: String = ""
    @Published var sessions: [MedicalSession] = []
    
    // MARK: - Zero Latency Engine
    // @Published var zeroLatencyEngine = ZeroLatencyTranscriptionEngine() // Disabled temporarily
    
    // MARK: - Ollama Medical Summarizer
    // @Published var ollamaSummarizer = OllamaMedicalSummarizer() // Disabled temporarily
    
    // MARK: - Feature Toggles
    @Published var isBillingCodeSuggestionsEnabled: Bool = false
    @Published var isClinicalToolSuggestionsEnabled: Bool = false  // Clinical calculators/tools
    @Published var isContraindicationAlertsEnabled: Bool = false  // Drug interaction alerts
    @Published var billingCodePreferences = BillingCodePreferences()
    @Published var clinicalToolPreferences = ClinicalToolPreferences()
    @Published var clinicalAlertPreferences = ClinicalAlertPreferences()
    
    static let shared = CoreAppState()
    
    // MARK: - Billing Code Preferences
    struct BillingCodePreferences {
        var showInRealTime: Bool = true
        var optimizeForRevenue: Bool = true
        var includeTimeBasedBilling: Bool = true
        var autoDetectProcedures: Bool = true
        var suggestHigherLevels: Bool = true
        var verifyMedicalNecessity: Bool = true
        var specialtyMode: MedicalSpecialty = .generalPractice
    }
    
    // MARK: - Clinical Tool Preferences
    struct ClinicalToolPreferences {
        var suggestCalculators: Bool = true
        var suggestGuidelines: Bool = true
        var suggestScores: Bool = true
        var showInRealTime: Bool = false  // Show during transcription or after
        var specialtySpecific: Bool = true
    }
    
    // MARK: - Clinical Alert Preferences
    struct ClinicalAlertPreferences {
        var enableRedFlags: Bool = true
        var enableDrugInteractions: Bool = true
        var alertSeverityThreshold: String = "moderate"
        var showCriticalAlerts: Bool = true
        var showDrugInteractions: Bool = true
        var showLabAlerts: Bool = true
        var showAllergyWarnings: Bool = true
        var showDosageAlerts: Bool = true
        var showMissingDocumentation: Bool = true
        var showMalpracticeRisks: Bool = true
        var alertSoundEnabled: Bool = true
        var alertVibrationEnabled: Bool = true
    }
    
    enum MedicalSpecialty: String, CaseIterable {
        case emergency = "Emergency Medicine"
        case hospitalMedicine = "Hospital Medicine"
        case clinic = "Clinic Medicine"
        case urgentCare = "Urgent Care"
        // Additional specialties for future expansions
        case generalPractice = "General Practice"
        case cardiology = "Cardiology"
        case psychiatry = "Psychiatry"
        case pediatrics = "Pediatrics"
        case orthopedics = "Orthopedics"
        case internalMedicine = "Internal Medicine"
    }
    
    enum RecordingStatus {
        case idle
        case recording
        case processing
        case error(String)
    }
    
    enum AudioSource {
        case builtIn
        case bluetooth(name: String)
        
        var displayName: String {
            switch self {
            case .builtIn:
                return "Built-in Microphone"
            case .bluetooth(let name):
                return "Bluetooth: \(name)"
            }
        }
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        currentSessionId = UUID().uuidString
        transcription = ""
        medicalNote = ""
        recordingStatus = .idle
    }
    
    func saveCurrentSession() {
        guard !transcription.isEmpty else { return }
        
        let session = MedicalSession(
            id: currentSessionId.isEmpty ? UUID().uuidString : currentSessionId,
            timestamp: Date(),
            transcription: transcription,
            medicalNote: medicalNote,
            noteFormat: selectedNoteFormat
        )
        
        sessions.append(session)
        
        // Keep only last 10 sessions for memory management
        if sessions.count > 10 {
            sessions.removeFirst()
        }
    }
    
    func deleteSession(_ session: MedicalSession) {
        sessions.removeAll { $0.id == session.id }
    }
    
    func loadSession(_ session: MedicalSession) {
        currentSessionId = session.id
        transcription = session.transcription
        medicalNote = session.medicalNote
        selectedNoteFormat = session.noteFormat
    }
}

// MARK: - Medical Session Model
struct MedicalSession: Identifiable, Codable {
    let id: String
    let timestamp: Date
    let transcription: String
    let medicalNote: String
    let noteFormat: NoteType
    
    var displayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "\(noteFormat.rawValue) - \(formatter.string(from: timestamp))"
    }
    
    var previewText: String {
        if !medicalNote.isEmpty {
            return String(medicalNote.prefix(100)) + (medicalNote.count > 100 ? "..." : "")
        } else {
            return String(transcription.prefix(100)) + (transcription.count > 100 ? "..." : "")
        }
    }
}

// MARK: - NoteFormat Codable Support
extension NoteType: Codable {
    enum CodingKeys: String, CodingKey {
        case edNote, soap
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let key = try container.decode(String.self)
        
        switch key {
        case "edNote": self = .edNote
        case "soap": self = .soap
        default: self = .edNote
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .edNote: try container.encode("edNote")
        case .soap: try container.encode("soap")
        case .progress: try container.encode("progress")
        case .consult: try container.encode("consult")
        case .handoff: try container.encode("handoff")
        case .discharge: try container.encode("discharge")
        }
    }
}
