import Foundation
import SwiftUI

@MainActor
class EDEnvironmentManager: ObservableObject {
    
    // MARK: - Published Properties
    @Published var currentEnvironment: EDEnvironment?
    @Published var availableEnvironments: [EDEnvironment] = []
    @Published var selectedBed: BedLocation?
    
    // MARK: - Private Properties
    private let userDefaults = UserDefaults.standard
    private let environmentKey = "EDEnvironments"
    private let currentEnvironmentKey = "CurrentEDEnvironment"
    
    init() {
        loadEnvironments()
        createDefaultEnvironments()
    }
    
    // MARK: - Environment Management
    func createEnvironment(name: String, bedLocations: [BedLocation]) -> EDEnvironment {
        let environment = EDEnvironment(
            id: UUID(),
            name: name,
            bedLocations: bedLocations,
            createdDate: Date()
        )
        
        availableEnvironments.append(environment)
        saveEnvironments()
        
        return environment
    }
    
    func setCurrentEnvironment(_ environment: EDEnvironment) {
        currentEnvironment = environment
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(environment) {
            userDefaults.set(data, forKey: currentEnvironmentKey)
        }
    }
    
    func deleteEnvironment(_ environment: EDEnvironment) {
        availableEnvironments.removeAll { $0.id == environment.id }
        
        if currentEnvironment?.id == environment.id {
            currentEnvironment = availableEnvironments.first
        }
        
        saveEnvironments()
    }
    
    // MARK: - Bed Selection
    func selectBed(_ bed: BedLocation) {
        selectedBed = bed
    }
    
    func getBedByVoiceCommand(_ bedIdentifier: String) -> BedLocation? {
        guard let environment = currentEnvironment else { return nil }
        
        // Try exact match first
        if let bed = environment.bedLocations.first(where: { $0.voiceIdentifier.lowercased() == bedIdentifier.lowercased() }) {
            return bed
        }
        
        // Try partial match
        return environment.bedLocations.first { bed in
            bed.displayName.lowercased().contains(bedIdentifier.lowercased()) ||
            bed.voiceIdentifier.lowercased().contains(bedIdentifier.lowercased())
        }
    }
    
    // MARK: - Persistence
    func saveEnvironments() {
        if let data = try? JSONEncoder().encode(availableEnvironments) {
            userDefaults.set(data, forKey: environmentKey)
        }
    }
    
    private func loadEnvironments() {
        if let data = userDefaults.data(forKey: environmentKey),
           let environments = try? JSONDecoder().decode([EDEnvironment].self, from: data) {
            availableEnvironments = environments
        }
        
        if let data = userDefaults.data(forKey: currentEnvironmentKey),
           let environment = try? JSONDecoder().decode(EDEnvironment.self, from: data) {
            currentEnvironment = environment
        }
    }
    
    // MARK: - Default Environments
    private func createDefaultEnvironments() {
        if availableEnvironments.isEmpty {
            // Your custom environment
            let drAlfordED = createDrAlfordEnvironment()
            availableEnvironments.append(drAlfordED)
            
            // Generic ED
            let genericED = createGenericEDEnvironment()
            availableEnvironments.append(genericED)
            
            // Set Dr. Alford's as current
            currentEnvironment = drAlfordED
            
            saveEnvironments()
        }
    }
    
    private func createDrAlfordEnvironment() -> EDEnvironment {
        let bedLocations: [BedLocation] = [
            // Trauma Bays
            BedLocation(id: UUID(), displayName: "Trauma 1", voiceIdentifier: "trauma 1", category: .trauma, sortOrder: 1),
            BedLocation(id: UUID(), displayName: "Trauma 2", voiceIdentifier: "trauma 2", category: .trauma, sortOrder: 2),
            
            // ED Beds
            BedLocation(id: UUID(), displayName: "ED Bed 3", voiceIdentifier: "bed 3", category: .acute, sortOrder: 3),
            BedLocation(id: UUID(), displayName: "ED Bed 4", voiceIdentifier: "bed 4", category: .acute, sortOrder: 4),
            BedLocation(id: UUID(), displayName: "ED Bed 5", voiceIdentifier: "bed 5", category: .acute, sortOrder: 5),
            BedLocation(id: UUID(), displayName: "ED Bed 6", voiceIdentifier: "bed 6", category: .acute, sortOrder: 6),
            BedLocation(id: UUID(), displayName: "ED Bed 7", voiceIdentifier: "bed 7", category: .acute, sortOrder: 7),
            BedLocation(id: UUID(), displayName: "ED Bed 8", voiceIdentifier: "bed 8", category: .acute, sortOrder: 8),
            BedLocation(id: UUID(), displayName: "ED Bed 9", voiceIdentifier: "bed 9", category: .acute, sortOrder: 9),
            
            // Psych
            BedLocation(id: UUID(), displayName: "Psych Bed 10", voiceIdentifier: "psych bed", category: .psych, sortOrder: 10),
            
            // More ED Beds (no 13)
            BedLocation(id: UUID(), displayName: "ED Bed 11", voiceIdentifier: "bed 11", category: .acute, sortOrder: 11),
            BedLocation(id: UUID(), displayName: "ED Bed 12", voiceIdentifier: "bed 12", category: .acute, sortOrder: 12),
            BedLocation(id: UUID(), displayName: "ED Bed 14", voiceIdentifier: "bed 14", category: .acute, sortOrder: 14),
            
            // Fast Track
            BedLocation(id: UUID(), displayName: "Fast Track 1", voiceIdentifier: "fast track 1", category: .fastTrack, sortOrder: 21),
            BedLocation(id: UUID(), displayName: "Fast Track 2", voiceIdentifier: "fast track 2", category: .fastTrack, sortOrder: 22),
            BedLocation(id: UUID(), displayName: "Fast Track 3", voiceIdentifier: "fast track 3", category: .fastTrack, sortOrder: 23)
        ]
        
        return EDEnvironment(
            id: UUID(),
            name: "Dr. Alford's ED",
            bedLocations: bedLocations,
            createdDate: Date()
        )
    }
    
    private func createGenericEDEnvironment() -> EDEnvironment {
        let bedLocations: [BedLocation] = [
            BedLocation(id: UUID(), displayName: "Trauma 1", voiceIdentifier: "trauma 1", category: .trauma, sortOrder: 1),
            BedLocation(id: UUID(), displayName: "Trauma 2", voiceIdentifier: "trauma 2", category: .trauma, sortOrder: 2),
            BedLocation(id: UUID(), displayName: "ED 1", voiceIdentifier: "bed 1", category: .acute, sortOrder: 3),
            BedLocation(id: UUID(), displayName: "ED 2", voiceIdentifier: "bed 2", category: .acute, sortOrder: 4),
            BedLocation(id: UUID(), displayName: "ED 3", voiceIdentifier: "bed 3", category: .acute, sortOrder: 5),
            BedLocation(id: UUID(), displayName: "ED 4", voiceIdentifier: "bed 4", category: .acute, sortOrder: 6),
            BedLocation(id: UUID(), displayName: "ED 5", voiceIdentifier: "bed 5", category: .acute, sortOrder: 7),
            BedLocation(id: UUID(), displayName: "Fast Track 1", voiceIdentifier: "fast track 1", category: .fastTrack, sortOrder: 8),
            BedLocation(id: UUID(), displayName: "Fast Track 2", voiceIdentifier: "fast track 2", category: .fastTrack, sortOrder: 9)
        ]
        
        return EDEnvironment(
            id: UUID(),
            name: "Generic ED",
            bedLocations: bedLocations,
            createdDate: Date()
        )
    }
}

// MARK: - ED Environment Model
struct EDEnvironment: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    var name: String
    var bedLocations: [BedLocation]
    let createdDate: Date
    
    var bedsByCategory: [BedCategory: [BedLocation]] {
        Dictionary(grouping: bedLocations.sorted { $0.sortOrder < $1.sortOrder }, by: \.category)
    }
    
    static func == (lhs: EDEnvironment, rhs: EDEnvironment) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Bed Location Model
struct BedLocation: Codable, Identifiable, Hashable {
    let id: UUID
    var displayName: String
    var voiceIdentifier: String
    var category: BedCategory
    var sortOrder: Int
    
    var shortName: String {
        displayName.replacingOccurrences(of: "ED Bed ", with: "")
                  .replacingOccurrences(of: "Fast Track ", with: "FT")
                  .replacingOccurrences(of: "Trauma ", with: "T")
                  .replacingOccurrences(of: "Psych Bed ", with: "Psych")
    }
}

// MARK: - Bed Category
enum BedCategory: String, CaseIterable, Codable {
    case trauma = "trauma"
    case acute = "acute"
    case psych = "psych"
    case fastTrack = "fastTrack"
    
    var displayName: String {
        switch self {
        case .trauma: return "Trauma"
        case .acute: return "Acute Care"
        case .psych: return "Psychiatric"
        case .fastTrack: return "Fast Track"
        }
    }
    
    var color: Color {
        switch self {
        case .trauma: return .red
        case .acute: return .blue
        case .psych: return .purple
        case .fastTrack: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .trauma: return "exclamationmark.triangle.fill"
        case .acute: return "cross.fill"
        case .psych: return "brain.head.profile"
        case .fastTrack: return "bolt.fill"
        }
    }
}