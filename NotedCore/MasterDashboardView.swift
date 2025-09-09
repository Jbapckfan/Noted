import SwiftUI

struct MasterDashboardView: View {
    @StateObject private var patientService = PatientService.shared
    @StateObject private var audioService = AudioCaptureService()
    @StateObject private var appState = CoreAppState.shared
    @StateObject private var whisperService = WhisperService.shared
    
    @State private var selectedView: DashboardView = .patients
    @State private var showingRecordingInterface = false
    @State private var showingHandoffGenerator = false
    @State private var showingAnalytics = false
    
    enum DashboardView {
        case patients, recording, analytics, handoff
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Master Header
                masterHeader
                
                // Main Dashboard Content
                HStack(spacing: 0) {
                    // Left Sidebar - Navigation & Patient List
                    leftSidebar
                        .frame(width: geometry.size.width * 0.25)
                    
                    // Center Content Area
                    centerContent
                        .frame(width: geometry.size.width * 0.50)
                    
                    // Right Sidebar - Intelligence & Actions
                    rightSidebar
                        .frame(width: geometry.size.width * 0.25)
                }
            }
        }
        .background(Color(.systemGray6))
        .sheet(isPresented: $showingRecordingInterface) {
            RecordingInterfaceSheet()
        }
        .sheet(isPresented: $showingHandoffGenerator) {
            HandoffGeneratorSheet()
        }
        .sheet(isPresented: $showingAnalytics) {
            AnalyticsSheet()
        }
    }
    
    // MARK: - Master Header
    private var masterHeader: some View {
        HStack {
            // Branding & Status
            HStack(spacing: 12) {
                Circle()
                    .fill(whisperService.isReady ? .green : .orange)
                    .frame(width: 8, height: 8)
                
                Text("NOTEDCORE AI")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if audioService.isRecording {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.red)
                            .frame(width: 6, height: 6)
                            .scaleEffect(0.8)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: audioService.isRecording)
                        
                        Text("Recording: Room \(patientService.activePatient?.room ?? "?")")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            
            Spacer()
            
            // Provider Info & Shift Stats
            HStack(spacing: 24) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Dr. Sarah Chen")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("Emergency Medicine")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Shift: \(patientService.shiftMetrics.formattedShiftDuration)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Patients: \(patientService.shiftMetrics.patientsSeenCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("RVUs: \(String(format: "%.1f", patientService.shiftMetrics.totalRVUs))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("$\(Int(patientService.shiftMetrics.hourlyRate))/hr")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }
    
    // MARK: - Left Sidebar
    private var leftSidebar: some View {
        VStack(spacing: 0) {
            // Navigation Tabs
            navigationTabs
            
            // Patient List
            patientListSection
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator)
                .frame(width: 0.5)
        }
    }
    
    private var navigationTabs: some View {
        HStack(spacing: 0) {
            ForEach([
                (DashboardView.patients, "👥", "Patients"),
                (DashboardView.recording, "🎙️", "Record"),
                (DashboardView.analytics, "📊", "Stats"),
                (DashboardView.handoff, "🔄", "Handoff")
            ], id: \.0) { view, icon, title in
                Button(action: { selectedView = view }) {
                    VStack(spacing: 4) {
                        Text(icon)
                            .font(.title3)
                        
                        Text(title)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedView == view ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedView == view ? .blue : .secondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    private var patientListSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section Header
            HStack {
                Text("MY PATIENTS")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                Text("\(patientService.patients.filter { $0.status != .discharged }.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Patient List
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(patientService.patients.filter { $0.status != .discharged }) { patient in
                        PatientListRow(
                            patient: patient,
                            isActive: patientService.activePatient?.id == patient.id
                        ) {
                            patientService.setActivePatient(patient)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
    
    // MARK: - Center Content
    private var centerContent: some View {
        Group {
            switch selectedView {
            case .patients:
                activePatientView
            case .recording:
                recordingInterfaceView
            case .analytics:
                analyticsOverview
            case .handoff:
                handoffPreview
            }
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator)
                .frame(width: 0.5)
        }
    }
    
    private var activePatientView: some View {
        VStack(spacing: 0) {
            if let patient = patientService.activePatient {
                // Active Patient Header
                activePatientHeader(patient)
                
                // Live Transcription Area
                liveTranscriptionArea
                
                Spacer()
            } else {
                // No Active Patient
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    Text("Select a patient to begin")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func activePatientHeader(_ patient: Patient) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ACTIVE PATIENT")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    
                    Text("\(patient.fullName), \(patient.displayAge), Room \(patient.room)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("CC: \(patient.chiefComplaint)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Chart Strength")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            Rectangle()
                                .fill(index < patient.chartLevel.completionPercentage / 20 ? .green : .gray.opacity(0.3))
                                .frame(width: 8, height: 16)
                        }
                        
                        Text("\(patient.chartLevel.completionPercentage)%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    
                    Text("Level \(patient.chartLevel.levelDisplay)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Missing Elements
            if !patient.chartLevel.missingElements.isEmpty {
                HStack {
                    Text("Missing:")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Text(patient.chartLevel.missingElements.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }
    
    private var liveTranscriptionArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Transcription Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(whisperService.isTranscribing ? .blue : .gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(whisperService.isTranscribing ? 0.8 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), 
                                  value: whisperService.isTranscribing)
                    
                    Text("🎙️ LIVE TRANSCRIPTION")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                }
                
                Spacer()
                
                // Recording Controls
                Button(action: toggleRecording) {
                    HStack(spacing: 6) {
                        Image(systemName: audioService.isRecording ? "stop.circle.fill" : "record.circle")
                            .foregroundColor(audioService.isRecording ? .red : .blue)
                        
                        Text(audioService.isRecording ? "Stop" : "Record")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            
            // Audio Waveform (compact version for dashboard)
            if audioService.isRecording {
                audioWaveformCompact
            }
            
            // Transcription Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if appState.transcription.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 32))
                                .foregroundColor(.gray.opacity(0.4))
                            
                            Text(audioService.isRecording ? "Listening for speech..." : "Press record to begin transcription")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        Text(appState.transcription)
                            .font(.body)
                            .lineSpacing(6)
                            .textSelection(.enabled)
                            .padding(16)
                        
                        // Live typing indicator
                        if audioService.isRecording {
                            HStack {
                                Rectangle()
                                    .fill(.blue)
                                    .frame(width: 2, height: 20)
                                    .opacity(0.8)
                                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), 
                                              value: audioService.isRecording)
                                
                                Spacer()
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(16)
    }
    
    private var recordingInterfaceView: some View {
        // Placeholder for detailed recording interface
        ContentView()
    }
    
    private var analyticsOverview: some View {
        Text("Analytics Overview")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var handoffPreview: some View {
        Text("Handoff Generator")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Right Sidebar
    private var rightSidebar: some View {
        VStack(spacing: 0) {
            // Intelligence Assistant Header
            intelligenceHeader
            
            // Smart Notifications
            notificationsSection
            
            // Quick Actions
            quickActionsSection
            
            // Revenue Opportunities
            revenueOpportunitiesSection
            
            Spacer()
        }
        .background(.ultraThinMaterial)
    }
    
    private var intelligenceHeader: some View {
        HStack {
            Text("💡 INTELLIGENT ASSISTANT")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
        }
    }
    
    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🔔 SMART NOTIFICATIONS")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                if !patientService.notifications.isEmpty {
                    Text("\(patientService.notifications.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.red)
                        .clipShape(Capsule())
                }
            }
            
            if patientService.notifications.isEmpty {
                Text("No active alerts")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                LazyVStack(spacing: 4) {
                    ForEach(patientService.notifications.prefix(3)) { notification in
                        NotificationRow(notification: notification)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("⚡ QUICK ACTIONS")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 6) {
                QuickActionButton(title: "+Social History", color: .blue) {
                    // Add social history
                }
                
                QuickActionButton(title: "+Review Records", color: .green) {
                    // Add record review
                }
                
                QuickActionButton(title: "+Personal Review", color: .orange) {
                    // Add personal review
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var revenueOpportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("💰 REVENUE OPPORTUNITIES")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if let patient = patientService.activePatient {
                let opportunities = patientService.generateRevenueOpportunities(for: patient)
                
                if opportunities.isEmpty {
                    Text("Chart optimized")
                        .font(.caption)
                        .foregroundColor(.green)
                        .italic()
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(opportunities.prefix(2)) { opportunity in
                            RevenueOpportunityRow(opportunity: opportunity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Actions
    
    private func toggleRecording() {
        Task {
            if audioService.isRecording {
                await stopRecording()
            } else {
                do {
                    try await startRecording()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }
    
    private func startRecording() async throws {
        // Clear previous state
        appState.transcription = ""
        appState.medicalNote = ""
        
        // Start WhisperKit session
        whisperService.startNewSession()
        
        // Start audio capture with proper error handling
        try await audioService.start()
        
        Logger.audioInfo("Started premium medical transcription session")
    }
    
    private func stopRecording() async {
        audioService.stop()
        
        // Finalize WhisperKit processing
        await whisperService.finalizeCurrentSession()
        
        Logger.audioInfo("Stopped medical transcription session")
    }
    
    // MARK: - Audio Waveform
    
    private var audioWaveformCompact: some View {
        HStack(spacing: 2) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [.blue.opacity(0.3), .blue], startPoint: .bottom, endPoint: .top))
                    .frame(width: 3)
                    .frame(height: waveformHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: audioService.level)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let level = audioService.level
        
        // Add some variation to make it look more natural
        let variation = sin(Double(index) * 0.8) * 0.4 + 1.0
        let height = baseHeight + (maxHeight - baseHeight) * CGFloat(level) * variation
        
        return max(2, min(maxHeight, height))
    }
}

// MARK: - Supporting Views

struct PatientListRow: View {
    let patient: Patient
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Room & Status
                VStack(spacing: 2) {
                    Text(patient.room)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(patient.status.icon)
                        .font(.caption)
                }
                .frame(width: 30)
                
                // Patient Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(patient.fullName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("\(patient.displayAge) \(patient.chiefComplaint)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Level & Time
                VStack(alignment: .trailing, spacing: 2) {
                    Text(patient.chartLevel.levelDisplay)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                    
                    Text(patient.formattedTimeInDepartment)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isActive ? .blue.opacity(0.1) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

struct NotificationRow: View {
    let notification: ClinicalAlert
    
    private func severityColor(_ severity: ClinicalAlert.AlertSeverity) -> Color {
        switch severity {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(severityColor(notification.severity))
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.message)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if notification.actionable {
                    Text("Tap for actions")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct QuickActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct RevenueOpportunityRow: View {
    let opportunity: RevenueOpportunity
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(opportunity.description)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            HStack {
                Text("+$\(Int(opportunity.revenueIncrease))")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Spacer()
                
                Text("\(opportunity.estimatedTime)s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Sheet Views (Placeholders)

struct RecordingInterfaceSheet: View {
    var body: some View {
        ContentView()
    }
}

struct HandoffGeneratorSheet: View {
    var body: some View {
        Text("Handoff Generator")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct AnalyticsSheet: View {
    var body: some View {
        Text("Analytics Dashboard")
            .font(.title)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    MasterDashboardView()
}