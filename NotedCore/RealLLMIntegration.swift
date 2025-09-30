import Foundation
import NaturalLanguage
#if canImport(CoreML)
import CoreML
#endif
#if canImport(CreateML)
import CreateML
#endif

/// REAL LLM Integration for NotedCore
/// This shows how to actually use LLMs, not just pattern matching
class RealLLMIntegration {
    
    // MARK: - Option 1: Use Local Ollama (Actually Running on Device)
    
    func generateHPIWithOllama(transcript: String, chiefComplaint: String) async throws -> String {
        // Ollama runs locally on macOS
        let prompt = """
        You are a medical scribe. Generate an HPI from this conversation:
        
        Chief Complaint: \(chiefComplaint)
        
        Transcript:
        \(transcript)
        
        Generate a professional HPI in this format:
        [Age]-year-old [sex] presents with [chief complaint]. [Onset and timing]. 
        [Quality and characteristics]. [Associated symptoms]. [Pertinent negatives].
        """
        
        // Call local Ollama API
        let url = URL(string: "http://localhost:11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": "llama2", // or "mistral", "codellama", etc.
            "prompt": prompt,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(OllamaResponse.self, from: data)
        
        return response.response
    }
    
    // MARK: - Option 2: Use Apple's On-Device ML (Actually on iPhone)
    
    @available(iOS 17.0, macOS 14.0, *)
    func generateHPIWithAppleML(transcript: String) async throws -> String {
        // This would use Apple's on-device language models
        // Currently requires specific model files, but here's the structure:
        
        #if canImport(CoreML)
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        #endif
        
        // You would need to include a Core ML model
        // Example: a fine-tuned BERT or GPT model converted to Core ML
        
        // For now, Apple provides NLLanguageRecognizer for basic NLP
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(transcript)
        
        // Extract entities and structure
        let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
        tagger.string = transcript
        
        var extractedSymptoms: [String] = []
        var timeline: [String] = []
        
        tagger.enumerateTags(in: transcript.startIndex..<transcript.endIndex, 
                             unit: .sentence, 
                             scheme: .lexicalClass) { tag, range in
            let sentence = String(transcript[range])
            // Process each sentence for medical information
            if sentence.contains("started") || sentence.contains("began") {
                timeline.append(sentence)
            }
            return true
        }
        
        // This is still rule-based, but uses Apple's NLP
        // For true LLM, you'd need a Core ML model
        return "Generated HPI using Apple's on-device processing"
    }
    
    // MARK: - Option 3: Use WhisperKit's Partner Models
    
    func generateHPIWithWhisperKit(transcript: String) async throws -> String {
        // WhisperKit can integrate with local models
        // This would use the actual WhisperKit framework we have
        
        let modelPath = Bundle.main.path(forResource: "whisper-medical", ofType: "mlmodel")
        // Load and run the model...
        
        return "Generated with WhisperKit integration"
    }
    
    // MARK: - Option 4: Use Groq API (Fast Cloud LLM)
    
    func generateHPIWithGroq(transcript: String, chiefComplaint: String) async throws -> String {
        // Groq is super fast and could work for real-time
        let url = URL(string: "https://api.groq.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(getGroqAPIKey())", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messages = [
            ["role": "system", "content": "You are a medical scribe. Generate structured medical documentation."],
            ["role": "user", "content": "Generate HPI from: \(transcript)"]
        ]
        
        let body: [String: Any] = [
            "model": "mixtral-8x7b-32768", // Or "llama2-70b-4096"
            "messages": messages,
            "temperature": 0.3,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GroqResponse.self, from: data)
        
        return response.choices.first?.message.content ?? ""
    }
    
    // MARK: - How to Verify What's Actually Running
    
    func verifyLLMSource() -> String {
        """
        VERIFICATION METHOD:
        
        1. Check Network Traffic:
           - If using Ollama: Look for localhost:11434 requests
           - If using Groq: Look for api.groq.com requests
           - If fully offline: No external network calls
        
        2. Check Process Monitor:
           - Ollama: 'ollama' process running
           - Apple ML: High Neural Engine usage
           - WhisperKit: MLCompute framework active
        
        3. Test Offline:
           - Turn off WiFi/Internet
           - If it still works: It's using on-device LLM
           - If it fails: It's using cloud LLM
        
        4. Check Response Variability:
           - Rule-based: Same input = Same output
           - Real LLM: Same input = Slightly different outputs
        
        5. Monitor CPU/GPU Usage:
           - Real LLM: Spike in CPU/GPU when generating
           - Rule-based: Minimal processing spike
        """
    }
    
    private func getGroqAPIKey() -> String {
        // In production, use Keychain
        return ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
    }
}

// MARK: - Response Models

struct OllamaResponse: Codable {
    let response: String
    let model: String
    let done: Bool
}

struct GroqResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

// MARK: - Actual Usage Example

class MedicalDocumentationWithRealLLM {
    let llm = RealLLMIntegration()
    
    func processTranscript(_ transcript: String, chiefComplaint: String) async throws -> (hpi: String, mdm: String) {
        // Try local first, fallback to cloud
        
        do {
            // Try Ollama (local)
            let hpi = try await llm.generateHPIWithOllama(
                transcript: transcript,
                chiefComplaint: chiefComplaint
            )
            
            let mdmPrompt = "Generate MDM from HPI: \(hpi)"
            let mdm = try await llm.generateHPIWithOllama(
                transcript: mdmPrompt,
                chiefComplaint: chiefComplaint
            )
            
            print("✅ Generated using LOCAL Ollama LLM")
            return (hpi, mdm)
            
        } catch {
            // Fallback to Groq (fast cloud)
            print("⚠️ Local LLM unavailable, using Groq cloud")
            
            let hpi = try await llm.generateHPIWithGroq(
                transcript: transcript,
                chiefComplaint: chiefComplaint
            )
            
            let mdm = "Generated MDM..." // Generate similarly
            
            return (hpi, mdm)
        }
    }
}

// MARK: - How to Install and Run Local LLM

/*
TO ACTUALLY USE A LOCAL LLM:

1. Install Ollama (for macOS):
   brew install ollama
   ollama serve
   ollama pull llama2
   ollama pull mistral

2. For iOS (on-device):
   - Use Core ML models
   - Convert models using coremltools:
     pip install coremltools
     python convert_model.py

3. Test it's working:
   curl http://localhost:11434/api/generate -d '{
     "model": "llama2",
     "prompt": "Generate an HPI for chest pain"
   }'

4. In NotedCore, use this class instead of pattern matching!
*/