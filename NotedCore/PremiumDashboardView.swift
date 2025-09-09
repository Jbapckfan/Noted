import SwiftUI

struct PremiumDashboardView: View {
    @StateObject private var dashboardService = ClinicalIntelligenceService()
    @ObservedObject var appState = CoreAppState.shared
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Premium background with glassmorphic effects
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3)
                    ]),
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: geometry.size.width
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header with branding
                        premiumHeader
                        
                        // Clinical Intelligence Hub
                        clinicalIntelligenceHub
                        
                        // Performance Metrics
                        performanceMetrics
                        
                        // AI Recommendations
                        aiRecommendations
                        
                        // Live Activity Feed
                        liveActivityFeed
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            dashboardService.refreshMetrics()
        }
    }
    
    private var premiumHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noted AI")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("Clinical Documentation Intelligence")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                        .opacity(0.8)
                        .scaleEffect(1.5)
                        .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: UUID())
                    
                    Text("Systems Operational")
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
                .background(Color.gray.opacity(0.3))
        }
    }
    
    private var clinicalIntelligenceHub: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Text("Clinical Documentation Intelligence")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Menu {
                        Button("View Details") { }
                        Button("Configure Settings") { }
                        Button("Export Report") { }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Today's Insights")
                            .font(.headline)
                        Spacer()
                        Text("AI Confidence")
                            .font(.headline)
                    }
                    
                    InsightRow(
                        icon: "doc.text.fill",
                        title: "\(dashboardService.todayMetrics.encountersTranscribed) patient encounters transcribed",
                        confidence: dashboardService.todayMetrics.transcriptionAccuracy
                    )
                    
                    InsightRow(
                        icon: "clock.fill",
                        title: "\(String(format: "%.1f", dashboardService.todayMetrics.hoursSaved)) hours saved on documentation",
                        confidence: 0.95
                    )
                    
                    InsightRow(
                        icon: "textformat.abc",
                        title: "\(dashboardService.todayMetrics.medicalTermsCorrected) medical terms auto-corrected",
                        confidence: 0.99
                    )
                    
                    InsightRow(
                        icon: "exclamationmark.triangle.fill",
                        title: "\(dashboardService.todayMetrics.criticalFindingsHighlighted) critical findings highlighted",
                        confidence: 0.97
                    )
                }
            }
        }
    }
    
    private var performanceMetrics: some View {
        HStack(spacing: 16) {
            MetricCard(
                title: "Accuracy",
                value: String(format: "%.1f%%", dashboardService.performanceMetrics.accuracy * 100),
                change: "+2.3%",
                color: .green,
                icon: "target"
            )
            
            MetricCard(
                title: "Efficiency",
                value: String(format: "%.1fx", dashboardService.performanceMetrics.efficiencyMultiplier),
                change: "+15%",
                color: .blue,
                icon: "speedometer"
            )
            
            MetricCard(
                title: "Time Saved",
                value: "\(Int(dashboardService.performanceMetrics.timeSavedToday))h",
                change: "+45min",
                color: .purple,
                icon: "clock.badge.checkmark"
            )
        }
    }
    
    private var aiRecommendations: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "lightbulb.fill")
                        .font(.title2)
                        .foregroundColor(.yellow)
                    
                    Text("AI Recommendations")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                ForEach(dashboardService.aiRecommendations, id: \.id) { recommendation in
                    RecommendationRow(recommendation: recommendation)
                }
            }
        }
    }
    
    private var liveActivityFeed: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Live Activity Feed")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text("Real-time")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                }
                
                ForEach(dashboardService.liveActivities.prefix(5), id: \.id) { activity in
                    ActivityRow(activity: activity)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct GlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            )
    }
}

struct InsightRow: View {
    let icon: String
    let title: String
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            ConfidenceBar(confidence: confidence)
        }
    }
}

struct ConfidenceBar: View {
    let confidence: Double
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(String(format: "%.1f%%", confidence * 100))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 1) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(confidence > Double(index) / 5.0 ? .green : .gray.opacity(0.3))
                        .frame(width: 4, height: 12)
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: color.opacity(0.2), radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

struct RecommendationRow: View {
    let recommendation: AIRecommendation
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: recommendation.icon)
                .font(.title3)
                .foregroundColor(recommendation.priority.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(recommendation.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            Button("Configure") {
                // Handle configure action
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(.vertical, 8)
    }
}

struct ActivityRow: View {
    let activity: LiveActivity
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(activity.type.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.message)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Text(activity.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if activity.isNew {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    PremiumDashboardView()
}