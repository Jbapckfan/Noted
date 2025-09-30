import SwiftUI
import AVFoundation

struct ProfessionalEncounterView: View {
    @StateObject private var sessionManager = EncounterSessionManager.shared
    @StateObject private var speechService = SpeechRecognitionService.shared
    @StateObject private var summarizerService = ProductionMedicalSummarizerService()
    @State private var showingNotePreview = false
    @State private var animateRecording = false

    var body: some View {
        ZStack {
            // Clean white/dark background
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Minimal Header
                modernHeader

                // Main Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Recording Button - Hero Element
                        recordingButton

                        // Live Transcription - ALWAYS VISIBLE
                        transcriptionSection

                        // Generated Note
                        if sessionManager.generatedNote != nil {
                            generatedNoteSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showingNotePreview) {
            NoteDetailView(note: sessionManager.generatedNote ?? "")
        }
    }

    // MARK: - Modern Header
    private var modernHeader: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                // App Icon/Logo Area
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 2) {
                    Text("NotedCore")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(sessionManager.isRecording ? Color.green : Color.gray.opacity(0.5))
                            .frame(width: 6, height: 6)

                        Text(sessionManager.isRecording ? "Recording" : "Ready")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Note Type Selector
                Menu {
                    Picker("Note Type", selection: $sessionManager.selectedNoteType) {
                        ForEach(NoteType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(sessionManager.selectedNoteType.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.blue)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Recording Button (Hero)
    private var recordingButton: some View {
        VStack(spacing: 16) {
            ZStack {
                // Animated rings when recording
                if sessionManager.isRecording {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.6), Color.red.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 120 + CGFloat(i * 30), height: 120 + CGFloat(i * 30))
                            .scaleEffect(animateRecording ? 1.3 : 1.0)
                            .opacity(animateRecording ? 0.0 : 0.8)
                            .animation(
                                Animation.easeOut(duration: 1.5)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.3),
                                value: animateRecording
                            )
                    }
                }

                // Main button
                Button(action: {
                    toggleRecording()
                }) {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: sessionManager.isRecording ?
                                        [Color.red, Color.red.opacity(0.8)] :
                                        [Color.blue, Color.cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .shadow(
                                color: (sessionManager.isRecording ? Color.red : Color.blue).opacity(0.4),
                                radius: sessionManager.isRecording ? 20 : 15,
                                x: 0,
                                y: 8
                            )

                        // Icon
                        Image(systemName: sessionManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            .frame(height: 140)
            .onAppear {
                if sessionManager.isRecording {
                    animateRecording = true
                }
            }
            .onChange(of: sessionManager.isRecording) { isRecording in
                animateRecording = isRecording
            }

            // Instructions
            Text(sessionManager.isRecording ? "Tap to stop recording" : "Tap to start recording")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Transcription Section
    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)

                Text("Live Transcription")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                if !sessionManager.transcriptionBuffer.isEmpty {
                    Text("\(sessionManager.transcriptionBuffer.count) chars")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                }
            }

            // Text Editor Card
            ZStack(alignment: .topLeading) {
                // Card background
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                Color.gray.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

                // TextEditor
                TextEditor(text: $sessionManager.transcriptionBuffer)
                    .font(.system(.body, design: .rounded))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(16)
                    .frame(minHeight: 180)

                // Placeholder
                if sessionManager.transcriptionBuffer.isEmpty && !sessionManager.isRecording {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48, weight: .light))
                            .foregroundColor(.gray.opacity(0.3))

                        Text("Paste medical transcript here")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.secondary)

                        Text("Or tap the record button above")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 220)

            // Generate Button
            if !sessionManager.transcriptionBuffer.isEmpty && !sessionManager.isRecording {
                Button(action: {
                    Task {
                        await sessionManager.generateNoteFromText()
                    }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))

                        Text("Generate Medical Note")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))

                        Spacer()

                        if sessionManager.isGeneratingNote {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.9)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 20))
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: Color.blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(sessionManager.isGeneratingNote)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.3), value: sessionManager.transcriptionBuffer.isEmpty)
            }

            // Clear Button
            if !sessionManager.transcriptionBuffer.isEmpty && !sessionManager.isRecording {
                Button(action: {
                    withAnimation {
                        sessionManager.transcriptionBuffer = ""
                        sessionManager.generatedNote = nil
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                        Text("Clear Transcript")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    // MARK: - Generated Note Section
    private var generatedNoteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.green)

                Text("Generated Note")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                // Success badge
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Complete")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }

            // Note Preview Card
            VStack(alignment: .leading, spacing: 16) {
                ScrollView {
                    Text(sessionManager.generatedNote ?? "")
                        .font(.system(.body, design: .default))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)

                Divider()

                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: {
                        showingNotePreview = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye")
                                .font(.system(size: 14, weight: .medium))
                            Text("View Full")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: {
                        UIPasteboard.general.string = sessionManager.generatedNote
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                            Text("Copy")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(
                                Color.gray.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
            )
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4), value: sessionManager.generatedNote != nil)
    }

    // MARK: - Actions
    private func toggleRecording() {
        if sessionManager.isRecording {
            sessionManager.stopRecording(keepSession: true)
        } else {
            Task {
                await sessionManager.startRecording()
            }
        }
    }
}

// MARK: - Scale Button Style
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Note Detail View
struct NoteDetailView: View {
    let note: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(note)
                    .font(.system(.body, design: .default))
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Medical Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        UIPasteboard.general.string = note
                    }) {
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
}

#Preview {
    ProfessionalEncounterView()
}