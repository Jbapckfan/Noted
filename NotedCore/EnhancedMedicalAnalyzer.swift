import Foundation
import NaturalLanguage

/// Enhanced medical text analysis with context awareness and negation detection
@MainActor
final class EnhancedMedicalAnalyzer: ObservableObject {
    
    // MARK: - Medical Context Understanding
    
    struct MedicalContext {
        let symptoms: [Symptom]
        let medications: [Medication]
        let conditions: [MedicalCondition]
        let vitals: [VitalSign]
        let timeline: [TemporalEvent]
        let negations: [NegatedFinding]
        let abbreviations: [ExpandedAbbreviation]
    }
    
    struct Symptom {
        let name: String
        let severity: String?
        let duration: String?
        let location: String?
        let quality: String?
        let isNegated: Bool
        let onset: TemporalReference?
    }
    
    struct Medication {
        let name: String
        let dose: String?
        let frequency: String?
        let route: String?
        let status: MedicationStatus
        
        enum MedicationStatus {
            case current
            case discontinued(when: String?)
            case allergic
            case considered
        }
    }
    
    struct MedicalCondition {
        let name: String
        let status: ConditionStatus
        let onset: String?
        
        enum ConditionStatus {
            case active
            case resolved
            case chronic
            case acute
            case ruled_out
        }
    }
    
    struct VitalSign {
        let type: String
        let value: String
        let unit: String?
        let interpretation: String?
    }
    
    struct TemporalEvent {
        let event: String
        let reference: TemporalReference
    }
    
    struct TemporalReference {
        let value: Int?
        let unit: TimeUnit?
        let relation: TemporalRelation
        
        enum TimeUnit {
            case minutes, hours, days, weeks, months, years
        }
        
        enum TemporalRelation {
            case ago
            case since
            case for_duration
            case until
            case ongoing
        }
    }
    
    struct NegatedFinding {
        let finding: String
        let negationType: NegationType
        
        enum NegationType {
            case denied      // "denies chest pain"
            case absent      // "no evidence of"
            case resolved    // "no longer has"
            case never       // "never had"
        }
    }
    
    struct ExpandedAbbreviation {
        let abbreviation: String
        let expansion: String
        let confidence: Float
    }
    
    // MARK: - Medical Knowledge Base
    
    private let medicalAbbreviations: [String: String] = [
        "bp": "blood pressure",
        "hr": "heart rate",
        "rr": "respiratory rate",
        "o2": "oxygen",
        "sat": "saturation",
        "sob": "shortness of breath",
        "cp": "chest pain",
        "abd": "abdominal",
        "htn": "hypertension",
        "dm": "diabetes mellitus",
        "cad": "coronary artery disease",
        "chf": "congestive heart failure",
        "copd": "chronic obstructive pulmonary disease",
        "mi": "myocardial infarction",
        "cva": "cerebrovascular accident",
        "tia": "transient ischemic attack",
        "pe": "pulmonary embolism",
        "dvt": "deep vein thrombosis",
        "uti": "urinary tract infection",
        "uri": "upper respiratory infection",
        "gi": "gastrointestinal",
        "gu": "genitourinary",
        "cv": "cardiovascular",
        "ms": "musculoskeletal",
        "ns": "neurological system",
        "nkda": "no known drug allergies",
        "prn": "as needed",
        "po": "by mouth",
        "iv": "intravenous",
        "im": "intramuscular",
        "sq": "subcutaneous",
        "bid": "twice daily",
        "tid": "three times daily",
        "qid": "four times daily",
        "qd": "once daily",
        "qhs": "at bedtime",
        "ac": "before meals",
        "pc": "after meals",
        "wbc": "white blood cell",
        "rbc": "red blood cell",
        "hgb": "hemoglobin",
        "hct": "hematocrit",
        "plt": "platelet",
        "bun": "blood urea nitrogen",
        "cr": "creatinine",
        "na": "sodium",
        "k": "potassium",
        "cl": "chloride",
        "co2": "carbon dioxide",
        "ast": "aspartate aminotransferase",
        "alt": "alanine aminotransferase",
        "alk phos": "alkaline phosphatase",
        "t bili": "total bilirubin",
        "ekg": "electrocardiogram",
        "ecg": "electrocardiogram",
        "cxr": "chest x-ray",
        "ct": "computed tomography",
        "mri": "magnetic resonance imaging",
        "us": "ultrasound",
        "er": "emergency room",
        "ed": "emergency department",
        "icu": "intensive care unit",
        "or": "operating room",
        "nsr": "normal sinus rhythm",
        "afib": "atrial fibrillation",
        "vfib": "ventricular fibrillation",
        "vtach": "ventricular tachycardia",
        "pvc": "premature ventricular contraction",
        "pac": "premature atrial contraction"
    ]
    
    private let negationTriggers = [
        "no", "not", "denies", "denies any", "denied", "without",
        "negative for", "absence of", "free of", "ruled out",
        "no evidence", "no sign", "unremarkable for", "never",
        "neither", "nor", "failed to reveal", "no history of",
        "no complaint of", "no longer", "resolved"
    ]
    
    private let temporalMarkers = [
        "ago": TemporalReference.TemporalRelation.ago,
        "since": .since,
        "for": .for_duration,
        "until": .until,
        "ongoing": .ongoing,
        "started": .since,
        "began": .since,
        "lasting": .for_duration,
        "continued": .ongoing
    ]
    
    // MARK: - Advanced Analysis Methods
    
    func analyzeTranscription(_ text: String) -> MedicalContext {
        let normalizedText = text.lowercased()
        
        // Expand abbreviations first
        let expandedText = expandAbbreviations(normalizedText)
        
        // Extract components
        let symptoms = extractSymptoms(expandedText)
        let medications = extractMedications(expandedText)
        let conditions = extractConditions(expandedText)
        let vitals = extractVitals(expandedText)
        let timeline = extractTimeline(expandedText)
        let negations = detectNegations(expandedText)
        let abbreviations = findExpandedAbbreviations(normalizedText)
        
        return MedicalContext(
            symptoms: symptoms,
            medications: medications,
            conditions: conditions,
            vitals: vitals,
            timeline: timeline,
            negations: negations,
            abbreviations: abbreviations
        )
    }
    
    // MARK: - Abbreviation Expansion
    
    private func expandAbbreviations(_ text: String) -> String {
        var expanded = text
        
        for (abbrev, expansion) in medicalAbbreviations {
            // Match abbreviation with word boundaries
            let pattern = "\\b\(abbrev)\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(expanded.startIndex..., in: expanded)
                expanded = regex.stringByReplacingMatches(
                    in: expanded,
                    range: range,
                    withTemplate: expansion
                )
            }
        }
        
        return expanded
    }
    
    private func findExpandedAbbreviations(_ text: String) -> [ExpandedAbbreviation] {
        var found: [ExpandedAbbreviation] = []
        
        for (abbrev, expansion) in medicalAbbreviations {
            if text.contains(abbrev) {
                found.append(ExpandedAbbreviation(
                    abbreviation: abbrev,
                    expansion: expansion,
                    confidence: 0.95
                ))
            }
        }
        
        return found
    }
    
    // MARK: - Symptom Extraction with Context
    
    private func extractSymptoms(_ text: String) -> [Symptom] {
        var symptoms: [Symptom] = []
        var foundSymptoms = Set<String>() // Track found symptoms to avoid duplicates
        
        let symptomPatterns = [
            "pain", "ache", "discomfort", "pressure", "tightness",
            "shortness of breath", "dyspnea", "difficulty breathing",
            "nausea", "vomiting", "diarrhea", "constipation",
            "fever", "chills", "sweating", "diaphoresis",
            "dizziness", "lightheaded", "vertigo", "syncope",
            "weakness", "fatigue", "malaise", "lethargy",
            "cough", "congestion", "rhinorrhea", "sore throat",
            "rash", "itching", "swelling", "edema",
            "numbness", "tingling", "paresthesia",
            "headache", "migraine", "cephalalgia",
            "palpitations", "racing heart", "irregular heartbeat",
            "bleeding", "hemorrhage", "discharge",
            "blurry vision", "vision changes", "photophobia",
            "neck stiffness", "stiff neck", "queasy", "nauseous"
        ]
        
        for pattern in symptomPatterns {
            // Use word boundary matching for better accuracy
            let regexPattern = "\\b\(pattern)\\b"
            if let range = text.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) {
                // Skip if already found a similar symptom
                let baseSymptom = pattern.components(separatedBy: " ").first ?? pattern
                if foundSymptoms.contains(baseSymptom) { continue }
                
                // Check for negation
                let beforeText = String(text[..<range.lowerBound])
                let isNegated = checkNegation(beforeText, within: 50)
                
                // Extract modifiers
                let context = extractSymptomContext(
                    around: pattern,
                    in: text,
                    at: range
                )
                
                let symptom = Symptom(
                    name: pattern,
                    severity: context.severity,
                    duration: context.duration,
                    location: context.location,
                    quality: context.quality,
                    isNegated: isNegated,
                    onset: context.onset
                )
                
                symptoms.append(symptom)
                foundSymptoms.insert(baseSymptom)
            }
        }
        
        return symptoms
    }
    
    private func extractSymptomContext(around symptom: String, in text: String, at range: Range<String.Index>) -> (severity: String?, duration: String?, location: String?, quality: String?, onset: TemporalReference?) {
        
        // Get surrounding text (100 chars before and after)
        let startIndex = text.index(range.lowerBound, offsetBy: -100, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: 100, limitedBy: text.endIndex) ?? text.endIndex
        let context = String(text[startIndex..<endIndex])
        
        // Extract severity
        let severityWords = ["mild", "moderate", "severe", "intense", "extreme", "slight", "significant"]
        let severity = severityWords.first { context.contains($0) }
        
        // Extract duration
        let duration = extractDuration(from: context)
        
        // Extract location with word boundaries
        let locationWords = ["chest", "head", "abdomen", "back", "arm", "leg", "throat", "stomach", "eye", "neck", "shoulder"]
        let location = locationWords.first { word in
            // Use word boundary matching to avoid partial matches
            let pattern = "\\b\(word)\\b"
            return context.range(of: pattern, options: .regularExpression) != nil
        }
        
        // Extract quality
        let qualityWords = ["sharp", "dull", "burning", "crushing", "stabbing", "throbbing", "aching"]
        let quality = qualityWords.first { context.contains($0) }
        
        // Extract onset
        let onset = extractTemporalReference(from: context)
        
        return (severity, duration, location, quality, onset)
    }
    
    // MARK: - Negation Detection
    
    private func checkNegation(_ text: String, within distance: Int) -> Bool {
        let words = text.split(separator: " ")
        let recentWords = words.suffix(distance / 5)  // Approximate word count
        
        for trigger in negationTriggers {
            if recentWords.contains(where: { $0.lowercased().contains(trigger) }) {
                return true
            }
        }
        
        return false
    }
    
    private func detectNegations(_ text: String) -> [NegatedFinding] {
        var negations: [NegatedFinding] = []
        
        for trigger in negationTriggers {
            if let triggerRange = text.range(of: trigger) {
                // Look for what follows the negation
                let afterText = String(text[triggerRange.upperBound...])
                let words = afterText.split(separator: " ").prefix(5)
                let finding = words.joined(separator: " ")
                
                let negationType: NegatedFinding.NegationType
                switch trigger {
                case "denies", "denied":
                    negationType = .denied
                case "no evidence", "absence of":
                    negationType = .absent
                case "resolved", "no longer":
                    negationType = .resolved
                case "never":
                    negationType = .never
                default:
                    negationType = .denied
                }
                
                if !finding.isEmpty {
                    negations.append(NegatedFinding(
                        finding: finding,
                        negationType: negationType
                    ))
                }
            }
        }
        
        return negations
    }
    
    // MARK: - Medication Extraction
    
    private func extractMedications(_ text: String) -> [Medication] {
        var medications: [Medication] = []
        
        // Common medication patterns
        let medicationNames = [
            "aspirin", "metformin", "lisinopril", "atorvastatin", "metoprolol",
            "omeprazole", "amlodipine", "losartan", "gabapentin", "hydrochlorothiazide",
            "levothyroxine", "simvastatin", "albuterol", "warfarin", "furosemide",
            "insulin", "prednisone", "ibuprofen", "acetaminophen", "amoxicillin"
        ]
        
        for medName in medicationNames {
            if text.contains(medName) {
                // Extract dose and frequency
                let medContext = extractMedicationContext(for: medName, in: text)
                medications.append(medContext)
            }
        }
        
        return medications
    }
    
    private func extractMedicationContext(for medication: String, in text: String) -> Medication {
        // Find medication mention
        guard let range = text.range(of: medication) else {
            return Medication(name: medication, dose: nil, frequency: nil, route: nil, status: .current)
        }
        
        // Get surrounding context
        let startIndex = text.index(range.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
        let endIndex = text.index(range.upperBound, offsetBy: 50, limitedBy: text.endIndex) ?? text.endIndex
        let context = String(text[startIndex..<endIndex])
        
        // Extract dose (look for numbers followed by mg, mcg, units, etc.)
        let dose = extractDose(from: context)
        
        // Extract frequency
        let frequency = extractFrequency(from: context)
        
        // Extract route
        let route = extractRoute(from: context)
        
        // Determine status
        let status: Medication.MedicationStatus
        if context.contains("stopped") || context.contains("discontinued") {
            let when = extractDuration(from: context)
            status = .discontinued(when: when)
        } else if context.contains("allergic") || context.contains("allergy") {
            status = .allergic
        } else if context.contains("considering") || context.contains("might start") {
            status = .considered
        } else {
            status = .current
        }
        
        return Medication(
            name: medication,
            dose: dose,
            frequency: frequency,
            route: route,
            status: status
        )
    }
    
    private func extractDose(from text: String) -> String? {
        let pattern = "(\\d+(?:\\.\\d+)?)[\\s-]*(mg|mcg|g|ml|units?|iu)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        return nil
    }
    
    private func extractFrequency(from text: String) -> String? {
        let frequencies = ["once daily", "twice daily", "three times daily", "four times daily",
                          "qd", "bid", "tid", "qid", "as needed", "prn", "at bedtime", "qhs"]
        return frequencies.first { text.contains($0) }
    }
    
    private func extractRoute(from text: String) -> String? {
        let routes = ["by mouth", "po", "intravenous", "iv", "intramuscular", "im",
                     "subcutaneous", "sq", "topical", "inhaled", "nasal"]
        return routes.first { text.contains($0) }
    }
    
    // MARK: - Temporal Extraction
    
    private func extractTimeline(_ text: String) -> [TemporalEvent] {
        var events: [TemporalEvent] = []
        
        // Look for temporal patterns
        let pattern = "(\\d+)\\s*(minutes?|hours?|days?|weeks?|months?|years?)\\s*(ago|since|for)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)
            
            for match in matches {
                if let matchRange = Range(match.range, in: text) {
                    let matchText = String(text[matchRange])
                    if let temporal = parseTemporalReference(matchText) {
                        // Get the preceding context to understand what event this refers to
                        let beforeRange = text.index(matchRange.lowerBound, offsetBy: -50, limitedBy: text.startIndex) ?? text.startIndex
                        let eventContext = String(text[beforeRange..<matchRange.lowerBound])
                        
                        events.append(TemporalEvent(
                            event: eventContext.trimmingCharacters(in: .whitespacesAndNewlines),
                            reference: temporal
                        ))
                    }
                }
            }
        }
        
        return events
    }
    
    private func extractTemporalReference(from text: String) -> TemporalReference? {
        return parseTemporalReference(text)
    }
    
    private func parseTemporalReference(_ text: String) -> TemporalReference? {
        let pattern = "(\\d+)\\s*(minutes?|hours?|days?|weeks?|months?|years?)\\s*(ago|since|for)?"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                // Extract number
                var value: Int?
                if let valueRange = Range(match.range(at: 1), in: text) {
                    value = Int(text[valueRange])
                }
                
                // Extract unit
                var unit: TemporalReference.TimeUnit?
                if let unitRange = Range(match.range(at: 2), in: text) {
                    let unitText = text[unitRange].lowercased()
                    switch unitText {
                    case let u where u.starts(with: "minute"): unit = .minutes
                    case let u where u.starts(with: "hour"): unit = .hours
                    case let u where u.starts(with: "day"): unit = .days
                    case let u where u.starts(with: "week"): unit = .weeks
                    case let u where u.starts(with: "month"): unit = .months
                    case let u where u.starts(with: "year"): unit = .years
                    default: break
                    }
                }
                
                // Extract relation
                var relation = TemporalReference.TemporalRelation.ago
                if match.numberOfRanges > 3, let relationRange = Range(match.range(at: 3), in: text) {
                    let relationText = text[relationRange].lowercased()
                    switch relationText {
                    case "ago": relation = .ago
                    case "since": relation = .since
                    case "for": relation = .for_duration
                    default: break
                    }
                }
                
                return TemporalReference(value: value, unit: unit, relation: relation)
            }
        }
        return nil
    }
    
    private func extractDuration(from text: String) -> String? {
        let pattern = "(\\d+)\\s*(minutes?|hours?|days?|weeks?|months?|years?)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                return String(text[Range(match.range, in: text)!])
            }
        }
        return nil
    }
    
    // MARK: - Condition Extraction
    
    private func extractConditions(_ text: String) -> [MedicalCondition] {
        var conditions: [MedicalCondition] = []
        
        let conditionPatterns = [
            "diabetes", "hypertension", "heart disease", "copd", "asthma",
            "cancer", "stroke", "heart attack", "kidney disease", "liver disease",
            "arthritis", "depression", "anxiety", "thyroid", "anemia"
        ]
        
        for pattern in conditionPatterns {
            if text.contains(pattern) {
                let status = determineConditionStatus(for: pattern, in: text)
                conditions.append(MedicalCondition(
                    name: pattern,
                    status: status,
                    onset: nil
                ))
            }
        }
        
        return conditions
    }
    
    private func determineConditionStatus(for condition: String, in text: String) -> MedicalCondition.ConditionStatus {
        guard let range = text.range(of: condition) else { return .active }
        
        let beforeText = String(text[..<range.lowerBound])
        let afterText = String(text[range.upperBound...])
        
        if beforeText.contains("history of") || beforeText.contains("past") {
            return .resolved
        } else if beforeText.contains("chronic") || afterText.contains("for years") {
            return .chronic
        } else if beforeText.contains("acute") || beforeText.contains("new") {
            return .acute
        } else if beforeText.contains("ruled out") || beforeText.contains("no evidence") {
            return .ruled_out
        }
        
        return .active
    }
    
    // MARK: - Vital Signs Extraction
    
    private func extractVitals(_ text: String) -> [VitalSign] {
        var vitals: [VitalSign] = []
        
        // Blood pressure pattern
        let bpPattern = "(\\d{2,3})/(\\d{2,3})"
        if let regex = try? NSRegularExpression(pattern: bpPattern) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if let matchRange = Range(match.range, in: text) {
                    let value = String(text[matchRange])
                    vitals.append(VitalSign(
                        type: "Blood Pressure",
                        value: value,
                        unit: "mmHg",
                        interpretation: interpretBP(value)
                    ))
                }
            }
        }
        
        // Heart rate pattern
        let hrPattern = "(?:heart rate|hr|pulse)[:\\s]*(\\d{2,3})"
        if let regex = try? NSRegularExpression(pattern: hrPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if let valueRange = Range(match.range(at: 1), in: text) {
                    let value = String(text[valueRange])
                    vitals.append(VitalSign(
                        type: "Heart Rate",
                        value: value,
                        unit: "bpm",
                        interpretation: interpretHR(value)
                    ))
                }
            }
        }
        
        // Temperature pattern
        let tempPattern = "(?:temp|temperature)[:\\s]*(\\d{2,3}(?:\\.\\d)?)"
        if let regex = try? NSRegularExpression(pattern: tempPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                if let valueRange = Range(match.range(at: 1), in: text) {
                    let value = String(text[valueRange])
                    vitals.append(VitalSign(
                        type: "Temperature",
                        value: value,
                        unit: "°F",
                        interpretation: interpretTemp(value)
                    ))
                }
            }
        }
        
        return vitals
    }
    
    private func interpretBP(_ value: String) -> String {
        let components = value.split(separator: "/")
        guard components.count == 2,
              let systolic = Int(components[0]),
              let diastolic = Int(components[1]) else { return "" }
        
        if systolic < 90 || diastolic < 60 {
            return "Hypotensive"
        } else if systolic >= 180 || diastolic >= 120 {
            return "Hypertensive crisis"
        } else if systolic >= 140 || diastolic >= 90 {
            return "Hypertensive"
        } else if systolic >= 120 || diastolic >= 80 {
            return "Elevated"
        } else {
            return "Normal"
        }
    }
    
    private func interpretHR(_ value: String) -> String {
        guard let hr = Int(value) else { return "" }
        
        if hr < 60 {
            return "Bradycardic"
        } else if hr > 100 {
            return "Tachycardic"
        } else {
            return "Normal"
        }
    }
    
    private func interpretTemp(_ value: String) -> String {
        guard let temp = Double(value) else { return "" }
        
        if temp < 96.8 {
            return "Hypothermic"
        } else if temp >= 100.4 {
            return "Febrile"
        } else if temp >= 99 {
            return "Low-grade fever"
        } else {
            return "Afebrile"
        }
    }
    
    // MARK: - Proper Medical Formatting
    
    private func formatNegationProperly(_ negation: NegatedFinding) -> String {
        // Convert verbatim quotes to proper medical abbreviations
        switch negation.negationType {
        case .denied:
            return "Denies \(negation.finding)"
        case .absent:
            return "No \(negation.finding)"
        case .resolved:
            return "Resolved \(negation.finding)"
        case .never:
            return "No h/o \(negation.finding)"
        }
    }
    
    // MARK: - Generate Enhanced Summary
    
    func generateEnhancedSummary(from context: MedicalContext) -> String {
        var summary = "## Enhanced Medical Analysis\n\n"
        
        // Active symptoms (not negated)
        let activeSymptoms = context.symptoms.filter { !$0.isNegated }
        if !activeSymptoms.isEmpty {
            summary += "### Active Symptoms\n"
            for symptom in activeSymptoms {
                var line = "• \(symptom.name.capitalized)"
                if let severity = symptom.severity { line += " (\(severity))" }
                // FIXED: Removed location logic causing "in chest" issues
                if let duration = symptom.onset {
                    line += " for \(duration.value ?? 0) \(duration.unit?.description ?? "")"
                }
                summary += line + "\n"
            }
            summary += "\n"
        }
        
        // Negated findings
        if !context.negations.isEmpty {
            summary += "### Pertinent Negatives\n"
            for negation in context.negations {
                summary += "• \(formatNegationProperly(negation))\n"
            }
            summary += "\n"
        }
        
        // Current medications
        let currentMeds = context.medications.filter { 
            if case .current = $0.status { return true }
            return false
        }
        if !currentMeds.isEmpty {
            summary += "### Current Medications\n"
            for med in currentMeds {
                var line = "• \(med.name.capitalized)"
                if let dose = med.dose { line += " \(dose)" }
                if let freq = med.frequency { line += " \(freq)" }
                summary += line + "\n"
            }
            summary += "\n"
        }
        
        // Medical conditions
        if !context.conditions.isEmpty {
            summary += "### Medical Conditions\n"
            for condition in context.conditions {
                summary += "• \(condition.name.capitalized) (\(condition.status.description))\n"
            }
            summary += "\n"
        }
        
        // Vital signs
        if !context.vitals.isEmpty {
            summary += "### Vital Signs\n"
            for vital in context.vitals {
                var line = "• \(vital.type): \(vital.value)"
                if let unit = vital.unit { line += " \(unit)" }
                if let interp = vital.interpretation, !interp.isEmpty { 
                    line += " [\(interp)]" 
                }
                summary += line + "\n"
            }
            summary += "\n"
        }
        
        // Timeline
        if !context.timeline.isEmpty {
            summary += "### Timeline\n"
            for event in context.timeline {
                summary += "• \(event.event): \(event.reference.description)\n"
            }
        }
        
        return summary
    }
}

// MARK: - Extensions for Descriptions

extension EnhancedMedicalAnalyzer.NegatedFinding.NegationType {
    var description: String {
        switch self {
        case .denied: return "Patient denies"
        case .absent: return "No evidence of"
        case .resolved: return "Resolved"
        case .never: return "Never had"
        }
    }
}

extension EnhancedMedicalAnalyzer.MedicalCondition.ConditionStatus {
    var description: String {
        switch self {
        case .active: return "Active"
        case .resolved: return "Resolved"
        case .chronic: return "Chronic"
        case .acute: return "Acute"
        case .ruled_out: return "Ruled out"
        }
    }
}

extension EnhancedMedicalAnalyzer.TemporalReference {
    var description: String {
        guard let value = value, let unit = unit else { return "" }
        
        switch relation {
        case .ago: return "\(value) \(unit) ago"
        case .since: return "since \(value) \(unit)"
        case .for_duration: return "for \(value) \(unit)"
        case .until: return "until \(value) \(unit)"
        case .ongoing: return "ongoing for \(value) \(unit)"
        }
    }
}

extension EnhancedMedicalAnalyzer.TemporalReference.TimeUnit {
    var description: String {
        switch self {
        case .minutes: return "minutes"
        case .hours: return "hours"
        case .days: return "days"
        case .weeks: return "weeks"
        case .months: return "months"
        case .years: return "years"
        }
    }
}