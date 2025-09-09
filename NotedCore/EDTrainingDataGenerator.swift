import Foundation

// Generate synthetic training data for ED Smart-Summary
@MainActor
class EDTrainingDataGenerator {
    static let shared = EDTrainingDataGenerator()
    
    // MARK: - Training Templates
    private let chiefComplaints = [
        "chest pain", "abdominal pain", "headache", "back pain",
        "shortness of breath", "dizziness", "nausea and vomiting",
        "fever", "weakness", "altered mental status", "syncope",
        "seizure", "trauma", "laceration", "burn"
    ]
    
    private let onsetVariations = [
        "started {time} ago",
        "began {time} ago",
        "noticed it {time} ago",
        "has been going on for {time}",
        "woke up with it {time}"
    ]
    
    private let timeFrames = [
        "30 minutes", "1 hour", "2 hours", "3 hours", "6 hours",
        "this morning", "last night", "yesterday", "2 days",
        "3 days", "a week"
    ]
    
    private let severities = [
        "mild", "moderate", "severe", "10 out of 10",
        "worst pain of my life", "tolerable", "unbearable"
    ]
    
    private let associatedSymptoms = [
        "nausea", "vomiting", "dizziness", "sweating",
        "shortness of breath", "weakness", "numbness",
        "tingling", "fever", "chills"
    ]
    
    // MARK: - Generate Training Samples
    func generateTrainingSample(count: Int = 100) -> [TrainingSample] {
        var samples: [TrainingSample] = []
        
        for _ in 0..<count {
            let cc = chiefComplaints.randomElement()!
            let onset = generateOnset()
            let severity = severities.randomElement()!
            let associated = generateAssociatedSymptoms()
            
            let transcript = generateTranscript(
                chiefComplaint: cc,
                onset: onset,
                severity: severity,
                associatedSymptoms: associated
            )
            
            let expectedOutput = generateExpectedOutput(
                chiefComplaint: cc,
                onset: onset,
                severity: severity,
                associatedSymptoms: associated
            )
            
            samples.append(TrainingSample(
                transcript: transcript,
                expectedJSON: expectedOutput,
                phase: .initial
            ))
        }
        
        return samples
    }
    
    private func generateOnset() -> String {
        let template = onsetVariations.randomElement()!
        let time = timeFrames.randomElement()!
        return template.replacingOccurrences(of: "{time}", with: time)
    }
    
    private func generateAssociatedSymptoms() -> [String] {
        let count = Int.random(in: 0...3)
        var selected: Set<String> = []
        
        for _ in 0..<count {
            if let symptom = associatedSymptoms.randomElement() {
                selected.insert(symptom)
            }
        }
        
        return Array(selected)
    }
    
    private func generateTranscript(
        chiefComplaint: String,
        onset: String,
        severity: String,
        associatedSymptoms: [String]
    ) -> String {
        var transcript = """
        Physician: What brings you in today?
        Patient: I have \(chiefComplaint). It \(onset).
        """
        
        if Bool.random() {
            transcript += "\nPhysician: How severe is the pain?"
            transcript += "\nPatient: It's \(severity)."
        }
        
        if !associatedSymptoms.isEmpty {
            transcript += "\nPhysician: Any other symptoms?"
            transcript += "\nPatient: Yes, I also have \(associatedSymptoms.joined(separator: " and "))."
        }
        
        return transcript
    }
    
    private func generateExpectedOutput(
        chiefComplaint: String,
        onset: String,
        severity: String,
        associatedSymptoms: [String]
    ) -> [String: Any] {
        var json: [String: Any] = [
            "Phase": "Initial",
            "ChiefComplaint": chiefComplaint.capitalized
        ]
        
        var hpi = "\(onset), \(severity) severity"
        if !associatedSymptoms.isEmpty {
            hpi += ", associated with \(associatedSymptoms.joined(separator: ", "))"
        }
        json["HPI"] = hpi
        
        if !associatedSymptoms.isEmpty {
            var ros: [String: [String]] = [:]
            
            for symptom in associatedSymptoms {
                let system = mapSymptomToSystem(symptom)
                if ros[system] == nil {
                    ros[system] = []
                }
                ros[system]?.append(symptom)
            }
            
            json["ROS"] = ros
        }
        
        return json
    }
    
    private func mapSymptomToSystem(_ symptom: String) -> String {
        switch symptom.lowercased() {
        case "nausea", "vomiting", "diarrhea":
            return "GI"
        case "shortness of breath", "cough":
            return "Respiratory"
        case "chest pain", "palpitations":
            return "Cardiovascular"
        case "headache", "dizziness", "weakness", "numbness", "tingling":
            return "Neurological"
        case "fever", "chills":
            return "Constitutional"
        default:
            return "General"
        }
    }
    
    // MARK: - Validation
    func validateExtraction(
        generated: [String: Any],
        expected: [String: Any]
    ) -> ValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        var score = 0.0
        var maxScore = 0.0
        
        // Check required fields
        let requiredFields = ["Phase", "ChiefComplaint"]
        for field in requiredFields {
            maxScore += 1.0
            if generated[field] != nil {
                score += 1.0
            } else {
                errors.append("Missing required field: \(field)")
            }
        }
        
        // Check HPI
        maxScore += 2.0
        if let genHPI = generated["HPI"] as? String,
           let expHPI = expected["HPI"] as? String {
            let similarity = calculateSimilarity(genHPI, expHPI)
            score += similarity * 2.0
            
            if similarity < 0.7 {
                warnings.append("HPI similarity low: \(Int(similarity * 100))%")
            }
        }
        
        // Check ROS
        if let expROS = expected["ROS"] as? [String: [String]] {
            maxScore += Double(expROS.count)
            if let genROS = generated["ROS"] as? [String: [String]] {
                for (system, symptoms) in expROS {
                    if let genSymptoms = genROS[system] {
                        let matchRatio = calculateArraySimilarity(genSymptoms, symptoms)
                        score += matchRatio
                        
                        if matchRatio < 1.0 {
                            warnings.append("ROS \(system) incomplete match")
                        }
                    } else {
                        warnings.append("Missing ROS system: \(system)")
                    }
                }
            } else {
                errors.append("Missing ROS when expected")
            }
        }
        
        let accuracy = maxScore > 0 ? score / maxScore : 0.0
        
        return ValidationResult(
            accuracy: accuracy,
            errors: errors,
            warnings: warnings,
            score: score,
            maxScore: maxScore
        )
    }
    
    private func calculateSimilarity(_ str1: String, _ str2: String) -> Double {
        let words1 = Set(str1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(str2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateArraySimilarity(_ arr1: [String], _ arr2: [String]) -> Double {
        let set1 = Set(arr1.map { $0.lowercased() })
        let set2 = Set(arr2.map { $0.lowercased() })
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
}

// MARK: - Supporting Types
struct TrainingSample {
    let transcript: String
    let expectedJSON: [String: Any]
    let phase: EncounterPhase
}

struct ValidationResult {
    let accuracy: Double
    let errors: [String]
    let warnings: [String]
    let score: Double
    let maxScore: Double
    
    var isValid: Bool {
        return errors.isEmpty && accuracy >= 0.8
    }
    
    var summary: String {
        return """
        Accuracy: \(Int(accuracy * 100))%
        Score: \(score)/\(maxScore)
        Errors: \(errors.count)
        Warnings: \(warnings.count)
        Status: \(isValid ? "✅ Valid" : "❌ Invalid")
        """
    }
}

// MARK: - Performance Benchmarking
@MainActor
class EDPerformanceBenchmark {
    @MainActor
    static func benchmark(
        service: MedicalSummarizerService,
        samples: [TrainingSample]
    ) async -> BenchmarkResult {
        var totalTime: TimeInterval = 0
        var accuracies: [Double] = []
        var errors: [String] = []
        
        for sample in samples {
            let start = Date()
            
            await service.generateMedicalNote(
                from: sample.transcript,
                noteType: .edNote,
                customInstructions: "",
                encounterID: "Test-\(UUID().uuidString)",
                phase: sample.phase
            )
            
            let elapsed = Date().timeIntervalSince(start)
            totalTime += elapsed
            
            // Parse generated JSON
            if let data = service.generatedNote.data(using: .utf8),
               let generated = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let validation = EDTrainingDataGenerator.shared.validateExtraction(
                    generated: generated,
                    expected: sample.expectedJSON
                )
                
                accuracies.append(validation.accuracy)
                errors.append(contentsOf: validation.errors)
            } else {
                errors.append("Failed to parse JSON output")
                accuracies.append(0.0)
            }
        }
        
        let avgAccuracy = accuracies.reduce(0, +) / Double(accuracies.count)
        let avgTime = totalTime / Double(samples.count)
        
        return BenchmarkResult(
            averageAccuracy: avgAccuracy,
            averageTime: avgTime,
            totalSamples: samples.count,
            errors: errors
        )
    }
}

struct BenchmarkResult {
    let averageAccuracy: Double
    let averageTime: TimeInterval
    let totalSamples: Int
    let errors: [String]
    
    var summary: String {
        return """
        === Benchmark Results ===
        Samples: \(totalSamples)
        Average Accuracy: \(Int(averageAccuracy * 100))%
        Average Time: \(String(format: "%.3f", averageTime))s
        Errors: \(errors.count)
        Performance: \(averageTime < 0.5 ? "✅ Fast" : "⚠️ Slow")
        """
    }
}