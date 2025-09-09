import SwiftUI

struct MedicalNotesView: View {
    @StateObject private var summarizerService = EnhancedMedicalSummarizerService()
    @StateObject private var redFlagService = MedicalRedFlagService.shared
    @ObservedObject var appState: CoreAppState
    
    @State private var selectedNoteType: NoteType = .edNote
    @State private var customInstructions = ""
    @State private var showingShareSheet = false
    @State private var isGenerating = false
    @State private var encounterID = "Bed 1"
    @State private var encounterPhase: EncounterPhase = .initial
    @State private var showCopyFeedback = false
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                // PRODUCTION: Red Flag Alerts at top if critical
                if redFlagService.hasActiveCriticalFlags {
                    RedFlagAlertView()
                        .padding(.horizontal)
                }
                
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Medical Note Generation")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                    }
                    
                    Text("Transform your transcription into professional medical documentation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // Source Transcription Section (Compact)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Source Transcription")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            ScrollView {
                                Text(appState.transcriptionText.isEmpty ? "No transcription available. Start recording to generate medical notes." : appState.transcriptionText)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(appState.transcriptionText.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .frame(height: 120) // Compact height for source
                        }
                        .padding(.horizontal)
                        
                        // Generation Controls
                        VStack(spacing: 12) {
                            // Note Type and Phase Selection
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Note Format")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Picker("Note Type", selection: $selectedNoteType) {
                                        ForEach(NoteType.allCases, id: \.self) { type in
                                            Text(type.rawValue).tag(type)
                                        }
                                    }
                                    .pickerStyle(SegmentedPickerStyle())
                                }
                                
                                if selectedNoteType == .edNote {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("ED Phase")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        Picker("Phase", selection: $encounterPhase) {
                                            Text("Initial").tag(EncounterPhase.initial)
                                            Text("Follow-up").tag(EncounterPhase.followUp)
                                        }
                                        .pickerStyle(SegmentedPickerStyle())
                                    }
                                }
                            }
                            
                            // Encounter ID and Instructions
                            HStack(spacing: 16) {
                                if selectedNoteType == .edNote {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Encounter ID")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        
                                        TextField("e.g., Bed 3 - Chest pain", text: $encounterID)
                                            .textFieldStyle(RoundedBorderTextFieldStyle())
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Additional Instructions (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    TextField("e.g., Focus on cardiovascular assessment", text: $customInstructions, axis: .vertical)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .lineLimit(2...4)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Generate Button
                            Button(action: generateNote) {
                                HStack {
                                    if isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Generating Medical Note...")
                                    } else {
                                        Image(systemName: "doc.text.fill")
                                        Text("Generate Medical Note")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(canGenerate ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(!canGenerate || isGenerating)
                        }
                        .padding(.horizontal)
                        
                        // Generated Medical Note Section (MAIN FOCUS - LARGE HEIGHT)
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Generated Medical Note")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                // Action buttons
                                if !summarizerService.generatedNote.isEmpty {
                                    HStack(spacing: 12) {
                                        Button(action: copyNote) {
                                            Image(systemName: showCopyFeedback ? "checkmark" : "doc.on.doc")
                                            Text(showCopyFeedback ? "Copied!" : "Copy")
                                        }
                                        .foregroundColor(showCopyFeedback ? .green : .blue)
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                        .animation(.easeInOut(duration: 0.2), value: showCopyFeedback)
                                        
                                        Button(action: shareNote) {
                                            Image(systemName: "square.and.arrow.up")
                                            Text("Share")
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            
                            // FIXED: Large, usable text view for the generated note
                            ScrollView {
                                if summarizerService.generatedNote.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .font(.system(size: 48))
                                            .foregroundColor(.secondary)
                                        
                                        Text("Medical note will appear here")
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .foregroundColor(.secondary)
                                        
                                        Text("Start by recording a patient conversation, then generate a professional medical note using AI")
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                } else {
                                    // FIXED: Proper medical note display with adequate height
                                    Text(summarizerService.generatedNote)
                                        .font(.system(.body, design: .default))
                                        .foregroundColor(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)
                                        .textSelection(.enabled) // Allow text selection
                                }
                            }
                            .frame(minHeight: 400) // FIXED: Minimum height of 400pt instead of tiny height
                            .frame(maxHeight: geometry.size.height * 0.6) // FIXED: Up to 60% of screen height
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray4), lineWidth: 1)
                                    )
                            )
                            
                            // Status indicator
                            if summarizerService.isGenerating {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Generating medical note... This may take 15-30 seconds")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if !summarizerService.statusMessage.isEmpty && summarizerService.statusMessage != "Ready" {
                                Text(summarizerService.statusMessage)
                                    .font(.caption)
                                    .foregroundColor(summarizerService.statusMessage.contains("Error") ? .red : .secondary)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        // ShareSheet disabled for macOS build
        // .sheet(isPresented: $showingShareSheet) {
        //     ShareSheet(activityItems: [summarizerService.generatedNote])
        // }
    }
    
    // MARK: - Computed Properties
    
    private var canGenerate: Bool {
        return !appState.transcriptionText.isEmpty && !isGenerating
    }
    
    // MARK: - Actions
    
    private func generateNote() {
        guard !appState.transcriptionText.isEmpty else { return }
        
        isGenerating = true
        
        Task {
            await summarizerService.generateRealMedicalNote(
                from: appState.transcriptionText,
                noteType: selectedNoteType
            )
            
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func copyNote() {
        UIPasteboard.general.string = summarizerService.generatedNote
        
        // Show visual feedback
        showCopyFeedback = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // Reset feedback after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopyFeedback = false
        }
    }
    
    private func shareNote() {
        // showingShareSheet = true // Disabled for macOS
    }
    
    // MARK: - Helper Methods
    
    private func qualityColor(for score: Float) -> Color {
        switch score {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .yellow
        case 0.2..<0.4: return .orange
        default: return .red
        }
    }
    
    private func confidenceColor(for confidence: Float) -> Color {
        switch confidence {
        case 0.9...1.0: return .green
        case 0.8..<0.9: return .blue
        case 0.7..<0.8: return .yellow
        case 0.6..<0.7: return .orange
        default: return .red
        }
    }
}

// MARK: - ShareSheet Helper

// ShareSheet is iOS-specific, removed for macOS build
// TODO: Implement NSSharingServicePicker for macOS sharing

// MARK: - Preview

struct MedicalNotesView_Previews: PreviewProvider {
    static var previews: some View {
        MedicalNotesView(appState: CoreAppState.shared)
    }
}