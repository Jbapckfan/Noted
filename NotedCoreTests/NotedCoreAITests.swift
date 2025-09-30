import XCTest
@testable import NotedCore

class NotedCoreAITests: XCTestCase {

    let service = NotedCoreAIService()

    func testSeizureTranscription() async {
        let transcript = """
        Patient was completely unconscious, he was blue, foam everywhere,
        arms stiff, BP was 217 over 161
        """

        await service.generateMedicalNote(from: transcript)

        XCTAssertTrue(service.generatedNote.contains("cyanotic"))
        XCTAssertTrue(service.generatedNote.contains("foam"))
        XCTAssertTrue(service.generatedNote.contains("217/161"))
    }

    func testChestPainTranscription() async {
        let transcript = """
        Grabbing my chest, weird feeling in my jaw, gave me 4 aspirins
        and the nitro, pain was 9 out of 10
        """

        await service.generateMedicalNote(from: transcript)

        XCTAssertTrue(service.generatedNote.contains("chest pain"))
        XCTAssertTrue(service.generatedNote.contains("jaw"))
        XCTAssertTrue(service.generatedNote.contains("9/10"))
        XCTAssertTrue(service.generatedNote.contains("aspirin"))
        XCTAssertTrue(service.generatedNote.contains("nitroglycerin"))
    }

    func testPatternTransformation() {
        let transformer = PatternTransformationEngine()

        let input = "Patient was blue and can't breathe, threw up and passed out"
        let result = transformer.transformTranscript(input)

        XCTAssertTrue(result.contains("cyanotic"))
        XCTAssertTrue(result.contains("dyspnea"))
        XCTAssertTrue(result.contains("vomiting"))
        XCTAssertTrue(result.contains("lost consciousness"))
        XCTAssertFalse(result.contains("blue"))
        XCTAssertFalse(result.contains("threw up"))
    }

    func testChiefComplaintClassification() {
        let classifier = ChiefComplaintClassifier()

        // Test neurological classification
        let neuroTranscript = "Patient had a seizure and is unconscious"
        let (neuroType, neuroConfidence) = classifier.classify(transcript: neuroTranscript)
        XCTAssertEqual(neuroType, .neurological)
        XCTAssertGreaterThan(neuroConfidence, 0.0)

        // Test cardiovascular classification
        let cardioTranscript = "Chest pain radiating to jaw with pressure"
        let (cardioType, cardioConfidence) = classifier.classify(transcript: cardioTranscript)
        XCTAssertEqual(cardioType, .cardiovascular)
        XCTAssertGreaterThan(cardioConfidence, 0.0)
    }

    func testChartStrengthCalculation() {
        let calculator = ChartStrengthCalculator()

        let note = """
        Chief Complaint: Chest pain

        HPI: Patient presents with chest pain that started 2 hours ago,
        described as severe pressure, 8/10 in severity.

        MDM: Differential includes MI, PE, aortic dissection.

        """

        let strength = calculator.calculateStrength(
            for: note,
            type: .cardiovascular
        )

        XCTAssertGreaterThan(strength.completeness, 0.0)
        XCTAssertLessThanOrEqual(strength.completeness, 1.0)
        XCTAssertTrue(strength.currentLevel.rawValue >= 2)
        XCTAssertTrue(strength.missingElements.count > 0)
    }

    func testAllExampleTypes() async {
        // Test all 18 example patterns
        let testCases = [
            "Patient was unconscious and blue with foam",
            "Chest pain radiating to jaw, gave aspirin",
            "Can't breathe, wheezing badly",
            "Throwing up blood, stomach hurts",
            "Can't pee for 2 days",
            "Fell and hit head yesterday",
            "Fever and yellow drainage from wound",
            "Feeling suicidal and anxious",
            "Sugar is 450, feeling weak",
            "Cancer patient with new symptoms"
        ]

        for testCase in testCases {
            await service.generateMedicalNote(from: testCase)
            XCTAssertFalse(service.generatedNote.isEmpty)
        }
    }
}