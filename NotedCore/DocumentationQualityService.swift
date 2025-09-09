import Foundation
import SwiftUI
import Combine

// MARK: - Documentation Quality Models
enum DocumentationLevel: String, CaseIterable {
    case level1 = "L1"
    case level2 = "L2" 
    case level3 = "L3"
    case level4 = "L4"
    case level5 = "L5"
    
    var color: Color {
        switch self {
        case .level1, .level2: return .red
        case .level3: return .yellow
        case .level4, .level5: return .green
        }
    }
    
    var description: String {
        switch self {
        case .level1: return "Problem Focused (99212)"
        case .level2: return "Expanded Problem Focused (99213)"
        case .level3: return "Detailed (99214)"
        case .level4: return "Comprehensive (99215)"
        case .level5: return "Comprehensive High Complexity (99215)"
        }
    }
    
    var billingSuggestion: String {
        switch self {
        case .level1: return "Add 1-2 HPI elements for Level 2"
        case .level2: return "Add 2-3 HPI elements for Level 3" 
        case .level3: return "Add 1-2 HPI elements for Level 4 (+$50)"
        case .level4: return "Excellent documentation level"
        case .level5: return "Outstanding comprehensive documentation"
        }
    }
}

struct HPIAnalysis {
    let presentElements: [String]
    let missingElements: [String] 
    let level: DocumentationLevel
    let elementsCount: Int
    
    init(transcription: String) {
        let analysis = HPIAnalyzer.analyze(transcription)
        self.presentElements = analysis.present
        self.missingElements = analysis.missing
        self.elementsCount = analysis.present.count
        
        // Determine level based on HPI elements
        switch analysis.present.count {
        case 0...1: self.level = .level1
        case 2...3: self.level = .level2
        case 4...5: self.level = .level3
        case 6...7: self.level = .level4
        case 8...: self.level = .level5
        default: self.level = .level1
        }
    }
}

// MARK: - Fast HPI Analyzer (Pattern-Based)
struct HPIAnalyzer {
    static func analyze(_ text: String) -> (present: [String], missing: [String]) {
        let lowercaseText = text.lowercased()
        var presentElements: [String] = []
        
        // 1. Location - Where is the symptom?
        let locationKeywords = ["pain in", "located", "area", "region", "chest", "abdomen", "head", "arm", "leg", "back", "left", "right", "side"]
        if locationKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Location")
        }
        
        // 2. Quality/Character - What does it feel like?
        let qualityKeywords = ["sharp", "dull", "aching", "burning", "stabbing", "throbbing", "cramping", "pressure", "squeezing", "tearing", "crushing"]
        if qualityKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Quality")
        }
        
        // 3. Severity - How severe? (1-10 scale)
        let severityKeywords = ["severe", "mild", "moderate", "pain scale", "/10", "out of 10", "1-10", "rate", "intensity", "scale of"]
        if severityKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Severity")
        }
        
        // 4. Duration - How long?
        let durationKeywords = ["since", "for", "started", "began", "hours", "days", "weeks", "months", "years", "minutes", "ongoing", "chronic"]
        if durationKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Duration")
        }
        
        // 5. Timing - When does it occur?
        let timingKeywords = ["constant", "intermittent", "comes and goes", "episodic", "continuous", "periodic", "worse at night", "morning", "evening"]
        if timingKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Timing")
        }
        
        // 6. Context - What were you doing?
        let contextKeywords = ["after", "during", "while", "when", "activity", "exercise", "eating", "bending", "lifting", "walking", "sitting"]
        if contextKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Context")
        }
        
        // 7. Modifying Factors - What makes it better/worse?
        let modifyingKeywords = ["better with", "worse with", "relieves", "aggravates", "improves", "worsens", "medication", "rest", "movement", "helps"]
        if modifyingKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Modifying Factors")
        }
        
        // 8. Associated Symptoms - Other symptoms?
        let associatedKeywords = ["nausea", "vomiting", "sweating", "shortness of breath", "dizziness", "numbness", "tingling", "weakness", "also", "associated"]
        if associatedKeywords.contains(where: { lowercaseText.contains($0) }) {
            presentElements.append("Associated Symptoms")
        }
        
        let allElements = ["Location", "Quality", "Severity", "Duration", "Timing", "Context", "Modifying Factors", "Associated Symptoms"]
        let missingElements = allElements.filter { !presentElements.contains($0) }
        
        return (present: presentElements, missing: missingElements)
    }
}

// MARK: - Documentation Quality Service
@MainActor
class DocumentationQualityService: ObservableObject {
    @Published var currentAnalysis: HPIAnalysis?
    @Published var isAnalyzing = false
    
    private var analysisTimer: Timer?
    private var lastAnalyzedText = ""
    
    func analyzeTranscription(_ text: String) {
        // Only analyze if content has changed significantly
        guard text != lastAnalyzedText && text.count > 20 else { return }
        
        // Cancel existing timer
        analysisTimer?.invalidate()
        analysisTimer = nil
        
        // Debounce - wait for pause in transcription
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] timer in
            Task { @MainActor in
                self?.performAnalysis(text)
                timer.invalidate()
            }
        }
    }
    
    private func performAnalysis(_ text: String) {
        isAnalyzing = true
        lastAnalyzedText = text
        
        // Fast pattern-based analysis
        let analysis = HPIAnalysis(transcription: text)
        
        // Smooth animation
        withAnimation(.easeInOut(duration: 0.5)) {
            currentAnalysis = analysis
            isAnalyzing = false
        }
        
        Logger.log(.info, category: .general, message: "Documentation quality: \(analysis.level.rawValue) with \(analysis.elementsCount) HPI elements")
    }
    
    func clearAnalysis() {
        analysisTimer?.invalidate()
        analysisTimer = nil
        currentAnalysis = nil
        lastAnalyzedText = ""
    }
    
    deinit {
        analysisTimer?.invalidate()
    }
}

// MARK: - Color Bar Component
struct DocumentationQualityBar: View {
    let analysis: HPIAnalysis?
    let isAnalyzing: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            if let analysis = analysis {
                // Quality color bar
                Rectangle()
                    .fill(analysis.level.color)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: analysis.level.color)
                    .overlay(
                        // Subtle shimmer effect when analyzing
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.3), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .scaleEffect(x: isAnalyzing ? 1 : 0, anchor: .leading)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: isAnalyzing)
                    )
            } else {
                // Placeholder bar
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .cornerRadius(2)
    }
}

// MARK: - Quality Status Badge
struct QualityStatusBadge: View {
    let analysis: HPIAnalysis?
    let isAnalyzing: Bool
    @State private var showingDetails = false
    
    var body: some View {
        HStack(spacing: 6) {
            if let analysis = analysis {
                // Level indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(analysis.level.color)
                        .frame(width: 8, height: 8)
                    
                    Text(analysis.level.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("(\(analysis.elementsCount)/8)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .onTapGesture {
                    showingDetails = true
                }
            }
            
            // Analysis indicator
            if isAnalyzing {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 12, height: 12)
            }
        }
        .sheet(isPresented: $showingDetails) {
            if let analysis = analysis {
                QualityDetailsSheet(analysis: analysis)
            }
        }
    }
}

// MARK: - Quality Details Sheet
struct QualityDetailsSheet: View {
    let analysis: HPIAnalysis
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Overall status
                HStack {
                    Circle()
                        .fill(analysis.level.color)
                        .frame(width: 20, height: 20)
                    
                    VStack(alignment: .leading) {
                        Text(analysis.level.description)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(analysis.level.billingSuggestion)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                
                // HPI Elements
                VStack(alignment: .leading, spacing: 12) {
                    Text("HPI Elements (\(analysis.elementsCount)/8)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Present elements
                    if !analysis.presentElements.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("✅ Documented:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            ForEach(analysis.presentElements, id: \.self) { element in
                                Text("• \(element)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    
                    // Missing elements
                    if !analysis.missingElements.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⚠️ Missing for higher level:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            ForEach(analysis.missingElements.prefix(3), id: \.self) { element in
                                Text("• \(element)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Documentation Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Enhanced Transcription View
struct TranscriptionViewWithQualityBar: View {
    let transcriptionText: String
    let qualityService: DocumentationQualityService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with quality status
            HStack {
                Text("Live Transcription")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Quality status badge (only shows when there's analysis)
                QualityStatusBadge(
                    analysis: qualityService.currentAnalysis,
                    isAnalyzing: qualityService.isAnalyzing
                )
            }
            
            // Transcription with quality bar
            VStack(alignment: .leading, spacing: 0) {
                // Quality bar (4px colored bar)
                DocumentationQualityBar(
                    analysis: qualityService.currentAnalysis,
                    isAnalyzing: qualityService.isAnalyzing
                )
                
                // Transcription content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if transcriptionText.isEmpty {
                            Text("Start recording to see live transcription...")
                                .foregroundColor(.secondary)
                                .italic()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        } else {
                            Text(transcriptionText)
                                .font(.body)
                                .textSelection(.enabled)
                                .lineSpacing(4)
                        }
                    }
                    .padding()
                }
                .frame(minHeight: 200)
            }
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .onChange(of: transcriptionText) { _, newValue in
            // Analyze transcription for quality
            qualityService.analyzeTranscription(newValue)
        }
    }
}