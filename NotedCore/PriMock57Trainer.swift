import Foundation
import AVFoundation
import NaturalLanguage

/// PriMock57 Dataset Integration for Medical Dialogue Training
/// Dataset: https://github.com/babylonhealth/primock57
/// Contains 57 mock primary care consultations with audio, transcripts, and clinical notes
@MainActor
class PriMock57Trainer: ObservableObject {
    
    // MARK: - Dataset Structure
    struct PriMock57Sample {
        let id: String
        let audioPath: String?
        let transcript: ConsultationTranscript
        let clinicalNote: String
        let metadata: ConsultationMetadata
        let humanEvaluation: HumanEvaluation?
    }
    
    struct ConsultationTranscript {
        let utterances: [Utterance]
        let duration: TimeInterval
        let speakerTurns: Int
        
        var fullText: String {
            utterances.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        }
    }
    
    struct Utterance {
        let speaker: Speaker
        let text: String
        let timestamp: TimeInterval
        let confidence: Float?
    }
    
    enum Speaker: Equatable {
        case clinician
        case patient
        case nurse
        case other(String)
        
        var label: String {
            switch self {
            case .clinician: return "Physician"
            case .patient: return "Patient"
            case .nurse: return "Nurse"
            case .other(let name): return name
            }
        }
    }
    
    struct ConsultationMetadata {
        let consultationType: ConsultationType
        let chiefComplaint: String
        let duration: TimeInterval
        let complexity: ComplexityLevel
        let conditionCategory: [ConditionCategory]
        let hasPhysicalExam: Bool
        let hasPrescription: Bool
        let hasReferral: Bool
    }
    
    enum ConsultationType {
        case initialConsult
        case followUp
        case urgent
        case routine
        case telehealth
    }
    
    enum ComplexityLevel: Int {
        case simple = 1
        case moderate = 2
        case complex = 3
        case veryComplex = 4
    }
    
    enum ConditionCategory: String, CaseIterable {
        case respiratory = "Respiratory"
        case cardiovascular = "Cardiovascular"
        case gastrointestinal = "Gastrointestinal"
        case musculoskeletal = "Musculoskeletal"
        case neurological = "Neurological"
        case dermatological = "Dermatological"
        case endocrine = "Endocrine"
        case psychiatric = "Psychiatric"
        case genitourinary = "Genitourinary"
        case infectious = "Infectious"
        case preventive = "Preventive Care"
        case other = "Other"
    }
    
    struct HumanEvaluation {
        let noteQuality: Float // 1-5 scale
        let transcriptAccuracy: Float // 0-100%
        let clinicalCompleteness: Float // 0-100%
        let diagnosticAccuracy: Float // 0-100%
        let communicationQuality: Float // 1-5 scale
        let evaluatorNotes: String?
    }
    
    // MARK: - Data Loading
    
    func loadPriMock57Dataset(path: String = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/primock57") async throws -> [PriMock57Sample] {
        var samples: [PriMock57Sample] = []
        
        // Load all 57 consultations
        for i in 1...57 {
            let sampleId = String(format: "primock_%03d", i)
            
            // Load transcript
            let transcript = try await loadTranscript(id: sampleId, path: path)
            
            // Load clinical note
            let clinicalNote = try await loadClinicalNote(id: sampleId, path: path)
            
            // Load human evaluation if available
            let humanEval = try? await loadHumanEvaluation(id: sampleId, path: path)
            
            // Extract metadata
            let metadata = extractMetadata(from: transcript, note: clinicalNote)
            
            let sample = PriMock57Sample(
                id: sampleId,
                audioPath: "\(path)/audio/\(sampleId).wav",
                transcript: transcript,
                clinicalNote: clinicalNote,
                metadata: metadata,
                humanEvaluation: humanEval
            )
            
            samples.append(sample)
        }
        
        return samples
    }
    
    private func loadTranscript(id: String, path: String) async throws -> ConsultationTranscript {
        let transcriptPath = "\(path)/transcripts/\(id).txt"
        guard let url = URL(string: transcriptPath) else {
            throw DataLoadError.invalidPath(transcriptPath)
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseTranscript(content)
    }
    
    private func parseTranscript(_ content: String) -> ConsultationTranscript {
        var utterances: [Utterance] = []
        let lines = content.components(separatedBy: .newlines)
        var currentTime: TimeInterval = 0
        
        for line in lines {
            // Parse format: "[timestamp] Speaker: text"
            // Or simple format: "Speaker: text"
            if line.contains(":") {
                let parts = line.split(separator: ":", maxSplits: 1)
                if parts.count == 2 {
                    let speakerPart = String(parts[0]).trimmingCharacters(in: .whitespaces)
                    let text = String(parts[1]).trimmingCharacters(in: .whitespaces)
                    
                    // Extract timestamp if present
                    var speaker = speakerPart
                    if speakerPart.hasPrefix("[") {
                        let timestampEnd = speakerPart.firstIndex(of: "]") ?? speakerPart.endIndex
                        let timestampStr = speakerPart[speakerPart.index(after: speakerPart.startIndex)..<timestampEnd]
                        currentTime = TimeInterval(timestampStr) ?? currentTime
                        speaker = String(speakerPart[speakerPart.index(after: timestampEnd)...]).trimmingCharacters(in: .whitespaces)
                    }
                    
                    let speakerType = parseSpeaker(speaker)
                    let utterance = Utterance(
                        speaker: speakerType,
                        text: text,
                        timestamp: currentTime,
                        confidence: nil
                    )
                    utterances.append(utterance)
                    currentTime += 2.0 // Approximate time per utterance
                }
            }
        }
        
        let speakerTurns = utterances.enumerated().reduce(0) { count, element in
            let (index, utterance) = element
            if index == 0 { return 1 }
            return utterances[index - 1].speaker != utterance.speaker ? count + 1 : count
        }
        
        return ConsultationTranscript(
            utterances: utterances,
            duration: currentTime,
            speakerTurns: speakerTurns
        )
    }
    
    private func parseSpeaker(_ text: String) -> Speaker {
        let normalized = text.lowercased()
        if normalized.contains("doctor") || normalized.contains("physician") || normalized.contains("dr") {
            return .clinician
        } else if normalized.contains("patient") || normalized.contains("pt") {
            return .patient
        } else if normalized.contains("nurse") || normalized.contains("rn") {
            return .nurse
        } else {
            return .other(text)
        }
    }
    
    private func loadClinicalNote(id: String, path: String) async throws -> String {
        let notePath = "\(path)/notes/\(id).txt"
        guard let url = URL(string: notePath) else {
            throw DataLoadError.invalidPath(notePath)
        }
        
        return try String(contentsOf: url, encoding: .utf8)
    }
    
    private func loadHumanEvaluation(id: String, path: String) async throws -> HumanEvaluation {
        let evalPath = "\(path)/human_eval_data/\(id).json"
        guard let url = URL(string: evalPath) else {
            throw DataLoadError.invalidPath(evalPath)
        }
        
        let data = try Data(contentsOf: url)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        return HumanEvaluation(
            noteQuality: json["note_quality"] as? Float ?? 0,
            transcriptAccuracy: json["transcript_accuracy"] as? Float ?? 0,
            clinicalCompleteness: json["clinical_completeness"] as? Float ?? 0,
            diagnosticAccuracy: json["diagnostic_accuracy"] as? Float ?? 0,
            communicationQuality: json["communication_quality"] as? Float ?? 0,
            evaluatorNotes: json["notes"] as? String
        )
    }
    
    // MARK: - Metadata Extraction
    
    private func extractMetadata(from transcript: ConsultationTranscript, note: String) -> ConsultationMetadata {
        // Extract chief complaint from first patient utterance
        let chiefComplaint = transcript.utterances
            .first(where: { $0.speaker == .patient })?
            .text ?? "Not specified"
        
        // Determine complexity based on various factors
        let complexity = calculateComplexity(transcript: transcript, note: note)
        
        // Categorize conditions
        let conditions = categorizeConditions(from: note)
        
        // Check for specific elements
        let hasPhysicalExam = note.lowercased().contains("physical exam") || 
                              note.lowercased().contains("examination")
        let hasPrescription = note.lowercased().contains("prescrib") || 
                             note.lowercased().contains("medication")
        let hasReferral = note.lowercased().contains("refer") || 
                         note.lowercased().contains("specialist")
        
        return ConsultationMetadata(
            consultationType: determineConsultationType(from: transcript),
            chiefComplaint: chiefComplaint,
            duration: transcript.duration,
            complexity: complexity,
            conditionCategory: conditions,
            hasPhysicalExam: hasPhysicalExam,
            hasPrescription: hasPrescription,
            hasReferral: hasReferral
        )
    }
    
    private func calculateComplexity(transcript: ConsultationTranscript, note: String) -> ComplexityLevel {
        var score = 0
        
        // Length factors
        if transcript.utterances.count > 50 { score += 1 }
        if note.count > 2000 { score += 1 }
        
        // Medical complexity indicators
        let complexTerms = ["differential", "rule out", "consider", "multiple", "chronic", "complicated"]
        for term in complexTerms {
            if note.lowercased().contains(term) { score += 1; break }
        }
        
        // Multiple conditions
        if note.components(separatedBy: "diagnosis").count > 2 { score += 1 }
        
        switch score {
        case 0...1: return .simple
        case 2: return .moderate
        case 3: return .complex
        default: return .veryComplex
        }
    }
    
    private func determineConsultationType(from transcript: ConsultationTranscript) -> ConsultationType {
        let text = transcript.fullText.lowercased()
        
        if text.contains("follow up") || text.contains("follow-up") {
            return .followUp
        } else if text.contains("urgent") || text.contains("emergency") {
            return .urgent
        } else if text.contains("routine") || text.contains("check-up") {
            return .routine
        } else if text.contains("video") || text.contains("phone") {
            return .telehealth
        } else {
            return .initialConsult
        }
    }
    
    private func categorizeConditions(from note: String) -> [ConditionCategory] {
        var categories: [ConditionCategory] = []
        let text = note.lowercased()
        
        let categoryKeywords: [ConditionCategory: [String]] = [
            .respiratory: ["cough", "breath", "asthma", "pneumonia", "bronch"],
            .cardiovascular: ["heart", "chest pain", "hypertension", "cardiac"],
            .gastrointestinal: ["abdominal", "stomach", "nausea", "diarrhea", "constipation"],
            .musculoskeletal: ["joint", "muscle", "back pain", "arthritis"],
            .neurological: ["headache", "migraine", "dizzy", "seizure", "neuro"],
            .dermatological: ["rash", "skin", "eczema", "dermatitis"],
            .endocrine: ["diabetes", "thyroid", "hormone"],
            .psychiatric: ["anxiety", "depression", "mood", "stress"],
            .genitourinary: ["urine", "uti", "kidney", "bladder"],
            .infectious: ["infection", "fever", "viral", "bacterial"]
        ]
        
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { text.contains($0) }) {
                categories.append(category)
            }
        }
        
        return categories.isEmpty ? [.other] : categories
    }
    
    // MARK: - Training Integration
    
    func prepareForTraining(_ samples: [PriMock57Sample]) -> [(input: String, output: String, metadata: [String: Any])] {
        return samples.map { sample in
            let input = formatTrainingInput(sample)
            let output = formatTrainingOutput(sample)
            let metadata: [String: Any] = [
                "id": sample.id,
                "complexity": sample.metadata.complexity.rawValue,
                "categories": sample.metadata.conditionCategory.map { $0.rawValue },
                "duration": sample.metadata.duration,
                "quality_score": sample.humanEvaluation?.noteQuality ?? 3.0,
                "has_audio": sample.audioPath != nil
            ]
            
            return (input, output, metadata)
        }
    }
    
    private func formatTrainingInput(_ sample: PriMock57Sample) -> String {
        return """
        Generate a clinical note from this primary care consultation:
        
        CONSULTATION TYPE: \(sample.metadata.consultationType)
        CHIEF COMPLAINT: \(sample.metadata.chiefComplaint)
        
        CONVERSATION:
        \(sample.transcript.fullText)
        
        CLINICAL NOTE:
        """
    }
    
    private func formatTrainingOutput(_ sample: PriMock57Sample) -> String {
        return sample.clinicalNote
    }
    
    // MARK: - Audio Processing (if needed)
    
    func processAudioFiles(_ samples: [PriMock57Sample]) async throws {
        for sample in samples {
            guard let audioPath = sample.audioPath else { continue }
            
            // Process audio for training if needed
            // This could involve:
            // - Feature extraction
            // - Whisper transcription
            // - Audio quality analysis
            
            print("Processing audio: \(audioPath)")
        }
    }
    
    // MARK: - Quality Filtering
    
    func filterHighQualitySamples(_ samples: [PriMock57Sample], minQuality: Float = 3.5) -> [PriMock57Sample] {
        return samples.filter { sample in
            guard let eval = sample.humanEvaluation else { return true }
            return eval.noteQuality >= minQuality &&
                   eval.clinicalCompleteness >= 70 &&
                   eval.diagnosticAccuracy >= 70
        }
    }
    
    // MARK: - Error Types
    
    enum DataLoadError: Error {
        case invalidPath(String)
        case parseError(String)
        case missingData(String)
    }
}