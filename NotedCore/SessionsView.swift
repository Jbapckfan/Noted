import SwiftUI

struct SessionsView: View {
    @ObservedObject var encounterManager = EncounterManager.shared
    @State private var encounterToDelete: MedicalEncounter?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            VStack {
                if encounterManager.activeEncounters.isEmpty {
                    emptyStateView
                } else {
                    encounterListView
                }
            }
            .navigationTitle("Encounters")
            .alert(isPresented: $showDeleteConfirmation) {
                deleteConfirmationAlert
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Encounters Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.primary)

            Text("Start recording to create your first encounter")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var encounterListView: some View {
        List {
            ForEach(encounterManager.activeEncounters) { encounter in
                EncounterTileView(
                    encounter: encounter,
                    onPause: { encounterManager.pauseEncounter(encounter.id) },
                    onResume: { encounterManager.resumeEncounter(encounter.id) },
                    onDelete: {
                        encounterToDelete = encounter
                        showDeleteConfirmation = true
                    }
                )
            }
        }
    }

    private var deleteConfirmationAlert: Alert {
        Alert(
            title: Text("Delete Encounter"),
            message: Text("Are you sure you want to delete the encounter for \(encounterToDelete?.room.number ?? "")? This action cannot be undone."),
            primaryButton: .destructive(Text("Delete")) {
                if let encounter = encounterToDelete {
                    encounterManager.deleteEncounter(encounter.id)
                }
                encounterToDelete = nil
            },
            secondaryButton: .cancel {
                encounterToDelete = nil
            }
        )
    }
}

struct EncounterTileView: View {
    let encounter: MedicalEncounter
    let onPause: () -> Void
    let onResume: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with room and status
            HStack {
                // Room and Chief Complaint
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: encounter.room.type.icon)
                            .foregroundColor(.blue)
                        Text("Room \(encounter.room.number)")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }

                    if !encounter.chiefComplaint.isEmpty {
                        Text(encounter.chiefComplaint)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Status badge
                EncounterStatusBadge(status: encounter.status, isPaused: encounter.isPaused)
            }

            // Time information
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(timeDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if encounter.isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("Paused")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                if encounter.isActive {
                    if encounter.isPaused {
                        Button(action: onResume) {
                            Label("Resume", systemImage: "play.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(action: onPause) {
                            Label("Pause", systemImage: "pause.circle.fill")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var timeDisplay: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let startTime = formatter.string(from: encounter.startTime)

        if let endTime = encounter.endTime {
            let endTimeStr = formatter.string(from: endTime)
            return "\(startTime) - \(endTimeStr)"
        } else {
            let elapsed = Date().timeIntervalSince(encounter.startTime) - encounter.totalPausedDuration
            let minutes = Int(elapsed / 60)
            return "\(startTime) • \(minutes) min"
        }
    }
}

struct EncounterStatusBadge: View {
    let status: EncounterManager.EncounterStatus
    let isPaused: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .cornerRadius(8)
    }

    private var statusText: String {
        if isPaused {
            return "Paused"
        }
        return status.rawValue
    }

    private var statusColor: Color {
        if isPaused {
            return .orange
        }

        switch status {
        case .waiting:
            return hexToColor(status.color)
        case .inProgress:
            return hexToColor(status.color)
        case .completed:
            return hexToColor(status.color)
        case .followUp:
            return hexToColor(status.color)
        case .discharged:
            return hexToColor(status.color)
        }
    }

    private func hexToColor(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return .gray }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        return Color(red: r, green: g, blue: b)
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView()
    }
}