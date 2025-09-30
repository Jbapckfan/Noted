import SwiftUI

struct VoiceCommandsHelpView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Voice Commands", systemImage: "mic.fill")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Say \"Hey NotedCore\" followed by:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Recording Commands
                    CommandSection(
                        title: "Recording",
                        commands: [
                            ("Start encounter", "Begin recording"),
                            ("End encounter", "Stop & save"),
                            ("Pause", "Pause recording"),
                            ("Resume", "Continue recording")
                        ]
                    )
                    
                    // Navigation Commands
                    CommandSection(
                        title: "Navigation",
                        commands: [
                            ("Next phase", "Go to next section"),
                            ("Previous phase", "Go back"),
                            ("Switch to exam", "Jump to exam")
                        ]
                    )
                    
                    // Utility Commands
                    CommandSection(
                        title: "Utilities",
                        commands: [
                            ("Add bookmark", "Mark important"),
                            ("Save note", "Save session"),
                            ("Help", "Show commands")
                        ]
                    )
                    
                    // Bluetooth Tip
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Pro Tip", systemImage: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        
                        Text("Connect Bluetooth headphones or a car mic for hands-free control!")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Status
                    HStack {
                        Image(systemName: VoiceCommandHandler.shared.isListening ? "dot.radiowaves.left.and.right" : "mic.slash")
                        Text(VoiceCommandHandler.shared.isListening ? "Voice Active" : "Voice Inactive")
                            .font(.caption)
                    }
                    .foregroundColor(VoiceCommandHandler.shared.isListening ? .green : .gray)
                }
                .padding()
            }
            .navigationTitle("Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct CommandSection: View {
    let title: String
    let commands: [(command: String, description: String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(commands, id: \.command) { item in
                    HStack(alignment: .top) {
                        Text("• \"\(item.command)\"")
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(item.description)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

#Preview {
    VoiceCommandsHelpView()
}