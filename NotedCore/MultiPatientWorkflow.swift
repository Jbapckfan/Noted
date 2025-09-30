import Foundation
import SwiftUI

// MARK: - Supporting Types

struct EncounterStats {
    let totalToday: Int
    let activeCount: Int
    let completedToday: Int
    let averageDuration: TimeInterval
    let occupiedBeds: Int
    
    var formattedAverageDuration: String {
        let minutes = Int(averageDuration / 60)
        return "\(minutes) min"
    }
}

enum BedStatus: String, CaseIterable {
    case available = "Available"
    case occupied = "Occupied"
    case empty = "Empty"
    case ready = "Ready for Discharge"
    case cleanup = "Needs Cleanup"
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .occupied:
            return .red
        case .empty:
            return .gray
        case .ready:
            return .blue
        case .cleanup:
            return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .available:
            return "checkmark.circle.fill"
        case .occupied:
            return "person.fill"
        case .empty:
            return "circle"
        case .ready:
            return "arrow.right.circle.fill"
        case .cleanup:
            return "wrench.fill"
        }
    }
}

struct EncounterExport: Codable {
    let activeEncounters: [MedicalEncounter]
    let completedEncounters: [MedicalEncounter]
    let exportDate: Date
}

enum EncounterFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case inProgress = "In Progress"
    case completed = "Completed"
    case today = "Today"
}

// MARK: - Enhanced Encounters View

struct EnhancedEncountersView: View {
    @ObservedObject var encounterManager: EncounterManager
    @ObservedObject var environmentManager: EDEnvironmentManager
    @State private var searchText = ""
    @State private var selectedFilter: EncounterFilter = .all
    @State private var showingStats = false
    
    var filteredEncounters: [MedicalEncounter] {
        let allEncounters = encounterManager.activeEncounters
        var filtered = allEncounters
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .inProgress }
        case .inProgress:
            filtered = filtered.filter { $0.status == .inProgress }
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        case .today:
            let calendar = Calendar.current
            filtered = filtered.filter { calendar.isDate($0.startTime, inSameDayAs: Date()) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { encounter in
                (encounter.room.number.localizedCaseInsensitiveContains(searchText)) ||
                (encounter.chiefComplaint.localizedCaseInsensitiveContains(searchText))
            }
        }
        
        return filtered.sorted { $0.startTime > $1.startTime }
    }
    
    private var encounterStats: EncounterStats {
        let statistics = encounterManager.getEncounterStatistics()
        return EncounterStats(
            totalToday: statistics.totalToday,
            activeCount: statistics.activeCount,
            completedToday: statistics.completedCount,
            averageDuration: statistics.averageDuration,
            occupiedBeds: Int(statistics.roomUtilization * Float(encounterManager.availableRooms.count))
        )
    }
    
    private var headerContent: some View {
        Group {
            if showingStats {
                EncounterStatsView(stats: encounterStats)
                    .padding()
            }
        }
    }
    
    private var bedStatusContent: some View {
        BedStatusGridView(
            encounterManager: encounterManager,
            environmentManager: environmentManager
        )
        .padding(.horizontal)
    }
    
    private var searchAndFilterContent: some View {
        VStack(spacing: 8) {
            SearchBar(text: $searchText)
            
            Picker("Filter", selection: $selectedFilter) {
                ForEach(EncounterFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(.horizontal)
    }
    
    private var encountersListContent: some View {
        List {
            ForEach(Array(filteredEncounters.enumerated()), id: \.element.id) { index, encounter in
                EnhancedEncounterRowView(encounter: encounter) {
                    encounterManager.currentEncounter = encounter
                    // encounterManager.selectedBed = encounter.room.number
                }
                .swipeActions(edge: .trailing) {
                    Button("Complete") {
                        encounterManager.completeEncounter(encounter.id)
                    }
                    .tint(.green)
                    
                    Button("Delete") {
                        // TODO: Add delete functionality
                        encounterManager.completeEncounter(encounter.id)
                    }
                    .tint(.red)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                headerContent
                bedStatusContent  
                searchAndFilterContent
                encountersListContent
            }
            .navigationTitle("Patient Encounters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingStats.toggle() }) {
                        Image(systemName: "chart.bar.fill")
                    }
                }
            }
        }
    }
}

struct BedStatusGridView: View {
    let encounterManager: EncounterManager
    let environmentManager: EDEnvironmentManager
    
    let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Bed Status")
                .font(.headline)
                .padding(.bottom, 4)
            
            if let environment = environmentManager.currentEnvironment {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(environment.bedLocations) { bed in
                        BedStatusCard(
                            bed: bed,
                            status: .empty
                        ) {
                            // Switch to bed action
                        }
                    }
                }
            } else {
                Text("No environment configured")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }
}

struct BedStatusCard: View {
    let bed: BedLocation
    let status: BedStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
                    .font(.system(size: 12))
                
                Text(bed.shortName)
                    .font(.caption2)
                    .fontWeight(.medium)
                
                Text(status.rawValue)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(status.color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

func formatTimeAgo(_ date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    let minutes = Int(interval / 60)
    if minutes < 60 {
        return "\(minutes)m ago"
    }
    let hours = minutes / 60
    if hours < 24 {
        return "\(hours)h ago"
    }
    let days = hours / 24
    return "\(days)d ago"
}

struct EnhancedEncounterRowView: View {
    let encounter: MedicalEncounter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(encounter.room.number)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(formatTimeAgo(encounter.startTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(encounter.chiefComplaint.isEmpty ? "No chief complaint" : encounter.chiefComplaint)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text(encounter.status.rawValue.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(encounter.statusColor.opacity(0.2))
                            .foregroundColor(encounter.statusColor)
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        Text(encounter.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct EncounterStatsView: View {
    let stats: EncounterStats
    
    var body: some View {
        HStack(spacing: 16) {
            StatCard(title: "Today", value: "\(stats.totalToday)")
            StatCard(title: "Active", value: "\(stats.activeCount)")
            StatCard(title: "Completed", value: "\(stats.completedToday)")
            StatCard(title: "Avg Time", value: stats.formattedAverageDuration)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search encounters...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension MedicalEncounter {
    var statusColor: Color {
        switch status {
        case .inProgress:
            return .blue
        case .completed:
            return .green
        case .waiting:
            return .orange
        case .followUp:
            return .purple
        case .discharged:
            return .gray
        }
    }
    
    var formattedDuration: String {
        let endTime = self.endTime ?? Date()
        let duration = endTime.timeIntervalSince(startTime)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}