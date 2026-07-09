import Foundation

/// The kind of microphone an input port represents. The app maps `AVAudioSession.Port` onto this;
/// the SELECTION policy is pure and unit-tested.
public enum AudioInputKind: Sendable, Equatable {
    case bluetooth   // AVAudioSession .bluetoothHFP — a paired BT mic/headset
    case wired       // headset mic, USB, line-in
    case builtIn     // the device's own mic
    case other
}

public struct AudioInputOption: Sendable, Equatable {
    public let name: String
    public let kind: AudioInputKind
    public init(name: String, kind: AudioInputKind) {
        self.name = name
        self.kind = kind
    }
}

/// Chooses which microphone to record from. A clinician wearing a Bluetooth mic expects it to be
/// used; so a connected BT input wins over wired, which wins over the built-in mic. If a manual
/// preference is set and still available, it's honored.
public enum AudioRoutePolicy {

    /// Preference order: Bluetooth > wired > built-in > other.
    public static func preferred(
        from options: [AudioInputOption],
        manual: AudioInputOption? = nil
    ) -> AudioInputOption? {
        if let manual, options.contains(manual) { return manual }
        let ranked = options.sorted { rank($0.kind) < rank($1.kind) }
        return ranked.first
    }

    /// True if a Bluetooth mic is available to record from.
    public static func hasBluetooth(_ options: [AudioInputOption]) -> Bool {
        options.contains { $0.kind == .bluetooth }
    }

    private static func rank(_ kind: AudioInputKind) -> Int {
        switch kind {
        case .bluetooth: return 0
        case .wired:     return 1
        case .builtIn:   return 2
        case .other:     return 3
        }
    }
}
