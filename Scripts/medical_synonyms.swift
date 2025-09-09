#!/usr/bin/env swift

// Medical Synonyms Enhancement for Pattern Training
// This adds comprehensive medical synonym mappings that the base training might miss

import Foundation

struct MedicalSynonyms {
    // Comprehensive synonym groups for common medical concepts
    static let synonymGroups: [[String: String]] = [
        // Syncope/Loss of consciousness variations
        [
            "passed out": "syncope",
            "fainted": "syncope", 
            "fainting": "syncope",
            "collapsed": "syncope",
            "collapsing": "syncope",
            "lost consciousness": "syncope",
            "blacked out": "syncope",
            "fell out": "syncope",
            "falling out": "syncope",
            "went down": "syncope episode",
            "dropped": "syncope episode"
        ],
        
        // Vomiting variations
        [
            "throwing up": "vomiting",
            "threw up": "vomited",
            "puking": "vomiting",
            "puked": "vomited",
            "getting sick": "vomiting",
            "tossing cookies": "vomiting",
            "upchucking": "vomiting",
            "barfing": "vomiting",
            "heaving": "vomiting"
        ],
        
        // Dizziness variations
        [
            "dizzy": "dizziness",
            "lightheaded": "lightheadedness",
            "light-headed": "lightheadedness",
            "woozy": "dizziness",
            "spinning": "vertigo",
            "room spinning": "vertigo",
            "unsteady": "dizziness",
            "off balance": "disequilibrium",
            "feeling faint": "pre-syncope"
        ],
        
        // Chest pain variations
        [
            "chest pain": "Chest Pain",
            "chest hurts": "chest pain",
            "pain in chest": "chest pain",
            "chest pressure": "chest pressure sensation",
            "chest tightness": "chest tightness",
            "chest discomfort": "chest discomfort",
            "heart pain": "cardiac-type chest pain",
            "crushing feeling": "crushing chest pain",
            "squeezing chest": "squeezing chest pain"
        ],
        
        // Shortness of breath variations
        [
            "sob": "shortness of breath",
            "short of breath": "shortness of breath",
            "can't breathe": "dyspnea",
            "hard to breathe": "difficulty breathing",
            "trouble breathing": "difficulty breathing",
            "breathing problems": "respiratory distress",
            "out of breath": "dyspnea on exertion",
            "winded": "dyspnea",
            "can't catch breath": "air hunger",
            "gasping": "respiratory distress"
        ],
        
        // Fever variations
        [
            "fever": "Fever",
            "febrile": "febrile",
            "high temp": "elevated temperature",
            "temperature": "fever",
            "burning up": "febrile",
            "hot": "febrile sensation",
            "chills": "chills",
            "sweating": "diaphoresis",
            "night sweats": "nocturnal diaphoresis"
        ],
        
        // Pain severity (beyond basic numbers)
        [
            "worst pain ever": "10/10 severe pain",
            "excruciating": "severe pain",
            "unbearable": "severe pain",
            "killing me": "severe pain",
            "can't stand it": "severe pain",
            "really bad": "severe",
            "terrible": "severe",
            "awful": "severe",
            "horrible": "severe",
            "mild": "mild severity",
            "slight": "mild",
            "a little": "mild",
            "bearable": "tolerable",
            "manageable": "tolerable"
        ],
        
        // Nausea variations
        [
            "nauseous": "nausea",
            "queasy": "nausea",
            "sick to stomach": "nausea",
            "upset stomach": "nausea",
            "stomach turning": "nausea",
            "going to be sick": "nausea",
            "feel like vomiting": "nausea"
        ],
        
        // Headache variations
        [
            "headache": "Headache",
            "head pain": "cephalgia",
            "migraine": "migraine headache",
            "head hurts": "headache",
            "splitting headache": "severe headache",
            "pounding head": "throbbing headache",
            "tension headache": "tension-type headache"
        ],
        
        // Abdominal pain variations
        [
            "stomach ache": "abdominal pain",
            "belly pain": "abdominal pain",
            "tummy ache": "abdominal pain",
            "stomach hurts": "abdominal pain",
            "belly hurts": "abdominal pain",
            "gut pain": "abdominal pain",
            "cramps": "abdominal cramping",
            "stomach cramps": "abdominal cramping"
        ],
        
        // Mental status changes
        [
            "confused": "confusion",
            "disoriented": "disorientation",
            "altered": "altered mental status",
            "not making sense": "confusion",
            "foggy": "mental fog",
            "can't think straight": "cognitive dysfunction",
            "memory problems": "memory impairment",
            "forgetful": "memory deficit"
        ],
        
        // Weakness variations
        [
            "weak": "weakness",
            "no energy": "fatigue",
            "tired": "fatigue",
            "exhausted": "severe fatigue",
            "worn out": "fatigue",
            "can't move": "profound weakness",
            "legs gave out": "lower extremity weakness",
            "no strength": "generalized weakness"
        ],
        
        // Swelling variations
        [
            "swollen": "swelling",
            "puffy": "edema",
            "bloated": "distension",
            "water retention": "edema",
            "puffed up": "edema",
            "enlarged": "swelling"
        ],
        
        // Common medication colloquialisms
        [
            "tylenol": "Acetaminophen (Tylenol)",
            "advil": "Ibuprofen (Advil)",
            "motrin": "Ibuprofen (Motrin)",
            "aspirin": "Aspirin",
            "aleve": "Naproxen (Aleve)",
            "benadryl": "Diphenhydramine (Benadryl)",
            "pepto": "Bismuth subsalicylate (Pepto-Bismol)",
            "tums": "Calcium carbonate (Tums)",
            "insulin": "Insulin",
            "blood pressure meds": "antihypertensive medications",
            "water pill": "diuretic",
            "blood thinner": "anticoagulant",
            "pain meds": "analgesics",
            "antibiotics": "antibiotics"
        ],
        
        // Time expressions
        [
            "yesterday": "1 day ago",
            "last night": "overnight",
            "this morning": "earlier today",
            "last week": "1 week ago",
            "couple days ago": "2-3 days ago",
            "few days ago": "3-4 days ago",
            "couple weeks": "2 weeks ago",
            "last month": "1 month ago",
            "recently": "recently",
            "just started": "acute onset",
            "sudden": "acute onset",
            "gradual": "insidious onset",
            "slowly getting worse": "progressive worsening"
        ],
        
        // Body locations (colloquial to medical)
        [
            "tummy": "abdomen",
            "belly": "abdomen",
            "stomach": "epigastric region",
            "chest": "thoracic region",
            "back": "dorsal region",
            "lower back": "lumbar region",
            "upper back": "thoracic spine",
            "neck": "cervical region",
            "head": "cranial region",
            "arm": "upper extremity",
            "leg": "lower extremity",
            "foot": "pedal region",
            "hand": "hand",
            "shoulder": "shoulder region",
            "hip": "hip region",
            "knee": "knee",
            "ankle": "ankle"
        ]
    ]
    
    static func generateEnhancedPatterns() -> [String: String] {
        var patterns: [String: String] = [:]
        
        for group in synonymGroups {
            for (colloquial, medical) in group {
                patterns[colloquial] = medical
            }
        }
        
        return patterns
    }
    
    static func writeEnhancedPatternsFile() {
        let patterns = generateEnhancedPatterns()
        let sortedPatterns = patterns.sorted { $0.key < $1.key }
        
        var output = """
        // Enhanced Medical Synonym Patterns
        // Generated: \(Date())
        // Total Patterns: \(patterns.count)
        //
        // These patterns provide comprehensive medical synonym mappings
        // to ensure colloquial terms are properly translated to medical terminology
        
        import Foundation
        
        extension PretrainedMedicalPatterns {
            /// Enhanced synonym patterns for better coverage
            static let enhancedPatterns: [String: String] = [
        """
        
        for (key, value) in sortedPatterns {
            output += "\n        \"\(key)\": \"\(value)\","
        }
        
        // Remove last comma
        output = String(output.dropLast())
        
        output += """
        
            ]
            
            /// Apply both base and enhanced patterns
            static func applyWithEnhancements(to text: String) -> String {
                var improved = text
                
                // Apply enhanced patterns first (more specific)
                let enhancedSorted = enhancedPatterns.sorted { $0.key.count > $1.key.count }
                for (pattern, replacement) in enhancedSorted {
                    let regex = try? NSRegularExpression(
                        pattern: "\\\\b\\(NSRegularExpression.escapedPattern(for: pattern))\\\\b",
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
                
                // Then apply base patterns
                improved = apply(to: improved)
                
                return improved
            }
        }
        """
        
        // Write to file
        let filePath = "../NotedCore/EnhancedMedicalPatterns.swift"
        do {
            try output.write(toFile: filePath, atomically: true, encoding: .utf8)
            print("✅ Generated EnhancedMedicalPatterns.swift with \(patterns.count) patterns")
        } catch {
            print("❌ Failed to write file: \(error)")
        }
    }
}

// Generate the enhanced patterns file
MedicalSynonyms.writeEnhancedPatternsFile()
print("📊 Enhanced patterns include comprehensive synonyms for:")
print("   - Syncope (11 variations)")
print("   - Vomiting (9 variations)")
print("   - Dizziness (9 variations)")
print("   - Chest pain (9 variations)")
print("   - Shortness of breath (10 variations)")
print("   - And many more medical concepts...")