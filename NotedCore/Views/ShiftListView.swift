//  ShiftListView.swift
//  The shift board (PR6): every encounter of the shift, status at a glance, review/edit/sign in
//  ANY order, and the entry point to dictate a disposition later. Thin SwiftUI shell over
//  NotedCoreKit.ShiftBoard (the ordering/sign/badge logic that IS unit-tested on macOS).
//
//  DEVICE/UI code — not built in the package suite. Verify layout + navigation on device.

import SwiftUI
import SwiftData
import NotedCoreKit

@MainActor
@Observable
final class EncounterListModel {
    private let context: ModelContext
    private(set) var encounters: [Encounter] = []

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    func reload() {
        encounters = (try? ShiftBoard.fetchAllForDisplay(in: context)) ?? []
    }

    /// Sign a drafted encounter — order-independent.
    func sign(_ encounter: Encounter) {
        _ = try? ShiftBoard.sign(encounter, in: context)
        reload()
    }
}

struct ShiftListView: View {
    @State var model: EncounterListModel

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.encounters, id: \.id) { encounter in
                    NavigationLink(value: encounter.id) {
                        EncounterRow(encounter: encounter)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Shift")
            .navigationDestination(for: UUID.self) { id in
                if let encounter = model.encounters.first(where: { $0.id == id }) {
                    EncounterDetailView(encounter: encounter) { model.sign(encounter) }
                }
            }
            .refreshable { model.reload() }
        }
    }
}

private struct EncounterRow: View {
    let encounter: Encounter

    var body: some View {
        let status = ShiftBoard.status(for: encounter.phase)
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: status.badge))
                .frame(width: 4)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.chiefComplaint.isEmpty ? "New encounter" : encounter.chiefComplaint)
                    .font(.headline)
                    .lineLimit(1)
                Text(encounter.updatedAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ShiftRowBadge(status: status)
        }
        .padding(.vertical, 4)
    }
}

private struct ShiftRowBadge: View {
    let status: EncounterStatus
    var body: some View {
        Text(status.label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color(for: status.badge).opacity(0.15), in: Capsule())
            .foregroundStyle(color(for: status.badge))
    }
}

/// Semantic status colours — separate from any brand accent. Red/amber/green carry meaning.
private func color(for badge: EncounterBadge) -> Color {
    switch badge {
    case .recording:           return .blue
    case .working:             return .secondary
    case .readyToSign:         return .orange
    case .awaitingDisposition: return .orange
    case .signed:              return .green
    case .failed:              return .red
    }
}
