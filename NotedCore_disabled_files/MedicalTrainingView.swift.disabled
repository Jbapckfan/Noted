import SwiftUI
import Charts

struct MedicalTrainingView: View {
    @StateObject private var trainer = UnifiedMedicalTrainer()
    @StateObject private var verifier = DatasetVerifier()
    @State private var showAdvancedSettings = false
    @State private var trainingConfig = UnifiedMedicalTrainer.TrainingConfiguration()
    @State private var showDatasetInfo = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header with status
                trainingHeaderSection
                
                // Dataset verification section
                datasetVerificationSection
                
                // Progress and metrics
                if trainer.currentPhase != .idle {
                    trainingProgressSection
                }
                
                // Dataset information
                datasetInfoSection
                
                // Training controls
                trainingControlsSection
                
                // Advanced settings
                if showAdvancedSettings {
                    advancedSettingsSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("AI Training")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                Task {
                    await verifier.verifyDatasets()
                }
            }
        }
    }
    
    // MARK: - Dataset Verification Section
    
    private var datasetVerificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Dataset Status")
                    .font(.headline)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await verifier.verifyDatasets()
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading) {
                        Text("MTS-Dialog")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("1,700+ emergency medicine conversations")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(verifier.mtsStatus.description)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(verifier.mtsStatus.isReady ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(verifier.mtsStatus.isReady ? .green : .orange)
                        .cornerRadius(6)
                }
                
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading) {
                        Text("PriMock57")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("57 primary care consultations + audio")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(verifier.priMockStatus.description)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(verifier.priMockStatus.isReady ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                        .foregroundColor(verifier.priMockStatus.isReady ? .green : .orange)
                        .cornerRadius(6)
                }
            }
            
            Text(verifier.overallStatus)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(verifier.mtsStatus.isReady && verifier.priMockStatus.isReady ? .green : .orange)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Header Section
    
    private var trainingHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: trainer.currentPhase == .idle ? "brain.head.profile" : "brain.head.profile.fill")
                    .font(.title2)
                    .foregroundColor(trainer.currentPhase == .idle ? .blue : .green)
                
                VStack(alignment: .leading) {
                    Text("Medical AI Training")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(trainer.statusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 8)
                            .scaleEffect(trainer.currentPhase == .idle ? 1 : 1.5)
                            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: trainer.currentPhase)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
    
    private var statusColor: Color {
        switch trainer.currentPhase {
        case .idle: return .gray
        case .loadingData, .preprocessing: return .orange
        case .baseTraining, .finetuning: return .blue
        case .evaluation: return .purple
        case .completed: return .green
        case .failed(_): return .red
        }
    }
    
    // MARK: - Progress Section
    
    private var trainingProgressSection: some View {
        VStack(spacing: 16) {
            // Overall progress
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Training Progress")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(trainer.overallProgress * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: trainer.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                
                Text("Phase: \(trainer.currentPhase.description)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current epoch info
            if trainer.currentEpoch > 0 {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Epoch")
                        Text("\(trainer.currentEpoch)/\(trainer.totalEpochs)")
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Loss")
                        Text(String(format: "%.4f", trainer.trainingMetrics.combinedLoss))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Metrics chart
            if trainer.trainingMetrics.bleuScore > 0 {
                metricsChartSection
            }
        }
    }
    
    private var metricsChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance Metrics")
                .font(.headline)
            
            Chart {
                BarMark(
                    x: .value("Metric", "BLEU Score"),
                    y: .value("Value", trainer.trainingMetrics.bleuScore)
                )
                .foregroundStyle(.blue)
                
                BarMark(
                    x: .value("Metric", "Clinical Accuracy"),
                    y: .value("Value", trainer.trainingMetrics.clinicalAccuracy)
                )
                .foregroundStyle(.green)
                
                BarMark(
                    x: .value("Metric", "Validation Acc."),
                    y: .value("Value", trainer.trainingMetrics.validationAccuracy)
                )
                .foregroundStyle(.purple)
            }
            .frame(height: 120)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Dataset Info Section
    
    private var datasetInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Training Datasets")
                    .font(.headline)
                
                Spacer()
                
                Button("Details") {
                    showDatasetInfo.toggle()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                DatasetCard(
                    title: "MTS-Dialog",
                    subtitle: "1,700 conversations",
                    description: "Emergency medicine dialogues with clinical notes",
                    icon: "stethoscope",
                    color: .red
                )
                
                DatasetCard(
                    title: "PriMock57",
                    subtitle: "57 consultations",
                    description: "Primary care consultations with audio transcripts",
                    icon: "person.text.rectangle",
                    color: .green
                )
            }
            
            if trainer.trainingMetrics.totalSamples > 0 {
                Text("Total: \(trainer.trainingMetrics.totalSamples) training samples")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .sheet(isPresented: $showDatasetInfo) {
            DatasetDetailView()
        }
    }
    
    // MARK: - Training Controls Section
    
    private var trainingControlsSection: some View {
        VStack(spacing: 12) {
            // Main training button
            Button(action: handleTrainingAction) {
                HStack {
                    Image(systemName: trainingButtonIcon)
                    Text(trainingButtonText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(trainingButtonColor)
                .foregroundColor(.white)
                .fontWeight(.semibold)
                .cornerRadius(12)
            }
            .disabled(trainer.currentPhase == .baseTraining || 
                     trainer.currentPhase == .finetuning ||
                     !verifier.mtsStatus.isReady ||
                     !verifier.priMockStatus.isReady)
            
            // Secondary controls
            HStack(spacing: 12) {
                Button("Advanced") {
                    showAdvancedSettings.toggle()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .cornerRadius(8)
                
                if trainer.currentPhase != .idle && trainer.currentPhase != .completed {
                    Button("Stop") {
                        trainer.stopTraining()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                if trainer.currentPhase == .completed {
                    Button("Export Model") {
                        exportModel()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var trainingButtonText: String {
        switch trainer.currentPhase {
        case .idle: return "Start Training"
        case .loadingData: return "Loading Data..."
        case .preprocessing: return "Preprocessing..."
        case .baseTraining: return "Training Model..."
        case .finetuning: return "Fine-tuning..."
        case .evaluation: return "Evaluating..."
        case .completed: return "Training Complete"
        case .failed(_): return "Retry Training"
        }
    }
    
    private var trainingButtonIcon: String {
        switch trainer.currentPhase {
        case .idle, .failed(_): return "play.fill"
        case .completed: return "checkmark.circle.fill"
        default: return "arrow.triangle.2.circlepath"
        }
    }
    
    private var trainingButtonColor: Color {
        switch trainer.currentPhase {
        case .idle, .failed(_): return .blue
        case .completed: return .green
        default: return .gray
        }
    }
    
    // MARK: - Advanced Settings Section
    
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Settings")
                .font(.headline)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Epochs")
                    Spacer()
                    Stepper("\(trainingConfig.epochs)", value: $trainingConfig.epochs, in: 5...50)
                }
                
                HStack {
                    Text("Batch Size")
                    Spacer()
                    Picker("Batch Size", selection: $trainingConfig.batchSize) {
                        ForEach([2, 4, 8, 16], id: \.self) { size in
                            Text("\(size)").tag(size)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 120)
                }
                
                HStack {
                    Text("Learning Rate")
                    Spacer()
                    Text(String(format: "%.0e", trainingConfig.learningRate))
                        .foregroundColor(.secondary)
                }
                
                Toggle("Use Augmented Data", isOn: $trainingConfig.useAugmentedData)
                Toggle("Include Audio Features", isOn: $trainingConfig.includeAudioFeatures)
                Toggle("Filter Low Quality", isOn: $trainingConfig.filterLowQuality)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Actions
    
    private func handleTrainingAction() {
        switch trainer.currentPhase {
        case .idle, .failed(_):
            startTraining()
        case .completed:
            break // Could show model info or export options
        default:
            break // Training in progress
        }
    }
    
    private func startTraining() {
        Task {
            do {
                try await trainer.startUnifiedTraining(config: trainingConfig)
            } catch {
                print("Training failed: \(error)")
            }
        }
    }
    
    private func exportModel() {
        // Implement model export functionality
        print("Exporting trained model...")
    }
}

// MARK: - Supporting Views

struct DatasetCard: View {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Spacer()
            }
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(color)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DatasetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MTS-Dialog details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MTS-Dialog Dataset")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("1,700 doctor-patient conversations with clinical notes from emergency medicine encounters.")
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("• Training samples:")
                                Spacer()
                                Text("1,201")
                            }
                            HStack {
                                Text("• Validation samples:")
                                Spacer()
                                Text("100")
                            }
                            HStack {
                                Text("• Clinical sections:")
                                Spacer()
                                Text("20 normalized")
                            }
                            HStack {
                                Text("• Augmented data:")
                                Spacer()
                                Text("3,600 samples")
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // PriMock57 details
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PriMock57 Dataset")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("57 mock primary care consultations with audio recordings, manual transcripts, and clinical notes.")
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("• Audio recordings:")
                                Spacer()
                                Text("57 files")
                            }
                            HStack {
                                Text("• Manual transcripts:")
                                Spacer()
                                Text("High quality")
                            }
                            HStack {
                                Text("• Clinical notes:")
                                Spacer()
                                Text("Physician-written")
                            }
                            HStack {
                                Text("• Human evaluations:")
                                Spacer()
                                Text("Quality ratings")
                            }
                        }
                        .font(.caption)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Dataset Details")
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

// MARK: - Preview

#Preview {
    MedicalTrainingView()
}