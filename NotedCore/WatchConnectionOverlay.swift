import SwiftUI
import AVFoundation

// MARK: - Watch Connection Overlay
struct WatchConnectionOverlay: View {
    @ObservedObject var watchManager = WatchConnectivityManager.shared
    @State private var showConfirmation = false
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack {
            if watchManager.isAwaitingWatchConfirmation {
                confirmationBanner
            }
            
            if showConfirmation, let confirmation = watchManager.pendingEncounterConfirmation {
                successBanner(confirmation: confirmation)
            }
            
            Spacer()
        }
        .animation(.spring(), value: watchManager.isAwaitingWatchConfirmation)
        .animation(.spring(), value: showConfirmation)
        .onChange(of: watchManager.pendingEncounterConfirmation) { newValue in
            if newValue != nil {
                showSuccessFeedback()
            }
        }
    }
    
    // MARK: - Confirmation Banner
    private var confirmationBanner: some View {
        HStack(spacing: 12) {
            // Animated Watch Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title3)
                    .foregroundColor(.blue)
                    .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            .onAppear { pulseAnimation = true }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Starting Encounter...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let confirmation = watchManager.pendingEncounterConfirmation {
                    HStack(spacing: 8) {
                        Text("Room \(confirmation.room)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .foregroundColor(.secondary)
                        
                        Text("Code: \(confirmation.confirmationCode)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
            
            // Loading indicator
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(0.8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
        .padding()
        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
    
    // MARK: - Success Banner
    private func successBanner(confirmation: EncounterConfirmation) -> some View {
        HStack(spacing: 12) {
            // Success Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Encounter Started")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label("Room \(confirmation.room)", systemImage: "door.left.hand.open")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(confirmation.confirmationCode)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: dismissSuccess) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding()
        .shadow(color: .green.opacity(0.2), radius: 10, y: 5)
    }
    
    // MARK: - Actions
    private func showSuccessFeedback() {
        withAnimation(.spring()) {
            showConfirmation = true
        }
        
        // Play success sound
        AudioServicesPlaySystemSound(1054)
        
        // Auto-dismiss after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            dismissSuccess()
        }
    }
    
    private func dismissSuccess() {
        withAnimation(.spring()) {
            showConfirmation = false
            pulseAnimation = false
        }
    }
}

// MARK: - Watch Status Widget
struct WatchStatusWidget: View {
    @ObservedObject var watchManager = WatchConnectivityManager.shared
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails.toggle() }) {
            HStack(spacing: 8) {
                // Connection indicator
                Circle()
                    .fill(watchManager.isReachable ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                Image(systemName: "applewatch")
                    .font(.caption)
                
                Text(watchManager.isReachable ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if !watchManager.lastReceivedRoom.isEmpty {
                    Text("Room \(watchManager.lastReceivedRoom)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .sheet(isPresented: $showingDetails) {
            WatchConnectionDetailsView()
        }
    }
}

// MARK: - Watch Connection Details View
struct WatchConnectionDetailsView: View {
    @ObservedObject var watchManager = WatchConnectivityManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Connection Status
                connectionStatusCard
                
                // Current Encounter Info
                if !watchManager.lastReceivedRoom.isEmpty {
                    currentEncounterCard
                }
                
                // Recent Confirmations
                recentConfirmationsCard
                
                Spacer()
            }
            .padding()
            .navigationTitle("Apple Watch")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private var connectionStatusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.largeTitle)
                    .foregroundColor(watchManager.isReachable ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(watchManager.isReachable ? "Watch Connected" : "Watch Not Connected")
                        .font(.headline)
                    
                    Text(watchManager.isReachable ? 
                         "Ready to control encounters from your Apple Watch" : 
                         "Open the Noted app on your Apple Watch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if !watchManager.isReachable {
                Button(action: retryConnection) {
                    Label("Retry Connection", systemImage: "arrow.clockwise")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
    
    private var currentEncounterCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Current Settings", systemImage: "gear")
                .font(.headline)
                .foregroundColor(.blue)
            
            HStack {
                Text("Room:")
                    .foregroundColor(.secondary)
                Text(watchManager.lastReceivedRoom)
                    .fontWeight(.medium)
            }
            
            if !watchManager.lastReceivedComplaint.isEmpty {
                HStack {
                    Text("Chief Complaint:")
                        .foregroundColor(.secondary)
                    Text(watchManager.lastReceivedComplaint)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.1))
        )
    }
    
    private var recentConfirmationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Confirmations", systemImage: "checkmark.seal")
                .font(.headline)
                .foregroundColor(.green)
            
            if let confirmation = watchManager.pendingEncounterConfirmation {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Room \(confirmation.room)")
                            .font(.callout)
                        Text(formatTime(confirmation.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(confirmation.confirmationCode)
                        .font(.system(.callout, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(6)
                }
            } else {
                Text("No recent confirmations")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private func retryConnection() {
        WatchConnectivityManager.shared.activate()
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Integration with ContentView
extension ContentView {
    func addWatchOverlay() -> some View {
        self.overlay(
            WatchConnectionOverlay()
                .allowsHitTesting(false)
        )
    }
}