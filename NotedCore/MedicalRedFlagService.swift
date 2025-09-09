import Foundation
import SwiftUI

/// Critical medical red flag detection service for identifying emergency conditions
@MainActor
final class MedicalRedFlagService: ObservableObject {
    static let shared = MedicalRedFlagService()
    
    @Published var detectedRedFlags: [DetectedRedFlag] = []
    @Published var hasActiveCriticalFlags: Bool = false
    @Published var postGenerationIssues: [PostGenerationIssue] = []
    @Published var hasContradictions: Bool = false
    
    // MARK: - Red Flag Models
    
    struct MedicalRedFlag {
        let phrases: [String]  // Multiple variations of the same concern
        let severity: Severity
        let category: EmergencyCategory
        let clinicalSignificance: String
        let recommendedAction: String
        
        enum Severity: Int, Comparable {
            case moderate = 1   // Prompt assessment needed
            case high = 2       // Urgent evaluation required
            case critical = 3   // Immediate emergency response
            
            static func < (lhs: Severity, rhs: Severity) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
            
            var color: Color {
                switch self {
                case .moderate: return .orange
                case .high: return .red
                case .critical: return Color(red: 0.8, green: 0, blue: 0)
                }
            }
            
            var displayName: String {
                switch self {
                case .moderate: return "⚠️ Moderate Risk"
                case .high: return "🚨 High Risk"
                case .critical: return "🆘 CRITICAL"
                }
            }
        }
        
        enum EmergencyCategory: String, CaseIterable {
            case cardiac = "Cardiac Emergency"
            case neurological = "Neurological Emergency"
            case respiratory = "Respiratory Emergency"
            case vascular = "Vascular Emergency"
            case sepsis = "Sepsis/Infection"
            case trauma = "Trauma"
            case obstetric = "Obstetric Emergency"
            case anaphylaxis = "Anaphylaxis"
            
            var icon: String {
                switch self {
                case .cardiac: return "❤️"
                case .neurological: return "🧠"
                case .respiratory: return "🫁"
                case .vascular: return "🩸"
                case .sepsis: return "🦠"
                case .trauma: return "🚑"
                case .obstetric: return "🤰"
                case .anaphylaxis: return "💉"
                }
            }
        }
    }
    
    struct DetectedRedFlag: Identifiable {
        let id = UUID()
        let redFlag: MedicalRedFlag
        let matchedPhrase: String
        let context: String
        let timestamp: Date
        let transcriptionSegment: String
    }
    
    struct PostGenerationIssue: Identifiable {
        let id = UUID()
        let type: IssueType
        let description: String
        let location: String  // Where in the note
        let suggestion: String
        let severity: MedicalRedFlag.Severity
        
        enum IssueType {
            case contradiction
            case missedRedFlag
            case inconsistentTiming
            case dosageError
            case missingCriticalInfo
            
            var icon: String {
                switch self {
                case .contradiction: return "⚡️"
                case .missedRedFlag: return "🚨"
                case .inconsistentTiming: return "⏱️"
                case .dosageError: return "💊"
                case .missingCriticalInfo: return "❗️"
                }
            }
            
            var displayName: String {
                switch self {
                case .contradiction: return "Contradiction Found"
                case .missedRedFlag: return "Critical Finding Missed"
                case .inconsistentTiming: return "Timeline Inconsistency"
                case .dosageError: return "Medication Issue"
                case .missingCriticalInfo: return "Missing Critical Information"
                }
            }
        }
    }
    
    // MARK: - Comprehensive Red Flag Database
    
    private let redFlags: [MedicalRedFlag] = [
        // CARDIAC EMERGENCIES
        MedicalRedFlag(
            phrases: ["crushing chest pain", "chest feels crushed", "elephant on chest", "crushing pressure chest"],
            severity: .critical,
            category: .cardiac,
            clinicalSignificance: "Classic presentation of acute myocardial infarction",
            recommendedAction: "IMMEDIATE: Activate STEMI protocol, EKG, aspirin, oxygen, IV access"
        ),
        MedicalRedFlag(
            phrases: ["tearing chest pain", "ripping chest pain", "tearing sensation chest", "chest tearing apart"],
            severity: .critical,
            category: .vascular,
            clinicalSignificance: "Pathognomonic for aortic dissection",
            recommendedAction: "IMMEDIATE: CT angiography, BP control, surgical consultation"
        ),
        MedicalRedFlag(
            phrases: ["chest pain radiating to jaw", "chest pain going to jaw", "chest pain jaw neck", "chest pain left arm jaw"],
            severity: .critical,
            category: .cardiac,
            clinicalSignificance: "Classic ACS radiation pattern",
            recommendedAction: "IMMEDIATE: EKG, troponin, aspirin, cardiology consult"
        ),
        
        // NEUROLOGICAL EMERGENCIES
        MedicalRedFlag(
            phrases: ["worst headache of my life", "worst headache ever", "worst headache i've ever had", "thunderclap headache", "sudden severe headache"],
            severity: .critical,
            category: .neurological,
            clinicalSignificance: "Subarachnoid hemorrhage until proven otherwise",
            recommendedAction: "IMMEDIATE: CT head, lumbar puncture if CT negative, neurosurgery consult"
        ),
        MedicalRedFlag(
            phrases: ["sudden vision loss", "suddenly can't see", "vision went black", "sudden blindness", "lost vision suddenly"],
            severity: .critical,
            category: .neurological,
            clinicalSignificance: "Possible stroke, retinal artery occlusion, or temporal arteritis",
            recommendedAction: "IMMEDIATE: Stroke protocol, ophthalmology consult, ESR/CRP"
        ),
        MedicalRedFlag(
            phrases: ["facial droop", "face drooping", "can't smile right", "face feels numb one side", "face weakness"],
            severity: .critical,
            category: .neurological,
            clinicalSignificance: "Stroke symptom - FAST positive",
            recommendedAction: "IMMEDIATE: Activate stroke protocol, CT head, tPA evaluation"
        ),
        MedicalRedFlag(
            phrases: ["slurred speech", "can't speak properly", "speech garbled", "talking funny", "words coming out wrong"],
            severity: .high,
            category: .neurological,
            clinicalSignificance: "Possible stroke or neurological emergency",
            recommendedAction: "URGENT: Neuro exam, stroke protocol if acute onset"
        ),
        
        // RESPIRATORY EMERGENCIES
        MedicalRedFlag(
            phrases: ["can't breathe", "cannot breathe", "no air", "drowning in air", "suffocating"],
            severity: .critical,
            category: .respiratory,
            clinicalSignificance: "Acute respiratory failure",
            recommendedAction: "IMMEDIATE: Oxygen, ABG, chest X-ray, prepare for intubation"
        ),
        MedicalRedFlag(
            phrases: ["blue lips", "lips turning blue", "blue fingers", "turning blue", "cyanotic"],
            severity: .critical,
            category: .respiratory,
            clinicalSignificance: "Hypoxemia with cyanosis",
            recommendedAction: "IMMEDIATE: High-flow oxygen, pulse ox, ABG, chest imaging"
        ),
        MedicalRedFlag(
            phrases: ["coughing blood", "blood when cough", "hemoptysis", "spitting blood", "blood in sputum"],
            severity: .high,
            category: .respiratory,
            clinicalSignificance: "Hemoptysis - possible PE, TB, malignancy",
            recommendedAction: "URGENT: Chest X-ray, CBC, coags, CT chest if massive"
        ),
        
        // VASCULAR EMERGENCIES
        MedicalRedFlag(
            phrases: ["tearing back pain", "ripping back pain", "tearing pain between shoulders", "back tearing apart"],
            severity: .critical,
            category: .vascular,
            clinicalSignificance: "Aortic dissection Type A or B",
            recommendedAction: "IMMEDIATE: CT angio, BP control, vascular surgery"
        ),
        MedicalRedFlag(
            phrases: ["cold blue leg", "leg turned cold", "can't feel leg", "leg is dead", "no pulse in leg"],
            severity: .critical,
            category: .vascular,
            clinicalSignificance: "Acute limb ischemia",
            recommendedAction: "IMMEDIATE: Vascular surgery, heparin, angiography"
        ),
        
        // SEPSIS/INFECTION
        MedicalRedFlag(
            phrases: ["high fever confusion", "fever and confused", "burning up confused", "fever altered mental"],
            severity: .critical,
            category: .sepsis,
            clinicalSignificance: "Sepsis with altered mental status",
            recommendedAction: "IMMEDIATE: Sepsis protocol, blood cultures, antibiotics within 1 hour"
        ),
        MedicalRedFlag(
            phrases: ["stiff neck fever", "neck stiff headache fever", "can't touch chin chest fever", "meningitis symptoms"],
            severity: .critical,
            category: .sepsis,
            clinicalSignificance: "Meningitis presentation",
            recommendedAction: "IMMEDIATE: LP after CT, blood cultures, empiric antibiotics"
        ),
        
        // ANAPHYLAXIS
        MedicalRedFlag(
            phrases: ["throat closing", "throat swelling shut", "can't swallow throat tight", "airway closing"],
            severity: .critical,
            category: .anaphylaxis,
            clinicalSignificance: "Anaphylaxis with airway compromise",
            recommendedAction: "IMMEDIATE: Epinephrine IM, airway management, steroids, antihistamines"
        ),
        MedicalRedFlag(
            phrases: ["whole body rash can't breathe", "hives everywhere breathing hard", "allergic reaction severe"],
            severity: .critical,
            category: .anaphylaxis,
            clinicalSignificance: "Anaphylactic reaction",
            recommendedAction: "IMMEDIATE: Epinephrine, H1/H2 blockers, steroids"
        ),
        
        // OBSTETRIC EMERGENCIES
        MedicalRedFlag(
            phrases: ["pregnant bleeding heavily", "pregnant gushing blood", "pregnant severe bleeding", "bleeding pregnant cramping"],
            severity: .critical,
            category: .obstetric,
            clinicalSignificance: "Placental abruption or placenta previa",
            recommendedAction: "IMMEDIATE: OB emergency, 2 large bore IVs, type & cross, ultrasound"
        ),
        MedicalRedFlag(
            phrases: ["pregnant severe headache", "pregnant seeing spots", "pregnant vision changes", "pregnant swelling headache"],
            severity: .critical,
            category: .obstetric,
            clinicalSignificance: "Preeclampsia/eclampsia",
            recommendedAction: "IMMEDIATE: BP check, magnesium sulfate, OB consult, delivery planning"
        ),
        
        // TRAUMA
        MedicalRedFlag(
            phrases: ["hit head lost consciousness", "knocked out", "passed out after hitting head", "head injury blacked out"],
            severity: .high,
            category: .trauma,
            clinicalSignificance: "Head trauma with LOC",
            recommendedAction: "URGENT: CT head, neuro checks, cervical spine precautions"
        ),
        MedicalRedFlag(
            phrases: ["severe abdominal pain after accident", "belly pain after crash", "stomach hurt after fall"],
            severity: .high,
            category: .trauma,
            clinicalSignificance: "Possible internal bleeding",
            recommendedAction: "URGENT: FAST exam, CT abdomen/pelvis, serial exams"
        ),
        
        // GENERAL HIGH-RISK
        MedicalRedFlag(
            phrases: ["worst pain ever", "worst pain of my life", "never felt pain like this", "10 out of 10 pain"],
            severity: .high,
            category: .cardiac,
            clinicalSignificance: "Severe pain requiring immediate evaluation",
            recommendedAction: "URGENT: Full evaluation based on location, consider serious pathology"
        ),
        MedicalRedFlag(
            phrases: ["want to die", "suicidal", "going to kill myself", "end my life", "better off dead"],
            severity: .critical,
            category: .neurological,
            clinicalSignificance: "Suicidal ideation",
            recommendedAction: "IMMEDIATE: 1:1 observation, psychiatry consult, safety assessment"
        )
    ]
    
    // MARK: - Negation Detection
    
    private let negationPhrases = [
        "no", "not", "denies", "denies any", "without", "no evidence",
        "negative for", "absence of", "free of", "ruled out", "never had"
    ]
    
    // MARK: - Public Methods
    
    func analyzeTranscription(_ text: String) -> [DetectedRedFlag] {
        let lowercasedText = text.lowercased()
        var detectedFlags: [DetectedRedFlag] = []
        
        // Split into sentences for context
        let sentences = lowercasedText.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            // Check for negation in this sentence
            let hasNegation = negationPhrases.contains { phrase in
                sentence.contains(phrase)
            }
            
            // Skip if sentence is negated (e.g., "no chest pain")
            if hasNegation {
                continue
            }
            
            // Check each red flag
            for redFlag in redFlags {
                for phrase in redFlag.phrases {
                    if sentence.contains(phrase) {
                        let contextRange = extractContext(
                            phrase: phrase,
                            from: sentence,
                            fullText: lowercasedText
                        )
                        
                        let detected = DetectedRedFlag(
                            redFlag: redFlag,
                            matchedPhrase: phrase,
                            context: contextRange,
                            timestamp: Date(),
                            transcriptionSegment: sentence.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        
                        detectedFlags.append(detected)
                        
                        // Log for debugging
                        Logger.medicalAIInfo("🚨 RED FLAG DETECTED: \(phrase) - Severity: \(redFlag.severity)")
                        
                        break // Don't match multiple phrases from same red flag
                    }
                }
            }
        }
        
        // Update published properties
        self.detectedRedFlags = detectedFlags
        self.hasActiveCriticalFlags = detectedFlags.contains { $0.redFlag.severity == .critical }
        
        // Sort by severity
        return detectedFlags.sorted { $0.redFlag.severity > $1.redFlag.severity }
    }
    
    private func extractContext(phrase: String, from sentence: String, fullText: String) -> String {
        // Get 50 characters before and after the phrase for context
        if let range = sentence.range(of: phrase) {
            let startIndex = sentence.index(range.lowerBound, offsetBy: -50, limitedBy: sentence.startIndex) ?? sentence.startIndex
            let endIndex = sentence.index(range.upperBound, offsetBy: 50, limitedBy: sentence.endIndex) ?? sentence.endIndex
            return String(sentence[startIndex..<endIndex])
        }
        return sentence
    }
    
    func clearFlags() {
        detectedRedFlags = []
        hasActiveCriticalFlags = false
        postGenerationIssues = []
        hasContradictions = false
    }
    
    // MARK: - Post-Generation Analysis
    
    func analyzeGeneratedNote(_ note: String) async {
        var issues: [PostGenerationIssue] = []
        
        // 1. Check for contradictions
        let contradictions = detectContradictions(in: note)
        issues.append(contentsOf: contradictions)
        
        // 2. Check for missed red flags (comparing with original transcript if available)
        let missedFlags = detectMissedRedFlags(in: note)
        issues.append(contentsOf: missedFlags)
        
        // 3. Check for timing inconsistencies
        let timingIssues = detectTimingInconsistencies(in: note)
        issues.append(contentsOf: timingIssues)
        
        // 4. Check for dosage/medication errors
        let medicationIssues = detectMedicationIssues(in: note)
        issues.append(contentsOf: medicationIssues)
        
        // 5. Check for missing critical information
        let missingInfo = detectMissingCriticalInfo(in: note)
        issues.append(contentsOf: missingInfo)
        
        // Update published properties
        await MainActor.run {
            self.postGenerationIssues = issues
            self.hasContradictions = !contradictions.isEmpty
        }
    }
    
    private func detectContradictions(in note: String) -> [PostGenerationIssue] {
        var issues: [PostGenerationIssue] = []
        let lines = note.components(separatedBy: .newlines)
        
        // Common contradiction patterns
        let contradictionPatterns: [(String, String, String)] = [
            ("denies chest pain", "chest pain", "Patient both denies and reports chest pain"),
            ("no fever", "febrile", "Contradiction: Patient described as both afebrile and febrile"),
            ("no allergies", "allergic to", "Contradiction: Allergy status inconsistent"),
            ("denies", "positive for", "Contradictory symptom reporting"),
            ("normal vital signs", "hypotensive", "Vital signs contradiction"),
            ("stable", "deteriorating", "Clinical status contradiction")
        ]
        
        for (pattern1, pattern2, description) in contradictionPatterns {
            let hasPattern1 = note.lowercased().contains(pattern1)
            let hasPattern2 = note.lowercased().contains(pattern2)
            
            if hasPattern1 && hasPattern2 {
                // Find the specific lines
                let line1 = lines.first { $0.lowercased().contains(pattern1) } ?? ""
                let line2 = lines.first { $0.lowercased().contains(pattern2) } ?? ""
                
                issues.append(PostGenerationIssue(
                    type: .contradiction,
                    description: description,
                    location: "Lines containing: '\(pattern1)' and '\(pattern2)'",
                    suggestion: "Review and reconcile: \(line1.prefix(50))... vs \(line2.prefix(50))...",
                    severity: .high
                ))
            }
        }
        
        return issues
    }
    
    private func detectMissedRedFlags(in note: String) -> [PostGenerationIssue] {
        var issues: [PostGenerationIssue] = []
        
        // Check if critical symptoms are mentioned but not highlighted
        let criticalTerms = [
            "crushing chest pain": "STEMI protocol should be activated",
            "worst headache": "Consider subarachnoid hemorrhage workup",
            "sudden vision loss": "Ophthalmology emergency consultation needed",
            "severe abdominal pain": "Consider surgical abdomen"
        ]
        
        for (term, action) in criticalTerms {
            if note.lowercased().contains(term) {
                // Check if the action is mentioned
                if !note.lowercased().contains(action.lowercased()) {
                    issues.append(PostGenerationIssue(
                        type: .missedRedFlag,
                        description: "Critical finding '\(term)' not properly addressed",
                        location: "In clinical narrative",
                        suggestion: action,
                        severity: .critical
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func detectTimingInconsistencies(in note: String) -> [PostGenerationIssue] {
        var issues: [PostGenerationIssue] = []
        
        // Extract time references
        let timePattern = #"(\d+)\s*(hours?|minutes?|days?|weeks?)\s*ago"#
        
        if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) {
            let matches = regex.matches(in: note, range: NSRange(location: 0, length: note.count))
            
            var timeReferences: [(Int, String, String)] = []
            
            for match in matches {
                if let range = Range(match.range, in: note) {
                    let timeStr = String(note[range])
                    if match.numberOfRanges >= 2,
                       let numberRange = Range(match.range(at: 1), in: note),
                       let number = Int(note[numberRange]) {
                        timeReferences.append((number, timeStr, String(note[range])))
                    }
                }
            }
            
            // Check for logical inconsistencies
            for i in 0..<timeReferences.count {
                for j in i+1..<timeReferences.count {
                    if timeReferences[i].1.contains("hour") && timeReferences[j].1.contains("day") {
                        if timeReferences[i].0 > 24 {
                            issues.append(PostGenerationIssue(
                                type: .inconsistentTiming,
                                description: "Timeline inconsistency detected",
                                location: "Time references",
                                suggestion: "Review: '\(timeReferences[i].2)' seems inconsistent with '\(timeReferences[j].2)'",
                                severity: .moderate
                            ))
                        }
                    }
                }
            }
        }
        
        return issues
    }
    
    private func detectMedicationIssues(in note: String) -> [PostGenerationIssue] {
        var issues: [PostGenerationIssue] = []
        
        // Common medication dosage ranges (simplified)
        let medicationRanges: [String: (min: Int, max: Int, unit: String)] = [
            "metformin": (500, 2000, "mg"),
            "aspirin": (81, 325, "mg"),
            "lisinopril": (5, 40, "mg"),
            "metoprolol": (25, 200, "mg")
        ]
        
        for (drug, range) in medicationRanges {
            if note.lowercased().contains(drug) {
                // Try to extract dosage
                let pattern = drug + #"\s*(\d+)\s*(mg|mcg|units?)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: note, range: NSRange(location: 0, length: note.count))
                    
                    for match in matches {
                        if match.numberOfRanges >= 2,
                           let doseRange = Range(match.range(at: 1), in: note),
                           let dose = Int(note[doseRange]) {
                            
                            if dose < range.min || dose > range.max {
                                issues.append(PostGenerationIssue(
                                    type: .dosageError,
                                    description: "Unusual dosage for \(drug): \(dose)\(range.unit)",
                                    location: "Medications section",
                                    suggestion: "Typical range: \(range.min)-\(range.max)\(range.unit). Verify if intentional.",
                                    severity: .high
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        return issues
    }
    
    private func detectMissingCriticalInfo(in note: String) -> [PostGenerationIssue] {
        var issues: [PostGenerationIssue] = []
        
        // Only check for sections that SHOULD be present from conversation
        // Note: This app documents conversations, not EMR data
        let requiredSections: [(String, String)] = [
            ("chief complaint", "Chief complaint/presenting problem"),
            ("history", "History of present illness"),
            ("assessment", "Clinical assessment")
            // Removed vital signs - not available from conversation alone
            // Plan is optional as it may be determined later
        ]
        
        for (keyword, description) in requiredSections {
            if !note.lowercased().contains(keyword) {
                issues.append(PostGenerationIssue(
                    type: .missingCriticalInfo,
                    description: "Missing: \(description)",
                    location: "Note structure", 
                    suggestion: "Consider adding \(description) if discussed",
                    severity: .moderate
                ))
            }
        }
        
        return issues
    }
    
    func generateRedFlagSummary() -> String {
        guard !detectedRedFlags.isEmpty else {
            return "No red flags detected."
        }
        
        let criticalFlags = detectedRedFlags.filter { $0.redFlag.severity == .critical }
        let highFlags = detectedRedFlags.filter { $0.redFlag.severity == .high }
        let moderateFlags = detectedRedFlags.filter { $0.redFlag.severity == .moderate }
        
        var summary = "⚠️ **CLINICAL ALERTS DETECTED** ⚠️\n\n"
        
        if !criticalFlags.isEmpty {
            summary += "🆘 **CRITICAL RED FLAGS:**\n"
            for flag in criticalFlags {
                summary += "• \(flag.redFlag.category.icon) \(flag.matchedPhrase.capitalized)\n"
                summary += "  → \(flag.redFlag.clinicalSignificance)\n"
                summary += "  → ACTION: \(flag.redFlag.recommendedAction)\n\n"
            }
        }
        
        if !highFlags.isEmpty {
            summary += "🚨 **HIGH PRIORITY FLAGS:**\n"
            for flag in highFlags {
                summary += "• \(flag.matchedPhrase.capitalized): \(flag.redFlag.clinicalSignificance)\n"
            }
            summary += "\n"
        }
        
        if !moderateFlags.isEmpty {
            summary += "⚠️ **MODERATE CONCERNS:**\n"
            for flag in moderateFlags {
                summary += "• \(flag.matchedPhrase.capitalized)\n"
            }
        }
        
        return summary
    }
}

// MARK: - SwiftUI View for Red Flags

struct RedFlagAlertView: View {
    @ObservedObject var service = MedicalRedFlagService.shared
    @State private var showingDetails = false
    
    var body: some View {
        if service.hasActiveCriticalFlags {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title)
                    
                    Text("CRITICAL RED FLAGS DETECTED")
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button(action: { showingDetails.toggle() }) {
                        Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                    }
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
                
                if showingDetails {
                    ForEach(service.detectedRedFlags.filter { $0.redFlag.severity == .critical }) { flag in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(flag.redFlag.category.icon + " " + flag.redFlag.category.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(flag.matchedPhrase.capitalized)
                                .font(.headline)
                            
                            Text(flag.redFlag.clinicalSignificance)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Text("ACTION: " + flag.redFlag.recommendedAction)
                                .font(.caption2)
                                .padding(4)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .animation(.easeInOut, value: showingDetails)
        }
    }
}