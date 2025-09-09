import Foundation
import NaturalLanguage

/// Simple offline summarization using iOS built-in capabilities
/// No external LLM needed - uses Apple's on-device ML
@MainActor
class SimpleLLMSummarizer: ObservableObject {
    static let shared = SimpleLLMSummarizer()
    
    @Published var isProcessing = false
    @Published var lastSummary = ""
    
    /// Summarize using iOS built-in NLP (completely offline)
    func summarizeWithBuiltInNLP(_ text: String) -> String {
        // Use NaturalLanguage framework for extraction
        var summary = SummaryComponents()
        
        // 1. Extract key sentences using importance scoring
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Score each sentence
        let scoredSentences = sentences.map { sentence -> (String, Double) in
            var score = 0.0
            let words = sentence.lowercased().components(separatedBy: .whitespaces)
            
            // Medical term scoring
            for word in words {
                // Symptoms
                if ["pain", "ache", "fever", "cough", "nausea", "vomiting", "dizzy", "weak"].contains(word) {
                    score += 3.0
                }
                // Time markers
                if ["days", "weeks", "hours", "started", "began", "since"].contains(word) {
                    score += 2.0
                }
                // Medications
                if ["mg", "medication", "taking", "prescribed", "dose"].contains(word) {
                    score += 2.5
                }
                // Body parts
                if ["chest", "head", "stomach", "back", "throat", "arm", "leg"].contains(word) {
                    score += 1.5
                }
            }
            
            return (sentence, score)
        }
        
        // Sort by score and extract top sentences
        let topSentences = scoredSentences
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0.0 }
        
        // 2. Pattern-based extraction for structured output
        for sentence in sentences {
            let lower = sentence.lowercased()
            
            // Chief complaint (first symptom mentioned)
            if summary.chiefComplaint.isEmpty {
                if lower.contains("pain") || lower.contains("ache") || lower.contains("hurt") {
                    summary.chiefComplaint = extractSymptom(from: sentence)
                }
            }
            
            // Duration
            if let duration = extractDuration(from: sentence) {
                summary.duration = duration
            }
            
            // Medications
            if lower.contains("taking") || lower.contains("medication") || lower.contains("mg") {
                summary.medications.append(sentence)
            }
            
            // Associated symptoms
            if lower.contains("also") || lower.contains("and") || lower.contains("with") {
                if ["nausea", "vomiting", "fever", "dizzy", "weak"].contains(where: { lower.contains($0) }) {
                    summary.associatedSymptoms.append(sentence)
                }
            }
        }
        
        // 3. Format the output
        return formatSummary(summary, topSentences: topSentences)
    }
    
    /// Even simpler rule-based extraction
    func simpleRuleBasedSummary(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var summary = ""
        
        // Extract by speaker patterns
        var patientStatements: [String] = []
        var doctorQuestions: [String] = []
        
        for line in lines {
            if line.lowercased().starts(with: "patient:") {
                patientStatements.append(line.replacingOccurrences(of: "Patient:", with: "").trimmingCharacters(in: .whitespaces))
            } else if line.lowercased().starts(with: "doctor:") {
                doctorQuestions.append(line.replacingOccurrences(of: "Doctor:", with: "").trimmingCharacters(in: .whitespaces))
            }
        }
        
        // Build summary from patient statements
        if !patientStatements.isEmpty {
            // First statement is usually chief complaint
            summary += "CHIEF COMPLAINT: \(patientStatements.first ?? "")\n\n"
            
            // Rest is HPI
            if patientStatements.count > 1 {
                summary += "HPI:\n"
                for statement in patientStatements.dropFirst() {
                    summary += "• \(statement)\n"
                }
            }
        }
        
        return summary
    }
    
    // MARK: - Helper Methods
    
    private func extractSymptom(from sentence: String) -> String {
        // Simple pattern matching for symptoms
        if sentence.contains("chest pain") { return "Chest pain" }
        if sentence.contains("headache") { return "Headache" }
        if sentence.contains("stomach") { return "Abdominal pain" }
        if sentence.contains("back pain") { return "Back pain" }
        
        // Fallback: extract "X pain" pattern
        if let range = sentence.range(of: #"\w+\s+pain"#, options: .regularExpression) {
            return String(sentence[range]).capitalized
        }
        
        return sentence
    }
    
    private func extractDuration(from sentence: String) -> String? {
        // Pattern matching for duration
        let patterns = [
            #"\d+\s+days?"#,
            #"\d+\s+weeks?"#,
            #"\d+\s+hours?"#,
            #"since\s+\w+"#,
            #"for\s+\w+\s+\w+"#
        ]
        
        for pattern in patterns {
            if let range = sentence.range(of: pattern, options: .regularExpression) {
                return String(sentence[range])
            }
        }
        
        return nil
    }
    
    private func formatSummary(_ components: SummaryComponents, topSentences: [String]) -> String {
        var output = ""
        
        // Chief Complaint
        if !components.chiefComplaint.isEmpty {
            output += "CHIEF COMPLAINT:\n\(components.chiefComplaint)"
            if let duration = components.duration {
                output += " x\(duration)"
            }
            output += "\n\n"
        }
        
        // HPI from top sentences
        output += "HPI:\n"
        for sentence in topSentences.prefix(3) {
            output += "• \(sentence)\n"
        }
        output += "\n"
        
        // Medications
        if !components.medications.isEmpty {
            output += "MEDICATIONS:\n"
            for med in components.medications {
                output += "• \(med)\n"
            }
            output += "\n"
        }
        
        // Associated symptoms
        if !components.associatedSymptoms.isEmpty {
            output += "ASSOCIATED SYMPTOMS:\n"
            for symptom in components.associatedSymptoms {
                output += "• \(symptom)\n"
            }
        }
        
        return output
    }
    
    private struct SummaryComponents {
        var chiefComplaint = ""
        var duration: String?
        var medications: [String] = []
        var associatedSymptoms: [String] = []
    }
}

// MARK: - For Real Offline LLM (Requires downloading a model)

extension SimpleLLMSummarizer {
    /// This would use a real local LLM like Phi-3 or Llama
    /// But requires downloading 2-4GB model files
    func summarizeWithLocalLLM(_ text: String) async -> String {
        // Option 1: Use MLX (Apple Silicon)
        // - Requires MLX framework and model files
        // - See Phi3MLXService.swift
        
        // Option 2: Use llama.cpp
        // - Cross-platform, runs on CPU
        // - Requires building llama.cpp and downloading GGUF models
        
        // Option 3: Use Core ML models
        // - Apple's framework, optimized for iOS/Mac
        // - Requires converting models to Core ML format
        
        // For now, fall back to rule-based
        return simpleRuleBasedSummary(text)
    }
}