import Foundation

/// Verifies that medical training datasets are properly downloaded and accessible
@MainActor
class DatasetVerifier: ObservableObject {
    
    @Published var mtsStatus: DatasetStatus = .checking
    @Published var priMockStatus: DatasetStatus = .checking
    @Published var overallStatus: String = "Checking datasets..."
    
    enum DatasetStatus {
        case checking
        case found(fileCount: Int)
        case missing
        case error(String)
        
        var description: String {
            switch self {
            case .checking: return "Checking..."
            case .found(let count): return "✅ Found (\(count) files)"
            case .missing: return "❌ Missing"
            case .error(let message): return "⚠️ Error: \(message)"
            }
        }
        
        var isReady: Bool {
            if case .found = self { return true }
            return false
        }
    }
    
    private let basePath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets"
    
    func verifyDatasets() async {
        await verifyMTSDialog()
        await verifyPriMock57()
        updateOverallStatus()
    }
    
    private func verifyMTSDialog() async {
        let mtsPath = "\(basePath)/MTS-Dialog"
        
        guard FileManager.default.fileExists(atPath: mtsPath) else {
            mtsStatus = .missing
            return
        }
        
        do {
            // Check for key files
            let contents = try FileManager.default.contentsOfDirectory(atPath: mtsPath)
            
            // Look for training data files (CSV or JSON)
            let dataFiles = contents.filter { 
                $0.lowercased().contains("train") || 
                $0.lowercased().contains("data") ||
                $0.hasSuffix(".csv") ||
                $0.hasSuffix(".json")
            }
            
            if dataFiles.isEmpty {
                // Check subdirectories
                let subdirs = contents.filter { item in
                    let fullPath = "\(mtsPath)/\(item)"
                    var isDir: ObjCBool = false
                    FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)
                    return isDir.boolValue
                }
                
                var totalFiles = 0
                for subdir in subdirs {
                    let subdirPath = "\(mtsPath)/\(subdir)"
                    if let subContents = try? FileManager.default.contentsOfDirectory(atPath: subdirPath) {
                        totalFiles += subContents.count
                    }
                }
                
                mtsStatus = totalFiles > 0 ? .found(fileCount: totalFiles) : .missing
            } else {
                mtsStatus = .found(fileCount: dataFiles.count)
            }
            
        } catch {
            mtsStatus = .error(error.localizedDescription)
        }
    }
    
    private func verifyPriMock57() async {
        let priMockPath = "\(basePath)/primock57"
        
        guard FileManager.default.fileExists(atPath: priMockPath) else {
            priMockStatus = .missing
            return
        }
        
        do {
            // Check for expected subdirectories
            let expectedDirs = ["audio", "transcripts", "notes"]
            var foundFiles = 0
            
            for dir in expectedDirs {
                let dirPath = "\(priMockPath)/\(dir)"
                if FileManager.default.fileExists(atPath: dirPath) {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: dirPath)
                    foundFiles += contents.count
                }
            }
            
            if foundFiles > 0 {
                priMockStatus = .found(fileCount: foundFiles)
            } else {
                // Check root directory for files
                let contents = try FileManager.default.contentsOfDirectory(atPath: priMockPath)
                priMockStatus = contents.isEmpty ? .missing : .found(fileCount: contents.count)
            }
            
        } catch {
            priMockStatus = .error(error.localizedDescription)
        }
    }
    
    private func updateOverallStatus() {
        let mtsReady = mtsStatus.isReady
        let priMockReady = priMockStatus.isReady
        
        if mtsReady && priMockReady {
            overallStatus = "🎉 Both datasets ready for training!"
        } else if mtsReady {
            overallStatus = "⚠️ MTS-Dialog ready, PriMock57 missing"
        } else if priMockReady {
            overallStatus = "⚠️ PriMock57 ready, MTS-Dialog missing" 
        } else {
            overallStatus = "❌ Datasets not found - please run download script"
        }
    }
    
    // Get detailed file information
    func getDatasetDetails() -> (mts: [String], priMock: [String]) {
        var mtsFiles: [String] = []
        var priMockFiles: [String] = []
        
        // MTS-Dialog details
        let mtsPath = "\(basePath)/MTS-Dialog"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: mtsPath) {
            mtsFiles = contents.sorted()
        }
        
        // PriMock57 details
        let priMockPath = "\(basePath)/primock57"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: priMockPath) {
            priMockFiles = contents.sorted()
        }
        
        return (mtsFiles, priMockFiles)
    }
    
    // Count total samples available for training
    func countTrainingSamples() async -> (mts: Int, priMock: Int) {
        var mtsCount = 0
        var priMockCount = 0
        
        // Count MTS-Dialog samples
        let mtsPath = "\(basePath)/MTS-Dialog"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: mtsPath) {
            for file in contents {
                if file.hasSuffix(".csv") || file.hasSuffix(".json") {
                    let filePath = "\(mtsPath)/\(file)"
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
                       let string = String(data: data, encoding: .utf8) {
                        // Rough count of lines/entries
                        mtsCount += string.components(separatedBy: .newlines).count
                    }
                }
            }
        }
        
        // Count PriMock57 samples (should be 57)
        let priMockPath = "\(basePath)/primock57/transcripts"
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: priMockPath) {
            priMockCount = contents.filter { $0.hasSuffix(".txt") }.count
        }
        
        return (mtsCount, priMockCount)
    }
}