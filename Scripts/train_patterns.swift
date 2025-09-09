#!/usr/bin/env swift

import Foundation

// Standalone training script to generate patterns from MTS-Dialog dataset
// Run this ONCE during development to generate the patterns file
// The generated file gets compiled into the app for all users

struct ExtractedPattern: Hashable {
    let inputPhrase: String
    let outputFormat: String
    let confidence: Float
    let source: String
}

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

class PatternExtractor {
    private var patterns: [PatternCategory: Set<ExtractedPattern>] = [:]
    private var processedPatterns = 0
    
    func run() {
        print("🔬 MTS-Dialog Pattern Extraction Tool v2.0")
        print("=========================================")
        
        // Initialize pattern sets
        for category in PatternCategory.allCases {
            patterns[category] = []
        }
        
        let mtsPath = "../MedicalDatasets/MTS-Dialog/Main-Dataset/MTS-Dialog-TrainingSet.csv"
        
        guard FileManager.default.fileExists(atPath: mtsPath) else {
            print("❌ Error: MTS-Dialog dataset not found at \(mtsPath)")
            print("Please download the dataset first using download_datasets.sh")
            exit(1)
        }
        
        print("✅ Found MTS-Dialog dataset")
        print("📊 Starting comprehensive pattern extraction...")
        
        do {
            let content = try String(contentsOfFile: mtsPath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)
            
            var processedSamples = 0
            let dataLines = lines.dropFirst() // Skip header
            
            // Process ALL samples for maximum pattern extraction
            for line in dataLines {
                guard !line.isEmpty else { continue }
                
                let fields = parseCSVLine(line)
                guard fields.count >= 4 else { continue }
                
                let sectionHeader = fields[1].trimmingCharacters(in: .whitespaces)
                let sectionText = fields[2]
                let dialogue = fields[3]
                
                if sectionHeader == "section_header" { continue }
                
                // Extract patterns from ALL fields comprehensively
                extractAllPatterns(
                    header: sectionHeader,
                    text: sectionText,
                    dialogue: dialogue
                )
                
                processedSamples += 1
                if processedSamples % 100 == 0 {
                    print("  Processed \(processedSamples) samples... (\(processedPatterns) patterns found)")
                }
            }
            
            let totalPatterns = patterns.values.reduce(0) { $0 + $1.count }
            print("✅ Extracted \(totalPatterns) unique patterns from \(processedSamples) samples")
            
            // Print category breakdown
            print("\n📊 Pattern Breakdown by Category:")
            for category in PatternCategory.allCases {
                let count = patterns[category]?.count ?? 0
                if count > 0 {
                    print("  • \(category.rawValue): \(count) patterns")
                }
            }
            
            // Generate Swift file
            generatePatternFile()
            
            print("\n✅ Successfully generated NotedCore/PretrainedMedicalPatterns.swift")
            print("📦 This file will be compiled into the app for all users")
            
        } catch {
            print("❌ Error: \(error)")
            exit(1)
        }
    }
    
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
        
        result.append(currentField)
        
        return result.map { field in
            field.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
    }
    
    private func extractAllPatterns(header: String, text: String, dialogue: String) {
        let combinedText = "\(text) \(dialogue)"
        
        // Extract patterns based on section type
        switch header.lowercased() {
        case "cc", "chief complaint":
            extractChiefComplaintPatterns(from: text, dialogue: dialogue)
        case "hpi", "genhx", "history of present illness":
            extractHPIPatterns(from: text, dialogue: dialogue)
        case "medications", "meds", "medication":
            extractMedicationPatterns(from: text, dialogue: dialogue)
        case "allergies", "allergy":
            extractAllergyPatterns(from: text, dialogue: dialogue)
        case "exam", "pe", "physical exam", "physical examination":
            extractExamPatterns(from: text, dialogue: dialogue)
        case "assessment", "plan", "a/p", "assessment and plan":
            extractAssessmentPatterns(from: text, dialogue: dialogue)
        case "disposition", "dispo":
            extractDispositionPatterns(from: text, dialogue: dialogue)
        case "ros", "review of systems":
            extractROSPatterns(from: text, dialogue: dialogue)
        case "pmh", "past medical history":
            extractPMHPatterns(from: text, dialogue: dialogue)
        case "psh", "past surgical history":
            extractPSHPatterns(from: text, dialogue: dialogue)
        case "sh", "social history":
            extractSocialHistoryPatterns(from: text, dialogue: dialogue)
        default:
            // Still extract general patterns
            break
        }
        
        // Always extract these patterns from all sections
        extractVitalPatterns(from: combinedText)
        extractTimingPatterns(from: combinedText)
        extractSeverityPatterns(from: combinedText)
        extractLocationPatterns(from: combinedText)
        extractQualityPatterns(from: combinedText)
        extractSymptomPatterns(from: combinedText)
    }
    
    private func addPattern(_ category: PatternCategory, _ input: String, _ output: String, confidence: Float = 0.9) {
        guard !input.isEmpty && !output.isEmpty else { return }
        patterns[category]?.insert(ExtractedPattern(
            inputPhrase: input.lowercased(),
            outputFormat: output,
            confidence: confidence,
            source: "MTS-Dialog"
        ))
        processedPatterns += 1
    }
    
    private func extractChiefComplaintPatterns(from text: String, dialogue: String) {
        let complaints = [
            "chest pain", "abdominal pain", "headache", "shortness of breath",
            "back pain", "nausea", "vomiting", "diarrhea", "fever", "cough",
            "dizziness", "weakness", "fatigue", "rash", "swelling",
            "pain", "bleeding", "constipation", "difficulty breathing",
            "palpitations", "syncope", "altered mental status", "seizure",
            "anxiety", "depression", "confusion", "leg pain", "arm pain",
            "neck pain", "throat pain", "ear pain", "eye pain", "tooth pain",
            "joint pain", "muscle pain", "numbness", "tingling", "burning"
        ]
        
        let textLower = text.lowercased()
        for complaint in complaints {
            if textLower.contains(complaint) {
                addPattern(.chiefComplaint, complaint, complaint.capitalized)
                
                // Add variations
                if complaint.contains("pain") {
                    let location = complaint.replacingOccurrences(of: " pain", with: "")
                    addPattern(.location, location, "\(location) region")
                }
            }
        }
    }
    
    private func extractHPIPatterns(from text: String, dialogue: String) {
        // Age patterns
        let ageRegex = try? NSRegularExpression(pattern: "(\\d+)[- ]?year[- ]?old", options: .caseInsensitive)
        if let matches = ageRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(5) {
                if let ageRange = Range(match.range, in: text) {
                    let ageText = String(text[ageRange])
                    if let ageNum = Int(ageText.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) {
                        addPattern(.demographics, "age \(ageNum)", "The patient is a \(ageText)")
                        addPattern(.demographics, "\(ageNum) year old", "\(ageText) patient")
                    }
                }
            }
        }
        
        // Gender patterns
        let genderTerms = [
            ("male", "male patient"),
            ("female", "female patient"),
            ("man", "male patient"),
            ("woman", "female patient"),
            ("gentleman", "male patient"),
            ("lady", "female patient")
        ]
        
        let textLower = text.lowercased()
        for (term, medical) in genderTerms {
            if textLower.contains(term) {
                addPattern(.demographics, term, medical)
            }
        }
        
        // Onset patterns
        let onsetTerms = [
            ("sudden onset", "acute onset"),
            ("gradual onset", "insidious onset"),
            ("started suddenly", "sudden onset"),
            ("came on slowly", "gradual onset"),
            ("acute", "acute presentation"),
            ("chronic", "chronic condition"),
            ("intermittent", "intermittent symptoms"),
            ("constant", "persistent symptoms"),
            ("on and off", "intermittent")
        ]
        
        for (colloquial, medical) in onsetTerms {
            if textLower.contains(colloquial) {
                addPattern(.onset, colloquial, medical)
            }
        }
    }
    
    private func extractMedicationPatterns(from text: String, dialogue: String) {
        let medications = [
            "aspirin", "ibuprofen", "acetaminophen", "tylenol", "advil", "motrin",
            "lisinopril", "metformin", "atorvastatin", "omeprazole", "prilosec",
            "metoprolol", "amlodipine", "simvastatin", "losartan", "gabapentin",
            "hydrochlorothiazide", "sertraline", "zoloft", "lexapro", "prozac",
            "insulin", "albuterol", "prednisone", "amoxicillin", "azithromycin",
            "ciprofloxacin", "doxycycline", "levothyroxine", "warfarin", "lorazepam",
            "tramadol", "oxycodone", "morphine", "fentanyl", "dilaudid",
            "zofran", "phenergan", "benadryl", "pepcid", "tums", "maalox"
        ]
        
        let textLower = text.lowercased()
        for med in medications {
            if textLower.contains(med) {
                let capitalizedMed = med.capitalized
                addPattern(.medications, med, capitalizedMed)
                
                // Common brand/generic pairs
                if med == "acetaminophen" {
                    addPattern(.medications, "tylenol", "Acetaminophen (Tylenol)")
                } else if med == "ibuprofen" {
                    addPattern(.medications, "advil", "Ibuprofen (Advil)")
                    addPattern(.medications, "motrin", "Ibuprofen (Motrin)")
                }
            }
        }
        
        // Dosage patterns
        let doseRegex = try? NSRegularExpression(
            pattern: "(\\d+)\\s*(mg|mcg|g|ml|units?|tabs?|pills?)",
            options: .caseInsensitive
        )
        
        if let matches = doseRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(10) {
                if let doseRange = Range(match.range, in: text) {
                    let doseText = String(text[doseRange])
                    addPattern(.medications, doseText.lowercased(), doseText, confidence: 0.95)
                }
            }
        }
    }
    
    private func extractAllergyPatterns(from text: String, dialogue: String) {
        let allergyTerms = [
            ("nkda", "NKDA"),
            ("no known drug allergies", "NKDA"),
            ("no allergies", "NKDA"),
            ("no known allergies", "NKDA"),
            ("penicillin allergy", "Penicillin allergy"),
            ("sulfa allergy", "Sulfa allergy"),
            ("morphine allergy", "Morphine allergy"),
            ("codeine allergy", "Codeine allergy"),
            ("shellfish allergy", "Shellfish allergy"),
            ("peanut allergy", "Peanut allergy"),
            ("latex allergy", "Latex allergy"),
            ("allergic to", "Allergy to")
        ]
        
        let textLower = text.lowercased()
        for (term, medical) in allergyTerms {
            if textLower.contains(term) {
                addPattern(.allergies, term, medical)
            }
        }
    }
    
    private func extractExamPatterns(from text: String, dialogue: String) {
        let examFindings = [
            ("tender", "tenderness on palpation"),
            ("no tenderness", "no tenderness elicited"),
            ("hurts when i press", "positive for tenderness"),
            ("doesn't hurt", "no pain elicited"),
            ("normal", "within normal limits"),
            ("unremarkable", "unremarkable examination"),
            ("looks good", "normal appearance"),
            ("looks fine", "no abnormalities noted"),
            ("clear lungs", "lungs clear to auscultation bilaterally"),
            ("lungs sound good", "clear lung sounds"),
            ("regular rhythm", "regular rate and rhythm"),
            ("heart sounds normal", "normal S1 and S2, no murmurs"),
            ("soft abdomen", "abdomen soft, non-tender"),
            ("belly soft", "abdomen soft"),
            ("distended", "abdominal distension noted"),
            ("swollen", "edema present"),
            ("guarding", "voluntary guarding present"),
            ("rebound", "positive rebound tenderness"),
            ("murmur", "cardiac murmur appreciated"),
            ("wheezing", "expiratory wheezing noted"),
            ("rales", "rales present"),
            ("crackles", "crackles on auscultation")
        ]
        
        let textLower = text.lowercased()
        for (finding, medical) in examFindings {
            if textLower.contains(finding) {
                addPattern(.examination, finding, medical)
            }
        }
    }
    
    private func extractAssessmentPatterns(from text: String, dialogue: String) {
        let assessmentTerms = [
            ("likely", "most likely"),
            ("probably", "probable"),
            ("possibly", "possible"),
            ("maybe", "possible"),
            ("rule out", "rule out"),
            ("consistent with", "consistent with"),
            ("suspicious for", "concerning for"),
            ("looks like", "appears to be"),
            ("think it's", "clinical impression"),
            ("working diagnosis", "working diagnosis"),
            ("differential", "differential diagnosis includes")
        ]
        
        let textLower = text.lowercased()
        for (term, medical) in assessmentTerms {
            if textLower.contains(term) {
                addPattern(.assessment, term, medical)
            }
        }
    }
    
    private func extractDispositionPatterns(from text: String, dialogue: String) {
        let dispoTerms = [
            ("discharge home", "Discharged home in stable condition"),
            ("send home", "Discharged home"),
            ("go home", "Discharged to home"),
            ("admit", "Admitted for further management"),
            ("admission", "Hospital admission"),
            ("keep overnight", "Admit for observation"),
            ("observation", "Placed in observation status"),
            ("obs unit", "Observation unit admission"),
            ("transfer", "Transfer to higher level of care"),
            ("follow up", "Follow-up arranged"),
            ("come back if", "Return precautions given"),
            ("return if worse", "Return if symptoms worsen"),
            ("call doctor", "Contact primary care physician"),
            ("see pcp", "Follow up with primary care")
        ]
        
        let textLower = text.lowercased()
        for (term, formal) in dispoTerms {
            if textLower.contains(term) {
                addPattern(.disposition, term, formal)
            }
        }
    }
    
    private func extractROSPatterns(from text: String, dialogue: String) {
        let rosTerms = [
            ("denies fever", "Denies fever"),
            ("no fever", "No fever"),
            ("no chills", "Denies chills"),
            ("no weight loss", "Denies weight loss"),
            ("no night sweats", "Denies night sweats"),
            ("no chest pain", "Denies chest pain"),
            ("no sob", "Denies shortness of breath"),
            ("no nausea", "Denies nausea"),
            ("no vomiting", "Denies vomiting"),
            ("no diarrhea", "Denies diarrhea"),
            ("no constipation", "Denies constipation"),
            ("no blood", "Denies bleeding"),
            ("no rash", "Denies rash"),
            ("positive for", "Positive for"),
            ("negative for", "Negative for")
        ]
        
        let textLower = text.lowercased()
        for (term, medical) in rosTerms {
            if textLower.contains(term) {
                addPattern(.symptoms, term, medical)
            }
        }
    }
    
    private func extractPMHPatterns(from text: String, dialogue: String) {
        let conditions = [
            "diabetes", "hypertension", "heart disease", "cad", "chf",
            "asthma", "copd", "cancer", "stroke", "heart attack", "mi",
            "kidney disease", "liver disease", "thyroid", "depression",
            "anxiety", "bipolar", "schizophrenia", "seizures", "epilepsy",
            "arthritis", "osteoporosis", "gerd", "ulcers", "ibs",
            "crohn's", "colitis", "hepatitis", "hiv", "aids"
        ]
        
        let textLower = text.lowercased()
        for condition in conditions {
            if textLower.contains(condition) {
                let formatted = condition.uppercased() == condition ? condition : condition.capitalized
                addPattern(.assessment, condition, "History of \(formatted)")
                addPattern(.assessment, "h/o \(condition)", "History of \(formatted)")
                addPattern(.assessment, "hx \(condition)", "History of \(formatted)")
            }
        }
    }
    
    private func extractPSHPatterns(from text: String, dialogue: String) {
        let surgeries = [
            ("appendectomy", "Appendectomy"),
            ("cholecystectomy", "Cholecystectomy"),
            ("hysterectomy", "Hysterectomy"),
            ("c-section", "Cesarean section"),
            ("cesarean", "Cesarean section"),
            ("hernia repair", "Hernia repair"),
            ("gallbladder surgery", "Cholecystectomy"),
            ("gallbladder removed", "Prior cholecystectomy"),
            ("appendix removed", "Prior appendectomy"),
            ("tonsillectomy", "Tonsillectomy"),
            ("knee surgery", "Knee surgery"),
            ("back surgery", "Back surgery"),
            ("heart surgery", "Cardiac surgery"),
            ("bypass", "CABG"),
            ("stent", "Cardiac stent placement")
        ]
        
        let textLower = text.lowercased()
        for (surgery, medical) in surgeries {
            if textLower.contains(surgery) {
                addPattern(.assessment, surgery, "Prior \(medical)")
            }
        }
    }
    
    private func extractSocialHistoryPatterns(from text: String, dialogue: String) {
        let socialTerms = [
            ("smokes", "Tobacco use"),
            ("smoker", "Current smoker"),
            ("quit smoking", "Former smoker"),
            ("drinks alcohol", "Alcohol use"),
            ("drinks", "ETOH use"),
            ("no alcohol", "Denies alcohol use"),
            ("drugs", "Substance use"),
            ("no drugs", "Denies illicit drug use"),
            ("married", "Married"),
            ("single", "Single"),
            ("divorced", "Divorced"),
            ("widowed", "Widowed"),
            ("retired", "Retired"),
            ("works", "Employed"),
            ("unemployed", "Unemployed")
        ]
        
        let textLower = text.lowercased()
        for (term, formal) in socialTerms {
            if textLower.contains(term) {
                addPattern(.assessment, term, formal)
            }
        }
    }
    
    private func extractVitalPatterns(from text: String) {
        // Blood pressure patterns
        let bpRegex = try? NSRegularExpression(pattern: "(\\d{2,3})/(\\d{2,3})", options: [])
        if let matches = bpRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(5) {
                if let bpRange = Range(match.range, in: text) {
                    let bp = String(text[bpRange])
                    // Validate BP is reasonable
                    let components = bp.split(separator: "/")
                    if components.count == 2,
                       let systolic = Int(components[0]),
                       let diastolic = Int(components[1]),
                       systolic > 70 && systolic < 250,
                       diastolic > 40 && diastolic < 150 {
                        addPattern(.vitals, "bp \(bp)", "BP: \(bp) mmHg")
                        addPattern(.vitals, "blood pressure \(bp)", "BP: \(bp) mmHg")
                        addPattern(.vitals, "\(bp)", "Blood pressure \(bp) mmHg")
                    }
                }
            }
        }
        
        // Heart rate patterns
        let hrRegex = try? NSRegularExpression(pattern: "(?:hr|heart rate|pulse)\\s*(?:of|is)?\\s*(\\d{2,3})", options: .caseInsensitive)
        if let matches = hrRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(3) {
                if let group = Range(match.range(at: 1), in: text) {
                    let hr = String(text[group])
                    if let hrValue = Int(hr), hrValue > 40 && hrValue < 200 {
                        addPattern(.vitals, "hr \(hr)", "HR: \(hr) bpm")
                        addPattern(.vitals, "pulse \(hr)", "Pulse: \(hr) bpm")
                        addPattern(.vitals, "heart rate \(hr)", "Heart rate: \(hr) bpm")
                    }
                }
            }
        }
        
        // Temperature patterns
        let tempRegex = try? NSRegularExpression(pattern: "(\\d{2,3}\\.\\d)", options: [])
        if let matches = tempRegex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(3) {
                if let tempRange = Range(match.range, in: text) {
                    let temp = String(text[tempRange])
                    if let tempValue = Float(temp), tempValue > 95 && tempValue < 106 {
                        addPattern(.vitals, "temp \(temp)", "Temperature: \(temp)°F")
                        addPattern(.vitals, "temperature \(temp)", "Temp: \(temp)°F")
                        addPattern(.vitals, "fever \(temp)", "Febrile: \(temp)°F")
                    }
                }
            }
        }
        
        // O2 saturation
        let o2Regex = try? NSRegularExpression(pattern: "(?:o2|oxygen|sat)\\s*(?:sat)?\\s*(\\d{2,3})\\s*%?", options: .caseInsensitive)
        if let matches = o2Regex?.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            for match in matches.prefix(3) {
                if let group = Range(match.range(at: 1), in: text) {
                    let o2 = String(text[group])
                    if let o2Value = Int(o2), o2Value > 70 && o2Value <= 100 {
                        addPattern(.vitals, "o2 \(o2)", "O2 Sat: \(o2)%")
                        addPattern(.vitals, "sat \(o2)", "SpO2: \(o2)%")
                    }
                }
            }
        }
    }
    
    private func extractTimingPatterns(from text: String) {
        let timingTerms = [
            ("yesterday", "1 day ago"),
            ("today", "today"),
            ("this morning", "earlier today"),
            ("this afternoon", "this afternoon"),
            ("tonight", "this evening"),
            ("last night", "overnight"),
            ("few days ago", "2-3 days ago"),
            ("couple days", "2 days"),
            ("few hours ago", "several hours ago"),
            ("couple hours", "2 hours"),
            ("last week", "1 week ago"),
            ("couple weeks", "2 weeks ago"),
            ("last month", "1 month ago"),
            ("few months", "2-3 months"),
            ("last year", "1 year ago"),
            ("minutes ago", "few minutes ago"),
            ("just now", "moments ago"),
            ("recently", "recently"),
            ("a while ago", "some time ago"),
            ("long time", "chronic duration"),
            ("ongoing", "persistent"),
            ("on and off", "intermittent")
        ]
        
        let textLower = text.lowercased()
        for (colloquial, medical) in timingTerms {
            if textLower.contains(colloquial) {
                addPattern(.timing, colloquial, medical)
            }
        }
    }
    
    private func extractSeverityPatterns(from text: String) {
        // Pain scale patterns
        for i in 1...10 {
            let patterns = [
                "\(i)/10",
                "\(i) out of 10",
                "\(i) of 10"
            ]
            
            for pattern in patterns {
                if text.lowercased().contains(pattern) {
                    let description = i <= 3 ? "mild" : i <= 6 ? "moderate" : "severe"
                    addPattern(.severity, pattern, "\(i)/10 - \(description)")
                    addPattern(.severity, "pain \(pattern)", "Pain severity \(i)/10 - \(description)")
                }
            }
        }
        
        // Descriptive severity
        let severityTerms = [
            ("mild", "mild severity"),
            ("moderate", "moderate severity"),
            ("severe", "severe intensity"),
            ("really bad", "severe"),
            ("terrible", "severe"),
            ("worst ever", "10/10 - worst possible"),
            ("worst pain", "severe pain"),
            ("unbearable", "unbearable pain"),
            ("excruciating", "excruciating pain"),
            ("tolerable", "tolerable discomfort"),
            ("minimal", "minimal discomfort")
        ]
        
        let textLower = text.lowercased()
        for (term, medical) in severityTerms {
            if textLower.contains(term) {
                addPattern(.severity, term, medical)
            }
        }
    }
    
    private func extractLocationPatterns(from text: String) {
        let locations = [
            ("head", "cranial region"),
            ("chest", "thoracic region"),
            ("belly", "abdominal region"),
            ("stomach", "epigastric region"),
            ("back", "dorsal region"),
            ("lower back", "lumbar region"),
            ("upper back", "thoracic spine"),
            ("neck", "cervical region"),
            ("shoulder", "shoulder region"),
            ("arm", "upper extremity"),
            ("leg", "lower extremity"),
            ("foot", "pedal region"),
            ("hand", "hand"),
            ("left side", "left lateral"),
            ("right side", "right lateral"),
            ("both sides", "bilateral"),
            ("everywhere", "diffuse/generalized"),
            ("all over", "generalized"),
            ("rlq", "right lower quadrant"),
            ("ruq", "right upper quadrant"),
            ("llq", "left lower quadrant"),
            ("luq", "left upper quadrant")
        ]
        
        let textLower = text.lowercased()
        for (colloquial, medical) in locations {
            if textLower.contains(colloquial) {
                addPattern(.location, colloquial, medical)
            }
        }
    }
    
    private func extractQualityPatterns(from text: String) {
        let qualities = [
            ("sharp", "sharp/stabbing quality"),
            ("stabbing", "stabbing pain"),
            ("dull", "dull aching"),
            ("aching", "aching quality"),
            ("burning", "burning sensation"),
            ("throbbing", "throbbing/pulsatile"),
            ("crushing", "crushing/pressure-like"),
            ("squeezing", "squeezing sensation"),
            ("tight", "tightness"),
            ("pressure", "pressure-like"),
            ("cramping", "crampy quality"),
            ("shooting", "shooting pain"),
            ("electric", "electric shock-like"),
            ("tingling", "paresthesias"),
            ("numbness", "numbness"),
            ("radiating", "radiating pain"),
            ("constant", "continuous"),
            ("comes and goes", "intermittent"),
            ("getting worse", "progressive worsening"),
            ("getting better", "improving")
        ]
        
        let textLower = text.lowercased()
        for (descriptor, medical) in qualities {
            if textLower.contains(descriptor) {
                addPattern(.quality, descriptor, medical)
            }
        }
    }
    
    private func extractSymptomPatterns(from text: String) {
        let symptoms = [
            ("sob", "shortness of breath"),
            ("cp", "chest pain"),
            ("n/v", "nausea and vomiting"),
            ("n&v", "nausea and vomiting"),
            ("ha", "headache"),
            ("dizzy", "dizziness"),
            ("vertigo", "vertigo"),
            ("weak", "weakness"),
            ("tired", "fatigue"),
            ("can't sleep", "insomnia"),
            ("can't breathe", "dyspnea"),
            ("trouble breathing", "difficulty breathing"),
            ("hard to breathe", "breathing difficulty"),
            ("throwing up", "vomiting"),
            ("threw up", "emesis"),
            ("passed out", "syncope"),
            ("fainted", "syncopal episode"),
            ("blacked out", "loss of consciousness"),
            ("racing heart", "palpitations"),
            ("heart racing", "tachycardia"),
            ("sweating", "diaphoresis"),
            ("sweaty", "diaphoretic"),
            ("confused", "confusion"),
            ("disoriented", "disorientation")
        ]
        
        let textLower = text.lowercased()
        for (colloquial, medical) in symptoms {
            if textLower.contains(colloquial) {
                addPattern(.symptoms, colloquial, medical)
            }
        }
    }
    
    private func generatePatternFile() {
        let totalPatterns = patterns.values.reduce(0) { $0 + $1.count }
        
        var content = """
        // Pre-trained Medical Patterns from MTS-Dialog Dataset
        // Generated: \(Date())
        // Total Patterns: \(totalPatterns)
        // 
        // This file is generated by Scripts/train_patterns.swift
        // DO NOT EDIT MANUALLY - regenerate using the training script
        
        import Foundation
        
        /// Pre-trained patterns for medical note generation
        /// These patterns are compiled into the app and available to all users
        struct PretrainedMedicalPatterns {
            
            /// All learned patterns organized by category
            static let patterns: [String: String] = [
        """
        
        // Add all unique patterns
        var allPatterns: [(String, String)] = []
        
        for (category, categoryPatterns) in patterns {
            if !categoryPatterns.isEmpty {
                content += "\n                // \(category.rawValue) patterns (\(categoryPatterns.count) total)\n"
                for pattern in Array(categoryPatterns).prefix(50) { // Up to 50 per category
                    let key = pattern.inputPhrase.replacingOccurrences(of: "\"", with: "\\\"")
                    let value = pattern.outputFormat.replacingOccurrences(of: "\"", with: "\\\"")
                    allPatterns.append((key, value))
                }
            }
        }
        
        // Sort and add patterns
        allPatterns.sort { $0.0 < $1.0 }
        for (key, value) in allPatterns {
            content += "                \"\(key)\": \"\(value)\",\n"
        }
        
        content += """
            ]
            
            /// Apply patterns to improve text
            static func apply(to text: String) -> String {
                var improved = text
                
                // Sort patterns by length (longest first) to avoid partial replacements
                let sortedPatterns = patterns.sorted { $0.key.count > $1.key.count }
                
                for (patternKey, replacement) in sortedPatterns {
                    // Use word boundary matching for better accuracy
                    let regex = try? NSRegularExpression(
                        pattern: "\\\\b\\(NSRegularExpression.escapedPattern(for: patternKey))\\\\b",
                        options: .caseInsensitive
                    )
                    
                    if let regex = regex {
                        improved = regex.stringByReplacingMatches(
                            in: improved,
                            range: NSRange(improved.startIndex..., in: improved),
                            withTemplate: replacement
                        )
                    }
                }
                
                return improved
            }
            
            /// Get statistics about loaded patterns
            static var statistics: String {
                return "Using \\(patterns.count) pre-trained medical patterns from MTS-Dialog dataset"
            }
        }
        """
        
        do {
            try content.write(toFile: "../NotedCore/PretrainedMedicalPatterns.swift", atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write pattern file: \(error)")
        }
    }
}

// Run the extractor
let extractor = PatternExtractor()
extractor.run()