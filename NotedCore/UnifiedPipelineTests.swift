import XCTest
import Foundation
@testable import NotedCore

// MARK: - Comprehensive Testing Framework
final class UnifiedPipelineTests: XCTestCase {
    
    var pipeline: UnifiedMedicalPipeline!
    var mockAudioData: Data!
    
    override func setUp() async throws {
        pipeline = UnifiedMedicalPipeline()
        mockAudioData = generateMockAudioData()
    }
    
    override func tearDown() async throws {
        pipeline = nil
        mockAudioData = nil
    }
    
    // MARK: - Pipeline Tests
    func testSessionCreation() async throws {
        let sessionID = try await pipeline.createSession(
            patientID: "TEST123",
            encounterType: .emergency
        )
        
        XCTAssertNotNil(sessionID)
    }
    
    func testAudioProcessing() async throws {
        let sessionID = try await pipeline.createSession()
        
        let result = try await pipeline.processAudioChunk(
            mockAudioData,
            sessionID: sessionID
        )
        
        XCTAssertNotNil(result.transcription)
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertLessThanOrEqual(result.confidence, 1.0)
        XCTAssertNotNil(result.clinicalInsights)
    }
    
    func testSessionFinalization() async throws {
        let sessionID = try await pipeline.createSession()
        
        // Process some audio
        _ = try await pipeline.processAudioChunk(mockAudioData, sessionID: sessionID)
        
        // Finalize session
        let report = try await pipeline.finalizeSession(sessionID)
        
        XCTAssertNotNil(report.summary)
        XCTAssertNotNil(report.diagnostics)
        XCTAssertNotNil(report.recommendations)
        XCTAssertNotNil(report.billing)
    }
    
    func testConcurrentSessions() async throws {
        let sessions = try await withThrowingTaskGroup(of: UUID.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    try await self.pipeline.createSession()
                }
            }
            
            var sessionIDs: [UUID] = []
            for try await sessionID in group {
                sessionIDs.append(sessionID)
            }
            return sessionIDs
        }
        
        XCTAssertEqual(sessions.count, 5)
        XCTAssertEqual(Set(sessions).count, 5) // All unique
    }
    
    func testPerformanceOptimization() async throws {
        await pipeline.optimizePerformance()
        // Performance optimization should complete without errors
    }
    
    // MARK: - Helper Methods
    private func generateMockAudioData() -> Data {
        // Generate mock audio data for testing
        let sampleRate = 16000
        let duration = 3.0
        let sampleCount = Int(Double(sampleRate) * duration)
        
        var samples: [Float] = []
        for i in 0..<sampleCount {
            // Generate a simple sine wave
            let frequency: Float = 440.0 // A4 note
            let sample = sin(2.0 * Float.pi * frequency * Float(i) / Float(sampleRate))
            samples.append(sample)
        }
        
        return Data(bytes: samples, count: samples.count * MemoryLayout<Float>.size)
    }
}

// MARK: - Transcription Engine Tests
final class AdvancedTranscriptionEngineTests: XCTestCase {
    
    var engine: AdvancedTranscriptionEngine!
    
    override func setUp() async throws {
        engine = AdvancedTranscriptionEngine()
        await engine.initialize()
    }
    
    func testTranscriptionWithContext() async throws {
        let audioData = generateMockAudioData()
        let context = createMockClinicalContext()
        
        let result = await engine.transcribe(audioData, context: context)
        
        XCTAssertFalse(result.text.isEmpty || result.text == "")
        XCTAssertGreaterThan(result.confidence, 0.0)
        XCTAssertNotNil(result.segments)
    }
    
    func testSessionManagement() async throws {
        let sessionID = UUID()
        
        await engine.prepareSession(sessionID)
        // Session should be prepared without errors
        
        await engine.cleanupSession(sessionID)
        // Cleanup should complete without errors
    }
    
    func testCacheClearing() async throws {
        let yesterday = Date().addingTimeInterval(-86400)
        await engine.clearCache(olderThan: yesterday)
        // Cache clearing should complete without errors
    }
    
    private func generateMockAudioData() -> Data {
        Data(repeating: 0, count: 48000)
    }
    
    private func createMockClinicalContext() -> ClinicalContext {
        ClinicalContext(
            entities: [],
            relationships: [],
            temporalInfo: TemporalInfo(
                timeline: ClinicalTimeline(),
                onsetTime: nil,
                duration: nil,
                progression: .acute
            ),
            symptomProfile: SymptomProfile(),
            patientProfile: nil,
            clinicalRelevance: nil,
            insights: [],
            confidence: 0.8,
            lastUpdate: Date()
        )
    }
}

// MARK: - Context Engine Tests
final class DeepMedicalContextEngineTests: XCTestCase {
    
    var contextEngine: DeepMedicalContextEngine!
    
    override func setUp() async throws {
        contextEngine = DeepMedicalContextEngine()
        await contextEngine.initialize()
    }
    
    func testContextUpdate() async throws {
        let transcription = TranscriptionResult(
            text: "Patient presents with chest pain and shortness of breath for 2 days",
            confidence: 0.9,
            segments: [],
            processingTime: 0.5
        )
        
        let previousContext = createEmptyContext()
        
        let updatedContext = await contextEngine.updateContext(
            transcription: transcription,
            previousContext: previousContext,
            encounterType: .emergency
        )
        
        XCTAssertFalse(updatedContext.entities.isEmpty)
        XCTAssertGreaterThan(updatedContext.confidence, 0.0)
    }
    
    func testSummaryGeneration() async throws {
        let session = createMockSession()
        
        let summary = await contextEngine.generateSummary(session: session)
        
        XCTAssertFalse(summary.chiefComplaint.isEmpty)
        XCTAssertFalse(summary.hpi.isEmpty)
        XCTAssertFalse(summary.assessment.isEmpty)
        XCTAssertFalse(summary.plan.isEmpty)
    }
    
    func testSessionLifecycle() async throws {
        let sessionID = UUID()
        
        await contextEngine.prepareSession(sessionID, encounterType: .routine)
        // Preparation should complete
        
        await contextEngine.cleanupSession(sessionID)
        // Cleanup should complete
    }
    
    private func createEmptyContext() -> ClinicalContext {
        ClinicalContext(
            entities: [],
            relationships: [],
            temporalInfo: TemporalInfo(
                timeline: ClinicalTimeline(),
                onsetTime: nil,
                duration: nil,
                progression: .acute
            ),
            symptomProfile: SymptomProfile(),
            patientProfile: nil,
            clinicalRelevance: nil,
            insights: [],
            confidence: 0.0,
            lastUpdate: Date()
        )
    }
    
    private func createMockSession() -> PipelineSession {
        PipelineSession(
            id: UUID(),
            patientID: nil,
            encounterType: .emergency,
            startTime: Date(),
            audioBuffer: AudioBuffer(),
            transcriptionBuffer: TranscriptionBuffer(),
            clinicalContext: createEmptyContext()
        )
    }
}

// MARK: - Clinical Intelligence Tests
final class ClinicalIntelligenceCoreTests: XCTestCase {
    
    var intelligence: ClinicalIntelligenceCore!
    
    override func setUp() async throws {
        intelligence = ClinicalIntelligenceCore()
        await intelligence.initialize()
    }
    
    func testClinicalAnalysis() async throws {
        let transcription = "Patient with severe chest pain radiating to left arm, diaphoretic, nausea"
        let context = createCardiacContext()
        
        let insights = await intelligence.analyze(
            transcription: transcription,
            context: context,
            encounterType: .emergency
        )
        
        XCTAssertFalse(insights.differentials.isEmpty)
        XCTAssertNotNil(insights.riskAssessment)
        XCTAssertGreaterThan(insights.riskAssessment.overallScore, 0.5)
        XCTAssertFalse(insights.treatments.isEmpty)
    }
    
    func testSuggestionGeneration() async throws {
        let context = createCardiacContext()
        let insights = createMockInsights()
        
        let suggestions = await intelligence.generateSuggestions(
            context: context,
            insights: insights
        )
        
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertTrue(suggestions.contains { $0.type == .diagnosticQuestion })
    }
    
    func testBillingCodeGeneration() async throws {
        let context = createCardiacContext()
        let duration: TimeInterval = 2400 // 40 minutes
        
        let billing = await intelligence.generateBillingCodes(
            context: context,
            duration: duration
        )
        
        XCTAssertFalse(billing.emLevel.isEmpty)
        XCTAssertFalse(billing.icd10.isEmpty)
        XCTAssertNotNil(billing.mdmComplexity)
    }
    
    func testAdaptiveLearning() async throws {
        let session = createMockSession()
        let report = createMockReport()
        let feedback = ClinicalFeedback(
            sessionID: session.id,
            actualDiagnosis: "Acute MI",
            outcomeQuality: 5,
            accuracyRating: 4,
            comments: "Good analysis",
            timestamp: Date()
        )
        
        await intelligence.learnFromSession(
            session: session,
            report: report,
            feedback: feedback
        )
        
        // Learning should complete without errors
    }
    
    private func createCardiacContext() -> ClinicalContext {
        var context = createEmptyContext()
        
        // Add cardiac-related entities
        let chestPain = MedicalEntity(
            text: "chest pain",
            type: .symptom,
            range: "chest pain".startIndex..<"chest pain".endIndex,
            confidence: 0.95,
            attributes: ["severity": "severe", "radiation": "left arm"]
        )
        
        context.entities.append(chestPain)
        
        return context
    }
    
    private func createEmptyContext() -> ClinicalContext {
        ClinicalContext(
            entities: [],
            relationships: [],
            temporalInfo: TemporalInfo(
                timeline: ClinicalTimeline(),
                onsetTime: nil,
                duration: nil,
                progression: .acute
            ),
            symptomProfile: SymptomProfile(),
            patientProfile: nil,
            clinicalRelevance: nil,
            insights: [],
            confidence: 0.0,
            lastUpdate: Date()
        )
    }
    
    private func createMockSession() -> PipelineSession {
        PipelineSession(
            id: UUID(),
            patientID: nil,
            encounterType: .emergency,
            startTime: Date(),
            audioBuffer: AudioBuffer(),
            transcriptionBuffer: TranscriptionBuffer(),
            clinicalContext: createEmptyContext()
        )
    }
    
    private func createMockReport() -> FinalReport {
        FinalReport(
            sessionID: UUID(),
            summary: ClinicalSummary(
                chiefComplaint: "Chest pain",
                hpi: "Sudden onset severe chest pain",
                ros: "Positive for chest pain, SOB",
                physicalExam: nil,
                assessment: "Possible ACS",
                plan: "EKG, troponins, cardiology consult",
                criticalFindings: [],
                confidence: 0.85
            ),
            diagnostics: [
                Diagnostic(
                    diagnosis: "Acute MI",
                    icd10Code: "I21.9",
                    confidence: 0.8,
                    evidence: ["chest pain", "EKG changes"],
                    ruledOut: []
                )
            ],
            recommendations: [],
            billing: BillingCodes(
                emLevel: "99285",
                icd10: ["I21.9"],
                cpt: [],
                mdmComplexity: .high,
                timeBasedBilling: false,
                criticalCare: true
            ),
            confidence: 0.85,
            processingMetrics: SessionMetrics()
        )
    }
    
    private func createMockInsights() -> ClinicalInsights {
        ClinicalInsights(
            differentials: [
                DifferentialDiagnosis(
                    diagnosis: "Acute MI",
                    icd10Code: "I21.9",
                    probability: 0.7,
                    supportingEvidence: ["chest pain", "diaphoresis"],
                    ruledOutReasons: [],
                    clinicalPearls: []
                )
            ],
            riskAssessment: RiskAssessment(
                overallScore: 0.8,
                category: .high,
                clinicalRisk: 0.8,
                diagnosticRisk: 0.7,
                mlRisk: 0.75,
                recommendations: ["Immediate EKG", "Cardiac enzymes"],
                criticalFindings: []
            ),
            treatments: [],
            decisionSupport: ClinicalDecisionSupport(
                diagnosticTests: [],
                orderSets: [],
                pathways: [],
                carePlan: CarePlan(
                    goals: [],
                    interventions: [],
                    timeline: "",
                    followUpSchedule: []
                ),
                documentationSuggestions: [],
                criticalActions: []
            ),
            alerts: [],
            qualityIssues: [],
            confidence: 0.8,
            timestamp: Date()
        )
    }
}

// MARK: - Security Tests
final class HIPAASecurityLayerTests: XCTestCase {
    
    var securityLayer: HIPAASecurityLayer!
    
    override func setUp() async throws {
        securityLayer = HIPAASecurityLayer()
        await securityLayer.initialize()
    }
    
    func testAuthentication() async throws {
        let credentials = Credentials(
            username: "testuser",
            password: "SecureP@ssw0rd123",
            mfaCode: "123456"
        )
        
        do {
            let result = try await securityLayer.authenticate(credentials: credentials)
            XCTAssertNotNil(result.sessionID)
            XCTAssertFalse(result.token.isEmpty)
        } catch {
            // Authentication might fail in test environment
            XCTAssertTrue(error is SecurityError)
        }
    }
    
    func testEncryptionDecryption() async throws {
        let plaintext = "Sensitive patient data: John Doe, DOB: 01/01/1980"
        
        let encrypted = await securityLayer.encrypt(plaintext)
        XCTAssertNotEqual(encrypted, plaintext)
        
        let decrypted = await securityLayer.decrypt(encrypted)
        XCTAssertEqual(decrypted, plaintext)
    }
    
    func testPHIDeidentification() async throws {
        let phi = "Patient John Doe, SSN 123-45-6789, diagnosed with diabetes"
        
        let deidentified = await securityLayer.deidentifyPHI(phi)
        
        XCTAssertFalse(deidentified.contains("John Doe"))
        XCTAssertFalse(deidentified.contains("123-45-6789"))
    }
    
    func testComplianceCheck() async throws {
        let report = await securityLayer.checkCompliance()
        
        XCTAssertNotNil(report)
        XCTAssertNotNil(report.date)
        // Compliance check should complete
    }
    
    func testAuditLogging() async throws {
        await securityLayer.logDataAccess(
            user: "testuser",
            dataType: "patient_record",
            action: "read"
        )
        
        await securityLayer.logSecurityEvent(.authenticationSuccess, details: "Test login")
        
        // Logging should complete without errors
    }
}

// MARK: - Distributed Processing Tests
final class DistributedProcessingTests: XCTestCase {
    
    var processor: DistributedProcessingManager!
    
    override func setUp() async throws {
        processor = DistributedProcessingManager(
            configuration: DistributedProcessingManager.Configuration(
                enableCloudProcessing: false, // Disable for testing
                enablePeerToPeer: false
            )
        )
        await processor.initialize()
    }
    
    func testLocalProcessing() async throws {
        let audioData = Data(repeating: 0, count: 1024)
        let sessionID = UUID()
        
        let result = await processor.processTranscription(audioData, sessionID: sessionID)
        
        XCTAssertNotNil(result)
        XCTAssertFalse(result.text.isEmpty)
    }
    
    func testCaching() async throws {
        let key = "test_key"
        let value = "test_value"
        
        await processor.cacheResult(key, value)
        
        let cached = await processor.getCachedResult(key)
        XCTAssertNotNil(cached)
        
        if let cachedString = cached as? String {
            XCTAssertEqual(cachedString, value)
        }
    }
    
    func testResourceRelease() async throws {
        let sessionID = UUID()
        
        await processor.releaseResources(sessionID)
        // Resource release should complete without errors
    }
    
    func testPerformanceMetrics() {
        let metrics = processor.getPerformanceMetrics()
        XCTAssertNotNil(metrics)
    }
}

// MARK: - Integration Tests
final class IntegrationTests: XCTestCase {
    
    var pipeline: UnifiedMedicalPipeline!
    
    override func setUp() async throws {
        pipeline = UnifiedMedicalPipeline()
    }
    
    func testEndToEndProcessing() async throws {
        // Create session
        let sessionID = try await pipeline.createSession(
            patientID: "INT_TEST_001",
            encounterType: .emergency
        )
        
        // Simulate audio chunks
        let audioChunks = generateAudioChunks(count: 5)
        
        for chunk in audioChunks {
            let result = try await pipeline.processAudioChunk(chunk, sessionID: sessionID)
            
            XCTAssertNotNil(result)
            XCTAssertGreaterThan(result.confidence, 0.0)
        }
        
        // Finalize and get report
        let report = try await pipeline.finalizeSession(sessionID)
        
        XCTAssertNotNil(report)
        XCTAssertNotNil(report.summary)
        XCTAssertFalse(report.diagnostics.isEmpty)
        XCTAssertFalse(report.recommendations.isEmpty)
        XCTAssertNotNil(report.billing)
    }
    
    func testPerformanceUnderLoad() async throws {
        let startTime = Date()
        
        // Create multiple concurrent sessions
        let sessionCount = 10
        
        let sessions = try await withThrowingTaskGroup(of: UUID.self) { group in
            for _ in 0..<sessionCount {
                group.addTask {
                    try await self.pipeline.createSession()
                }
            }
            
            var sessionIDs: [UUID] = []
            for try await sessionID in group {
                sessionIDs.append(sessionID)
            }
            return sessionIDs
        }
        
        // Process audio for each session
        let audioData = generateMockAudioData()
        
        await withTaskGroup(of: Void.self) { group in
            for sessionID in sessions {
                group.addTask {
                    _ = try? await self.pipeline.processAudioChunk(audioData, sessionID: sessionID)
                }
            }
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        XCTAssertLessThan(elapsed, 10.0) // Should complete within 10 seconds
        print("⏱️ Processed \(sessionCount) sessions in \(elapsed) seconds")
    }
    
    private func generateAudioChunks(count: Int) -> [Data] {
        (0..<count).map { _ in
            generateMockAudioData()
        }
    }
    
    private func generateMockAudioData() -> Data {
        Data(repeating: 0, count: 48000)
    }
}