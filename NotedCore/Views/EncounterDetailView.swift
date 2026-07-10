//  EncounterDetailView.swift
//  Review + edit + sign one encounter (PR6). Signing is allowed whenever a draft exists,
//  independent of every other encounter. Also hosts the "Dictate disposition" entry point that
//  the discharge pipeline (PR8) hangs off of — dictating from HERE binds the audio to this
//  encounter's persisted id, so an hours-later disposition still lands on the right chart.
//
//  Trust semantics (Codex review): a signed note is read-only (no silent post-sign edits); only a
//  MANUAL-TEST encounter exposes an editable source transcript + regenerate; verification reads as a
//  positive safety signal (what was removed), not an alarm; edits after grounding are flagged.
//
//  DEVICE/UI code — not built in the package suite. Verify on device.

import SwiftUI
import SwiftData
import NotedCoreKit

struct EncounterDetailView: View {
    @Bindable var encounter: Encounter
    var onSign: () -> Void
    var onDictateDisposition: (() -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil

    @State private var confirmSign = false
    @State private var confirmRegenerate = false

    private var isSigned: Bool { encounter.signedAt != nil || encounter.phase == .signed }
    private var isTest: Bool { encounter.source == .manualTest }
    private var canEditSource: Bool { isTest && !isSigned }

    var body: some View {
        Form {
            Section {
                LabeledContent("Status", value: ShiftBoard.status(for: encounter.phase).label)
                LabeledContent("Source", value: isTest ? "Manual test transcript" : "Recorded on device")
                if let signedAt = encounter.signedAt {
                    LabeledContent("Signed", value: signedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }

            groundingSection

            Section("Note") {
                if isSigned {
                    Text(encounter.noteText ?? "")
                        .font(.body)
                        .textSelection(.enabled)
                } else {
                    TextEditor(text: Binding(
                        get: { encounter.noteText ?? "" },
                        set: { newValue in
                            guard newValue != (encounter.noteText ?? "") else { return }
                            encounter.noteText = newValue
                            encounter.noteEditedAfterGrounding = true
                            encounter.updatedAt = Date()
                        }
                    ))
                    .frame(minHeight: 260)
                    .font(.body)
                }
            }

            if encounter.transcript != nil || canEditSource {
                Section {
                    if canEditSource {
                        TextEditor(text: Binding(
                            get: { encounter.transcript ?? "" },
                            set: { encounter.transcript = $0; encounter.updatedAt = Date() }
                        ))
                        .frame(minHeight: 140)
                        .font(.callout)
                        if onRegenerate != nil {
                            Button { confirmRegenerate = true } label: {
                                Label("Generate note from this transcript", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled((encounter.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    } else {
                        Text(encounter.transcript ?? "")
                            .font(.callout)
                            .textSelection(.enabled)
                    }
                } header: {
                    Text(isTest ? "Test transcript" : "Source transcript")
                } footer: {
                    Text(canEditSource
                         ? "Edit and regenerate to re-run the summarizer on your changes."
                         : "Transcribed on device — the source material for the draft above.")
                }
            }

            if encounter.dischargeClinicianText != nil || encounter.dischargePatientText != nil || encounter.phase == .dischargeDrafted {
                Section("Discharge — clinician") {
                    dischargeEditor(
                        get: { encounter.dischargeClinicianText ?? "" },
                        set: { encounter.dischargeClinicianText = $0 },
                        minHeight: 140
                    )
                }
                Section {
                    dischargeEditor(
                        get: { encounter.dischargePatientText ?? "" },
                        set: { encounter.dischargePatientText = $0 },
                        minHeight: 140
                    )
                } header: {
                    Text("Patient discharge instructions")
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
                    Button("Sign note") { confirmSign = true }.bold()
                }
            }
        }
        .confirmationDialog("Sign this note?", isPresented: $confirmSign, titleVisibility: .visible) {
            Button("Sign note") { onSign() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signing locks the note and transcript. You can't silently edit them afterward.")
        }
        .confirmationDialog("Regenerate the note?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate", role: .destructive) { onRegenerate?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current draft note with a fresh one from the transcript above.")
        }
    }

    // MARK: - Grounding summary (a safety signal, not an alarm)

    @ViewBuilder
    private var groundingSection: some View {
        if let report = verificationReport {
            Section("Grounding") {
                if encounter.noteEditedAfterGrounding {
                    Label("Edited after the grounding check — your edits were not re-checked",
                          systemImage: "pencil")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
                if report.flags.isEmpty {
                    Label("Draft checked against the source — nothing removed",
                          systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("\(report.flags.count) unsupported item\(report.flags.count == 1 ? "" : "s") excluded from the draft",
                          systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.tint)
                    DisclosureGroup("See excluded items") {
                        ForEach(Array(report.flags.enumerated()), id: \.offset) { _, flag in
                            VStack(alignment: .leading, spacing: 3) {
                                Label(flag.claim, systemImage: "minus.circle.fill")
                                    .font(.callout.weight(.medium))
                                Text(flag.detail)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .font(.callout)
                }
            }
        }
    }

    // MARK: - Discharge editor (locked once signed)

    @ViewBuilder
    private func dischargeEditor(get: @escaping () -> String, set: @escaping (String) -> Void, minHeight: CGFloat) -> some View {
        if isSigned {
            Text(get()).font(.body).textSelection(.enabled)
        } else {
            TextEditor(text: Binding(get: get, set: { set($0); encounter.updatedAt = Date() }))
                .frame(minHeight: minHeight)
                .font(.body)
        }
    }

    private var canDictateDisposition: Bool {
        onDictateDisposition != nil &&
        (encounter.phase == .signed || encounter.phase == .noteDrafted || encounter.phase == .awaitingDisposition)
    }

    private var verificationReport: VerificationReport? {
        guard let json = encounter.verificationReport,
              let data = json.data(using: .utf8),
              let report = try? JSONDecoder().decode(VerificationReport.self, from: data)
        else { return nil }
        return report
    }
}
