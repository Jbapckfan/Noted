import Foundation

// MARK: - Performance Optimization Utilities

/// Efficient string builder for reducing concatenation overhead
final class StringBuilder {
    private var components: [String] = []
    private var estimatedLength: Int = 0
    
    init() {}
    
    @discardableResult
    func append(_ string: String) -> StringBuilder {
        components.append(string)
        estimatedLength += string.count
        return self
    }
    
    @discardableResult
    func appendLine(_ string: String = "") -> StringBuilder {
        components.append(string + "\n")
        estimatedLength += string.count + 1
        return self
    }
    
    @discardableResult
    func appendJoined(_ items: [String], separator: String = ", ") -> StringBuilder {
        let joined = items.joined(separator: separator)
        components.append(joined)
        estimatedLength += joined.count
        return self
    }
    
    func build() -> String {
        // Reserve capacity for better performance
        var result = String()
        result.reserveCapacity(estimatedLength)
        return components.joined()
    }
    
    func clear() {
        components.removeAll(keepingCapacity: true)
        estimatedLength = 0
    }
}

/// Circular buffer for efficient transcription management without memory spikes
final class CircularStringBuffer {
    private var buffer: [String] = []
    private let maxCapacity: Int
    private let chunkSize: Int
    private var currentLength: Int = 0
    
    init(maxCapacity: Int, chunkSize: Int = 1000) {
        self.maxCapacity = maxCapacity
        self.chunkSize = chunkSize
        buffer.reserveCapacity(maxCapacity / chunkSize)
    }
    
    func append(_ text: String) {
        // Break text into chunks for better memory management
        let chunks = stride(from: 0, to: text.count, by: chunkSize).map {
            let start = text.index(text.startIndex, offsetBy: $0)
            let end = text.index(start, offsetBy: min(chunkSize, text.count - $0))
            return String(text[start..<end])
        }
        
        for chunk in chunks {
            buffer.append(chunk)
            currentLength += chunk.count
        }
        
        // Remove oldest chunks if over capacity
        while currentLength > maxCapacity && !buffer.isEmpty {
            let removed = buffer.removeFirst()
            currentLength -= removed.count
        }
    }
    
    func getText() -> String {
        // Efficient joining without intermediate strings
        let result = buffer.joined()
        
        // If still over capacity after joining, truncate from beginning
        if result.count > maxCapacity {
            let keepLength = Int(Double(maxCapacity) * 0.9)
            let startIndex = result.index(result.endIndex, offsetBy: -keepLength, limitedBy: result.startIndex) ?? result.startIndex
            return String(result[startIndex...])
        }
        
        return result
    }
    
    func clear() {
        buffer.removeAll(keepingCapacity: true)
        currentLength = 0
    }
    
    var count: Int {
        return currentLength
    }
}

/// LRU Cache for caching expensive string operations
final class LRUCache<Key: Hashable, Value> {
    private let capacity: Int
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let queue = DispatchQueue(label: "com.notedcore.lrucache", attributes: .concurrent)
    
    init(capacity: Int) {
        self.capacity = max(1, capacity)
        cache.reserveCapacity(capacity)
        accessOrder.reserveCapacity(capacity)
    }
    
    func get(_ key: Key) -> Value? {
        queue.sync {
            guard let value = cache[key] else { return nil }
            
            // Move to end (most recently used)
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(key)
            
            return value
        }
    }
    
    func set(_ key: Key, _ value: Value) {
        queue.async(flags: .barrier) {
            // If key exists, remove old position
            if self.cache[key] != nil {
                if let index = self.accessOrder.firstIndex(of: key) {
                    self.accessOrder.remove(at: index)
                }
            }
            
            // Add to cache and access order
            self.cache[key] = value
            self.accessOrder.append(key)
            
            // Evict oldest if over capacity
            while self.accessOrder.count > self.capacity {
                let oldest = self.accessOrder.removeFirst()
                self.cache.removeValue(forKey: oldest)
            }
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll(keepingCapacity: true)
            self.accessOrder.removeAll(keepingCapacity: true)
        }
    }
}

/// Specialized cache for lowercased string operations
final class StringCache {
    static let shared = StringCache()
    
    private let lowercaseCache = LRUCache<String, String>(capacity: 100)
    private let trimmedCache = LRUCache<String, String>(capacity: 100)
    
    private init() {}
    
    func lowercased(_ string: String) -> String {
        if let cached = lowercaseCache.get(string) {
            return cached
        }
        
        let result = string.lowercased()
        lowercaseCache.set(string, result)
        return result
    }
    
    func trimmed(_ string: String) -> String {
        if let cached = trimmedCache.get(string) {
            return cached
        }
        
        let result = string.trimmingCharacters(in: .whitespacesAndNewlines)
        trimmedCache.set(string, result)
        return result
    }
    
    func clear() {
        lowercaseCache.clear()
        trimmedCache.clear()
    }
}

/// Change detector for avoiding unnecessary computations
final class ChangeDetector<T: Hashable> {
    private var lastValue: T?
    private var lastHash: Int?
    
    func hasChanged(_ value: T) -> Bool {
        let currentHash = value.hashValue
        
        if let lastHash = lastHash, lastHash == currentHash {
            // Hash matches, check actual value to be sure
            if let lastValue = lastValue, lastValue == value {
                return false
            }
        }
        
        lastValue = value
        lastHash = currentHash
        return true
    }
    
    func reset() {
        lastValue = nil
        lastHash = nil
    }
}

/// Specialized change detector for strings
final class StringChangeDetector {
    private var lastLength: Int = 0
    private var lastHash: Int = 0
    private var lastSample: String = ""
    
    func hasChanged(_ string: String) -> Bool {
        // Quick check: length change
        guard string.count == lastLength else {
            updateState(string)
            return true
        }
        
        // Quick check: hash change
        let currentHash = string.hashValue
        guard currentHash == lastHash else {
            updateState(string)
            return true
        }
        
        // Sample check: compare first and last 100 characters
        let sampleSize = min(100, string.count)
        let currentSample = String(string.prefix(sampleSize)) + String(string.suffix(sampleSize))
        
        guard currentSample == lastSample else {
            updateState(string)
            return true
        }
        
        return false
    }
    
    private func updateState(_ string: String) {
        lastLength = string.count
        lastHash = string.hashValue
        let sampleSize = min(100, string.count)
        lastSample = String(string.prefix(sampleSize)) + String(string.suffix(sampleSize))
    }
    
    func reset() {
        lastLength = 0
        lastHash = 0
        lastSample = ""
    }
}