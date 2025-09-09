import Foundation

/// Template system for common clinical presentations
class ClinicalTemplateSystem {
    
    struct ClinicalTemplate {
        let name: String
        let category: String
        let requiredElements: [String]
        let physicalExamFocus: [String]
        let standardWorkup: [String]
        let documentationTemplate: String
        let criticalActions: [String]
    }
    
    /// Common ED presentation templates
    static let templates: [String: ClinicalTemplate] = [
        
        "chest_pain": ClinicalTemplate(
            name: "Chest Pain - Rule Out ACS",
            category: "Cardiovascular",
            requiredElements: [
                "Character (crushing/sharp/burning)",
                "Radiation pattern",
                "Associated symptoms (SOB, diaphoresis, nausea)",
                "Exacerbating/relieving factors",
                "Cardiac risk factors"
            ],
            physicalExamFocus: [
                "Vital signs including bilateral BP",
                "Cardiac auscultation (murmurs, rubs, gallops)",
                "Lung auscultation (crackles, wheezes)",
                "Extremity exam (edema, pulses)",
                "Chest wall palpation"
            ],
            standardWorkup: [
                "ECG within 10 minutes",
                "Troponin x2 (0 and 3 hours)",
                "CBC, BMP, PT/INR",
                "Chest X-ray",
                "Consider D-dimer if PE suspected"
            ],
            documentationTemplate: """
            Patient is a [AGE]-year-old [GENDER] presenting with chest pain.
            
            **Timing**: Onset [ONSET], duration [DURATION]
            **Character**: [QUALITY] pain, [SEVERITY]/10 severity
            **Location**: [LOCATION] with radiation to [RADIATION]
            **Associated symptoms**: [ASSOCIATED]
            **Risk factors**: [RISK_FACTORS]
            
            **HEART Score**: [CALCULATE]
            **Risk stratification**: [LOW/MODERATE/HIGH]
            """,
            criticalActions: [
                "ECG within 10 minutes of arrival",
                "Aspirin 325mg if no contraindications",
                "Serial troponins",
                "Continuous cardiac monitoring"
            ]
        ),
        
        "abdominal_pain": ClinicalTemplate(
            name: "Acute Abdominal Pain",
            category: "Gastrointestinal",
            requiredElements: [
                "Location and migration pattern",
                "Character (sharp/dull/cramping/colicky)",
                "Onset and progression",
                "Associated GI symptoms",
                "Last bowel movement",
                "Menstrual history (if applicable)"
            ],
            physicalExamFocus: [
                "Abdominal inspection",
                "Auscultation (bowel sounds)",
                "Palpation (all quadrants)",
                "Special signs (Murphy's, McBurney's, Rovsing's)",
                "Rebound and guarding",
                "Consider pelvic exam if indicated"
            ],
            standardWorkup: [
                "CBC with differential",
                "CMP",
                "Lipase",
                "Urinalysis",
                "Pregnancy test (if applicable)",
                "CT abdomen/pelvis with contrast (if indicated)"
            ],
            documentationTemplate: """
            Patient presents with abdominal pain localized to [LOCATION].
            
            **Onset**: [SUDDEN/GRADUAL] onset [TIME_AGO]
            **Character**: [QUALITY] pain, [SEVERITY]/10 severity
            **Migration**: [MIGRATION_PATTERN]
            **Associated symptoms**: [N/V/D/C], [FEVER], [APPETITE]
            **Aggravating factors**: [FACTORS]
            **Relieving factors**: [FACTORS]
            
            **Physical exam notable for**: [FINDINGS]
            **Peritoneal signs**: [PRESENT/ABSENT]
            """,
            criticalActions: [
                "Pain control",
                "NPO status if surgical concern",
                "IV fluid resuscitation if dehydrated",
                "Surgical consultation if indicated"
            ]
        ),
        
        "trauma": ClinicalTemplate(
            name: "Trauma Evaluation",
            category: "Trauma",
            requiredElements: [
                "Mechanism of injury",
                "Time of injury",
                "Loss of consciousness",
                "GCS score",
                "Associated injuries",
                "Tetanus status"
            ],
            physicalExamFocus: [
                "Primary survey (ABCDE)",
                "Secondary survey (head to toe)",
                "Neurological exam",
                "Focused exam of injured area",
                "Vascular exam distal to injury"
            ],
            standardWorkup: [
                "Imaging based on injury pattern",
                "CBC if significant blood loss",
                "Type and screen if surgery possible",
                "Coagulation studies if on anticoagulation"
            ],
            documentationTemplate: """
            **Mechanism**: [MECHANISM] at [TIME]
            **Loss of consciousness**: [YES/NO], duration [TIME]
            **GCS**: E[#] V[#] M[#] = [TOTAL]
            **Injuries identified**: [LIST]
            
            **Primary survey**: [STABLE/UNSTABLE]
            **Secondary survey findings**: [FINDINGS]
            **Neurovascular status**: [INTACT/DEFICIT]
            """,
            criticalActions: [
                "C-spine immobilization if indicated",
                "FAST exam if indicated",
                "Tetanus prophylaxis",
                "Trauma team activation if criteria met"
            ]
        ),
        
        "altered_mental_status": ClinicalTemplate(
            name: "Altered Mental Status",
            category: "Neurological",
            requiredElements: [
                "Baseline mental status",
                "Time course of change",
                "Associated symptoms",
                "Medication list review",
                "Substance use history",
                "Recent infections"
            ],
            physicalExamFocus: [
                "GCS score",
                "Pupils (size, reactivity)",
                "Complete neurological exam",
                "Signs of trauma",
                "Signs of infection",
                "Signs of toxidrome"
            ],
            standardWorkup: [
                "Fingerstick glucose",
                "CBC, CMP, LFTs",
                "Urinalysis and culture",
                "Blood cultures if febrile",
                "CT head",
                "Consider LP if indicated",
                "Toxicology screen",
                "Ammonia, TSH if indicated"
            ],
            documentationTemplate: """
            **Baseline mental status**: [DESCRIPTION]
            **Current mental status**: GCS [SCORE], [DESCRIPTION]
            **Time course**: [ACUTE/GRADUAL] over [TIMEFRAME]
            
            **Possible precipitants**: [LIST]
            **Medication changes**: [LIST]
            **Infectious symptoms**: [PRESENT/ABSENT]
            
            **Neurological findings**: [FOCAL/NON-FOCAL]
            """,
            criticalActions: [
                "Immediate glucose check",
                "Protect airway if needed",
                "Naloxone if opioid suspected",
                "Thiamine before glucose if indicated"
            ]
        )
    ]
    
    /// Match template based on chief complaint
    static func selectTemplate(for chiefComplaint: String) -> ClinicalTemplate? {
        let normalized = chiefComplaint.lowercased()
        
        // Direct matches
        if normalized.contains("chest pain") { return templates["chest_pain"] }
        if normalized.contains("abdominal pain") || normalized.contains("belly pain") { 
            return templates["abdominal_pain"] 
        }
        if normalized.contains("trauma") || normalized.contains("injury") || normalized.contains("fall") {
            return templates["trauma"]
        }
        if normalized.contains("confusion") || normalized.contains("altered") {
            return templates["altered_mental_status"]
        }
        
        return nil
    }
    
    /// Generate template-based documentation prompts
    static func generateDocumentationPrompts(template: ClinicalTemplate) -> [String] {
        var prompts: [String] = []
        
        prompts.append("=== REQUIRED DOCUMENTATION FOR \(template.name.uppercased()) ===\n")
        
        prompts.append("⚠️ CRITICAL ACTIONS:")
        for action in template.criticalActions {
            prompts.append("  □ \(action)")
        }
        
        prompts.append("\n📋 REQUIRED HISTORY ELEMENTS:")
        for element in template.requiredElements {
            prompts.append("  • \(element)")
        }
        
        prompts.append("\n🔍 PHYSICAL EXAM MUST INCLUDE:")
        for exam in template.physicalExamFocus {
            prompts.append("  • \(exam)")
        }
        
        prompts.append("\n🧪 STANDARD WORKUP:")
        for test in template.standardWorkup {
            prompts.append("  • \(test)")
        }
        
        return prompts
    }
    
    /// Validate documentation completeness
    static func validateDocumentation(
        note: String,
        template: ClinicalTemplate
    ) -> (isComplete: Bool, missingElements: [String]) {
        
        var missingElements: [String] = []
        let noteLower = note.lowercased()
        
        // Check for required elements
        for element in template.requiredElements {
            let keywords = element.lowercased().components(separatedBy: " ")
            var found = false
            
            for keyword in keywords {
                if noteLower.contains(keyword) {
                    found = true
                    break
                }
            }
            
            if !found {
                missingElements.append(element)
            }
        }
        
        // Check for physical exam elements
        for exam in template.physicalExamFocus {
            let keywords = exam.lowercased().components(separatedBy: " ")
            var found = false
            
            for keyword in keywords where keyword.count > 3 { // Skip short words
                if noteLower.contains(keyword) {
                    found = true
                    break
                }
            }
            
            if !found {
                missingElements.append("Physical exam: \(exam)")
            }
        }
        
        return (missingElements.isEmpty, missingElements)
    }
    
    /// Generate quality metrics for documentation
    static func generateQualityMetrics(note: String, template: ClinicalTemplate?) -> String {
        var metrics = "=== DOCUMENTATION QUALITY METRICS ===\n\n"
        
        // Word count
        let wordCount = note.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
        metrics += "📊 Word count: \(wordCount)"
        if wordCount < 100 {
            metrics += " ⚠️ (Brief - consider adding more detail)"
        } else if wordCount > 500 {
            metrics += " ✅ (Comprehensive)"
        } else {
            metrics += " ✓ (Adequate)"
        }
        metrics += "\n"
        
        // Check for medical terminology usage
        let medicalTerms = [
            "bilateral", "auscultation", "palpation", "tenderness",
            "differential", "etiology", "exacerbation", "acute", "chronic",
            "proximal", "distal", "lateral", "medial", "posterior", "anterior"
        ]
        
        var termCount = 0
        for term in medicalTerms {
            if note.lowercased().contains(term) {
                termCount += 1
            }
        }
        
        metrics += "🏥 Medical terminology: \(termCount)/\(medicalTerms.count) terms used"
        if termCount > 8 {
            metrics += " ✅ (Professional)"
        } else if termCount > 4 {
            metrics += " ✓ (Good)"
        } else {
            metrics += " ⚠️ (Consider using more medical terminology)"
        }
        metrics += "\n"
        
        // Check for completeness if template provided
        if let template = template {
            let validation = validateDocumentation(note: note, template: template)
            metrics += "✅ Completeness: "
            if validation.isComplete {
                metrics += "All required elements present ✅"
            } else {
                metrics += "\(template.requiredElements.count - validation.missingElements.count)/\(template.requiredElements.count) elements documented"
                if !validation.missingElements.isEmpty {
                    metrics += "\n   Missing: \(validation.missingElements.prefix(3).joined(separator: ", "))"
                    if validation.missingElements.count > 3 {
                        metrics += " and \(validation.missingElements.count - 3) more"
                    }
                }
            }
        }
        
        return metrics
    }
}