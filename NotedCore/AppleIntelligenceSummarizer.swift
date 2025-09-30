import Foundation
import NaturalLanguage

@MainActor
class AppleIntelligenceSummarizer: ObservableObject {
    static let shared = AppleIntelligenceSummarizer()
    
    @Published var isProcessing = false
    @Published var summary = ""
    @Published var medicalNote = ""
    @Published var keyPoints: [String] = []
    
    private init() {}
    
    // Medical sentence classification
    struct MedicalSentence {
        let text: String
        let category: MedicalCategory
        let confidence: Double
    }
    
    enum MedicalCategory: String {
        case chiefComplaint = "Chief Complaint"
        case hpi = "History of Present Illness"
        case pmh = "Past Medical History"
        case psh = "Past Surgical History"
        case medications = "Medications"
        case allergies = "Allergies"
        case socialHistory = "Social History"
        case familyHistory = "Family History"
        case ros = "Review of Systems"
        case physicalExam = "Physical Exam"
        case vitals = "Vitals"
        case labs = "Labs"
        case imaging = "Imaging"
        case assessment = "Assessment"
        case plan = "Plan"
        case mdm = "Medical Decision Making"
        case disposition = "Disposition"
        case discharge = "Discharge Instructions"
    }
    
    // MARK: - Main Processing
    
    func processTranscription(_ transcription: String, noteType: NoteType = .soap) async {
        await MainActor.run {
            self.isProcessing = true
        }
        
        // Step 1: Classify sentences
        let sentences = classifyMedicalSentences(transcription)
        
        // Step 2: Build medical note
        let note = await buildMedicalNote(from: sentences, noteType: noteType)
        
        // Step 3: Extract key points
        let points = extractKeyPoints(from: sentences)
        
        await MainActor.run {
            self.medicalNote = note
            self.keyPoints = points
            self.isProcessing = false
        }
    }
    
    // MARK: - Sentence Classification
    
    private func classifyMedicalSentences(_ text: String) -> [MedicalSentence] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        
        var sentences: [MedicalSentence] = []
        
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range])
            let category = classifySentence(sentence)
            
            sentences.append(MedicalSentence(
                text: sentence.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category,
                confidence: calculateConfidence(sentence, category: category)
            ))
            
            return true
        }
        
        return sentences
    }
    
    private func classifySentence(_ sentence: String) -> MedicalCategory {
        let lower = sentence.lowercased()
        
        // Chief complaint patterns
        if lower.contains("presents") || lower.contains("complains") || 
           lower.contains("here for") || lower.contains("chief complaint") {
            return .chiefComplaint
        }
        
        // HPI patterns
        if lower.contains("started") || lower.contains("began") || 
           lower.contains("worse") || lower.contains("better") ||
           lower.contains("associated") || lower.contains("radiates") {
            return .hpi
        }
        
        // Physical exam patterns
        if lower.contains("exam") || lower.contains("auscultation") ||
           lower.contains("palpation") || lower.contains("tender") {
            return .physicalExam
        }
        
        // Medication patterns
        if lower.contains("taking") || lower.contains("medication") ||
           lower.contains("prescribed") || lower.contains("dose") {
            return .medications
        }
        
        // Lab/Imaging patterns
        if lower.contains("lab") || lower.contains("blood") ||
           lower.contains("x-ray") || lower.contains("ct") || lower.contains("mri") {
            return lower.contains("x-ray") || lower.contains("ct") || lower.contains("mri") ? .imaging : .labs
        }
        
        // Assessment/Plan patterns
        if lower.contains("diagnosis") || lower.contains("impression") ||
           lower.contains("recommend") || lower.contains("follow up") {
            return lower.contains("recommend") || lower.contains("follow") ? .plan : .assessment
        }
        
        // Default to HPI for narrative text
        return .hpi
    }
    
    private func calculateConfidence(_ sentence: String, category: MedicalCategory) -> Double {
        // Simple confidence scoring based on keyword presence
        var score = 0.5
        let lower = sentence.lowercased()
        
        switch category {
        case .chiefComplaint:
            if lower.contains("presents with") { score += 0.3 }
        case .physicalExam:
            if lower.contains("examination reveals") { score += 0.3 }
        case .assessment:
            if lower.contains("diagnosis") { score += 0.3 }
        default:
            break
        }
        
        return min(score, 1.0)
    }
    
    // MARK: - Medical Note Building
    
    private func buildMedicalNote(from sentences: [MedicalSentence], noteType: NoteType) async -> String {
        let builder = MedicalSummaryBuilder()
        
        switch noteType {
        case .soap:
            return buildSOAPNote(from: sentences, summary: builder)
        case .edNote:
            return buildEDNote(from: sentences, summary: builder)
        case .progress:
            return buildProgressNote(from: sentences, summary: builder)
        default:
            return buildGenericNote(from: sentences, summary: builder)
        }
    }
    
    private func buildEDNote(from sentences: [MedicalSentence], summary: MedicalSummaryBuilder) -> String {
        var note = "**EMERGENCY DEPARTMENT NOTE**\n"
        
        note += "\n"
        
        // Chief Complaint
        note += "**CC:**\n"
        if let cc = sentences.first(where: { $0.category == .chiefComplaint }) {
            note += extractChiefComplaint(from: cc.text) + "\n"
        } else {
            note += "[Chief complaint]\n"
        }
        
        note += "\n"
        
        // HPI
        note += "**HPI:**\n"
        let hpiSentences = sentences.filter { $0.category == .hpi }
        if !hpiSentences.isEmpty {
            note += hpiSentences.prefix(5).map { $0.text }.joined(separator: " ") + "\n"
        } else {
            note += "[History of present illness]\n"
        }
        
        note += "\n"
        
        // Social History
        let shSentences = sentences.filter { 
            $0.text.lowercased().contains("smoke") ||
            $0.text.lowercased().contains("alcohol") ||
            $0.text.lowercased().contains("drug")
        }
        if !shSentences.isEmpty {
            note += "**SH:**\n"
            note += shSentences.first?.text ?? ""
            note += "\n\n"
        }
        
        // Family History
        let fhSentences = sentences.filter {
            $0.text.lowercased().contains("family") ||
            $0.text.lowercased().contains("mother") ||
            $0.text.lowercased().contains("father")
        }
        if !fhSentences.isEmpty {
            note += "**FH:**\n"
            note += fhSentences.first?.text ?? ""
            note += "\n\n"
        }
        
        // Past Medical History
        let pmhSentences = sentences.filter { $0.category == .pmh }
        if !pmhSentences.isEmpty {
            note += "**PMH:**\n"
            for item in pmhSentences.prefix(3) {
                note += "• " + extractMedicalHistory(from: item.text) + "\n"
            }
            note += "\n"
        }
        
        // Past Surgical History
        let pshSentences = sentences.filter {
            $0.text.lowercased().contains("surgery") ||
            $0.text.lowercased().contains("operation")
        }
        if !pshSentences.isEmpty {
            note += "**PSH:**\n"
            note += pshSentences.first?.text ?? ""
            note += "\n\n"
        }
        
        // Review of Systems
        let rosSentences = sentences.filter { $0.category == .ros }
        if !rosSentences.isEmpty {
            note += "**ROS:**\n"
            for item in rosSentences.prefix(5) {
                note += "• " + item.text + "\n"
            }
            note += "\n"
        }
        
        // Physical Exam/Vitals
        let peSentences = sentences.filter { 
            $0.category == .physicalExam || $0.category == .vitals
        }
        if !peSentences.isEmpty {
            note += "**PE/Vitals:**\n"
            for item in peSentences.prefix(10) {
                note += "• " + item.text + "\n"
            }
            note += "\n"
        }
        
        // Labs/Imaging
        let labSentences = sentences.filter { 
            $0.category == .labs || $0.category == .imaging
        }
        if !labSentences.isEmpty {
            note += "**Lab/Imaging:**\n"
            for item in labSentences {
                note += "• " + item.text + "\n"
            }
            note += "\n"
        }
        
        // Medical Decision Making
        note += "**MDM:**\n"
        let mdmSentences = sentences.filter { $0.category == .assessment || $0.category == .mdm }
        if !mdmSentences.isEmpty {
            note += mdmSentences.map { $0.text }.joined(separator: " ")
        } else {
            note += "[Medical decision making]"
        }
        note += "\n\n"
        
        // Disposition
        let dispSentences = sentences.filter { $0.category == .disposition }
        if !dispSentences.isEmpty {
            note += "**Disposition:**\n"
            note += dispSentences.first?.text ?? ""
            note += "\n\n"
        }
        
        // Discharge Instructions
        let dcSentences = sentences.filter { $0.category == .discharge }
        if !dcSentences.isEmpty {
            note += "**Discharge Instructions:**\n"
            for (index, item) in dcSentences.enumerated() {
                note += "\(index + 1). " + item.text + "\n"
            }
            note += "\n"
        }
        
        note += "\n*Generated locally using Apple Intelligence*"
        
        return note
    }
    
    private func buildSOAPNote(from sentences: [MedicalSentence], summary: MedicalSummaryBuilder) -> String {
        var note = "**SOAP NOTE**\n\n"
        
        // Subjective
        note += "**S (Subjective):**\n"
        let subjective = sentences.filter { 
            $0.category == .chiefComplaint || 
            $0.category == .hpi ||
            $0.category == .ros
        }
        for item in subjective.prefix(5) {
            note += "• " + item.text + "\n"
        }
        note += "\n"
        
        // Objective
        note += "**O (Objective):**\n"
        let objective = sentences.filter {
            $0.category == .physicalExam ||
            $0.category == .vitals ||
            $0.category == .labs ||
            $0.category == .imaging
        }
        for item in objective.prefix(8) {
            note += "• " + item.text + "\n"
        }
        note += "\n"
        
        // Assessment
        note += "**A (Assessment):**\n"
        let assessment = sentences.filter { $0.category == .assessment }
        if !assessment.isEmpty {
            note += assessment.map { $0.text }.joined(separator: " ") + "\n"
        } else {
            note += "[Clinical assessment]\n"
        }
        note += "\n"
        
        // Plan
        note += "**P (Plan):**\n"
        let plan = sentences.filter { $0.category == .plan }
        if !plan.isEmpty {
            for (index, item) in plan.enumerated() {
                note += "\(index + 1). " + item.text + "\n"
            }
        } else {
            note += "[Treatment plan]\n"
        }
        
        return note
    }
    
    private func buildProgressNote(from sentences: [MedicalSentence], summary: MedicalSummaryBuilder) -> String {
        var note = "**PROGRESS NOTE**\n\n"
        
        note += "**Interval History:**\n"
        let interval = sentences.filter { $0.category == .hpi }.prefix(3)
        note += interval.map { $0.text }.joined(separator: " ") + "\n\n"
        
        note += "**Current Status:**\n"
        let exam = sentences.filter { $0.category == .physicalExam }.prefix(3)
        note += exam.map { $0.text }.joined(separator: " ") + "\n\n"
        
        note += "**Plan:**\n"
        let plan = sentences.filter { $0.category == .plan }
        note += plan.map { $0.text }.joined(separator: " ") + "\n"
        
        return note
    }
    
    private func buildGenericNote(from sentences: [MedicalSentence], summary: MedicalSummaryBuilder) -> String {
        var note = "**MEDICAL NOTE**\n\n"
        
        let grouped = Dictionary(grouping: sentences) { $0.category }
        
        for (category, items) in grouped.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            note += "**\(category.rawValue):**\n"
            for item in items.prefix(5) {
                note += "• " + item.text + "\n"
            }
            note += "\n"
        }
        
        return note
    }
    
    // MARK: - Helper Methods
    
    private func extractChiefComplaint(from text: String) -> String {
        // Extract the main complaint from a sentence
        if let match = text.range(of: "presents with ", options: .caseInsensitive) {
            return String(text[match.upperBound...]).capitalized
        }
        if let match = text.range(of: "complains of ", options: .caseInsensitive) {
            return String(text[match.upperBound...]).capitalized
        }
        return text
    }
    
    private func extractMedicalHistory(from text: String) -> String {
        // Clean up medical history items
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(of: "history of ", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "past medical history includes ", with: "", options: .caseInsensitive)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func extractKeyPoints(from sentences: [MedicalSentence]) -> [String] {
        var points: [String] = []
        
        // Chief complaint
        if let cc = sentences.first(where: { $0.category == .chiefComplaint }) {
            points.append("CC: " + extractChiefComplaint(from: cc.text))
        }
        
        // Significant findings
        let significantCategories: [MedicalCategory] = [.assessment, .plan, .disposition]
        for category in significantCategories {
            if let finding = sentences.first(where: { $0.category == category }) {
                points.append("\(category.rawValue): \(finding.text)")
            }
        }
        
        return points
    }
}

// Supporting class
class MedicalSummaryBuilder {
    // Placeholder for additional summary building logic
}