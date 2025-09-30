import Foundation
import SwiftUI

// MARK: - Groq API Service for Medical Note Generation
// Based on ScribeWizard's approach with medical adaptations

@MainActor
class GroqService: ObservableObject {
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generationProgress: Float = 0.0
    @Published var currentSection = ""
    @Published var streamedContent = ""
    @Published var error: String?
    @Published var statistics = GenerationStatistics()
    
    // MARK: - Configuration
    private let baseURL = "https://api.groq.com/openai/v1/chat/completions"
    private var apiKey: String {
        // Try environment variable first, then UserDefaults
        ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? 
        UserDefaults.standard.string(forKey: "groq_api_key") ?? ""
    }
    
    // MARK: - Models (Free Tier Compatible)
    enum Model: String {
        // Fast models for free tier
        case llamaScout = "llama-3.2-3b-preview"  // Fastest, for outlines
        case llamaInstant = "llama-3.2-1b-preview" // Ultra-fast, basic tasks
        case mixtral = "mixtral-8x7b-32768" // Good balance
        case llamaMedium = "llama3-8b-8192" // Better quality
        
        var contextWindow: Int {
            switch self {
            case .llamaScout, .llamaInstant: return 8192
            case .mixtral: return 32768
            case .llamaMedium: return 8192
            }
        }
        
        var description: String {
            switch self {
            case .llamaScout: return "Fast Outline Generation"
            case .llamaInstant: return "Ultra-Fast Processing"
            case .mixtral: return "Balanced Performance"
            case .llamaMedium: return "Quality Output"
            }
        }
    }
    
    // MARK: - Generation Statistics
    struct GenerationStatistics {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var totalTime: TimeInterval = 0
        var model: String = ""
        
        var tokensPerSecond: Double {
            guard totalTime > 0 else { return 0 }
            return Double(outputTokens) / totalTime
        }
        
        var formattedSpeed: String {
            return String(format: "%.1f T/s", tokensPerSecond)
        }
    }
    
    // MARK: - Main Generation Methods
    
    func generateStructuredMedicalNote(
        from transcription: String,
        noteType: NoteType = .soap
    ) async -> String {
        isGenerating = true
        generationProgress = 0.0
        streamedContent = ""
        error = nil
        
        do {
            // Use advanced medical prompt engine for human-level accuracy
            currentSection = "Analyzing medical context..."
            generationProgress = 0.2
            
            let note = try await generateOutline(from: transcription, noteType: noteType)
            
            generationProgress = 0.8
            
            // Extract the content from the response
            if let content = note["content"] as? String {
                streamedContent = content
                generationProgress = 1.0
                isGenerating = false
                return content
            }
            
            isGenerating = false
            return transcription // Fallback
            
        } catch {
            self.error = "Generation failed: \(error.localizedDescription)"
            isGenerating = false
            return transcription // Fallback to original transcription
        }
    }
    
    // MARK: - Stage 1: Outline Generation
    
    private func generateOutline(from transcription: String, noteType: NoteType) async throws -> [String: Any] {
        // Use advanced medical prompt engine for human-level accuracy
        let contextAnalysis = AdvancedMedicalPromptEngine.analyzeTranscriptForMedicalContext(transcription)
        
        let prompt = AdvancedMedicalPromptEngine.generateUltraAccurateMedicalNote(
            transcript: transcription,
            noteType: noteType,
            clinicalContext: contextAnalysis.urgencyLevel,
            patientDemographics: nil
        )
        
        let endpoint = "https://api.groq.com/openai/v1/chat/completions"
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "mixtral-8x7b-32768",
            "messages": [
                ["role": "system", "content": prompt],
                ["role": "user", "content": "Generate the medical note from the transcript provided."]
            ],
            "temperature": 0.3,
            "max_tokens": 4000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            
            streamedContent = content
            
            // Return structured outline
            return [
                "content": content,
                "analysis": [
                    "redFlags": contextAnalysis.redFlags,
                    "urgency": contextAnalysis.urgencyLevel,
                    "symptoms": contextAnalysis.symptoms.map { $0.name },
                    "medications": contextAnalysis.medications.map { $0.name }
                ]
            ]
        }
        
        throw GroqError.invalidResponse
    }
    
    // MARK: - Stage 3: Formatting
    
    private func formatMedicalNote(sections: [String: String], noteType: NoteType) -> String {
        var formattedNote = ""
        
        // Add header
        formattedNote += "═══════════════════════════════════════\n"
        formattedNote += "\(noteType.displayName.uppercased())\n"
        formattedNote += "Generated: \(Date().formatted(date: .abbreviated, time: .shortened))\n"
        formattedNote += "═══════════════════════════════════════\n\n"
        
        // Format based on note type
        switch noteType {
        case .soap:
            formattedNote += formatSOAPNote(sections)
        case .edNote:
            formattedNote += formatEDNote(sections)
        case .progress:
            formattedNote += formatProgressNote(sections)
        case .discharge:
            formattedNote += formatDischargeNote(sections)
        default:
            formattedNote += formatGenericNote(sections)
        }
        
        // Add statistics if available
        if statistics.tokensPerSecond > 0 {
            formattedNote += "\n\n---\n"
            formattedNote += "⚡ Generated at \(statistics.formattedSpeed)\n"
            formattedNote += "Model: \(statistics.model)\n"
        }
        
        return formattedNote
    }
    
    private func formatSOAPNote(_ sections: [String: String]) -> String {
        var note = ""
        
        // Subjective
        note += "SUBJECTIVE:\n"
        note += sections["chief_complaint"] ?? "Not documented"
        note += "\n\n"
        note += "History of Present Illness:\n"
        note += sections["hpi"] ?? "See transcription"
        note += "\n\n"
        
        // Objective
        note += "OBJECTIVE:\n"
        note += sections["physical_exam"] ?? "Vital signs stable"
        note += "\n\n"
        
        // Assessment
        note += "ASSESSMENT:\n"
        note += sections["assessment"] ?? "See plan"
        note += "\n\n"
        
        // Plan
        note += "PLAN:\n"
        note += sections["plan"] ?? "Follow up as needed"
        
        return note
    }
    
    private func formatEDNote(_ sections: [String: String]) -> String {
        var note = ""
        
        note += "CHIEF COMPLAINT: "
        note += sections["chief_complaint"] ?? ""
        note += "\n\n"
        
        note += "HISTORY OF PRESENT ILLNESS:\n"
        note += sections["hpi"] ?? ""
        note += "\n\n"
        
        note += "REVIEW OF SYSTEMS:\n"
        note += sections["review_of_systems"] ?? "Otherwise negative"
        note += "\n\n"
        
        note += "PHYSICAL EXAMINATION:\n"
        note += sections["physical_exam"] ?? ""
        note += "\n\n"
        
        note += "EMERGENCY DEPARTMENT COURSE:\n"
        note += sections["ed_course"] ?? sections["assessment"] ?? ""
        note += "\n\n"
        
        note += "MEDICAL DECISION MAKING:\n"
        note += sections["assessment"] ?? ""
        note += "\n\n"
        
        note += "DISPOSITION AND PLAN:\n"
        note += sections["plan"] ?? ""
        
        return note
    }
    
    private func formatProgressNote(_ sections: [String: String]) -> String {
        return formatSOAPNote(sections) // Similar format
    }
    
    private func formatDischargeNote(_ sections: [String: String]) -> String {
        var note = ""
        
        note += "DISCHARGE SUMMARY\n\n"
        note += "ADMISSION DIAGNOSIS: "
        note += sections["chief_complaint"] ?? ""
        note += "\n\n"
        
        note += "HOSPITAL COURSE:\n"
        note += sections["assessment"] ?? ""
        note += "\n\n"
        
        note += "DISCHARGE INSTRUCTIONS:\n"
        note += sections["plan"] ?? ""
        
        return note
    }
    
    private func formatGenericNote(_ sections: [String: String]) -> String {
        var note = ""
        for (key, value) in sections.sorted(by: { $0.key < $1.key }) {
            note += "\(key.replacingOccurrences(of: "_", with: " ").uppercased()):\n"
            note += value
            note += "\n\n"
        }
        return note
    }
    
    // MARK: - API Communication
    
    private func callGroqAPI(
        prompt: String,
        model: Model,
        temperature: Double = 0.5,
        maxTokens: Int = 500,
        stream: Bool = false
    ) async throws -> String {
        
        guard !apiKey.isEmpty else {
            throw GroqError.missingAPIKey
        }
        
        let startTime = Date()
        
        // Prepare request
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build request body
        let requestBody: [String: Any] = [
            "model": model.rawValue,
            "messages": [
                ["role": "system", "content": "You are a medical scribe assistant. Be accurate, concise, and use appropriate medical terminology."],
                ["role": "user", "content": prompt]
            ],
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": stream
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        // Make request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Check response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GroqError.invalidResponse
        }
        
        // Handle rate limiting (free tier: 30 requests/minute)
        if httpResponse.statusCode == 429 {
            throw GroqError.rateLimitExceeded
        }
        
        guard httpResponse.statusCode == 200 else {
            throw GroqError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw GroqError.invalidResponse
        }
        
        // Update statistics
        if let usage = json["usage"] as? [String: Any] {
            statistics.inputTokens = usage["prompt_tokens"] as? Int ?? 0
            statistics.outputTokens = usage["completion_tokens"] as? Int ?? 0
            statistics.totalTime = Date().timeIntervalSince(startTime)
            statistics.model = model.rawValue
        }
        
        return content
    }
    
    // MARK: - Error Handling
    
    enum GroqError: LocalizedError {
        case missingAPIKey
        case invalidResponse
        case rateLimitExceeded
        case httpError(Int)
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Groq API key not configured. Add GROQ_API_KEY to environment."
            case .invalidResponse:
                return "Invalid response from Groq API"
            case .rateLimitExceeded:
                return "Rate limit exceeded (Free tier: 30 requests/minute). Please wait."
            case .httpError(let code):
                return "HTTP error: \(code)"
            }
        }
    }
    
    // MARK: - Configuration
    
    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "groq_api_key")
    }
    
    func hasAPIKey() -> Bool {
        return !apiKey.isEmpty
    }
    
    // MARK: - Free Tier Management
    
    private var requestCount = 0
    private var requestWindowStart = Date()
    
    private func checkRateLimit() async throws {
        let now = Date()
        let windowDuration: TimeInterval = 60 // 1 minute
        
        if now.timeIntervalSince(requestWindowStart) > windowDuration {
            // Reset window
            requestCount = 0
            requestWindowStart = now
        }
        
        if requestCount >= 30 { // Free tier limit
            let waitTime = windowDuration - now.timeIntervalSince(requestWindowStart)
            if waitTime > 0 {
                currentSection = "Rate limit reached. Waiting \(Int(waitTime))s..."
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                requestCount = 0
                requestWindowStart = Date()
            }
        }
        
        requestCount += 1
    }
}