import Foundation
import Combine

@MainActor
final class PatientService: ObservableObject {
    static let shared = PatientService()
    
    @Published var patients: [Patient] = []
    @Published var activePatient: Patient?
    @Published var shiftMetrics: ShiftMetrics
    @Published var notifications: [ClinicalAlert] = []
    @Published var revenueOpportunities: [RevenueOpportunity] = []
    
    private let providerId = "dr_sarah_chen"
    
    private init() {
        self.shiftMetrics = ShiftMetrics(
            totalEncounters: 0,
            averageEncounterDuration: 0,
            transcriptionAccuracy: 0.95,
            revenueGenerated: 0.0
        )
        
        loadSampleData()
        startShiftTimer()
    }
    
    // MARK: - Patient Management
    
    func addPatient(_ patient: Patient) {
        patients.append(patient)
        // shiftMetrics.patientsSeenCount += 1 // TODO: Update when ShiftMetrics is expanded
        updateShiftMetrics()
    }
    
    func updatePatient(_ patient: Patient) {
        if let index = patients.firstIndex(where: { $0.id == patient.id }) {
            patients[index] = patient
        }
    }
    
    func setActivePatient(_ patient: Patient) {
        activePatient = patient
    }
    
    func dischargePatient(_ patientId: UUID) {
        if let index = patients.firstIndex(where: { $0.id == patientId }) {
            // patients[index].status = .discharged // TODO: Add status field to Patient
            // shiftMetrics.completedDischarges += 1 // TODO: Update when ShiftMetrics is expanded
            updateShiftMetrics()
        }
    }
    
    // MARK: - Clinical Intelligence
    
    func analyzePatientChart(_ patient: Patient) -> ChartLevel {
        // Simulate chart analysis
        let completionPercentage = Int.random(in: 75...95)
        let currentLevel = Int.random(in: 3...4)
        let potentialLevel = min(5, currentLevel + (completionPercentage < 85 ? 1 : 0))
        
        let missingElements = completionPercentage < 85 ? ["Social History"] : []
        
        return ChartLevel(
            currentLevel: currentLevel,
            maxLevel: potentialLevel,
            missingElements: missingElements,
            completedElements: completionPercentage >= 85 ? ["HPI", "ROS", "Physical Exam", "Assessment"] : ["HPI", "ROS", "Physical Exam"]
        )
    }
    
    func detectProcedureInTranscription(_ transcription: String) -> [DetectedProcedure] {
        var procedures: [DetectedProcedure] = []
        
        // Simple procedure detection patterns
        let procedurePatterns = [
            ("sutur", "Complex Laceration Repair", "13132", 4.66, 150.0),
            ("stitch", "Simple Laceration Repair", "12001", 2.11, 68.0),
            ("drain", "Incision and Drainage", "10060", 2.58, 83.0),
            ("splint", "Splint Application", "29125", 1.27, 41.0),
            ("inject", "Joint Injection", "20610", 1.94, 62.0)
        ]
        
        let lowercased = transcription.lowercased()
        
        for (pattern, name, cpt, rvu, revenue) in procedurePatterns {
            if lowercased.contains(pattern) {
                let procedure = DetectedProcedure(
                    name: name,
                    cptCode: cpt,
                    confidence: 0.85,
                    context: transcription
                )
                procedures.append(procedure)
            }
        }
        
        return procedures
    }
    
    private func generateProcedureNote(_ procedureName: String, _ cptCode: String) -> String {
        return """
        PROCEDURE: \(procedureName)
        CPT: \(cptCode)
        
        INDICATION: [Auto-detected from transcription]
        CONSENT: Verbal consent obtained after discussion of risks and benefits
        TECHNIQUE: Standard sterile technique employed
        
        PROCEDURE DETAILS:
        [To be completed by provider]
        
        COMPLICATIONS: None
        DISPOSITION: Tolerated well
        """
    }
    
    // MARK: - Revenue Optimization
    
    func generateRevenueOpportunities(for patient: Patient) -> [RevenueOpportunity] {
        var opportunities: [RevenueOpportunity] = []
        
        if patient.chartLevel.missingElements.contains("Social History") {
            opportunities.append(RevenueOpportunity(
                id: UUID(),
                type: .documentation,
                description: "Add social history to upgrade to Level \(patient.chartLevel.maxLevel)",
                potentialRevenue: 52.0,
                effort: .low,
                priority: .high
            ))
        }
        
        // Add other opportunity types
        if patient.chartLevel.completionPercentage < 90 {
            opportunities.append(RevenueOpportunity(
                id: UUID(),
                type: .documentation,
                description: "Complete ROS documentation",
                potentialRevenue: 25.0,
                effort: .low,

                priority: .medium
            ))
        }
        
        return opportunities
    }
    
    // MARK: - Notifications & Alerts
    
    func generateClinicalAlerts() {
        // Simulate smart notifications
        // Commented out until ClinicalDecisionAlerts is available
        /*
        let alertTypes: [(ClinicalDecisionAlerts.AlertType, String, ClinicalDecisionAlerts.AlertSeverity)] = [
            (.sepsis, "Room 8 meets sepsis criteria - Begin bundle?", .high),
            (.criticalValue, "Critical troponin result - Room 5", .critical),
            (.procedureOpportunity, "Undocumented procedure detected - Room 3", .medium),
            (.revenueOpportunity, "Chart optimization available - Room 12", .low)
        ]
        
        for (type, message, severity) in alertTypes where Bool.random() {
            let alert = ClinicalAlert(
                type: type,
                severity: severity,
                title: message,
                message: message,
                timestamp: Date()
            )
            notifications.append(alert)
        }
        */
        
        // Keep only recent notifications
        notifications = Array(notifications.suffix(10))
    }
    
    // MARK: - Shift Management
    
    private func updateShiftMetrics() {
        // TODO: Update metrics when ShiftMetrics is expanded
        // let totalRVUs = patients.reduce(0.0) { $0 + $1.rvuValue }
        // let avgLevel = patients.isEmpty ? 0.0 : patients.reduce(0.0) { $0 + Double($1.chartLevel.currentLevel) } / Double(patients.count)
        // let hourlyRate = shiftMetrics.rvuPerHour * 32.74 // 2024 conversion factor
        
        // shiftMetrics.totalRVUs = totalRVUs
        // shiftMetrics.averageLevel = avgLevel
        // shiftMetrics.hourlyRate = hourlyRate
    }
    
    private func startShiftTimer() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.generateClinicalAlerts()
                self?.updateShiftMetrics()
            }
        }
    }
    
    // MARK: - Sample Data
    
    private func loadSampleData() {
        let samplePatients = [
            Patient(
                id: UUID(),
                medicalRecordNumber: "MRN001",
                firstName: "John",
                lastName: "Smith",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -67, to: Date()) ?? Date(),
                gender: "M",
                primaryInsurance: "Blue Cross",
                emergencyContact: "Jane Smith (555-0123)",
                allergies: ["Penicillin"],
                medications: ["Metoprolol", "Lisinopril"],
                medicalHistory: ["Hypertension", "Hyperlipidemia"],
                chartLevel: ChartLevel(
                    currentLevel: 4,
                    maxLevel: 5,
                    missingElements: ["Social History"],
                    completedElements: ["HPI", "ROS", "Physical Exam", "MDM"]
                )
            ),
            Patient(
                id: UUID(),
                medicalRecordNumber: "MRN002",
                firstName: "Mary",
                lastName: "Johnson",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -34, to: Date()) ?? Date(),
                gender: "F",
                primaryInsurance: "United Healthcare",
                emergencyContact: "Bob Johnson (555-0124)",
                allergies: [],
                medications: ["Birth Control"],
                medicalHistory: ["None"],
                chartLevel: ChartLevel(
                    currentLevel: 5,
                    maxLevel: 5,
                    missingElements: [],
                    completedElements: ["HPI", "ROS", "Physical Exam", "MDM", "Social History"]
                )
            ),
            Patient(
                id: UUID(),
                medicalRecordNumber: "MRN003",
                firstName: "Emma",
                lastName: "Davis",
                dateOfBirth: Calendar.current.date(byAdding: .year, value: -28, to: Date()) ?? Date(),
                gender: "F",
                primaryInsurance: "Aetna",
                emergencyContact: "Mark Davis (555-0125)",
                allergies: ["Sulfa"],
                medications: [],
                medicalHistory: ["Asthma"],
                chartLevel: ChartLevel(
                    currentLevel: 3,
                    maxLevel: 3,
                    missingElements: [],
                    completedElements: ["HPI", "Physical Exam", "MDM"]
                )
            )
        ]
        
        patients = samplePatients
        activePatient = samplePatients.first
        // shiftMetrics.patientsSeenCount = samplePatients.count // TODO: Add patientsSeenCount to ShiftMetrics
        updateShiftMetrics()
    }
}