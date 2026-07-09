import Foundation

/// A single thing a draft note claimed that is NOT grounded in the transcript.
public struct VerificationFlag: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case ungroundedMedication   // a drug never mentioned in the encounter
        case ungroundedDose         // a dose value not present near the drug
        case ungroundedRoute        // a route not present in the transcript
        case ungroundedLabValue     // a lab/result value not present near its test name
        case ungroundedVitalValue   // a vital sign value not present near its name
        case fabricatedPrecaution   // a return precaution outside the allowed library
    }
    public let kind: Kind
    public let claim: String   // what the note claimed
    public let detail: String  // why it was flagged

    public init(kind: Kind, claim: String, detail: String) {
        self.kind = kind; self.claim = claim; self.detail = detail
    }
}

public struct VerificationReport: Equatable, Codable, Sendable {
    public let flags: [VerificationFlag]
    public init(flags: [VerificationFlag]) { self.flags = flags }
    public var isClean: Bool { flags.isEmpty }
}

/// The deterministic last line of defense against a hallucinated dose or a swapped lab value.
///
/// It does NOT trust the model: every drug, dose, route, and lab/result value in the extracted
/// facts must appear VERBATIM in the encounter transcript, or it is flagged for review. Numeric
/// matching is digit-exact and boundary-aware — `3.2` never matches `7.2`, `32`, `13.2`, or
/// `3.25` — which is the whole point (a potassium of 3.2 vs 7.2 is the difference between fine
/// and a code). Values are checked NEAR their name, so a real "7.2" belonging to a different
/// test doesn't launder a wrong potassium.
///
/// Diagnosis is intentionally NOT string-verified here — it's a clinical conclusion, not a
/// transcript quote; its consistency check belongs with the differential (PR8). Return
/// precautions are verified against an allowed library, not the transcript (they're selected,
/// never free-text), when that library is supplied.
public struct GroundingVerifier {

    private let normalizedTranscript: String
    private let allowedPrecautions: Set<String>?
    private let proximityWindow: Int

    /// - Parameters:
    ///   - transcript: the ground-truth encounter transcript.
    ///   - allowedPrecautions: if provided, any return precaution not in this set is flagged.
    ///   - proximityWindow: how many characters after a name to look for its value.
    public init(transcript: String, allowedPrecautions: Set<String>? = nil, proximityWindow: Int = 80) {
        self.normalizedTranscript = Self.normalize(transcript)
        self.allowedPrecautions = allowedPrecautions.map { Set($0.map { Self.normalize($0) }) }
        self.proximityWindow = proximityWindow
    }

    public func verify(_ facts: ClinicalFacts) -> VerificationReport {
        var flags: [VerificationFlag] = []

        for med in facts.medications {
            let drugGrounded = phraseGrounded(med.drug)
            if !drugGrounded {
                flags.append(.init(kind: .ungroundedMedication, claim: med.drug,
                                   detail: "medication not mentioned in the transcript"))
                continue // no point checking a dose for a drug that was never said
            }
            if let dose = med.dose, !dose.isEmpty {
                let tokens = Self.numericTokens(in: dose)
                if !tokens.isEmpty, !valueGroundedNear(name: med.drug, numericTokens: tokens) {
                    flags.append(.init(kind: .ungroundedDose, claim: "\(med.drug) \(dose)",
                                       detail: "dose \(dose) not found near \(med.drug) in the transcript"))
                }
            }
            if let route = med.route, !route.isEmpty, !routeGrounded(route) {
                flags.append(.init(kind: .ungroundedRoute, claim: "\(med.drug) \(route)",
                                   detail: "route \(route) not present in the transcript"))
            }
        }

        for lab in facts.labs {
            let tokens = Self.numericTokens(in: lab.value)
            guard !tokens.isEmpty else { continue } // non-numeric result ("positive"); handled elsewhere
            if !valueGroundedNear(name: lab.test, numericTokens: tokens) {
                flags.append(.init(kind: .ungroundedLabValue, claim: "\(lab.test) \(lab.value)",
                                   detail: "value \(lab.value) not found near \(lab.test) in the transcript"))
            }
        }

        for vital in facts.vitals {
            let tokens = Self.numericTokens(in: vital.value)
            guard !tokens.isEmpty else { continue }
            if !valueGroundedNear(name: vital.name, numericTokens: tokens) {
                flags.append(.init(kind: .ungroundedVitalValue, claim: "\(vital.name) \(vital.value)",
                                   detail: "vital \(vital.value) not found near \(vital.name) in the transcript"))
            }
        }

        if let allowed = allowedPrecautions {
            for precaution in facts.returnPrecautions where !allowed.contains(Self.normalize(precaution)) {
                flags.append(.init(kind: .fabricatedPrecaution, claim: precaution,
                                   detail: "return precaution not in the approved library"))
            }
        }

        return VerificationReport(flags: flags)
    }

    /// GATE the note: return a copy of `facts` with every ungrounded medication, dose, lab value,
    /// and vital REMOVED (not merely flagged), plus a report of what was dropped. Nothing that
    /// isn't in the transcript can reach the rendered note — a hallucinated troponin is deleted,
    /// not annotated. Only same-value verified facts survive.
    public func filtered(_ facts: ClinicalFacts) -> (facts: ClinicalFacts, report: VerificationReport) {
        var flags: [VerificationFlag] = []
        var kept = facts

        kept.medications = facts.medications.filter { med in
            guard phraseGrounded(med.drug) else {
                flags.append(.init(kind: .ungroundedMedication, claim: med.drug, detail: "removed — drug not said in the encounter"))
                return false
            }
            if let dose = med.dose, !dose.isEmpty {
                let tokens = Self.numericTokens(in: dose)
                if !tokens.isEmpty, !valueGroundedNear(name: med.drug, numericTokens: tokens) {
                    flags.append(.init(kind: .ungroundedDose, claim: "\(med.drug) \(dose)", detail: "removed — dose not said near the drug"))
                    return false
                }
            }
            return true
        }

        kept.labs = facts.labs.filter { lab in
            let tokens = Self.numericTokens(in: lab.value)
            guard !tokens.isEmpty else { return false } // no numeric result → not a real lab value
            if !valueGroundedNear(name: lab.test, numericTokens: tokens) {
                flags.append(.init(kind: .ungroundedLabValue, claim: "\(lab.test) \(lab.value)", detail: "removed — result not said in the encounter"))
                return false
            }
            return true
        }

        kept.vitals = facts.vitals.filter { vital in
            let tokens = Self.numericTokens(in: vital.value)
            guard !tokens.isEmpty else { return true } // non-numeric vital label; keep
            if !valueGroundedNear(name: vital.name, numericTokens: tokens) {
                flags.append(.init(kind: .ungroundedVitalValue, claim: "\(vital.name) \(vital.value)", detail: "removed — value not said in the encounter"))
                return false
            }
            return true
        }

        if let allowed = allowedPrecautions {
            kept.returnPrecautions = facts.returnPrecautions.filter { p in
                if allowed.contains(Self.normalize(p)) { return true }
                flags.append(.init(kind: .fabricatedPrecaution, claim: p, detail: "removed — not in the approved library"))
                return false
            }
        }

        return (kept, VerificationReport(flags: flags))
    }

    // MARK: - Matching primitives

    /// A phrase (drug/test name) appears in the transcript, whitespace/case-insensitive.
    private func phraseGrounded(_ phrase: String) -> Bool {
        let n = Self.normalize(phrase)
        guard !n.isEmpty else { return false }
        return normalizedTranscript.contains(n)
    }

    /// A route word appears anywhere in the transcript (routes aren't tied to one position).
    private func routeGrounded(_ route: String) -> Bool {
        let n = Self.normalize(route)
        guard !n.isEmpty else { return true }
        // Expand common abbreviations so "IV" grounds against "intravenous" and vice-versa.
        let synonyms = Self.routeSynonyms[n] ?? [n]
        return synonyms.contains { normalizedTranscript.contains($0) }
    }

    /// A value is grounded only if its FIRST numeric token is the number ADJACENT to the name —
    /// the first number after it (`potassium 3.2`) or the last number before it (`3.2 potassium`)
    /// within the window — and its remaining tokens are also in that window. Binding to the
    /// adjacent number is what stops a different test's value from laundering a swap: with
    /// "glucose 7.2 and potassium 3.2", a claimed potassium of 7.2 is NOT the number next to
    /// "potassium" (that's 3.2), so it is correctly flagged even though 7.2 appears nearby.
    private func valueGroundedNear(name: String, numericTokens tokens: [String]) -> Bool {
        let n = Self.normalize(name)
        guard !n.isEmpty, let firstToken = tokens.first else { return false }
        let hay = normalizedTranscript
        var searchStart = hay.startIndex
        while let r = hay.range(of: n, range: searchStart..<hay.endIndex) {
            let fwdEnd = hay.index(r.upperBound, offsetBy: proximityWindow, limitedBy: hay.endIndex) ?? hay.endIndex
            let bwdStart = hay.index(r.lowerBound, offsetBy: -proximityWindow, limitedBy: hay.startIndex) ?? hay.startIndex
            // Clip each side at the nearest item separator so binding never crosses into a
            // neighbouring lab/med ("glucose 7.2, potassium 3.2" — 7.2 must not bind to potassium).
            let forward = Self.headBeforeFirstSeparator(String(hay[r.upperBound..<fwdEnd]))
            let backward = Self.tailAfterLastSeparator(String(hay[bwdStart..<r.lowerBound]))

            let adjacent = Self.firstNumericToken(in: forward) == firstToken
                || Self.lastNumericToken(in: backward) == firstToken
            if adjacent {
                let rest = tokens.dropFirst()
                if rest.allSatisfy({ Self.numberPresent($0, in: forward) || Self.numberPresent($0, in: backward) }) {
                    return true
                }
            }
            searchStart = r.upperBound
        }
        return false
    }

    /// Item separators between clinical values — a value binds only within its own run.
    /// NOTE: "." is deliberately NOT a separator char (it is a decimal point in "3.2"); a
    /// sentence break is handled as the ". " phrase instead.
    private static let separatorChars = CharacterSet(charactersIn: ",;\n\t")
    private static let separatorPhrases = [". ", " and ", " with ", " plus ", " but "]

    /// The run from the start of `s` up to the first separator.
    static func headBeforeFirstSeparator(_ s: String) -> String {
        var head = s
        if let idx = head.unicodeScalars.firstIndex(where: { separatorChars.contains($0) }) {
            head = String(String.UnicodeScalarView(head.unicodeScalars[head.unicodeScalars.startIndex..<idx]))
        }
        for phrase in separatorPhrases {
            if let range = head.range(of: phrase) { head = String(head[head.startIndex..<range.lowerBound]) }
        }
        return head
    }

    /// The run from the last separator to the end of `s`.
    static func tailAfterLastSeparator(_ s: String) -> String {
        var tail = s
        if let idx = tail.unicodeScalars.lastIndex(where: { separatorChars.contains($0) }) {
            let after = tail.unicodeScalars.index(after: idx)
            tail = String(String.UnicodeScalarView(tail.unicodeScalars[after..<tail.unicodeScalars.endIndex]))
        }
        for phrase in separatorPhrases {
            if let range = tail.range(of: phrase, options: .backwards) { tail = String(tail[range.upperBound...]) }
        }
        return tail
    }

    // MARK: - Static helpers

    static func normalize(_ s: String) -> String {
        let lowered = s.lowercased()
        let collapsed = lowered.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        )
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract numeric tokens like "324", "3.2", "12.5" from a value string.
    static func numericTokens(in value: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: "[0-9]+(?:\\.[0-9]+)?") else { return [] }
        let ns = value as NSString
        let matches = re.matches(in: value, range: NSRange(location: 0, length: ns.length))
        return matches.map { ns.substring(with: $0.range) }
    }

    static func firstNumericToken(in text: String) -> String? {
        numericTokens(in: text).first
    }

    static func lastNumericToken(in text: String) -> String? {
        numericTokens(in: text).last
    }

    /// Digit-exact, boundary-aware presence: `3.2` matches `3.2` but not `13.2`, `3.25`, or `32`.
    static func numberPresent(_ token: String, in text: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: token)
        let pattern = "(?<![0-9.])\(escaped)(?![0-9.])"
        guard let re = try? NSRegularExpression(pattern: pattern) else {
            return text.contains(token)
        }
        let ns = text as NSString
        return re.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    private static let routeSynonyms: [String: [String]] = [
        "iv": ["iv", "intravenous"],
        "intravenous": ["intravenous", "iv"],
        "po": ["po", "oral", "by mouth"],
        "oral": ["oral", "po", "by mouth"],
        "im": ["im", "intramuscular"],
        "intramuscular": ["intramuscular", "im"],
        "sl": ["sl", "sublingual"],
        "sublingual": ["sublingual", "sl"],
        "sq": ["sq", "subcutaneous", "subq"],
        "subcutaneous": ["subcutaneous", "sq", "subq"],
    ]
}
