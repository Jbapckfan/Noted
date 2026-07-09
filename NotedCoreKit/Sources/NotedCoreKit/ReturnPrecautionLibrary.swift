import Foundation

/// The curated return-precaution library. This is where hallucinated advice is most dangerous, so
/// precautions are SELECTED from vetted per-diagnosis text — never free-generated. The discharge
/// verifier flags any precaution that isn't a library entry for the encounter's diagnosis (plus a
/// small set of universal precautions allowed for every discharge).
public enum ReturnPrecautionLibrary {

    /// Allowed for any discharge.
    public static let universal: [String] = [
        "Return to the emergency department or call 911 if your symptoms get worse.",
        "Return if you develop a high fever, worsening pain, or any new or concerning symptoms.",
    ]

    /// Keyword-keyed categories → vetted precautions. Diagnosis text is matched to a category by
    /// keyword so "acute appendicitis" and "abdominal pain, r/o appendicitis" both resolve.
    public static let categories: [(keywords: [String], precautions: [String])] = [
        (["chest pain", "acs", "angina", "myocardial", "stemi", "nstemi", "cardiac"], [
            "Return immediately or call 911 for chest pain, pressure, or tightness — especially if it spreads to your arm, jaw, or back.",
            "Return for shortness of breath, sweating, nausea, or feeling like you might pass out.",
        ]),
        (["head injury", "concussion", "head trauma", "tbi", "closed head"], [
            "Return for worsening headache, repeated vomiting, confusion, or trouble waking up.",
            "Return for seizures, weakness or numbness, slurred speech, or fluid/blood from the nose or ears.",
            "Have someone wake you every few hours tonight to check that you respond normally.",
        ]),
        (["abdominal pain", "appendicitis", "abdomen"], [
            "Return for worsening or spreading abdominal pain, or pain that becomes severe.",
            "Return for repeated vomiting, a hard or swollen belly, blood in your stool or vomit, or inability to keep fluids down.",
            "Return for a fever, or if you have not passed gas or a stool and your belly is getting bigger.",
        ]),
        (["laceration", "wound", "suture", "cut"], [
            "Return for increasing redness, swelling, warmth, pus, or red streaks spreading from the wound.",
            "Return for a fever, or if the wound reopens or bleeding does not stop with pressure.",
        ]),
        (["copd", "asthma", "pneumonia", "bronchitis", "respiratory", "dyspnea"], [
            "Return or call 911 for worsening shortness of breath, or if your lips or fingertips turn blue.",
            "Return for a high fever, chest pain, or coughing up blood.",
        ]),
    ]

    /// The full set of approved precautions for a diagnosis (universal + matched category).
    public static func approved(forDiagnosis diagnosis: String) -> [String] {
        let dx = diagnosis.lowercased()
        var result = universal
        for category in categories where category.keywords.contains(where: { dx.contains($0) }) {
            result.append(contentsOf: category.precautions)
        }
        return result
    }

    /// A set (normalized) for the verifier's membership check.
    public static func approvedSet(forDiagnosis diagnosis: String) -> Set<String> {
        Set(approved(forDiagnosis: diagnosis).map { normalize($0) })
    }

    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
