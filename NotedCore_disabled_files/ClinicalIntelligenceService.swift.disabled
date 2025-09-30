import Foundation
import Combine

@MainActor
class ClinicalIntelligenceService: ObservableObject {
    @Published var todayMetrics = TodayMetrics()
    @Published var performanceMetrics = PerformanceMetrics()
    @Published var aiRecommendations: [AIRecommendation] = []
    @Published var liveActivities: [LiveActivity] = []
    
    private var timer: Timer?
    
    init() {
        loadInitialData()
        startRealTimeUpdates()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func refreshMetrics() {
        updateTodayMetrics()
        updatePerformanceMetrics()
        generateAIRecommendations()
        updateLiveActivities()
    }
    
    private func loadInitialData() {
        // Simulate loading real data
        todayMetrics = TodayMetrics(
            encountersTranscribed: 12,
            transcriptionAccuracy: 0.987,
            hoursSaved: 3.2,
            medicalTermsCorrected: 247,
            criticalFindingsHighlighted: 2
        )
        
        performanceMetrics = PerformanceMetrics(
            accuracy: 0.995,
            efficiencyMultiplier: 2.8,
            timeSavedToday: 3.2
        )
        
        generateAIRecommendations()
        generateInitialActivities()
    }
    
    private func startRealTimeUpdates() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateLiveActivities()
            }
        }
    }
    
    private func updateTodayMetrics() {
        // Simulate real-time metric updates
        todayMetrics.encountersTranscribed += Int.random(in: 0...2)
        todayMetrics.medicalTermsCorrected += Int.random(in: 0...5)
    }
    
    private func updatePerformanceMetrics() {
        // Simulate performance improvements
        let accuracyChange = Double.random(in: -0.002...0.005)
        performanceMetrics.accuracy = min(1.0, max(0.9, performanceMetrics.accuracy + accuracyChange))
    }
    
    private func generateAIRecommendations() {
        aiRecommendations = [
            AIRecommendation(
                id: UUID().uuidString,
                title: "Optimize Documentation Length",
                description: "Your H&P notes average 15% longer than optimal. Enable Smart Summarization for efficiency gains.",
                priority: .medium,
                icon: "doc.text.magnifyingglass"
            ),
            AIRecommendation(
                id: UUID().uuidString,
                title: "Enable Billing Optimization",
                description: "Potential revenue increase of $2,400/month with automated billing code suggestions.",
                priority: .high,
                icon: "dollarsign.circle"
            ),
            AIRecommendation(
                id: UUID().uuidString,
                title: "Template Efficiency",
                description: "Create quick templates for your 5 most common procedures to save 45 minutes daily.",
                priority: .low,
                icon: "square.grid.3x3"
            )
        ]
    }
    
    private func generateInitialActivities() {
        liveActivities = [
            LiveActivity(
                id: UUID().uuidString,
                message: "Dr. Chen completed 3 SOAP notes in 12 minutes",
                timestamp: Date().addingTimeInterval(-300),
                type: .achievement,
                isNew: true
            ),
            LiveActivity(
                id: UUID().uuidString,
                message: "New accuracy record: 99.2% on cardiology terms",
                timestamp: Date().addingTimeInterval(-720),
                type: .milestone,
                isNew: true
            ),
            LiveActivity(
                id: UUID().uuidString,
                message: "Medication interaction detected and flagged",
                timestamp: Date().addingTimeInterval(-1200),
                type: .alert,
                isNew: false
            ),
            LiveActivity(
                id: UUID().uuidString,
                message: "Weekly documentation goal reached",
                timestamp: Date().addingTimeInterval(-1800),
                type: .achievement,
                isNew: false
            ),
            LiveActivity(
                id: UUID().uuidString,
                message: "System backup completed successfully",
                timestamp: Date().addingTimeInterval(-2400),
                type: .system,
                isNew: false
            )
        ]
    }
    
    private func updateLiveActivities() {
        // Simulate new activities
        let newActivities = [
            "New patient encounter processed",
            "Clinical guideline updated",
            "Voice command template activated",
            "Transcription quality improved",
            "Billing code validated"
        ]
        
        if Int.random(in: 1...10) <= 3 { // 30% chance of new activity
            let newActivity = LiveActivity(
                id: UUID().uuidString,
                message: newActivities.randomElement() ?? "System update",
                timestamp: Date(),
                type: ActivityType.allCases.randomElement() ?? .system,
                isNew: true
            )
            
            liveActivities.insert(newActivity, at: 0)
            
            // Keep only last 20 activities
            if liveActivities.count > 20 {
                liveActivities = Array(liveActivities.prefix(20))
            }
        }
    }
}

// MARK: - Data Models

struct TodayMetrics {
    var encountersTranscribed: Int = 0
    var transcriptionAccuracy: Double = 0.0
    var hoursSaved: Double = 0.0
    var medicalTermsCorrected: Int = 0
    var criticalFindingsHighlighted: Int = 0
}

struct PerformanceMetrics {
    var accuracy: Double = 0.0
    var efficiencyMultiplier: Double = 1.0
    var timeSavedToday: Double = 0.0
}

struct AIRecommendation {
    let id: String
    let title: String
    let description: String
    let priority: RecommendationPriority
    let icon: String
}

enum RecommendationPriority: CaseIterable {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        }
    }
}

struct LiveActivity {
    let id: String
    let message: String
    let timestamp: Date
    let type: ActivityType
    var isNew: Bool
}

enum ActivityType: CaseIterable {
    case achievement, milestone, alert, system
    
    var color: Color {
        switch self {
        case .achievement: return .green
        case .milestone: return .purple
        case .alert: return .red
        case .system: return .blue
        }
    }
}

import SwiftUI