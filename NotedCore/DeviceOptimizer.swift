import Foundation
import UIKit

/// Automatic device detection and optimization for NotedCore
/// Optimizes transcription settings based on device capabilities
@MainActor
final class DeviceOptimizer {
    static let shared = DeviceOptimizer()

    // MARK: - Device Information

    enum DeviceClass {
        case iphone16ProMax      // A18 Pro - Top tier
        case iphone16Pro         // A18 Pro
        case iphone15ProMax      // A17 Pro
        case iphone15Pro         // A17 Pro
        case iphone15            // A16
        case iphone14Pro         // A16
        case iphone14            // A15
        case older               // A14 or older

        var neuralEngineTOPS: Int {
            switch self {
            case .iphone16ProMax, .iphone16Pro: return 35
            case .iphone15ProMax, .iphone15Pro: return 35
            case .iphone15: return 17
            case .iphone14Pro: return 17
            case .iphone14: return 17
            case .older: return 11
            }
        }

        var ramGB: Int {
            switch self {
            case .iphone16ProMax, .iphone16Pro: return 8
            case .iphone15ProMax, .iphone15Pro: return 8
            case .iphone15: return 6
            case .iphone14Pro: return 6
            case .iphone14: return 6
            case .older: return 4
            }
        }

        var supportsAppleIntelligence: Bool {
            switch self {
            case .iphone16ProMax, .iphone16Pro: return true
            case .iphone15ProMax, .iphone15Pro: return true
            default: return false
            }
        }

        var displayName: String {
            switch self {
            case .iphone16ProMax: return "iPhone 16 Pro Max"
            case .iphone16Pro: return "iPhone 16 Pro"
            case .iphone15ProMax: return "iPhone 15 Pro Max"
            case .iphone15Pro: return "iPhone 15 Pro"
            case .iphone15: return "iPhone 15"
            case .iphone14Pro: return "iPhone 14 Pro"
            case .iphone14: return "iPhone 14"
            case .older: return "iPhone (Older)"
            }
        }
    }

    private(set) var currentDevice: DeviceClass = .older
    private(set) var deviceIdentifier: String = ""

    init() {
        detectDevice()
    }

    // MARK: - Device Detection

    private func detectDevice() {
        deviceIdentifier = getDeviceIdentifier()
        currentDevice = classifyDevice(identifier: deviceIdentifier)

        Logger.transcriptionInfo("📱 Detected: \(currentDevice.displayName)")
        Logger.transcriptionInfo("🧠 Neural Engine: \(currentDevice.neuralEngineTOPS) TOPS")
        Logger.transcriptionInfo("💾 RAM: \(currentDevice.ramGB)GB")
        Logger.transcriptionInfo("🤖 Apple Intelligence: \(currentDevice.supportsAppleIntelligence ? "✅" : "❌")")
    }

    private func getDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private func classifyDevice(identifier: String) -> DeviceClass {
        // iPhone 16 Pro models
        if identifier == "iPhone17,1" || identifier == "iPhone17,2" {
            return .iphone16ProMax
        }
        if identifier == "iPhone17,3" {
            return .iphone16Pro
        }

        // iPhone 15 Pro models
        if identifier == "iPhone16,2" {
            return .iphone15ProMax
        }
        if identifier == "iPhone16,1" {
            return .iphone15Pro
        }

        // iPhone 15 non-Pro
        if identifier.hasPrefix("iPhone15,") {
            return .iphone15
        }

        // iPhone 14 models
        if identifier.hasPrefix("iPhone14,") {
            return .iphone14Pro
        }
        if identifier.hasPrefix("iPhone14,") {
            return .iphone14
        }

        return .older
    }

    // MARK: - Optimized Settings

    struct OptimizedSettings {
        let whisperModel: String
        let windowSize: TimeInterval
        let overlapSize: TimeInterval
        let minWindowSize: TimeInterval
        let maxWindowSize: TimeInterval
        let bufferSize: Int
        let useAppleIntelligence: Bool
        let enableSmallModel: Bool
        let maxConcurrentOperations: Int
    }

    func getOptimizedSettings() -> OptimizedSettings {
        switch currentDevice {
        case .iphone16ProMax, .iphone16Pro:
            // A18 Pro - BEST performance
            return OptimizedSettings(
                whisperModel: "openai_whisper-base.en",
                windowSize: 2.0,
                overlapSize: 0.3,
                minWindowSize: 1.5,
                maxWindowSize: 3.0,
                bufferSize: 2048,
                useAppleIntelligence: true,
                enableSmallModel: true,  // Can upgrade to small model
                maxConcurrentOperations: 4
            )

        case .iphone15ProMax, .iphone15Pro:
            // A17 Pro - Excellent performance
            return OptimizedSettings(
                whisperModel: "openai_whisper-base.en",
                windowSize: 2.5,
                overlapSize: 0.4,
                minWindowSize: 2.0,
                maxWindowSize: 3.0,
                bufferSize: 2048,
                useAppleIntelligence: true,
                enableSmallModel: true,
                maxConcurrentOperations: 3
            )

        case .iphone15:
            // A16 - Good performance
            return OptimizedSettings(
                whisperModel: "openai_whisper-base.en",
                windowSize: 3.0,
                overlapSize: 0.5,
                minWindowSize: 2.5,
                maxWindowSize: 3.5,
                bufferSize: 2048,
                useAppleIntelligence: false,
                enableSmallModel: false,  // Stick with base
                maxConcurrentOperations: 2
            )

        case .iphone14Pro, .iphone14:
            // A15/A16 - Moderate performance
            return OptimizedSettings(
                whisperModel: "openai_whisper-tiny.en",
                windowSize: 3.0,
                overlapSize: 0.5,
                minWindowSize: 2.5,
                maxWindowSize: 4.0,
                bufferSize: 1024,
                useAppleIntelligence: false,
                enableSmallModel: false,
                maxConcurrentOperations: 2
            )

        case .older:
            // A14 or older - Conservative settings
            return OptimizedSettings(
                whisperModel: "openai_whisper-tiny.en",
                windowSize: 4.0,
                overlapSize: 0.5,
                minWindowSize: 3.0,
                maxWindowSize: 5.0,
                bufferSize: 1024,
                useAppleIntelligence: false,
                enableSmallModel: false,
                maxConcurrentOperations: 1
            )
        }
    }

    // MARK: - Performance Recommendations

    func getPerformanceRecommendations() -> [String] {
        var recommendations: [String] = []

        switch currentDevice {
        case .iphone16ProMax, .iphone16Pro:
            recommendations.append("✅ Your device is PERFECT for NotedCore!")
            recommendations.append("🚀 A18 Pro Neural Engine provides real-time transcription")
            recommendations.append("🤖 Apple Intelligence enabled for superior note generation")
            recommendations.append("⚡ Can handle base/small WhisperKit models with ease")
            recommendations.append("🔋 Expected battery: 4-6 hours continuous recording")

        case .iphone15ProMax, .iphone15Pro:
            recommendations.append("✅ Excellent device for NotedCore!")
            recommendations.append("🚀 A17 Pro provides fast transcription")
            recommendations.append("🤖 Apple Intelligence enabled")
            recommendations.append("⚡ Base model recommended")
            recommendations.append("🔋 Expected battery: 3-5 hours continuous recording")

        case .iphone15:
            recommendations.append("✅ Good device for NotedCore")
            recommendations.append("⚡ Base model will work well")
            recommendations.append("💡 Consider keeping Low Power Mode off during recording")
            recommendations.append("🔋 Expected battery: 2-4 hours continuous recording")

        case .iphone14Pro, .iphone14:
            recommendations.append("✅ NotedCore will work on your device")
            recommendations.append("⚡ Using optimized tiny model for best performance")
            recommendations.append("💡 Close background apps for best performance")
            recommendations.append("🔋 Expected battery: 2-3 hours continuous recording")

        case .older:
            recommendations.append("⚠️ Your device may experience slower transcription")
            recommendations.append("💡 Recommendations:")
            recommendations.append("  • Close all background apps")
            recommendations.append("  • Keep device plugged in for long sessions")
            recommendations.append("  • Use shorter recording segments")
            recommendations.append("🔋 Expected battery: 1-2 hours continuous recording")
        }

        return recommendations
    }

    // MARK: - Real-time Performance Monitoring

    func shouldUpgradeModel(currentProcessingTime: TimeInterval, windowSize: TimeInterval) -> Bool {
        let processingRatio = currentProcessingTime / windowSize

        // If processing faster than 0.6x real-time, we can upgrade
        // Only for devices with 8GB+ RAM
        if processingRatio < 0.6 && currentDevice.ramGB >= 8 {
            return true
        }

        return false
    }

    func shouldDowngradeModel(currentProcessingTime: TimeInterval, windowSize: TimeInterval) -> Bool {
        let processingRatio = currentProcessingTime / windowSize

        // If processing slower than 1.2x real-time, downgrade for reliability
        if processingRatio > 1.2 {
            return true
        }

        return false
    }

    // MARK: - Memory Management

    func estimatedMemoryUsage() -> String {
        switch currentDevice {
        case .iphone16ProMax, .iphone16Pro:
            return "~300-400MB (plenty of headroom with 8GB RAM)"
        case .iphone15ProMax, .iphone15Pro:
            return "~300-400MB (comfortable with 8GB RAM)"
        case .iphone15:
            return "~250-350MB (manageable with 6GB RAM)"
        case .iphone14Pro, .iphone14:
            return "~200-300MB (optimized for 6GB RAM)"
        case .older:
            return "~150-250MB (conservative for 4GB RAM)"
        }
    }

    // MARK: - Feature Availability

    func canUseFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .appleIntelligence:
            return currentDevice.supportsAppleIntelligence && isIOS18OrLater()
        case .smallWhisperModel:
            return currentDevice.ramGB >= 8
        case .concurrentTranscription:
            return currentDevice.neuralEngineTOPS >= 17
        case .realtimeSuggestions:
            return currentDevice.neuralEngineTOPS >= 35
        case .backgroundRecording:
            return true // All devices support
        }
    }

    enum Feature {
        case appleIntelligence
        case smallWhisperModel
        case concurrentTranscription
        case realtimeSuggestions
        case backgroundRecording
    }

    private func isIOS18OrLater() -> Bool {
        if #available(iOS 18.0, *) {
            return true
        }
        return false
    }
}