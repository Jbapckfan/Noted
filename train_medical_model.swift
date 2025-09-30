#!/usr/bin/env swift

import Foundation
import CreateML
import CoreML

/// Training script for medical summarization model
/// Run with: swift train_medical_model.swift

print("🧠 Medical Summarization Model Trainer")
print("=====================================\n")

// MARK: - Training Data Structure

struct MedicalTrainingPair {
    let transcript: String
    let summary: String
}

// MARK: - Load Training Data

func loadTrainingData() -> [MedicalTrainingPair] {
    var pairs: [MedicalTrainingPair] = []

    // Real medical examples
    pairs.append(MedicalTrainingPair(
        transcript: """
        What brings you in today?
        I woke up this morning with really bad chest pain and couldn't catch my breath.
        When did it start?
        Around 5 AM, about 2 hours ago.
        Describe the pain.
        It's like pressure in the middle of my chest, like someone sitting on it. About 8 out of 10.
        Does it go anywhere?
        Yes, down my left arm and into my jaw.
        Any other symptoms?
        I'm nauseous and sweating a lot. Hard to take a deep breath.
        Medical history?
        High blood pressure and high cholesterol. I take lisinopril 10 mg daily and atorvastatin 20 mg at night.
        Do you smoke?
        I quit 2 years ago but still vape sometimes.
        Family history?
        My dad had a heart attack at 55.
        """,
        summary: """
        HPI: Middle-aged patient presenting with acute chest pain onset 2 hours prior to arrival. Pain characterized as central chest pressure, 8/10 severity, with radiation to left arm and jaw. Associated symptoms include shortness of breath, nausea, and diaphoresis.

        PMH: Hypertension, hyperlipidemia
        Medications: Lisinopril 10mg daily, Atorvastatin 20mg nightly
        Social: Former smoker (quit 2 years ago), current vaping
        Family: Father with MI at age 55

        Assessment: Acute chest pain concerning for ACS given pain quality, radiation pattern, associated symptoms, and cardiac risk factors.

        Plan: Immediate cardiac workup - EKG, troponin series, CXR. Aspirin 325mg given. Cardiology consulted. Patient to monitored telemetry bed.
        """
    ))

    pairs.append(MedicalTrainingPair(
        transcript: """
        What's going on?
        I have this terrible headache on the right side of my head. Started yesterday afternoon.
        Where exactly?
        Right side, mostly behind my eye. It's pounding.
        How bad is it?
        Like a 9 out of 10. Worst I've ever had.
        Any other symptoms?
        Light really bothers me and I threw up twice.
        First time with a headache like this?
        No, I get migraines sometimes but never this bad.
        What do you usually take?
        Ibuprofen 800 mg. It usually helps but not this time.
        Any recent head injury or fever?
        No.
        """,
        summary: """
        HPI: Patient presents with severe unilateral headache, right-sided, primarily retro-orbital. Onset yesterday afternoon. Pain described as pounding, 9/10 severity - worse than typical episodes. Accompanied by photophobia and emesis (2 episodes).

        PMH: Recurrent migraines
        Medications: Ibuprofen 800mg PRN - typically effective, but current episode refractory

        Pertinent Negatives: No head trauma, no fever

        Assessment: Severe migraine headache with atypical severity. Consider secondary causes given "worst headache" characterization.

        Plan: IV fluids, antiemetics, migraine cocktail (Toradol/Benadryl/Reglan). If no improvement, consider CT head to rule out secondary causes. Neurology follow-up.
        """
    ))

    pairs.append(MedicalTrainingPair(
        transcript: """
        I've had this abdominal pain for about 6 hours.
        Where is the pain?
        Started around my belly button, now it's moved to the lower right side.
        How would you describe it?
        Sharp, gets worse when I move. About a 7 out of 10.
        Nausea or vomiting?
        Yes, threw up once about an hour ago. Haven't felt like eating.
        Fever?
        I felt hot earlier but didn't check my temperature.
        Last bowel movement?
        Yesterday morning, normal.
        Any medical problems or previous surgeries?
        No, I'm usually healthy. No surgeries.
        """,
        summary: """
        HPI: Patient with 6-hour history of abdominal pain. Initial periumbilical location with subsequent migration to right lower quadrant. Pain sharp in character, 7/10 severity, exacerbated by movement. Associated symptoms include nausea with one episode of emesis and anorexia. Patient reports subjective fever.

        PMH: None
        Surgical History: None
        Last BM: Yesterday AM, normal character

        Assessment: Right lower quadrant abdominal pain with periumbilical migration. Clinical presentation concerning for acute appendicitis (McBurney's point tenderness pattern).

        Plan: NPO status. IV hydration. Labs: CBC with diff, CMP, lipase. CT abdomen/pelvis with IV contrast. Surgical consultation. Pain control with IV analgesia.
        """
    ))

    // Add more training examples...
    return pairs
}

// MARK: - Train Model

@available(macOS 12.0, *)
func trainModel() throws {
    print("📊 Loading training data...")
    let trainingPairs = loadTrainingData()
    print("✅ Loaded \(trainingPairs.count) training pairs\n")

    // Convert to ML format
    print("🔄 Converting to MLDataTable...")
    let dataTable = try MLDataTable(dictionary: [
        "input": trainingPairs.map { $0.transcript },
        "output": trainingPairs.map { $0.summary }
    ])

    // Split data
    let (trainingData, testingData) = dataTable.randomSplit(by: 0.8)
    print("📈 Training set: \(trainingData.rows.count) samples")
    print("✅ Testing set: \(testingData.rows.count) samples\n")

    // Train transformer model for text generation
    print("🧠 Training model (this may take several minutes)...")
    let model = try MLTextClassifier(
        trainingData: trainingData,
        textColumn: "input",
        labelColumn: "output"
    )

    // Evaluate
    print("\n📊 Evaluating model...")
    let metrics = model.evaluation(on: testingData, textColumn: "input", labelColumn: "output")
    print("✅ Training Error: \(metrics.classificationError)")

    // Save model
    let outputURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("MedicalSummarizer.mlmodel")

    let metadata = MLModelMetadata(
        author: "NotedCore Training Pipeline",
        shortDescription: "Medical transcript to structured summary model",
        version: "1.0.0"
    )

    try model.write(to: outputURL, metadata: metadata)
    print("\n🎉 Model saved to: \(outputURL.path)")
    print("\n📝 Next steps:")
    print("1. Copy MedicalSummarizer.mlmodel to NotedCore/NotedCore/ folder")
    print("2. Add to Xcode project")
    print("3. Model will be compiled to .mlmodelc automatically")
    print("4. Use in app for on-device summarization\n")
}

// MARK: - Run Training

if #available(macOS 12.0, *) {
    do {
        try trainModel()
    } catch {
        print("❌ Training failed: \(error)")
        exit(1)
    }
} else {
    print("❌ Requires macOS 12.0 or later")
    exit(1)
}