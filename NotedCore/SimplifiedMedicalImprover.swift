import Foundation

/// Simplified approach to improve medical note generation using MTS-Dialog patterns
/// This doesn't require MLX or actual ML training - instead it learns patterns from the dataset
@MainActor
class SimplifiedMedicalImprover: ObservableObject {
    
    @Published var isAnalyzing = false
    @Published var progress: Float = 0.0
    @Published var statusMessage = "Ready to analyze datasets"
    @Published var patternsLearned = 0
    @Published var improvementComplete = false
    
    // Pattern storage
    private var learnedPatterns: [PatternCategory: [ExtractedPattern]] = [:]
    
    enum PatternCategory: String, CaseIterable {
        case chiefComplaint
        case demographics
        case onset
        case symptoms
        case medications
        case allergies
        case examination
        case assessment
        case disposition
        case vitals
        case timing
        case severity
        case location
        case quality
        case modifiers
    }
    
    struct ExtractedPattern: Hashable {
        let inputPhrase: String
        let outputFormat: String
        let confidence: Float
        let source: String // "MTS-Dialog" or "PriMock57"
    }
    
    /// Analyze MTS-Dialog dataset to extract patterns (no ML training required)
    func analyzeAndLearnPatterns() async {
        await MainActor.run {
            isAnalyzing = true
            statusMessage = "Loading MTS-Dialog dataset..."
            progress = 0.1
        }
        
        do {
            // Load and analyze MTS-Dialog CSV
            let mtsPath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/MTS-Dialog/Main-Dataset/MTS-Dialog-TrainingSet.csv"
            
            if FileManager.default.fileExists(atPath: mtsPath) {
                let patterns = try await extractPatternsFromMTSDialog(path: mtsPath)
                
                await MainActor.run {
                    self.learnedPatterns = patterns
                    self.patternsLearned = patterns.values.reduce(0) { $0 + $1.count }
                    self.progress = 0.5
                    self.statusMessage = "Learned \(self.patternsLearned) patterns from MTS-Dialog"
                }
                
                // Apply patterns to improve RealConversationAnalyzer
                try await applyPatternsToAnalyzer()
                
                await MainActor.run {
                    self.progress = 1.0
                    self.statusMessage = "Successfully improved analyzer with \(self.patternsLearned) patterns!"
                    self.improvementComplete = true
                    self.isAnalyzing = false
                }
            } else {
                await MainActor.run {
                    self.statusMessage = "MTS-Dialog dataset not found. Please download first."
                    self.isAnalyzing = false
                }
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Error: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }
    
    /// Extract patterns from MTS-Dialog CSV without ML
    private func extractPatternsFromMTSDialog(path: String) async throws -> [PatternCategory: [ExtractedPattern]] {
        var patterns: [PatternCategory: [ExtractedPattern]] = [:]
        
        // Initialize pattern arrays
        for category in PatternCategory.allCases {
            patterns[category] = []
        }
        
        // Read CSV and extract patterns
        let content = try String(contentsOfFile: path, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        
        var processedSamples = 0
        var successfulExtractions = 0
        
        // Skip header line
        let dataLines = lines.dropFirst()
        
        // Process MORE samples for better learning
        for line in dataLines.prefix(500) { // Increased from 200 to 500
            guard !line.isEmpty else { continue }
            
            // Better CSV parsing that handles quoted fields with commas
            let parsedFields = parseCSVLine(line)
            guard parsedFields.count >= 4 else { continue }
            
            let id = parsedFields[0]
            let sectionHeader = parsedFields[1].trimmingCharacters(in: .whitespaces)
            let sectionText = parsedFields[2]
            let dialogue = parsedFields[3]
            
            // Skip if it's just the header row
            if sectionHeader == "section_header" { continue }
            
            successfulExtractions += 1
            
            // ENHANCED: Extract patterns from ALL text fields
            extractComprehensivePatterns(from: sectionText, dialogue: dialogue, section: sectionHeader, patterns: &patterns)
            
            // Extract patterns based on section with MORE detail
            switch sectionHeader.lowercased() {
            case "cc", "chief complaint":
                extractChiefComplaintPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "genhx", "hpi", "history of present illness":
                extractHPIPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "medications", "meds", "med":
                extractMedicationPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "allergies", "allergy":
                extractAllergyPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "exam", "pe", "physical exam", "physical examination":
                extractExamPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "assessment", "plan", "assessment and plan", "a/p":
                extractAssessmentPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "disposition", "dispo":
                extractDispositionPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "ros", "review of systems":
                extractROSPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "pmh", "past medical history":
                extractPMHPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "psh", "past surgical history":
                extractPSHPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "sh", "social history":
                extractSocialHistoryPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            case "fh", "family history":
                extractFamilyHistoryPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
                
            default:
                // Still extract general patterns from unknown sections
                extractGeneralPatterns(from: sectionText, dialogue: dialogue, patterns: &patterns)
            }
            
            processedSamples += 1
            
            // Update progress
            let currentProgress = Float(processedSamples) / 500.0 * 0.4 + 0.1
            await MainActor.run {
                self.progress = currentProgress
                self.statusMessage = "Analyzing sample \(processedSamples)/500..."
            }
        }
        
        // Deduplicate patterns within each category
        for (category, categoryPatterns) in patterns {
            let uniquePatterns = Array(Set(categoryPatterns))
            patterns[category] = uniquePatterns
        }
        
        return patterns
    }
    
    /// Comprehensive pattern extraction from all text
    private func extractComprehensivePatterns(from text: String, dialogue: String, section: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let combinedText = "\(text) \(dialogue)".lowercased()
        
        // Extract vital signs patterns
        extractVitalsPatterns(from: combinedText, patterns: &patterns)
        
        // Extract timing patterns
        extractTimingPatterns(from: combinedText, patterns: &patterns)
        
        // Extract severity patterns
        extractSeverityPatterns(from: combinedText, patterns: &patterns)
        
        // Extract location patterns
        extractLocationPatterns(from: combinedText, patterns: &patterns)
        
        // Extract quality descriptors
        extractQualityPatterns(from: combinedText, patterns: &patterns)
        
        // Extract medical modifiers
        extractModifierPatterns(from: combinedText, patterns: &patterns)
    }
    
    /// Extract chief complaint patterns with more detail
    private func extractChiefComplaintPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let complaints = [
            "chest pain", "abdominal pain", "headache", "shortness of breath",
            "back pain", "nausea", "vomiting", "diarrhea", "fever", "cough",
            "dizziness", "weakness", "fatigue", "rash", "swelling",
            "pain", "bleeding", "constipation", "difficulty breathing",
            "palpitations", "syncope", "altered mental status", "seizure"
        ]
        
        for complaint in complaints {
            if text.lowercased().contains(complaint) {
                patterns[.chiefComplaint]?.append(ExtractedPattern(
                    inputPhrase: complaint,
                    outputFormat: complaint.capitalized,
                    confidence: 0.95,
                    source: "MTS-Dialog"
                ))
                
                // Add related variations
                if complaint.contains("pain") {
                    let location = complaint.replacingOccurrences(of: " pain", with: "")
                    patterns[.location]?.append(ExtractedPattern(
                        inputPhrase: location,
                        outputFormat: "\(location) region",
                        confidence: 0.85,
                        source: "MTS-Dialog"
                    ))
                }
            }
        }
    }
    
    /// Extract HPI patterns with comprehensive detail
    private func extractHPIPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        // Age patterns
        if let agePattern = extractAgePattern(from: text) {
            patterns[.demographics]?.append(agePattern)
        }
        
        // Gender patterns
        let genderPatterns = ["male", "female", "man", "woman", "boy", "girl"]
        for gender in genderPatterns {
            if text.lowercased().contains(gender) {
                patterns[.demographics]?.append(ExtractedPattern(
                    inputPhrase: gender,
                    outputFormat: gender == "man" ? "male" : gender == "woman" ? "female" : gender,
                    confidence: 0.9,
                    source: "MTS-Dialog"
                ))
            }
        }
        
        // Onset patterns
        let onsetPatterns = [
            "sudden onset", "gradual onset", "acute onset", "chronic",
            "started yesterday", "began this morning", "for weeks",
            "for months", "for years", "intermittent", "constant"
        ]
        
        for onset in onsetPatterns {
            if text.lowercased().contains(onset) {
                patterns[.onset]?.append(ExtractedPattern(
                    inputPhrase: onset,
                    outputFormat: onset,
                    confidence: 0.85,
                    source: "MTS-Dialog"
                ))
            }
        }
        
        // Extract symptom patterns
        extractDetailedSymptomPatterns(from: text, patterns: &patterns)
    }
    
    /// Extract detailed symptom patterns
    private func extractDetailedSymptomPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let symptomDescriptors = [
            ("sharp", "sharp/stabbing"),
            ("dull", "dull/aching"),
            ("burning", "burning sensation"),
            ("throbbing", "throbbing/pulsating"),
            ("cramping", "crampy"),
            ("pressure", "pressure-like"),
            ("tight", "tightness"),
            ("radiating", "radiating"),
            ("localized", "well-localized"),
            ("diffuse", "diffuse/generalized"),
            ("mild", "mild intensity"),
            ("moderate", "moderate intensity"),
            ("severe", "severe intensity"),
            ("worst", "worst ever experienced"),
            ("10/10", "10 out of 10 severity"),
            ("unbearable", "unbearable")
        ]
        
        for (phrase, medical) in symptomDescriptors {
            if text.lowercased().contains(phrase) {
                patterns[.symptoms]?.append(ExtractedPattern(
                    inputPhrase: phrase,
                    outputFormat: medical,
                    confidence: 0.88,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract medication patterns with dosages
    private func extractMedicationPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        // Common medications
        let commonMeds = [
            "aspirin", "ibuprofen", "acetaminophen", "tylenol", "advil",
            "lisinopril", "metformin", "atorvastatin", "omeprazole",
            "metoprolol", "amlodipine", "simvastatin", "losartan",
            "gabapentin", "hydrochlorothiazide", "sertraline", "zoloft",
            "lexapro", "prozac", "insulin", "albuterol", "prednisone"
        ]
        
        for med in commonMeds {
            if text.lowercased().contains(med) {
                patterns[.medications]?.append(ExtractedPattern(
                    inputPhrase: med,
                    outputFormat: med.capitalized,
                    confidence: 0.92,
                    source: "MTS-Dialog"
                ))
            }
        }
        
        // Extract dosage patterns
        let doseRegex = try? NSRegularExpression(
            pattern: "(\\d+)\\s*(mg|mcg|g|ml|units?|tabs?|pills?)",
            options: .caseInsensitive
        )
        
        if let matches = doseRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches {
                if let doseRange = Range(match.range, in: text) {
                    let doseText = String(text[doseRange])
                    patterns[.medications]?.append(ExtractedPattern(
                        inputPhrase: doseText.lowercased(),
                        outputFormat: doseText,
                        confidence: 0.9,
                        source: "MTS-Dialog"
                    ))
                }
            }
        }
    }
    
    /// Extract allergy patterns
    private func extractAllergyPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let allergyTerms = [
            "nkda", "no known drug allergies", "penicillin", "sulfa",
            "morphine", "codeine", "shellfish", "peanuts", "latex",
            "iodine", "contrast", "nsaids", "aspirin allergy"
        ]
        
        for term in allergyTerms {
            if text.lowercased().contains(term) {
                let formatted = term == "nkda" ? "NKDA" : term.capitalized
                patterns[.allergies]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: formatted,
                    confidence: 0.9,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract exam patterns
    private func extractExamPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let examFindings = [
            ("tender", "tenderness on palpation"),
            ("no tenderness", "no tenderness elicited"),
            ("normal", "within normal limits"),
            ("unremarkable", "unremarkable examination"),
            ("clear lungs", "lungs clear to auscultation bilaterally"),
            ("regular rhythm", "regular rate and rhythm"),
            ("soft abdomen", "abdomen soft"),
            ("distended", "distension noted"),
            ("guarding", "voluntary guarding present"),
            ("rebound", "positive rebound tenderness"),
            ("murmur", "cardiac murmur appreciated"),
            ("rales", "rales present"),
            ("wheezing", "expiratory wheezing"),
            ("edema", "pedal edema noted")
        ]
        
        for (finding, medical) in examFindings {
            if text.lowercased().contains(finding) {
                patterns[.examination]?.append(ExtractedPattern(
                    inputPhrase: finding,
                    outputFormat: medical,
                    confidence: 0.87,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract assessment patterns
    private func extractAssessmentPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let assessmentTerms = [
            "likely", "probable", "possible", "rule out", "consistent with",
            "differential includes", "working diagnosis", "clinical impression",
            "suspect", "concerning for", "evaluate for", "workup for"
        ]
        
        for term in assessmentTerms {
            if text.lowercased().contains(term) {
                patterns[.assessment]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: term,
                    confidence: 0.82,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract disposition patterns
    private func extractDispositionPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let dispoTerms = [
            ("discharge home", "Discharged home in stable condition"),
            ("admit", "Admitted for further management"),
            ("observation", "Placed in observation status"),
            ("transfer", "Transferred to higher level of care"),
            ("follow up", "Follow-up arranged"),
            ("return if worse", "Return precautions given"),
            ("call pcp", "Advised to contact primary care physician")
        ]
        
        for (term, formal) in dispoTerms {
            if text.lowercased().contains(term) {
                patterns[.disposition]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: formal,
                    confidence: 0.88,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract Review of Systems patterns
    private func extractROSPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let rosTerms = [
            "denies fever", "no chills", "no weight loss", "no night sweats",
            "no chest pain", "no palpitations", "no shortness of breath",
            "no nausea", "no vomiting", "no diarrhea", "no constipation",
            "no dysuria", "no hematuria", "no rash", "no joint pain"
        ]
        
        for term in rosTerms {
            if text.lowercased().contains(term) {
                patterns[.symptoms]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: term.capitalized,
                    confidence: 0.85,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract Past Medical History patterns
    private func extractPMHPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let pmhConditions = [
            "diabetes", "hypertension", "heart disease", "asthma", "copd",
            "cancer", "stroke", "heart attack", "kidney disease", "liver disease",
            "thyroid", "depression", "anxiety", "bipolar", "schizophrenia"
        ]
        
        for condition in pmhConditions {
            if text.lowercased().contains(condition) {
                patterns[.assessment]?.append(ExtractedPattern(
                    inputPhrase: condition,
                    outputFormat: "History of \(condition)",
                    confidence: 0.86,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract Past Surgical History patterns
    private func extractPSHPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let surgeries = [
            "appendectomy", "cholecystectomy", "hysterectomy", "c-section",
            "cesarean", "hernia repair", "gallbladder", "appendix removed",
            "tonsillectomy", "knee surgery", "back surgery", "heart surgery"
        ]
        
        for surgery in surgeries {
            if text.lowercased().contains(surgery) {
                patterns[.assessment]?.append(ExtractedPattern(
                    inputPhrase: surgery,
                    outputFormat: "Prior \(surgery)",
                    confidence: 0.84,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract Social History patterns
    private func extractSocialHistoryPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let socialTerms = [
            ("smokes", "Tobacco use"),
            ("drinks", "Alcohol use"),
            ("drugs", "Substance use"),
            ("denies smoking", "Denies tobacco use"),
            ("no alcohol", "Denies alcohol use"),
            ("no drugs", "Denies illicit drug use"),
            ("married", "Married"),
            ("divorced", "Divorced"),
            ("retired", "Retired"),
            ("works", "Employed")
        ]
        
        for (term, formal) in socialTerms {
            if text.lowercased().contains(term) {
                patterns[.assessment]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: formal,
                    confidence: 0.83,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract Family History patterns
    private func extractFamilyHistoryPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let familyTerms = [
            "family history of diabetes", "mother had cancer", "father had heart disease",
            "no family history", "family history significant for", "runs in family"
        ]
        
        for term in familyTerms {
            if text.lowercased().contains(term) {
                patterns[.assessment]?.append(ExtractedPattern(
                    inputPhrase: term,
                    outputFormat: term.capitalized,
                    confidence: 0.82,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract general patterns from any section
    private func extractGeneralPatterns(from text: String, dialogue: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        // Extract any medical terminology
        let medicalTerms = extractMedicalTerms(from: text)
        for term in medicalTerms {
            patterns[.symptoms]?.append(ExtractedPattern(
                inputPhrase: term.lowercased(),
                outputFormat: term,
                confidence: 0.75,
                source: "MTS-Dialog"
            ))
        }
    }
    
    /// Extract vital signs patterns
    private func extractVitalsPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        // Blood pressure patterns
        let bpRegex = try? NSRegularExpression(pattern: "(\\d{2,3})/(\\d{2,3})", options: [])
        if let matches = bpRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(3) {
                if let bpRange = Range(match.range, in: text) {
                    let bp = String(text[bpRange])
                    patterns[.vitals]?.append(ExtractedPattern(
                        inputPhrase: "blood pressure \(bp)",
                        outputFormat: "BP: \(bp) mmHg",
                        confidence: 0.95,
                        source: "MTS-Dialog"
                    ))
                }
            }
        }
        
        // Heart rate patterns
        let hrTerms = ["heart rate", "pulse", "hr"]
        for term in hrTerms {
            if text.contains(term) {
                if let hrMatch = text.range(of: "\\d{2,3}", options: .regularExpression) {
                    let hr = String(text[hrMatch])
                    patterns[.vitals]?.append(ExtractedPattern(
                        inputPhrase: "\(term) \(hr)",
                        outputFormat: "HR: \(hr) bpm",
                        confidence: 0.92,
                        source: "MTS-Dialog"
                    ))
                }
            }
        }
        
        // Temperature patterns
        let tempRegex = try? NSRegularExpression(pattern: "(\\d{2}\\.\\d|\\d{3}\\.\\d)", options: [])
        if let matches = tempRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(2) {
                if let tempRange = Range(match.range, in: text) {
                    let temp = String(text[tempRange])
                    if let tempValue = Float(temp), tempValue > 95 && tempValue < 106 {
                        patterns[.vitals]?.append(ExtractedPattern(
                            inputPhrase: "temp \(temp)",
                            outputFormat: "Temperature: \(temp)°F",
                            confidence: 0.9,
                            source: "MTS-Dialog"
                        ))
                    }
                }
            }
        }
    }
    
    /// Extract timing patterns
    private func extractTimingPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let timingTerms = [
            ("yesterday", "1 day ago"),
            ("this morning", "earlier today"),
            ("last night", "overnight"),
            ("few days", "2-3 days"),
            ("couple weeks", "2 weeks"),
            ("last month", "1 month ago"),
            ("hours ago", "several hours ago"),
            ("just now", "moments ago"),
            ("ongoing", "persistent")
        ]
        
        for (colloquial, medical) in timingTerms {
            if text.contains(colloquial) {
                patterns[.timing]?.append(ExtractedPattern(
                    inputPhrase: colloquial,
                    outputFormat: medical,
                    confidence: 0.85,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract severity patterns
    private func extractSeverityPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let severityScale = [
            ("1/10", "1 out of 10"),
            ("2/10", "2 out of 10"),
            ("3/10", "3 out of 10 - mild"),
            ("4/10", "4 out of 10 - mild to moderate"),
            ("5/10", "5 out of 10 - moderate"),
            ("6/10", "6 out of 10 - moderate"),
            ("7/10", "7 out of 10 - moderate to severe"),
            ("8/10", "8 out of 10 - severe"),
            ("9/10", "9 out of 10 - severe"),
            ("10/10", "10 out of 10 - worst possible")
        ]
        
        for (scale, description) in severityScale {
            if text.contains(scale) {
                patterns[.severity]?.append(ExtractedPattern(
                    inputPhrase: scale,
                    outputFormat: description,
                    confidence: 0.93,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract location patterns
    private func extractLocationPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let anatomicalLocations = [
            ("head", "cranial region"),
            ("chest", "thoracic region"),
            ("belly", "abdominal region"),
            ("back", "dorsal region"),
            ("leg", "lower extremity"),
            ("arm", "upper extremity"),
            ("left side", "left lateral"),
            ("right side", "right lateral"),
            ("both sides", "bilateral"),
            ("everywhere", "diffuse/generalized")
        ]
        
        for (colloquial, medical) in anatomicalLocations {
            if text.contains(colloquial) {
                patterns[.location]?.append(ExtractedPattern(
                    inputPhrase: colloquial,
                    outputFormat: medical,
                    confidence: 0.86,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract quality patterns
    private func extractQualityPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let qualityDescriptors = [
            ("stabbing", "sharp/stabbing quality"),
            ("crushing", "crushing/pressure-like"),
            ("squeezing", "squeezing sensation"),
            ("aching", "dull aching quality"),
            ("burning", "burning quality"),
            ("electric", "electric shock-like"),
            ("throbbing", "pulsatile quality"),
            ("constant", "continuous"),
            ("comes and goes", "intermittent")
        ]
        
        for (descriptor, medical) in qualityDescriptors {
            if text.contains(descriptor) {
                patterns[.quality]?.append(ExtractedPattern(
                    inputPhrase: descriptor,
                    outputFormat: medical,
                    confidence: 0.87,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract modifier patterns
    private func extractModifierPatterns(from text: String, patterns: inout [PatternCategory: [ExtractedPattern]]) {
        let modifiers = [
            ("getting worse", "progressive worsening"),
            ("getting better", "improving"),
            ("no change", "unchanged"),
            ("worse with movement", "exacerbated by movement"),
            ("better with rest", "relieved by rest"),
            ("worse at night", "nocturnal exacerbation"),
            ("worse when breathing", "pleuritic"),
            ("radiates", "with radiation to")
        ]
        
        for (modifier, medical) in modifiers {
            if text.contains(modifier) {
                patterns[.modifiers]?.append(ExtractedPattern(
                    inputPhrase: modifier,
                    outputFormat: medical,
                    confidence: 0.84,
                    source: "MTS-Dialog"
                ))
            }
        }
    }
    
    /// Extract age pattern from text
    private func extractAgePattern(from text: String) -> ExtractedPattern? {
        // Look for age patterns like "76-year-old" or "25 year old"
        let ageRegex = try? NSRegularExpression(pattern: "\\d+[- ]?year[- ]?old", options: .caseInsensitive)
        if let match = ageRegex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            let ageText = String(text[Range(match.range, in: text)!])
            return ExtractedPattern(
                inputPhrase: "age mention",
                outputFormat: "The patient is a \(ageText)",
                confidence: 0.95,
                source: "MTS-Dialog"
            )
        }
        return nil
    }
    
    /// Parse CSV line handling quoted fields
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var currentField = ""
        var inQuotes = false
        var previousChar: Character?
        
        for char in line {
            if char == "\"" && previousChar != "\\" {
                inQuotes = !inQuotes
            } else if char == "," && !inQuotes {
                result.append(currentField)
                currentField = ""
            } else {
                currentField.append(char)
            }
            previousChar = char
        }
        
        // Add the last field
        result.append(currentField)
        
        // Clean up fields - remove quotes and trim
        return result.map { field in
            field.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }
    
    /// Extract medical terms from text
    private func extractMedicalTerms(from text: String) -> [String] {
        var terms: [String] = []
        
        // Expanded medical terms list
        let medicalKeywords = [
            "pain", "fever", "cough", "headache", "nausea", "vomiting",
            "diarrhea", "constipation", "bleeding", "swelling", "rash",
            "shortness of breath", "chest pain", "abdominal pain",
            "dizziness", "weakness", "fatigue", "malaise", "chills",
            "sweating", "palpitations", "syncope", "confusion",
            "anxiety", "depression", "insomnia", "anorexia",
            "dyspnea", "dysphagia", "dysuria", "hemoptysis",
            "hematuria", "hematemesis", "melena", "epistaxis"
        ]
        
        let textLower = text.lowercased()
        for keyword in medicalKeywords {
            if textLower.contains(keyword) {
                terms.append(keyword.capitalized)
            }
        }
        
        return terms
    }
    
    /// Apply learned patterns to improve the analyzer
    private func applyPatternsToAnalyzer() async throws {
        await MainActor.run {
            self.statusMessage = "Applying patterns to analyzer..."
            self.progress = 0.7
        }
        
        // Create pattern configuration file
        var configContent = """
        // Learned Patterns from MTS-Dialog Dataset
        // Generated: \(Date())
        // Total Patterns: \(patternsLearned)
        
        import Foundation
        
        /// Pattern-based improvements for RealConversationAnalyzer
        extension RealConversationAnalyzer {
            
            static let mtsDialogPatterns: [String: String] = [
        """
        
        // Add learned patterns - include MORE patterns per category
        for (category, patterns) in learnedPatterns {
            if !patterns.isEmpty {
                configContent += "\n        // \(category.rawValue) patterns (\(patterns.count) total)\n"
                // Include up to 15 patterns per category instead of just 5
                for pattern in patterns.prefix(15) {
                    let key = pattern.inputPhrase.replacingOccurrences(of: "\"", with: "\\\"")
                    let value = pattern.outputFormat.replacingOccurrences(of: "\"", with: "\\\"")
                    configContent += "        \"\(key)\": \"\(value)\",\n"
                }
            }
        }
        
        configContent += """
            ]
            
            /// Apply MTS-Dialog patterns to improve extraction
            static func applyMTSDialogPatterns(to text: String) -> [String: String] {
                var improvements: [String: String] = [:]
                
                for (pattern, output) in mtsDialogPatterns {
                    if text.lowercased().contains(pattern.lowercased()) {
                        improvements[pattern] = output
                    }
                }
                
                return improvements
            }
            
            /// Get pattern statistics
            static func getPatternStats() -> String {
                return "Loaded \\(mtsDialogPatterns.count) patterns from MTS-Dialog dataset"
            }
        }
        """
        
        // Save pattern configuration
        let configPath = "/Users/jamesalford/Documents/NotedCore/NotedCore/MTSDialogPatterns.swift"
        try configContent.write(toFile: configPath, atomically: true, encoding: .utf8)
        
        await MainActor.run {
            self.statusMessage = "Pattern configuration saved with \(self.patternsLearned) patterns"
            self.progress = 0.9
        }
    }
    
    /// Download datasets if not present
    func downloadDatasets() async {
        await MainActor.run {
            statusMessage = "Checking for datasets..."
        }
        
        let mtsPath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/MTS-Dialog"
        let priMockPath = "/Users/jamesalford/Documents/NotedCore/MedicalDatasets/primock57"
        
        let mtsExists = FileManager.default.fileExists(atPath: mtsPath)
        let priMockExists = FileManager.default.fileExists(atPath: priMockPath)
        
        if !mtsExists || !priMockExists {
            await MainActor.run {
                statusMessage = "Please run the download script: ./Scripts/download_datasets.sh"
            }
        } else {
            await MainActor.run {
                statusMessage = "Datasets found! Ready to analyze."
            }
        }
    }
}

// Helper extension for String
extension String {
    var trimmingQuotes: String {
        self.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}