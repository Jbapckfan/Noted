import Foundation

/// Held-out eval metrics for a trained adapter, on the honest real-ED test split.
public struct AdapterEvalMetrics: Codable, Equatable, Sendable {
    public var hallucinationRate: Double   // fabricated facts — dangerous
    public var omissionRate: Double        // dropped facts — the ED-dangerous error
    public var structureValidity: Double   // fraction that parse to the schema (0…1)

    public init(hallucinationRate: Double, omissionRate: Double, structureValidity: Double) {
        self.hallucinationRate = hallucinationRate
        self.omissionRate = omissionRate
        self.structureValidity = structureValidity
    }
}

/// The ship/no-ship gate. An adapter ships ONLY if it clears every bar on the held-out real-ED
/// split — and the SAME gate is re-run on the quantized shipped artifact (quantization can move
/// error rates; gate on numbers, not "it loaded").
public enum AdapterGate {
    public static let maxHallucination = 0.0147
    public static let maxOmission = 0.0345
    public static let minStructureValidity = 0.99

    public static func failures(_ m: AdapterEvalMetrics) -> [String] {
        var out: [String] = []
        if m.hallucinationRate > maxHallucination {
            out.append("hallucination \(pct(m.hallucinationRate)) > \(pct(maxHallucination))")
        }
        if m.omissionRate > maxOmission {
            out.append("omission \(pct(m.omissionRate)) > \(pct(maxOmission))")
        }
        if m.structureValidity < minStructureValidity {
            out.append("structure validity \(pct(m.structureValidity)) < \(pct(minStructureValidity))")
        }
        return out
    }

    public static func passes(_ m: AdapterEvalMetrics) -> Bool { failures(m).isEmpty }

    private static func pct(_ x: Double) -> String { String(format: "%.2f%%", x * 100) }
}

/// One shippable adapter (the base stays shared; adapters are NOT fused — fusing triples shipped
/// weight). `gatePassed` is computed from the metrics so an ungated adapter can never be marked shippable.
public struct AdapterManifest: Codable, Equatable, Sendable {
    public var task: String        // "extraction" | "note" | "discharge"
    public var version: String
    public var fileName: String
    public var baseModel: String
    public var metrics: AdapterEvalMetrics
    public var gatePassed: Bool

    public init(task: String, version: String, fileName: String, baseModel: String, metrics: AdapterEvalMetrics) {
        self.task = task
        self.version = version
        self.fileName = fileName
        self.baseModel = baseModel
        self.metrics = metrics
        self.gatePassed = AdapterGate.passes(metrics)
    }

    /// A bundle ships only when every adapter cleared the gate.
    public static func shippable(_ manifests: [AdapterManifest]) -> Bool {
        !manifests.isEmpty && manifests.allSatisfy { $0.gatePassed }
    }
}
