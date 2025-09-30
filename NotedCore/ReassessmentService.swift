import SwiftUI
import Combine

/// Service for handling quick reassessments and MDM discussions
@MainActor
final class ReassessmentService: ObservableObject {
    static let shared = ReassessmentService()
    
    // MARK: - Published Properties
    @Published var isRecordingReassessment = false
    @Published var reassessmentText = ""
    @Published var mdmSummary = ""
    @Published var planPoints: [String] = []
    @Published var dispositionDecision = ""
    @Published var timestamp = Date()
    
    // MARK: - Reassessment Types
    enum ReassessmentType: String, CaseIterable {
        case mdmDiscussion = "MDM Discussion"
        case planReview = "Plan Review"
        case dispositionDecision = "Disposition Decision"
        case patientQuestions = "Patient Questions"
        case followUp = "Follow-up Instructions"
        
        var icon: String {
            switch self {
            case .mdmDiscussion: return "🧠"
            case .planReview: return "📋"
            case .dispositionDecision: return "🏥"
            case .patientQuestions: return "❓"
            case .followUp: return "📅"
            }
        }
    }
    
    @Published var currentType: ReassessmentType = .mdmDiscussion
    
    // MARK: - Quick MDM Generation
    func generateQuickMDM(from transcription: String) -> String {
        var mdm = "**REASSESSMENT/MDM UPDATE**\n"
        mdm += "Time: \(formatTime(timestamp))\n\n"
        
        // Extract key discussion points
        let sentences = transcription.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Look for decision-making content
        let decisionSentences = sentences.filter { sent in
            sent.lowercased().contains("decided") ||
            sent.lowercased().contains("plan") ||
            sent.lowercased().contains("going to") ||
            sent.lowercased().contains("will") ||
            sent.lowercased().contains("recommend") ||
            sent.lowercased().contains("think") ||
            sent.lowercased().contains("likely")
        }
        
        if !decisionSentences.isEmpty {
            mdm += "**Clinical Thinking:**\n"
            mdm += decisionSentences.joined(separator: " ") + "\n\n"
        }
        
        // Extract action items
        let actionSentences = sentences.filter { sent in
            sent.lowercased().contains("order") ||
            sent.lowercased().contains("get") ||
            sent.lowercased().contains("start") ||
            sent.lowercased().contains("consult") ||
            sent.lowercased().contains("admit") ||
            sent.lowercased().contains("discharge")
        }
        
        if !actionSentences.isEmpty {
            mdm += "**Actions:**\n"
            for (index, action) in actionSentences.enumerated() {
                mdm += "\(index + 1). \(action)\n"
            }
            mdm += "\n"
        }
        
        // Patient discussion points
        let patientSentences = sentences.filter { sent in
            sent.lowercased().contains("explained") ||
            sent.lowercased().contains("discussed") ||
            sent.lowercased().contains("told") ||
            sent.lowercased().contains("patient") ||
            sent.lowercased().contains("questions")
        }
        
        if !patientSentences.isEmpty {
            mdm += "**Patient Discussion:**\n"
            mdm += patientSentences.joined(separator: " ") + "\n\n"
        }
        
        // Disposition if mentioned
        if let disposition = sentences.first(where: { 
            $0.lowercased().contains("admit") || 
            $0.lowercased().contains("discharge") ||
            $0.lowercased().contains("home") ||
            $0.lowercased().contains("observation")
        }) {
            mdm += "**Disposition:** \(disposition)\n"
        }
        
        return mdm
    }
    
    // MARK: - Plan Points Extraction
    func extractPlanPoints(from text: String) -> [String] {
        var points: [String] = []
        
        let patterns = [
            "will (.*?)\\.",
            "going to (.*?)\\.",
            "plan to (.*?)\\.",
            "recommend (.*?)\\.",
            "should (.*?)\\.",
            "need to (.*?)\\."
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let point = String(text[range])
                        if !point.isEmpty && point.count < 100 {
                            points.append(point.capitalized)
                        }
                    }
                }
            }
        }
        
        return points
    }
    
    // MARK: - Append to Existing Note
    func appendReassessmentToNote(_ existingNote: String, reassessment: String) -> String {
        var updatedNote = existingNote
        
        // Find where to insert reassessment (before discharge instructions if present)
        if let dischargeRange = updatedNote.range(of: "**Discharge Instructions:**") {
            updatedNote.insert(contentsOf: "\n" + reassessment + "\n", at: dischargeRange.lowerBound)
        } else {
            // Append at end
            updatedNote += "\n\n" + reassessment
        }
        
        return updatedNote
    }
    
    // MARK: - Time-stamped Updates
    func createTimeStampedUpdate(_ text: String, type: ReassessmentType) -> String {
        var update = "\n---\n"
        update += "\(type.icon) **\(type.rawValue)** - \(formatTime(Date()))\n"
        update += text
        update += "\n"
        
        return update
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Reassessment View
struct ReassessmentView: View {
    @StateObject private var service = ReassessmentService.shared
    @StateObject private var audioService = AudioCaptureService()
    @State private var transcribedText = ""
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerSection
            
            // Type Selector
            typeSelector
            
            // Recording Section
            recordingSection
            
            // Transcribed Text
            if !transcribedText.isEmpty {
                transcribedSection
            }
            
            // Generated MDM
            if !service.mdmSummary.isEmpty {
                mdmSection
            }
            
            // Plan Points
            if !service.planPoints.isEmpty {
                planSection
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading) {
            Text("Quick Reassessment")
                .font(.largeTitle)
                .bold()
            
            Text("Record MDM discussion or plan review without generating full note")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var typeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(ReassessmentService.ReassessmentType.allCases, id: \.self) { type in
                    Button(action: { service.currentType = type }) {
                        HStack {
                            Text(type.icon)
                            Text(type.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(service.currentType == type ? Color.blue : Color.gray.opacity(0.2))
                        .foregroundColor(service.currentType == type ? .white : .primary)
                        .cornerRadius(15)
                    }
                }
            }
        }
    }
    
    private var recordingSection: some View {
        VStack {
            Button(action: toggleRecording) {
                HStack {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading) {
                        Text(isRecording ? "Recording..." : "Start Reassessment")
                            .font(.headline)
                        Text(service.currentType.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isRecording ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .cornerRadius(10)
            }
            .foregroundColor(isRecording ? .red : .blue)
        }
    }
    
    private var transcribedSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Transcription")
                    .font(.headline)
                Spacer()
                Button("Generate MDM") {
                    generateMDM()
                }
                .buttonStyle(.bordered)
            }
            
            TextEditor(text: $transcribedText)
                .frame(height: 150)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
    
    private var mdmSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("MDM Summary")
                    .font(.headline)
                Spacer()
                Button(action: copyMDM) {
                    Image(systemName: "doc.on.doc")
                }
            }
            
            ScrollView {
                Text(service.mdmSummary)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 200)
            .padding()
            .background(Color.green.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private var planSection: some View {
        VStack(alignment: .leading) {
            Text("Extracted Plan Points")
                .font(.headline)
            
            ForEach(service.planPoints, id: \.self) { point in
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text(point)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
    
    private func toggleRecording() {
        if isRecording {
            // Stop recording
            audioService.stop()
            isRecording = false
            
            // Simulate transcription result
            transcribedText = CoreAppState.shared.transcriptionText
            
        } else {
            // Start recording
            Task {
                try? await audioService.start()
                isRecording = true
                transcribedText = ""
                service.mdmSummary = ""
                service.planPoints = []
            }
        }
    }
    
    private func generateMDM() {
        service.mdmSummary = service.generateQuickMDM(from: transcribedText)
        service.planPoints = service.extractPlanPoints(from: transcribedText)
    }
    
    private func copyMDM() {
        #if os(iOS)
        UIPasteboard.general.string = service.mdmSummary
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(service.mdmSummary, forType: .string)
        #endif
    }
}

// MARK: - Integration with ContentView
extension ContentView {
    var reassessmentButton: some View {
        Button(action: { /* showReassessment = true */ }) {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Quick Reassessment")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.2))
            .cornerRadius(8)
        }
        // .sheet(isPresented: $showReassessment) {
        //     ReassessmentView()
        // }
    }
}