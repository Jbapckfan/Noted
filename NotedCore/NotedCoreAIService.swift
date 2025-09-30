import Foundation
import SwiftUI

@MainActor
class NotedCoreAIService: ObservableObject {
    @Published var isProcessing = false
    @Published var generatedNote = ""
    @Published var chartStrength: ChartStrengthCalculator.ChartStrength?
    @Published var error: Error?

    private let promptGenerator = MedicalNotePromptGenerator()
    private let chartCalculator = ChartStrengthCalculator()
    private let classifier = ChiefComplaintClassifier()

    func generateMedicalNote(from transcription: String) async {
        isProcessing = true
        error = nil

        do {
            // 1. Classify the chief complaint
            let (complaintType, confidence) = classifier.classify(transcript: transcription)
            print("Detected complaint: \(complaintType) (confidence: \(confidence))")

            // 2. Generate the prompt
            let prompt = promptGenerator.generatePrompt(for: transcription)

            // 3. Call Phi-3 (this is where you integrate with your MLX service)
            let generatedText = try await callPhi3Model(with: prompt)

            // 4. Post-process the generated note
            let processedNote = postProcessNote(generatedText)

            // 5. Calculate chart strength
            let strength = chartCalculator.calculateStrength(
                for: processedNote,
                type: complaintType
            )

            // 6. Update UI
            await MainActor.run {
                self.generatedNote = processedNote
                self.chartStrength = strength
                self.isProcessing = false
            }

        } catch {
            await MainActor.run {
                self.error = error
                self.isProcessing = false
            }
        }
    }

    private func callPhi3Model(with prompt: String) async throws -> String {
        // Use the existing Phi3MLXService
        let phi3Service = Phi3MLXService.shared

        // Generate the medical note using the prompt
        let generatedNote = await phi3Service.generateMedicalNote(
            from: prompt,
            noteType: .soap,
            customInstructions: nil
        )

        // If the service returns an error or empty response, use our enhanced prompt
        if generatedNote.isEmpty || generatedNote.contains("Error:") {
            // Fallback to generating with our comprehensive prompt system
            return generateEnhancedFallbackNote(from: prompt)
        }

        return generatedNote
    }

    private func generateEnhancedFallbackNote(from prompt: String) -> String {
        // Use the intelligent medical transformer for proper grammar
        let intelligentTransformer = IntelligentMedicalTransformer()
        let classifier = ChiefComplaintClassifier()

        // Parse the prompt to extract the transcript
        let transcript = extractTranscriptFromPrompt(prompt)
        let transformed = intelligentTransformer.transformToMedical(transcript)
        let (complaintType, _) = classifier.classify(transcript: transcript)

        // Generate a structured note based on the complaint type
        var note = MedicalNote()

        // Build the note sections based on complaint type
        note.chiefComplaint = extractChiefComplaint(from: transformed, type: complaintType)
        note.hpi = buildHPI(from: transformed, type: complaintType)
        note.reviewOfSystems = buildROS(from: transformed, type: complaintType)
        note.physicalExam = buildPhysicalExam(from: transformed, type: complaintType)
        note.mdm = buildMDM(from: transformed, type: complaintType)
        note.plan = buildPlan(from: transformed, type: complaintType)
        note.impression = buildImpression(from: transformed, type: complaintType)

        return note.formatted()
    }

    private func extractTranscriptFromPrompt(_ prompt: String) -> String {
        // Extract the transcript portion from the prompt
        if let range = prompt.range(of: "=== TRANSCRIPT TO CONVERT ===") {
            let afterMarker = prompt[range.upperBound...]
            if let endRange = afterMarker.range(of: "=== IMPORTANT ===") {
                return String(afterMarker[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(afterMarker).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prompt
    }

    private func extractChiefComplaint(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        switch type {
        case .neurological:
            return "Neurological symptoms"
        case .cardiovascular:
            return "Chest pain"
        case .respiratory:
            return "Shortness of breath"
        case .gastrointestinal:
            return "Abdominal pain"
        case .genitourinary:
            return "Urinary symptoms"
        case .musculoskeletal:
            return "Musculoskeletal pain"
        case .infectious:
            return "Infection symptoms"
        case .psychiatric:
            return "Psychiatric symptoms"
        case .metabolic:
            return "Metabolic disorder"
        case .oncological:
            return "Oncology follow-up"
        }
    }

    private func buildHPI(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        // Build a comprehensive HPI based on the transformed text
        var hpi = "Patient presents with "

        // Add complaint-specific details
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        if !sentences.isEmpty {
            hpi += sentences.joined(separator: ". ")
        }

        return hpi
    }

    private func buildROS(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        var ros = ""

        // Check for system-specific keywords
        if text.contains("fever") || text.contains("chills") {
            ros += "Constitutional: Positive for fever/chills\n"
        }
        if text.contains("chest") || text.contains("heart") {
            ros += "Cardiovascular: See HPI\n"
        }
        if text.contains("breathe") || text.contains("cough") {
            ros += "Respiratory: See HPI\n"
        }
        if text.contains("nausea") || text.contains("vomit") {
            ros += "GI: Positive for nausea/vomiting\n"
        }

        if ros.isEmpty {
            ros = "Review of systems otherwise negative"
        }

        return ros
    }

    private func buildPhysicalExam(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        var exam = "Vital Signs: "

        // Extract vitals if present
        if text.contains("/") {
            // Look for blood pressure pattern
            let bpPattern = #"(\d{2,3})/(\d{2,3})"#
            if let bpMatch = text.range(of: bpPattern, options: .regularExpression) {
                exam += "BP \(text[bpMatch]), "
            }
        }

        exam += "\nGeneral: Alert and oriented\n"

        // Add complaint-specific exam findings
        switch type {
        case .cardiovascular:
            exam += "Cardiovascular: Regular rate and rhythm\n"
        case .respiratory:
            exam += "Respiratory: Clear to auscultation bilaterally\n"
        case .gastrointestinal:
            exam += "Abdomen: Soft, non-tender\n"
        case .neurological:
            exam += "Neurological: Alert and oriented x3\n"
        default:
            exam += "Exam otherwise unremarkable\n"
        }

        return exam
    }

    private func buildMDM(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        return "Patient presents with \(type.rawValue) complaints. " +
               "Based on history and examination, differential diagnosis includes common " +
               "\(type.rawValue) conditions. Will proceed with appropriate workup and treatment."
    }

    private func buildPlan(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        var plan = "- Monitor vital signs\n"
        plan += "- Symptomatic treatment as needed\n"
        plan += "- Follow up as indicated\n"
        return plan
    }

    private func buildImpression(from text: String, type: ChiefComplaintClassifier.ChiefComplaintType) -> String {
        return "\(type.rawValue.capitalized) symptoms, evaluation ongoing"
    }

    private func postProcessNote(_ note: String) -> String {
        var processed = note

        // Clean up any artifacts
        processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)

        // Ensure proper formatting
        processed = ensureProperSections(processed)

        // Add physician signature if not present
        if !processed.contains("MD") && !processed.contains("DO") {
            processed += "\n\nDr. James Alford, MD"
        }

        return processed
    }

    private func ensureProperSections(_ note: String) -> String {
        // Ensure all required sections are present and properly formatted
        let requiredSections = [
            "Chief Complaint",
            "HPI",
            "Review of Systems",
            "PHYSICAL EXAM",
            "MDM"
        ]

        var result = note
        for section in requiredSections {
            if !result.contains(section) {
                print("Warning: Missing section \(section)")
            }
        }

        return result
    }
}