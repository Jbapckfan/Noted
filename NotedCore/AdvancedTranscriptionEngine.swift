import Foundation
import WhisperKit
import Speech
import AVFoundation
import Accelerate
import CoreML
import NaturalLanguage

// MARK: - Advanced Multi-Model Transcription Engine
actor AdvancedTranscriptionEngine {
    
    // MARK: - Models
    private var whisperModels: [WhisperModel] = []
    private var speechRecognizer: SFSpeechRecognizer?
    private var customMedicalModel: MLModel?
    private let medicalVocabulary = MedicalVocabularyDatabase()
    
    // MARK: - Processing State
    private var activeTranscriptions: [UUID: TranscriptionState] = [:]
    private let processingQueue = DispatchQueue(label: "transcription.processing", qos: .userInitiated, attributes: .concurrent)
    
    // MARK: - Configuration
    struct Configuration {
        var enableMultiModel: Bool = true
        var enableRealTimeCorrection: Bool = true
        var enableMedicalSpecialization: Bool = true
        var confidenceThreshold: Double = 0.85
        var chunkDuration: TimeInterval = 2.0
        var overlapDuration: TimeInterval = 0.5
        var maxRetries: Int = 3
        var enableVAD: Bool = true // Voice Activity Detection
        var enableNoiseSuppression: Bool = true
        var enableDiarization: Bool = true // Speaker identification
    }
    
    private var configuration: Configuration
    
    // MARK: - Audio Processing
    private let audioProcessor = AdvancedAudioProcessor()
    private let noiseSupressor = NoiseSuppressor()
    private let vad = VoiceActivityDetector()
    private let diarizer = SpeakerDiarizer()
    
    // MARK: - Error Correction
    private let medicalCorrector = MedicalTranscriptionCorrector()
    private let contextualCorrector = ContextualCorrector()
    private let acousticModelCorrector = AcousticModelCorrector()
    
    // MARK: - Performance Monitoring
    private var metrics = TranscriptionMetrics()
    
    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }
    
    // MARK: - Initialization
    func initialize() async {
        await loadModels()
        await initializeProcessors()
        await loadMedicalVocabulary()
    }
    
    private func loadModels() async {
        // Load multiple Whisper models for ensemble processing
        let modelVariants = [
            "openai_whisper-base.en",
            "openai_whisper-small.en",
            "openai_whisper-medium.en"
        ]
        
        for variant in modelVariants {
            if let model = await loadWhisperModel(variant) {
                whisperModels.append(model)
            }
        }
        
        // Initialize iOS Speech Recognizer for fallback
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.supportsOnDeviceRecognition = true
        
        // Load custom medical ML model
        if let modelURL = Bundle.main.url(forResource: "MedicalTranscription", withExtension: "mlmodelc") {
            customMedicalModel = try? MLModel(contentsOf: modelURL)
        }
    }
    
    private func loadWhisperModel(_ variant: String) async -> WhisperModel? {
        do {
            let modelPath = WhisperKit.modelPath(for: variant)
            let whisperKit = try await WhisperKit(modelFolder: modelPath)
            return WhisperModel(kit: whisperKit, variant: variant)
        } catch {
            print("Failed to load Whisper model \(variant): \(error)")
            return nil
        }
    }
    
    private func initializeProcessors() async {
        await audioProcessor.initialize()
        await noiseSupressor.initialize()
        await vad.initialize()
        await diarizer.initialize()
    }
    
    private func loadMedicalVocabulary() async {
        await medicalVocabulary.load()
        await medicalCorrector.loadVocabulary(medicalVocabulary)
    }
    
    // MARK: - Session Management
    func prepareSession(_ sessionID: UUID) async {
        activeTranscriptions[sessionID] = TranscriptionState(
            sessionID: sessionID,
            startTime: Date(),
            audioBuffer: CircularAudioBuffer(maxDuration: 30.0),
            transcriptionHistory: []
        )
    }
    
    func cleanupSession(_ sessionID: UUID) async {
        activeTranscriptions.removeValue(forKey: sessionID)
    }
    
    // MARK: - Main Transcription Method
    func transcribe(_ audioData: Data, context: ClinicalContext) async -> TranscriptionResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Pre-process audio
        let processedAudio = await preprocessAudio(audioData)
        
        // Voice Activity Detection
        guard await vad.detectVoice(in: processedAudio) else {
            return TranscriptionResult(text: "", confidence: 1.0, segments: [], processingTime: 0)
        }
        
        // Multi-model transcription
        let transcriptions = await performMultiModelTranscription(processedAudio)
        
        // Ensemble and merge results
        let mergedResult = await mergeTranscriptions(transcriptions, context: context)
        
        // Apply corrections
        let correctedResult = await applyCorrections(mergedResult, context: context)
        
        // Speaker diarization if enabled
        let finalResult = configuration.enableDiarization ? 
            await applyDiarization(correctedResult, audio: processedAudio) : correctedResult
        
        // Record metrics
        let processingTime = CFAbsoluteTimeGetCurrent() - startTime
        metrics.record(processingTime: processingTime, confidence: finalResult.confidence)
        
        return finalResult
    }
    
    // MARK: - Audio Preprocessing
    private func preprocessAudio(_ audioData: Data) async -> ProcessedAudio {
        var audio = ProcessedAudio(data: audioData)
        
        // Apply noise suppression
        if configuration.enableNoiseSuppression {
            audio = await noiseSupressor.suppress(audio)
        }
        
        // Normalize audio levels
        audio = await audioProcessor.normalize(audio)
        
        // Apply medical audio enhancement (optimize for medical terminology)
        audio = await audioProcessor.enhanceForMedical(audio)
        
        return audio
    }
    
    // MARK: - Multi-Model Transcription
    private func performMultiModelTranscription(_ audio: ProcessedAudio) async -> [ModelTranscription] {
        guard configuration.enableMultiModel else {
            // Use single best model
            if let bestModel = whisperModels.first {
                let result = await transcribeWithWhisper(audio, model: bestModel)
                return [result]
            }
            return []
        }
        
        // Run models in parallel
        return await withTaskGroup(of: ModelTranscription.self) { group in
            // Whisper models
            for model in whisperModels {
                group.addTask {
                    await self.transcribeWithWhisper(audio, model: model)
                }
            }
            
            // iOS Speech Recognition
            if speechRecognizer != nil {
                group.addTask {
                    await self.transcribeWithSpeechRecognizer(audio)
                }
            }
            
            // Custom medical model
            if customMedicalModel != nil {
                group.addTask {
                    await self.transcribeWithCustomModel(audio)
                }
            }
            
            var results: [ModelTranscription] = []
            for await transcription in group {
                results.append(transcription)
            }
            return results
        }
    }
    
    // MARK: - Individual Model Transcription
    private func transcribeWithWhisper(_ audio: ProcessedAudio, model: WhisperModel) async -> ModelTranscription {
        do {
            let audioArray = audio.toFloatArray()
            let options = DecodingOptions(
                language: "en",
                task: .transcribe,
                usePrefillPrompt: true,
                skipSpecialTokens: true,
                withoutTimestamps: false
            )
            
            let results = try await model.kit.transcribe(
                audioArray: audioArray,
                decodeOptions: options
            )
            
            let segments = results.map { segment in
                TranscriptionSegment(
                    text: segment.text,
                    startTime: segment.start,
                    endTime: segment.end,
                    confidence: segment.probability ?? 0.5,
                    speaker: nil
                )
            }
            
            return ModelTranscription(
                modelName: model.variant,
                text: results.map { $0.text }.joined(separator: " "),
                segments: segments,
                confidence: calculateOverallConfidence(segments)
            )
        } catch {
            return ModelTranscription(
                modelName: model.variant,
                text: "",
                segments: [],
                confidence: 0.0
            )
        }
    }
    
    private func transcribeWithSpeechRecognizer(_ audio: ProcessedAudio) async -> ModelTranscription {
        guard let recognizer = speechRecognizer else {
            return ModelTranscription(modelName: "iOS Speech", text: "", segments: [], confidence: 0.0)
        }
        
        do {
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = false
            request.requiresOnDeviceRecognition = true
            
            let audioBuffer = audio.toAVAudioPCMBuffer()
            request.append(audioBuffer)
            
            let result = try await recognizer.recognitionTask(with: request)
            let transcription = result.bestTranscription
            
            let segments = transcription.segments.map { segment in
                TranscriptionSegment(
                    text: segment.substring,
                    startTime: segment.timestamp,
                    endTime: segment.timestamp + segment.duration,
                    confidence: segment.confidence,
                    speaker: nil
                )
            }
            
            return ModelTranscription(
                modelName: "iOS Speech",
                text: transcription.formattedString,
                segments: segments,
                confidence: Double(transcription.segments.map { $0.confidence }.reduce(0, +)) / Double(max(transcription.segments.count, 1))
            )
        } catch {
            return ModelTranscription(modelName: "iOS Speech", text: "", segments: [], confidence: 0.0)
        }
    }
    
    private func transcribeWithCustomModel(_ audio: ProcessedAudio) async -> ModelTranscription {
        guard let model = customMedicalModel else {
            return ModelTranscription(modelName: "Custom Medical", text: "", segments: [], confidence: 0.0)
        }
        
        do {
            let input = try MLDictionaryFeatureProvider(
                dictionary: ["audio": MLMultiArray(audio.toFloatArray())]
            )
            
            let output = try model.prediction(from: input)
            
            if let transcription = output.featureValue(for: "transcription")?.stringValue,
               let confidence = output.featureValue(for: "confidence")?.doubleValue {
                return ModelTranscription(
                    modelName: "Custom Medical",
                    text: transcription,
                    segments: [], // Custom model returns full text only
                    confidence: confidence
                )
            }
        } catch {
            print("Custom model transcription failed: \(error)")
        }
        
        return ModelTranscription(modelName: "Custom Medical", text: "", segments: [], confidence: 0.0)
    }
    
    // MARK: - Ensemble Merging
    private func mergeTranscriptions(_ transcriptions: [ModelTranscription], context: ClinicalContext) async -> TranscriptionResult {
        guard !transcriptions.isEmpty else {
            return TranscriptionResult(text: "", confidence: 0.0, segments: [], processingTime: 0)
        }
        
        // Weight models based on their historical performance and current confidence
        let weightedTranscriptions = transcriptions.map { transcription in
            let weight = calculateModelWeight(transcription, context: context)
            return (transcription, weight)
        }
        
        // Use ROVER (Recognizer Output Voting Error Reduction) algorithm
        let mergedText = await performROVER(weightedTranscriptions)
        
        // Merge segments with alignment
        let mergedSegments = await mergeSegments(weightedTranscriptions)
        
        // Calculate overall confidence
        let totalWeight = weightedTranscriptions.map { $0.1 }.reduce(0, +)
        let weightedConfidence = weightedTranscriptions.map { $0.0.confidence * $0.1 }.reduce(0, +) / totalWeight
        
        return TranscriptionResult(
            text: mergedText,
            confidence: weightedConfidence,
            segments: mergedSegments,
            processingTime: 0
        )
    }
    
    private func calculateModelWeight(_ transcription: ModelTranscription, context: ClinicalContext) -> Double {
        var weight = transcription.confidence
        
        // Boost weight for medical-specialized models
        if transcription.modelName.contains("medical") || transcription.modelName.contains("Medical") {
            weight *= 1.2
        }
        
        // Adjust based on context relevance
        let medicalTermCount = countMedicalTerms(in: transcription.text)
        if medicalTermCount > 0 {
            weight *= (1.0 + Double(medicalTermCount) * 0.05)
        }
        
        return min(weight, 1.0)
    }
    
    private func performROVER(_ weightedTranscriptions: [(ModelTranscription, Double)]) async -> String {
        // Simplified ROVER implementation
        // In production, use dynamic programming for optimal alignment
        
        let texts = weightedTranscriptions.map { $0.0.text }
        let weights = weightedTranscriptions.map { $0.1 }
        
        // Token-level voting
        let tokenizedTexts = texts.map { $0.split(separator: " ").map(String.init) }
        let maxLength = tokenizedTexts.map { $0.count }.max() ?? 0
        
        var mergedTokens: [String] = []
        
        for position in 0..<maxLength {
            var tokenVotes: [String: Double] = [:]
            
            for (index, tokens) in tokenizedTexts.enumerated() {
                if position < tokens.count {
                    let token = tokens[position]
                    tokenVotes[token, default: 0] += weights[index]
                }
            }
            
            if let bestToken = tokenVotes.max(by: { $0.value < $1.value })?.key {
                mergedTokens.append(bestToken)
            }
        }
        
        return mergedTokens.joined(separator: " ")
    }
    
    private func mergeSegments(_ weightedTranscriptions: [(ModelTranscription, Double)]) async -> [TranscriptionSegment] {
        // Merge segments from different models with time alignment
        var allSegments: [(TranscriptionSegment, Double)] = []
        
        for (transcription, weight) in weightedTranscriptions {
            for segment in transcription.segments {
                allSegments.append((segment, weight))
            }
        }
        
        // Sort by start time
        allSegments.sort { $0.0.startTime < $1.0.startTime }
        
        // Merge overlapping segments
        var mergedSegments: [TranscriptionSegment] = []
        var currentSegment: TranscriptionSegment?
        var currentWeight: Double = 0
        
        for (segment, weight) in allSegments {
            if let current = currentSegment {
                if segment.startTime < current.endTime {
                    // Overlapping segments - merge
                    if weight > currentWeight {
                        currentSegment = segment
                        currentWeight = weight
                    }
                } else {
                    // Non-overlapping - add current and start new
                    mergedSegments.append(current)
                    currentSegment = segment
                    currentWeight = weight
                }
            } else {
                currentSegment = segment
                currentWeight = weight
            }
        }
        
        if let finalSegment = currentSegment {
            mergedSegments.append(finalSegment)
        }
        
        return mergedSegments
    }
    
    // MARK: - Corrections
    private func applyCorrections(_ result: TranscriptionResult, context: ClinicalContext) async -> TranscriptionResult {
        var correctedText = result.text
        var correctedSegments = result.segments
        
        // Medical terminology correction
        if configuration.enableMedicalSpecialization {
            correctedText = await medicalCorrector.correct(correctedText, context: context)
            correctedSegments = await medicalCorrector.correctSegments(correctedSegments, context: context)
        }
        
        // Contextual correction
        if configuration.enableRealTimeCorrection {
            correctedText = await contextualCorrector.correct(correctedText, context: context)
        }
        
        // Acoustic model correction for common errors
        correctedText = await acousticModelCorrector.correct(correctedText)
        
        return TranscriptionResult(
            text: correctedText,
            confidence: result.confidence * 1.1, // Boost confidence after corrections
            segments: correctedSegments,
            processingTime: result.processingTime
        )
    }
    
    // MARK: - Speaker Diarization
    private func applyDiarization(_ result: TranscriptionResult, audio: ProcessedAudio) async -> TranscriptionResult {
        let speakerSegments = await diarizer.identifySpeakers(audio: audio, segments: result.segments)
        
        return TranscriptionResult(
            text: result.text,
            confidence: result.confidence,
            segments: speakerSegments,
            processingTime: result.processingTime
        )
    }
    
    // MARK: - Helper Methods
    private func countMedicalTerms(in text: String) -> Int {
        let medicalTerms = medicalVocabulary.getAllTerms()
        let words = text.lowercased().split(separator: " ").map(String.init)
        return words.filter { medicalTerms.contains($0) }.count
    }
    
    private func calculateOverallConfidence(_ segments: [TranscriptionSegment]) -> Double {
        guard !segments.isEmpty else { return 0.0 }
        return segments.map { $0.confidence }.reduce(0, +) / Double(segments.count)
    }
    
    func clearCache(olderThan date: Date) async {
        // Clear old transcription states
        activeTranscriptions = activeTranscriptions.filter { $0.value.startTime > date }
    }
}

// MARK: - Supporting Types
struct WhisperModel {
    let kit: WhisperKit
    let variant: String
}

struct TranscriptionState {
    let sessionID: UUID
    let startTime: Date
    var audioBuffer: CircularAudioBuffer
    var transcriptionHistory: [TranscriptionResult]
}

struct ModelTranscription {
    let modelName: String
    let text: String
    let segments: [TranscriptionSegment]
    let confidence: Double
}

struct TranscriptionResult {
    let text: String
    let confidence: Double
    let segments: [TranscriptionSegment]
    let processingTime: TimeInterval
}

struct TranscriptionSegment {
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Double
    var speaker: String?
}

struct ProcessedAudio {
    let data: Data
    
    func toFloatArray() -> [Float] {
        let floatCount = data.count / MemoryLayout<Float>.size
        return data.withUnsafeBytes { bytes in
            Array(UnsafeBufferPointer(start: bytes.bindMemory(to: Float.self).baseAddress, count: floatCount))
        }
    }
    
    func toAVAudioPCMBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(data.count / 2))!
        buffer.frameLength = buffer.frameCapacity
        
        data.withUnsafeBytes { bytes in
            memcpy(buffer.int16ChannelData![0], bytes.baseAddress, data.count)
        }
        
        return buffer
    }
}

// MARK: - Metrics
struct TranscriptionMetrics {
    private var processingTimes: [TimeInterval] = []
    private var confidenceScores: [Double] = []
    
    mutating func record(processingTime: TimeInterval, confidence: Double) {
        processingTimes.append(processingTime)
        confidenceScores.append(confidence)
        
        // Keep only recent metrics
        if processingTimes.count > 1000 {
            processingTimes.removeFirst(500)
            confidenceScores.removeFirst(500)
        }
    }
    
    var averageProcessingTime: TimeInterval {
        processingTimes.isEmpty ? 0 : processingTimes.reduce(0, +) / Double(processingTimes.count)
    }
    
    var averageConfidence: Double {
        confidenceScores.isEmpty ? 0 : confidenceScores.reduce(0, +) / Double(confidenceScores.count)
    }
}