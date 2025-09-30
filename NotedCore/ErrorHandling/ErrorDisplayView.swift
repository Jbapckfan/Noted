import SwiftUI
#if os(macOS)
import AppKit
#endif

// MARK: - Error Alert View

struct ErrorAlertView: View {
    @ObservedObject var errorHandler = MedicalErrorHandler.shared
    
    var body: some View {
        EmptyView()
            .alert(
                errorHandler.currentError?.errorDescription ?? "Unknown Error",
                isPresented: $errorHandler.showErrorAlert,
                presenting: errorHandler.currentError
            ) { error in
                alertButtons(for: error)
            } message: { error in
                if let recovery = error.recoverySuggestion {
                    Text(recovery)
                }
            }
    }
    
    @ViewBuilder
    private func alertButtons(for error: MedicalAppError) -> some View {
        // Always provide a dismiss button
        Button("OK") {
            errorHandler.dismissError()
        }
        
        // Add action buttons based on error type
        switch error {
        case .microphonePermissionDenied:
            Button("Open Settings") {
                openAppSettings()
                errorHandler.dismissError()
            }
            
        case .networkUnavailable, .groqAPIFailure:
            Button("Retry") {
                errorHandler.dismissError()
                // Trigger retry through notification
                NotificationCenter.default.post(name: .errorRecoveryRetry, object: error)
            }
            
        case .lowMemory:
            Button("Free Memory") {
                freeMemory()
                errorHandler.dismissError()
            }
            
        case .whisperModelLoadFailed:
            Button("Restart Audio") {
                errorHandler.dismissError()
                NotificationCenter.default.post(name: .errorRecoveryRestart, object: "WhisperService")
            }
            
        default:
            EmptyView()
        }
    }
    
    private func openAppSettings() {
        #if os(iOS)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #else
        // On macOS, open System Preferences
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
    
    private func freeMemory() {
        // Signal to clear caches and free memory
        NotificationCenter.default.post(name: .freeMemoryRequested, object: nil)
    }
}

// MARK: - Error Dashboard View

struct ErrorDashboardView: View {
    @ObservedObject var errorHandler = MedicalErrorHandler.shared
    @State private var selectedSeverity: ErrorSeverity?
    @State private var showingDetails = false
    
    var filteredErrors: [ErrorLogEntry] {
        if let severity = selectedSeverity {
            return errorHandler.errorHistory.filter { $0.severity == severity }
        }
        return errorHandler.errorHistory
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Recovery Status Banner
                if errorHandler.isInRecoveryMode {
                    recoveryBanner
                }
                
                // Error Summary Cards
                errorSummarySection
                
                // Error History List
                errorHistorySection
            }
            .navigationTitle("System Status")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Clear History") {
                            errorHandler.clearErrorHistory()
                        }
                        Button("Export Logs") {
                            exportErrorLogs()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }
    
    private var recoveryBanner: some View {
        HStack {
            Image(systemName: "arrow.clockwise")
                .foregroundColor(.blue)
            Text("System Recovery in Progress...")
                .font(.subheadline)
                .foregroundColor(.blue)
            Spacer()
        }
        .padding()
        .background(Color.blue.opacity(0.1))
    }
    
    private var errorSummarySection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(ErrorSeverity.allCases, id: \.self) { severity in
                    ErrorSummaryCard(
                        severity: severity,
                        count: errorHandler.errorHistory.filter { $0.severity == severity }.count,
                        isSelected: selectedSeverity == severity
                    ) {
                        selectedSeverity = selectedSeverity == severity ? nil : severity
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private var errorHistorySection: some View {
        List {
            ForEach(filteredErrors.reversed()) { entry in
                ErrorRowView(entry: entry)
                    .onTapGesture {
                        // Show detailed error information
                    }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private func exportErrorLogs() {
        // Implementation for exporting error logs
        // This would typically create a file and share it
    }
}

// MARK: - Error Summary Card

struct ErrorSummaryCard: View {
    let severity: ErrorSeverity
    let count: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: severity.systemImage)
                    .font(.title2)
                    .foregroundColor(severity.color)
                
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(severity.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 80, height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? severity.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? severity.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Error Row View

struct ErrorRowView: View {
    let entry: ErrorLogEntry
    @State private var showingDetails = false
    
    var body: some View {
        HStack {
            Image(systemName: entry.severity.systemImage)
                .foregroundColor(entry.severity.color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.error.errorDescription ?? "Unknown Error")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(entry.context.isEmpty ? "System" : entry.context)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(RelativeDateTimeFormatter().localizedString(for: entry.timestamp, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { showingDetails.toggle() }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetails) {
            ErrorDetailView(entry: entry)
        }
    }
}

// MARK: - Error Detail View

struct ErrorDetailView: View {
    let entry: ErrorLogEntry
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Error Header
                    HStack {
                        Image(systemName: entry.severity.systemImage)
                            .foregroundColor(entry.severity.color)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading) {
                            Text(entry.severity.rawValue)
                                .font(.headline)
                                .foregroundColor(entry.severity.color)
                            
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Error Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(title: "Error", content: entry.error.errorDescription ?? "Unknown")
                        
                        if !entry.context.isEmpty {
                            DetailRow(title: "Context", content: entry.context)
                        }
                        
                        if let recovery = entry.error.recoverySuggestion {
                            DetailRow(title: "Recovery Suggestion", content: recovery)
                        }
                        
                        DetailRow(title: "Error ID", content: entry.id.uuidString)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Error Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Floating Error Badge

struct ErrorBadgeView: View {
    @ObservedObject var errorHandler = MedicalErrorHandler.shared
    @State private var showingDashboard = false
    
    private var recentCriticalErrors: Int {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return errorHandler.errorHistory.filter {
            $0.severity == .critical && $0.timestamp > oneHourAgo
        }.count
    }
    
    private var recentHighErrors: Int {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        return errorHandler.errorHistory.filter {
            $0.severity == .high && $0.timestamp > oneHourAgo
        }.count
    }
    
    var body: some View {
        if recentCriticalErrors > 0 || recentHighErrors > 0 {
            Button(action: { showingDashboard = true }) {
                HStack(spacing: 4) {
                    Image(systemName: recentCriticalErrors > 0 ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                        .foregroundColor(recentCriticalErrors > 0 ? .red : .orange)
                    
                    Text("\(recentCriticalErrors + recentHighErrors)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(recentCriticalErrors > 0 ? Color.red : Color.orange)
                )
            }
            .sheet(isPresented: $showingDashboard) {
                ErrorDashboardView()
            }
        }
    }
}

// MARK: - Memory Warning View

struct MemoryWarningView: View {
    @State private var showingMemoryWarning = false
    
    var body: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: .showMemoryWarning)) { _ in
                showingMemoryWarning = true
            }
            .alert("Low Memory Warning", isPresented: $showingMemoryWarning) {
                Button("Free Memory") {
                    freeAppMemory()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("The app is using a lot of memory. Would you like to clear caches and free up memory?")
            }
    }
    
    private func freeAppMemory() {
        NotificationCenter.default.post(name: .freeMemoryRequested, object: nil)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let freeMemoryRequested = Notification.Name("freeMemoryRequested")
}