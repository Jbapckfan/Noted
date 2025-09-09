import Foundation
import MLX
import MLXNN
import MLXOptimizers
import MLXRandom

/// MTS-Dialog Training Integration for Medical Note Generation
/// Dataset: https://github.com/abachaa/MTS-Dialog
@MainActor
class MTSDialogTrainer: ObservableObject {
    
    // MARK: - Training Status
    @Published var isTraining = false
    @Published var currentEpoch = 0
    @Published var totalEpochs = 10
    @Published var trainingLoss: Float = 0.0
    @Published var validationLoss: Float = 0.0
    @Published var trainingProgress: String = "Not Started"
    
    // MARK: - Dataset Structure
    struct MTSDialogSample {
        let conversation: String
        let clinicalNote: String
        let sectionHeaders: [String: String]
        let metadata: DialogMetadata
    }
    
    struct DialogMetadata {
        let id: String
        let sourceLanguage: String // en, fr, es for augmented data
        let sectionCount: Int
        let wordCount: Int
        let hasAllSections: Bool
    }
    
    // MARK: - Section Headers from MTS-Dialog
    enum ClinicalSection: String, CaseIterable {
        case chiefComplaint = "cc"
        case historyOfPresentIllness = "hpi"
        case pastMedicalHistory = "pastmedicalhx"
        case medications = "medications"
        case allergies = "allergies"
        case familySocialHistory = "fam/sochx"
        case generalHistory = "genhx"
        case reviewOfSystems = "ros"
        case physicalExam = "pe"
        case assessment = "assessment"
        case plan = "plan"
        case diagnoses = "diagnosis"
        case procedures = "procedures"
        case immunizations = "immunizations"
        case otherHistory = "otherhx"
        case labs = "labs"
        case imaging = "imaging"
        case patientInstructions = "patient_instructions"
        case disposition = "disposition"
        case edCourse = "edcourse"
        
        var displayName: String {
            switch self {
            case .chiefComplaint: return "Chief Complaint"
            case .historyOfPresentIllness: return "History of Present Illness"
            case .pastMedicalHistory: return "Past Medical History"
            case .medications: return "Medications"
            case .allergies: return "Allergies"
            case .familySocialHistory: return "Family/Social History"
            case .generalHistory: return "General History"
            case .reviewOfSystems: return "Review of Systems"
            case .physicalExam: return "Physical Exam"
            case .assessment: return "Assessment"
            case .plan: return "Plan"
            case .diagnoses: return "Diagnoses"
            case .procedures: return "Procedures"
            case .immunizations: return "Immunizations"
            case .otherHistory: return "Other History"
            case .labs: return "Laboratory Results"
            case .imaging: return "Imaging Results"
            case .patientInstructions: return "Patient Instructions"
            case .disposition: return "Disposition"
            case .edCourse: return "ED Course"
            }
        }
    }
    
    // MARK: - Data Loading
    
    func loadMTSDialogDataset() async throws -> (train: [MTSDialogSample], validation: [MTSDialogSample]) {
        // Load from downloaded dataset directory
        let basePath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/MTS-Dialog"
        
        // Load the 1,201 training samples
        let trainingSamples = try await loadDatasetSplit(basePath: basePath, fileName: "TaskA-TrainingSet.csv", count: 1201)
        
        // Load the 100 validation samples  
        let validationSamples = try await loadDatasetSplit(basePath: basePath, fileName: "TaskA-ValidationSet.csv", count: 100)
        
        // Optionally load augmented data (3.6k samples)
        if UserDefaults.standard.bool(forKey: "UseAugmentedData") {
            let augmentedSamples = try await loadAugmentedDataset()
            return (trainingSamples + augmentedSamples, validationSamples)
        }
        
        return (trainingSamples, validationSamples)
    }
    
    private func loadDatasetSplit(basePath: String, fileName: String, count: Int) async throws -> [MTSDialogSample] {
        let fullPath = "\(basePath)/\(fileName)"
        guard let url = URL(string: "file://\(fullPath)") else {
            throw TrainingError.datasetNotFound(fullPath)
        }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        
        return json.compactMap { item in
            guard let conversation = item["conversation"] as? String,
                  let note = item["note"] as? String,
                  let id = item["id"] as? String else {
                return nil
            }
            
            let sections = extractSections(from: note)
            let metadata = DialogMetadata(
                id: id,
                sourceLanguage: item["language"] as? String ?? "en",
                sectionCount: sections.count,
                wordCount: note.split(separator: " ").count,
                hasAllSections: sections.count >= 10
            )
            
            return MTSDialogSample(
                conversation: conversation,
                clinicalNote: note,
                sectionHeaders: sections,
                metadata: metadata
            )
        }
    }
    
    private func loadAugmentedDataset() async throws -> [MTSDialogSample] {
        // Load French and Spanish back-translated augmented data
        var augmented: [MTSDialogSample] = []
        let basePath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/MTS-Dialog"
        
        for language in ["fr", "es"] {
            let fileName = "mts_dialog_augmented_\(language).json"
            let samples = try await loadDatasetSplit(basePath: basePath, fileName: fileName, count: 1200)
            augmented.append(contentsOf: samples)
        }
        
        return augmented
    }
    
    // MARK: - Section Extraction
    
    private func extractSections(from note: String) -> [String: String] {
        var sections: [String: String] = [:]
        let lines = note.components(separatedBy: "\n")
        var currentSection: String?
        var currentContent = ""
        
        for line in lines {
            // Check if line is a section header
            if let section = ClinicalSection.allCases.first(where: { 
                line.lowercased().starts(with: $0.rawValue + ":") ||
                line.lowercased() == $0.rawValue
            }) {
                // Save previous section if exists
                if let prevSection = currentSection {
                    sections[prevSection] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                currentSection = section.rawValue
                currentContent = ""
            } else if currentSection != nil {
                currentContent += line + "\n"
            }
        }
        
        // Save last section
        if let lastSection = currentSection {
            sections[lastSection] = currentContent.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return sections
    }
    
    // MARK: - Training Pipeline
    
    func trainModel(
        on dataset: [MTSDialogSample],
        validation: [MTSDialogSample],
        modelPath: String = "NotedCore_MTS_Model"
    ) async throws {
        isTraining = true
        trainingProgress = "Initializing training..."
        
        // Convert samples to training format
        let trainData = prepareTrainingData(from: dataset)
        let valData = prepareTrainingData(from: validation)
        
        // Training configuration
        let config = TrainingConfig(
            batchSize: 4,
            learningRate: 5e-5,
            epochs: totalEpochs,
            warmupSteps: 100,
            gradientAccumulationSteps: 4,
            maxLength: 2048
        )
        
        // Initialize or load model
        let model = try await initializeModel(config: config)
        
        // Training loop
        for epoch in 1...config.epochs {
            currentEpoch = epoch
            trainingProgress = "Training epoch \(epoch)/\(config.epochs)"
            
            // Train on batches
            var epochLoss: Float = 0
            for batch in trainData.batched(config.batchSize) {
                let loss = try await trainStep(model: model, batch: batch, config: config)
                epochLoss += loss
            }
            
            trainingLoss = epochLoss / Float(trainData.count / config.batchSize)
            
            // Validation
            if epoch % 2 == 0 {
                validationLoss = try await validate(model: model, data: valData, config: config)
                trainingProgress = "Epoch \(epoch): Train Loss: \(String(format: "%.4f", trainingLoss)), Val Loss: \(String(format: "%.4f", validationLoss))"
            }
            
            // Save checkpoint
            if epoch % 5 == 0 {
                try await saveCheckpoint(model: model, epoch: epoch, path: modelPath)
            }
        }
        
        isTraining = false
        trainingProgress = "Training complete!"
    }
    
    // MARK: - Data Preparation
    
    private func prepareTrainingData(from samples: [MTSDialogSample]) -> [[String: Any]] {
        return samples.map { sample in
            // Format input prompt
            let prompt = createTrainingPrompt(conversation: sample.conversation)
            
            // Format target output
            let target = formatClinicalNote(sample: sample)
            
            return [
                "input": prompt,
                "output": target,
                "metadata": [
                    "id": sample.metadata.id,
                    "sections": sample.sectionHeaders.count,
                    "quality_score": calculateQualityScore(sample)
                ]
            ]
        }
    }
    
    private func createTrainingPrompt(conversation: String) -> String {
        return """
        Convert this doctor-patient conversation into a comprehensive clinical note with proper section headers.
        
        CONVERSATION:
        \(conversation)
        
        CLINICAL NOTE:
        """
    }
    
    private func formatClinicalNote(sample: MTSDialogSample) -> String {
        var note = ""
        
        // Add sections in standard order
        for section in ClinicalSection.allCases {
            if let content = sample.sectionHeaders[section.rawValue] {
                note += "**\(section.displayName.uppercased()):**\n"
                note += content + "\n\n"
            }
        }
        
        return note.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func calculateQualityScore(_ sample: MTSDialogSample) -> Float {
        var score: Float = 0.0
        
        // Section completeness (40%)
        score += Float(sample.sectionHeaders.count) / Float(ClinicalSection.allCases.count) * 0.4
        
        // Content length (30%)
        let idealLength = 500
        let lengthRatio = min(Float(sample.metadata.wordCount) / Float(idealLength), 1.0)
        score += lengthRatio * 0.3
        
        // Critical sections present (30%)
        let criticalSections: Set<String> = ["cc", "hpi", "assessment", "plan"]
        let sampleSections = Set(sample.sectionHeaders.keys)
        let criticalPresent = criticalSections.intersection(sampleSections)
        score += Float(criticalPresent.count) / Float(criticalSections.count) * 0.3
        
        return score
    }
    
    // MARK: - Model Operations
    
    private func initializeModel(config: TrainingConfig) async throws -> MLXModel {
        // Initialize or load existing model
        // This would integrate with your existing Phi3MLXService or similar
        fatalError("Implement model initialization with MLX")
    }
    
    private func trainStep(model: MLXModel, batch: [[String: Any]], config: TrainingConfig) async throws -> Float {
        // Implement training step
        fatalError("Implement training step with MLX")
    }
    
    private func validate(model: MLXModel, data: [[String: Any]], config: TrainingConfig) async throws -> Float {
        // Implement validation
        fatalError("Implement validation with MLX")
    }
    
    private func saveCheckpoint(model: MLXModel, epoch: Int, path: String) async throws {
        // Save model checkpoint
        let checkpointPath = "\(path)_epoch_\(epoch).mlx"
        // Implement checkpoint saving
    }
    
    // MARK: - Fine-tuning for Specific Use Cases
    
    func fineTuneForEmergencyMedicine(baseModel: MLXModel) async throws {
        // Filter dataset for emergency medicine cases
        let (train, val) = try await loadMTSDialogDataset()
        
        let edCases = train.filter { sample in
            // Look for ED-specific patterns
            let text = sample.conversation.lowercased()
            return text.contains("emergency") ||
                   text.contains("urgent") ||
                   text.contains("acute") ||
                   sample.sectionHeaders["edcourse"] != nil
        }
        
        // Train with ED-specific prompts
        try await trainModel(on: edCases, validation: val, modelPath: "NotedCore_ED_Model")
    }
    
    // MARK: - Evaluation Metrics
    
    func evaluateModel(on testSet: [MTSDialogSample]) async throws -> EvaluationMetrics {
        var metrics = EvaluationMetrics()
        
        for sample in testSet {
            let generated = try await generateNote(from: sample.conversation)
            
            // Calculate BLEU score
            metrics.bleuScore += calculateBLEU(reference: sample.clinicalNote, generated: generated)
            
            // Calculate section accuracy
            let generatedSections = extractSections(from: generated)
            let refKeys = Set(sample.sectionHeaders.keys)
            let genKeys = Set(generatedSections.keys)
            let sectionOverlap = Float(refKeys.intersection(genKeys).count)
            metrics.sectionAccuracy += sectionOverlap / Float(sample.sectionHeaders.count)
            
            // Medical entity extraction accuracy
            metrics.entityAccuracy += evaluateEntityExtraction(reference: sample, generated: generated)
        }
        
        // Average metrics
        let count = Float(testSet.count)
        metrics.bleuScore /= count
        metrics.sectionAccuracy /= count
        metrics.entityAccuracy /= count
        
        return metrics
    }
    
    private func generateNote(from conversation: String) async throws -> String {
        // Use trained model to generate note
        fatalError("Implement note generation with trained model")
    }
    
    private func calculateBLEU(reference: String, generated: String) -> Float {
        // Implement BLEU score calculation
        return 0.0
    }
    
    private func evaluateEntityExtraction(reference: MTSDialogSample, generated: String) -> Float {
        // Compare medical entities between reference and generated
        return 0.0
    }
    
    // MARK: - Supporting Types
    
    struct TrainingConfig {
        let batchSize: Int
        let learningRate: Float
        let epochs: Int
        let warmupSteps: Int
        let gradientAccumulationSteps: Int
        let maxLength: Int
    }
    
    struct EvaluationMetrics {
        var bleuScore: Float = 0.0
        var sectionAccuracy: Float = 0.0
        var entityAccuracy: Float = 0.0
        var perplexity: Float = 0.0
        
        var overall: Float {
            (bleuScore + sectionAccuracy + entityAccuracy) / 3.0
        }
    }
    
    enum TrainingError: Error {
        case datasetNotFound(String)
        case modelInitializationFailed
        case trainingFailed(String)
    }
    
    // MARK: - MLX Model Placeholder
    struct MLXModel {
        // Placeholder for actual MLX model integration
    }
}

// MARK: - Array Extension for Batching
extension Array {
    func batched(_ batchSize: Int) -> [[Element]] {
        stride(from: 0, to: count, by: batchSize).map {
            Array(self[$0..<Swift.min($0 + batchSize, count)])
        }
    }
}