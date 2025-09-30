import SwiftUI

struct MedicalNoteGeneratorView: View {
    @StateObject private var aiService = NotedCoreAIService()
    @State private var transcription: String = ""

    var body: some View {
        VStack(spacing: 20) {
            // Transcription Input
            VStack(alignment: .leading) {
                Text("Transcription")
                    .font(.headline)
                TextEditor(text: $transcription)
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }

            // Generate Button
            Button(action: {
                Task {
                    await aiService.generateMedicalNote(from: transcription)
                }
            }) {
                if aiService.isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                } else {
                    Text("Generate Medical Note")
                }
            }
            .disabled(aiService.isProcessing || transcription.isEmpty)
            .buttonStyle(.borderedProminent)

            // Chart Strength Indicator
            if let strength = aiService.chartStrength {
                ChartStrengthView(strength: strength)
            }

            // Generated Note
            if !aiService.generatedNote.isEmpty {
                VStack(alignment: .leading) {
                    Text("Generated Note")
                        .font(.headline)
                    ScrollView {
                        Text(aiService.generatedNote)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 300)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray, lineWidth: 1)
                    )

                    HStack {
                        Button("Copy") {
                            #if os(iOS)
                            UIPasteboard.general.string = aiService.generatedNote
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(aiService.generatedNote, forType: .string)
                            #endif
                        }
                        Button("Share") {
                            // Implement sharing
                        }
                    }
                }
            }

            // Error Display
            if let error = aiService.error {
                Text("Error: \(error.localizedDescription)")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

struct ChartStrengthView: View {
    let strength: ChartStrengthCalculator.ChartStrength

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Progress Bar
            HStack {
                Text("Chart Strength")
                    .font(.headline)
                Spacer()
                Text("Level \(strength.currentLevel.rawValue) → Level \(strength.achievableLevel.rawValue)")
            }

            ProgressView(value: strength.completeness)
                .progressViewStyle(LinearProgressViewStyle(tint: colorForStrength(strength.completeness)))

            // Missing Elements
            if !strength.missingElements.isEmpty {
                Text("Missing: \(strength.missingElements.prefix(3).joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            // Revenue Impact
            if strength.potentialRevenue > 0 {
                Text("Potential Revenue: +$\(String(format: "%.2f", strength.potentialRevenue))")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func colorForStrength(_ value: Double) -> Color {
        switch value {
        case 0..<0.4: return .red
        case 0.4..<0.7: return .orange
        case 0.7...1.0: return .green
        default: return .blue
        }
    }
}