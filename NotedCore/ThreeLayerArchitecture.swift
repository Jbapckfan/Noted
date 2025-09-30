import Foundation

// MARK: - THREE-LAYER ARCHITECTURE
// Layer 1: Perception (What was said)
// Layer 2: Comprehension (What it means)
// Layer 3: Generation (How to document)

// ═══════════════════════════════════════════════════════════════
// LAYER 1: PERCEPTION - Transcription & Basic Processing
// ═══════════════════════════════════════════════════════════════

struct PerceptionLayer {

    /// Raw transcription with metadata
    struct TranscribedSegment {
        let text: String
        let speaker: Speaker
        let timestamp: TimeInterval
        let confidence: Double
        let alternatives: [String]
    }

    enum Speaker {
        case doctor
        case patient
        case nurse
        case family
        case unknown
    }

    /// Process raw transcription into structured segments
    static func process(_ rawTranscription: String) -> [TranscribedSegment] {
        // For now, simple implementation - will enhance with real Speech framework integration
        let sentences = rawTranscription.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var segments: [TranscribedSegment] = []
        var currentTime: TimeInterval = 0

        for sentence in sentences {
            let speaker = inferSpeaker(from: sentence)

            segments.append(TranscribedSegment(
                text: sentence,
                speaker: speaker,
                timestamp: currentTime,
                confidence: 0.9, // Placeholder - would come from Speech framework
                alternatives: []
            ))

            // Estimate 3 seconds per sentence
            currentTime += 3.0
        }

        return segments
    }

    private static func inferSpeaker(from text: String) -> Speaker {
        let lower = text.lowercased()

        // Doctor indicators
        if lower.contains("let me") || lower.contains("i'm going to") ||
           lower.contains("i recommend") || lower.contains("we'll") {
            return .doctor
        }

        // Patient indicators
        if lower.contains("i have") || lower.contains("i feel") ||
           lower.contains("my pain") || lower.contains("i'm experiencing") {
            return .patient
        }

        return .unknown
    }
}

// ═══════════════════════════════════════════════════════════════
// LAYER 2: COMPREHENSION - Semantic Understanding
// ═══════════════════════════════════════════════════════════════

struct ComprehensionLayer {

    // MARK: - Core Entities

    enum EntityType {
        case symptom
        case finding
        case medication
        case allergy
        case medicalHistory
        case socialHistory
        case familyHistory
        case treatment
        case diagnostic
    }

    struct ClinicalEntity: Identifiable {
        let id: UUID
        let type: EntityType
        var attributes: [String: Any]
        var mentions: [EntityMention]
        var relationships: [EntityRelationship]
        var temporalAnchors: [TemporalAnchor]
        var confidence: Double

        init(type: EntityType, attributes: [String: Any] = [:]) {
            self.id = UUID()
            self.type = type
            self.attributes = attributes
            self.mentions = []
            self.relationships = []
            self.temporalAnchors = []
            self.confidence = 1.0
        }
    }

    struct EntityMention {
        let segmentIndex: Int
        let textRange: Range<String.Index>
        let referenceType: ReferenceType

        enum ReferenceType {
            case direct      // "chest pain"
            case pronoun     // "it"
            case definite    // "the pain"
            case possessive  // "my pain"
        }
    }

    struct EntityRelationship {
        let relatedEntityId: UUID
        let type: RelationshipType

        enum RelationshipType {
            case causes
            case alleviates
            case worsens
            case temporallyRelated
            case spatiallyRelated
            case treats
        }
    }

    struct TemporalAnchor {
        let time: TemporalExpression
        let eventType: EventType

        enum EventType {
            case onset
            case peak
            case resolution
            case worsening
            case improvement
        }
    }

    enum TemporalExpression {
        case absolute(Date)
        case relative(offset: TimeInterval, from: Date)
        case duration(TimeInterval)
        case descriptive(String)  // "2 hours ago", "last night"
    }

    // MARK: - Structured HPI (OLDCARTS)

    struct StructuredHPI {
        var onset: TemporalExpression?
        var location: AnatomicalLocation?
        var duration: Duration?
        var character: [String]
        var alleviatingFactors: [String]
        var radiationPattern: [String]
        var timing: Timing?
        var severity: Severity?
        var associatedSymptoms: [UUID]  // References to other symptom entities

        var completeness: Double {
            var score = 0.0
            if onset != nil { score += 1.0 }
            if location != nil { score += 1.0 }
            if duration != nil { score += 1.0 }
            if !character.isEmpty { score += 1.0 }
            if !alleviatingFactors.isEmpty { score += 1.0 }
            if !radiationPattern.isEmpty { score += 1.0 }
            if timing != nil { score += 1.0 }
            if severity != nil { score += 1.0 }
            return score / 8.0  // OLDCARTS = 8 elements
        }
    }

    struct AnatomicalLocation {
        let primary: String
        let descriptors: [String]  // "substernal", "epigastric", etc.
    }

    struct Duration {
        let value: TimeInterval
        let pattern: DurationPattern

        enum DurationPattern {
            case continuous
            case intermittent
            case episodic
            case constant
        }
    }

    struct Timing {
        let pattern: String
        let trend: Trend

        enum Trend {
            case worsening
            case improving
            case stable
            case fluctuating
        }
    }

    struct Severity {
        let scale: SeverityScale
        let value: Any

        enum SeverityScale {
            case numeric(min: Int, max: Int)  // 1-10
            case descriptive  // mild, moderate, severe
            case functional   // affects daily activities
        }
    }

    // MARK: - Comprehension Engine

    class ComprehensionEngine {
        private var entities: [UUID: ClinicalEntity] = [:]
        private var segments: [PerceptionLayer.TranscribedSegment] = []

        func comprehend(_ segments: [PerceptionLayer.TranscribedSegment]) -> [ClinicalEntity] {
            self.segments = segments

            // Step 1: Extract initial entities
            extractEntities()

            // Step 2: Link pronouns and references
            linkReferences()

            // Step 3: Extract relationships
            extractRelationships()

            // Step 4: Build temporal timeline
            buildTemporalTimeline()

            // Step 5: Structure HPI elements
            structureHPI()

            return Array(entities.values)
        }

        private func extractEntities() {
            for (index, segment) in segments.enumerated() {
                let text = segment.text.lowercased()

                // Extract symptoms
                if text.contains("pain") {
                    let painEntity = extractPainEntity(from: segment, index: index)
                    entities[painEntity.id] = painEntity
                }

                // Extract medications
                if text.contains("taking") || text.contains("medication") {
                    let medEntities = extractMedicationEntities(from: segment, index: index)
                    medEntities.forEach { entities[$0.id] = $0 }
                }

                // Extract allergies
                if text.contains("allergic") || text.contains("allergy") {
                    let allergyEntities = extractAllergyEntities(from: segment, index: index)
                    allergyEntities.forEach { entities[$0.id] = $0 }
                }

                // Extract vital signs
                if text.contains("blood pressure") || text.contains("heart rate") {
                    let vitalEntities = extractVitalEntities(from: segment, index: index)
                    vitalEntities.forEach { entities[$0.id] = $0 }
                }
            }
        }

        private func extractPainEntity(from segment: PerceptionLayer.TranscribedSegment, index: Int) -> ClinicalEntity {
            var entity = ClinicalEntity(type: .symptom, attributes: ["type": "pain"])

            let text = segment.text.lowercased()

            // Extract location
            if text.contains("chest") {
                entity.attributes["location"] = "chest"
                if text.contains("substernal") {
                    entity.attributes["location_detail"] = "substernal"
                }
            } else if text.contains("abdomen") || text.contains("stomach") {
                entity.attributes["location"] = "abdomen"
            } else if text.contains("head") {
                entity.attributes["location"] = "head"
            }

            // Extract character
            var characters: [String] = []
            if text.contains("crushing") { characters.append("crushing") }
            if text.contains("sharp") { characters.append("sharp") }
            if text.contains("dull") { characters.append("dull") }
            if text.contains("burning") { characters.append("burning") }
            if text.contains("pressure") { characters.append("pressure") }
            if !characters.isEmpty {
                entity.attributes["character"] = characters
            }

            // Extract severity
            if let severityMatch = text.range(of: #"(\d+)\s*(out of|/)\s*10"#, options: .regularExpression) {
                let severityText = String(text[severityMatch])
                if let numMatch = severityText.range(of: #"\d+"#, options: .regularExpression),
                   let severity = Int(String(severityText[numMatch])) {
                    entity.attributes["severity"] = severity
                }
            }

            // Extract temporal info
            if text.contains("started") {
                if text.contains("2 hours ago") || text.contains("two hours ago") {
                    entity.temporalAnchors.append(TemporalAnchor(
                        time: .relative(offset: -7200, from: Date()),
                        eventType: .onset
                    ))
                } else if text.contains("this morning") {
                    entity.temporalAnchors.append(TemporalAnchor(
                        time: .descriptive("this morning"),
                        eventType: .onset
                    ))
                }
            }

            // Extract radiation
            var radiation: [String] = []
            if text.contains("left arm") { radiation.append("left arm") }
            if text.contains("jaw") { radiation.append("jaw") }
            if text.contains("back") { radiation.append("back") }
            if !radiation.isEmpty {
                entity.attributes["radiation"] = radiation
            }

            // Add mention
            entity.mentions.append(EntityMention(
                segmentIndex: index,
                textRange: text.startIndex..<text.endIndex,
                referenceType: .direct
            ))

            return entity
        }

        private func extractMedicationEntities(from segment: PerceptionLayer.TranscribedSegment, index: Int) -> [ClinicalEntity] {
            var medications: [ClinicalEntity] = []
            let text = segment.text.lowercased()

            let medNames = ["lisinopril", "metformin", "aspirin", "atorvastatin", "metoprolol"]

            for medName in medNames {
                if text.contains(medName) {
                    var entity = ClinicalEntity(type: .medication, attributes: ["name": medName])

                    // Try to extract dose
                    if let doseMatch = text.range(of: #"\d+\s*mg"#, options: .regularExpression) {
                        entity.attributes["dose"] = String(text[doseMatch])
                    }

                    entity.mentions.append(EntityMention(
                        segmentIndex: index,
                        textRange: text.startIndex..<text.endIndex,
                        referenceType: .direct
                    ))

                    medications.append(entity)
                }
            }

            return medications
        }

        private func extractAllergyEntities(from segment: PerceptionLayer.TranscribedSegment, index: Int) -> [ClinicalEntity] {
            var allergies: [ClinicalEntity] = []
            let text = segment.text.lowercased()

            let allergens = ["penicillin", "sulfa", "latex", "shellfish"]

            for allergen in allergens {
                if text.contains(allergen) {
                    var entity = ClinicalEntity(type: .allergy, attributes: ["allergen": allergen])

                    // Extract reaction
                    if text.contains("rash") {
                        entity.attributes["reaction"] = "rash"
                    } else if text.contains("anaphylaxis") {
                        entity.attributes["reaction"] = "anaphylaxis"
                        entity.attributes["severity"] = "severe"
                    }

                    entity.mentions.append(EntityMention(
                        segmentIndex: index,
                        textRange: text.startIndex..<text.endIndex,
                        referenceType: .direct
                    ))

                    allergies.append(entity)
                }
            }

            return allergies
        }

        private func extractVitalEntities(from segment: PerceptionLayer.TranscribedSegment, index: Int) -> [ClinicalEntity] {
            var vitals: [ClinicalEntity] = []
            let text = segment.text.lowercased()

            // Blood pressure
            if let bpMatch = text.range(of: #"(\d{2,3})\s*over\s*(\d{2,3})"#, options: .regularExpression) {
                let bpText = String(text[bpMatch])
                var entity = ClinicalEntity(type: .finding, attributes: ["type": "blood_pressure", "value": bpText])
                entity.mentions.append(EntityMention(
                    segmentIndex: index,
                    textRange: bpMatch,
                    referenceType: .direct
                ))
                vitals.append(entity)
            }

            // Heart rate
            if let hrMatch = text.range(of: #"heart rate.*?(\d{2,3})"#, options: .regularExpression) {
                let hrText = String(text[hrMatch])
                var entity = ClinicalEntity(type: .finding, attributes: ["type": "heart_rate", "value": hrText])
                entity.mentions.append(EntityMention(
                    segmentIndex: index,
                    textRange: hrMatch,
                    referenceType: .direct
                ))
                vitals.append(entity)
            }

            return vitals
        }

        private func linkReferences() {
            // Link pronouns to entities
            for (index, segment) in segments.enumerated() {
                let text = segment.text.lowercased()

                // Find pronouns
                if text.contains("it") || text.contains("the pain") || text.contains("my pain") {
                    // Find most recent pain entity
                    if let painEntity = findRecentEntity(ofType: .symptom, before: index, with: ["type": "pain"]) {
                        // Add pronoun mention to that entity
                        var updated = entities[painEntity.id]!

                        let referenceType: EntityMention.ReferenceType
                        if text.contains("it") {
                            referenceType = .pronoun
                        } else if text.contains("the pain") {
                            referenceType = .definite
                        } else {
                            referenceType = .possessive
                        }

                        updated.mentions.append(EntityMention(
                            segmentIndex: index,
                            textRange: text.startIndex..<text.endIndex,
                            referenceType: referenceType
                        ))

                        entities[painEntity.id] = updated
                    }
                }
            }
        }

        private func findRecentEntity(ofType type: EntityType, before index: Int, with attributes: [String: String]) -> ClinicalEntity? {
            // Find entities mentioned before this segment
            let candidates = entities.values.filter { entity in
                entity.type == type &&
                entity.mentions.contains { $0.segmentIndex < index }
            }

            // Filter by attributes
            let filtered = candidates.filter { entity in
                attributes.allSatisfy { key, value in
                    if let entityValue = entity.attributes[key] as? String {
                        return entityValue == value
                    }
                    return false
                }
            }

            // Return most recent
            return filtered.max { e1, e2 in
                let max1 = e1.mentions.map { $0.segmentIndex }.max() ?? 0
                let max2 = e2.mentions.map { $0.segmentIndex }.max() ?? 0
                return max1 < max2
            }
        }

        private func extractRelationships() {
            // Extract relationships between entities
            for (index, segment) in segments.enumerated() {
                let text = segment.text.lowercased()

                // "worse with movement" -> pain worsens with activity
                if text.contains("worse with") || text.contains("worsens with") {
                    // Find pain entity
                    if let painEntity = findRecentEntity(ofType: .symptom, before: index + 1, with: ["type": "pain"]) {
                        // Create activity entity if doesn't exist
                        // Add relationship
                        // (Simplified for now)
                    }
                }

                // "better with rest" -> pain alleviates with rest
                if text.contains("better with") || text.contains("improves with") || text.contains("relieved by") {
                    // Similar logic
                }
            }
        }

        private func buildTemporalTimeline() {
            // Order entities by temporal anchors
            // Build coherent timeline of events
            // (Implementation depends on specific use case)
        }

        private func structureHPI() {
            // Find main symptom entities
            // Build OLDCARTS structure for each
            // (Implementation would map entities to structured HPI)
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// LAYER 3: GENERATION - Document Creation
// ═══════════════════════════════════════════════════════════════

struct GenerationLayer {

    // MARK: - Document Generation

    class DocumentGenerator {

        func generateClinicalNote(from entities: [ComprehensionLayer.ClinicalEntity]) -> ClinicalNote {
            // Generate structured note from entities
            var note = ClinicalNote()

            // Extract symptoms and build HPI
            let symptoms = entities.filter { $0.type == .symptom }
            note.chiefComplaint = generateChiefComplaint(from: symptoms)
            note.hpi = generateHPI(from: symptoms)

            // Extract medications
            let medications = entities.filter { $0.type == .medication }
            note.medications = generateMedicationList(from: medications)

            // Extract allergies
            let allergies = entities.filter { $0.type == .allergy }
            note.allergies = generateAllergyList(from: allergies)

            // Extract findings (vitals, physical exam)
            let findings = entities.filter { $0.type == .finding }
            note.physicalExam = generatePhysicalExam(from: findings)

            // Quality metrics
            note.qualityMetrics = calculateQuality(entities: entities)

            return note
        }

        private func generateChiefComplaint(from symptoms: [ComprehensionLayer.ClinicalEntity]) -> String {
            guard let primarySymptom = symptoms.first else {
                return "Unspecified complaint"
            }

            if let location = primarySymptom.attributes["location"] as? String {
                let symptomType = primarySymptom.attributes["type"] as? String ?? "symptom"

                // Add duration if available
                if let onset = primarySymptom.temporalAnchors.first(where: { $0.eventType == .onset }) {
                    return "\(location.capitalized) \(symptomType) x [duration]"
                }

                return "\(location.capitalized) \(symptomType)"
            }

            return "Symptom present"
        }

        private func generateHPI(from symptoms: [ComprehensionLayer.ClinicalEntity]) -> String {
            guard let primarySymptom = symptoms.first else {
                return "Patient presents with chief complaint as noted."
            }

            var hpi: [String] = []

            // Onset
            if let onset = primarySymptom.temporalAnchors.first(where: { $0.eventType == .onset }) {
                hpi.append("Symptoms began \(formatTemporal(onset.time))")
            }

            // Location
            if let location = primarySymptom.attributes["location"] as? String {
                hpi.append("located in the \(location)")
            }

            // Character
            if let characters = primarySymptom.attributes["character"] as? [String] {
                hpi.append("described as \(characters.joined(separator: " and "))")
            }

            // Severity
            if let severity = primarySymptom.attributes["severity"] as? Int {
                hpi.append("rated \(severity)/10 in severity")
            }

            // Radiation
            if let radiation = primarySymptom.attributes["radiation"] as? [String] {
                hpi.append("radiating to \(radiation.joined(separator: " and "))")
            }

            return hpi.joined(separator: ", ") + "."
        }

        private func generateMedicationList(from medications: [ComprehensionLayer.ClinicalEntity]) -> String {
            if medications.isEmpty {
                return "None documented"
            }

            let medStrings = medications.compactMap { med -> String? in
                guard let name = med.attributes["name"] as? String else { return nil }

                if let dose = med.attributes["dose"] as? String {
                    return "\(name.capitalized) \(dose)"
                }

                return name.capitalized
            }

            return medStrings.joined(separator: ", ")
        }

        private func generateAllergyList(from allergies: [ComprehensionLayer.ClinicalEntity]) -> String {
            if allergies.isEmpty {
                return "NKDA"
            }

            let allergyStrings = allergies.compactMap { allergy -> String? in
                guard let allergen = allergy.attributes["allergen"] as? String else { return nil }

                if let reaction = allergy.attributes["reaction"] as? String {
                    return "\(allergen.capitalized) (\(reaction))"
                }

                return allergen.capitalized
            }

            return allergyStrings.joined(separator: "; ")
        }

        private func generatePhysicalExam(from findings: [ComprehensionLayer.ClinicalEntity]) -> String {
            if findings.isEmpty {
                return "Physical examination documented in chart"
            }

            var exam: [String] = []

            // Group by type
            let vitals = findings.filter { ($0.attributes["type"] as? String)?.contains("blood_pressure") == true ||
                                          ($0.attributes["type"] as? String)?.contains("heart_rate") == true }

            if !vitals.isEmpty {
                let vitalStrings = vitals.compactMap { vital -> String? in
                    guard let type = vital.attributes["type"] as? String,
                          let value = vital.attributes["value"] as? String else { return nil }

                    let label = type.replacingOccurrences(of: "_", with: " ").capitalized
                    return "\(label): \(value)"
                }

                if !vitalStrings.isEmpty {
                    exam.append("Vitals: \(vitalStrings.joined(separator: ", "))")
                }
            }

            return exam.joined(separator: "\n")
        }

        private func formatTemporal(_ temporal: ComprehensionLayer.TemporalExpression) -> String {
            switch temporal {
            case .absolute(let date):
                return "on \(date.formatted())"
            case .relative(let offset, _):
                let hours = abs(offset) / 3600
                return "\(Int(hours)) hours ago"
            case .duration(let interval):
                let hours = interval / 3600
                return "for \(Int(hours)) hours"
            case .descriptive(let desc):
                return desc
            }
        }

        private func calculateQuality(entities: [ComprehensionLayer.ClinicalEntity]) -> QualityMetrics {
            var metrics = QualityMetrics()

            // Calculate completeness based on entity types present
            let entityTypes = Set(entities.map { $0.type })

            var completenessScore = 0.0
            if entityTypes.contains(.symptom) { completenessScore += 0.2 }
            if entityTypes.contains(.medication) { completenessScore += 0.15 }
            if entityTypes.contains(.allergy) { completenessScore += 0.15 }
            if entityTypes.contains(.finding) { completenessScore += 0.2 }
            if entityTypes.contains(.medicalHistory) { completenessScore += 0.15 }
            if entityTypes.contains(.socialHistory) { completenessScore += 0.15 }

            metrics.completeness = min(completenessScore, 1.0)

            // Calculate average confidence
            let avgConfidence = entities.map { $0.confidence }.reduce(0.0, +) / Double(max(entities.count, 1))
            metrics.confidence = avgConfidence

            return metrics
        }
    }

    // MARK: - Output Structures

    struct ClinicalNote {
        var chiefComplaint: String = ""
        var hpi: String = ""
        var medications: String = ""
        var allergies: String = ""
        var physicalExam: String = ""
        var qualityMetrics: QualityMetrics = QualityMetrics()

        func generateSOAPNote() -> String {
            return """
            CHIEF COMPLAINT: \(chiefComplaint)

            HISTORY OF PRESENT ILLNESS:
            \(hpi)

            MEDICATIONS: \(medications)
            ALLERGIES: \(allergies)

            PHYSICAL EXAM:
            \(physicalExam)

            QUALITY METRICS:
            Completeness: \(Int(qualityMetrics.completeness * 100))%
            Confidence: \(Int(qualityMetrics.confidence * 100))%
            """
        }
    }

    struct QualityMetrics {
        var completeness: Double = 0.0
        var confidence: Double = 0.0
        var specificity: Double = 0.0
    }
}

// ═══════════════════════════════════════════════════════════════
// INTEGRATION: Pipeline Coordinator
// ═══════════════════════════════════════════════════════════════

class ThreeLayerPipeline {

    /// Main entry point: Raw transcription → Structured clinical note
    static func process(_ rawTranscription: String) -> GenerationLayer.ClinicalNote {
        // Layer 1: Perception
        let segments = PerceptionLayer.process(rawTranscription)

        // Layer 2: Comprehension
        let comprehensionEngine = ComprehensionLayer.ComprehensionEngine()
        let entities = comprehensionEngine.comprehend(segments)

        // Layer 3: Generation
        let generator = GenerationLayer.DocumentGenerator()
        let note = generator.generateClinicalNote(from: entities)

        return note
    }
}
