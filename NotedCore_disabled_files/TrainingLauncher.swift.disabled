import Foundation

/// Simple launcher to start medical AI training
@MainActor
class TrainingLauncher: ObservableObject {
    @Published var isDownloading = false
    @Published var downloadStatus = "Ready to download datasets"
    @Published var canStartTraining = false
    
    private let trainer = UnifiedMedicalTrainer()
    
    // Check if datasets exist
    func checkDatasets() -> (mtsExists: Bool, priMockExists: Bool) {
        let mtsPath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/MTS-Dialog"
        let priMockPath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/primock57"
        
        let mtsExists = FileManager.default.fileExists(atPath: mtsPath)
        let priMockExists = FileManager.default.fileExists(atPath: priMockPath)
        
        canStartTraining = mtsExists && priMockExists
        
        if mtsExists && priMockExists {
            downloadStatus = "✅ Both datasets ready for training"
        } else if mtsExists {
            downloadStatus = "⚠️ MTS-Dialog ready, PriMock57 missing"
        } else if priMockExists {
            downloadStatus = "⚠️ PriMock57 ready, MTS-Dialog missing"
        } else {
            downloadStatus = "❌ No datasets found - run download script"
        }
        
        return (mtsExists, priMockExists)
    }
    
    // Download datasets using the script (macOS only - Process not available on iOS)
    func downloadDatasets() async {
        isDownloading = true
        downloadStatus = "📥 This feature requires running the download script manually on macOS"
        
        #if os(macOS)
        let scriptPath = "/Users/jamesalford/Documents/NotedCore/Scripts/download_datasets.sh"
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [scriptPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                downloadStatus = "✅ Datasets downloaded successfully"
                canStartTraining = true
            } else {
                downloadStatus = "❌ Download failed - check script manually"
            }
        } catch {
            downloadStatus = "❌ Error running download script: \(error.localizedDescription)"
        }
        #else
        downloadStatus = "ℹ️ Please run the download script manually in terminal"
        #endif
        
        isDownloading = false
    }
    
    // Start training process
    func startTraining() async {
        do {
            try await trainer.startUnifiedTraining()
        } catch {
            print("Training failed: \(error)")
        }
    }
    
    // Quick setup - download and train
    func quickSetupAndTrain() async {
        // First check if datasets exist
        let (mtsExists, priMockExists) = checkDatasets()
        
        // Download if needed
        if !mtsExists || !priMockExists {
            await downloadDatasets()
        }
        
        // Start training if datasets are ready
        if canStartTraining {
            await startTraining()
        }
    }
}