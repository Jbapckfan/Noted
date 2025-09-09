import Foundation
import NaturalLanguage
import CoreML
import CreateML
import TabularData

// MARK: - Deep Medical Context Engine with Advanced NLP
actor DeepMedicalContextEngine {
    
    // MARK: - NLP Components
    private let tokenizer = NLTokenizer(unit: .word)
    private let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType, .lemma])
    private let sentimentAnalyzer = NLModel()
    private let entityRecognizer: NLModel
    
    // MARK: - Medical Knowledge Base
    private let medicalOntology = MedicalOntology()
    private let clinicalGuidelines = ClinicalGuidelinesDatabase()
    private let drugDatabase = DrugInteractionDatabase()
    private let symptomAnalyzer = SymptomAnalyzer()
    private let anatomyMapper = AnatomyMapper()
    
    // MARK: - ML Models
    private var contextPredictionModel: MLModel?
    private var severityClassifier: MLModel?
    private var urgencyDetector: MLModel?
    private var clinicalRelevanceModel: MLModel?
    
    // MARK: - Context State
    private var sessionContexts: [UUID: SessionContext] = [:]
    private let contextHistory = ContextHistory()
    
    // MARK: - Configuration
    struct Configuration {
        var enableDeepLearning: Bool = true
        var enableTemporalAnalysis: Bool = true
        var enableRelationshipExtraction: Bool = true
        var contextWindowSize: Int = 100
        var minConfidence: Double = 0.7
        var enableCrossReference: Bool = true
        var maxContextDepth: Int = 5
    }
    
    private var configuration: Configuration
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.entityRecognizer = try! NLModel(mlModel: Self.loadEntityModel())
    }
    
    // MARK: - Initialization
    func initialize() async {
        await loadModels()
        await loadKnowledgeBases()
        await initializeNLP()
    }
    
    private func loadModels() async {
        // Load pre-trained models
        contextPredictionModel = try? await loadModel(named: "ContextPrediction")
        severityClassifier = try? await loadModel(named: "SeverityClassifier")
        urgencyDetector = try? await loadModel(named: "UrgencyDetector")
        clinicalRelevanceModel = try? await loadModel(named: "ClinicalRelevance")
    }
    
    private func loadModel(named name: String) async throws -> MLModel {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
            throw ContextEngineError.modelNotFound(name)
        }
        return try MLModel(contentsOf: url)
    }
    
    private static func loadEntityModel() -> MLModel {
        // Create or load a medical entity recognition model
        // In production, this would be a pre-trained BERT or BioBERT model
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        
        // Placeholder - replace with actual model
        return try! MLModel(contentsOf: Bundle.main.url(forResource: "MedicalNER", withExtension: "mlmodelc")!,
                           configuration: configuration)
    }
    
    private func loadKnowledgeBases() async {
        await medicalOntology.load()
        await clinicalGuidelines.load()
        await drugDatabase.load()
        await symptomAnalyzer.loadSymptomDatabase()
        await anatomyMapper.loadAnatomyMap()
    }
    
    private func initializeNLP() async {
        tokenizer.string = ""
        tagger.string = ""
    }
    
    // MARK: - Session Management
    func prepareSession(_ sessionID: UUID, encounterType: EncounterType) async {
        sessionContexts[sessionID] = SessionContext(
            sessionID: sessionID,
            encounterType: encounterType,
            startTime: Date(),
            entities: [],
            relationships: [],
            timeline: ClinicalTimeline(),
            patientProfile: PatientProfile()
        )
    }
    
    func cleanupSession(_ sessionID: UUID) async {
        if let context = sessionContexts[sessionID] {
            await contextHistory.archive(context)
        }
        sessionContexts.removeValue(forKey: sessionID)
    }
    
    // MARK: - Context Update
    func updateContext(
        transcription: TranscriptionResult,
        previousContext: ClinicalContext,
        encounterType: EncounterType
    ) async -> ClinicalContext {
        
        // Extract entities and relationships
        let entities = await extractMedicalEntities(from: transcription.text)
        let relationships = await extractRelationships(entities: entities, text: transcription.text)
        
        // Analyze temporal information
        let temporalInfo = await analyzeTemporalInformation(transcription.text, entities: entities)
        
        // Build symptom profile
        let symptomProfile = await buildSymptomProfile(entities: entities, text: transcription.text)
        
        // Analyze clinical relevance
        let relevance = await analyzeClinicalRelevance(
            entities: entities,
            symptoms: symptomProfile,
            encounterType: encounterType
        )
        
        // Update patient profile
        let patientProfile = await updatePatientProfile(
            previous: previousContext.patientProfile,
            entities: entities,
            symptoms: symptomProfile
        )
        
        // Generate clinical insights
        let insights = await generateInsights(
            entities: entities,
            relationships: relationships,
            symptoms: symptomProfile,
            patientProfile: patientProfile
        )
        
        // Calculate confidence
        let confidence = calculateContextConfidence(
            entities: entities,
            relationships: relationships,
            insights: insights
        )
        
        return ClinicalContext(
            entities: entities,
            relationships: relationships,
            temporalInfo: temporalInfo,
            symptomProfile: symptomProfile,
            patientProfile: patientProfile,
            clinicalRelevance: relevance,
            insights: insights,
            confidence: confidence,
            lastUpdate: Date()
        )
    }
    
    // MARK: - Entity Extraction
    private func extractMedicalEntities(from text: String) async -> [MedicalEntity] {
        var entities: [MedicalEntity] = []
        
        // Use NLP tagger for initial extraction
        tagger.string = text
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if let tag = tag {
                let substring = String(text[range])
                
                // Check if it's a medical entity
                if let medicalType = await classifyMedicalEntity(substring, tag: tag) {
                    let entity = MedicalEntity(
                        text: substring,
                        type: medicalType,
                        range: range,
                        confidence: 0.9,
                        attributes: await extractEntityAttributes(substring, type: medicalType)
                    )
                    entities.append(entity)
                }
            }
            return true
        }
        
        // Use deep learning model for advanced extraction
        if configuration.enableDeepLearning {
            let dlEntities = await extractWithDeepLearning(text)
            entities = mergeEntities(entities, dlEntities)
        }
        
        // Cross-reference with medical databases
        if configuration.enableCrossReference {
            entities = await validateWithMedicalDatabases(entities)
        }
        
        return entities
    }
    
    private func classifyMedicalEntity(_ text: String, tag: NLTag) async -> MedicalEntityType? {
        // Check medical ontology
        if await medicalOntology.isSymptom(text) {
            return .symptom
        } else if await medicalOntology.isDiagnosis(text) {
            return .diagnosis
        } else if await medicalOntology.isMedication(text) {
            return .medication
        } else if await medicalOntology.isProcedure(text) {
            return .procedure
        } else if await medicalOntology.isAnatomicalSite(text) {
            return .anatomicalSite
        } else if await medicalOntology.isLabTest(text) {
            return .labTest
        }
        
        // Use ML model for classification
        if let model = entityRecognizer.model {
            let prediction = try? model.prediction(from: text)
            if let entityType = prediction?.entityType {
                return MedicalEntityType(rawValue: entityType)
            }
        }
        
        return nil
    }
    
    private func extractEntityAttributes(_ text: String, type: MedicalEntityType) async -> [String: Any] {
        var attributes: [String: Any] = [:]
        
        switch type {
        case .symptom:
            attributes["severity"] = await symptomAnalyzer.analyzeSeverity(text)
            attributes["duration"] = await symptomAnalyzer.analyzeDuration(text)
            attributes["frequency"] = await symptomAnalyzer.analyzeFrequency(text)
            
        case .medication:
            if let drugInfo = await drugDatabase.lookup(text) {
                attributes["dosage"] = drugInfo.dosage
                attributes["route"] = drugInfo.route
                attributes["frequency"] = drugInfo.frequency
                attributes["interactions"] = drugInfo.interactions
            }
            
        case .anatomicalSite:
            attributes["laterality"] = await anatomyMapper.extractLaterality(text)
            attributes["region"] = await anatomyMapper.mapToRegion(text)
            
        case .diagnosis:
            attributes["icd10"] = await medicalOntology.getICD10Code(text)
            attributes["certainty"] = await analyzeDiagnosisCertainty(text)
            
        default:
            break
        }
        
        return attributes
    }
    
    private func extractWithDeepLearning(_ text: String) async -> [MedicalEntity] {
        guard let model = contextPredictionModel else { return [] }
        
        // Tokenize text for BERT-like model
        let tokens = tokenizeForBERT(text)
        
        // Create input features
        let input = try? MLDictionaryFeatureProvider(dictionary: [
            "tokens": MLMultiArray(tokens),
            "attention_mask": MLMultiArray(Array(repeating: 1, count: tokens.count))
        ])
        
        guard let input = input,
              let output = try? model.prediction(from: input) else { return [] }
        
        // Parse model output to entities
        return parseModelOutput(output, originalText: text)
    }
    
    // MARK: - Relationship Extraction
    private func extractRelationships(entities: [MedicalEntity], text: String) async -> [EntityRelationship] {
        var relationships: [EntityRelationship] = []
        
        guard configuration.enableRelationshipExtraction else { return relationships }
        
        // Use dependency parsing and pattern matching
        for i in 0..<entities.count {
            for j in (i+1)..<entities.count {
                let entity1 = entities[i]
                let entity2 = entities[j]
                
                // Check proximity
                if areEntitiesProximate(entity1, entity2, in: text) {
                    // Analyze relationship type
                    if let relationType = await analyzeRelationship(entity1, entity2, text: text) {
                        let relationship = EntityRelationship(
                            source: entity1,
                            target: entity2,
                            type: relationType,
                            confidence: 0.8
                        )
                        relationships.append(relationship)
                    }
                }
            }
        }
        
        return relationships
    }
    
    private func areEntitiesProximate(_ e1: MedicalEntity, _ e2: MedicalEntity, in text: String) -> Bool {
        // Check if entities are within reasonable proximity (same sentence or adjacent sentences)
        let distance = text.distance(from: e1.range.upperBound, to: e2.range.lowerBound)
        return distance < configuration.contextWindowSize
    }
    
    private func analyzeRelationship(_ e1: MedicalEntity, _ e2: MedicalEntity, text: String) async -> RelationshipType? {
        // Analyze text between entities to determine relationship
        let contextText = String(text[e1.range.upperBound..<e2.range.lowerBound])
        
        if contextText.contains("caused by") || contextText.contains("due to") {
            return .causedBy
        } else if contextText.contains("treated with") || contextText.contains("prescribed") {
            return .treatedWith
        } else if contextText.contains("located in") || contextText.contains("at") {
            return .locatedAt
        } else if contextText.contains("associated with") || contextText.contains("related to") {
            return .associatedWith
        }
        
        return nil
    }
    
    // MARK: - Temporal Analysis
    private func analyzeTemporalInformation(_ text: String, entities: [MedicalEntity]) async -> TemporalInfo {
        var timeline = ClinicalTimeline()
        
        // Extract time expressions
        let timeExpressions = extractTimeExpressions(from: text)
        
        // Map entities to timeline
        for entity in entities {
            if let timeRef = findNearestTimeReference(for: entity, in: timeExpressions, text: text) {
                timeline.addEvent(ClinicalEvent(
                    entity: entity,
                    timestamp: timeRef.resolvedTime,
                    duration: timeRef.duration,
                    frequency: timeRef.frequency
                ))
            }
        }
        
        return TemporalInfo(
            timeline: timeline,
            onsetTime: timeline.earliestEvent?.timestamp,
            duration: timeline.totalDuration,
            progression: analyzeProgression(timeline)
        )
    }
    
    private func extractTimeExpressions(from text: String) -> [TimeExpression] {
        var expressions: [TimeExpression] = []
        
        // Pattern matching for time expressions
        let patterns = [
            "\\d+ (days?|weeks?|months?|years?) ago",
            "for \\d+ (days?|weeks?|months?)",
            "since (yesterday|last week|last month)",
            "started (today|yesterday|this morning)",
            "acute onset",
            "gradual onset",
            "chronic"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let timeText = String(text[range])
                        let expression = TimeExpression(
                            text: timeText,
                            range: range,
                            resolvedTime: resolveTimeExpression(timeText),
                            duration: extractDuration(from: timeText),
                            frequency: extractFrequency(from: timeText)
                        )
                        expressions.append(expression)
                    }
                }
            }
        }
        
        return expressions
    }
    
    // MARK: - Symptom Analysis
    private func buildSymptomProfile(entities: [MedicalEntity], text: String) async -> SymptomProfile {
        let symptoms = entities.filter { $0.type == .symptom }
        
        var profile = SymptomProfile()
        
        for symptom in symptoms {
            let analysis = await symptomAnalyzer.analyzeSymptom(symptom, context: text)
            
            profile.symptoms.append(SymptomDetail(
                name: symptom.text,
                severity: analysis.severity,
                duration: analysis.duration,
                frequency: analysis.frequency,
                characteristics: analysis.characteristics,
                aggravatingFactors: analysis.aggravatingFactors,
                alleviatingFactors: analysis.alleviatingFactors,
                associatedSymptoms: findAssociatedSymptoms(symptom, in: symptoms)
            ))
        }
        
        // Calculate overall severity
        profile.overallSeverity = calculateOverallSeverity(profile.symptoms)
        
        // Identify symptom clusters
        profile.clusters = identifySymptomClusters(profile.symptoms)
        
        // Generate differential considerations
        profile.differentialConsiderations = await generateDifferentials(profile)
        
        return profile
    }
    
    // MARK: - Clinical Relevance
    private func analyzeClinicalRelevance(
        entities: [MedicalEntity],
        symptoms: SymptomProfile,
        encounterType: EncounterType
    ) async -> ClinicalRelevance {
        
        // Identify red flags
        let redFlags = await identifyRedFlags(entities: entities, symptoms: symptoms)
        
        // Calculate urgency score
        let urgencyScore = await calculateUrgency(
            symptoms: symptoms,
            redFlags: redFlags,
            encounterType: encounterType
        )
        
        // Determine required actions
        let requiredActions = await determineRequiredActions(
            urgencyScore: urgencyScore,
            redFlags: redFlags,
            encounterType: encounterType
        )
        
        // Check clinical guidelines
        let guidelineRecommendations = await checkGuidelines(
            entities: entities,
            symptoms: symptoms,
            encounterType: encounterType
        )
        
        return ClinicalRelevance(
            urgencyScore: urgencyScore,
            redFlags: redFlags,
            requiredActions: requiredActions,
            guidelineRecommendations: guidelineRecommendations,
            riskFactors: await identifyRiskFactors(entities: entities),
            clinicalPriority: determinePriority(urgencyScore: urgencyScore, redFlags: redFlags)
        )
    }
    
    // MARK: - Summary Generation
    func generateSummary(session: PipelineSession) async -> ClinicalSummary {
        let context = session.clinicalContext
        
        // Structure the summary
        let chiefComplaint = extractChiefComplaint(context)
        let hpi = generateHPI(context)
        let ros = generateROS(context)
        let assessment = generateAssessment(context)
        let plan = generatePlan(context)
        
        return ClinicalSummary(
            chiefComplaint: chiefComplaint,
            hpi: hpi,
            ros: ros,
            physicalExam: nil, // Only if explicitly mentioned
            assessment: assessment,
            plan: plan,
            criticalFindings: context.clinicalRelevance?.redFlags ?? [],
            confidence: context.confidence
        )
    }
    
    // MARK: - Helper Methods
    private func tokenizeForBERT(_ text: String) -> [Int] {
        // Simplified tokenization - in production use proper BERT tokenizer
        let words = text.lowercased().split(separator: " ")
        return words.map { word in
            // Map to vocabulary indices
            word.hashValue % 30000 // Simplified mapping
        }
    }
    
    private func parseModelOutput(_ output: MLFeatureProvider, originalText: String) -> [MedicalEntity] {
        // Parse BERT-like model output to extract entities
        var entities: [MedicalEntity] = []
        
        // Implementation depends on model architecture
        // This is a placeholder
        
        return entities
    }
    
    private func mergeEntities(_ primary: [MedicalEntity], _ secondary: [MedicalEntity]) -> [MedicalEntity] {
        var merged = primary
        
        for entity in secondary {
            if !merged.contains(where: { $0.overlaps(with: entity) }) {
                merged.append(entity)
            }
        }
        
        return merged.sorted { $0.range.lowerBound < $1.range.lowerBound }
    }
    
    private func validateWithMedicalDatabases(_ entities: [MedicalEntity]) async -> [MedicalEntity] {
        var validated: [MedicalEntity] = []
        
        for entity in entities {
            var validEntity = entity
            
            // Validate against medical databases
            switch entity.type {
            case .medication:
                if await drugDatabase.validate(entity.text) {
                    validEntity.confidence *= 1.1
                }
            case .diagnosis:
                if await medicalOntology.validateDiagnosis(entity.text) {
                    validEntity.confidence *= 1.1
                }
            case .symptom:
                if await symptomAnalyzer.validateSymptom(entity.text) {
                    validEntity.confidence *= 1.1
                }
            default:
                break
            }
            
            validated.append(validEntity)
        }
        
        return validated
    }
    
    private func calculateContextConfidence(
        entities: [MedicalEntity],
        relationships: [EntityRelationship],
        insights: [ClinicalInsight]
    ) -> Double {
        let entityConfidence = entities.map { $0.confidence }.reduce(0, +) / Double(max(entities.count, 1))
        let relationshipConfidence = relationships.map { $0.confidence }.reduce(0, +) / Double(max(relationships.count, 1))
        let insightConfidence = insights.map { $0.confidence }.reduce(0, +) / Double(max(insights.count, 1))
        
        return (entityConfidence * 0.4 + relationshipConfidence * 0.3 + insightConfidence * 0.3)
    }
    
    func clearCache(olderThan date: Date) async {
        await contextHistory.clearOld(before: date)
    }
}

// MARK: - Supporting Types
struct ClinicalContext {
    let entities: [MedicalEntity]
    let relationships: [EntityRelationship]
    let temporalInfo: TemporalInfo
    let symptomProfile: SymptomProfile
    let patientProfile: PatientProfile?
    let clinicalRelevance: ClinicalRelevance?
    let insights: [ClinicalInsight]
    let confidence: Double
    let lastUpdate: Date
}

struct MedicalEntity {
    let text: String
    let type: MedicalEntityType
    let range: Range<String.Index>
    var confidence: Double
    let attributes: [String: Any]
    
    func overlaps(with other: MedicalEntity) -> Bool {
        return range.overlaps(other.range)
    }
}

enum MedicalEntityType: String {
    case symptom
    case diagnosis
    case medication
    case procedure
    case anatomicalSite
    case labTest
    case vitalSign
    case allergy
}

struct EntityRelationship {
    let source: MedicalEntity
    let target: MedicalEntity
    let type: RelationshipType
    let confidence: Double
}

enum RelationshipType {
    case causedBy
    case treatedWith
    case locatedAt
    case associatedWith
    case contraindicatedWith
    case precedesCase
}

struct SymptomProfile {
    var symptoms: [SymptomDetail] = []
    var overallSeverity: Double = 0
    var clusters: [SymptomCluster] = []
    var differentialConsiderations: [String] = []
}

struct SymptomDetail {
    let name: String
    let severity: Double
    let duration: TimeInterval?
    let frequency: String?
    let characteristics: [String]
    let aggravatingFactors: [String]
    let alleviatingFactors: [String]
    let associatedSymptoms: [String]
}

struct ClinicalRelevance {
    let urgencyScore: Double
    let redFlags: [RedFlag]
    let requiredActions: [ClinicalAction]
    let guidelineRecommendations: [String]
    let riskFactors: [RiskFactor]
    let clinicalPriority: Priority
}

struct ClinicalSummary {
    let chiefComplaint: String
    let hpi: String
    let ros: String
    let physicalExam: String?
    let assessment: String
    let plan: String
    let criticalFindings: [RedFlag]
    let confidence: Double
}

enum ContextEngineError: Error {
    case modelNotFound(String)
    case insufficientContext
    case processingError(String)
}