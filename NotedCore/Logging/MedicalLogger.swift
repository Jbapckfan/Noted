import Foundation
import os.log
import SwiftUI

// MARK: - Log Levels

enum LogLevel: String, CaseIterable, Codable {
    case verbose = "VERBOSE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning, .error: return .error
        case .critical: return .fault
        }
    }
    
    var emoji: String {
        switch self {
        case .verbose: return "💭"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var color: Color {
        switch self {
        case .verbose: return .gray
        case .debug: return .blue
        case .info: return .green
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Log Categories

enum LogCategory: String, CaseIterable, Codable {
    // Core functionalities
    case transcription = "Transcription"
    case audioProcessing = "AudioProcessing"
    case whisper = "Whisper"
    case speechRecognition = "SpeechRecognition"
    
    // Medical processing
    case medicalAnalysis = "MedicalAnalysis"
    case redFlags = "RedFlags"
    case noteGeneration = "NoteGeneration"
    case templates = "Templates"
    
    // Data management
    case encounters = "Encounters"
    case persistence = "Persistence"
    case sync = "Sync"
    case export = "Export"
    
    // Network and APIs
    case groqAPI = "GroqAPI"
    case network = "Network"
    
    // System
    case performance = "Performance"
    case memory = "Memory"
    case watchConnectivity = "WatchConnectivity"
    case ui = "UI"
    case errorHandling = "ErrorHandling"
    
    var subsystem: String {
        return "com.notedcore.app"
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int
    let metadata: [String: String]
    
    var formattedMessage: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss.SSS"
        
        return "\(level.emoji) [\(dateFormatter.string(from: timestamp))] \(category.rawValue): \(message)"
    }
}

// MARK: - Medical Logger

class MedicalLogger: ObservableObject {
    static let shared = MedicalLogger()
    
    @Published var logEntries: [LogEntry] = []
    @Published var isLoggingEnabled = true
    @Published var minimumLogLevel: LogLevel = .info
    @Published var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
    
    private let osLogger: [LogCategory: Logger] = {
        var loggers: [LogCategory: Logger] = [:]
        for category in LogCategory.allCases {
            loggers[category] = Logger()
        }
        return loggers
    }()
    
    private let maxLogEntries = 1000
    private let logQueue = DispatchQueue(label: "com.notedcore.logging", qos: .utility)
    private var logFileURL: URL?
    
    private init() {
        // setupLogFile()
        // loadSettings()
        
        // Set up periodic log cleanup
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            // self.cleanupOldLogs()
        }
    }
    
    // MARK: - Public Logging Methods
    
    func verbose(_ message: String, category: LogCategory = .ui, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .verbose, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func debug(_ message: String, category: LogCategory = .ui, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func info(_ message: String, category: LogCategory = .ui, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func warning(_ message: String, category: LogCategory = .ui, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func error(_ message: String, category: LogCategory = .errorHandling, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    func critical(_ message: String, category: LogCategory = .errorHandling, file: String = #file, function: String = #function, line: Int = #line, metadata: [String: String] = [:]) {
        log(level: .critical, message: message, category: category, file: file, function: function, line: line, metadata: metadata)
    }
    
    // MARK: - Core Logging Method
    
    private func log(level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int, metadata: [String: String]) {
        guard isLoggingEnabled else {
            return
        }
        
        logQueue.async {
            let entry = LogEntry(
                timestamp: Date(),
                level: level,
                category: category,
                message: message,
                file: file,
                function: function,
                line: line,
                metadata: metadata
            )
            
            // self.writeToLog(entry)
            print("[\(entry.level.rawValue)] \(entry.category.rawValue): \(entry.message)")
        }
    }
    
    func logMemoryUsage(context: String = "General", category: LogCategory = .memory) {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageMB = Float(memoryInfo.resident_size) / (1024 * 1024)
            
            let level: LogLevel = memoryUsageMB > 200 ? .warning : .info
            log(
                level: level,
                message: "\(context) - Memory usage: \(String(format: "%.1f", memoryUsageMB))MB",
                category: category,
                file: #file,
                function: #function,
                line: #line,
                metadata: ["memory_mb": String(format: "%.1f", memoryUsageMB)]
            )
        }
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let criticalLogReceived = Notification.Name("criticalLogReceived")
}

// MARK: - Convenience Logging Functions

// Global convenience functions for easy logging
func logVerbose(_ message: String, category: LogCategory = .ui, metadata: [String: String] = [:]) {
    MedicalLogger.shared.verbose(message, category: category, metadata: metadata)
}

func logDebug(_ message: String, category: LogCategory = .ui, metadata: [String: String] = [:]) {
    MedicalLogger.shared.debug(message, category: category, metadata: metadata)
}

func logInfo(_ message: String, category: LogCategory = .ui, metadata: [String: String] = [:]) {
    MedicalLogger.shared.info(message, category: category, metadata: metadata)
}

func logWarning(_ message: String, category: LogCategory = .ui, metadata: [String: String] = [:]) {
    MedicalLogger.shared.warning(message, category: category, metadata: metadata)
}

func logError(_ message: String, category: LogCategory = .errorHandling, metadata: [String: String] = [:]) {
    MedicalLogger.shared.error(message, category: category, metadata: metadata)
}

func logCritical(_ message: String, category: LogCategory = .errorHandling, metadata: [String: String] = [:]) {
    MedicalLogger.shared.critical(message, category: category, metadata: metadata)
}