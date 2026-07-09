//  EncounterDetailView.swift
//  Review + edit + sign one encounter (PR6). Signing is allowed whenever a draft exists,
//  independent of every other encounter. Also hosts the "Dictate disposition" entry point that
//  the discharge pipeline (PR8) hangs off of — dictating from HERE binds the audio to this
//  encounter's persisted id, so an hours-later disposition still lands on the right chart.
//
//  DEVICE/UI code — not built in the package suite. Verify on device.

import SwiftUI
import SwiftData
import NotedCoreKit

struct EncounterDetailView: View {
    @Bindable var encounter: Encounter
    var onSign: () -> Void
    var onDictateDisposition: (() -> Void)? = nil

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: ShiftBoard.status(for: encounter.phase).label)
                if let signedAt = encounter.signedAt {
                    LabeledContent("Signed", value: signedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if let flags = verificationFlags, !flags.isEmpty {
                Section("Review flags") {
                    ForEach(Array(flags.enumerated()), id: \.offset) { _, flag in
                        Label(flag.claim, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(flag.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section("Note") {
                TextEditor(text: Binding(
                    get: { encounter.noteText ?? "" },
                    set: { encounter.noteText = $0; encounter.updatedAt = Date() }
                ))
                .frame(minHeight: 220)
                .font(.body.monospaced())
            }

            if let transcript = encounter.transcript, !transcript.isEmpty {
                Section("Transcript — exactly what was heard") {
                    Text(transcript)
                        .font(.callout)
                        .textSelection(.enabled)
                }
            }

            if encounter.dischargeClinicianText != nil || encounter.dischargePatientText != nil || encounter.phase == .dischargeDrafted {
                Section("Discharge — clinician") {
                    TextEditor(text: Binding(
                        get: { encounter.dischargeClinicianText ?? "" },
                        set: { encounter.dischargeClinicianText = $0; encounter.updatedAt = Date() }
                    ))
                    .frame(minHeight: 140)
                    .font(.body.monospaced())
                }
                Section {
                    TextEditor(text: Binding(
                        get: { encounter.dischargePatientText ?? "" },
                        set: { encounter.dischargePatientText = $0; encounter.updatedAt = Date() }
                    ))
                    .frame(minHeight: 140)
                } header: {
                    Text("Patient discharge instructions — customizable")
                } footer: {
                    Text("Edit freely; the patient version is yours to tailor.")
                }
            }

            if canDictateDisposition {
                Section {
                    Button {
                        onDictateDisposition?()
                    } label: {
                        Label("Dictate disposition", systemImage: "mic.fill")
                    }
                }
            }
        }
        .navigationTitle(encounter.chiefComplaint.isEmpty ? "Encounter" : encounter.chiefComplaint)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if ShiftBoard.isSignable(encounter) {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sign", action: onSign).bold()
                }
            }
        }
    }

    private var canDictateDisposition: Bool {
        // once a note is signed/drafted, the disposition can be captured (possibly hours later)
        onDictateDisposition != nil &&
        (encounter.phase == .signed || encounter.phase == .noteDrafted || encounter.phase == .awaitingDisposition)
    }

    private var verificationFlags: [VerificationFlag]? {
        guard let json = encounter.verificationReport,
              let data = json.data(using: .utf8),
              let report = try? JSONDecoder().decode(VerificationReport.self, from: data)
        else { return nil }
        return report.flags
    }
}
