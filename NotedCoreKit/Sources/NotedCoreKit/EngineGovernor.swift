import Foundation

/// System signals the governor reacts to. The app maps `ProcessInfo.thermalState`,
/// `DispatchSource` memory pressure, and battery/low-power state onto these; the POLICY that
/// turns them into decisions is pure and unit-tested.
public enum ThermalLevel: Int, Sendable, Comparable {
    case nominal, fair, serious, critical
    public static func < (a: ThermalLevel, b: ThermalLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum MemoryPressure: Int, Sendable {
    case normal, warning, critical
}

public struct PowerState: Sendable {
    public var lowPowerMode: Bool
    public var batteryFraction: Double // 0…1
    public init(lowPowerMode: Bool = false, batteryFraction: Double = 1.0) {
        self.lowPowerMode = lowPowerMode
        self.batteryFraction = batteryFraction
    }
}

/// What the generation queue should do right now.
public enum GovernorDecision: Equatable, Sendable {
    case drainNormally
    case coolDownBetweenJobs(seconds: Double) // serious thermal: space out backlog draining
    case pauseQueue(reason: String)           // critical thermal/memory, or low-power+low-battery
}

/// What to do with resident models under memory pressure.
public enum ModelAction: Equatable, Sendable {
    case keepLoaded
    case unloadLLM  // warning: drop the big LLM, keep Whisper
    case unloadAll  // critical: drop everything and pause
}

/// The governance POLICY. Pure functions of the system signals — no observers, no side effects,
/// so every branch is unit-tested. The one invariant it encodes but never touches: RECORDING IS
/// PROTECTED. Capture holds no models, so nothing here ever sheds or pauses the mic — these
/// decisions apply only to the generation queue and the resident models.
public enum EngineGovernor {

    public static func decision(thermal: ThermalLevel, memory: MemoryPressure, power: PowerState) -> GovernorDecision {
        if memory == .critical { return .pauseQueue(reason: "memory critical") }
        if thermal == .critical { return .pauseQueue(reason: "device too hot") }
        // Skip opportunistic backlog draining on low power + low battery — drain on demand instead.
        if power.lowPowerMode && power.batteryFraction < 0.20 {
            return .pauseQueue(reason: "low power mode, battery < 20%")
        }
        if thermal == .serious {
            // Measured: sustained back-to-back draining collapses throughput with no recovery in
            // tight gaps. Insert a cool-down between backlog jobs.
            return .coolDownBetweenJobs(seconds: 75)
        }
        return .drainNormally
    }

    public static func modelAction(memory: MemoryPressure) -> ModelAction {
        switch memory {
        case .normal:   return .keepLoaded
        case .warning:  return .unloadLLM
        case .critical: return .unloadAll
        }
    }

    /// Generation parameters under thermal stress: cap tokens + greedy decode when serious.
    public static func generationLimits(thermal: ThermalLevel) -> (maxTokens: Int?, greedy: Bool) {
        thermal >= .serious ? (512, true) : (nil, false)
    }
}

/// The worker consults this before each job. The app provides one backed by live system signals;
/// the default drains normally (so tests and the simulator aren't gated by fake thermal state).
public protocol GenerationGovernor: Sendable {
    func decisionNow() -> GovernorDecision
}

public struct AlwaysDrainGovernor: GenerationGovernor {
    public init() {}
    public func decisionNow() -> GovernorDecision { .drainNormally }
}
