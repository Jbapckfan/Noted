import SwiftUI

// MARK: - Environment Builder View
struct EDEnvironmentBuilderView: View {
    @EnvironmentObject var environmentManager: EDEnvironmentManager
    @State private var showingNewEnvironment = false
    @State private var showingEditEnvironment = false
    @State private var environmentToEdit: EDEnvironment?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Current Environment
                currentEnvironmentSection
                
                // Bed Layout
                bedLayoutSection
                
                Spacer()
            }
            .padding()
            .navigationTitle("ED Environment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button("New Environment") {
                            showingNewEnvironment = true
                        }
                        
                        if environmentManager.currentEnvironment != nil {
                            Button("Edit Current") {
                                environmentToEdit = environmentManager.currentEnvironment
                                showingEditEnvironment = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewEnvironment) {
            EnvironmentEditorView(environmentManager: environmentManager)
        }
        .sheet(isPresented: $showingEditEnvironment) {
            if let environment = environmentToEdit {
                EnvironmentEditorView(
                    environmentManager: environmentManager,
                    editingEnvironment: environment
                )
            }
        }
    }
    
    private var currentEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Current Environment")
                    .font(.headline)
                
                Spacer()
                
                if !environmentManager.availableEnvironments.isEmpty {
                    Picker("Environment", selection: Binding(
                        get: { environmentManager.currentEnvironment },
                        set: { if let env = $0 { environmentManager.setCurrentEnvironment(env) } }
                    )) {
                        ForEach(environmentManager.availableEnvironments) { env in
                            Text(env.name).tag(env as EDEnvironment?)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
            
            if let currentEnv = environmentManager.currentEnvironment {
                Text(currentEnv.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("\(currentEnv.bedLocations.count) beds configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("No environment selected")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var bedLayoutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Bed Layout")
                .font(.headline)
            
            if let environment = environmentManager.currentEnvironment {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(environment.bedLocations.sorted { $0.sortOrder < $1.sortOrder }) { bed in
                        BedButton(
                            bed: bed,
                            isSelected: environmentManager.selectedBed?.id == bed.id
                        ) {
                            environmentManager.selectBed(bed)
                        }
                    }
                }
            } else {
                Text("Create or select an environment to see bed layout")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
    }
}

// MARK: - Bed Button Component
struct BedButton: View {
    let bed: BedLocation
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: bed.category.icon)
                    .font(.title3)
                    .foregroundColor(bed.category.color)
                
                Text(bed.shortName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? bed.category.color.opacity(0.2) : Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? bed.category.color : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Environment Editor View
struct EnvironmentEditorView: View {
    @ObservedObject var environmentManager: EDEnvironmentManager
    let editingEnvironment: EDEnvironment?
    
    @State private var environmentName = ""
    @State private var bedLocations: [BedLocation] = []
    @State private var newBedName = ""
    @State private var newBedVoiceID = ""
    @State private var newBedCategory: BedCategory = .acute
    @Environment(\.dismiss) private var dismiss
    
    init(environmentManager: EDEnvironmentManager, editingEnvironment: EDEnvironment? = nil) {
        self.environmentManager = environmentManager
        self.editingEnvironment = editingEnvironment
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Environment Details") {
                    TextField("Environment Name", text: $environmentName)
                }
                
                Section("Beds") {
                    ForEach(bedLocations) { bed in
                        HStack {
                            Image(systemName: bed.category.icon)
                                .foregroundColor(bed.category.color)
                            
                            VStack(alignment: .leading) {
                                Text(bed.displayName)
                                    .font(.headline)
                                Text("Voice: '\(bed.voiceIdentifier)'")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(bed.category.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(bed.category.color.opacity(0.2))
                                .cornerRadius(6)
                        }
                    }
                    .onDelete(perform: deleteBed)
                    .onMove(perform: moveBed)
                    
                    // Add new bed
                    HStack {
                        TextField("Bed Name", text: $newBedName)
                        TextField("Voice ID", text: $newBedVoiceID)
                        Picker("Category", selection: $newBedCategory) {
                            ForEach(BedCategory.allCases, id: \.self) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        Button("Add") {
                            addBed()
                        }
                        .disabled(newBedName.isEmpty || newBedVoiceID.isEmpty)
                    }
                }
            }
            .navigationTitle(editingEnvironment == nil ? "New Environment" : "Edit Environment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .automatic) {
                    Button("Save") {
                        saveEnvironment()
                    }
                    .disabled(environmentName.isEmpty || bedLocations.isEmpty)
                }
            }
        }
        .onAppear {
            if let editing = editingEnvironment {
                environmentName = editing.name
                bedLocations = editing.bedLocations
            }
        }
    }
    
    private func addBed() {
        let newBed = BedLocation(
            id: UUID(),
            displayName: newBedName,
            voiceIdentifier: newBedVoiceID,
            category: newBedCategory,
            sortOrder: bedLocations.count + 1
        )
        
        bedLocations.append(newBed)
        newBedName = ""
        newBedVoiceID = ""
    }
    
    private func deleteBed(at offsets: IndexSet) {
        bedLocations.remove(atOffsets: offsets)
    }
    
    private func moveBed(from source: IndexSet, to destination: Int) {
        bedLocations.move(fromOffsets: source, toOffset: destination)
        
        // Update sort orders
        for (index, _) in bedLocations.enumerated() {
            bedLocations[index].sortOrder = index + 1
        }
    }
    
    private func saveEnvironment() {
        if let editing = editingEnvironment {
            // Update existing
            if let index = environmentManager.availableEnvironments.firstIndex(where: { $0.id == editing.id }) {
                environmentManager.availableEnvironments[index] = EDEnvironment(
                    id: editing.id,
                    name: environmentName,
                    bedLocations: bedLocations,
                    createdDate: editing.createdDate
                )
                environmentManager.saveEnvironments()
            }
        } else {
            // Create new
            let newEnvironment = environmentManager.createEnvironment(
                name: environmentName,
                bedLocations: bedLocations
            )
            environmentManager.setCurrentEnvironment(newEnvironment)
        }
        
        dismiss()
    }
}