import SwiftUI

struct RoomSelectionView: View {
    @State private var room: String = ""
    @State private var complaint: String = "Chest pain"
    private let complaints = ["Chest pain","Shortness of breath","Abdominal pain","Headache","Dizziness"]
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Room #", text: $room)
            Picker("Chief Complaint", selection: $complaint) {
                ForEach(complaints, id: \.self) { Text($0) }
            }
            .labelsHidden()
            
            HStack {
                Button("Start") { WatchConnector.shared.startEncounter(room: room, chiefComplaint: complaint) }
                Button("Stop") { WatchConnector.shared.stopEncounter() }
            }
            Button("Bookmark") { WatchConnector.shared.bookmark(label: "Key moment") }
        }
        .padding()
    }
}

