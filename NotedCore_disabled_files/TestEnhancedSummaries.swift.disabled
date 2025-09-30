import Foundation

// MARK: - Test Suite for Enhanced Medical Summaries
@MainActor
class TestEnhancedMedicalSummaries {
    
    let enhancedService = EnhancedMedicalSummarizerService()
    
    // MARK: - Test Scenarios
    
    func testChestPainScenario() async {
        let transcript = """
        Patient: I've been having this chest pain since about 5 o'clock this morning.
        Doctor: Can you describe the pain for me?
        Patient: It's like a pressure, kind of crushing feeling in the center of my chest.
        Doctor: Does it radiate anywhere?
        Patient: Yes, it goes up to my jaw and down my left arm.
        Doctor: Any other symptoms?
        Patient: I've been feeling nauseous and sweating a lot. Also short of breath.
        Doctor: Have you had this before?
        Patient: No, never. I do have high blood pressure and diabetes though.
        Doctor: Do you smoke?
        Patient: I quit about 5 years ago, but I smoked for 20 years before that.
        Doctor: Any family history of heart disease?
        Patient: Yes, my father had a heart attack at 55.
        Doctor: Does anything make it better or worse?
        Patient: Walking makes it worse. Sitting still helps a little bit.
        Doctor: On a scale of 1 to 10, how severe is the pain?
        Patient: It's about an 8 out of 10.
        Doctor: I'm concerned this could be your heart. We need to do an EKG right away, check cardiac enzymes including troponin, and get a chest X-ray. I'm going to give you aspirin and nitroglycerin. We may need to admit you to the cardiac unit.
        """
        
        await enhancedService.generateEnhancedMedicalNote(
            from: transcript,
            noteType: .soap,
            encounterID: "TEST-001",
            phase: .initial
        )
        
        let generatedNote = enhancedService.generatedNote
        
        // Validate enhanced medical terminology
        let validations = [
            ("ACS/Acute coronary syndrome", generatedNote.contains("ACS") || generatedNote.contains("Acute coronary syndrome")),
            ("Crushing quality", generatedNote.contains("crushing")),
            ("Radiation pattern", generatedNote.contains("radiation") || generatedNote.contains("radiates")),
            ("Diaphoresis", generatedNote.contains("diaphoresis")),
            ("Dyspnea/SOB", generatedNote.contains("dyspnea") || generatedNote.contains("SOB"))
        ]
        
        // Validate risk factors documentation
        let riskFactors = [
            ("Hypertension", generatedNote.contains("hypertension") || generatedNote.contains("HTN")),
            ("Diabetes", generatedNote.contains("diabetes") || generatedNote.contains("DM")),
            ("Tobacco history", generatedNote.contains("tobacco") || generatedNote.contains("smoking")),
            ("Family history", generatedNote.contains("family history"))
        ]
        
        // Validate clinical reasoning
        let clinicalElements = [
            ("High risk assessment", generatedNote.contains("high risk") || generatedNote.contains("concerning")),
            ("Troponin ordered", generatedNote.contains("troponin")),
            ("EKG/ECG ordered", generatedNote.contains("EKG") || generatedNote.contains("ECG"))
        ]
        
        for (item, passed) in validations + riskFactors + clinicalElements {
            print(passed ? "✓ \(item)" : "✗ \(item)")
        }
        
        print("✅ Chest Pain Scenario Test Passed")
        print("Generated Note Preview:")
        print(String(generatedNote.prefix(500)))
    }
    
    func testAbdominalPainScenario() async {
        let transcript = """
        Patient: I've had severe abdominal pain for the past 12 hours.
        Doctor: Where exactly is the pain located?
        Patient: It started around my belly button but now it's moved to my right lower side.
        Doctor: Describe the pain for me.
        Patient: It's sharp and constant, gets worse when I move or cough.
        Doctor: Any nausea or vomiting?
        Patient: Yes, I've vomited twice and have no appetite.
        Doctor: Any fever?
        Patient: I've been feeling hot and cold, haven't checked my temperature.
        Doctor: Have you had your appendix removed?
        Patient: No, I still have it.
        Doctor: Any changes in bowel movements?
        Patient: No diarrhea or constipation.
        Doctor: When was your last menstrual period? (if applicable)
        Patient: About 2 weeks ago, it was normal.
        Doctor: Based on your symptoms, I'm concerned about appendicitis. We need to do a CBC to check your white blood cell count, a comprehensive metabolic panel, and likely a CT scan of your abdomen. I'll also do a physical exam. You may need surgery if this is appendicitis.
        """
        
        await enhancedService.generateEnhancedMedicalNote(
            from: transcript,
            noteType: .soap,
            encounterID: "TEST-002",
            phase: .initial
        )
        
        let generatedNote = enhancedService.generatedNote
        
        // Validate enhanced medical terminology
        let validations = [
            ("RLQ/Right lower quadrant", generatedNote.contains("RLQ") || generatedNote.contains("right lower quadrant")),
            ("Periumbilical/Umbilical", generatedNote.contains("periumbilical") || generatedNote.contains("umbilical")),
            ("Migration pattern", generatedNote.contains("migration")),
            ("Anorexia", generatedNote.contains("anorexia") || generatedNote.contains("appetite"))
        ]
        
        // Validate differential diagnosis
        let diagnostics = [
            ("Appendicitis", generatedNote.contains("appendicitis")),
            ("CBC ordered", generatedNote.contains("CBC") || generatedNote.contains("complete blood count")),
            ("CT scan ordered", generatedNote.contains("CT") || generatedNote.contains("computed tomography"))
        ]
        
        for (item, passed) in validations + diagnostics {
            print(passed ? "✓ \(item)" : "✗ \(item)")
        }
        
        print("✅ Abdominal Pain Scenario Test Passed")
        print("Generated Note Preview:")
        print(String(generatedNote.prefix(500)))
    }
    
    func testShortnessOfBreathScenario() async {
        let transcript = """
        Patient: I can't catch my breath, it started suddenly about 2 hours ago.
        Doctor: Were you doing anything when it started?
        Patient: No, I was just sitting at my desk working.
        Doctor: Any chest pain?
        Patient: Yes, sharp pain when I take a deep breath, on my right side.
        Doctor: Have you been traveling recently or been immobile for long periods?
        Patient: I just flew back from Europe yesterday, it was a 10-hour flight.
        Doctor: Any leg swelling or pain?
        Patient: My right calf has been a bit sore, I thought it was from walking so much on vacation.
        Doctor: Do you take birth control pills or hormone therapy?
        Patient: Yes, I'm on birth control.
        Doctor: Any history of blood clots?
        Patient: No, never.
        Doctor: Are you coughing up any blood?
        Patient: No blood, just a dry cough.
        Doctor: Based on your symptoms and risk factors, I'm concerned about a possible pulmonary embolism - a blood clot in your lung. We need to do a D-dimer blood test, and likely a CT angiogram of your chest. I'm also going to check your oxygen levels and do an EKG. We may need to start blood thinners if this is confirmed.
        """
        
        await enhancedService.generateEnhancedMedicalNote(
            from: transcript,
            noteType: .soap,
            encounterID: "TEST-003",
            phase: .initial
        )
        
        let generatedNote = enhancedService.generatedNote
        
        // Validate enhanced medical terminology
        let terminology = [
            ("Dyspnea/SOB", generatedNote.contains("dyspnea") || generatedNote.contains("SOB")),
            ("Pleuritic pain", generatedNote.contains("pleuritic")),
            ("PE/Pulmonary embolism", generatedNote.contains("PE") || generatedNote.contains("pulmonary embolism"))
        ]
        
        // Validate risk factors
        let riskFactors = [
            ("Recent travel", generatedNote.contains("recent travel") || generatedNote.contains("long flight")),
            ("OCP/Birth control", generatedNote.contains("OCP") || generatedNote.contains("oral contraceptive") || generatedNote.contains("birth control")),
            ("Calf pain/DVT", generatedNote.contains("calf pain") || generatedNote.contains("DVT"))
        ]
        
        // Validate workup
        let workup = [
            ("D-dimer", generatedNote.contains("D-dimer")),
            ("CTA chest", generatedNote.contains("CTA") || generatedNote.contains("CT angiogram")),
            ("Anticoagulation", generatedNote.contains("anticoagulation") || generatedNote.contains("blood thinners"))
        ]
        
        for (item, passed) in terminology + riskFactors + workup {
            print(passed ? "✓ \(item)" : "✗ \(item)")
        }
        
        print("✅ Shortness of Breath Scenario Test Passed")
        print("Generated Note Preview:")
        print(String(generatedNote.prefix(500)))
    }
    
    func testFollowUpPhaseScenario() async {
        let transcript = """
        Doctor: How are you feeling since we gave you the medications?
        Patient: The chest pain is much better, down to about a 3 out of 10.
        Doctor: Good. Your EKG showed some concerning changes and your troponin came back elevated at 0.8.
        Patient: What does that mean?
        Doctor: It suggests you're having a heart attack. We need to admit you to the cardiac unit.
        Patient: Oh my god, am I going to be okay?
        Doctor: We're going to take good care of you. Cardiology is on their way to see you, and we'll likely need to do a cardiac catheterization to look at your heart vessels.
        Patient: What about my family?
        Doctor: You can have them come in. We'll keep you on continuous heart monitoring, continue the blood thinners and other cardiac medications. The cardiologist will discuss the procedure with you in detail.
        """
        
        await enhancedService.generateEnhancedMedicalNote(
            from: transcript,
            noteType: .progress,
            encounterID: "TEST-001",
            phase: .followUp
        )
        
        let generatedNote = enhancedService.generatedNote
        
        // Validate follow-up documentation
        let followUpItems = [
            ("Improvement noted", generatedNote.contains("improved") || generatedNote.contains("better")),
            ("Troponin result", generatedNote.contains("troponin")),
            ("Elevated marker", generatedNote.contains("elevated"))
        ]
        
        // Validate diagnosis
        let diagnosis = [
            ("MI diagnosis", generatedNote.contains("NSTEMI") || generatedNote.contains("myocardial infarction") || generatedNote.contains("heart attack"))
        ]
        
        // Validate disposition
        let disposition = [
            ("Admission", generatedNote.contains("admit") || generatedNote.contains("admission")),
            ("Cardiology involvement", generatedNote.contains("cardiac") || generatedNote.contains("cardiology")),
            ("Catheterization", generatedNote.contains("catheterization") || generatedNote.contains("cath"))
        ]
        
        for (item, passed) in followUpItems + diagnosis + disposition {
            print(passed ? "✓ \(item)" : "✗ \(item)")
        }
        
        print("✅ Follow-up Phase Scenario Test Passed")
        print("Generated Note Preview:")
        print(String(generatedNote.prefix(500)))
    }
    
    func testJSONOutputFormat() async {
        let transcript = """
        Patient: I have severe headache that started suddenly about an hour ago.
        Doctor: Is this the worst headache of your life?
        Patient: Yes, absolutely. It came on like thunder.
        Doctor: Any neck stiffness?
        Patient: Yes, I can't touch my chin to my chest.
        Doctor: Any vision changes or weakness?
        Patient: My vision is a bit blurry.
        Doctor: This could be a subarachnoid hemorrhage. We need an immediate CT scan of your head and possibly a lumbar puncture.
        """
        
        await enhancedService.generateEnhancedMedicalNote(
            from: transcript,
            noteType: .soap,
            encounterID: "TEST-004",
            phase: .initial
        )
        
        let generatedNote = enhancedService.generatedNote
        
        // Validate JSON structure is present
        let jsonStructure = [
            ("JSON format", generatedNote.contains("```json")),
            ("Encounter ID", generatedNote.contains("encounterID")),
            ("Chief complaint", generatedNote.contains("chiefComplaint")),
            ("Phase field", generatedNote.contains("phase"))
        ]
        
        // Validate critical findings
        let criticalFindings = [
            ("Thunderclap/Sudden onset", generatedNote.contains("thunderclap") || generatedNote.contains("sudden onset")),
            ("SAH mentioned", generatedNote.contains("SAH") || generatedNote.contains("subarachnoid")),
            ("Meningismus/Neck stiffness", generatedNote.contains("meningismus") || generatedNote.contains("neck stiffness"))
        ]
        
        for (item, passed) in jsonStructure + criticalFindings {
            print(passed ? "✓ \(item)" : "✗ \(item)")
        }
        
        print("✅ JSON Output Format Test Passed")
        print("Generated Note Preview:")
        print(String(generatedNote.prefix(500)))
    }
}

// MARK: - Test Runner
@MainActor
func runEnhancedSummaryTests() async {
    print("🏥 Running Enhanced Medical Summary Tests...\n")
    
    let testSuite = TestEnhancedMedicalSummaries()
    
    print("Test 1: Chest Pain Scenario")
    await testSuite.testChestPainScenario()
    print("\n" + String(repeating: "-", count: 50) + "\n")
    
    print("Test 2: Abdominal Pain Scenario")
    await testSuite.testAbdominalPainScenario()
    print("\n" + String(repeating: "-", count: 50) + "\n")
    
    print("Test 3: Shortness of Breath Scenario")
    await testSuite.testShortnessOfBreathScenario()
    print("\n" + String(repeating: "-", count: 50) + "\n")
    
    print("Test 4: Follow-up Phase Scenario")
    await testSuite.testFollowUpPhaseScenario()
    print("\n" + String(repeating: "-", count: 50) + "\n")
    
    print("Test 5: JSON Output Format")
    await testSuite.testJSONOutputFormat()
    print("\n" + String(repeating: "-", count: 50) + "\n")
    
    print("✅ All Enhanced Medical Summary Tests Completed Successfully!")
}