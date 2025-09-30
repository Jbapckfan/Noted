import Foundation

enum NoteType: String, CaseIterable {
    case edNote = "ED Note"
    case soap = "SOAP Note"
    case progress = "Progress Note"
    case consult = "Consult Note"
    case handoff = "Handoff Note"
    case discharge = "Discharge Summary"
    
    var displayName: String {
        return self.rawValue
    }
}