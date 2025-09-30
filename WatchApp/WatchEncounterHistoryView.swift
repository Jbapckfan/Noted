import SwiftUI
import WatchKit

struct WatchEncounterHistoryView: View {
    @EnvironmentObject var encounterManager: WatchEncounterManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedEncounter: WatchEncounter?
    @State private var showingDetails = false
    
    var body: some View {
        NavigationStack {
            if encounterManager.encounterHistory.isEmpty {
                emptyState
            } else {
                encounterList
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("No Encounters Yet")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Your completed encounters will appear here")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .navigationTitle("History")
    }
    
    private var encounterList: some View {
        List {
            ForEach(encounterManager.encounterHistory) { encounter in
                EncounterHistoryRow(encounter: encounter)
                    .onTapGesture {
                        selectedEncounter = encounter
                        showingDetails = true
                        WKInterfaceDevice.current().play(.click)
                    }
            }
        }
        .navigationTitle("History")
        .sheet(isPresented: $showingDetails) {
            if let encounter = selectedEncounter {
                EncounterDetailsView(encounter: encounter)
            }
        }
    }
}

// MARK: - Encounter History Row
struct EncounterHistoryRow: View {
    let encounter: WatchEncounter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with room and time
            HStack {
                Label(encounter.room, systemImage: "door.left.hand.open")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text(timeAgo(from: encounter.startTime))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Chief complaint
            if !encounter.chiefComplaint.isEmpty && encounter.chiefComplaint != "General" {
                Text(encounter.chiefComplaint)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            
            // Bottom info
            HStack(spacing: 12) {
                // Duration
                Label(formatDuration(encounter.duration), systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                // Bookmarks
                if encounter.bookmarkCount > 0 {
                    Label("\(encounter.bookmarkCount)", systemImage: "bookmark.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                
                // Save status
                if encounter.isSaved {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            // Confirmation code if available
            if !encounter.confirmationCode.isEmpty {
                Text("Code: \(encounter.confirmationCode)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Encounter Details View
struct EncounterDetailsView: View {
    let encounter: WatchEncounter
    @Environment(\.dismiss) private var dismiss
    @State private var copiedCode = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Status badge
                    if encounter.isSaved {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text("Saved Successfully")
                                .fontWeight(.medium)
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(20)
                    }
                    
                    // Room and Complaint
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Room \(encounter.room)", systemImage: "door.left.hand.open")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        if !encounter.chiefComplaint.isEmpty {
                            Label(encounter.chiefComplaint, systemImage: "stethoscope")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Divider()
                    
                    // Timing Information
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(
                            icon: "clock.arrow.circlepath",
                            title: "Start",
                            value: formatDate(encounter.startTime)
                        )
                        
                        if let endTime = encounter.endTime {
                            detailRow(
                                icon: "clock.badge.checkmark",
                                title: "End",
                                value: formatDate(endTime)
                            )
                        }
                        
                        detailRow(
                            icon: "timer",
                            title: "Duration",
                            value: formatFullDuration(encounter.duration)
                        )
                    }
                    
                    Divider()
                    
                    // Statistics
                    VStack(alignment: .leading, spacing: 8) {
                        if encounter.bookmarkCount > 0 {
                            detailRow(
                                icon: "bookmark.fill",
                                title: "Bookmarks",
                                value: "\(encounter.bookmarkCount)",
                                color: .orange
                            )
                        }
                        
                        detailRow(
                            icon: "doc.text.fill",
                            title: "Encounter ID",
                            value: String(encounter.id.prefix(8)) + "...",
                            color: .gray
                        )
                    }
                    
                    // Confirmation Codes
                    if !encounter.confirmationCode.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirmation Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: copyCode) {
                                HStack {
                                    Text(encounter.confirmationCode)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.bold)
                                    
                                    Spacer()
                                    
                                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                                        .font(.caption)
                                        .foregroundColor(copiedCode ? .green : .blue)
                                }
                                .padding(8)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            if copiedCode {
                                Text("Copied!")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Encounter Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func detailRow(icon: String, title: String, value: String, color: Color = .blue) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatFullDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m \(seconds)s"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds) seconds"
        }
    }
    
    private func copyCode() {
        // Copy to pasteboard (watchOS doesn't have UIPasteboard, but we can simulate)
        copiedCode = true
        WKInterfaceDevice.current().play(.success)
        
        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            copiedCode = false
        }
    }
}

// MARK: - Quick Access from Main View
extension WatchMainView {
    var historyButton: some View {
        NavigationLink(destination: WatchEncounterHistoryView()) {
            Label("History", systemImage: "clock.arrow.circlepath")
                .font(.caption)
        }
    }
}