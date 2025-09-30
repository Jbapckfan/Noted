import SwiftUI
import Speech

struct SimpleRecordingView: View {
    @StateObject private var sessionManager = EncounterSessionManager.shared
    @StateObject private var speechService = SpeechRecognitionService.shared
    @State private var showingNote = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Status Section
                VStack(spacing: 8) {
                    Text(sessionManager.isRecording ? "Recording" : "Ready")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(sessionManager.isRecording ? .red : .primary)

                    if sessionManager.isRecording {
                        Text(formatDuration())
                            .font(.headline)
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 20)

                // Record Button
                Button(action: toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(sessionManager.isRecording ? Color.red : Color.blue)
                            .frame(width: 120, height: 120)

                        Image(systemName: sessionManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(sessionManager.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: sessionManager.isRecording)

                // Live Transcription
                if sessionManager.isRecording || !sessionManager.transcriptionBuffer.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Live Transcription")
                                .font(.headline)
                            Spacer()
                            if sessionManager.isRecording {
                                Image(systemName: "dot.radiowaves.left.and.right")
                                    .foregroundColor(.red)
                            }
                        }

                        ScrollView {
                            Text(sessionManager.transcriptionBuffer.isEmpty ? "Listening..." : sessionManager.transcriptionBuffer)
                                .font(.body)
                                .foregroundColor(sessionManager.transcriptionBuffer.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 20) {
                    Button(action: { showingNote = true }) {
                        Label("Generate Note", systemImage: "doc.text")
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(sessionManager.transcriptionBuffer.isEmpty)

                    Button(action: clearTranscription) {
                        Label("Clear", systemImage: "trash")
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(sessionManager.transcriptionBuffer.isEmpty)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("NotedCore")
            .sheet(isPresented: $showingNote) {
                if let note = sessionManager.generatedNote {
                    NoteView(note: note)
                }
            }
        }
        .onAppear {
            requestPermissions()
        }
    }

    private func toggleRecording() {
        if sessionManager.isRecording {
            sessionManager.stopRecording(keepSession: false)
            if !sessionManager.transcriptionBuffer.isEmpty {
                sessionManager.generateNote()
            }
        } else {
            // Start new session
            sessionManager.startNewSession(encounterId: UUID(), patientId: nil)
        }
    }

    private func clearTranscription() {
        sessionManager.transcriptionBuffer = ""
        sessionManager.editableTranscript = ""
        sessionManager.generatedNote = nil
    }

    private func formatDuration() -> String {
        guard let startTime = sessionManager.currentSession?.startTime else { return "00:00" }
        let duration = Int(Date().timeIntervalSince(startTime))
        let minutes = duration / 60
        let seconds = duration % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func requestPermissions() {
        Task {
            do {
                try await speechService.requestPermissions()
            } catch {
                print("Failed to get permissions: \(error)")
            }
        }
    }
}

struct NoteView: View {
    let note: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                Text(note)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Generated Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}