//  EncounterDetailView.swift
//  Review + edit + sign one encounter as a DOCUMENT (Codex review): a compact header, a grounding
//  safety summary, and a segmented Note / Source / Discharge surface with the note as the primary
//  work area and a bottom "Sign note" action.
//
//  Trust semantics preserved: a signed note is read-only; only a MANUAL-TEST encounter exposes an
//  editable source transcript + regenerate; verification reads as a safety signal, not an alarm;
//  edits after grounding are flagged.
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

    @State private var tab: DetailTab = .note
    @State private var dischargeAudience: DischargeAudience = .clinician
    @State private var confirmSign = false
    @State private var confirmRegenerate = false

    private enum DetailTab: String, CaseIterable { case note = "Note", source = "Source", discharge = "Discharge" }
    private enum DischargeAudience: String, CaseIterable { case clinician = "Clinician", patient = "Patient" }

    private var isSigned: Bool { encounter.signedAt != nil || encounter.phase == .signed }
    private var isTest: Bool { encounter.source == .manualTest }
    private var canEditSource: Bool { isTest && !isSigned }
    private var hasDischarge: Bool {
        encounter.dischargeClinicianText != nil || encounter.dischargePatientText != nil || encounter.phase == .dischargeDrafted
    }
    private var availableTabs: [DetailTab] { hasDischarge ? DetailTab.allCases : [.note, .source] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s4) {
                header
                grounding
                Picker("View", selection: $tab) {
                    ForEach(availableTabs, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                content
            }
            .padding(Theme.s4)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(encounter.chiefComplaint.isEmpty ? "Encounter" : encounter.chiefComplaint)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { primaryAction }
        .confirmationDialog("Sign this note?", isPresented: $confirmSign, titleVisibility: .visible) {
            Button("Sign note") { onSign() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Signing locks the note and transcript — no silent edits afterward.")
        }
        .confirmationDialog("Regenerate the note?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Regenerate", role: .destructive) { onRegenerate?() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces the current draft with a fresh note from the transcript.")
        }
    }

    private var header: some View {
        HStack(spacing: Theme.s2) {
            Label(ShiftBoard.status(for: encounter.phase).label, systemImage: isSigned ? "lock.fill" : "circle.dashed")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSigned ? Theme.signed : Theme.accent)
            Spacer()
            Text(isTest ? "Manual test" : "Recorded on device")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // A safety signal (what the gate removed), not an alarm.
    @ViewBuilder private var grounding: some View {
        if let report = verificationReport {
            VStack(alignment: .leading, spacing: Theme.s2) {
                if encounter.noteEditedAfterGrounding {
                    Label("Edited after the grounding check — your edits weren't re-checked", systemImage: "pencil")
                        .font(.footnote).foregroundStyle(Theme.caution)
                }
                if report.flags.isEmpty {
                    Label("Draft checked against the source — nothing removed", systemImage: "checkmark.shield.fill")
                        .font(.subheadline).foregroundStyle(Theme.signed)
                } else {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: Theme.s2) {
                            ForEach(Array(report.flags.enumerated()), id: \.offset) { _, flag in
                                VStack(alignment: .leading, spacing: 2) {
                                    Label(flag.claim, systemImage: "minus.circle.fill").font(.footnote.weight(.medium))
                                    Text(flag.detail).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.top, Theme.s1)
                    } label: {
                        Label("\(report.flags.count) unsupported item\(report.flags.count == 1 ? "" : "s") excluded",
                              systemImage: "checkmark.shield.fill")
                            .font(.subheadline).foregroundStyle(Theme.accent)
                    }
                    .tint(Theme.accent)
                }
            }
            .padding(Theme.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.fieldRadius))
        }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .note: noteContent
        case .source: sourceContent
        case .discharge: dischargeContent
        }
    }

    @ViewBuilder private var noteContent: some View {
        if isSigned {
            readOnly(encounter.noteText ?? "", font: .body)
        } else {
            editor(minHeight: 380, font: .body,
                   get: { encounter.noteText ?? "" },
                   set: { newValue in
                       guard newValue != (encounter.noteText ?? "") else { return }
                       encounter.noteText = newValue
                       encounter.noteEditedAfterGrounding = true
                       encounter.updatedAt = Date()
                   })
        }
    }

    @ViewBuilder private var sourceContent: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            Text(isTest ? "Test transcript" : "Source transcript — transcribed on device")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if canEditSource {
                editor(minHeight: 240, font: .callout,
                       get: { encounter.transcript ?? "" },
                       set: { encounter.transcript = $0; encounter.updatedAt = Date() })
                Button { confirmRegenerate = true } label: {
                    Label("Generate note from this transcript", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight)
                }
                .buttonStyle(.bordered).tint(Theme.accent)
                .disabled((encounter.transcript ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } else {
                readOnly(encounter.transcript ?? "", font: .callout)
            }
        }
    }

    @ViewBuilder private var dischargeContent: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            Picker("Audience", selection: $dischargeAudience) {
                ForEach(DischargeAudience.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            let isClinician = dischargeAudience == .clinician
            if isSigned {
                readOnly((isClinician ? encounter.dischargeClinicianText : encounter.dischargePatientText) ?? "", font: .body)
            } else {
                editor(minHeight: 260, font: .body,
                       get: { (isClinician ? encounter.dischargeClinicianText : encounter.dischargePatientText) ?? "" },
                       set: { newValue in
                           if isClinician { encounter.dischargeClinicianText = newValue }
                           else { encounter.dischargePatientText = newValue }
                           encounter.updatedAt = Date()
                       })
                if !isClinician {
                    Text("Edit freely; the patient version is yours to tailor.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if ShiftBoard.isSignable(encounter) || canDictateDisposition {
            VStack {
                if ShiftBoard.isSignable(encounter) {
                    Button { confirmSign = true } label: {
                        Label("Sign note", systemImage: "signature")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                } else if canDictateDisposition {
                    Button { onDictateDisposition?() } label: {
                        Label("Dictate disposition", systemImage: "mic.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: Theme.primaryControlHeight)
                    }
                    .buttonStyle(.bordered).tint(Theme.accent)
                }
            }
            .padding(.horizontal, Theme.s4)
            .padding(.vertical, Theme.s2)
            .background(.bar)
            .overlay(alignment: .top) { Divider() }
        }
    }

    // MARK: - Helpers

    private func editor(minHeight: CGFloat, font: Font, get: @escaping () -> String, set: @escaping (String) -> Void) -> some View {
        TextEditor(text: Binding(get: get, set: set))
            .font(font)
            .frame(minHeight: minHeight)
            .padding(Theme.s2)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.fieldRadius))
    }

    private func readOnly(_ text: String, font: Font) -> some View {
        Text(text.isEmpty ? "—" : text)
            .font(font)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.s3)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: Theme.fieldRadius))
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
