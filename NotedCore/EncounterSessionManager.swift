import Foundation
import SwiftUI
import Combine
import CryptoKit

@MainActor
class EncounterSessionManager: ObservableObject {
    static let shared = EncounterSessionManager()
    
    // MARK: - Published Properties
    @Published var currentSession: EncounterSession?
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var currentPhase: EncounterPhaseType = .intake
    @Published var transcriptionBuffer: String = ""
    @Published var editableTranscript: String = ""
    @Published var selectedNoteType: NoteType = .soap
    @Published var generatedNote: String?
    @Published var isGeneratingNote = false
    @Published var sessionHistory: [EncounterSession] = []
    @Published var previousSessions: [EncounterSession] = []
    
    // MARK: - Deduplication Properties
    private var recentTextBuffer: [String] = []
    private let bufferSize = 10
    private var lastProcessedHash: String = ""
    private let similarityThreshold: Double = 0.85
    
    // MARK: - Services
    private let transcriptionService = SpeechRecognitionService.shared
    private let encounterManager = EncounterManager.shared
    private let noteGenerator = MedicalNoteGenerator()
    
    // MARK: - Timers and Observers
    private var transcriptionTimer: Timer?
    private var autoSaveTimer: Timer?
    private var durationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupObservers()
        loadSessionHistory()
    }
    
    // MARK: - Session Management
    
    func startNewSession(encounterId: UUID, patientId: String? = nil) {
        // End any existing session
        if let current = currentSession {
            endSession(current)
        }
        
        // Create new session
        currentSession = EncounterSession(
            id: encounterId,
            startTime: Date(),
            patientId: patientId ?? "",
            transcript: ""
        )
        
        // Start transcription
        startRecording()
        
        // Setup auto-save
        startAutoSave()
    }
    
    func resumeSession(_ session: EncounterSession) {
        // guard session.isResumable else { return } // TODO: Add isResumable property
        
        currentSession = session
        // currentSession?.status = .resuming // TODO: Add status property
        
        // Add resumption marker to transcript
        let resumptionMarker = TranscriptionSegment(
            id: UUID(),
            text: "[Session resumed at \(Date().formatted())]",
            start: 0.0,
            end: 0.0
        )
        // currentSession?.transcriptionSegments.append(resumptionMarker) // TODO: Add segments array
        
        // Resume recording
        // if session.currentPhase == .mdm || session.currentPhase == .discharge {
        //     currentPhase = session.currentPhase
        // }
        
        // currentSession?.status = .active // TODO: Add status property
        startRecording()
    }
    
    func pauseSession(reason: String? = nil) {
        // guard let session = currentSession, session.status == .active else { return }
        guard currentSession != nil else { return }
        
        // currentSession?.status = .paused
        // currentSession?.currentPauseStart = Date()
        isPaused = true
        
        // Stop recording but keep session
        stopRecording(keepSession: true)
        
        // Add pause marker
        let pauseMarker = TranscriptionSegment(
            id: UUID(),
            text: "[Session paused\(reason != nil ? ": \(reason!)" : "")]",
            start: 0.0,
            end: 0.0
        )
        // currentSession?.transcriptionSegments.append(pauseMarker)
    }
    
    func unpauseSession() {
        // guard let session = currentSession, session.status == .paused else { return }
        guard currentSession != nil else { return }
        
        // if let pauseStart = session.currentPauseStart {
        //     let pausedInterval = EncounterSession.PausedInterval(
        //         startTime: pauseStart,
        //         endTime: Date(),
        //         reason: nil
        //     )
        //     currentSession?.pausedIntervals.append(pausedInterval)
        //     currentSession?.currentPauseStart = nil
        // }
        
        // currentSession?.status = .active
        isPaused = false
        startRecording()
    }
    
    func endSession(_ session: EncounterSession? = nil) {
        let sessionToEnd = session ?? currentSession
        guard let session = sessionToEnd else { return }
        
        // session.status = .completed
        // session.endTime = Date()
        
        // Save to intake
        saveSession(session)
        
        // Clear if it's the current session
        if currentSession?.id == session.id {
            currentSession = nil
            stopRecording(keepSession: false)
        }
    }
    
    // MARK: - Phase Management
    
    func transitionToPhase(_ newPhase: EncounterPhaseType) {
        guard currentSession != nil else { return }
        
        // Complete current phase
        // if let currentPhaseIndex = session.phases.firstIndex(where: { $0.type == currentPhase }) {
        //     session.phases[currentPhaseIndex].endTime = Date()
        // }
        
        // Start new phase
        // let phase = EncounterPhase(type: newPhase, startTime: Date())
        // session.phases.append(phase)
        currentPhase = newPhase
        
        // Add phase marker to transcript
        let phaseMarker = TranscriptionSegment(
            id: UUID(),
            text: "[Transitioning to: \(newPhase.rawValue)]",
            start: 0.0,
            end: 0.0
        )
        // currentSession?.transcriptionSegments.append(phaseMarker) // TODO: Add segments array
    }
    
    // MARK: - Transcription with Deduplication
    
    func startRecording() {
        isRecording = true

        // Start duration timer to update UI
        durationTimer?.invalidate()
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }

        // Start transcription service
        Task {
            do {
                try await transcriptionService.startTranscription()
                print("✅ Transcription started successfully")
            } catch {
                print("❌ Failed to start transcription: \(error)")
            }
        }
        startTranscriptionMonitoring()
    }
    
    func stopRecording(keepSession: Bool) {
        isRecording = false

        // Stop all timers
        transcriptionTimer?.invalidate()
        transcriptionTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil

        if !keepSession {
            // transcriptionService.finalizeTranscription() // TODO: Add this method
            Task {
                await transcriptionService.stopTranscription()
            }
        }
    }
    
    private func startTranscriptionMonitoring() {
        transcriptionTimer?.invalidate()
        // PROFESSIONAL: 200ms updates for smooth live transcription (5Hz refresh)
        transcriptionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                self.processTranscriptionUpdate()
            }
        }
    }
    
    @MainActor
    private func processTranscriptionUpdate() {
        // Get the current transcription from SpeechRecognitionService
        let currentText = transcriptionService.currentTranscription
        
        // ALWAYS update the UI with the latest transcription
        // This ensures the UI stays in sync with what's in the console
        transcriptionBuffer = currentText
        
        // Also update from RealtimeMedicalProcessor if it has content
        if !RealtimeMedicalProcessor.shared.liveTranscript.isEmpty {
            transcriptionBuffer = RealtimeMedicalProcessor.shared.liveTranscript
        }
        
        // Only process for deduplication if there's actual new content
        if !currentText.isEmpty && currentText != lastProcessedHash {
            lastProcessedHash = currentText
            // Extract truly new content for other processing if needed
            let newContent = extractNewContent(from: currentText)
            if !newContent.isEmpty {
                addTranscriptionSegment(newContent)
            }
        }
    }
    
    private func isDuplicate(_ text: String) -> Bool {
        // Strategy 1: Exact hash matching
        let currentHash = generateContentHash(text)
        // if currentSession?.transcriptionHashes.contains(currentHash) == true {
        //     return true
        // }
        
        // Strategy 2: Sliding window comparison
        if isInRecentBuffer(text) {
            return true
        }
        
        // Strategy 3: Similarity detection
        // if let lastSegment = currentSession?.transcriptionSegments.last {
        //     let similarity = calculateSimilarity(text, lastSegment.text)
        //     if similarity > similarityThreshold {
        //         return true
        //     }
        // }
        
        return false
    }
    
    private func generateContentHash(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        
        // Simple hash for now - replace with proper SHA256 when CryptoKit is imported
        return String(normalized.hashValue)
    }
    
    private func isInRecentBuffer(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return recentTextBuffer.contains { buffer in
            buffer.lowercased().contains(normalized) || normalized.contains(buffer.lowercased())
        }
    }
    
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        let set1 = Set(text1.lowercased().split(separator: " "))
        let set2 = Set(text2.lowercased().split(separator: " "))
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        guard !union.isEmpty else { return 0 }
        return Double(intersection.count) / Double(union.count)
    }
    
    private func extractNewContent(from text: String) -> String {
        // Get the last known position
        // let lastKnownText = currentSession?.transcriptionSegments.last?.text ?? ""
        let lastKnownText = ""
        
        // Find truly new content
        if !lastKnownText.isEmpty && text.contains(lastKnownText) {
            // Extract only the new portion
            if let range = text.range(of: lastKnownText) {
                // Check if there's actually content after the range
                if range.upperBound < text.endIndex {
                    let newPortion = String(text[range.upperBound...])
                    return newPortion.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func addTranscriptionSegment(_ text: String) {
        guard !text.isEmpty else { return }
        
        let segment = TranscriptionSegment(
            id: UUID(),
            text: text,
            start: Date().timeIntervalSince(currentSession?.startTime ?? Date()),
            end: Date().timeIntervalSince(currentSession?.startTime ?? Date())
        )
        
        // currentSession?.transcriptionSegments.append(segment)
        
        // Update deduplication tracking
        let hash = generateContentHash(text)
        // currentSession?.transcriptionHashes.insert(hash)
        
        // Update recent buffer
        recentTextBuffer.append(text)
        if recentTextBuffer.count > bufferSize {
            recentTextBuffer.removeFirst()
        }
        
        // Update editable transcript
        updateEditableTranscript()
    }
    
    // MARK: - Transcript Editing
    
    func updateEditableTranscript() {
        // editableTranscript = currentSession?.getCurrentTranscript() ?? ""
        editableTranscript = currentSession?.transcript ?? ""
    }
    
    func saveEditedTranscript(_ newText: String) {
        // currentSession?.editedTranscript = newText
        editableTranscript = newText
    }
    
    func lockTranscript() {
        // currentSession?.transcriptLocked = true
        if let session = currentSession {
            saveSession(session)
        }
    }
    
    // MARK: - Note Generation
    
    func generateNote(type: NoteType? = nil) {
        guard let session = currentSession else { return }
        
        let noteType = type ?? selectedNoteType
        
        // Use the actual transcription buffer which contains the real transcript
        let transcript = transcriptionBuffer.isEmpty ? editableTranscript : transcriptionBuffer
        
        // If there's no transcript, use the live transcript from RealtimeMedicalProcessor
        let finalTranscript = transcript.isEmpty ? RealtimeMedicalProcessor.shared.liveTranscript : transcript
        
        // If there's still no transcript, don't generate a note
        guard !finalTranscript.isEmpty else {
            print("❌ No transcript available for note generation")
            return
        }
        
        print("📝 Generating note from transcript: \(finalTranscript.prefix(100))...")
        
        Task {
            // Actually analyze the transcript
            let analyzer = MedicalVocabularyEnhancer.shared
            let analysis = analyzer.analyzeTranscript(transcript)
            
            // Create a proper ConversationAnalysis from the analyzed transcript
            let conversation = ConversationAnalysis(
                chiefComplaint: analysis.chiefComplaint.isEmpty ? extractChiefComplaint(from: transcript) : analysis.chiefComplaint,
                timing: analysis.timing,
                symptoms: analysis.symptoms,
                medicalHistory: analysis.medicalHistory,
                medications: analysis.medications,
                socialHistory: analysis.socialHistory,
                workup: analysis.workup,
                riskFactors: analysis.riskFactors,
                originalText: transcript
            )

            // Use unified AI service (automatically picks best available mode)
            let note = await MedicalAIService.shared.generateMedicalNote(
                from: conversation,
                noteType: noteType
            )
            
            await MainActor.run {
                self.generatedNote = note
                // self.currentSession?.generatedNote = note
                // self.currentSession?.selectedNoteType = noteType
                // self.currentSession?.noteMetadata = EncounterSession.NoteMetadata(
                //     generatedAt: Date(),
                //     noteType: noteType,
                //     wordCount: note.split(separator: " ").count,
                //     sections: [:],
                //     confidence: 0.95
                // )
            }
        }
    }
    
    func regenerateNoteWithType(_ type: NoteType) {
        selectedNoteType = type
        generateNote(type: type)
    }

    // MARK: - Generate Note from Pasted Text

    func generateNoteFromText() async {
        guard !transcriptionBuffer.isEmpty else { return }

        await MainActor.run {
            self.isGeneratingNote = true
        }

        print("📝 Generating note from pasted text...")

        // Analyze the pasted text
        let analyzer = MedicalVocabularyEnhancer.shared
        let analysis = analyzer.analyzeTranscript(transcriptionBuffer)

        // Create ConversationAnalysis
        let conversation = ConversationAnalysis(
            chiefComplaint: analysis.chiefComplaint.isEmpty ? extractChiefComplaint(from: transcriptionBuffer) : analysis.chiefComplaint,
            timing: analysis.timing,
            symptoms: analysis.symptoms,
            medicalHistory: analysis.medicalHistory,
            medications: analysis.medications,
            socialHistory: analysis.socialHistory,
            workup: analysis.workup,
            riskFactors: analysis.riskFactors,
            originalText: transcriptionBuffer
        )

        // Generate note using maximum quality offline AI
        let note = await MedicalAIService.shared.generateMedicalNote(
            from: conversation,
            noteType: selectedNoteType
        )

        await MainActor.run {
            self.generatedNote = note
            self.isGeneratingNote = false
        }

        print("✅ Note generated from pasted text")
    }
    
    // Helper function to extract chief complaint from transcript
    private func extractChiefComplaint(from transcript: String) -> String {
        // Look for common patterns in the transcript
        let patterns = [
            "complaining of", "here for", "presents with", "came in with",
            "chief complaint", "main concern", "problem is", "issue is",
            "pain in", "experiencing", "suffering from", "having"
        ]
        
        let sentences = transcript.components(separatedBy: CharacterSet(charactersIn: ".!?"))
        
        for sentence in sentences {
            let lowercased = sentence.lowercased()
            for pattern in patterns {
                if lowercased.contains(pattern) {
                    // Extract the relevant part
                    if let range = lowercased.range(of: pattern) {
                        let complaint = String(sentence[range.upperBound...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if !complaint.isEmpty {
                            return complaint
                        }
                    }
                }
            }
        }
        
        // If no pattern found, use the first meaningful sentence
        return sentences.first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Patient encounter"
    }
    
    // MARK: - Persistence (Core Data)

    private func saveSession(_ session: EncounterSession) {
        sessionHistory.append(session)

        // Save to Core Data for unlimited storage
        let persistence = PersistenceController.shared

        // Save transcript
        if !transcriptionBuffer.isEmpty {
            persistence.saveTranscript(transcriptionBuffer, for: session.id)
        }

        // Save generated note
        if let note = generatedNote, !note.isEmpty {
            persistence.saveGeneratedNote(
                note,
                type: selectedNoteType.rawValue,
                for: session.id
            )
        }

        // Also keep lightweight copy in UserDefaults for quick access (last 10 sessions only)
        let recentSessions = Array(sessionHistory.suffix(10))
        if let encoded = try? JSONEncoder().encode(recentSessions) {
            UserDefaults.standard.set(encoded, forKey: "RecentEncounterSessions")
        }

        print("✅ Session saved to Core Data: \(session.id)")
    }

    private func loadSessionHistory() {
        // Load recent sessions from UserDefaults for quick access
        if let data = UserDefaults.standard.data(forKey: "RecentEncounterSessions"),
           let sessions = try? JSONDecoder().decode([EncounterSession].self, from: data) {
            sessionHistory = sessions
            print("📂 Loaded \(sessions.count) recent sessions from UserDefaults")
        }

        // Full session data available from Core Data when needed
        print("💾 Full session history available in Core Data")
    }

    // MARK: - Core Data Retrieval

    func loadTranscript(for sessionId: UUID) -> String? {
        let persistence = PersistenceController.shared
        let fetchRequest = TranscriptEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "encounterId == %@", sessionId as CVarArg)

        do {
            let results = try persistence.container.viewContext.fetch(fetchRequest)
            return results.first?.content
        } catch {
            print("❌ Failed to load transcript: \(error)")
            return nil
        }
    }

    func loadNotes(for sessionId: UUID) -> [NoteEntity] {
        return PersistenceController.shared.fetchNotes(for: sessionId)
    }

    func loadAllSessionHistory() -> [EncounterSession] {
        // This would fetch all sessions from Core Data if needed
        // For now, return what we have in memory
        return sessionHistory
    }
    
    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                if let session = self.currentSession {
                    self.saveSession(session)
                }
            }
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Monitor transcription service updates
        // TODO: Add publisher for live transcript
        // transcriptionService.$liveTranscript
        //     .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        //     .sink { [weak self] _ in
        //         self?.processTranscriptionUpdate()
        //     }
        //     .store(in: &cancellables)
    }
}

// MARK: - End of file