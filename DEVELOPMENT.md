# Development Guide for NotedCore

## Project Structure

```
NotedCore/
├── NotedCore/                      # Main app source code
│   ├── Models/                     # Data models and Core Data entities
│   ├── Views/                      # SwiftUI views (implicit organization)
│   ├── Services/                   # Core services (implicit organization)
│   │   ├── AudioCaptureService.swift
│   │   ├── SimpleWhisperService.swift
│   │   ├── MedicalSummarizerService.swift
│   │   └── LiveTranscriptionService.swift
│   ├── NotedCoreApp.swift         # App entry point
│   ├── ContentView.swift          # Main view
│   └── CoreAppState.swift         # Global app state
├── NotedCore.xcodeproj/            # Xcode project file
├── NotedCoreTests/                 # Unit tests
├── NotedCoreUITests/               # UI tests
└── Scripts/                        # Build and utility scripts
```

## Architecture Overview

### Core Components

#### 1. Audio Pipeline
```swift
AudioCaptureService → WhisperService → TranscriptionOptimizer → UI
```
- **AudioCaptureService**: Manages microphone input and audio streaming
- **SimpleWhisperService**: Handles on-device transcription via WhisperKit
- **LiveTranscriptionService**: Real-time transcription management

#### 2. Medical Processing
```swift
Transcription → MedicalSummarizer → ClinicalAnalyzer → Documentation
```
- **MedicalSummarizerService**: Generates medical summaries
- **EnhancedClinicalAnalyzer**: Extracts clinical entities
- **DocumentationQualityService**: Scores documentation quality

#### 3. State Management
- **CoreAppState**: Global singleton for app-wide state
- **@StateObject/@ObservedObject**: SwiftUI state management
- **Core Data**: Persistent storage for encounters and notes

## Development Workflow

### 1. Setting Up Development Environment

```bash
# Install development tools
brew install swiftlint
brew install xcbeautify

# Setup pre-commit hooks
cp Scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

### 2. Code Style Guidelines

#### Swift Style
- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistency
- Prefer `async/await` over completion handlers
- Use `@MainActor` for UI updates

#### Naming Conventions
```swift
// Classes/Structs: PascalCase
struct MedicalEncounter { }

// Functions/Variables: camelCase
func processTranscription() { }
let encounterCount = 0

// Constants: camelCase with descriptive names
let maximumRecordingDuration = 3600.0

// Protocols: PascalCase with descriptive names
protocol TranscriptionDelegate { }
```

### 3. Adding New Features

#### Step 1: Create Feature Branch
```bash
git checkout -b feature/your-feature-name
```

#### Step 2: Implement Feature
1. Add new files to appropriate groups
2. Follow existing patterns
3. Add unit tests
4. Update documentation

#### Step 3: Testing
```bash
# Run tests
xcodebuild test -scheme NotedCore

# Run specific test
xcodebuild test -scheme NotedCore -only-testing:NotedCoreTests/YourTestClass
```

#### Step 4: Submit PR
1. Ensure all tests pass
2. Update relevant documentation
3. Create pull request with description

## Key Development Areas

### 1. Audio Processing

#### Working with AudioCaptureService
```swift
class AudioCaptureService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var audioLevel: Float = 0
    
    func start() async throws {
        // Request permissions
        try await requestMicrophonePermission()
        
        // Configure audio session
        try configureAudioSession()
        
        // Start audio engine
        try setupAudioEngine()
    }
}
```

#### Adding Audio Features
- Modify `AudioCaptureService.swift` for audio pipeline changes
- Update `AudioUtilities.swift` for audio processing helpers
- Test with different audio inputs and sample rates

### 2. Transcription Enhancement

#### WhisperKit Integration
```swift
// In SimpleWhisperService.swift
func transcribe(audioPath: String) async throws -> String {
    guard let whisperKit = whisperKit else {
        throw TranscriptionError.modelNotLoaded
    }
    
    let result = try await whisperKit.transcribe(
        audioPath: audioPath,
        decodeOptions: DecodingOptions(
            language: "en",
            task: .transcribe
        )
    )
    
    return result.text
}
```

#### Custom Medical Models
- Add models to `Models/` directory
- Update `loadModels()` in relevant services
- Test with medical terminology

### 3. UI Development

#### SwiftUI Best Practices
```swift
struct MedicalNotesView: View {
    @StateObject private var viewModel = MedicalNotesViewModel()
    @EnvironmentObject var appState: CoreAppState
    
    var body: some View {
        NavigationView {
            // Content
        }
        .task {
            await viewModel.loadData()
        }
    }
}
```

#### Adding New Views
1. Create new SwiftUI view file
2. Add to appropriate navigation flow
3. Connect to CoreAppState if needed
4. Test on different device sizes

### 4. Medical Intelligence

#### Adding Medical Features
```swift
// In EnhancedClinicalAnalyzer.swift
static func extractMedicalEntities(_ text: String) -> MedicalEntities {
    // Extract symptoms
    let symptoms = extractSymptoms(from: text)
    
    // Extract medications
    let medications = extractMedications(from: text)
    
    // Extract diagnoses
    let diagnoses = extractDiagnoses(from: text)
    
    return MedicalEntities(
        symptoms: symptoms,
        medications: medications,
        diagnoses: diagnoses
    )
}
```

## Testing

### Unit Testing
```swift
import XCTest
@testable import NotedCore

class TranscriptionTests: XCTestCase {
    func testTranscriptionAccuracy() async throws {
        // Arrange
        let service = SimpleWhisperService()
        let audioFile = "test_audio.wav"
        
        // Act
        let result = try await service.transcribe(audioPath: audioFile)
        
        // Assert
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("expected text"))
    }
}
```

### UI Testing
```swift
import XCTest

class NotedCoreUITests: XCTestCase {
    func testRecordingFlow() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Test recording button
        let recordButton = app.buttons["Record"]
        XCTAssertTrue(recordButton.exists)
        
        recordButton.tap()
        
        // Verify recording state
        XCTAssertTrue(app.staticTexts["Recording..."].exists)
    }
}
```

## Performance Optimization

### Memory Management
- Use `weak` references for delegates
- Properly clean up audio resources
- Monitor memory usage with Instruments

### Audio Processing
- Use buffer sizes appropriate for real-time processing
- Implement audio level metering efficiently
- Cache processed audio when possible

### UI Responsiveness
- Use `@MainActor` for UI updates
- Implement lazy loading for large lists
- Use `task` modifier for async operations

## Debugging

### Common Issues

#### Audio Not Recording
```swift
// Check permissions
AVAudioApplication.shared.recordPermission

// Verify audio session
AVAudioSession.sharedInstance().category

// Check audio route
AVAudioSession.sharedInstance().currentRoute
```

#### Transcription Failures
```swift
// Enable WhisperKit verbose logging
WhisperKit.log.level = .debug

// Check model loading
print("Model loaded: \(whisperKit != nil)")

// Verify audio format
print("Sample rate: \(audioFormat.sampleRate)")
```

### Debugging Tools
- **Xcode Debugger**: Breakpoints and variable inspection
- **Instruments**: Performance profiling
- **Console**: Print debugging and logs
- **Network Link Conditioner**: Test poor network conditions

## Deployment

### Building for Release
```bash
# Archive for App Store
xcodebuild archive \
    -project NotedCore.xcodeproj \
    -scheme NotedCore \
    -archivePath NotedCore.xcarchive

# Export IPA
xcodebuild -exportArchive \
    -archivePath NotedCore.xcarchive \
    -exportPath NotedCore_Export \
    -exportOptionsPlist ExportOptions.plist
```

### Code Signing
1. Configure signing in Xcode project settings
2. Ensure valid provisioning profiles
3. Set appropriate entitlements

## Contributing

### Pull Request Process
1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Update documentation
5. Submit PR with description

### Code Review Checklist
- [ ] Code follows style guidelines
- [ ] Tests pass and coverage maintained
- [ ] Documentation updated
- [ ] No warnings or errors
- [ ] Performance impact considered
- [ ] Security implications reviewed

## Resources

### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [WhisperKit Documentation](https://github.com/argmaxinc/WhisperKit)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)

### Tools
- [Xcode](https://developer.apple.com/xcode/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Swift Package Index](https://swiftpackageindex.com/)

### Community
- [Swift Forums](https://forums.swift.org/)
- [iOS Dev Weekly](https://iosdevweekly.com/)
- [Ray Wenderlich](https://www.raywenderlich.com/)