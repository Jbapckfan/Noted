import Foundation

/// Extracts structured medication information from medical transcripts
/// Captures drug name, dose, route, frequency for complete documentation
class MedicationExtractor {

    // MARK: - Structured Medication Data

    struct Medication {
        let name: String
        let dose: String?
        let unit: String?
        let route: String?
        let frequency: String?
        let indication: String?
        let rawText: String // Original text where found

        var formattedString: String {
            var parts: [String] = [name]

            if let dose = dose, let unit = unit {
                parts.append("\(dose)\(unit)")
            } else if let dose = dose {
                parts.append(dose)
            }

            if let route = route {
                parts.append(route)
            }

            if let frequency = frequency {
                parts.append(frequency)
            }

            if let indication = indication {
                parts.append("for \(indication)")
            }

            return parts.joined(separator: " ")
        }
    }

    // MARK: - Route Mappings

    private static let routeAbbreviations: [String: String] = [
        "by mouth": "PO",
        "oral": "PO",
        "orally": "PO",
        "po": "PO",
        "intravenous": "IV",
        "iv": "IV",
        "intramuscular": "IM",
        "im": "IM",
        "subcutaneous": "SQ",
        "subq": "SQ",
        "sq": "SQ",
        "sublingual": "SL",
        "under the tongue": "SL",
        "sl": "SL",
        "topical": "topical",
        "inhaled": "inhaled",
        "nebulizer": "neb",
        "rectal": "PR",
        "pr": "PR",
        "transdermal": "transdermal",
        "patch": "transdermal"
    ]

    // MARK: - Frequency Mappings

    private static let frequencyMappings: [String: String] = [
        "once a day": "daily",
        "once daily": "daily",
        "every day": "daily",
        "twice a day": "BID",
        "twice daily": "BID",
        "bid": "BID",
        "two times a day": "BID",
        "three times a day": "TID",
        "tid": "TID",
        "four times a day": "QID",
        "qid": "QID",
        "every four hours": "Q4H",
        "q4h": "Q4H",
        "every 4 hours": "Q4H",
        "every six hours": "Q6H",
        "q6h": "Q6H",
        "every 6 hours": "Q6H",
        "every eight hours": "Q8H",
        "q8h": "Q8H",
        "every 8 hours": "Q8H",
        "as needed": "PRN",
        "prn": "PRN",
        "when needed": "PRN",
        "at bedtime": "QHS",
        "qhs": "QHS",
        "before bed": "QHS",
        "in the morning": "QAM",
        "qam": "QAM"
    ]

    // MARK: - Common Medications Database

    private static let commonMedications = [
        // Cardiac
        "lisinopril", "metoprolol", "atorvastatin", "simvastatin", "amlodipine",
        "losartan", "carvedilol", "furosemide", "lasix", "aspirin",
        "clopidogrel", "plavix", "warfarin", "coumadin", "apixaban", "eliquis",

        // Diabetes
        "metformin", "glucophage", "insulin", "glipizide", "glyburide",
        "januvia", "sitagliptin", "jardiance", "empagliflozin",

        // Respiratory
        "albuterol", "proair", "ventolin", "advair", "fluticasone",
        "montelukast", "singulair", "tiotropium", "spiriva",

        // GI
        "omeprazole", "prilosec", "pantoprazole", "protonix", "ranitidine",
        "zantac", "famotidine", "pepcid",

        // Pain
        "acetaminophen", "tylenol", "ibuprofen", "motrin", "advil",
        "naproxen", "aleve", "tramadol", "hydrocodone", "oxycodone",
        "morphine", "fentanyl", "dilaudid", "hydromorphone",

        // Antibiotics
        "amoxicillin", "augmentin", "azithromycin", "zithromax", "ciprofloxacin",
        "cipro", "levofloxacin", "levaquin", "doxycycline", "cephalexin", "keflex",

        // Psychiatric
        "sertraline", "zoloft", "escitalopram", "lexapro", "fluoxetine", "prozac",
        "citalopram", "celexa", "duloxetine", "cymbalta", "alprazolam", "xanax",
        "lorazepam", "ativan", "clonazepam", "klonopin",

        // Other common
        "levothyroxine", "synthroid", "prednisone", "gabapentin", "neurontin",
        "pregabalin", "lyrica", "cyclobenzaprine", "flexeril"
    ]

    // MARK: - Main Extraction Function

    static func extractMedications(from text: String) -> [Medication] {
        let lowercaseText = text.lowercased()
        var medications: [Medication] = []
        var processedRanges: [Range<String.Index>] = []

        // Find all medication mentions
        for medName in commonMedications {
            var searchRange = lowercaseText.startIndex..<lowercaseText.endIndex

            while let range = lowercaseText.range(of: medName, range: searchRange) {
                // Skip if already processed (avoid duplicates)
                if processedRanges.contains(where: { $0.overlaps(range) }) {
                    searchRange = range.upperBound..<lowercaseText.endIndex
                    continue
                }

                // Extract context around the medication (50 chars before, 100 after)
                let contextStart = lowercaseText.index(range.lowerBound, offsetBy: -50, limitedBy: lowercaseText.startIndex) ?? lowercaseText.startIndex
                let contextEnd = lowercaseText.index(range.upperBound, offsetBy: 100, limitedBy: lowercaseText.endIndex) ?? lowercaseText.endIndex
                let context = String(lowercaseText[contextStart..<contextEnd])

                // Extract structured information
                let dose = extractDose(from: context, afterMedication: medName)
                let unit = extractUnit(from: context, afterDose: dose)
                let route = extractRoute(from: context)
                let frequency = extractFrequency(from: context)
                let indication = extractIndication(from: context)

                let medication = Medication(
                    name: capitalizeGenericName(medName),
                    dose: dose,
                    unit: unit,
                    route: route,
                    frequency: frequency,
                    indication: indication,
                    rawText: context
                )

                medications.append(medication)
                processedRanges.append(range)

                searchRange = range.upperBound..<lowercaseText.endIndex
            }
        }

        return medications
    }

    // MARK: - Component Extractors

    private static func extractDose(from context: String, afterMedication: String) -> String? {
        // Look for dose patterns: "20 mg", "2.5mg", "100mg", "one tablet"
        let dosePatterns = [
            "\\b(\\d+(?:\\.\\d+)?)\\s*(?:mg|mcg|g|ml|units?|iu|meq|tablets?|capsules?)\\b",
            "\\b(one|two|three|four|five)\\s+(?:tablet|capsule|pill|puff)s?\\b"
        ]

        for pattern in dosePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
               let doseRange = Range(match.range(at: 1), in: context) {
                return String(context[doseRange])
            }
        }

        return nil
    }

    private static func extractUnit(from context: String, afterDose: String?) -> String? {
        if afterDose == nil { return nil }

        let unitPattern = "\\d+(?:\\.\\d+)?\\s*(mg|mcg|g|ml|units?|iu|meq|tablets?|capsules?|puffs?)\\b"

        if let regex = try? NSRegularExpression(pattern: unitPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
           let unitRange = Range(match.range(at: 1), in: context) {
            return String(context[unitRange])
        }

        return nil
    }

    private static func extractRoute(from context: String) -> String? {
        for (phrase, abbreviation) in routeAbbreviations {
            if context.contains(phrase) {
                return abbreviation
            }
        }

        return nil
    }

    private static func extractFrequency(from context: String) -> String? {
        for (phrase, abbreviation) in frequencyMappings {
            if context.contains(phrase) {
                return abbreviation
            }
        }

        return nil
    }

    private static func extractIndication(from context: String) -> String? {
        // Look for "for [indication]" or "to treat [condition]"
        let indicationPatterns = [
            "for (?:the |his |her )?(\\w+(?: \\w+){0,3})",
            "to treat (?:the |his |her )?(\\w+(?: \\w+){0,3})"
        ]

        for pattern in indicationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: context, range: NSRange(context.startIndex..., in: context)),
               let indicationRange = Range(match.range(at: 1), in: context) {
                let indication = String(context[indicationRange])
                // Filter out false positives
                if !["it", "that", "this", "pain", "the", "her", "his"].contains(indication.lowercased()) {
                    return indication
                }
            }
        }

        return nil
    }

    // MARK: - Helper Functions

    private static func capitalizeGenericName(_ name: String) -> String {
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    // MARK: - Home Medications vs ED Medications

    static func categorize(medications: [Medication], transcript: String) -> (homeMedications: [Medication], edMedications: [Medication]) {
        let lowercaseTranscript = transcript.lowercased()
        var homeMeds: [Medication] = []
        var edMeds: [Medication] = []

        for med in medications {
            // Check context for home vs ED
            let context = med.rawText.lowercased()

            let homeIndicators = [
                "take at home", "taking at home", "on at home", "home medication",
                "prescribed", "taking daily", "been on", "been taking"
            ]

            let edIndicators = [
                "gave", "given", "administered", "started", "will give",
                "in the ed", "emergency department", "here in the er"
            ]

            let isHomeMed = homeIndicators.contains { context.contains($0) }
            let isEDMed = edIndicators.contains { context.contains($0) }

            if isEDMed {
                edMeds.append(med)
            } else if isHomeMed || !isEDMed {
                // Default to home med if unclear
                homeMeds.append(med)
            }
        }

        return (homeMedications: homeMeds, edMedications: edMeds)
    }

    // MARK: - Formatting

    static func formatMedicationList(_ medications: [Medication]) -> String {
        if medications.isEmpty {
            return "None documented"
        }

        return medications.map { $0.formattedString }.joined(separator: "\n")
    }

    static func formatForEMR(_ medications: [Medication]) -> [[String: String]] {
        return medications.map { med in
            var dict: [String: String] = ["name": med.name]
            if let dose = med.dose { dict["dose"] = dose }
            if let unit = med.unit { dict["unit"] = unit }
            if let route = med.route { dict["route"] = route }
            if let frequency = med.frequency { dict["frequency"] = frequency }
            if let indication = med.indication { dict["indication"] = indication }
            return dict
        }
    }

    // MARK: - Allergy Extraction (Bonus Feature)

    struct Allergy {
        let allergen: String
        let reaction: String?
        let severity: AllergySeverity?

        enum AllergySeverity: String {
            case mild = "Mild"
            case moderate = "Moderate"
            case severe = "Severe"
            case anaphylaxis = "Anaphylaxis"
        }

        var formattedString: String {
            var result = allergen
            if let reaction = reaction {
                result += " (\(reaction))"
            }
            if let severity = severity {
                result += " - \(severity.rawValue)"
            }
            return result
        }
    }

    static func extractAllergies(from text: String) -> [Allergy] {
        let lowercaseText = text.lowercased()
        var allergies: [Allergy] = []

        // Check for "no allergies" first
        if lowercaseText.contains("no known allergies") ||
           lowercaseText.contains("nkda") ||
           lowercaseText.contains("no allergies") {
            return allergies // Return empty
        }

        // Common allergens
        let allergenPatterns: [(name: String, variations: [String])] = [
            ("Penicillin", ["penicillin", "pen", "pcn"]),
            ("Sulfa", ["sulfa", "sulfamethoxazole", "bactrim"]),
            ("Codeine", ["codeine"]),
            ("Morphine", ["morphine"]),
            ("Latex", ["latex"]),
            ("Iodine", ["iodine", "contrast"]),
            ("Shellfish", ["shellfish", "shrimp"]),
            ("Eggs", ["eggs", "egg"]),
            ("Nuts", ["nuts", "peanuts", "tree nuts"]),
            ("Aspirin", ["aspirin", "asa"]),
            ("NSAIDs", ["nsaids", "ibuprofen", "naproxen"])
        ]

        for allergen in allergenPatterns {
            for variation in allergen.variations {
                if lowercaseText.contains(variation) &&
                   (lowercaseText.contains("allerg") || lowercaseText.contains("reaction to")) {

                    // Extract reaction if mentioned
                    let reaction = extractAllergyReaction(for: variation, in: lowercaseText)

                    // Determine severity
                    let severity = determineAllergySeverity(for: reaction, in: lowercaseText)

                    allergies.append(Allergy(
                        allergen: allergen.name,
                        reaction: reaction,
                        severity: severity
                    ))
                    break
                }
            }
        }

        return allergies
    }

    private static func extractAllergyReaction(for allergen: String, in text: String) -> String? {
        let reactions = [
            "rash", "hives", "itching", "swelling", "anaphylaxis",
            "difficulty breathing", "throat closing", "nausea", "vomiting",
            "diarrhea", "upset stomach"
        ]

        // Look near the allergen mention
        if let allergenRange = text.range(of: allergen) {
            let contextEnd = text.index(allergenRange.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
            let context = String(text[allergenRange.lowerBound..<contextEnd])

            for reaction in reactions {
                if context.contains(reaction) {
                    return reaction
                }
            }
        }

        return nil
    }

    private static func determineAllergySeverity(for reaction: String?, in text: String) -> Allergy.AllergySeverity? {
        guard let reaction = reaction?.lowercased() else { return nil }

        if reaction.contains("anaphylaxis") || reaction.contains("throat closing") ||
           reaction.contains("difficulty breathing") || text.contains("epipen") {
            return .anaphylaxis
        }

        if reaction.contains("swelling") || reaction.contains("hives") {
            return .moderate
        }

        if reaction.contains("rash") || reaction.contains("itching") ||
           reaction.contains("nausea") || reaction.contains("upset stomach") {
            return .mild
        }

        return nil
    }

    static func formatAllergyList(_ allergies: [Allergy]) -> String {
        if allergies.isEmpty {
            return "NKDA"
        }

        return allergies.map { $0.formattedString }.joined(separator: "; ")
    }
}
