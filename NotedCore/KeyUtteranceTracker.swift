import Foundation

@MainActor
final class KeyUtteranceTracker: ObservableObject {
    static let shared = KeyUtteranceTracker()
    
    struct ActionItem: Identifiable, Hashable {
        enum Kind: String, CaseIterable { case order, medication, imaging, consult, instruction, commitment }
        let id = UUID()
        let kind: Kind
        let title: String
        let detail: String?
        let timestamp: Date
        var completed: Bool = false
        var dueDate: Date? = nil
    }
    
    @Published private(set) var items: [ActionItem] = []
    
    static func ActionKinds() -> [ActionItem.Kind] { ActionItem.Kind.allCases }
    
    private let medKeywords: [String] = [
        "aspirin","nitroglycerin","heparin","morphine","ondansetron","acetaminophen",
        "ibuprofen","metformin","lisinopril","atorvastatin","amlodipine","metoprolol"
    ]
    
    private let imagingKeywords: [String] = [
        "x-ray","xray","chest x-ray","cxr","ct","ct scan","cta","cta chest","mri","ultrasound","us"
    ]
    
    // Commitment patterns (statements to the patient)
    private let commitmentPhrases: [String] = [
        "we will", "we'll", "i will", "i'll", "we are going to", "i am going to",
        "we're going to", "i'm going to", "we plan to", "we're planning to",
        "we'll get", "we will get", "we'll order", "we will order", "we'll start", "we will start",
        "i'll order", "i will order", "i'll get", "i will get", "i'll start", "i will start",
        "we'll give you", "i'll give you", "we'll send you home with"
    ]
    
    func reset() {
        items.removeAll()
    }
    
    func markCompleted(_ item: ActionItem) {
        if let idx = items.firstIndex(of: item) { items[idx].completed = true }
    }
    
    func snooze(_ item: ActionItem, minutes: Int) {
        guard let idx = items.firstIndex(of: item) else { return }
        items[idx].dueDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }
    
    func setReminder(_ item: ActionItem, minutes: Int) {
        snooze(item, minutes: minutes)
    }
    
    func processSegment(_ text: String) {
        let t = text.lowercased()
        let now = Date()
        
        // Orders
        if t.contains("order") || t.contains("let's get") || t.contains("we will get") {
            // Imaging orders
            if let img = imagingKeywords.first(where: { t.contains($0) }) {
                append(kind: .imaging, title: "Order \(img.capitalized)", detail: nil, at: now)
            }
            // Lab shorthand
            if t.contains("troponin") { append(kind: .order, title: "Order troponin", detail: nil, at: now) }
            if t.contains("d-dimer") || t.contains("ddimer") { append(kind: .order, title: "Order D-dimer", detail: nil, at: now) }
            if t.contains("cbc") { append(kind: .order, title: "Order CBC", detail: nil, at: now) }
            if t.contains("bmp") { append(kind: .order, title: "Order BMP", detail: nil, at: now) }
            if t.contains("ekg") || t.contains("ecg") { append(kind: .order, title: "Obtain EKG", detail: nil, at: now) }
        }
        
        // Medications
        if t.contains("start ") || t.contains("give ") || t.contains("administer") || t.contains("prescribe") {
            if let med = medKeywords.first(where: { t.contains($0) }) {
                append(kind: .medication, title: "Administer \(med.capitalized)", detail: nil, at: now)
            }
        }
        
        // Consults
        if t.contains("consult") || t.contains("page cardiology") || t.contains("page surgery") {
            append(kind: .consult, title: "Place consult", detail: suggestedConsultDetail(t), at: now)
        }
        
        // Discharge instructions
        if t.contains("return precautions") || t.contains("discharge instructions") {
            append(kind: .instruction, title: "Document return precautions", detail: nil, at: now)
        }
        
        // Patient commitments (statements to patient)
        if commitmentPhrases.contains(where: { t.contains($0) }) {
            let summary = summarizeCommitment(from: t) ?? "Discussed plan and next steps"
            append(kind: .commitment, title: summary, detail: nil, at: now)
        }
    }
    
    private func suggestedConsultDetail(_ text: String) -> String? {
        if text.contains("cardio") { return "Cardiology" }
        if text.contains("surg") { return "Surgery" }
        if text.contains("neuro") { return "Neurology" }
        return nil
    }
    
    private func append(kind: ActionItem.Kind, title: String, detail: String?, at: Date) {
        // Avoid duplicates in short window
        if let last = items.last, last.title == title, Date().timeIntervalSince(last.timestamp) < 30 { return }
        items.append(ActionItem(kind: kind, title: title, detail: detail, timestamp: at, completed: false))
        // Keep list manageable
        if items.count > 50 { items.removeFirst(items.count - 50) }
    }

    // Extract a compact commitment summary
    private func summarizeCommitment(from text: String) -> String? {
        // Try to extract common objects: labs, ekg, x-ray, medication class
        if text.contains("ekg") || text.contains("ecg") { return "Will obtain EKG" }
        if imagingKeywords.contains(where: { text.contains($0) }) {
            if let img = imagingKeywords.first(where: { text.contains($0) }) { return "Will order \(img.capitalized)" }
        }
        if let med = medKeywords.first(where: { text.contains($0) }) { return "Will give \(med.capitalized)" }
        if text.contains("lab") || text.contains("labs") || text.contains("blood work") { return "Will obtain labs" }
        if text.contains("admit") { return "Discussed admission plan" }
        if text.contains("discharge") { return "Discussed discharge plan and precautions" }
        return nil
    }
}
