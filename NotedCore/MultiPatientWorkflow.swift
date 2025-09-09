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
    case ready = "Ready for Discharge"
    case cleanup = "Needs Cleanup"
    
    var color: Color {
        switch self {
        case .available:
            return .green
        case .occupied:
            return .red
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
        let allEncounters = encounterManager.activeEncounters + encounterManager.completedEncounters
        var filtered = allEncounters
        
        // Apply status filter
        switch selectedFilter {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.status == .active }
        case .completed:
            filtered = filtered.filter { $0.status == .completed }
        case .today:
            let calendar = Calendar.current
            filtered = filtered.filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { encounter in
                (encounter.bed?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (encounter.chiefComplaint?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return filtered.sorted { $0.timestamp > $1.timestamp }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Quick Stats Header
                if showingStats {
                    EncounterStatsView(stats: encounterManager.getEncounterStats())
                        .padding()
                }
                
                // Bed Status Overview
                BedStatusGridView(
                    encounterManager: encounterManager,
                    environmentManager: environmentManager
                )
                .padding(.horizontal)
                
                // Search and Filter
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
                
                // Encounters List
                List {
                    ForEach(filteredEncounters) { encounter in
                        EnhancedEncounterRowView(encounter: encounter) {
                            encounterManager.currentEncounter = encounter
                            encounterManager.selectedBed = encounter.bed ?? ""
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Complete") {
                                encounterManager.completeEncounter(encounter)
                            }
                            .tint(.green)
                            
                            Button("Delete") {
                                encounterManager.deleteEncounter(encounter)
                            }
                            .tint(.red)
                        }
                    }
                }
            }
            .navigationTitle("Patient Encounters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                            status: encounterManager.getBedStatus(bed.displayName)
                        ) {
                            encounterManager.switchToBed(bed.displayName)
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

struct EnhancedEncounterRowView: View {
    let encounter: MedicalEncounter
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(encounter.bed ?? "Unknown Bed")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(encounter.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(encounter.chiefComplaint ?? "No chief complaint")
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
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Extensions

extension MedicalEncounter {
    var statusColor: Color {
        switch status {
        case .active:
            return .blue
        case .completed:
            return .green
        case .draft:
            return .orange
        }
    }
    
    var formattedDuration: String {
        let endTime = self.endTime ?? Date()
        let duration = endTime.timeIntervalSince(timestamp)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}