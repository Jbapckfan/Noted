import SwiftUI

// MARK: - Templates Community View
struct TemplatesCommunityView: View {
    @StateObject private var templateService = TemplatesCommunityService.shared
    @State private var selectedTab = 0
    @State private var showingTemplateDetail: MedicalTemplate?
    @State private var showingVoiceExamples = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter Bar
                searchAndFilterBar
                
                // Tab Selection
                Picker("View", selection: $selectedTab) {
                    Text("My Templates").tag(0)
                    Text("Community").tag(1)
                    Text("Favorites").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content
                ScrollView {
                    switch selectedTab {
                    case 0:
                        myTemplatesView
                    case 1:
                        communityTemplatesView
                    case 2:
                        favoritesView
                    default:
                        EmptyView()
                    }
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                toolbarContent
            }
            .sheet(item: $showingTemplateDetail) { template in
                TemplateDetailView(template: template)
            }
            .sheet(isPresented: $showingVoiceExamples) {
                VoiceCommandExamplesView()
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search templates...", text: $templateService.searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Filters
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Category filter
                    Menu {
                        Button("All Categories") {
                            templateService.selectedCategory = nil
                        }
                        Divider()
                        ForEach(TemplateCategory.allCases, id: \.self) { category in
                            Button(action: {
                                templateService.selectedCategory = category
                            }) {
                                Label(category.rawValue, systemImage: category.icon)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: templateService.selectedCategory?.icon ?? "square.grid.3x3")
                            Text(templateService.selectedCategory?.rawValue ?? "All Categories")
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)
                    }
                    
                    // Specialty filter
                    Menu {
                        ForEach(MedicalSpecialty.allCases, id: \.self) { specialty in
                            Button(specialty.rawValue) {
                                templateService.selectedSpecialty = specialty
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "stethoscope")
                            Text(templateService.selectedSpecialty.rawValue)
                            Image(systemName: "chevron.down")
                        }
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - My Templates View
    private var myTemplatesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Recently Used
            if !templateService.recentlyUsedTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recently Used")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(templateService.recentlyUsedTemplates) { template in
                                QuickTemplateCard(template: template) {
                                    Task {
                                        await templateService.insertTemplate(template)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            
            // My Templates List
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("My Templates")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        // TODO: Show create template view
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                
                if templateService.myTemplates.isEmpty {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "No Templates Yet",
                        message: "Add templates from the community or create your own"
                    )
                    .padding()
                } else {
                    ForEach(templateService.myTemplates) { template in
                        TemplateRowView(template: template) {
                            showingTemplateDetail = template
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .padding(.top)
    }
    
    // MARK: - Community Templates View
    private var communityTemplatesView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Popular Templates
            VStack(alignment: .leading, spacing: 12) {
                Text("Popular Templates")
                    .font(.headline)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(templateService.popularTemplates.prefix(5)) { template in
                            PopularTemplateCard(template: template) {
                                showingTemplateDetail = template
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // All Templates
            VStack(alignment: .leading, spacing: 12) {
                Text("All Templates")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(templateService.filteredTemplates) { template in
                    TemplateRowView(template: template) {
                        showingTemplateDetail = template
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
    }
    
    // MARK: - Favorites View
    private var favoritesView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if templateService.favoriteTemplates.isEmpty {
                EmptyStateView(
                    icon: "star",
                    title: "No Favorites",
                    message: "Star templates to add them to your favorites"
                )
                .padding()
            } else {
                ForEach(templateService.favoriteTemplates) { template in
                    TemplateRowView(template: template) {
                        showingTemplateDetail = template
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.top)
    }
    
    // MARK: - Toolbar
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button(action: {
                showingVoiceExamples = true
            }) {
                Image(systemName: "mic.circle")
                    .foregroundColor(.blue)
            }
        }
    }
}

// MARK: - Template Row View
struct TemplateRowView: View {
    let template: MedicalTemplate
    let action: () -> Void
    @StateObject private var templateService = TemplatesCommunityService.shared
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    // Category Icon
                    Image(systemName: template.category.icon)
                        .font(.title2)
                        .foregroundColor(template.category.color)
                        .frame(width: 40)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(template.name)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if template.isVerified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        Text(template.specialty.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        // Favorite button
                        Button(action: {
                            templateService.toggleFavorite(template)
                        }) {
                            Image(systemName: templateService.isFavorite(template) ? "star.fill" : "star")
                                .foregroundColor(templateService.isFavorite(template) ? .yellow : .gray)
                        }
                        .buttonStyle(.plain)
                        
                        // Rating
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", template.rating))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(template.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(10)
                        }
                        
                        if template.tags.count > 3 {
                            Text("+\(template.tags.count - 3)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Template Card
struct QuickTemplateCard: View {
    let template: MedicalTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: template.category.icon)
                    .font(.title2)
                    .foregroundColor(template.category.color)
                
                Text(template.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                Text("Quick Insert")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .frame(width: 100, height: 100)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Popular Template Card
struct PopularTemplateCard: View {
    let template: MedicalTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.category.icon)
                        .font(.title3)
                        .foregroundColor(template.category.color)
                    
                    Spacer()
                    
                    if template.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        Text(String(format: "%.1f", template.rating))
                            .font(.caption2)
                    }
                    
                    Spacer()
                    
                    Text("\(template.downloads) uses")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(width: 160, height: 100)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Voice Command Examples View
struct VoiceCommandExamplesView: View {
    @Environment(\.dismiss) private var dismiss
    
    let examples = [
        "Hey Noted, add my laceration repair note with 3cm linear left forearm lidocaine with epi 4-0 nylon",
        "Insert intubation note with MAC 3 blade 7.5 ETT first attempt",
        "Add critical care time for septic shock 45 minutes",
        "Use my laceration template",
        "Insert procedure note"
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // How it works
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How Voice Commands Work")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Text("1.")
                                    .fontWeight(.semibold)
                                    .frame(width: 20)
                                Text("Say the activation phrase while recording")
                                    .font(.subheadline)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("2.")
                                    .fontWeight(.semibold)
                                    .frame(width: 20)
                                Text("Mention the template name or procedure")
                                    .font(.subheadline)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("3.")
                                    .fontWeight(.semibold)
                                    .frame(width: 20)
                                Text("Include any specific parameters (size, location, etc.)")
                                    .font(.subheadline)
                            }
                            
                            HStack(alignment: .top, spacing: 12) {
                                Text("4.")
                                    .fontWeight(.semibold)
                                    .frame(width: 20)
                                Text("The template is automatically inserted with your parameters")
                                    .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Examples
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Voice Command Examples")
                            .font(.headline)
                        
                        ForEach(Array(examples.enumerated()), id: \.offset) { index, example in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Example \(index + 1):")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text("\"\(example)\"")
                                    .font(.callout)
                                    .foregroundColor(.blue)
                                    .italic()
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Tips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pro Tips")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Label("The AI automatically extracts parameters like size, location, and materials", systemImage: "lightbulb")
                                .font(.subheadline)
                            
                            Label("Voice commands work best with templates in your 'My Templates' list", systemImage: "star")
                                .font(.subheadline)
                            
                            Label("Speak naturally - the system is designed to understand medical terminology", systemImage: "mic")
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Voice Commands")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}