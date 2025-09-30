import SwiftUI

/// Simplified training view that uses pattern extraction instead of ML training
struct SimplifiedTrainingView: View {
    @StateObject private var trainer = SimplifiedMedicalImprover()
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Medical Note Pattern Learning")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Learn from MTS-Dialog dataset without ML training")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            // Status Card
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: trainer.improvementComplete ? "checkmark.circle.fill" : "brain")
                        .font(.system(size: 40))
                        .foregroundColor(trainer.improvementComplete ? .green : .blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(trainer.statusMessage)
                            .font(.headline)
                    }
                    
                    Spacer()
                }
                
                if trainer.isAnalyzing {
                    ProgressView(value: trainer.progress) {
                        Text("Progress: \(Int(trainer.progress * 100))%")
                            .font(.caption)
                    }
                    .progressViewStyle(.linear)
                }
                
                if trainer.patternsLearned > 0 {
                    HStack {
                        Label("\(trainer.patternsLearned) patterns learned", systemImage: "doc.text.magnifyingglass")
                            .foregroundColor(.green)
                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Dataset Check
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Dataset Requirements", systemImage: "folder")
                        .font(.headline)
                    
                    Text("• MTS-Dialog: 1,700 medical conversations")
                    Text("• Location: MedicalDatasets/MTS-Dialog/")
                    Text("• Size: ~2MB CSV files")
                }
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    Task {
                        await trainer.downloadDatasets()
                    }
                }) {
                    Label("Check Datasets", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    Task {
                        await trainer.analyzeAndLearnPatterns()
                    }
                }) {
                    Label("Learn Patterns", systemImage: "brain")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(trainer.isAnalyzing)
            }
            .padding(.horizontal)
            
            // Information Box
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How This Works")
                        .font(.headline)
                    
                    Text("Unlike ML training which requires GPUs and MLX frameworks, this approach:")
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("✓ Analyzes MTS-Dialog examples")
                        Text("✓ Extracts common patterns")
                        Text("✓ Improves text extraction rules")
                        Text("✓ No GPU or MLX required")
                        Text("✓ Instant results")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .alert("Training Status", isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: trainer.improvementComplete) { completed in
            if completed {
                alertMessage = "Successfully learned \(trainer.patternsLearned) patterns from MTS-Dialog dataset!"
                showingAlert = true
            }
        }
    }
}

#Preview {
    SimplifiedTrainingView()
}