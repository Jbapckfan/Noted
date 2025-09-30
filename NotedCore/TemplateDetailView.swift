import SwiftUI

// MARK: - Template Detail View
struct TemplateDetailView: View {
    let template: MedicalTemplate
    @Environment(\.dismiss) private var dismiss
    @StateObject private var templateService = TemplatesCommunityService.shared
    @State private var parameterValues: [String: String] = [:]
    @State private var showingPreview = false
    @State private var previewContent = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Voice Commands
                    if !template.voiceCommands.isEmpty {
                        voiceCommandsSection
                    }
                    
                    // Parameters
                    if !template.parameters.isEmpty {
                        parametersSection
                    }
                    
                    // Template Content Preview
                    templatePreviewSection
                    
                    // Stats and Info
                    statsSection
                }
                .padding()
            }
            .navigationTitle(template.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                toolbarContent
            }
            .onAppear {
                initializeParameterValues()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Category
                Label(template.category.rawValue, systemImage: template.category.icon)
                    .font(.subheadline)
                    .foregroundColor(template.category.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(template.category.color.opacity(0.1))
                    .cornerRadius(15)
                
                // Specialty
                Text(template.specialty.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(15)
                
                Spacer()
                
                // Verified Badge
                if template.isVerified {
                    Label("Verified", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Author and Rating
            HStack {
                Text("by \(template.author)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.subheadline)
                        .foregroundColor(.yellow)
                    Text(String(format: "%.1f", template.rating))
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("(\(template.downloads) uses)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            // Use Template
            Button(action: {
                Task {
                    if parameterValues.isEmpty {
                        await templateService.insertTemplate(template)
                    } else {
                        await templateService.insertTemplateWithParameters(template, parameters: parameterValues)
                    }
                    dismiss()
                }
            }) {
                Label("Use Template", systemImage: "doc.text.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            // Add to My Templates
            if !templateService.myTemplates.contains(where: { $0.id == template.id }) {
                Button(action: {
                    templateService.addToMyTemplates(template)
                }) {
                    Label("Add to My Templates", systemImage: "plus.circle")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
        }
    }
    
    // MARK: - Voice Commands
    private var voiceCommandsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voice Commands")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(template.voiceCommands, id: \.self) { command in
                    HStack {
                        Image(systemName: "mic")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("\"\(command)\"")
                            .font(.subheadline)
                            .italic()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Parameters
    private var parametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parameters")
                    .font(.headline)
                
                Spacer()
                
                Button("Preview") {
                    previewContent = template.applyParameters(parameterValues)
                    showingPreview = true
                }
                .font(.subheadline)
            }
            
            VStack(spacing: 12) {
                ForEach(template.parameters, id: \.key) { parameter in
                    ParameterInputView(
                        parameter: parameter,
                        value: Binding(
                            get: { parameterValues[parameter.key] ?? parameter.defaultValue },
                            set: { parameterValues[parameter.key] = $0 }
                        )
                    )
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            TemplatePreviewSheet(content: previewContent)
        }
    }
    
    // MARK: - Template Preview
    private var templatePreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Template Content")
                .font(.headline)
            
            ScrollView {
                Text(template.formattedContent)
                    .font(.system(.callout, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(height: 200)
        }
    }
    
    // MARK: - Stats
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(template.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(15)
                }
            }
        }
    }
    
    // MARK: - Toolbar
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    templateService.toggleFavorite(template)
                }) {
                    Image(systemName: templateService.isFavorite(template) ? "star.fill" : "star")
                        .foregroundColor(templateService.isFavorite(template) ? .yellow : .gray)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func initializeParameterValues() {
        for parameter in template.parameters {
            parameterValues[parameter.key] = parameter.defaultValue
        }
    }
}

// MARK: - Parameter Input View
struct ParameterInputView: View {
    let parameter: TemplateParameter
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(parameter.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if parameter.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                }
            }
            
            switch parameter.type {
            case .text, .number, .measurement, .anatomicalLocation, .medication, .time:
                TextField(parameter.displayName, text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    #if os(iOS)
                    .keyboardType(parameter.type == .number ? .numberPad : .default)
                    #endif
                
            case .selection:
                if let options = parameter.options {
                    Picker(parameter.displayName, selection: $value) {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
            case .multiLine:
                TextEditor(text: $value)
                    .frame(height: 80)
                    .padding(4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

// MARK: - Template Preview Sheet
struct TemplatePreviewSheet: View {
    let content: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .textSelection(.enabled)
            }
            .navigationTitle("Preview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Flow Layout
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for row in result.rows {
            for index in row.indices {
                let x = row.xOffsets[index - row.indices.first!] + bounds.minX
                let y = row.yOffset + bounds.minY
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            }
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var rows: [Row] = []
        
        struct Row {
            var indices: Range<Int>
            var xOffsets: [Double]
            var yOffset: Double
            var height: Double
        }
        
        init(in maxWidth: Double, subviews: Subviews, spacing: CGFloat) {
            var x = 0.0
            var y = 0.0
            var rowHeight = 0.0
            var rowStart = 0
            var xOffsets: [Double] = []
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth, index > rowStart {
                    rows.append(Row(
                        indices: rowStart..<index,
                        xOffsets: xOffsets,
                        yOffset: y,
                        height: rowHeight
                    ))
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                    rowStart = index
                    xOffsets = []
                }
                xOffsets.append(x)
                x += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
            
            if rowStart < subviews.count {
                rows.append(Row(
                    indices: rowStart..<subviews.count,
                    xOffsets: xOffsets,
                    yOffset: y,
                    height: rowHeight
                ))
            }
            
            size.width = maxWidth
            size.height = rows.last.map { $0.yOffset + $0.height } ?? 0
        }
    }
}