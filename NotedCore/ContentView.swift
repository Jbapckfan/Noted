import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var appState: CoreAppState
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var summarizerService = ProductionMedicalSummarizerService()
    @State private var currentTranscript = ""
    @State private var generatedNote = ""
    
    var body: some View {
        // Professional medical scribe interface
        ProfessionalEncounterView()
            .onAppear {
                initializeEliteSystem()
            }
    }
    
    private func initializeEliteSystem() {
        Task {
            // Initialize all systems
            print("Initializing Elite Medical Scribe System...")
            
            // Load medical knowledge base
            if !true {
                print("Loading medical knowledge base...")
            }
            
            // Verify accuracy
            if ProcessInfo.processInfo.environment["RUN_ACCURACY_TEST"] == "1" {
                await runAccuracyTest()
            }
        }
    }
    
    private func runAccuracyTest() async {
        // TODO: Implement accuracy testing
        // let framework = String()
        // testResults = await framework.runComprehensiveTests()
        // 
        // if let results = testResults {
        //     print(results.summary)
        //     
        //     // Alert if accuracy is below threshold
        //     if results.overallAccuracy < 0.85 {
        //         showingAccuracyReport = true
        //     }
        // }
    }
}

struct ContentViewQualityIndicator: View {
    let title: String
    let value: Float
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(value))
                    .stroke(color, lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: value)
            }
            .frame(width: 50, height: 50)
            
            Text("\(Int(value * 100))%")
                .font(.caption2)
                .bold()
        }
    }
}

// MARK: - Voice Command Delegate
// Temporarily disabled until VoiceCommand protocol is fixed