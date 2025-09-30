import SwiftUI

struct SettingsView: View {
    @StateObject private var groqService = GroqService()
    @State private var apiKey = ""
    @State private var showAPIKeySaved = false
    @State private var selectedModel: GroqService.Model = .llamaScout
    @State private var enableStreaming = true
    @State private var maxTokens = 500
    @AppStorage("groq_api_key") private var savedAPIKey = ""
    @AppStorage("groq_model") private var savedModel = "llama-3.2-3b-preview"
    @AppStorage("groq_streaming") private var savedStreaming = true
    @AppStorage("groq_max_tokens") private var savedMaxTokens = 500
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Groq API Configuration
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Groq API Key")
                            .font(.headline)
                        
                        Text("Get your free API key at https://console.groq.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter API Key", text: $apiKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onAppear {
                                apiKey = savedAPIKey
                            }
                        
                        HStack {
                            Button("Save API Key") {
                                savedAPIKey = apiKey
                                groqService.setAPIKey(apiKey)
                                showAPIKeySaved = true
                                
                                // Hide feedback after 2 seconds
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showAPIKeySaved = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(apiKey.isEmpty)
                            
                            if showAPIKeySaved {
                                Label("Saved!", systemImage: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .transition(.scale)
                            }
                        }
                    }
                    .padding(.vertical, 5)
                } header: {
                    Label("AI Configuration", systemImage: "brain")
                } footer: {
                    Text("Free tier: 30 requests/minute, up to 8K tokens")
                        .font(.caption)
                }
                
                // MARK: - Model Selection
                Section {
                    Picker("AI Model", selection: $selectedModel) {
                        Text("Fast Outline (3B)")
                            .tag(GroqService.Model.llamaScout)
                        Text("Ultra-Fast (1B)")
                            .tag(GroqService.Model.llamaInstant)
                        Text("Balanced (Mixtral)")
                            .tag(GroqService.Model.mixtral)
                        Text("Quality (8B)")
                            .tag(GroqService.Model.llamaMedium)
                    }
                    .onChange(of: selectedModel) { newValue in
                        savedModel = newValue.rawValue
                    }
                    .onAppear {
                        if let model = GroqService.Model(rawValue: savedModel) {
                            selectedModel = model
                        }
                    }
                    
                    HStack {
                        Text("Context Window:")
                        Spacer()
                        Text("\(selectedModel.contextWindow) tokens")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Speed:")
                        Spacer()
                        Text(selectedModel.description)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Model Settings")
                } footer: {
                    Text("Faster models use fewer tokens but may be less accurate")
                        .font(.caption)
                }
                
                // MARK: - Advanced Settings
                Section {
                    Toggle("Enable Streaming", isOn: $enableStreaming)
                        .onChange(of: enableStreaming) { newValue in
                            savedStreaming = newValue
                        }
                    
                    VStack(alignment: .leading) {
                        Text("Max Response Tokens: \(maxTokens)")
                        Slider(value: Binding(
                            get: { Double(maxTokens) },
                            set: { maxTokens = Int($0) }
                        ), in: 100...1000, step: 100)
                        .onChange(of: maxTokens) { newValue in
                            savedMaxTokens = newValue
                        }
                    }
                } header: {
                    Text("Advanced Settings")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("AI Provider")
                        Spacer()
                        Text("Groq LPU")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Transcription")
                        Spacer()
                        Text("WhisperKit (Local)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("About")
                }
                
                // MARK: - Reset
                Section {
                    Button(role: .destructive) {
                        apiKey = ""
                        savedAPIKey = ""
                        groqService.setAPIKey("")
                    } label: {
                        Label("Clear API Key", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}