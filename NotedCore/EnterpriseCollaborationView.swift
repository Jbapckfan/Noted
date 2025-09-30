import SwiftUI

struct EnterpriseCollaborationView: View {
    @StateObject private var collaborationService = CollaborationService()
    @State private var selectedHandoffType: HandoffType = .sbar
    @State private var isCreatingHandoff = false
    @State private var selectedProvider: Provider?
    @State private var handoffMessage = ""
    @State private var criticalItems: [CriticalItem] = []
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Enterprise background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.05),
                        Color(red: 0.05, green: 0.05, blue: 0.1),
                        Color(red: 0.02, green: 0.02, blue: 0.05)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Enterprise header
                        enterpriseHeader
                        
                        // Quick Actions
                        quickActions
                        
                        // Active Handoffs
                        activeHandoffs
                        
                        // Team Collaboration Hub
                        teamCollaborationHub
                        
                        // Communication Center
                        communicationCenter
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $isCreatingHandoff) {
            HandoffCreationView(
                selectedType: $selectedHandoffType,
                selectedProvider: $selectedProvider,
                message: $handoffMessage,
                criticalItems: $criticalItems
            ) { handoff in
                collaborationService.createHandoff(handoff)
            }
        }
    }
    
    private var enterpriseHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "person.3.sequence.fill")
                            .font(.title)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Enterprise Collaboration")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    
                    Text("Provider Handoff & Team Communication")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        
                        Text("\(collaborationService.activeProviders) Providers Online")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    Text("Secure HIPAA Network")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.1))
        }
    }
    
    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                QuickActionCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Provider Handoff",
                    description: "Secure patient transfer",
                    color: .blue
                ) {
                    isCreatingHandoff = true
                }
                
                QuickActionCard(
                    icon: "stethoscope",
                    title: "Consultation Request",
                    description: "Request specialist input",
                    color: .purple
                ) {
                    // Handle consultation request
                }
                
                QuickActionCard(
                    icon: "envelope.badge.fill",
                    title: "Secure Message",
                    description: "Send encrypted message",
                    color: .green
                ) {
                    // Handle secure messaging
                }
                
                QuickActionCard(
                    icon: "doc.badge.arrow.up.fill",
                    title: "Referral Letter",
                    description: "Generate professional referral",
                    color: .orange
                ) {
                    // Handle referral generation
                }
            }
        }
    }
    
    private var activeHandoffs: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Active Handoffs")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("View All") {
                    // Handle view all
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if collaborationService.activeHandoffs.isEmpty {
                EmptyStateCard(
                    icon: "arrow.triangle.2.circlepath",
                    title: "No Active Handoffs",
                    description: "All patient transfers complete"
                )
            } else {
                ForEach(collaborationService.activeHandoffs.prefix(3), id: \.id) { handoff in
                    HandoffCard(handoff: handoff) {
                        // Handle handoff action
                    }
                }
            }
        }
    }
    
    private var teamCollaborationHub: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Team Collaboration Hub")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                CollaborationMetric(
                    icon: "person.2.fill",
                    title: "Active Team Members",
                    value: "\(collaborationService.activeProviders)",
                    color: .green
                )
                
                CollaborationMetric(
                    icon: "clock.fill",
                    title: "Avg Handoff Time",
                    value: "2.3 min",
                    color: .blue
                )
                
                CollaborationMetric(
                    icon: "checkmark.circle.fill",
                    title: "Handoff Success Rate",
                    value: "99.2%",
                    color: .purple
                )
                
                CollaborationMetric(
                    icon: "shield.checkerboard",
                    title: "Security Compliance",
                    value: "100%",
                    color: .orange
                )
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
    
    private var communicationCenter: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Communication Center")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
                ForEach(collaborationService.recentMessages.prefix(5), id: \.id) { message in
                    MessageRow(message: message)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Supporting Views

struct QuickActionCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HandoffCard: View {
    let handoff: ProviderHandoff
    let action: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(handoff.priority.color)
                        .frame(width: 8, height: 8)
                    
                    Text(handoff.patientInitials)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(handoff.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("From: \(handoff.fromProvider)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("To: \(handoff.toProvider)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(handoff.summary)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(2)
            }
            
            VStack(spacing: 8) {
                Button("Review") {
                    action()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(8)
                
                if handoff.hasCriticalItems {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.red)
                        
                        Text("Critical")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct CollaborationMetric: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
}

struct MessageRow: View {
    let message: TeamMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(message.type.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(message.sender)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if message.isUnread {
                Circle()
                    .fill(.blue)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Handoff Creation View

struct HandoffCreationView: View {
    @Binding var selectedType: HandoffType
    @Binding var selectedProvider: Provider?
    @Binding var message: String
    @Binding var criticalItems: [CriticalItem]
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: (ProviderHandoff) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // SBAR Template
                VStack(alignment: .leading, spacing: 16) {
                    Text("SBAR Handoff Format")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    SBARSection(title: "Situation", content: $message)
                    SBARSection(title: "Background", content: .constant(""))
                    SBARSection(title: "Assessment", content: .constant(""))
                    SBARSection(title: "Recommendation", content: .constant(""))
                }
                
                // Critical Items
                VStack(alignment: .leading, spacing: 12) {
                    Text("Critical Items")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    // Add critical items interface
                }
                
                Spacer()
                
                // Actions
                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    
                    Spacer()
                    
                    Button("Create Handoff") {
                        // Create handoff
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding()
            .navigationTitle("Provider Handoff")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct SBARSection: View {
    let title: String
    @Binding var content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            TextEditor(text: $content)
                .frame(height: 80)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

#Preview {
    EnterpriseCollaborationView()
}