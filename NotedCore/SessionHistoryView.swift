import SwiftUI
import CoreData

/// View to display saved encounter sessions with Core Data persistence
/// All sessions are permanently saved and survive app restarts
struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var sessionManager = EncounterSessionManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \TranscriptEntity.timestamp, ascending: false)],
        animation: .default)
    private var savedTranscripts: FetchedResults<TranscriptEntity>

    @State private var selectedTranscript: TranscriptEntity?
    
    var body: some View {
        NavigationView {
            List {
                if sessionManager.previousSessions.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No Previous Sessions")
                            .font(.headline)
                        Text("Your session history will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(sessionManager.previousSessions) { session in
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SessionRow: View {
    let session: EncounterSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.patientId)
                    .font(.headline)
                Spacer()
                Text(session.startTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !session.transcript.isEmpty {
                Text(session.transcript)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SessionHistoryView()
}