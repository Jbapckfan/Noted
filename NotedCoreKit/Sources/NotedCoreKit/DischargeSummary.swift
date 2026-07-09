import Foundation

/// The fixed discharge-summary schema (the second grammar). Built from three layers, none of
/// which the model is free to invent:
///  - Layer A: the already-verified HPI facts (`Encounter.extractionJSON`)
///  - Layer B: the results tray — physician-confirmed discrete values (`Encounter.resultsTrayJSON`)
///  - Layer C: the disposition dictation (`Encounter.dispositionTranscript`)
///
/// Drugs, doses, and result values are COPY SLOTS — only tokens present in A/B/C may fill them.
/// Return precautions are SELECTED from a curated library, never free-authored. Only
/// `briefClinicalCourse` and the plain-language explanations are free text (entailment-checked).
public struct DischargeSummary: Codable, Equatable, Sendable {
    public var finalDiagnosis: String
    public var differentialRuledOut: [String]
    public var briefClinicalCourse: String
    public var resultsExplained: [ResultExplanation]
    public var treatmentsGivenInED: [String]
    public var medicationsPrescribed: [PrescribedMedication]
    public var medicationsChangedOrStopped: [String]
    public var followUp: [FollowUp]
    public var returnPrecautions: [String]
    public var activityDietWorkRestrictions: [String]
    public var patientInstructions: [String]
    public var pendingResults: [PendingResult]

    public init(
        finalDiagnosis: String = "",
        differentialRuledOut: [String] = [],
        briefClinicalCourse: String = "",
        resultsExplained: [ResultExplanation] = [],
        treatmentsGivenInED: [String] = [],
        medicationsPrescribed: [PrescribedMedication] = [],
        medicationsChangedOrStopped: [String] = [],
        followUp: [FollowUp] = [],
        returnPrecautions: [String] = [],
        activityDietWorkRestrictions: [String] = [],
        patientInstructions: [String] = [],
        pendingResults: [PendingResult] = []
    ) {
        self.finalDiagnosis = finalDiagnosis
        self.differentialRuledOut = differentialRuledOut
        self.briefClinicalCourse = briefClinicalCourse
        self.resultsExplained = resultsExplained
        self.treatmentsGivenInED = treatmentsGivenInED
        self.medicationsPrescribed = medicationsPrescribed
        self.medicationsChangedOrStopped = medicationsChangedOrStopped
        self.followUp = followUp
        self.returnPrecautions = returnPrecautions
        self.activityDietWorkRestrictions = activityDietWorkRestrictions
        self.patientInstructions = patientInstructions
        self.pendingResults = pendingResults
    }

    private enum CodingKeys: String, CodingKey {
        case finalDiagnosis = "final_diagnosis"
        case differentialRuledOut = "differential_ruled_out"
        case briefClinicalCourse = "brief_clinical_course"
        case resultsExplained = "results_explained"
        case treatmentsGivenInED = "treatments_given_in_ED"
        case medicationsPrescribed = "medications_prescribed"
        case medicationsChangedOrStopped = "medications_changed_or_stopped"
        case followUp = "follow_up"
        case returnPrecautions = "return_precautions"
        case activityDietWorkRestrictions = "activity_diet_work_restrictions"
        case patientInstructions = "patient_instructions"
        case pendingResults = "pending_results"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        finalDiagnosis = try c.decodeIfPresent(String.self, forKey: .finalDiagnosis) ?? ""
        differentialRuledOut = try c.decodeIfPresent([String].self, forKey: .differentialRuledOut) ?? []
        briefClinicalCourse = try c.decodeIfPresent(String.self, forKey: .briefClinicalCourse) ?? ""
        resultsExplained = try c.decodeIfPresent([ResultExplanation].self, forKey: .resultsExplained) ?? []
        treatmentsGivenInED = try c.decodeIfPresent([String].self, forKey: .treatmentsGivenInED) ?? []
        medicationsPrescribed = try c.decodeIfPresent([PrescribedMedication].self, forKey: .medicationsPrescribed) ?? []
        medicationsChangedOrStopped = try c.decodeIfPresent([String].self, forKey: .medicationsChangedOrStopped) ?? []
        followUp = try c.decodeIfPresent([FollowUp].self, forKey: .followUp) ?? []
        returnPrecautions = try c.decodeIfPresent([String].self, forKey: .returnPrecautions) ?? []
        activityDietWorkRestrictions = try c.decodeIfPresent([String].self, forKey: .activityDietWorkRestrictions) ?? []
        patientInstructions = try c.decodeIfPresent([String].self, forKey: .patientInstructions) ?? []
        pendingResults = try c.decodeIfPresent([PendingResult].self, forKey: .pendingResults) ?? []
    }

    public static func parse(_ json: String) throws -> DischargeSummary {
        try JSONDecoder().decode(DischargeSummary.self, from: Data(json.utf8))
    }
}

public struct ResultExplanation: Codable, Equatable, Sendable {
    public var test: String
    public var resultValueVerbatim: String
    public var plainLanguageMeaning: String
    public init(test: String, resultValueVerbatim: String, plainLanguageMeaning: String = "") {
        self.test = test; self.resultValueVerbatim = resultValueVerbatim; self.plainLanguageMeaning = plainLanguageMeaning
    }
    private enum CodingKeys: String, CodingKey {
        case test, resultValueVerbatim = "result_value_verbatim", plainLanguageMeaning = "plain_language_meaning"
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        test = try c.decodeIfPresent(String.self, forKey: .test) ?? ""
        resultValueVerbatim = try c.decodeIfPresent(String.self, forKey: .resultValueVerbatim) ?? ""
        plainLanguageMeaning = try c.decodeIfPresent(String.self, forKey: .plainLanguageMeaning) ?? ""
    }
}

public struct PrescribedMedication: Codable, Equatable, Sendable {
    public var drug: String
    public var dose: String
    public var route: String
    public var frequency: String
    public var duration: String
    public var quantity: String
    public init(drug: String, dose: String = "", route: String = "", frequency: String = "", duration: String = "", quantity: String = "") {
        self.drug = drug; self.dose = dose; self.route = route; self.frequency = frequency; self.duration = duration; self.quantity = quantity
    }
    private enum CodingKeys: String, CodingKey { case drug, dose, route, frequency, duration, quantity }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        drug = try c.decodeIfPresent(String.self, forKey: .drug) ?? ""
        dose = try c.decodeIfPresent(String.self, forKey: .dose) ?? ""
        route = try c.decodeIfPresent(String.self, forKey: .route) ?? ""
        frequency = try c.decodeIfPresent(String.self, forKey: .frequency) ?? ""
        duration = try c.decodeIfPresent(String.self, forKey: .duration) ?? ""
        quantity = try c.decodeIfPresent(String.self, forKey: .quantity) ?? ""
    }
}

public struct FollowUp: Codable, Equatable, Sendable {
    public var who: String
    public var when: String
    public var why: String
    public init(who: String, when: String = "", why: String = "") { self.who = who; self.when = when; self.why = why }
    private enum CodingKeys: String, CodingKey { case who, when, why }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        who = try c.decodeIfPresent(String.self, forKey: .who) ?? ""
        when = try c.decodeIfPresent(String.self, forKey: .when) ?? ""
        why = try c.decodeIfPresent(String.self, forKey: .why) ?? ""
    }
}

public struct PendingResult: Codable, Equatable, Sendable {
    public var test: String
    public var howCommunicated: String
    public init(test: String, howCommunicated: String = "") { self.test = test; self.howCommunicated = howCommunicated }
    private enum CodingKeys: String, CodingKey { case test, howCommunicated = "how_communicated" }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        test = try c.decodeIfPresent(String.self, forKey: .test) ?? ""
        howCommunicated = try c.decodeIfPresent(String.self, forKey: .howCommunicated) ?? ""
    }
}
