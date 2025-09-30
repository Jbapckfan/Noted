import Foundation
import SwiftUI
import os.log

// MARK: - Medical App Error Types

enum MedicalAppError: LocalizedError, Equatable {
    // Transcription Errors
    case transcriptionFailed(reason: String)
    case audioProcessingFailed(reason: String)
    case whisperModelLoadFailed
    case speechRecognitionUnavailable
    case microphonePermissionDenied
    
    // Medical Processing Errors
    case medicalAnalysisFailed(reason: String)
    case redFlagDetectionFailed
    case noteGenerationFailed(reason: String)
    case templateProcessingFailed
    
    // Data Errors
    case encounterSaveFailed(reason: String)
    case exportFailed(format: String, reason: String)
    case syncFailed(reason: String)
    case corruptedData(file: String)
    
    // Network Errors
    case groqAPIFailure(statusCode: Int, message: String)
    case networkUnavailable
    case rateLimitExceeded(retryAfter: TimeInterval)
    
    // System Errors
    case lowMemory
    case diskSpaceLow(availableGB: Double)
    case backgroundTaskExpired
    case watchConnectivityFailed
    
    var errorDescription: String? {
        switch self {
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .audioProcessingFailed(let reason):
            return "Audio processing failed: \(reason)"
        case .whisperModelLoadFailed:
            return "Failed to load Whisper model. Please restart the app."
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available on this device"
        case .microphonePermissionDenied:
            return "Microphone access is required for transcription"
        case .medicalAnalysisFailed(let reason):
            return "Medical analysis failed: \(reason)"
        case .redFlagDetectionFailed:
            return "Unable to detect medical red flags"
        case .noteGenerationFailed(let reason):
            return "Note generation failed: \(reason)"
        case .templateProcessingFailed:
            return "Template processing failed"
        case .encounterSaveFailed(let reason):
            return "Failed to save encounter: \(reason)"
        case .exportFailed(let format, let reason):
            return "Export to \(format) failed: \(reason)"
        case .syncFailed(let reason):
            return "Sync failed: \(reason)"
        case .corruptedData(let file):
            return "Data corruption detected in \(file)"
        case .groqAPIFailure(let statusCode, let message):
            return "API Error (\(statusCode)): \(message)"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .rateLimitExceeded(let retryAfter):
            return "Rate limit exceeded. Please wait \(Int(retryAfter)) seconds"
        case .lowMemory:
            return "Low memory warning. Please close other apps"
        case .diskSpaceLow(let availableGB):
            return "Low disk space: \(String(format: "%.1f", availableGB))GB available"
        case .backgroundTaskExpired:
            return "Background processing time expired"
        case .watchConnectivityFailed:
            return "Apple Watch connection failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Go to Settings > Privacy & Security > Microphone to enable access"
        case .whisperModelLoadFailed:
            return "Restart the app or reinstall if the problem persists"
        case .networkUnavailable:
            return "Check your internet connection and try again"
        case .lowMemory:
            return "Close other apps and restart NotedCore"
        case .diskSpaceLow:
            return "Free up storage space on your device"
        case .rateLimitExceeded(let retryAfter):
            return "Wait \(Int(retryAfter)) seconds before trying again"
        default:
            return "Please try again or contact support if the problem persists"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .lowMemory, .diskSpaceLow, .microphonePermissionDenied:
            return .critical
        case .whisperModelLoadFailed, .speechRecognitionUnavailable:
            return .high
        case .transcriptionFailed, .audioProcessingFailed, .noteGenerationFailed:
            return .medium
        case .networkUnavailable, .groqAPIFailure:
            return .medium
        default:
            return .low
        }
    }
}

enum ErrorSeverity: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium" 
    case high = "High"
    case critical = "Critical"
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    var systemImage: String {
        switch self {
        case .low: return "info.circle"
        case .medium: return "exclamationmark.triangle"
        case .high: return "xmark.circle"
        case .critical: return "exclamationmark.octagon"
        }
    }
}

// MARK: - Error Recovery Strategies

enum RecoveryStrategy {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case fallback(alternative: String)
    case userAction(action: String)
    case restart(component: String)
    case ignore
}

// MARK: - Medical Error Handler

@MainActor
class MedicalErrorHandler: ObservableObject {
    static let shared = MedicalErrorHandler()
    
    @Published var currentError: MedicalAppError?
    @Published var errorHistory: [ErrorLogEntry] = []
    @Published var showErrorAlert = false
    @Published var isInRecoveryMode = false
    
    private let logger = Logger()
    private let maxHistoryEntries = 100
    private var recoveryAttempts: [String: Int] = [:]
    
    private init() {
        loadErrorHistory()
        setupMemoryWarningObserver()
        setupDiskSpaceMonitoring()
    }
    
    // MARK: - Error Handling
    
    func handle(_ error: MedicalAppError, context: String = "", autoRecover: Bool = true) {
        print("Medical app error: \(error.localizedDescription) in context: \(context)")
        
        let logEntry = ErrorLogEntry(
            error: error,
            context: context,
            timestamp: Date(),
            severity: error.severity
        )
        
        errorHistory.append(logEntry)
        trimHistoryIfNeeded()
        saveErrorHistory()
        
        // Set current error for UI display
        currentError = error
        showErrorAlert = true
        
        // Attempt automatic recovery if enabled
        if autoRecover {
            attemptRecovery(for: error, context: context)
        }
        
        // Send telemetry (without sensitive data)
        sendErrorTelemetry(logEntry)
    }
    
    private func attemptRecovery(for error: MedicalAppError, context: String) {
        let errorKey = "\(error)_\(context)"
        let attempts = recoveryAttempts[errorKey, default: 0]
        
        guard attempts < 3 else {
            print("Max recovery attempts reached for \(errorKey)")
            return
        }
        
        recoveryAttempts[errorKey] = attempts + 1
        isInRecoveryMode = true
        
        let strategy = getRecoveryStrategy(for: error)
        executeRecoveryStrategy(strategy, for: error, context: context)
    }
    
    private func getRecoveryStrategy(for error: MedicalAppError) -> RecoveryStrategy {
        switch error {
        case .transcriptionFailed, .audioProcessingFailed:
            return .retry(maxAttempts: 2, delay: 1.0)
        case .whisperModelLoadFailed:
            return .restart(component: "WhisperService")
        case .networkUnavailable, .groqAPIFailure:
            return .retry(maxAttempts: 3, delay: 2.0)
        case .rateLimitExceeded(let retryAfter):
            return .retry(maxAttempts: 1, delay: retryAfter)
        case .lowMemory:
            return .userAction(action: "FreeMemory")
        case .speechRecognitionUnavailable:
            return .fallback(alternative: "WhisperOnly")
        default:
            return .ignore
        }
    }
    
    private func executeRecoveryStrategy(_ strategy: RecoveryStrategy, for error: MedicalAppError, context: String) {
        Task {
            switch strategy {
            case .retry(let maxAttempts, let delay):
                await performRetry(delay: delay, for: error, context: context)
            case .fallback(let alternative):
                await performFallback(alternative, for: error)
            case .restart(let component):
                await restartComponent(component)
            case .userAction(let action):
                await promptUserAction(action)
            case .ignore:
                break
            }
            
            await MainActor.run {
                self.isInRecoveryMode = false
            }
        }
    }
    
    // MARK: - Recovery Actions
    
    private func performRetry(delay: TimeInterval, for error: MedicalAppError, context: String) async {
        print("Retrying after \(delay)s for error: \(error)")
        
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        // Signal that retry is happening
        NotificationCenter.default.post(name: .errorRecoveryRetry, object: error)
    }
    
    private func performFallback(_ alternative: String, for error: MedicalAppError) async {
        print("Using fallback: \(alternative) for error: \(error)")
        
        // Signal fallback activation
        NotificationCenter.default.post(
            name: .errorRecoveryFallback,
            object: error,
            userInfo: ["alternative": alternative]
        )
    }
    
    private func restartComponent(_ component: String) async {
        print("Restarting component: \(component)")
        
        // Signal component restart
        NotificationCenter.default.post(
            name: .errorRecoveryRestart,
            object: component
        )
    }
    
    private func promptUserAction(_ action: String) async {
        print("Prompting user action: \(action)")
        
        await MainActor.run {
            // Show specific action prompt based on action type
            switch action {
            case "FreeMemory":
                self.showMemoryWarning()
            default:
                break
            }
        }
    }
    
    // MARK: - System Monitoring
    
    private func setupMemoryWarningObserver() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handle(.lowMemory, context: "SystemWarning")
        }
        #else
        // macOS doesn't have the same memory warning system
        // Could monitor memory usage differently if needed
        #endif
    }
    
    private func setupDiskSpaceMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.checkDiskSpace()
        }
    }
    
    private func checkDiskSpace() {
        guard let availableSpace = getAvailableDiskSpace() else { return }
        
        if availableSpace < 1.0 { // Less than 1GB
            handle(.diskSpaceLow(availableGB: availableSpace), context: "SystemCheck")
        }
    }
    
    private func getAvailableDiskSpace() -> Double? {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        do {
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let availableSpace = values.volumeAvailableCapacityForImportantUsage {
                return Double(availableSpace) / (1024.0 * 1024.0 * 1024.0) // Convert to GB
            }
        } catch {
            print("Failed to check disk space: \(error)")
        }
        return nil
    }
    
    // MARK: - Error History Management
    
    private func trimHistoryIfNeeded() {
        if errorHistory.count > maxHistoryEntries {
            errorHistory = Array(errorHistory.suffix(maxHistoryEntries))
        }
    }
    
    private func saveErrorHistory() {
        do {
            let data = try JSONEncoder().encode(errorHistory)
            UserDefaults.standard.set(data, forKey: "errorHistory")
        } catch {
            print("Failed to save error history: \(error)")
        }
    }
    
    private func loadErrorHistory() {
        guard let data = UserDefaults.standard.data(forKey: "errorHistory") else { return }
        
        do {
            errorHistory = try JSONDecoder().decode([ErrorLogEntry].self, from: data)
        } catch {
            print("Failed to load error history: \(error)")
            errorHistory = []
        }
    }
    
    // MARK: - UI Helpers
    
    func dismissError() {
        currentError = nil
        showErrorAlert = false
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
        saveErrorHistory()
    }
    
    private func showMemoryWarning() {
        // This would trigger a memory cleanup UI prompt
        NotificationCenter.default.post(name: .showMemoryWarning, object: nil)
    }
    
    // MARK: - Telemetry
    
    private func sendErrorTelemetry(_ logEntry: ErrorLogEntry) {
        // Anonymized error reporting
        let telemetryData: [String: Any] = [
            "errorType": String(describing: logEntry.error),
            "severity": logEntry.severity.rawValue,
            "context": logEntry.context,
            "timestamp": logEntry.timestamp.timeIntervalSince1970
        ]
        
        // In a real app, send this to your analytics service
        print("Telemetry data: \(telemetryData)")
    }
}

// MARK: - Error Log Entry

struct ErrorLogEntry: Codable, Identifiable {
    let id = UUID()
    let error: MedicalAppError
    let context: String
    let timestamp: Date
    let severity: ErrorSeverity
    
    private enum CodingKeys: String, CodingKey {
        case error, context, timestamp, severity
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let errorRecoveryRetry = Notification.Name("errorRecoveryRetry")
    static let errorRecoveryFallback = Notification.Name("errorRecoveryFallback")
    static let errorRecoveryRestart = Notification.Name("errorRecoveryRestart")
    static let showMemoryWarning = Notification.Name("showMemoryWarning")
}

// MARK: - MedicalAppError Codable Conformance

extension MedicalAppError: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, reason, statusCode, message, format, file, availableGB, retryAfter
    }
    
    private enum ErrorType: String, Codable {
        case transcriptionFailed, audioProcessingFailed, whisperModelLoadFailed
        case speechRecognitionUnavailable, microphonePermissionDenied
        case medicalAnalysisFailed, redFlagDetectionFailed, noteGenerationFailed
        case templateProcessingFailed, encounterSaveFailed, exportFailed
        case syncFailed, corruptedData, groqAPIFailure, networkUnavailable
        case rateLimitExceeded, lowMemory, diskSpaceLow, backgroundTaskExpired
        case watchConnectivityFailed
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .transcriptionFailed(let reason):
            try container.encode(ErrorType.transcriptionFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .audioProcessingFailed(let reason):
            try container.encode(ErrorType.audioProcessingFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .whisperModelLoadFailed:
            try container.encode(ErrorType.whisperModelLoadFailed, forKey: .type)
        case .speechRecognitionUnavailable:
            try container.encode(ErrorType.speechRecognitionUnavailable, forKey: .type)
        case .microphonePermissionDenied:
            try container.encode(ErrorType.microphonePermissionDenied, forKey: .type)
        case .medicalAnalysisFailed(let reason):
            try container.encode(ErrorType.medicalAnalysisFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .redFlagDetectionFailed:
            try container.encode(ErrorType.redFlagDetectionFailed, forKey: .type)
        case .noteGenerationFailed(let reason):
            try container.encode(ErrorType.noteGenerationFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .templateProcessingFailed:
            try container.encode(ErrorType.templateProcessingFailed, forKey: .type)
        case .encounterSaveFailed(let reason):
            try container.encode(ErrorType.encounterSaveFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .exportFailed(let format, let reason):
            try container.encode(ErrorType.exportFailed, forKey: .type)
            try container.encode(format, forKey: .format)
            try container.encode(reason, forKey: .reason)
        case .syncFailed(let reason):
            try container.encode(ErrorType.syncFailed, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .corruptedData(let file):
            try container.encode(ErrorType.corruptedData, forKey: .type)
            try container.encode(file, forKey: .file)
        case .groqAPIFailure(let statusCode, let message):
            try container.encode(ErrorType.groqAPIFailure, forKey: .type)
            try container.encode(statusCode, forKey: .statusCode)
            try container.encode(message, forKey: .message)
        case .networkUnavailable:
            try container.encode(ErrorType.networkUnavailable, forKey: .type)
        case .rateLimitExceeded(let retryAfter):
            try container.encode(ErrorType.rateLimitExceeded, forKey: .type)
            try container.encode(retryAfter, forKey: .retryAfter)
        case .lowMemory:
            try container.encode(ErrorType.lowMemory, forKey: .type)
        case .diskSpaceLow(let availableGB):
            try container.encode(ErrorType.diskSpaceLow, forKey: .type)
            try container.encode(availableGB, forKey: .availableGB)
        case .backgroundTaskExpired:
            try container.encode(ErrorType.backgroundTaskExpired, forKey: .type)
        case .watchConnectivityFailed:
            try container.encode(ErrorType.watchConnectivityFailed, forKey: .type)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ErrorType.self, forKey: .type)
        
        switch type {
        case .transcriptionFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .transcriptionFailed(reason: reason)
        case .audioProcessingFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .audioProcessingFailed(reason: reason)
        case .whisperModelLoadFailed:
            self = .whisperModelLoadFailed
        case .speechRecognitionUnavailable:
            self = .speechRecognitionUnavailable
        case .microphonePermissionDenied:
            self = .microphonePermissionDenied
        case .medicalAnalysisFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .medicalAnalysisFailed(reason: reason)
        case .redFlagDetectionFailed:
            self = .redFlagDetectionFailed
        case .noteGenerationFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .noteGenerationFailed(reason: reason)
        case .templateProcessingFailed:
            self = .templateProcessingFailed
        case .encounterSaveFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .encounterSaveFailed(reason: reason)
        case .exportFailed:
            let format = try container.decode(String.self, forKey: .format)
            let reason = try container.decode(String.self, forKey: .reason)
            self = .exportFailed(format: format, reason: reason)
        case .syncFailed:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .syncFailed(reason: reason)
        case .corruptedData:
            let file = try container.decode(String.self, forKey: .file)
            self = .corruptedData(file: file)
        case .groqAPIFailure:
            let statusCode = try container.decode(Int.self, forKey: .statusCode)
            let message = try container.decode(String.self, forKey: .message)
            self = .groqAPIFailure(statusCode: statusCode, message: message)
        case .networkUnavailable:
            self = .networkUnavailable
        case .rateLimitExceeded:
            let retryAfter = try container.decode(TimeInterval.self, forKey: .retryAfter)
            self = .rateLimitExceeded(retryAfter: retryAfter)
        case .lowMemory:
            self = .lowMemory
        case .diskSpaceLow:
            let availableGB = try container.decode(Double.self, forKey: .availableGB)
            self = .diskSpaceLow(availableGB: availableGB)
        case .backgroundTaskExpired:
            self = .backgroundTaskExpired
        case .watchConnectivityFailed:
            self = .watchConnectivityFailed
        }
    }
}