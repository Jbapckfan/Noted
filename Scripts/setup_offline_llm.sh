#!/bin/bash

# Setup script for offline medical summarization
echo "🚀 Setting up offline medical summarization..."

# Option 1: Use llama.cpp (runs on CPU, works on Mac)
echo "📦 Option 1: llama.cpp with Phi-3 or Llama models"
echo "This runs entirely on CPU, no GPU needed"

# Clone llama.cpp if not exists
if [ ! -d "llama.cpp" ]; then
    git clone https://github.com/ggerganov/llama.cpp
    cd llama.cpp
    make
    cd ..
fi

# Download a small model (Phi-3 mini - 2.8GB)
echo "📥 Downloading Phi-3 Mini (2.8GB)..."
if [ ! -f "models/phi-3-mini.gguf" ]; then
    mkdir -p models
    # Use Phi-3 mini quantized for efficiency
    curl -L "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf" \
         -o models/phi-3-mini.gguf
fi

echo "✅ Model downloaded"

# Create simple Swift wrapper
cat > simple_offline_llm.swift << 'EOF'
#!/usr/bin/env swift

import Foundation

class OfflineLLM {
    private let modelPath: String
    private let llamaPath: String
    
    init() {
        self.modelPath = "models/phi-3-mini.gguf"
        self.llamaPath = "./llama.cpp/main"
    }
    
    func summarize(_ conversation: String) -> String {
        let prompt = """
        Summarize this medical conversation into a clinical note with these sections:
        - Chief Complaint (one line)
        - HPI (2-3 lines)
        - Medications
        - Assessment
        
        Conversation:
        \(conversation)
        
        Clinical Note:
        """
        
        // Run llama.cpp
        let task = Process()
        task.executableURL = URL(fileURLWithPath: llamaPath)
        task.arguments = [
            "-m", modelPath,
            "-p", prompt,
            "-n", "200",  // Max tokens
            "--temp", "0.1",  // Low temperature for consistency
            "--top-k", "10",
            "--top-p", "0.9",
            "--repeat-penalty", "1.1"
        ]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return cleanOutput(output)
        } catch {
            return "Error: \(error)"
        }
    }
    
    private func cleanOutput(_ output: String) -> String {
        // Extract just the generated summary
        var lines = output.split(separator: "\n").map(String.init)
        
        // Find where the actual summary starts
        if let startIndex = lines.firstIndex(where: { $0.contains("Chief Complaint") || $0.contains("CC:") }) {
            lines = Array(lines[startIndex...])
        }
        
        return lines.joined(separator: "\n")
    }
}

// Test it
let llm = OfflineLLM()

let testConversation = """
Doctor: What brings you in today?
Patient: I've had chest pain for 3 days. It's getting worse.
Doctor: Any other symptoms?
Patient: Shortness of breath when I walk upstairs.
Doctor: Are you on any medications?
Patient: Just aspirin.
"""

print("🏥 Testing Offline Medical Summarization")
print("=" * 40)
print("Input conversation:")
print(testConversation)
print("\n📝 Generated Summary:")
print(llm.summarize(testConversation))
EOF

chmod +x simple_offline_llm.swift

echo "
✅ Setup complete! You now have:

1. llama.cpp - Fast C++ inference engine
2. Phi-3 Mini model - 2.8GB, runs on CPU
3. Swift wrapper - simple_offline_llm.swift

To test:
./simple_offline_llm.swift

This gives you:
• 100% offline operation
• No API keys needed
• Runs on Mac CPU (no GPU required)
• Fast enough for real-time use
• Privacy-preserving (nothing leaves device)
"