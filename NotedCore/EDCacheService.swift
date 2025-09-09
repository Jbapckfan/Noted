import Foundation

// Intelligent caching for ED Smart-Summary performance
@MainActor
class EDCacheService {
    static let shared = EDCacheService()
    
    // MARK: - Cache Storage
    private var patternCache = NSCache<NSString, CachedPattern>()
    private var extractionCache = NSCache<NSString, CachedExtraction>()
    private var compiledRegexCache: [String: NSRegularExpression] = [:]
    
    // MARK: - Configuration
    init() {
        patternCache.countLimit = 1000
        patternCache.totalCostLimit = 10 * 1024 * 1024 // 10MB
        
        extractionCache.countLimit = 100
        extractionCache.totalCostLimit = 5 * 1024 * 1024 // 5MB
        
        precompileCommonPatterns()
    }
    
    // MARK: - Pattern Caching
    func getCachedPattern(for text: String, type: PatternType) -> CachedPattern? {
        let key = "\(type.rawValue):\(text.prefix(100))" as NSString
        return patternCache.object(forKey: key)
    }
    
    func cachePattern(_ pattern: CachedPattern, for text: String, type: PatternType) {
        let key = "\(type.rawValue):\(text.prefix(100))" as NSString
        let cost = pattern.result.count * MemoryLayout<Character>.size
        patternCache.setObject(pattern, forKey: key, cost: cost)
    }
    
    // MARK: - Extraction Caching
    func getCachedExtraction(for transcript: String) -> CachedExtraction? {
        let hash = transcript.hashValue
        let key = "extraction:\(hash)" as NSString
        return extractionCache.object(forKey: key)
    }
    
    func cacheExtraction(_ extraction: CachedExtraction, for transcript: String) {
        let hash = transcript.hashValue
        let key = "extraction:\(hash)" as NSString
        
        if let data = try? JSONSerialization.data(withJSONObject: extraction.data) {
            let cost = data.count
            extractionCache.setObject(extraction, forKey: key, cost: cost)
        }
    }
    
    // MARK: - Regex Compilation Cache
    func getCompiledRegex(for pattern: String) -> NSRegularExpression? {
        if let cached = compiledRegexCache[pattern] {
            return cached
        }
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            compiledRegexCache[pattern] = regex
            return regex
        }
        
        return nil
    }
    
    private func precompileCommonPatterns() {
        let commonPatterns = [
            // Time patterns
            "([0-9]+) ?(hours?|hrs?) ago",
            "([0-9]+) ?(days?) ago",
            "since ([0-9]{1,2}(?::[0-9]{2})? ?(?:am|pm))",
            
            // Severity patterns
            "([0-9]{1,2})/10",
            "(mild|moderate|severe)",
            
            // Location patterns
            "(left|right|bilateral) (.+)",
            "(upper|lower|mid) (.+)",
            
            // Symptom patterns
            "(?:associated with|along with) (.+)",
            "(?:worse|better) (?:with|when) (.+)",
            "radiates? to (.+)"
        ]
        
        for pattern in commonPatterns {
            _ = getCompiledRegex(for: pattern)
        }
    }
    
    // MARK: - Performance Monitoring
    func logCacheStats() -> CacheStats {
        return CacheStats(
            patternCacheCount: 0, // NSCache doesn't expose count directly
            extractionCacheCount: 0, // NSCache doesn't expose count directly
            compiledRegexCount: compiledRegexCache.count,
            estimatedMemoryUsage: estimateMemoryUsage()
        )
    }
    
    private func estimateMemoryUsage() -> Int {
        // Rough estimate in bytes
        let patternMemory = 1024 * 100 // Assume avg 100 bytes per pattern
        let extractionMemory = 1024 * 500 // Assume avg 500 bytes per extraction
        let regexMemory = compiledRegexCache.count * 256 // Assume 256 bytes per regex
        
        return patternMemory + extractionMemory + regexMemory
    }
    
    func clearCache() {
        patternCache.removeAllObjects()
        extractionCache.removeAllObjects()
        // Keep compiled regex as they're expensive to recreate
    }
}

// MARK: - Supporting Types
enum PatternType: String {
    case chiefComplaint
    case timing
    case severity
    case location
    case quality
    case radiation
    case modifyingFactors
    case associatedSymptoms
    case ros
    case physicalExam
    case mdm
}

class CachedPattern: NSObject {
    let result: String
    let confidence: Double
    let timestamp: Date
    
    init(result: String, confidence: Double) {
        self.result = result
        self.confidence = confidence
        self.timestamp = Date()
    }
    
    var isExpired: Bool {
        // Cache for 1 hour
        return Date().timeIntervalSince(timestamp) > 3600
    }
}

class CachedExtraction: NSObject {
    let data: [String: Any]
    let confidence: Double
    let timestamp: Date
    
    init(data: [String: Any], confidence: Double) {
        self.data = data
        self.confidence = confidence
        self.timestamp = Date()
    }
    
    var isExpired: Bool {
        // Cache for 30 minutes
        return Date().timeIntervalSince(timestamp) > 1800
    }
}

struct CacheStats {
    let patternCacheCount: Int
    let extractionCacheCount: Int
    let compiledRegexCount: Int
    let estimatedMemoryUsage: Int
    
    var summary: String {
        return """
        === Cache Statistics ===
        Pattern Cache: \(patternCacheCount) entries
        Extraction Cache: \(extractionCacheCount) entries
        Compiled Regex: \(compiledRegexCount) patterns
        Est. Memory: \(estimatedMemoryUsage / 1024)KB
        """
    }
}

// MARK: - Optimized Extraction Pipeline
@MainActor
class OptimizedEDExtractor {
    private let cache = EDCacheService.shared
    private let patterns = EDPatternRecognitionService.shared
    
    func extractWithCaching(from transcript: String) async -> [String: Any] {
        // Check cache first
        if let cached = cache.getCachedExtraction(for: transcript),
           !cached.isExpired {
            Logger.medicalAIInfo("Using cached extraction")
            return cached.data
        }
        
        // Perform extraction
        let startTime = Date()
        
        // Extract components (not actually async, so no need for Task)
        let chiefComplaint = patterns.extractChiefComplaint(from: transcript)
        let hpi = patterns.extractDetailedHPI(from: transcript)
        let ros = patterns.extractStructuredROS(from: transcript)
        let pe = patterns.extractPhysicalExam(from: transcript)
        
        var result: [String: Any] = [:]
        
        if let cc = chiefComplaint {
            result["ChiefComplaint"] = cc
        }
        
        let hpiData = hpi
        if !hpiData.isEmpty {
            result["HPI"] = formatHPI(hpiData)
        }
        
        let rosData = ros
        if !rosData.isEmpty {
            result["ROS"] = rosData
        }
        
        if let peData = pe {
            result["PE"] = peData
        }
        
        let confidence = patterns.calculateConfidence(for: result)
        
        // Cache the result
        let extraction = CachedExtraction(data: result, confidence: confidence)
        cache.cacheExtraction(extraction, for: transcript)
        
        let elapsed = Date().timeIntervalSince(startTime)
        Logger.medicalAIInfo("Extraction completed in \(String(format: "%.3f", elapsed))s")
        
        return result
    }
    
    private func formatHPI(_ data: [String: Any]) -> String {
        var components: [String] = []
        
        if let onset = data["onset"] as? String {
            components.append(onset)
        }
        
        if let location = data["location"] as? String {
            components.append(location)
        }
        
        if let quality = data["quality"] as? String {
            components.append("\(quality) pain")
        }
        
        if let severity = data["severity"] as? String {
            components.append(severity)
        }
        
        if let radiation = data["radiation"] as? String {
            components.append(radiation)
        }
        
        if let modifiers = data["modifying_factors"] as? [String: [String]] {
            if let aggravating = modifiers["aggravating"] {
                components.append("worse with \(aggravating.joined(separator: ", "))")
            }
            if let alleviating = modifiers["alleviating"] {
                components.append("better with \(alleviating.joined(separator: ", "))")
            }
        }
        
        if let associated = data["associated_symptoms"] as? [String] {
            components.append("associated with \(associated.joined(separator: ", "))")
        }
        
        return components.joined(separator: ", ")
    }
}