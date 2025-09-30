# ScribeWizard Integration Plan for NotedCore

## Overview
Integrate ScribeWizard's structured note generation capabilities with NotedCore to enhance medical documentation quality and speed.

## Benefits

### 1. Performance Improvements
- **10x faster inference** using Groq's LPU infrastructure
- **Cost reduction**: ~80% cheaper than OpenAI GPT-4
- **Low latency**: < 3 seconds for complete note generation

### 2. Better Note Structure
- **Iterative refinement**: Outline → Draft → Final
- **Hierarchical organization**: Nested sections for complex medical data
- **Template flexibility**: Easy to adapt for different note types

### 3. Enhanced Features
- **Real-time streaming**: Show notes as they generate
- **Multiple model options**: Balance speed vs quality
- **Export formats**: Markdown, PDF, structured JSON

## Implementation Steps

### Phase 1: Groq API Integration (Week 1)
1. Add Groq SDK to Swift project
2. Create `GroqMedicalService` class
3. Implement API authentication
4. Test with sample transcriptions

### Phase 2: Structured Note Generation (Week 2)
1. Port ScribeWizard's note structuring logic
2. Adapt for medical templates (SOAP, ED notes)
3. Implement two-stage generation:
   - Fast outline with Llama-3.2-3b-preview
   - Detailed content with Llama-3.1-70b-versatile

### Phase 3: UI Integration (Week 3)
1. Add streaming note display
2. Show generation progress
3. Allow note editing and refinement
4. Export to multiple formats

## Code Integration

### Swift Service Class
```swift
import Foundation

class GroqMedicalService: ObservableObject {
    private let apiKey: String
    private let baseURL = "https://api.groq.com/openai/v1"
    
    @Published var generationProgress: Float = 0
    @Published var currentSection: String = ""
    
    enum Model: String {
        case llamaScout = "llama-3.2-3b-preview"  // Fast outline
        case llamaMaverick = "llama-3.1-70b-versatile"  // Detailed content
        case medicalSpecialized = "llama-3.1-8b-instant"  // Medical terms
    }
    
    func generateStructuredNote(
        transcription: String,
        noteType: NoteType
    ) async throws -> MedicalNote {
        // Stage 1: Generate outline
        let outline = try await generateOutline(transcription, model: .llamaScout)
        
        // Stage 2: Fill sections
        let sections = try await fillSections(outline, transcription, model: .llamaMaverick)
        
        // Stage 3: Medical terminology refinement
        let finalNote = try await refineMedicalTerms(sections, model: .medicalSpecialized)
        
        return finalNote
    }
    
    private func generateOutline(_ text: String, model: Model) async throws -> NoteOutline {
        let prompt = """
        Create a structured medical note outline from this transcription.
        Format as hierarchical JSON with main sections and subsections.
        Include: Chief Complaint, HPI, ROS, Physical Exam, Assessment, Plan
        
        Transcription: \(text)
        """
        
        return try await callGroqAPI(prompt: prompt, model: model)
    }
}
```

### Configuration
```swift
// In Configuration.swift
struct GroqConfiguration {
    static let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] ?? ""
    static let maxTokens = 4096
    static let temperature = 0.3  // Lower for medical accuracy
    static let streamingEnabled = true
}
```

### UI Updates
```swift
// In MedicalNotesView.swift
struct EnhancedNoteGenerationView: View {
    @StateObject private var groqService = GroqMedicalService()
    
    var body: some View {
        VStack {
            // Progress indicator
            if groqService.generationProgress > 0 {
                ProgressView("Generating: \(groqService.currentSection)",
                           value: groqService.generationProgress)
            }
            
            // Streaming note display
            ScrollView {
                ForEach(groqService.noteSections) { section in
                    SectionView(section: section)
                        .transition(.slide)
                }
            }
        }
    }
}
```

## API Keys Required

### Groq API
1. Sign up at https://console.groq.com
2. Generate API key
3. Add to environment: `export GROQ_API_KEY="your_key"`

### Current Limits
- Free tier: 30 requests/minute
- Paid tier: 100+ requests/minute
- Token limits: 8k input, 4k output

## Medical Adaptations

### Custom Prompts for Medical Context
```python
medical_outline_prompt = """
You are a medical scribe. Generate a structured outline for a {note_type} note.
Requirements:
- Use standard medical abbreviations
- Include all SOAP/ED note sections
- Flag critical findings
- Suggest ICD-10 codes where applicable
"""

medical_content_prompt = """
Fill in the following section with detailed medical information:
Section: {section_name}
Context: {transcription_excerpt}
Include: symptoms, timeline, severity, associated factors
Use medical terminology appropriately.
"""
```

### Quality Assurance
1. Validate medical terminology
2. Check for contradictions
3. Ensure completeness
4. Flag uncertain information

## Performance Benchmarks

| Metric | Current (WhisperKit + Local) | With ScribeWizard/Groq |
|--------|------------------------------|------------------------|
| Transcription | 5-10 seconds | 5-10 seconds (same) |
| Note Generation | 15-30 seconds | 2-5 seconds |
| Total Time | 20-40 seconds | 7-15 seconds |
| API Cost | $0 (local) | ~$0.001 per note |
| Quality | Good | Excellent |

## Risks & Mitigations

### Risk 1: API Dependency
- **Mitigation**: Fallback to local processing
- Keep existing WhisperKit pipeline as backup

### Risk 2: HIPAA Compliance
- **Mitigation**: Groq offers HIPAA-compliant tier
- Or use local Llama models with Groq formatting logic

### Risk 3: Network Latency
- **Mitigation**: Queue and batch process
- Cache common responses

## Timeline

- **Week 1**: API integration and testing
- **Week 2**: Medical prompt engineering
- **Week 3**: UI updates and streaming
- **Week 4**: Testing and optimization
- **Week 5**: Production deployment

## Success Metrics

- Note generation time < 5 seconds
- Medical accuracy > 95%
- User satisfaction > 4.5/5
- API costs < $0.01 per encounter
- Zero HIPAA violations

## Conclusion

ScribeWizard integration offers significant benefits:
1. **3-5x faster** note generation
2. **Better structure** through iterative generation
3. **Cost-effective** API usage
4. **Proven technology** (Groq + Llama models)

Recommended for immediate integration into NotedCore.