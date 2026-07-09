import Foundation

/// A single thing a draft note claimed that is NOT grounded in the transcript.
public struct VerificationFlag: Equatable, Codable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case ungroundedMedication   // a drug never mentioned in the encounter
        case ungroundedDose         // a dose value (or its unit) not present near the drug
        case ungroundedRoute        // a route not present in the transcript
        case ungroundedFrequency    // a dosing frequency not present in the transcript
        case ungroundedLabValue     // a lab/result value not present near its test name
        case ungroundedVitalValue   // a vital sign value not present near its name
        case ungroundedNarrative    // a free-text sentence (HPI/MDM/exam) not supported by the transcript
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
                if !tokens.isEmpty, !valueGroundedNear(name: med.drug, numericTokens: tokens, unit: Self.claimedUnit(inValue: dose)) {
                    flags.append(.init(kind: .ungroundedDose, claim: "\(med.drug) \(dose)",
                                       detail: "dose \(dose) (value or unit) not found near \(med.drug) in the transcript"))
                }
            }
            if let route = med.route, !route.isEmpty, !routeGrounded(route) {
                flags.append(.init(kind: .ungroundedRoute, claim: "\(med.drug) \(route)",
                                   detail: "route \(route) not present in the transcript"))
            }
            if let freq = med.frequency, !freq.isEmpty, !frequencyGrounded(freq, near: med.drug) {
                flags.append(.init(kind: .ungroundedFrequency, claim: "\(med.drug) \(freq)",
                                   detail: "frequency \(freq) not present in the transcript"))
            }
        }

        for lab in facts.labs {
            let tokens = Self.numericTokens(in: lab.value)
            guard !tokens.isEmpty else { continue } // non-numeric result ("positive"); handled elsewhere
            let unit = lab.unit.flatMap { $0.isEmpty ? nil : $0 } ?? Self.claimedUnit(inValue: lab.value)
            if !valueGroundedNear(name: lab.test, numericTokens: tokens, unit: unit, comparator: Self.claimedComparator(in: lab.value)) {
                flags.append(.init(kind: .ungroundedLabValue, claim: "\(lab.test) \(lab.value)",
                                   detail: "value \(lab.value) (value, unit, or comparator) not found near \(lab.test) in the transcript"))
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

        // Per-field pruning: if the DRUG was said, keep the medication but strip any sub-field
        // (dose, route, frequency) that isn't grounded — rather than dropping the whole med or
        // (worse) keeping a fabricated route/frequency on a real drug. A bad dose UNIT (mg vs mcg)
        // strips the dose, since a 1000x-off dose is worse than no dose.
        kept.medications = facts.medications.compactMap { med -> Medication? in
            guard phraseGrounded(med.drug) else {
                flags.append(.init(kind: .ungroundedMedication, claim: med.drug, detail: "removed — drug not said in the encounter"))
                return nil
            }
            var m = med
            if let dose = m.dose, !dose.isEmpty {
                let tokens = Self.numericTokens(in: dose)
                if !tokens.isEmpty, !valueGroundedNear(name: m.drug, numericTokens: tokens, unit: Self.claimedUnit(inValue: dose)) {
                    flags.append(.init(kind: .ungroundedDose, claim: "\(m.drug) \(dose)", detail: "removed — dose value or unit not said near the drug"))
                    m.dose = nil
                }
            }
            if let route = m.route, !route.isEmpty, !routeGrounded(route) {
                flags.append(.init(kind: .ungroundedRoute, claim: "\(m.drug) \(route)", detail: "removed — route not said in the encounter"))
                m.route = nil
            }
            if let freq = m.frequency, !freq.isEmpty, !frequencyGrounded(freq, near: m.drug) {
                flags.append(.init(kind: .ungroundedFrequency, claim: "\(m.drug) \(freq)", detail: "removed — frequency not said in the encounter"))
                m.frequency = nil
            }
            return m
        }

        kept.labs = facts.labs.filter { lab in
            let tokens = Self.numericTokens(in: lab.value)
            guard !tokens.isEmpty else { return false } // no numeric result → not a real lab value
            let unit = lab.unit.flatMap { $0.isEmpty ? nil : $0 } ?? Self.claimedUnit(inValue: lab.value)
            if !valueGroundedNear(name: lab.test, numericTokens: tokens, unit: unit, comparator: Self.claimedComparator(in: lab.value)) {
                flags.append(.init(kind: .ungroundedLabValue, claim: "\(lab.test) \(lab.value)", detail: "removed — result value, unit, or comparator not said in the encounter"))
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

        // Ground the FREE-TEXT narrative: keep only sentences whose content words are supported by
        // the transcript. A fabricated HPI (e.g. the patient never actually spoke) shares almost no
        // vocabulary with the transcript and is removed wholesale.
        kept.hpi = groundNarrative(facts.hpi, field: "HPI narrative", into: &flags)
        kept.reviewOfSystems = groundNarrative(facts.reviewOfSystems, field: "Review of systems", into: &flags)
        kept.physicalExam = groundNarrative(facts.physicalExam, field: "Physical exam", into: &flags)
        kept.mdm = groundNarrative(facts.mdm, field: "MDM narrative", into: &flags)

        if let allowed = allowedPrecautions {
            kept.returnPrecautions = facts.returnPrecautions.filter { p in
                if allowed.contains(Self.normalize(p)) { return true }
                flags.append(.init(kind: .fabricatedPrecaution, claim: p, detail: "removed — not in the approved library"))
                return false
            }
        }

        return (kept, VerificationReport(flags: flags))
    }

    /// Keep only the sentences of a free-text field whose content words appear in the transcript.
    /// Returns nil if nothing survives (records a flag for what was dropped).
    private func groundNarrative(_ text: String?, field: String, into flags: inout [VerificationFlag]) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let transcriptWords = Self.contentWords(normalizedTranscript)
        guard !transcriptWords.isEmpty else {
            flags.append(.init(kind: .ungroundedNarrative, claim: field, detail: "removed — no transcript to support it"))
            return nil
        }
        let sentences = text.split(whereSeparator: { ".!?\n".contains($0) }).map(String.init)
        var kept: [String] = []
        var dropped = false
        for sentence in sentences {
            let words = Self.contentWords(Self.normalize(sentence))
            guard !words.isEmpty else { continue }
            let supported = words.filter { transcriptWords.contains($0) }.count
            let overlap = Double(supported) / Double(words.count)
            if overlap >= 0.5 {
                kept.append(sentence.trimmingCharacters(in: .whitespaces))
            } else {
                dropped = true
            }
        }
        if dropped {
            flags.append(.init(kind: .ungroundedNarrative, claim: field,
                               detail: "removed unsupported sentence(s) — not stated in the transcript"))
        }
        let result = kept.joined(separator: ". ").trimmingCharacters(in: .whitespaces)
        if result.isEmpty { return nil }
        return result.hasSuffix(".") ? result : result + "."
    }

    /// Meaningful (non-stopword) word tokens for coarse narrative grounding.
    static func contentWords(_ normalizedText: String) -> Set<String> {
        let stop: Set<String> = [
            "the","and","that","this","with","for","was","were","are","been","being","has","have","had",
            "you","your","not","from","but","all","can","will","would","could","should","into","out","about",
            "some","any","his","her","him","she","they","them","their","our","which","what","when","where",
            "who","how","why","also","then","than","just","like","get","got","now","one","two","today",
        ]
        return Set(
            normalizedText
                .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
                .map(String.init)
                .filter { $0.count > 2 && !stop.contains($0) }
        )
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
        // WHOLE-WORD match so "IV" doesn't ground on the "iv" inside "give", "PO" inside "reports",
        // or "IM" inside "time". Expand abbreviations so "IV" grounds against "intravenous".
        let synonyms = Self.routeSynonyms[n] ?? [n]
        return synonyms.contains { Self.wordPresent($0, in: normalizedTranscript) }
    }

    /// A dosing frequency is grounded if it (or a common spoken form of it) appears AS A WHOLE WORD
    /// within the drug's vicinity. Fail-closed: an unrecognized/absent frequency is stripped so a
    /// fabricated schedule ("ten times daily") never reaches the chart. Whole-word + near-drug stops
    /// "TID" grounding on "tidal" and a global "twice/at night" far from the drug.
    private func frequencyGrounded(_ frequency: String, near drug: String) -> Bool {
        let f = Self.normalize(frequency)
        guard !f.isEmpty else { return true }
        var candidates: Set<String> = [f]
        for (abbrev, forms) in Self.frequencySynonyms where f == abbrev || forms.contains(f) {
            candidates.insert(abbrev)
            forms.forEach { candidates.insert($0) }
        }
        let vicinity = windows(around: drug, clip: false)
        return candidates.contains { cand in vicinity.contains { Self.wordPresent(cand, in: $0) } }
    }

    /// The forward/backward proximity windows around each occurrence of `name`. When `clip` is true
    /// each side is cut at the nearest item separator (for value binding); false keeps the raw
    /// window (for frequency, whose phrase may sit past a comma).
    private func windows(around name: String, clip: Bool) -> [String] {
        let n = Self.normalize(name)
        guard !n.isEmpty else { return [] }
        let hay = normalizedTranscript
        var out: [String] = []
        var start = hay.startIndex
        while let r = hay.range(of: n, range: start..<hay.endIndex) {
            let fwdEnd = hay.index(r.upperBound, offsetBy: proximityWindow, limitedBy: hay.endIndex) ?? hay.endIndex
            let bwdStart = hay.index(r.lowerBound, offsetBy: -proximityWindow, limitedBy: hay.startIndex) ?? hay.startIndex
            let fwd = String(hay[r.upperBound..<fwdEnd])
            let bwd = String(hay[bwdStart..<r.lowerBound])
            out.append(clip ? Self.headBeforeFirstSeparator(fwd) : fwd)
            out.append(clip ? Self.tailAfterLastSeparator(bwd) : bwd)
            start = r.upperBound
        }
        return out
    }

    /// Whole-word (boundary-aware) presence of a token/phrase — no match inside a larger word.
    static func wordPresent(_ needle: String, in haystack: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        guard let re = try? NSRegularExpression(pattern: "(?<![a-z0-9])\(escaped)(?![a-z0-9])") else {
            return haystack.contains(needle)
        }
        let ns = haystack as NSString
        return re.firstMatch(in: haystack, range: NSRange(location: 0, length: ns.length)) != nil
    }

    /// A value is grounded only if its FIRST numeric token is the number ADJACENT to the name —
    /// the first number after it (`potassium 3.2`) or the last number before it (`3.2 potassium`)
    /// within the window — and its remaining tokens are also in that window. Binding to the
    /// adjacent number is what stops a different test's value from laundering a swap: with
    /// "glucose 7.2 and potassium 3.2", a claimed potassium of 7.2 is NOT the number next to
    /// "potassium" (that's 3.2), so it is correctly flagged even though 7.2 appears nearby.
    /// - Parameters:
    ///   - unit: the unit the draft claims (e.g. "mg", "mEq/L"). When non-nil, a number that is
    ///     adjacent to the name grounds ONLY if the transcript spoke NO recognizable unit there or
    ///     the SAME unit — a conflicting unit (mg vs mcg, mEq/L vs mg/dL) is rejected. A 1000x dose
    ///     error must not pass just because the digits match.
    ///   - comparator: a "<"/">" the draft claims. A source bound ("troponin less than 0.01") must
    ///     not be laundered into an exact value, so a spoken comparator with no claimed comparator
    ///     (or a mismatched one) is rejected.
    private func valueGroundedNear(name: String, numericTokens tokens: [String], unit: String? = nil, comparator: String? = nil) -> Bool {
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

            let matchedForward = Self.firstNumericToken(in: forward) == firstToken
            let matchedBackward = Self.lastNumericToken(in: backward) == firstToken
            if matchedForward || matchedBackward {
                let rest = tokens.dropFirst()
                let restPresent = rest.allSatisfy { Self.numberPresent($0, in: forward) || Self.numberPresent($0, in: backward) }
                // Check the spoken unit/comparator on BOTH sides of the binding — a conflicting unit
                // in either window (e.g. a range "1 to 2 mg" whose unit trails the second number)
                // must reject the claim.
                if restPresent
                    && Self.unitConsistent(claimed: unit, forward: forward, backward: backward)
                    && Self.comparatorConsistent(claimed: comparator, number: firstToken, forward: forward, backward: backward) {
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

    // MARK: - Unit + comparator grounding

    /// The unit a claimed value carries, if any — the text after its last numeric token.
    /// "50 mg" -> "mg", "3.2 mEq/L" -> "mEq/L", "0.1 mcg/kg/min" -> "mcg/kg/min", "5/325" -> nil.
    static func claimedUnit(inValue value: String) -> String? {
        let toks = numericTokens(in: value)
        guard let last = toks.last, let r = value.range(of: last, options: .backwards) else { return nil }
        let tail = value[r.upperBound...].trimmingCharacters(in: CharacterSet(charactersIn: " -–,"))
        return tail.isEmpty ? nil : tail
    }

    /// Canonical unit, mapped component-wise and KEEPING the denominator, so a rate or weight-based
    /// unit never collapses to a flat one: "mcg/kg/min" -> "mcg/kg/min", "mg/kg" -> "mg/kg",
    /// "mg/dL" -> "mg/dl", "micrograms" -> "mcg". Returns nil unless the FIRST component is a
    /// recognized unit — so an unknown token imposes no constraint (we reject a CONFLICT, never an
    /// unknown), and a rate ("mcg/kg/min") is a distinct class from its flat unit ("mcg").
    static func canonicalUnit(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let cleaned = raw.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: " .,()[]"))
        guard !cleaned.isEmpty else { return nil }
        let parts = cleaned.split(separator: "/", omittingEmptySubsequences: true).map { unitSynonyms[String($0)] ?? String($0) }
        guard let head = parts.first, unitSynonyms.values.contains(head) else { return nil }
        return parts.joined(separator: "/")
    }

    private static let unitSynonyms: [String: String] = [
        "milligrams": "mg", "milligram": "mg", "mgs": "mg", "mg": "mg",
        "micrograms": "mcg", "microgram": "mcg", "mcg": "mcg", "mcgs": "mcg", "ug": "mcg",
        "µg": "mcg", "μg": "mcg", "mics": "mcg",  // micro sign (U+00B5) AND greek mu (U+03BC)
        "grams": "g", "gram": "g", "gm": "g", "g": "g",
        "milliequivalents": "meq", "milliequivalent": "meq", "meq": "meq", "meqs": "meq",
        "millimoles": "mmol", "millimole": "mmol", "mmol": "mmol", "mmols": "mmol",
        "nanograms": "ng", "nanogram": "ng", "ng": "ng",
        "units": "unit", "unit": "unit", "iu": "unit",
        "milliliters": "ml", "milliliter": "ml", "ml": "ml", "mls": "ml", "cc": "ml",
        "liters": "l", "liter": "l",
        "kilograms": "kg", "kilogram": "kg", "kg": "kg", "kgs": "kg",
    ]

    /// Every recognized unit (canonical) spoken in a window — used to detect a conflicting unit
    /// regardless of which number it trails (so a range "1 to 2 mg" is caught even though the unit
    /// follows the second number).
    static func recognizedUnits(in window: String) -> Set<String> {
        guard let re = try? NSRegularExpression(pattern: "[a-zµμ]+(?:/[a-zµμ]+)*") else { return [] }
        let ns = window as NSString
        var out: Set<String> = []
        for m in re.matches(in: window, range: NSRange(location: 0, length: ns.length)) {
            if let c = canonicalUnit(ns.substring(with: m.range)) { out.insert(c) }
        }
        return out
    }

    /// True unless the transcript spoke a recognizable unit that does NOT match the claimed unit
    /// (checked across both adjacency windows). No recognizable unit spoken → allowed (unverifiable).
    static func unitConsistent(claimed: String?, forward: String, backward: String) -> Bool {
        guard let claimedCanon = canonicalUnit(claimed) else { return true }
        let spoken = recognizedUnits(in: forward).union(recognizedUnits(in: backward))
        return spoken.isEmpty || spoken.contains(claimedCanon)
    }

    /// A comparator ("<"/">") a claimed value carries, if any.
    static func claimedComparator(in value: String) -> String? { comparatorToken(in: value) }

    /// True unless the source spoke a bound the claim dropped or changed — "troponin less than 0.01"
    /// (below assay) must not be laundered into an exact "0.01". Checks the region just before the
    /// number on either side.
    static func comparatorConsistent(claimed: String?, number: String, forward: String, backward: String) -> Bool {
        let spoken = comparatorBefore(number, in: forward) ?? comparatorBefore(number, in: backward)
        guard let spoken else { return true }
        return spoken == claimed
    }

    private static func comparatorBefore(_ number: String, in window: String) -> String? {
        guard let r = window.range(of: number) else { return nil }
        return comparatorToken(in: String(window[window.startIndex..<r.lowerBound].suffix(28)))
    }

    private static func comparatorToken(in text: String) -> String? {
        let t = text.lowercased()
        for p in ["≤", "<=", "<", "less than", "no more than", "up to", "at most"] where t.contains(p) { return "<" }
        for p in ["≥", ">=", ">", "greater than", "at least", "no less than"] where t.contains(p) { return ">" }
        // ambiguous bare words → whole-word only, and only the ones reliably meaning a bound
        let words = Set(t.split(whereSeparator: { !$0.isLetter }).map(String.init))
        if !words.isDisjoint(with: ["under", "below"]) { return "<" }
        return nil
    }

    private static let frequencySynonyms: [String: [String]] = [
        "bid": ["twice daily", "twice a day", "two times a day", "twice", "two times"],
        "tid": ["three times daily", "three times a day", "three times"],
        "qid": ["four times daily", "four times a day", "four times"],
        "daily": ["once daily", "once a day", "every day", "qd", "q day", "qday"],
        "prn": ["as needed", "if needed", "when needed"],
        "qhs": ["at bedtime", "nightly", "at night", "every night", "bedtime"],
        "qod": ["every other day"],
        "q1h": ["every hour", "every 1 hour", "hourly"],
        "q2h": ["every 2 hours", "every two hours"],
        "q3h": ["every 3 hours", "every three hours"],
        "q4h": ["every 4 hours", "every four hours"],
        "q6h": ["every 6 hours", "every six hours"],
        "q8h": ["every 8 hours", "every eight hours"],
        "q12h": ["every 12 hours", "every twelve hours"],
    ]

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
