import SwiftUI

/// View for testing medical note generation with pasted transcripts
/// Allows testing summarization quality without recording
struct TranscriptTestView: View {
    @State private var pastedTranscript: String = ""
    @State private var generatedNote: String = ""
    @State private var selectedNoteType: NoteType = .soap
    @State private var isGenerating = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Input Section
                    GroupBox(label: Label("Paste Transcript Here", systemImage: "text.quote")) {
                        TextEditor(text: $pastedTranscript)
                            .frame(minHeight: 200)
                            .font(.body)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )

                        HStack {
                            Text("\(pastedTranscript.count) characters")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("Clear") {
                                pastedTranscript = ""
                                generatedNote = ""
                            }
                            .font(.caption)
                        }
                        .padding(.top, 4)
                    }

                    // Note Type Selection
                    GroupBox(label: Label("Note Type", systemImage: "doc.text")) {
                        Picker("Note Type", selection: $selectedNoteType) {
                            ForEach(NoteType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // Generate Button
                    Button(action: generateNote) {
                        HStack {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("Generating...")
                            } else {
                                Image(systemName: "wand.and.stars")
                                Text("Generate Medical Note")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canGenerate ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!canGenerate || isGenerating)

                    // Output Section
                    if !generatedNote.isEmpty {
                        GroupBox(label: Label("Generated Note", systemImage: "doc.richtext")) {
                            ScrollView {
                                Text(generatedNote)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 400)

                            HStack {
                                Button(action: copyNote) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }

                                Spacer()

                                ShareLink(item: generatedNote) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            .padding(.top, 8)
                        }
                    }

                    // Sample Transcripts
                    GroupBox(label: Label("Sample Transcripts", systemImage: "text.book.closed")) {
                        VStack(alignment: .leading, spacing: 12) {
                            SampleButton(title: "Chest Pain (Complete)", transcript: chestPainSample)
                            SampleButton(title: "Headache (Brief)", transcript: headacheSample)
                            SampleButton(title: "Follow-up (Minimal Info)", transcript: minimalSample)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Test Summarization")
            .alert("Error", isPresented: $showError) {
                Button("OK") {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canGenerate: Bool {
        !pastedTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func generateNote() {
        guard canGenerate else { return }

        isGenerating = true
        errorMessage = ""

        Task {
            do {
                // Analyze the transcript
                let analyzer = MedicalVocabularyEnhancer.shared
                let analysis = analyzer.analyzeTranscript(pastedTranscript)

                // Check if we have enough information
                guard !analysis.chiefComplaint.isEmpty || !analysis.symptoms.isEmpty else {
                    await MainActor.run {
                        errorMessage = "Cannot generate note: Transcript does not contain sufficient medical information (no chief complaint or symptoms detected)."
                        showError = true
                        isGenerating = false
                    }
                    return
                }

                // Create conversation analysis
                let conversation = ConversationAnalysis(
                    chiefComplaint: analysis.chiefComplaint.isEmpty ? "Not specified" : analysis.chiefComplaint,
                    timing: analysis.timing,
                    symptoms: analysis.symptoms,
                    medicalHistory: analysis.medicalHistory,
                    medications: analysis.medications,
                    socialHistory: analysis.socialHistory,
                    workup: analysis.workup,
                    riskFactors: analysis.riskFactors,
                    originalText: pastedTranscript
                )

                // Generate note
                let note: String
                if #available(iOS 18.1, macOS 15.1, *) {
                    note = await AppleIntelligenceNoteGenerator.shared.generateMedicalNote(
                        from: conversation,
                        noteType: selectedNoteType
                    )
                } else {
                    note = MedicalNoteGenerator().generateNote(
                        from: conversation,
                        noteType: selectedNoteType
                    )
                }

                await MainActor.run {
                    generatedNote = note
                    isGenerating = false
                }

            } catch {
                await MainActor.run {
                    errorMessage = "Error generating note: \(error.localizedDescription)"
                    showError = true
                    isGenerating = false
                }
            }
        }
    }

    private func copyNote() {
        UIPasteboard.general.string = generatedNote
    }

    // MARK: - Sample Button

    @ViewBuilder
    private func SampleButton(title: String, transcript: String) -> some View {
        Button(action: {
            pastedTranscript = transcript
            generatedNote = ""
        }) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Image(systemName: "arrow.down.doc")
                    .font(.caption)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Sample Transcripts

    private var chestPainSample: String {
        """
        Good morning, what brings you in today?

        I woke up this morning around 5 AM with really bad chest pain and I couldn't catch my breath.

        Tell me more about the chest pain. When exactly did it start?

        It started about 2 hours ago when I woke up. The pain is right in the center of my chest, feels like pressure, like someone sitting on my chest. It's about an 8 out of 10 in severity.

        Does the pain go anywhere else?

        Yes, it radiates down my left arm and into my jaw.

        Any nausea, sweating, or other symptoms?

        Yes, I feel nauseous and I've been sweating a lot. I also feel short of breath, can't take a deep breath without the pain getting worse.

        Do you have any medical history I should know about?

        I have high blood pressure and high cholesterol. I take lisinopril 10 milligrams daily and atorvastatin 20 milligrams at night.

        Do you smoke?

        I used to smoke for 15 years but quit 2 years ago. I still vape occasionally.

        Any family history of heart disease?

        Yes, my father had a heart attack at age 55.

        Any allergies?

        Penicillin - I get hives.
        """
    }

    private var headacheSample: String {
        """
        What's going on today?

        I have a really bad headache. Started yesterday afternoon.

        Where is the pain?

        Mostly on the right side of my head, behind my eye.

        Any other symptoms?

        I feel nauseous and the light bothers me.

        Have you had headaches like this before?

        Yes, I get migraines sometimes.

        What do you usually take for them?

        Ibuprofen 800 milligrams.
        """
    }

    private var minimalSample: String {
        """
        Hi, what can I help you with?

        I'm just here for a follow-up visit.

        Okay, how have you been feeling?

        Pretty good, no major complaints.
        """
    }
}

#Preview {
    TranscriptTestView()
}