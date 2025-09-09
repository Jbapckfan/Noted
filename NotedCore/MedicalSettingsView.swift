import SwiftUI

struct MedicalSettingsView: View {
    @StateObject private var appState = CoreAppState.shared
    @State private var showingSpecialtyPicker = false
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - Billing Code Section
                Section {
                    Toggle(isOn: $appState.isBillingCodeSuggestionsEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Billing Code Suggestions")
                                    .font(.headline)
                                Text("Auto-suggest ICD-10 and CPT codes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    
                    if appState.isBillingCodeSuggestionsEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            // Billing preferences
                            Toggle("Show codes in real-time", isOn: $appState.billingCodePreferences.showInRealTime)
                                .font(.subheadline)
                            
                            Toggle("Optimize for revenue", isOn: $appState.billingCodePreferences.optimizeForRevenue)
                                .font(.subheadline)
                            
                            Toggle("Include time-based billing", isOn: $appState.billingCodePreferences.includeTimeBasedBilling)
                                .font(.subheadline)
                            
                            Toggle("Auto-detect procedures", isOn: $appState.billingCodePreferences.autoDetectProcedures)
                                .font(.subheadline)
                            
                            Toggle("Suggest higher E/M levels", isOn: $appState.billingCodePreferences.suggestHigherLevels)
                                .font(.subheadline)
                            
                            // Specialty selector
                            HStack {
                                Text("Specialty")
                                    .font(.subheadline)
                                Spacer()
                                Picker("Specialty", selection: $appState.billingCodePreferences.specialtyMode) {
                                    ForEach(CoreAppState.MedicalSpecialty.allCases, id: \.self) { specialty in
                                        Text(specialty.rawValue).tag(specialty)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .font(.subheadline)
                            }
                        }
                        .padding(.leading, 36)
                        .transition(.opacity)
                    }
                } header: {
                    Text("BILLING & CODING")
                } footer: {
                    if appState.isBillingCodeSuggestionsEnabled {
                        Text("Billing suggestions help maximize reimbursement and ensure proper documentation for medical necessity.")
                    }
                }
                
                // MARK: - Optional Alerts Section
                Section {
                    // Contraindication Alerts
                    Toggle(isOn: $appState.isContraindicationAlertsEnabled) {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Contraindication Alerts")
                                    .font(.headline)
                                Text("Drug interactions and allergy warnings")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        } icon: {
                            Image(systemName: "pills.circle.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .orange))
                    
                    if appState.isContraindicationAlertsEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            // Alert preferences
                            Toggle("Critical condition alerts", isOn: $appState.clinicalAlertPreferences.showCriticalAlerts)
                                .font(.subheadline)
                            
                            Toggle("Drug interaction warnings", isOn: $appState.clinicalAlertPreferences.showDrugInteractions)
                                .font(.subheadline)
                            
                            Toggle("Allergy warnings", isOn: $appState.clinicalAlertPreferences.showAllergyWarnings)
                                .font(.subheadline)
                            
                            Toggle("Dosage alerts", isOn: $appState.clinicalAlertPreferences.showDosageAlerts)
                                .font(.subheadline)
                            
                            Toggle("Missing documentation alerts", isOn: $appState.clinicalAlertPreferences.showMissingDocumentation)
                                .font(.subheadline)
                            
                            Toggle("Malpractice risk warnings", isOn: $appState.clinicalAlertPreferences.showMalpracticeRisks)
                                .font(.subheadline)
                            
                            Divider()
                            
                            Toggle("Alert sounds", isOn: $appState.clinicalAlertPreferences.alertSoundEnabled)
                                .font(.subheadline)
                            
                            Toggle("Alert vibration", isOn: $appState.clinicalAlertPreferences.alertVibrationEnabled)
                                .font(.subheadline)
                        }
                        .padding(.leading, 36)
                        .transition(.opacity)
                    }
                } header: {
                    Text("CLINICAL SAFETY ALERTS")
                } footer: {
                    Text("⚠️ Clinical alerts help prevent medical errors and ensure patient safety. Disabling these may increase liability risk.")
                        .foregroundColor(.orange)
                }
                
                // MARK: - Alert Examples Section
                if appState.isContraindicationAlertsEnabled {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            AlertExampleRow(
                                icon: "pills.fill",
                                color: .orange,
                                title: "Drug Interaction",
                                message: "Warfarin + Aspirin increases bleeding risk"
                            )
                            
                            AlertExampleRow(
                                icon: "allergens",
                                color: .orange,
                                title: "Allergy Alert",
                                message: "Patient allergic to Penicillin"
                            )
                        }
                    } header: {
                        Text("EXAMPLE ALERTS")
                    }
                }
                
                // MARK: - Statistics Section
                Section {
                    HStack {
                        Label("Alerts triggered today", systemImage: "bell.fill")
                        Spacer()
                        Text("12")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Critical alerts", systemImage: "exclamationmark.triangle.fill")
                        Spacer()
                        Text("2")
                            .foregroundColor(.red)
                    }
                    
                    HStack {
                        Label("Revenue optimized", systemImage: "dollarsign.circle.fill")
                        Spacer()
                        Text("+$340")
                            .foregroundColor(.green)
                    }
                    
                    HStack {
                        Label("Errors prevented", systemImage: "checkmark.shield.fill")
                        Spacer()
                        Text("5")
                            .foregroundColor(.blue)
                    }
                } header: {
                    Text("TODAY'S IMPACT")
                }
            }
            .navigationTitle("Medical Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct AlertExampleRow: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
struct MedicalSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MedicalSettingsView()
    }
}