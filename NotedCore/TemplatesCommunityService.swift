import Foundation
import SwiftUI
import Combine

// MARK: - Templates Community Service
@MainActor
class TemplatesCommunityService: ObservableObject {
    static let shared = TemplatesCommunityService()
    
    // MARK: - Published Properties
    @Published var allTemplates: [MedicalTemplate] = []
    @Published var myTemplates: [MedicalTemplate] = []
    @Published var favoriteTemplates: [MedicalTemplate] = []
    @Published var recentlyUsedTemplates: [MedicalTemplate] = []
    @Published var isLoadingTemplates = false
    @Published var searchText = ""
    @Published var selectedCategory: TemplateCategory?
    @Published var selectedSpecialty: MedicalSpecialty = .general
    
    // MARK: - Voice Command Processing
    @Published var isProcessingVoiceCommand = false
    @Published var lastProcessedCommand: String?
    @Published var lastInsertedTemplate: MedicalTemplate?
    
    // MARK: - Computed Properties
    var filteredTemplates: [MedicalTemplate] {
        var filtered = allTemplates
        
        // Filter by category
        if let category = selectedCategory {
            filtered = filtered.filter { $0.category == category }
        }
        
        // Filter by specialty
        if selectedSpecialty != .general {
            filtered = filtered.filter { $0.specialty == selectedSpecialty || $0.specialty == .general }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                template.content.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var popularTemplates: [MedicalTemplate] {
        allTemplates.sorted { $0.downloads > $1.downloads }.prefix(10).map { $0 }
    }
    
    var verifiedTemplates: [MedicalTemplate] {
        allTemplates.filter { $0.isVerified }
    }
    
    // MARK: - Initialization
    private init() {
        loadTemplates()
        setupNotifications()
    }
    
    private func loadTemplates() {
        // Load sample templates for now
        allTemplates = MedicalTemplate.sampleTemplates
        
        // Load user's templates from UserDefaults
        loadMyTemplates()
        loadFavorites()
        loadRecentlyUsed()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleProcessTemplateCommand(_:)),
            name: .processTemplateCommand,
            object: nil
        )
    }
    
    // MARK: - Template Management
    func addToMyTemplates(_ template: MedicalTemplate) {
        guard !myTemplates.contains(where: { $0.id == template.id }) else { return }
        myTemplates.append(template)
        saveMyTemplates()
        Logger.log(.info, category: .general, message: "Added template to my templates: \(template.name)")
    }
    
    func removeFromMyTemplates(_ template: MedicalTemplate) {
        myTemplates.removeAll { $0.id == template.id }
        saveMyTemplates()
    }
    
    func toggleFavorite(_ template: MedicalTemplate) {
        if favoriteTemplates.contains(where: { $0.id == template.id }) {
            favoriteTemplates.removeAll { $0.id == template.id }
        } else {
            favoriteTemplates.append(template)
        }
        saveFavorites()
    }
    
    func isFavorite(_ template: MedicalTemplate) -> Bool {
        favoriteTemplates.contains { $0.id == template.id }
    }
    
    // MARK: - Template Insertion
    func insertTemplate(_ template: MedicalTemplate) async {
        await MainActor.run {
            lastInsertedTemplate = template
            
            // Add to recently used
            recentlyUsedTemplates.removeAll { $0.id == template.id }
            recentlyUsedTemplates.insert(template, at: 0)
            if recentlyUsedTemplates.count > 10 {
                recentlyUsedTemplates = Array(recentlyUsedTemplates.prefix(10))
            }
            saveRecentlyUsed()
            
            // Send notification to insert template
            NotificationCenter.default.post(
                name: .insertTemplate,
                object: template.formattedContent
            )
            
            Logger.log(.info, category: .general, message: "Inserted template: \(template.name)")
        }
    }
    
    func insertTemplateWithParameters(_ template: MedicalTemplate, parameters: [String: String]) async {
        await MainActor.run {
            lastInsertedTemplate = template
            
            // Apply parameters and insert
            let filledContent = template.applyParameters(parameters)
            
            // Add to recently used
            recentlyUsedTemplates.removeAll { $0.id == template.id }
            recentlyUsedTemplates.insert(template, at: 0)
            if recentlyUsedTemplates.count > 10 {
                recentlyUsedTemplates = Array(recentlyUsedTemplates.prefix(10))
            }
            saveRecentlyUsed()
            
            // Send notification to insert template
            NotificationCenter.default.post(
                name: .insertTemplate,
                object: filledContent
            )
            
            Logger.log(.info, category: .general, message: "Inserted template with parameters: \(template.name)")
        }
    }
    
    // MARK: - Voice Command Processing
    @objc private func handleProcessTemplateCommand(_ notification: Notification) {
        guard let command = notification.object as? String else { return }
        
        Task {
            await processVoiceCommand(command)
        }
    }
    
    func processVoiceCommand(_ command: String) async {
        await MainActor.run {
            isProcessingVoiceCommand = true
            lastProcessedCommand = command
        }
        
        Logger.log(.info, category: .general, message: "Processing voice command: \(command)")
        
        // Extract template and parameters
        if let template = extractTemplateFromCommand(command) {
            let parameters = extractParametersFromCommand(command)
            
            if parameters.isEmpty {
                await insertTemplate(template)
            } else {
                await insertTemplateWithParameters(template, parameters: parameters)
            }
            
            // Show success feedback
            await MainActor.run {
                isProcessingVoiceCommand = false
            }
        } else {
            // No template found
            await MainActor.run {
                isProcessingVoiceCommand = false
            }
            Logger.log(.warning, category: .general, message: "No template found for command: \(command)")
        }
    }
    
    // MARK: - AI-Powered Parameter Extraction
    private func extractParametersFromCommand(_ command: String) -> [String: String] {
        var parameters: [String: String] = [:]
        let lowercaseCommand = command.lowercased()
        
        // Size extraction
        let sizePatterns = [
            #"(\d+(?:\.\d+)?)\s*(?:cm|centimeter|millimeter|mm|inch|in)"#,
            #"(\d+(?:\.\d+)?)\s*(?:by|x)\s*(\d+(?:\.\d+)?)"#
        ]
        
        for pattern in sizePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let matches = regex.matches(in: lowercaseCommand, options: [], range: NSRange(location: 0, length: lowercaseCommand.count))
                if let match = matches.first {
                    let matchRange = match.range
                    if let range = Range(matchRange, in: lowercaseCommand) {
                        parameters["size"] = String(lowercaseCommand[range])
                        break
                    }
                }
            }
        }
        
        // Location extraction
        let locationKeywords = [
            "forehead", "scalp", "face", "cheek", "chin", "nose",
            "arm", "forearm", "hand", "finger", "thumb",
            "leg", "shin", "thigh", "foot", "toe",
            "chest", "back", "abdomen", "shoulder"
        ]
        
        for location in locationKeywords {
            if lowercaseCommand.contains(location) {
                let side = lowercaseCommand.contains("left") ? "left" : 
                          lowercaseCommand.contains("right") ? "right" : ""
                parameters["location"] = side.isEmpty ? location : "\(side) \(location)"
                break
            }
        }
        
        // Shape extraction
        let shapeKeywords = ["linear", "curved", "stellate", "irregular", "jagged"]
        for shape in shapeKeywords {
            if lowercaseCommand.contains(shape) {
                parameters["shape"] = shape
                break
            }
        }
        
        // Anesthetic extraction
        if lowercaseCommand.contains("lidocaine") {
            if lowercaseCommand.contains("epinephrine") || lowercaseCommand.contains("epi") {
                parameters["anesthetic_type"] = "lidocaine 1% with epinephrine"
            } else {
                parameters["anesthetic_type"] = "lidocaine 1%"
            }
        }
        
        // Suture extraction
        let suturePattern = #"(\d+-\d+)\s*(?:nylon|vicryl|silk|prolene)"#
        if let regex = try? NSRegularExpression(pattern: suturePattern, options: []) {
            let matches = regex.matches(in: lowercaseCommand, options: [], range: NSRange(location: 0, length: lowercaseCommand.count))
            if let match = matches.first {
                let matchRange = match.range
                if let range = Range(matchRange, in: lowercaseCommand) {
                    parameters["suture_type"] = String(lowercaseCommand[range])
                }
            }
        }
        
        return parameters
    }
    
    // MARK: - Template Matching
    private func extractTemplateFromCommand(_ command: String) -> MedicalTemplate? {
        let lowercaseCommand = command.lowercased()
        
        // First check direct voice commands
        for template in myTemplates + allTemplates {
            for voiceCommand in template.voiceCommands {
                if lowercaseCommand.contains(voiceCommand.lowercased()) {
                    return template
                }
            }
        }
        
        // Then check keywords
        let templateKeywords: [String: [String]] = [
            "laceration repair": ["laceration", "lac", "cut", "wound", "suture", "stitch"],
            "endotracheal intubation": ["intubation", "intubate", "airway", "ett", "tube"],
            "critical care time": ["critical care", "icu time", "critical time"]
        ]
        
        for template in myTemplates + allTemplates {
            if let keywords = templateKeywords[template.name.lowercased()] {
                let matchCount = keywords.filter { lowercaseCommand.contains($0) }.count
                if matchCount >= 1 {
                    return template
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Persistence
    private func saveMyTemplates() {
        if let encoded = try? JSONEncoder().encode(myTemplates) {
            UserDefaults.standard.set(encoded, forKey: "MyMedicalTemplates")
        }
    }
    
    private func loadMyTemplates() {
        if let data = UserDefaults.standard.data(forKey: "MyMedicalTemplates"),
           let decoded = try? JSONDecoder().decode([MedicalTemplate].self, from: data) {
            myTemplates = decoded
        } else {
            // Default templates for new users
            myTemplates = [MedicalTemplate.sampleTemplates[0]] // Start with laceration repair
        }
    }
    
    private func saveFavorites() {
        let favoriteIDs = favoriteTemplates.map { $0.id.uuidString }
        UserDefaults.standard.set(favoriteIDs, forKey: "FavoriteMedicalTemplates")
    }
    
    private func loadFavorites() {
        if let favoriteIDs = UserDefaults.standard.stringArray(forKey: "FavoriteMedicalTemplates") {
            favoriteTemplates = allTemplates.filter { template in
                favoriteIDs.contains(template.id.uuidString)
            }
        }
    }
    
    private func saveRecentlyUsed() {
        if let encoded = try? JSONEncoder().encode(recentlyUsedTemplates) {
            UserDefaults.standard.set(encoded, forKey: "RecentlyUsedMedicalTemplates")
        }
    }
    
    private func loadRecentlyUsed() {
        if let data = UserDefaults.standard.data(forKey: "RecentlyUsedMedicalTemplates"),
           let decoded = try? JSONDecoder().decode([MedicalTemplate].self, from: data) {
            recentlyUsedTemplates = decoded
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let insertTemplate = Notification.Name("insertTemplate")
    static let processTemplateCommand = Notification.Name("processTemplateCommand")
}