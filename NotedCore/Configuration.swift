import Foundation

// MARK: - Centralized Configuration Management
public struct NotedCoreConfiguration {
    
    // MARK: - Environment
    public enum Environment: String {
        case development = "dev"
        case staging = "staging"
        case production = "prod"
        
        var baseURL: String {
            switch self {
            case .development:
                return "http://localhost:8080"
            case .staging:
                return "https://staging-api.notedcore.com"
            case .production:
                return "https://api.notedcore.com"
            }
        }
        
        var logLevel: LogLevel {
            switch self {
            case .development:
                return .debug
            case .staging:
                return .info
            case .production:
                return .warning
            }
        }
    }
    
    // MARK: - Log Levels
    public enum LogLevel: Int {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4
    }
    
    // MARK: - Current Configuration
    public static let shared = NotedCoreConfiguration()
    
    public let environment: Environment
    public let version: String
    public let buildNumber: String
    
    // MARK: - Feature Flags
    public struct FeatureFlags {
        public let enableDistributedProcessing: Bool
        public let enableCloudProcessing: Bool
        public let enableAdaptiveLearning: Bool
        public let enableAdvancedNLP: Bool
        public let enableRealTimeCorrection: Bool
        public let enableBiometrics: Bool
        public let enableMFA: Bool
        public let enableClinicalAlerts: Bool
        public let enableAutoScaling: Bool
        public let enableIntrusionDetection: Bool
    }
    
    public let features: FeatureFlags
    
    // MARK: - API Configuration
    public struct APIConfiguration {
        public let baseURL: String
        public let timeout: TimeInterval
        public let maxRetries: Int
        public let apiKey: String?
        public let apiSecret: String?
    }
    
    public let api: APIConfiguration
    
    // MARK: - Model Configuration
    public struct ModelConfiguration {
        public let whisperVariants: [String]
        public let customModelPath: String?
        public let modelUpdateInterval: TimeInterval
        public let enableModelCaching: Bool
        public let maxModelCacheSize: Int
    }
    
    public let models: ModelConfiguration
    
    // MARK: - Security Configuration
    public struct SecurityConfiguration {
        public let encryptionAlgorithm: String
        public let keyRotationInterval: TimeInterval
        public let sessionTimeout: TimeInterval
        public let maxLoginAttempts: Int
        public let passwordMinLength: Int
        public let requireSpecialCharacters: Bool
        public let auditLogRetentionDays: Int
    }
    
    public let security: SecurityConfiguration
    
    // MARK: - Performance Configuration
    public struct PerformanceConfiguration {
        public let maxConcurrentSessions: Int
        public let processingTimeout: TimeInterval
        public let chunkDuration: TimeInterval
        public let bufferSize: Int
        public let cacheSize: Int
        public let compressionEnabled: Bool
        public let compressionLevel: Int
    }
    
    public let performance: PerformanceConfiguration
    
    // MARK: - Cloud Configuration
    public struct CloudConfiguration {
        public let awsRegion: String?
        public let awsAccessKey: String?
        public let awsSecretKey: String?
        public let azureRegion: String?
        public let azureSubscriptionId: String?
        public let azureClientId: String?
        public let cloudKitContainerId: String?
    }
    
    public let cloud: CloudConfiguration
    
    // MARK: - Initialization
    private init() {
        // Determine environment
        #if DEBUG
        self.environment = .development
        #else
        self.environment = ProcessInfo.processInfo.environment["ENVIRONMENT"]
            .flatMap(Environment.init(rawValue:)) ?? .production
        #endif
        
        // Version info
        self.version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        // Load feature flags
        self.features = FeatureFlags(
            enableDistributedProcessing: UserDefaults.standard.bool(forKey: "feature.distributedProcessing") || environment != .production,
            enableCloudProcessing: UserDefaults.standard.bool(forKey: "feature.cloudProcessing") || environment == .production,
            enableAdaptiveLearning: UserDefaults.standard.bool(forKey: "feature.adaptiveLearning") || true,
            enableAdvancedNLP: UserDefaults.standard.bool(forKey: "feature.advancedNLP") || true,
            enableRealTimeCorrection: UserDefaults.standard.bool(forKey: "feature.realTimeCorrection") || true,
            enableBiometrics: UserDefaults.standard.bool(forKey: "feature.biometrics") || true,
            enableMFA: UserDefaults.standard.bool(forKey: "feature.mfa") || environment == .production,
            enableClinicalAlerts: UserDefaults.standard.bool(forKey: "feature.clinicalAlerts") || true,
            enableAutoScaling: UserDefaults.standard.bool(forKey: "feature.autoScaling") || environment == .production,
            enableIntrusionDetection: UserDefaults.standard.bool(forKey: "feature.intrusionDetection") || environment == .production
        )
        
        // API configuration
        self.api = APIConfiguration(
            baseURL: environment.baseURL,
            timeout: 30.0,
            maxRetries: 3,
            apiKey: ProcessInfo.processInfo.environment["API_KEY"],
            apiSecret: ProcessInfo.processInfo.environment["API_SECRET"]
        )
        
        // Model configuration
        self.models = ModelConfiguration(
            whisperVariants: [
                "openai_whisper-base.en",
                "openai_whisper-small.en",
                "openai_whisper-medium.en"
            ],
            customModelPath: Bundle.main.path(forResource: "MedicalTranscription", ofType: "mlmodelc"),
            modelUpdateInterval: 86400, // Daily
            enableModelCaching: true,
            maxModelCacheSize: 500 * 1024 * 1024 // 500MB
        )
        
        // Security configuration
        self.security = SecurityConfiguration(
            encryptionAlgorithm: "AES-256-GCM",
            keyRotationInterval: 86400 * 30, // 30 days
            sessionTimeout: 900, // 15 minutes
            maxLoginAttempts: 5,
            passwordMinLength: 12,
            requireSpecialCharacters: true,
            auditLogRetentionDays: 2555 // 7 years per HIPAA
        )
        
        // Performance configuration
        self.performance = PerformanceConfiguration(
            maxConcurrentSessions: environment == .production ? 50 : 10,
            processingTimeout: 30.0,
            chunkDuration: 2.0,
            bufferSize: 10 * 1024 * 1024, // 10MB
            cacheSize: 100 * 1024 * 1024, // 100MB
            compressionEnabled: true,
            compressionLevel: 6 // Balanced
        )
        
        // Cloud configuration
        self.cloud = CloudConfiguration(
            awsRegion: ProcessInfo.processInfo.environment["AWS_REGION"],
            awsAccessKey: ProcessInfo.processInfo.environment["AWS_ACCESS_KEY"],
            awsSecretKey: ProcessInfo.processInfo.environment["AWS_SECRET_KEY"],
            azureRegion: ProcessInfo.processInfo.environment["AZURE_REGION"],
            azureSubscriptionId: ProcessInfo.processInfo.environment["AZURE_SUBSCRIPTION_ID"],
            azureClientId: ProcessInfo.processInfo.environment["AZURE_CLIENT_ID"],
            cloudKitContainerId: ProcessInfo.processInfo.environment["CLOUDKIT_CONTAINER_ID"]
        )
    }
    
    // MARK: - Configuration Validation
    public func validate() -> [String] {
        var issues: [String] = []
        
        // Check API configuration
        if api.apiKey == nil && environment == .production {
            issues.append("API key is required for production environment")
        }
        
        // Check cloud configuration
        if features.enableCloudProcessing {
            if cloud.awsAccessKey == nil && cloud.azureClientId == nil && cloud.cloudKitContainerId == nil {
                issues.append("Cloud credentials required when cloud processing is enabled")
            }
        }
        
        // Check model paths
        if models.customModelPath != nil {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: models.customModelPath!) {
                issues.append("Custom model file not found at specified path")
            }
        }
        
        // Check security settings
        if security.sessionTimeout < 300 && environment == .production {
            issues.append("Session timeout too short for production (minimum 5 minutes)")
        }
        
        return issues
    }
    
    // MARK: - Debug Description
    public var debugDescription: String {
        """
        NotedCore Configuration:
        - Environment: \(environment.rawValue)
        - Version: \(version) (\(buildNumber))
        - API URL: \(api.baseURL)
        - Features:
          • Distributed Processing: \(features.enableDistributedProcessing)
          • Cloud Processing: \(features.enableCloudProcessing)
          • Adaptive Learning: \(features.enableAdaptiveLearning)
          • Advanced NLP: \(features.enableAdvancedNLP)
          • Real-time Correction: \(features.enableRealTimeCorrection)
          • Biometrics: \(features.enableBiometrics)
          • MFA: \(features.enableMFA)
          • Clinical Alerts: \(features.enableClinicalAlerts)
        - Performance:
          • Max Sessions: \(performance.maxConcurrentSessions)
          • Chunk Duration: \(performance.chunkDuration)s
          • Compression: \(performance.compressionEnabled)
        - Security:
          • Encryption: \(security.encryptionAlgorithm)
          • Session Timeout: \(security.sessionTimeout)s
          • Audit Retention: \(security.auditLogRetentionDays) days
        """
    }
}

// MARK: - Configuration Manager
public class ConfigurationManager {
    
    public static let shared = ConfigurationManager()
    
    private var overrides: [String: Any] = [:]
    
    private init() {}
    
    // MARK: - Override Management
    public func setOverride(_ key: String, value: Any) {
        overrides[key] = value
    }
    
    public func removeOverride(_ key: String) {
        overrides.removeValue(forKey: key)
    }
    
    public func clearAllOverrides() {
        overrides.removeAll()
    }
    
    // MARK: - Configuration Export
    public func exportConfiguration() -> Data? {
        let config = NotedCoreConfiguration.shared
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let exportData: [String: Any] = [
            "environment": config.environment.rawValue,
            "version": config.version,
            "buildNumber": config.buildNumber,
            "features": [
                "distributedProcessing": config.features.enableDistributedProcessing,
                "cloudProcessing": config.features.enableCloudProcessing,
                "adaptiveLearning": config.features.enableAdaptiveLearning,
                "advancedNLP": config.features.enableAdvancedNLP,
                "realTimeCorrection": config.features.enableRealTimeCorrection
            ],
            "performance": [
                "maxConcurrentSessions": config.performance.maxConcurrentSessions,
                "chunkDuration": config.performance.chunkDuration,
                "compressionEnabled": config.performance.compressionEnabled
            ]
        ]
        
        return try? JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - Health Check
    public func performHealthCheck() -> HealthCheckResult {
        let config = NotedCoreConfiguration.shared
        let validationIssues = config.validate()
        
        let memoryUsage = ProcessInfo.processInfo.physicalMemory
        let diskSpace = checkDiskSpace()
        let networkReachable = checkNetworkReachability()
        
        return HealthCheckResult(
            status: validationIssues.isEmpty ? .healthy : .degraded,
            issues: validationIssues,
            memoryUsage: memoryUsage,
            diskSpace: diskSpace,
            networkReachable: networkReachable,
            timestamp: Date()
        )
    }
    
    private func checkDiskSpace() -> Int64 {
        if let attributes = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) {
            return (attributes[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        }
        return 0
    }
    
    private func checkNetworkReachability() -> Bool {
        // Simplified network check
        return true
    }
}

// MARK: - Health Check Result
public struct HealthCheckResult {
    public enum Status {
        case healthy
        case degraded
        case unhealthy
    }
    
    public let status: Status
    public let issues: [String]
    public let memoryUsage: UInt64
    public let diskSpace: Int64
    public let networkReachable: Bool
    public let timestamp: Date
    
    public var description: String {
        """
        Health Check: \(status)
        Issues: \(issues.isEmpty ? "None" : issues.joined(separator: ", "))
        Memory: \(memoryUsage / 1024 / 1024) MB
        Disk: \(diskSpace / 1024 / 1024 / 1024) GB free
        Network: \(networkReachable ? "Connected" : "Disconnected")
        Timestamp: \(timestamp)
        """
    }
}