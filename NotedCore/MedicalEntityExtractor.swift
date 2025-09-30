import Foundation
import NaturalLanguage
import CoreML

/// Advanced medical entity extraction with NER capabilities and confidence scoring
/// Extracts symptoms, medications, vitals, procedures, and other medical entities from conversation text
@MainActor
class MedicalEntityExtractor: ObservableObject {
    static let shared = MedicalEntityExtractor()

    // MARK: - Medical Vocabularies and Patterns

    private let symptomVocabulary: Set<String> = [
        // Pain-related
        "pain", "ache", "aching", "sharp pain", "dull pain", "burning pain", "stabbing pain",
        "chest pain", "abdominal pain", "back pain", "headache", "migraine", "neck pain",
        "shoulder pain", "knee pain", "joint pain", "muscle pain", "bone pain",

        // Respiratory
        "cough", "shortness of breath", "dyspnea", "wheezing", "chest tightness",
        "difficulty breathing", "unable to breathe", "can't catch breath", "winded",

        // Cardiovascular
        "palpitations", "racing heart", "irregular heartbeat", "chest pressure",
        "chest heaviness", "crushing sensation", "radiating pain",

        // Gastrointestinal
        "nausea", "vomiting", "throwing up", "diarrhea", "constipation",
        "stomach pain", "belly pain", "heartburn", "acid reflux", "bloating",
        "loss of appetite", "no appetite", "can't eat",

        // Neurological
        "dizziness", "lightheaded", "vertigo", "confusion", "memory loss",
        "weakness", "numbness", "tingling", "pins and needles", "seizure",
        "tremor", "shaking", "balance problems", "coordination problems",

        // General/Constitutional
        "fever", "chills", "night sweats", "fatigue", "tired", "exhausted",
        "weakness", "malaise", "weight loss", "weight gain", "appetite changes",

        // Skin/Dermatological
        "rash", "itching", "burning skin", "swelling", "redness", "bruising",
        "bleeding", "discharge", "lesion", "bump", "lump",

        // Sleep/Psychiatric
        "insomnia", "can't sleep", "difficulty sleeping", "anxiety", "worried",
        "depressed", "sad", "mood changes", "panic", "restlessness"
    ]

    private let medicationVocabulary: Set<String> = [
        // Common medications
        "aspirin", "tylenol", "acetaminophen", "ibuprofen", "advil", "motrin", "aleve", "naproxen",

        // Cardiovascular
        "lisinopril", "metoprolol", "atorvastatin", "simvastatin", "amlodipine", "losartan",
        "carvedilol", "enalapril", "hydrochlorothiazide", "furosemide", "warfarin", "apixaban",
        "rivaroxaban", "clopidogrel", "digoxin", "amiodarone", "diltiazem", "verapamil",

        // Diabetes
        "metformin", "insulin", "glipizide", "glyburide", "januvia", "jardiance", "ozempic",
        "victoza", "trulicity", "lantus", "humalog", "novolog",

        // Respiratory
        "albuterol", "advair", "symbicort", "spiriva", "singulair", "prednisone", "prednisolone",

        // Antibiotics
        "amoxicillin", "azithromycin", "ciprofloxacin", "doxycycline", "cephalexin", "clindamycin",
        "levofloxacin", "trimethoprim", "sulfamethoxazole", "penicillin", "augmentin",

        // Psychiatric
        "sertraline", "zoloft", "escitalopram", "lexapro", "fluoxetine", "prozac",
        "duloxetine", "cymbalta", "bupropion", "wellbutrin", "trazodone", "mirtazapine",
        "alprazolam", "xanax", "lorazepam", "ativan", "clonazepam", "klonopin",

        // Sleep aids
        "zolpidem", "ambien", "trazodone", "melatonin", "diphenhydramine", "benadryl",

        // GI medications
        "omeprazole", "prilosec", "pantoprazole", "protonix", "famotidine", "pepcid",
        "ranitidine", "zantac", "simethicone", "gas-x", "loperamide", "imodium",

        // Pain medications
        "tramadol", "hydrocodone", "oxycodone", "morphine", "fentanyl", "codeine",
        "gabapentin", "lyrica", "pregabalin", "meloxicam", "celecoxib", "celebrex"
    ]

    private let vitalSignPatterns: [String] = [
        // Blood pressure patterns
        "blood pressure", "bp", "systolic", "diastolic", "hypertension", "hypotension",

        // Heart rate patterns
        "heart rate", "pulse", "bpm", "beats per minute", "tachycardia", "bradycardia",

        // Temperature patterns
        "temperature", "temp", "fever", "febrile", "afebrile", "celsius", "fahrenheit",

        // Respiratory patterns
        "respiratory rate", "breathing rate", "respirations", "o2 sat", "oxygen saturation",
        "pulse ox", "spo2",

        // Weight/BMI patterns
        "weight", "pounds", "kilograms", "lbs", "kg", "bmi", "body mass index",

        // Pain scale patterns
        "pain scale", "out of 10", "pain level", "0 to 10", "1 to 10"
    ]

    private let anatomicalVocabulary: Set<String> = [
        "head", "neck", "chest", "abdomen", "back", "arm", "leg", "hand", "foot",
        "shoulder", "elbow", "wrist", "hip", "knee", "ankle", "throat", "ear", "eye",
        "nose", "mouth", "stomach", "belly", "heart", "lung", "liver", "kidney",
        "brain", "spine", "pelvis", "groin", "thigh", "calf", "shin", "forearm"
    ]

    private let temporalPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"(\d+)\s+(days?|weeks?|months?|years?)\s+ago"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"for\s+(\d+)\s+(days?|weeks?|months?|years?)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"since\s+(yesterday|today|this\s+morning|last\s+night)"#, options: .caseInsensitive),
        try! NSRegularExpression(pattern: #"(suddenly|gradual|progressive|intermittent|constant|chronic|acute)"#, options: .caseInsensitive)
    ]

    // MARK: - Entity Extraction Methods

    private init() {}

    /// Extract medical entities from text in real-time with high performance
    func extractEntitiesRealtime(_ text: String, confidence: Double) async -> ExtractedMedicalEntities {
        return await performEntityExtraction(text, isComprehensive: false, confidence: confidence)
    }

    /// Extract medical entities with comprehensive analysis (slower but more thorough)
    func extractEntitiesComprehensive(_ text: String) async -> ExtractedMedicalEntities {
        return await performEntityExtraction(text, isComprehensive: true, confidence: 0.8)
    }

    // MARK: - Core Entity Extraction

    private func performEntityExtraction(_ text: String, isComprehensive: Bool, confidence: Double) async -> ExtractedMedicalEntities {
        let startTime = Date()

        // Preprocessing
        let processedText = preprocessText(text)
        let sentences = splitIntoSentences(processedText)

        var entities = ExtractedMedicalEntities()

        // Extract different entity types
        entities.symptoms = await extractSymptoms(sentences, isComprehensive: isComprehensive)
        entities.medications = await extractMedications(sentences, isComprehensive: isComprehensive)
        entities.vitals = await extractVitalSigns(sentences, isComprehensive: isComprehensive)
        entities.conditions = await extractConditions(sentences, isComprehensive: isComprehensive)
        entities.procedures = await extractProcedures(sentences, isComprehensive: isComprehensive)
        entities.anatomicalReferences = await extractAnatomicalReferences(sentences)
        entities.temporalExpressions = await extractTemporalExpressions(text)

        if isComprehensive {
            entities.severity = await analyzeSeverity(sentences)
            entities.negations = await detectNegations(sentences)
            entities.relationships = await extractRelationships(sentences, entities)
        }

        // Calculate confidence scores
        entities.confidence = calculateOverallConfidence(entities, inputConfidence: confidence)
        entities.processingTime = Date().timeIntervalSince(startTime)

        return entities
    }

    // MARK: - Symptom Extraction

    private func extractSymptoms(_ sentences: [String], isComprehensive: Bool) async -> [ExtractedEntity] {
        var symptoms: [ExtractedEntity] = []

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            // Direct vocabulary matching
            for symptom in symptomVocabulary {
                if lowerSentence.contains(symptom) {
                    let confidence = calculateSymptomConfidence(symptom, in: sentence)
                    let entity = ExtractedEntity(
                        text: symptom,
                        type: .symptom,
                        confidence: confidence,
                        startIndex: sentence.range(of: symptom, options: .caseInsensitive)?.lowerBound.utf16Offset(in: sentence) ?? 0,
                        endIndex: sentence.range(of: symptom, options: .caseInsensitive)?.upperBound.utf16Offset(in: sentence) ?? symptom.count,
                        sentenceIndex: index,
                        context: sentence
                    )
                    symptoms.append(entity)
                }
            }

            if isComprehensive {
                // Pattern-based symptom extraction
                let patternSymptoms = await extractSymptomsWithPatterns(sentence, sentenceIndex: index)
                symptoms.append(contentsOf: patternSymptoms)
            }
        }

        // Remove duplicates and merge similar symptoms
        return await postprocessSymptoms(symptoms)
    }

    private func extractSymptomsWithPatterns(_ sentence: String, sentenceIndex: Int) async -> [ExtractedEntity] {
        var symptoms: [ExtractedEntity] = []

        // Pattern: "I have/feel/experience [symptom]"
        let symptomPatterns = [
            #"(?:i\s+(?:have|feel|experience|am\s+having|been\s+having))\s+([^.!?]+)"#,
            #"(?:patient\s+(?:reports|complains\s+of|presents\s+with))\s+([^.!?]+)"#,
            #"(?:started|began)\s+(?:with|experiencing)\s+([^.!?]+)"#,
            #"(?:pain|ache|aching|hurts?|painful)\s+in\s+(?:my|the)\s+([^.!?]+)"#
        ]

        for patternString in symptomPatterns {
            if let regex = try? NSRegularExpression(pattern: patternString, options: .caseInsensitive) {
                let matches = regex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))

                for match in matches {
                    if let symptomRange = Range(match.range(at: 1), in: sentence) {
                        let symptomText = String(sentence[symptomRange]).trimmingCharacters(in: .whitespaces)
                        if isValidSymptom(symptomText) {
                            let entity = ExtractedEntity(
                                text: symptomText,
                                type: .symptom,
                                confidence: 0.7,
                                startIndex: symptomRange.lowerBound.utf16Offset(in: sentence),
                                endIndex: symptomRange.upperBound.utf16Offset(in: sentence),
                                sentenceIndex: sentenceIndex,
                                context: sentence
                            )
                            symptoms.append(entity)
                        }
                    }
                }
            }
        }

        return symptoms
    }

    // MARK: - Medication Extraction

    private func extractMedications(_ sentences: [String], isComprehensive: Bool) async -> [ExtractedEntity] {
        var medications: [ExtractedEntity] = []

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            // Direct vocabulary matching
            for medication in medicationVocabulary {
                if lowerSentence.contains(medication) {
                    let confidence = calculateMedicationConfidence(medication, in: sentence)
                    let entity = ExtractedEntity(
                        text: medication,
                        type: .medication,
                        confidence: confidence,
                        startIndex: sentence.range(of: medication, options: .caseInsensitive)?.lowerBound.utf16Offset(in: sentence) ?? 0,
                        endIndex: sentence.range(of: medication, options: .caseInsensitive)?.upperBound.utf16Offset(in: sentence) ?? medication.count,
                        sentenceIndex: index,
                        context: sentence
                    )
                    medications.append(entity)
                }
            }

            if isComprehensive {
                // Pattern-based medication extraction
                let patternMedications = await extractMedicationsWithPatterns(sentence, sentenceIndex: index)
                medications.append(contentsOf: patternMedications)
            }
        }

        return await postprocessMedications(medications)
    }

    private func extractMedicationsWithPatterns(_ sentence: String, sentenceIndex: Int) async -> [ExtractedEntity] {
        var medications: [ExtractedEntity] = []

        let medicationPatterns = [
            #"(?:taking|on|prescribed|given|started)\s+([a-zA-Z]+(?:\s+[a-zA-Z]+)?)\s*(?:\d+\s*mg|mg|\d+\s*mcg|mcg)?"#,
            #"(?:medication|med|drug|pill|tablet)\s+called\s+([a-zA-Z]+)"#,
            #"(?:prescribed|gave|started)\s+(?:me|him|her|patient)\s+([a-zA-Z]+)"#
        ]

        for patternString in medicationPatterns {
            if let regex = try? NSRegularExpression(pattern: patternString, options: .caseInsensitive) {
                let matches = regex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))

                for match in matches {
                    if let medRange = Range(match.range(at: 1), in: sentence) {
                        let medText = String(sentence[medRange]).trimmingCharacters(in: .whitespaces)
                        if isValidMedication(medText) {
                            let entity = ExtractedEntity(
                                text: medText,
                                type: .medication,
                                confidence: 0.6,
                                startIndex: medRange.lowerBound.utf16Offset(in: sentence),
                                endIndex: medRange.upperBound.utf16Offset(in: sentence),
                                sentenceIndex: sentenceIndex,
                                context: sentence
                            )
                            medications.append(entity)
                        }
                    }
                }
            }
        }

        return medications
    }

    // MARK: - Vital Signs Extraction

    private func extractVitalSigns(_ sentences: [String], isComprehensive: Bool) async -> [ExtractedEntity] {
        var vitals: [ExtractedEntity] = []

        for (index, sentence) in sentences.enumerated() {
            // Blood pressure pattern: "120/80", "BP 140/90"
            if let bpRegex = try? NSRegularExpression(pattern: #"(?:blood\s+pressure|bp)\s*:?\s*(\d{2,3})/(\d{2,3})"#, options: .caseInsensitive) {
                let matches = bpRegex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))
                for match in matches {
                    if let fullRange = Range(match.range, in: sentence) {
                        let bpText = String(sentence[fullRange])
                        let entity = ExtractedEntity(
                            text: bpText,
                            type: .vital,
                            confidence: 0.9,
                            startIndex: fullRange.lowerBound.utf16Offset(in: sentence),
                            endIndex: fullRange.upperBound.utf16Offset(in: sentence),
                            sentenceIndex: index,
                            context: sentence
                        )
                        vitals.append(entity)
                    }
                }
            }

            // Heart rate pattern: "HR 80", "pulse 72"
            if let hrRegex = try? NSRegularExpression(pattern: #"(?:heart\s+rate|hr|pulse)\s*:?\s*(\d{2,3})\s*(?:bpm)?"#, options: .caseInsensitive) {
                let matches = hrRegex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))
                for match in matches {
                    if let fullRange = Range(match.range, in: sentence) {
                        let hrText = String(sentence[fullRange])
                        let entity = ExtractedEntity(
                            text: hrText,
                            type: .vital,
                            confidence: 0.85,
                            startIndex: fullRange.lowerBound.utf16Offset(in: sentence),
                            endIndex: fullRange.upperBound.utf16Offset(in: sentence),
                            sentenceIndex: index,
                            context: sentence
                        )
                        vitals.append(entity)
                    }
                }
            }

            // Temperature pattern: "temp 98.6", "fever of 101"
            if let tempRegex = try? NSRegularExpression(pattern: #"(?:temperature|temp|fever)\s*(?:of)?\s*:?\s*(\d{2,3}(?:\.\d)?)\s*(?:degrees?|°)?\s*(?:f|fahrenheit|c|celsius)?"#, options: .caseInsensitive) {
                let matches = tempRegex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))
                for match in matches {
                    if let fullRange = Range(match.range, in: sentence) {
                        let tempText = String(sentence[fullRange])
                        let entity = ExtractedEntity(
                            text: tempText,
                            type: .vital,
                            confidence: 0.8,
                            startIndex: fullRange.lowerBound.utf16Offset(in: sentence),
                            endIndex: fullRange.upperBound.utf16Offset(in: sentence),
                            sentenceIndex: index,
                            context: sentence
                        )
                        vitals.append(entity)
                    }
                }
            }

            // Oxygen saturation: "O2 sat 98%", "SpO2 95%"
            if let o2Regex = try? NSRegularExpression(pattern: #"(?:o2\s+sat|spo2|oxygen\s+saturation)\s*:?\s*(\d{2,3})\s*%?"#, options: .caseInsensitive) {
                let matches = o2Regex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))
                for match in matches {
                    if let fullRange = Range(match.range, in: sentence) {
                        let o2Text = String(sentence[fullRange])
                        let entity = ExtractedEntity(
                            text: o2Text,
                            type: .vital,
                            confidence: 0.85,
                            startIndex: fullRange.lowerBound.utf16Offset(in: sentence),
                            endIndex: fullRange.upperBound.utf16Offset(in: sentence),
                            sentenceIndex: index,
                            context: sentence
                        )
                        vitals.append(entity)
                    }
                }
            }
        }

        return vitals
    }

    // MARK: - Condition Extraction

    private func extractConditions(_ sentences: [String], isComprehensive: Bool) async -> [ExtractedEntity] {
        var conditions: [ExtractedEntity] = []

        let conditionVocabulary = [
            "diabetes", "hypertension", "high blood pressure", "asthma", "copd", "pneumonia",
            "covid", "covid-19", "coronavirus", "flu", "influenza", "bronchitis", "sinusitis",
            "migraine", "depression", "anxiety", "arthritis", "osteoarthritis", "rheumatoid arthritis",
            "heart disease", "coronary artery disease", "atrial fibrillation", "heart attack",
            "stroke", "kidney disease", "liver disease", "cancer", "tumor", "mass",
            "infection", "uti", "urinary tract infection", "pneumonia", "sepsis"
        ]

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            for condition in conditionVocabulary {
                if lowerSentence.contains(condition) {
                    let confidence = calculateConditionConfidence(condition, in: sentence)
                    let entity = ExtractedEntity(
                        text: condition,
                        type: .condition,
                        confidence: confidence,
                        startIndex: sentence.range(of: condition, options: .caseInsensitive)?.lowerBound.utf16Offset(in: sentence) ?? 0,
                        endIndex: sentence.range(of: condition, options: .caseInsensitive)?.upperBound.utf16Offset(in: sentence) ?? condition.count,
                        sentenceIndex: index,
                        context: sentence
                    )
                    conditions.append(entity)
                }
            }
        }

        return await postprocessConditions(conditions)
    }

    // MARK: - Procedure Extraction

    private func extractProcedures(_ sentences: [String], isComprehensive: Bool) async -> [ExtractedEntity] {
        var procedures: [ExtractedEntity] = []

        let procedureVocabulary = [
            "x-ray", "ct scan", "mri", "ultrasound", "ecg", "ekg", "echo", "echocardiogram",
            "blood test", "lab work", "urine test", "biopsy", "colonoscopy", "endoscopy",
            "surgery", "operation", "procedure", "injection", "shot", "vaccination",
            "mammogram", "stress test", "holter monitor", "sleep study"
        ]

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            for procedure in procedureVocabulary {
                if lowerSentence.contains(procedure) {
                    let confidence = calculateProcedureConfidence(procedure, in: sentence)
                    let entity = ExtractedEntity(
                        text: procedure,
                        type: .procedure,
                        confidence: confidence,
                        startIndex: sentence.range(of: procedure, options: .caseInsensitive)?.lowerBound.utf16Offset(in: sentence) ?? 0,
                        endIndex: sentence.range(of: procedure, options: .caseInsensitive)?.upperBound.utf16Offset(in: sentence) ?? procedure.count,
                        sentenceIndex: index,
                        context: sentence
                    )
                    procedures.append(entity)
                }
            }
        }

        return procedures
    }

    // MARK: - Anatomical Reference Extraction

    private func extractAnatomicalReferences(_ sentences: [String]) async -> [ExtractedEntity] {
        var anatomical: [ExtractedEntity] = []

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            for anatomy in anatomicalVocabulary {
                if lowerSentence.contains(anatomy) {
                    let entity = ExtractedEntity(
                        text: anatomy,
                        type: .anatomical,
                        confidence: 0.7,
                        startIndex: sentence.range(of: anatomy, options: .caseInsensitive)?.lowerBound.utf16Offset(in: sentence) ?? 0,
                        endIndex: sentence.range(of: anatomy, options: .caseInsensitive)?.upperBound.utf16Offset(in: sentence) ?? anatomy.count,
                        sentenceIndex: index,
                        context: sentence
                    )
                    anatomical.append(entity)
                }
            }
        }

        return anatomical
    }

    // MARK: - Temporal Expression Extraction

    private func extractTemporalExpressions(_ text: String) async -> [ExtractedEntity] {
        var temporal: [ExtractedEntity] = []

        for pattern in temporalPatterns {
            let matches = pattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))

            for match in matches {
                if let range = Range(match.range, in: text) {
                    let temporalText = String(text[range])
                    let entity = ExtractedEntity(
                        text: temporalText,
                        type: .temporal,
                        confidence: 0.8,
                        startIndex: range.lowerBound.utf16Offset(in: text),
                        endIndex: range.upperBound.utf16Offset(in: text),
                        sentenceIndex: 0,
                        context: temporalText
                    )
                    temporal.append(entity)
                }
            }
        }

        return temporal
    }

    // MARK: - Advanced Analysis Methods

    private func analyzeSeverity(_ sentences: [String]) async -> [SeverityAssessment] {
        var severities: [SeverityAssessment] = []

        let severityKeywords = [
            "severe": 0.9, "excruciating": 0.95, "unbearable": 0.9, "intense": 0.8,
            "moderate": 0.6, "mild": 0.3, "slight": 0.2, "minimal": 0.1,
            "worst": 0.95, "terrible": 0.8, "horrible": 0.85, "awful": 0.75
        ]

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            for (keyword, severity) in severityKeywords {
                if lowerSentence.contains(keyword) {
                    let assessment = SeverityAssessment(
                        sentenceIndex: index,
                        keyword: keyword,
                        severity: severity,
                        context: sentence
                    )
                    severities.append(assessment)
                }
            }

            // Numeric pain scale detection
            if let painRegex = try? NSRegularExpression(pattern: #"(\d{1,2})\s*(?:out\s+of\s+10|/10|\s+on\s+(?:a\s+)?(?:scale\s+of\s+)?10)"#, options: .caseInsensitive) {
                let matches = painRegex.matches(in: sentence, options: [], range: NSRange(sentence.startIndex..., in: sentence))
                for match in matches {
                    if let numberRange = Range(match.range(at: 1), in: sentence),
                       let painLevel = Int(String(sentence[numberRange])) {
                        let normalizedSeverity = Double(painLevel) / 10.0
                        let assessment = SeverityAssessment(
                            sentenceIndex: index,
                            keyword: "\(painLevel)/10",
                            severity: normalizedSeverity,
                            context: sentence
                        )
                        severities.append(assessment)
                    }
                }
            }
        }

        return severities
    }

    private func detectNegations(_ sentences: [String]) async -> [NegationDetection] {
        var negations: [NegationDetection] = []

        let negationKeywords = ["no", "not", "never", "without", "denies", "negative", "absent", "none"]

        for (index, sentence) in sentences.enumerated() {
            let lowerSentence = sentence.lowercased()

            for keyword in negationKeywords {
                if lowerSentence.contains(keyword) {
                    let negation = NegationDetection(
                        sentenceIndex: index,
                        negationKeyword: keyword,
                        scope: sentence,
                        confidence: 0.8
                    )
                    negations.append(negation)
                }
            }
        }

        return negations
    }

    private func extractRelationships(_ sentences: [String], _ entities: ExtractedMedicalEntities) async -> [EntityRelationship] {
        var relationships: [EntityRelationship] = []

        // Find relationships between symptoms and anatomical locations
        for symptom in entities.symptoms {
            for anatomical in entities.anatomicalReferences {
                if symptom.sentenceIndex == anatomical.sentenceIndex {
                    let relationship = EntityRelationship(
                        entity1: symptom,
                        entity2: anatomical,
                        relationshipType: .locatedIn,
                        confidence: 0.7
                    )
                    relationships.append(relationship)
                }
            }
        }

        // Find relationships between medications and conditions
        for medication in entities.medications {
            for condition in entities.conditions {
                if abs(medication.sentenceIndex - condition.sentenceIndex) <= 2 {
                    let relationship = EntityRelationship(
                        entity1: medication,
                        entity2: condition,
                        relationshipType: .treatsCondition,
                        confidence: 0.6
                    )
                    relationships.append(relationship)
                }
            }
        }

        return relationships
    }

    // MARK: - Confidence Calculation Methods

    private func calculateSymptomConfidence(_ symptom: String, in sentence: String) -> Double {
        var confidence = 0.7 // Base confidence

        let lowerSentence = sentence.lowercased()

        // Increase confidence for first-person statements
        if lowerSentence.contains("i feel") || lowerSentence.contains("i have") || lowerSentence.contains("i'm experiencing") {
            confidence += 0.2
        }

        // Increase confidence for patient reports
        if lowerSentence.contains("patient reports") || lowerSentence.contains("complains of") {
            confidence += 0.15
        }

        // Decrease confidence for negations
        if lowerSentence.contains("no " + symptom) || lowerSentence.contains("not " + symptom) {
            confidence -= 0.4
        }

        return min(confidence, 1.0)
    }

    private func calculateMedicationConfidence(_ medication: String, in sentence: String) -> Double {
        var confidence = 0.8 // Base confidence for medications

        let lowerSentence = sentence.lowercased()

        // Increase confidence for taking/prescribed context
        if lowerSentence.contains("taking") || lowerSentence.contains("prescribed") || lowerSentence.contains("on") {
            confidence += 0.1
        }

        // Increase confidence if dosage is mentioned
        if sentence.contains(#"\d+\s*mg"#) || sentence.contains(#"\d+\s*mcg"#) {
            confidence += 0.1
        }

        return min(confidence, 1.0)
    }

    private func calculateConditionConfidence(_ condition: String, in sentence: String) -> Double {
        var confidence = 0.6 // Base confidence

        let lowerSentence = sentence.lowercased()

        // Increase confidence for diagnosis context
        if lowerSentence.contains("diagnosed with") || lowerSentence.contains("history of") {
            confidence += 0.3
        }

        // Increase confidence for current problems
        if lowerSentence.contains("have") || lowerSentence.contains("suffering from") {
            confidence += 0.2
        }

        return min(confidence, 1.0)
    }

    private func calculateProcedureConfidence(_ procedure: String, in sentence: String) -> Double {
        var confidence = 0.7 // Base confidence

        let lowerSentence = sentence.lowercased()

        // Increase confidence for procedure context
        if lowerSentence.contains("had") || lowerSentence.contains("need") || lowerSentence.contains("order") {
            confidence += 0.2
        }

        return min(confidence, 1.0)
    }

    private func calculateOverallConfidence(_ entities: ExtractedMedicalEntities, inputConfidence: Double) -> Double {
        let entityConfidences = entities.symptoms.map { $0.confidence } +
                               entities.medications.map { $0.confidence } +
                               entities.vitals.map { $0.confidence } +
                               entities.conditions.map { $0.confidence }

        guard !entityConfidences.isEmpty else { return inputConfidence }

        let averageEntityConfidence = entityConfidences.reduce(0, +) / Double(entityConfidences.count)

        // Weight input confidence (from transcription) with entity extraction confidence
        return (inputConfidence * 0.3) + (averageEntityConfidence * 0.7)
    }

    // MARK: - Text Preprocessing

    private func preprocessText(_ text: String) -> String {
        // Normalize text for better extraction
        var processed = text

        // Expand common medical abbreviations
        let abbreviations = [
            "bp": "blood pressure",
            "hr": "heart rate",
            "temp": "temperature",
            "sob": "shortness of breath",
            "cp": "chest pain",
            "abd": "abdominal",
            "htn": "hypertension",
            "dm": "diabetes",
            "cad": "coronary artery disease"
        ]

        for (abbrev, expansion) in abbreviations {
            processed = processed.replacingOccurrences(of: "\\b\(abbrev)\\b", with: expansion, options: .regularExpression)
        }

        return processed
    }

    private func splitIntoSentences(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text

        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let sentence = String(text[tokenRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }

        return sentences
    }

    // MARK: - Validation Methods

    private func isValidSymptom(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.count >= 3 && trimmed.count <= 50 && !trimmed.contains(where: { $0.isNumber })
    }

    private func isValidMedication(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        return trimmed.count >= 3 && trimmed.count <= 30 && trimmed.allSatisfy { $0.isLetter || $0.isWhitespace }
    }

    // MARK: - Postprocessing Methods

    private func postprocessSymptoms(_ symptoms: [ExtractedEntity]) async -> [ExtractedEntity] {
        // Remove duplicates and merge similar symptoms
        var processed: [ExtractedEntity] = []
        var seen: Set<String> = []

        for symptom in symptoms.sorted(by: { $0.confidence > $1.confidence }) {
            let normalizedText = symptom.text.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalizedText) {
                seen.insert(normalizedText)
                processed.append(symptom)
            }
        }

        return processed
    }

    private func postprocessMedications(_ medications: [ExtractedEntity]) async -> [ExtractedEntity] {
        // Remove duplicates and normalize medication names
        var processed: [ExtractedEntity] = []
        var seen: Set<String> = []

        for medication in medications.sorted(by: { $0.confidence > $1.confidence }) {
            let normalizedText = medication.text.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalizedText) {
                seen.insert(normalizedText)
                processed.append(medication)
            }
        }

        return processed
    }

    private func postprocessConditions(_ conditions: [ExtractedEntity]) async -> [ExtractedEntity] {
        // Remove duplicates and merge related conditions
        var processed: [ExtractedEntity] = []
        var seen: Set<String> = []

        for condition in conditions.sorted(by: { $0.confidence > $1.confidence }) {
            let normalizedText = condition.text.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalizedText) {
                seen.insert(normalizedText)
                processed.append(condition)
            }
        }

        return processed
    }
}

// MARK: - Data Models

struct ExtractedMedicalEntities {
    var symptoms: [ExtractedEntity] = []
    var medications: [ExtractedEntity] = []
    var vitals: [ExtractedEntity] = []
    var conditions: [ExtractedEntity] = []
    var procedures: [ExtractedEntity] = []
    var anatomicalReferences: [ExtractedEntity] = []
    var temporalExpressions: [ExtractedEntity] = []
    var severity: [SeverityAssessment] = []
    var negations: [NegationDetection] = []
    var relationships: [EntityRelationship] = []
    var confidence: Double = 0.0
    var processingTime: TimeInterval = 0.0
}

struct ExtractedEntity: Identifiable {
    let id = UUID()
    let text: String
    let type: EntityType
    let confidence: Double
    let startIndex: Int
    let endIndex: Int
    let sentenceIndex: Int
    let context: String

    enum EntityType {
        case symptom
        case medication
        case vital
        case condition
        case procedure
        case anatomical
        case temporal
    }
}

struct SeverityAssessment {
    let sentenceIndex: Int
    let keyword: String
    let severity: Double // 0.0 to 1.0
    let context: String
}

struct NegationDetection {
    let sentenceIndex: Int
    let negationKeyword: String
    let scope: String
    let confidence: Double
}

struct EntityRelationship {
    let entity1: ExtractedEntity
    let entity2: ExtractedEntity
    let relationshipType: RelationshipType
    let confidence: Double

    enum RelationshipType {
        case locatedIn
        case treatsCondition
        case causedBy
        case measuredBy
        case temporallyRelated
    }
}

// Additional supporting models for drug interactions
struct DrugInteractionAlert: Identifiable {
    let id = UUID()
    let drug1: String
    let drug2: String
    let severity: AlertUrgency
    let description: String
    let recommendation: String
    let timestamp: Date = Date()
}

struct AllergyAlert: Identifiable {
    let id = UUID()
    let medication: String
    let allergen: String
    let severity: AlertUrgency
    let description: String
    let timestamp: Date = Date()
}

struct ContraindicationAlert: Identifiable {
    let id = UUID()
    let medication: String
    let condition: String
    let severity: AlertUrgency
    let description: String
    let recommendation: String
    let timestamp: Date = Date()
}