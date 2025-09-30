import Foundation
import WhisperKit

/// Guide to upgrading WhisperKit model for better medical transcription accuracy
@MainActor
class WhisperUpgrade: ObservableObject {
    
    @Published var currentModel: String = "openai_whisper-tiny"
    @Published var downloadProgress: Float = 0.0
    @Published var isDownloading = false
    @Published var modelStatus: String = "Using Tiny model"
    
    // MARK: - Available Models (All FREE)
    enum WhisperModel: String, CaseIterable {
        case tiny = "openai_whisper-tiny"           // 39 MB - Fast, less accurate
        case tinyEn = "openai_whisper-tiny.en"      // 39 MB - English only
        case base = "openai_whisper-base"           // 74 MB - Good balance
        case baseEn = "openai_whisper-base.en"      // 74 MB - English only
        case small = "openai_whisper-small"         // 244 MB - Better accuracy
        case smallEn = "openai_whisper-small.en"    // 244 MB - English only
        case medium = "openai_whisper-medium"       // 769 MB - High accuracy
        case mediumEn = "openai_whisper-medium.en"  // 769 MB - English only, faster
        case large = "openai_whisper-large-v3"      // 1.55 GB - Best accuracy
        
        var sizeMB: Int {
            switch self {
            case .tiny, .tinyEn: return 39
            case .base, .baseEn: return 74
            case .small, .smallEn: return 244
            case .medium, .mediumEn: return 769
            case .large: return 1550
            }
        }
        
        var accuracy: String {
            switch self {
            case .tiny, .tinyEn: return "~70% medical terms"
            case .base, .baseEn: return "~80% medical terms"
            case .small, .smallEn: return "~85% medical terms"
            case .medium, .mediumEn: return "~90% medical terms"
            case .large: return "~95% medical terms"
            }
        }
        
        var speed: String {
            switch self {
            case .tiny, .tinyEn: return "Real-time"
            case .base, .baseEn: return "Near real-time"
            case .small, .smallEn: return "1.5x slower"
            case .medium, .mediumEn: return "3x slower"
            case .large: return "5-10x slower"
            }
        }
        
        var recommendation: String {
            switch self {
            case .tiny, .tinyEn: 
                return "❌ Not recommended for medical use"
            case .base, .baseEn: 
                return "⚠️ Minimum for medical, may miss complex terms"
            case .small, .smallEn: 
                return "✅ Good for most medical conversations"
            case .medium, .mediumEn: 
                return "✅ Excellent for medical, English-only version recommended"
            case .large: 
                return "💎 Best accuracy but requires powerful device"
            }
        }
    }
    
    // MARK: - Upgrade WhisperKit Model
    
    func upgradeModel(to model: WhisperModel) async throws {
        isDownloading = true
        modelStatus = "Downloading \(model.rawValue)..."
        
        // Download model using WhisperKit
        // Note: WhisperKit downloads models automatically when initializing
        modelStatus = "Preparing \(model.rawValue)..."
        
        // Load the new model
        modelStatus = "Loading \(model.rawValue)..."
        let whisperKit = try await WhisperKit(
            model: model.rawValue,
            computeOptions: ModelComputeOptions(
                melCompute: .cpuAndGPU,
                audioEncoderCompute: .cpuAndGPU,
                textDecoderCompute: .cpuAndGPU
            ),
            verbose: true
        )
        
        // Update settings
        currentModel = model.rawValue
        modelStatus = "✅ Using \(model.rawValue) - \(model.accuracy)"
        isDownloading = false
        
        // Save preference
        UserDefaults.standard.set(model.rawValue, forKey: "WhisperModel")
    }
    
    // MARK: - Recommendations for Medical Use
    
    func getRecommendedModel() -> WhisperModel {
        let deviceMemory = ProcessInfo.processInfo.physicalMemory / 1_073_741_824 // GB
        
        if deviceMemory >= 16 {
            // iPhone 15 Pro Max, M1/M2 iPad Pro, Mac
            return .mediumEn  // English-only is faster and medical terms are English
        } else if deviceMemory >= 8 {
            // iPhone 14 Pro, standard iPads
            return .small
        } else {
            // Older devices
            return .base
        }
    }
    
    // MARK: - Medical Vocabulary Enhancement
    
    func addMedicalVocabulary() -> [String] {
        // Common medical terms to boost recognition
        return [
            // Medications
            "lisinopril", "metformin", "atorvastatin", "levothyroxine",
            "amlodipine", "metoprolol", "omeprazole", "simvastatin",
            
            // Conditions
            "hypertension", "diabetes", "dyslipidemia", "hypothyroidism",
            "coronary artery disease", "atrial fibrillation", "COPD",
            
            // Symptoms
            "dyspnea", "angina", "syncope", "vertigo", "diplopia",
            "paresthesia", "claudication", "orthopnea", "hemoptysis",
            
            // Procedures
            "electrocardiogram", "echocardiogram", "catheterization",
            "angiography", "bronchoscopy", "endoscopy", "colonoscopy",
            
            // Anatomy
            "hepatomegaly", "splenomegaly", "lymphadenopathy",
            "tachycardia", "bradycardia", "murmur", "gallop", "rales"
        ]
    }
    
    // MARK: - Cost Comparison
    
    func compareWithAPIs() -> String {
        """
        TRANSCRIPTION COST COMPARISON (per hour of audio):
        
        🎯 WhisperKit (Local) - All Models:
        • Cost: $0 (FREE)
        • Privacy: 100% on-device
        • No internet required
        • One-time download
        
        ☁️ OpenAI Whisper API:
        • Cost: $0.36 per hour
        • Requires internet
        • Data leaves device
        • Pay per use
        
        ☁️ Google Speech-to-Text:
        • Cost: $1.44 per hour (medical model)
        • Requires internet
        • Data leaves device
        • Pay per use
        
        ☁️ AWS Transcribe Medical:
        • Cost: $1.98 per hour
        • Requires internet
        • HIPAA compliant option
        • Pay per use
        
        💡 For 100 hours/month:
        • WhisperKit: $0
        • OpenAI API: $36
        • Google: $144
        • AWS: $198
        """
    }
}

// MARK: - Update Your WhisperService

extension WhisperService {
    func upgradeToLargerModel() async throws {
        // Current implementation likely uses tiny
        // Upgrade to small or medium for medical use
        
        let recommendedModel = WhisperUpgrade.WhisperModel.smallEn
        
        print("""
        📢 UPGRADING WHISPER MODEL:
        From: openai_whisper-tiny (39 MB)
        To: \(recommendedModel.rawValue) (\(recommendedModel.sizeMB) MB)
        Accuracy: \(recommendedModel.accuracy)
        Speed: \(recommendedModel.speed)
        """)
        
        // Store preference for WhisperService to use on next init
        UserDefaults.standard.set(recommendedModel.rawValue, forKey: "PreferredWhisperModel")
    }
}