import SwiftUI

struct SessionsView: View {
    @ObservedObject var appState: CoreAppState
    
    var body: some View {
        NavigationView {
            VStack {
                if appState.sessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Sessions Yet")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Start recording to create your first medical session")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List(appState.sessions) { session in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(session.displayTitle)
                                .font(.headline)
                            
                            Text(session.previewText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Sessions")
        }
    }
}

struct SessionsView_Previews: PreviewProvider {
    static var previews: some View {
        SessionsView(appState: CoreAppState.shared)
    }
}