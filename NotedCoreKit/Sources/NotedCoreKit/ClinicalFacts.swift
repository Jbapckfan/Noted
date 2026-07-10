import Foundation

/// The extraction schema — the structured facts pulled from a transcript before any note is
/// written. This is the "fact JSON" the extraction stage produces and everything downstream
/// copies from. Kept lenient (missing fields decode to empty) so a partial model output still
/// parses. Values are stored as strings so they can be matched VERBATIM against the transcript.
public struct ClinicalFacts: Codable, Equatable, Sendable {
    public var chiefComplaint: String?
    public var hpi: String?
    public var reviewOfSystems: String?
    public var pastMedicalHistory: [String]
    public var allergies: [String]
    public var medications: [Medication]
    public var vitals: [Vital]
    public var physicalExam: String?
    public var labs: [LabResult]
    public var mdm: String?          // medical decision-making reasoning
    public var diagnosis: String?
    public var differential: [String]
    public var disposition: String?
    public var returnPrecautions: [String]

    public init(
        chiefComplaint: String? = nil,
        hpi: String? = nil,
        reviewOfSystems: String? = nil,
        pastMedicalHistory: [String] = [],
        allergies: [String] = [],
        medications: [Medication] = [],
        vitals: [Vital] = [],
        physicalExam: String? = nil,
        labs: [LabResult] = [],
        mdm: String? = nil,
        diagnosis: String? = nil,
        differential: [String] = [],
        disposition: String? = nil,
        returnPrecautions: [String] = []
    ) {
        self.chiefComplaint = chiefComplaint
        self.hpi = hpi
        self.reviewOfSystems = reviewOfSystems
        self.pastMedicalHistory = pastMedicalHistory
        self.allergies = allergies
        self.medications = medications
        self.vitals = vitals
        self.physicalExam = physicalExam
        self.labs = labs
        self.mdm = mdm
        self.diagnosis = diagnosis
        self.differential = differential
        self.disposition = disposition
        self.returnPrecautions = returnPrecautions
    }

    private enum CodingKeys: String, CodingKey {
        case chiefComplaint = "chief_complaint"
        case hpi
        case reviewOfSystems = "review_of_systems"
        case pastMedicalHistory = "past_medical_history"
        case allergies
        case medications
        case vitals
        case physicalExam = "physical_exam"
        case labs
        case mdm
        case diagnosis
        case differential
        case disposition
        case returnPrecautions = "return_precautions"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // TOLERANT: a small base model drifts from the schema — it emits "" or "none" for an empty
        // list, omits keys, or wrong-types a field. The parser must NEVER throw on that (or a whole
        // encounter fails extraction on device); it decodes what parses and defaults the rest. The
        // grounding gate — not the parser — is what enforces correctness.
        chiefComplaint = Self.string(c, .chiefComplaint)
        hpi = Self.string(c, .hpi)
        reviewOfSystems = Self.string(c, .reviewOfSystems)
        pastMedicalHistory = Self.stringArray(c, .pastMedicalHistory)
        allergies = Self.stringArray(c, .allergies)
        medications = (try? c.decode([Medication].self, forKey: .medications)) ?? []
        vitals = (try? c.decode([Vital].self, forKey: .vitals)) ?? []
        physicalExam = Self.string(c, .physicalExam)
        labs = (try? c.decode([LabResult].self, forKey: .labs)) ?? []
        mdm = Self.string(c, .mdm)
        diagnosis = Self.string(c, .diagnosis)
        differential = Self.stringArray(c, .differential)
        disposition = Self.string(c, .disposition)
        returnPrecautions = Self.stringArray(c, .returnPrecautions)
    }

    private static func string(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        try? c.decode(String.self, forKey: key)
    }

    /// Accept a JSON array OR a bare string — the model sometimes emits `""` / `"none"` for an empty
    /// list, or a single string for a one-item list.
    private static func stringArray(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> [String] {
        if let arr = try? c.decode([String].self, forKey: key) { return arr }
        if let s = try? c.decode(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || ["none", "none mentioned", "unknown", "n/a", "na"].contains(t.lowercased()) { return [] }
            return [t]
        }
        return []
    }

    /// Parse from an extraction-JSON string (what `Encounter.extractionJSON` holds).
    public static func parse(_ json: String) throws -> ClinicalFacts {
        try JSONDecoder().decode(ClinicalFacts.self, from: Data(json.utf8))
    }
}

public struct Medication: Codable, Equatable, Sendable {
    public var drug: String
    public var dose: String?
    public var route: String?
    public var frequency: String?

    public init(drug: String, dose: String? = nil, route: String? = nil, frequency: String? = nil) {
        self.drug = drug; self.dose = dose; self.route = route; self.frequency = frequency
    }
}

public struct LabResult: Codable, Equatable, Sendable {
    public var test: String
    public var value: String
    public var unit: String?

    public init(test: String, value: String, unit: String? = nil) {
        self.test = test; self.value = value; self.unit = unit
    }
}

public struct Vital: Codable, Equatable, Sendable {
    public var name: String
    public var value: String

    public init(name: String, value: String) {
        self.name = name; self.value = value
    }
}
