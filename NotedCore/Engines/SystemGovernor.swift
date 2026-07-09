//  SystemGovernor.swift
//  Feeds live system signals (thermal state, memory pressure, battery / low-power) into the pure
//  EngineGovernor policy (which is unit-tested in NotedCoreKit). This is the only part that is
//  device-specific; the DECISIONS it makes are all tested. Pass an instance to GenerationWorker.
//
//  DEVICE-ONLY. The scenePhase + BGContinuedProcessingTask + MetricKit wiring lives in the app
//  entry point (see docs/INTEGRATION.md).

import Foundation
import NotedCoreKit
#if os(iOS)
import UIKit

public final class SystemGovernor: GenerationGovernor, @unchecked Sendable {
    private let lock = NSLock()
    private var memory: MemoryPressure = .normal
    private var memorySource: DispatchSourceMemoryPressure?

    public init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global())
        source.setEventHandler { [weak self] in
            guard let self, let data = self.memorySource?.data else { return }
            self.lock.lock()
            if data.contains(.critical) { self.memory = .critical }
            else if data.contains(.warning) { self.memory = max(self.memory, .warning) }
            self.lock.unlock()
        }
        source.resume()
        self.memorySource = source
    }

    public func decisionNow() -> GovernorDecision {
        EngineGovernor.decision(thermal: thermalLevel(), memory: currentMemory(), power: powerState())
    }

    /// What to do with resident models right now (call from a memory-pressure handler).
    public func modelActionNow() -> ModelAction {
        EngineGovernor.modelAction(memory: currentMemory())
    }

    /// Call after models have been shed so pressure state doesn't stay latched.
    public func clearMemoryPressure() {
        lock.lock(); memory = .normal; lock.unlock()
    }

    // MARK: - Signal mapping

    private func currentMemory() -> MemoryPressure {
        lock.lock(); defer { lock.unlock() }
        return memory
    }

    private func thermalLevel() -> ThermalLevel {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return .nominal
        case .fair:     return .fair
        case .serious:  return .serious
        case .critical: return .critical
        @unknown default: return .fair
        }
    }

    private func powerState() -> PowerState {
        let low = ProcessInfo.processInfo.isLowPowerModeEnabled
        let level = UIDevice.current.batteryLevel // -1 when unknown
        return PowerState(lowPowerMode: low, batteryFraction: level < 0 ? 1.0 : Double(level))
    }
}

private func max(_ a: MemoryPressure, _ b: MemoryPressure) -> MemoryPressure {
    a.rawValue >= b.rawValue ? a : b
}
#endif
