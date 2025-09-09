import Foundation
import Accelerate

// MARK: - Circular Buffer for Audio Data (Generic)
final class CircularBuffer<T> {
    private var buffer: [T]
    private var head = 0
    private var tail = 0
    private var count = 0
    private let capacity: Int
    
    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.buffer = Array(repeating: defaultValue, count: capacity)
    }
    
    func write(_ data: UnsafePointer<T>, count: Int) {
        for i in 0..<count {
            buffer[head] = data[i]
            head = (head + 1) % capacity
            if self.count < capacity {
                self.count += 1
            } else {
                tail = (tail + 1) % capacity
            }
        }
    }
    
    func read(_ data: UnsafeMutablePointer<T>, count: Int) -> Int {
        let actualCount = min(count, self.count)
        for i in 0..<actualCount {
            data[i] = buffer[tail]
            tail = (tail + 1) % capacity
        }
        self.count -= actualCount
        return actualCount
    }
}

// MARK: - Simple Noise Gate Implementation
final class NoiseGate {
    private let threshold: Float
    private var isOpen = false
    private let attackTime: Float = 0.001  // 1ms
    private let releaseTime: Float = 0.1   // 100ms
    private var envelope: Float = 0.0
    
    init(threshold: Float) {
        self.threshold = threshold
    }
    
    func process(_ input: UnsafePointer<Float>, output: UnsafeMutablePointer<Float>, frameCount: Int) {
        for i in 0..<frameCount {
            let inputLevel = abs(input[i])
            let inputLevelDb = 20 * log10(max(inputLevel, 1e-6))
            
            // Update gate state
            if inputLevelDb > threshold {
                isOpen = true
                envelope = min(1.0, envelope + attackTime)
            } else {
                envelope = max(0.0, envelope - releaseTime)
                if envelope <= 0.0 {
                    isOpen = false
                }
            }
            
            output[i] = input[i] * envelope
        }
    }
}

// MARK: - Audio Level Processor (Backend Processing)
final class AudioLevelProcessor {
    private var runningAverage: Float = 0.0
    private let smoothing: Float = 0.9
    
    func process(_ input: UnsafePointer<Float>, frameCount: Int) -> Float {
        var sum: Float = 0.0
        vDSP_svesq(input, 1, &sum, vDSP_Length(frameCount))
        
        let rms = sqrt(sum / Float(frameCount))
        let db = 20 * log10(max(rms, 1e-6))
        
        runningAverage = smoothing * runningAverage + (1 - smoothing) * db
        
        // Convert to 0-1 range for UI (-60dB to 0dB)
        return max(0.0, min(1.0, (runningAverage + 60.0) / 60.0))
    }
}
