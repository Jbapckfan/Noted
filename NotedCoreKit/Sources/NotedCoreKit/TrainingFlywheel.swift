import Foundation

/// One supervised training example in the shared chat/JSONL schema, tagged by task.
public struct TrainingPair: Codable, Equatable, Sendable {
    public var task: String   // "extraction" | "note" | "discharge"
    public var input: String
    public var output: String
    public init(task: String, input: String, output: String) {
        self.task = task; self.input = input; self.output = output
    }
}

/// The flywheel: James's corrected, SIGNED notes become new training pairs that pull the adapters
/// toward his voice over time.
///
/// SAFETY CONTRACT — these pairs are on-device and PRE-SCRUB. They MUST pass the de-identification
/// pipeline (Philter → Presidio surrogate substitution → 100% manual review) before any training,
/// and raw audio is never exported (text pairs only). This exporter produces the material; it does
/// NOT de-identify and nothing here should leave the device un-scrubbed.
public enum TrainingFlywheel {

    /// Only SIGNED encounters contribute (a signed note is a corrected gold target).
    public static func pairs(from e: Encounter) -> [TrainingPair] {
        guard e.phase == .signed else { return [] }
        var pairs: [TrainingPair] = []

        if let transcript = nonEmpty(e.transcript), let extraction = nonEmpty(e.extractionJSON) {
            pairs.append(TrainingPair(task: "extraction", input: transcript, output: extraction))
        }
        if let extraction = nonEmpty(e.extractionJSON), let note = nonEmpty(e.noteText) {
            pairs.append(TrainingPair(task: "note", input: extraction, output: note))
        }
        if let discharge = nonEmpty(e.dischargeJSON) {
            let source = [e.extractionJSON, e.resultsTrayJSON, e.dispositionTranscript]
                .compactMap { nonEmpty($0) }
                .joined(separator: "\n")
            if !source.isEmpty {
                pairs.append(TrainingPair(task: "discharge", input: source, output: discharge))
            }
        }
        return pairs
    }

    public static func pairs(from encounters: [Encounter]) -> [TrainingPair] {
        encounters.flatMap { pairs(from: $0) }
    }

    public static func jsonl(_ pairs: [TrainingPair]) -> String {
        let encoder = JSONEncoder()
        return pairs
            .compactMap { try? encoder.encode($0) }
            .compactMap { String(data: $0, encoding: .utf8) }
            .joined(separator: "\n")
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return s
    }
}
