import Foundation
import NaturalLanguage

// Advanced pattern recognition for ED Smart-Summary
@MainActor
class EDPatternRecognitionService {
    static let shared = EDPatternRecognitionService()
    
    // MARK: - Medical Pattern Library
    private let chiefComplaintPatterns = [
        // Pain patterns
        "(.+) pain": "$1 pain",
        "pain in (?:my |the )?(.+)": "$1 pain",
        "hurts? in (?:my |the )?(.+)": "$1 pain",
        "(?:my |the )?(.+) hurts?": "$1 pain",
        
        // Trauma patterns
        "(?:was in a?n? |had a?n? )?(?:mvc|mva|motor vehicle|car) (?:accident|crash|collision)": "Motor vehicle collision",
        "fell (?:down |from |off )?(.*)": "Fall $1",
        "hit (?:my |the )?(.+)": "Trauma to $1",
        
        // Symptom patterns
        "throwing up|vomiting": "Vomiting",
        "can't breathe|short(?:ness)? of breath|dyspnea|sob": "Shortness of breath",
        "dizzy|dizziness|lightheaded": "Dizziness",
        "passed out|syncope|fainted|lost consciousness": "Syncope",
        "seizure|convulsion": "Seizure"
    ]
    
    private let timePatterns = [
        // Specific times
        "(?:since |at |around )?([0-9]{1,2})(?::([0-9]{2}))? ?(am|pm|a\\.m\\.|p\\.m\\.)": "at $1:$2 $3",
        
        // Relative times
        "([0-9]+) ?(hours?|hrs?) ago": "$1 hours ago",
        "([0-9]+) ?(days?) ago": "$1 days ago",
        "([0-9]+) ?(weeks?) ago": "$1 weeks ago",
        "this morning": "this morning",
        "last night": "last night",
        "yesterday": "yesterday",
        "(?:a )?few hours ago": "few hours ago",
        "(?:a )?couple hours ago": "2 hours ago"
    ]
    
    private let severityPatterns = [
        "worst .+ ever": "10/10 severity",
        "terrible|horrible|severe|unbearable": "severe",
        "moderate|medium": "moderate", 
        "mild|slight|little": "mild",
        "([0-9]{1,2))/10": "$1/10 severity"
    ]
    
    // MARK: - Enhanced Extraction Methods
    func extractChiefComplaint(from text: String) -> String? {
        let normalized = text.lowercased()
        
        // Look for explicit chief complaint statements
        if let match = findPattern(in: normalized, patterns: [
            "(?:brings you in|what's going on|why are you here).*?patient: (.+?)(?:\\.|physician:|$)"
        ]) {
            return cleanAndCapitalize(match)
        }
        
        // Try pattern matching
        for (pattern, replacement) in chiefComplaintPatterns {
            if let _ = normalized.range(of: pattern, options: .regularExpression) {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(normalized.startIndex..., in: normalized)
                    let result = regex.stringByReplacingMatches(
                        in: normalized,
                        range: range,
                        withTemplate: replacement
                    )
                    if result != normalized {
                        return cleanAndCapitalize(result)
                    }
                }
            }
        }
        
        return nil
    }
    
    func extractDetailedHPI(from text: String) -> [String: Any] {
        var hpi: [String: Any] = [:]
        
        // Extract onset/timing
        if let timing = extractTiming(from: text) {
            hpi["onset"] = timing
        }
        
        // Extract location
        if let location = extractLocation(from: text) {
            hpi["location"] = location
        }
        
        // Extract quality
        if let quality = extractQuality(from: text) {
            hpi["quality"] = quality
        }
        
        // Extract radiation
        if let radiation = extractRadiation(from: text) {
            hpi["radiation"] = radiation
        }
        
        // Extract severity
        if let severity = extractSeverity(from: text) {
            hpi["severity"] = severity
        }
        
        // Extract modifying factors
        let modifiers = extractModifyingFactors(from: text)
        if !modifiers.isEmpty {
            hpi["modifying_factors"] = modifiers
        }
        
        // Extract associated symptoms
        let associated = extractAssociatedSymptoms(from: text)
        if !associated.isEmpty {
            hpi["associated_symptoms"] = associated
        }
        
        // Extract context (what patient was doing)
        if let context = extractContext(from: text) {
            hpi["context"] = context
        }
        
        return hpi
    }
    
    func extractTiming(from text: String) -> String? {
        let normalized = text.lowercased()
        
        for (pattern, replacement) in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(normalized.startIndex..., in: normalized)
                if let match = regex.firstMatch(in: normalized, range: range) {
                    if let captureRange = Range(match.range, in: normalized) {
                        let captured = String(normalized[captureRange])
                        return regex.stringByReplacingMatches(
                            in: captured,
                            range: NSRange(captured.startIndex..., in: captured),
                            withTemplate: replacement
                        )
                    }
                }
            }
        }
        
        // Look for "started" patterns
        if let match = findPattern(in: normalized, patterns: [
            "started (.+?) ago",
            "began (.+?) ago",
            "since (.+)"
        ]) {
            return match
        }
        
        return nil
    }
    
    func extractLocation(from text: String) -> String? {
        let bodyParts = [
            "head", "neck", "chest", "abdomen", "back", "shoulder",
            "arm", "elbow", "wrist", "hand", "finger",
            "hip", "leg", "knee", "ankle", "foot", "toe",
            "left side", "right side", "left", "right",
            "upper", "lower", "front", "back"
        ]
        
        let normalized = text.lowercased()
        
        for part in bodyParts {
            if normalized.contains(part) {
                // Look for modifiers
                let patterns = [
                    "(?:left |right |upper |lower )?\(part)",
                    "\(part) (?:area|region)"
                ]
                
                for pattern in patterns {
                    if let match = findPattern(in: normalized, patterns: [pattern]) {
                        return match
                    }
                }
                
                return part
            }
        }
        
        return nil
    }
    
    func extractQuality(from text: String) -> String? {
        let qualities = [
            "sharp", "dull", "aching", "burning", "stabbing",
            "throbbing", "cramping", "pressure", "tight", "crushing",
            "squeezing", "tearing", "electric", "shooting"
        ]
        
        let normalized = text.lowercased()
        
        for quality in qualities {
            if normalized.contains(quality) {
                return quality
            }
        }
        
        // Look for descriptive patterns
        if let match = findPattern(in: normalized, patterns: [
            "feels like (.+?)(?:\\.|,|;|$)",
            "it's (?:a |an )?(.+?) (?:pain|feeling|sensation)"
        ]) {
            return match
        }
        
        return nil
    }
    
    func extractRadiation(from text: String) -> String? {
        let normalized = text.lowercased()
        
        let patterns = [
            "radiates? (?:to |into |down )?(?:my |the )?(.+?)(?:\\.|,|;|and|$)",
            "goes? (?:to |into |down )?(?:my |the )?(.+?)(?:\\.|,|;|and|$)",
            "shoots? (?:to |into |down )?(?:my |the )?(.+?)(?:\\.|,|;|and|$)",
            "spreads? (?:to |into |down )?(?:my |the )?(.+?)(?:\\.|,|;|and|$)"
        ]
        
        if let match = findPattern(in: normalized, patterns: patterns) {
            return "radiates to \(match)"
        }
        
        return nil
    }
    
    func extractSeverity(from text: String) -> String? {
        let normalized = text.lowercased()
        
        for (pattern, replacement) in severityPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(normalized.startIndex..., in: normalized)
                if let match = regex.firstMatch(in: normalized, range: range) {
                    return regex.stringByReplacingMatches(
                        in: normalized,
                        range: match.range,
                        withTemplate: replacement
                    )
                }
            }
        }
        
        return nil
    }
    
    func extractModifyingFactors(from text: String) -> [String: [String]] {
        var factors: [String: [String]] = [:]
        let normalized = text.lowercased()
        
        // Aggravating factors
        let aggPatterns = [
            "worse (?:with |when |during )(.+?)(?:\\.|,|;|and|$)",
            "(?:aggravated|worsened) by (.+?)(?:\\.|,|;|and|$)",
            "can't (.+?) without (?:pain|it hurting)"
        ]
        
        var aggravating: [String] = []
        for pattern in aggPatterns {
            if let match = findPattern(in: normalized, patterns: [pattern]) {
                aggravating.append(match)
            }
        }
        if !aggravating.isEmpty {
            factors["aggravating"] = aggravating
        }
        
        // Alleviating factors
        let allePatterns = [
            "better (?:with |when |after )(.+?)(?:\\.|,|;|and|$)",
            "(?:improved|relieved) (?:by |with )(.+?)(?:\\.|,|;|and|$)",
            "helps when (?:I |he |she )?(.+?)(?:\\.|,|;|and|$)"
        ]
        
        var alleviating: [String] = []
        for pattern in allePatterns {
            if let match = findPattern(in: normalized, patterns: [pattern]) {
                alleviating.append(match)
            }
        }
        if !alleviating.isEmpty {
            factors["alleviating"] = alleviating
        }
        
        return factors
    }
    
    func extractAssociatedSymptoms(from text: String) -> [String] {
        var symptoms: Set<String> = []
        let normalized = text.lowercased()
        
        let symptomMap = [
            "nausea": ["nausea", "nauseated", "queasy", "sick to stomach"],
            "vomiting": ["vomiting", "vomited", "threw up", "throwing up"],
            "diarrhea": ["diarrhea", "loose stool", "watery stool"],
            "fever": ["fever", "febrile", "temperature", "hot"],
            "chills": ["chills", "shaking", "rigors"],
            "sweating": ["sweating", "diaphoresis", "sweaty", "clammy"],
            "dizziness": ["dizzy", "dizziness", "lightheaded", "woozy"],
            "weakness": ["weak", "weakness", "fatigue", "tired"],
            "numbness": ["numb", "numbness", "can't feel"],
            "tingling": ["tingling", "pins and needles", "paresthesia"]
        ]
        
        for (symptom, keywords) in symptomMap {
            for keyword in keywords {
                if normalized.contains(keyword) {
                    symptoms.insert(symptom)
                    break
                }
            }
        }
        
        return Array(symptoms).sorted()
    }
    
    func extractContext(from text: String) -> String? {
        let normalized = text.lowercased()
        
        let patterns = [
            "(?:was |were )?(.+?) when (?:it |this |the pain )?(?:started|began|happened)",
            "(?:started |began |happened )?(?:while|during|after) (.+?)(?:\\.|,|;|$)",
            "(?:I was |he was |she was |they were |patient was )(.+?) (?:when|and then)"
        ]
        
        if let match = findPattern(in: normalized, patterns: patterns) {
            return match
        }
        
        return nil
    }
    
    // MARK: - ROS Extraction with System Mapping
    func extractStructuredROS(from text: String) -> [String: [String]] {
        var ros: [String: [String]] = [:]
        let normalized = text.lowercased()
        
        let systemMappings = [
            "Constitutional": [
                "fever", "chills", "weight loss", "weight gain", "fatigue",
                "malaise", "night sweats"
            ],
            "HEENT": [
                "headache", "vision changes", "blurry vision", "hearing loss",
                "ear pain", "sore throat", "nasal congestion", "sinus"
            ],
            "Cardiovascular": [
                "chest pain", "chest pressure", "palpitations", "racing heart",
                "irregular heartbeat", "edema", "swelling"
            ],
            "Respiratory": [
                "shortness of breath", "dyspnea", "cough", "wheezing",
                "hemoptysis", "blood in sputum"
            ],
            "GI": [
                "nausea", "vomiting", "diarrhea", "constipation",
                "abdominal pain", "blood in stool", "melena", "hematemesis"
            ],
            "GU": [
                "dysuria", "frequency", "urgency", "hematuria",
                "blood in urine", "discharge"
            ],
            "Musculoskeletal": [
                "joint pain", "muscle pain", "back pain", "stiffness",
                "swelling", "limited range of motion"
            ],
            "Neurological": [
                "headache", "dizziness", "weakness", "numbness", "tingling",
                "seizure", "tremor", "gait disturbance", "speech difficulty"
            ],
            "Psychiatric": [
                "depression", "anxiety", "suicidal", "homicidal",
                "hallucinations", "insomnia"
            ],
            "Skin": [
                "rash", "itching", "lesion", "wound", "bruising"
            ]
        ]
        
        // Check for positive findings
        for (system, symptoms) in systemMappings {
            var positives: [String] = []
            
            for symptom in symptoms {
                if normalized.contains(symptom) {
                    // Check if it's denied
                    let denialPatterns = [
                        "no \(symptom)",
                        "denies \(symptom)",
                        "without \(symptom)",
                        "not? .{0,20}\(symptom)"
                    ]
                    
                    var isDenied = false
                    for pattern in denialPatterns {
                        if findPattern(in: normalized, patterns: [pattern]) != nil {
                            isDenied = true
                            break
                        }
                    }
                    
                    if !isDenied {
                        positives.append(symptom)
                    }
                }
            }
            
            if !positives.isEmpty {
                ros[system] = positives
            }
        }
        
        return ros
    }
    
    // MARK: - Physical Exam Extraction
    func extractPhysicalExam(from text: String) -> [String: [String]]? {
        let normalized = text.lowercased()
        
        // Only extract if physician explicitly states findings
        guard normalized.contains("exam") || 
              normalized.contains("i see") || 
              normalized.contains("i notice") ||
              normalized.contains("finding") ||
              normalized.contains("tender") else {
            return nil
        }
        
        var findings: [String: [String]] = [:]
        
        // Look for explicit abnormal findings
        let abnormalPatterns = [
            "tender": "tenderness",
            "swollen": "swelling",
            "red": "erythema",
            "warm": "warmth",
            "decreased range": "decreased ROM",
            "can't move": "unable to move",
            "drooping": "droop",
            "asymmetric": "asymmetry"
        ]
        
        for (pattern, finding) in abnormalPatterns {
            if normalized.contains(pattern) {
                // Try to identify the body system
                let location = extractLocation(from: normalized) ?? "General"
                if findings[location] == nil {
                    findings[location] = []
                }
                findings[location]?.append(finding)
            }
        }
        
        return findings.isEmpty ? nil : findings
    }
    
    // MARK: - MDM Extraction
    func extractMDM(from text: String) -> MDMContent? {
        let normalized = text.lowercased()
        
        // Look for differential diagnosis
        var ddx: [String] = []
        let ddxPatterns = [
            "(?:could be |possibly |likely |suspect |concern for )(.+?)(?:\\.|,|;|and|or)",
            "(?:rule out |r/o )(.+?)(?:\\.|,|;|and|or)",
            "differential includes (.+?)(?:\\.|;|$)"
        ]
        
        for pattern in ddxPatterns {
            let matches = findAllMatches(in: normalized, pattern: pattern)
        if !matches.isEmpty {
                ddx.append(contentsOf: matches)
            }
        }
        
        // Look for clinical reasoning
        var reasoning: String? = nil
        let reasoningPatterns = [
            "(?:because |since |given |based on )(.+?)(?:\\.|;|$)",
            "(?:concerned about |worried about |thinking )(.+?)(?:\\.|;|$)"
        ]
        
        for pattern in reasoningPatterns {
            if let match = findPattern(in: normalized, patterns: [pattern]) {
                reasoning = match
                break
            }
        }
        
        // Look for plan
        var plan: String? = nil
        let planPatterns = [
            "(?:plan is to |we'll |going to |will )(.+?)(?:\\.|;|$)",
            "(?:order|get|obtain|check) (.+?)(?:\\.|;|and|$)"
        ]
        
        for pattern in planPatterns {
            if let match = findPattern(in: normalized, patterns: [pattern]) {
                plan = match
                break
            }
        }
        
        if ddx.isEmpty && reasoning == nil && plan == nil {
            return nil
        }
        
        return MDMContent(
            ddx: ddx.isEmpty ? nil : ddx,
            clinicalReasoning: reasoning,
            plan: plan
        )
    }
    
    // MARK: - Helper Methods
    private func findPattern(in text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    if match.numberOfRanges > 1,
                       let captureRange = Range(match.range(at: 1), in: text) {
                        return String(text[captureRange])
                    }
                }
            }
        }
        return nil
    }
    
    private func findAllMatches(in text: String, pattern: String) -> [String] {
        var matches: [String] = []
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let range = NSRange(text.startIndex..., in: text)
            let results = regex.matches(in: text, range: range)
            
            for match in results {
                if match.numberOfRanges > 1,
                   let captureRange = Range(match.range(at: 1), in: text) {
                    matches.append(String(text[captureRange]))
                }
            }
        }
        
        return matches
    }
    
    private func cleanAndCapitalize(_ text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return text }
        
        return cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    }
    
    // MARK: - Confidence Scoring
    func calculateConfidence(for extraction: [String: Any]) -> Double {
        var score = 0.0
        var factors = 0
        
        // Check completeness of HPI elements
        let hpiElements = ["onset", "location", "quality", "severity", "modifying_factors", "associated_symptoms"]
        for element in hpiElements {
            factors += 1
            if extraction[element] != nil {
                score += 1.0
            }
        }
        
        return factors > 0 ? score / Double(factors) : 0.0
    }
}