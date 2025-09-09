import Foundation
import os.log

/**
 * Professional logging system for NotedCore Medical Transcription App
 * 
 * Provides structured logging with appropriate levels for production use.
 * Replaces debug print statements with proper logging infrastructure.
 */
final class Logger {
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case audio = "Audio"
        case transcription = "Transcription" 
        case medicalAI = "MedicalAI"
        case ui = "UI"
        case general = "General"
        
        var subsystem: String {
            return "com.notedcore.medical"
        }
        
        var osLog: OSLog {
            return OSLog(subsystem: subsystem, category: rawValue)
        }
    }
    
    // MARK: - Log Levels
    enum Level {
        case debug
        case info
        case warning
        case error
        case critical
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
    }
    
    // MARK: - Logging Methods
    static func log(_ level: Level, category: Category, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        
        #if DEBUG
        // In debug mode, also print to console for development
        let fileName = (file as NSString).lastPathComponent
        let prefix = "\(level.emoji) [\(category.rawValue)] \(fileName):\(line) \(function)"
        print("\(prefix) - \(message)")
        #endif
        
        // Always log to system log for production monitoring
        os_log("%{public}@", log: category.osLog, type: level.osLogType, message)
    }
    
    // MARK: - Convenience Methods
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, category: category, message: message, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, category: category, message: message, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, category: category, message: message, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, category: category, message: message, file: file, function: function, line: line)
    }
    
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, category: category, message: message, file: file, function: function, line: line)
    }
}

// MARK: - Audio Logging Extensions
extension Logger {
    static func audioInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .audio, file: file, function: function, line: line)
    }
    
    static func audioError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, category: .audio, file: file, function: function, line: line)
    }
    
    static func transcriptionInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .transcription, file: file, function: function, line: line)
    }
    
    static func transcriptionError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, category: .transcription, file: file, function: function, line: line)
    }
    
    static func medicalAIInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, category: .medicalAI, file: file, function: function, line: line)
    }
    
    static func medicalAIError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        error(message, category: .medicalAI, file: file, function: function, line: line)
    }
}