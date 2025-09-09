import Foundation
import Combine

// MARK: - Enhanced Medical Summarizer with Improved AI Terminology
@MainActor
final class EnhancedMedicalSummarizerService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = EnhancedMedicalSummarizerService()
    
    // MARK: - Published Properties
    @Published var isGenerating = false
    @Published var generatedNote = ""
    @Published var statusMessage = "Ready"
    @Published var progress: Double = 0.0
    @Published var audioQuality: Float = 0.0
    @Published var overallQualityScore: Float = 0.0
    
    // MARK: - Bayesian Clinical Intelligence
    @Published var clinicalReasoner = BayesianClinicalReasoner()
    
    // MARK: - Private Properties
    private var phi3Service: Phi3MLXService?
    private let medicalTerminologyEngine = MedicalTerminologyEngine()
    private let clinicalReasoning = ClinicalReasoningEngine()
    
    init() {
        phi3Service = Phi3MLXService.shared
    }
    
    // MARK: - Enhanced Medical Note Generation with Advanced AI
    func generateEnhancedMedicalNote(
        from transcription: String,
        noteType: NoteType,
        customInstructions: String = "",
        encounterID: String = "",
        phase: EncounterPhase = .initial
    ) async {
        
        guard !transcription.isEmpty else {
            statusMessage = "Error: No transcription to analyze"
            return
        }
        
        isGenerating = true
        statusMessage = "Applying optimizations..."
        progress = 0.2
        
        // Apply free optimizations
        let optimizedTranscription = applyFreeOptimizations(to: transcription)
        
        statusMessage = "Generating enhanced medical note with AI..."
        progress = 0.3
        
        // Use enhanced Phi-3 AI with medical terminology optimization
        if let phi3Service = phi3Service, phi3Service.modelStatus.isReady {
            statusMessage = "Using enhanced Phi-3 AI model..."
            progress = 0.5
            
            let enhancedPrompt = buildEnhancedMedicalPrompt(
                transcription: optimizedTranscription,
                noteType: noteType,
                encounterID: encounterID,
                phase: phase,
                customInstructions: customInstructions
            )
            
            let aiGeneratedNote = await phi3Service.generateEDSmartSummary(
                from: enhancedPrompt,
                encounterID: encounterID,
                phase: phase,
                customInstructions: customInstructions
            )
            
            // Post-process with medical terminology enhancement
            generatedNote = medicalTerminologyEngine.enhanceNote(aiGeneratedNote)
            
            // Score the generated summary for quality
            let qualityMetrics = scoreGeneratedSummary(generatedNote, noteType: noteType)
            let qualityPercentage = Int(qualityMetrics.overallScore * 100)
            
            progress = 1.0
            statusMessage = "Enhanced medical note generated successfully (Quality: \(qualityPercentage)%)"
        } else {
            // Fallback to enhanced ED Smart-Summary processing
            statusMessage = "Using enhanced ED Smart-Summary analysis..."
            let processedNote = generateEnhancedEDSmartSummary(
                transcription: optimizedTranscription,
                encounterID: encounterID,
                phase: phase
            )
            
            generatedNote = processedNote
            progress = 1.0
            statusMessage = "Enhanced ED Smart-Summary generated"
        }
        
        isGenerating = false
    }
    
    // MARK: - Generate Real Medical Note (No Fake Data)
    func generateRealMedicalNote(
        from transcription: String,
        noteType: NoteType
    ) async {
        guard !transcription.isEmpty else {
            statusMessage = "Error: No transcription to analyze"
            return
        }
        
        isGenerating = true
        statusMessage = "Analyzing with Bayesian clinical reasoning..."
        progress = 0.1
        
        // REVOLUTIONARY: Use Bayesian clinical reasoning
        await clinicalReasoner.processConversationSegment(transcription)
        progress = 0.4
        statusMessage = "Generating evidence-based clinical note..."
        
        // Generate note with clinical intelligence
        let intelligentNote = generateClinicallyIntelligentNote(
            transcription: transcription,
            hypotheses: clinicalReasoner.currentHypotheses,
            evidence: clinicalReasoner.evidenceChain,
            alerts: clinicalReasoner.clinicalAlerts,
            noteType: noteType
        )
        progress = 0.8
        
        // Fallback to OLDCARTS if clinical reasoning fails
        let soapNote = intelligentNote.isEmpty ? 
            OLDCARTSAnalyzer.generateSOAPNote(from: transcription) : intelligentNote
        
        if !soapNote.isEmpty {
            generatedNote = soapNote
            statusMessage = "Generated using human scribe methodology (OLDCARTS)"
        } else {
            // Fallback to pattern-based extraction
            // Apply advanced human scribe patterns first
            let advancedText = AdvancedHumanScribePatterns.applyAdvancedPatterns(to: transcription)
            let realData = RealConversationAnalyzer.analyzeRealConversation(advancedText)
            
            statusMessage = "Generating medical note from real data..."
            progress = 0.7
            
            // Generate note using ONLY real conversation data
            generatedNote = realData.generateSOAPNote()
        
        progress = 1.0
        statusMessage = "Real medical note generated successfully"
        isGenerating = false
    }
    
    // MARK: - Live Transcription Processing (for ProductionWhisperService)
    func processTranscriptionSegment(
        _ text: String,
        confidence: Float,
        audioQuality: Float
    ) async {
        // For live transcription, we accumulate segments and update the current working note
        // This is called from ProductionWhisperService during live recording
        
        statusMessage = "Processing live transcription segment..."
        
        // Use real conversation analysis for the segment
        // Apply advanced human scribe patterns first  
        let advancedText = AdvancedHumanScribePatterns.applyAdvancedPatterns(to: text)
        let realData = RealConversationAnalyzer.analyzeRealConversation(advancedText)
        
        // Generate or update the working note using real data only
        let segmentNote = realData.generateSOAPNote()
        
        // Update the generated note with this segment
        if generatedNote.isEmpty {
            generatedNote = segmentNote
        } else {
            // Append new information to existing note
            generatedNote += "\n\nLIVE UPDATE:\n" + segmentNote
        }
        
        statusMessage = "Live segment processed (Quality: \(Int(confidence * 100))%)"
    }
    
    // MARK: - Clinically Intelligent Note Generation
    private func generateClinicallyIntelligentNote(
        transcription: String,
        hypotheses: [MedicalHypothesis],
        evidence: [EvidenceItem],
        alerts: [ClinicalAlert],
        noteType: NoteType
    ) -> String {
        
        guard !transcription.isEmpty else { return "" }
        
        // Generate note with clinical intelligence
        var note = ""
        
        // Header with clinical intelligence indicators
        note += "# \(noteType.rawValue)\n"
        note += "Generated: \(Date().formatted(.dateTime.locale(.current)))\n"
        
        if !alerts.isEmpty {
            note += "⚠️ CLINICAL ALERTS: \(alerts.count) critical findings identified\n"
        }
        
        note += "\n"
        
        // Chief Complaint (extract from evidence)
        if let chiefComplaint = evidence.first(where: { $0.category == .chief_complaint }) {
            note += "**Chief Complaint:** \(chiefComplaint.finding)\n\n"
        } else {
            // Extract from transcription
            note += "**Chief Complaint:** \(extractChiefComplaintFromTranscription(transcription))\n\n"
        }
        
        // History of Present Illness with clinical reasoning
        note += "**History of Present Illness:**\n"
        note += extractEnhancedHPI(from: transcription)
        
        if !hypotheses.isEmpty {
            note += "\n\n**Clinical Reasoning:**\n"
            for hypothesis in hypotheses.prefix(3) {  // Top 3 hypotheses
                let percentage = Int(hypothesis.probability * 100)
                note += "• \(hypothesis.condition): \(percentage)% probability (\(hypothesis.probabilityDescription))\n"
                
                if !hypothesis.supportingEvidence.isEmpty {
                    note += "  - Supporting: \(hypothesis.supportingEvidence.map { $0.finding }.joined(separator: ", "))\n"
                }
                
                if hypothesis.urgencyLevel != .routine {
                    note += "  - Urgency: \(hypothesis.urgencyLevel.description)\n"
                }
            }
        }
        
        // Physical Examination
        note += "\n\n**Physical Examination:**\n"
        let physicalFindings = evidence.filter { $0.category == .physical_exam }
        if !physicalFindings.isEmpty {
            for finding in physicalFindings {
                note += "• \(finding.finding)\n"
            }
        } else {
            note += extractEnhancedPhysicalExam(from: transcription).map { key, value in
                "• \(key): \(value)"
            }.joined(separator: "\n")
        }
        
        // Assessment and Plan with clinical intelligence
        note += "\n\n**Assessment and Plan:**\n"
        
        if !hypotheses.isEmpty {
            for (index, hypothesis) in hypotheses.prefix(3).enumerated() {
                note += "\(index + 1). **\(hypothesis.condition)** (\(Int(hypothesis.probability * 100))% probability)\n"
                
                if !hypothesis.requiredWorkup.isEmpty {
                    note += "   - Workup: \(hypothesis.requiredWorkup.map { $0.action }.joined(separator: ", "))\n"
                }
                
                if let icd10 = hypothesis.icd10Code {
                    note += "   - ICD-10: \(icd10)\n"
                }
                
                note += "\n"
            }
        } else {
            // Fallback to traditional assessment extraction
            let assessments = extractEnhancedAssessment(from: transcription)
            for assessment in assessments {
                note += "• \(assessment)\n"
            }
        }
        
        // Critical Alerts Section
        if !alerts.isEmpty {
            note += "\n**🚨 CRITICAL ALERTS:**\n"
            for alert in alerts {
                note += "• **\(alert.condition)** - \(alert.urgency.description)\n"
                note += "  - Time to action: \(alert.formattedTimeToAction)\n"
                note += "  - Actions: \(alert.recommendedActions.joined(separator: ", "))\n\n"
            }
        }
        
        // Quality and Documentation Guidance
        let qualityScore = Int(clinicalReasoner.qualityScore * 100)
        note += "\n---\n"
        note += "**Documentation Quality:** \(qualityScore)%\n"
        
        if !clinicalReasoner.documentationGuidance.isEmpty {
            note += "**Documentation Guidance:**\n"
            for guidance in clinicalReasoner.documentationGuidance.prefix(3) {
                note += "• \(guidance.title): \(guidance.suggestion)\n"
            }
        }
        
        return note
    }
    
    private func extractChiefComplaintFromTranscription(_ transcription: String) -> String {
        let text = transcription.lowercased()
        
        // Look for chief complaint patterns
        if text.contains("chief complaint") || text.contains("cc:") {
            // Extract the complaint after the pattern
            if let range = text.range(of: "chief complaint:") ?? text.range(of: "cc:") {
                let afterCC = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return String(afterCC.prefix(100))
            }
        }
        
        // Look for common complaint patterns
        let complaintPatterns = [
            "presents with", "complains of", "c/o", "reports", "states"
        ]
        
        for pattern in complaintPatterns {
            if let range = text.range(of: pattern) {
                let afterPattern = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let firstSentence = afterPattern.components(separatedBy: ".").first ?? ""
                return String(firstSentence.prefix(100))
            }
        }
        
        // Default: use first sentence as chief complaint
        let firstSentence = transcription.components(separatedBy: ".").first ?? transcription
        return String(firstSentence.prefix(100))
    }
    
    // MARK: - Enhanced Prompt Building with Medical Best Practices
    private func buildEnhancedMedicalPrompt(
        transcription: String,
        noteType: NoteType,
        encounterID: String,
        phase: EncounterPhase,
        customInstructions: String
    ) -> String {
        
        let systemPrompt = """
        You are an expert emergency medicine physician with subspecialty training in critical care and clinical documentation.
        Generate professional medical documentation following evidence-based guidelines and current best practices.
        
        CLINICAL DOCUMENTATION STANDARDS:
        1. Use precise medical terminology (ICD-10/CPT compatible)
        2. Follow SOAP/H&P format with proper medical abbreviations
        3. Include pertinent positives AND negatives for completeness
        4. Document clinical decision-making with evidence-based reasoning
        5. Risk-stratify using validated clinical decision rules (HEART, Wells, PERC, etc.)
        6. Include time-stamps for critical interventions
        7. Document medical decision-making (MDM) complexity
        
        EMERGENCY MEDICINE PRIORITIES:
        - ABCs (Airway, Breathing, Circulation) assessment
        - Red flag symptoms requiring immediate intervention
        - Time-sensitive diagnoses (STEMI, stroke, sepsis)
        - Risk stratification using validated scoring systems
        - Disposition planning with clear follow-up instructions
        
        CLINICAL TERMINOLOGY REQUIREMENTS:
        - Use standard medical abbreviations (SOB, CP, N/V, etc.)
        - Include relevant vital sign trends if mentioned
        - Document pertinent physical exam findings using proper terminology
        - Use evidence-based differential diagnosis reasoning
        - Include relevant clinical decision rules and risk scores
        
        QUALITY METRICS:
        - Core measures compliance (door-to-balloon, antibiotics timing)
        - Appropriate use criteria for imaging
        - Pain management documentation
        - Fall risk and suicide screening when applicable
        """
        
        let phaseSpecificInstructions = getPhaseSpecificInstructions(phase: phase)
        let noteTypeTemplate = getNoteTypeTemplate(noteType: noteType)
        
        return """
        \(systemPrompt)
        
        \(phaseSpecificInstructions)
        
        \(noteTypeTemplate)
        
        ENCOUNTER DETAILS:
        - Encounter ID: \(encounterID)
        - Documentation Phase: \(phase)
        - Custom Requirements: \(customInstructions.isEmpty ? "Standard ED documentation" : customInstructions)
        
        CLINICAL CONVERSATION TO ANALYZE:
        \(transcription)
        
        GENERATE PROFESSIONAL MEDICAL DOCUMENTATION:
        """
    }
    
    // MARK: - Phase-Specific Instructions
    private func getPhaseSpecificInstructions(phase: EncounterPhase) -> String {
        switch phase {
        case .initial:
            return """
            INITIAL ENCOUNTER DOCUMENTATION:
            Focus on:
            - Chief complaint with symptom onset and duration
            - Comprehensive HPI using OPQRST (Onset, Provocation, Quality, Radiation, Severity, Time)
            - Review of systems (10-point ROS for billing compliance)
            - Pertinent past medical/surgical history
            - Current medications and allergies
            - Initial clinical impression and differential diagnosis
            - Planned diagnostic workup
            """
            
        case .followUp:
            return """
            RE-EVALUATION DOCUMENTATION:
            Focus on:
            - Interval history since initial evaluation
            - Response to treatments administered
            - Results interpretation (labs, imaging, EKG)
            - Updated clinical assessment
            - Medical decision-making with risk-benefit analysis
            - Final diagnosis or working diagnosis
            - Disposition planning with specific follow-up instructions
            - Return precautions and patient education
            """
        }
    }
    
    // MARK: - Note Type Templates
    private func getNoteTypeTemplate(noteType: NoteType) -> String {
        switch noteType {
        case .edNote:
            return """
            ED NOTE FORMAT:
            
            CHIEF COMPLAINT:
            - Primary presenting concern
            
            HISTORY OF PRESENT ILLNESS:
            - Onset, location, duration, character, aggravating/alleviating factors
            - Associated symptoms
            - Relevant negatives
            
            PAST MEDICAL/SURGICAL HISTORY:
            - Chronic conditions
            - Previous surgeries
            
            MEDICATIONS & ALLERGIES:
            - Current medications
            - Drug allergies/reactions
            
            PHYSICAL EXAMINATION:
            - Vital signs
            - General appearance
            - System-specific findings
            
            ASSESSMENT & PLAN:
            - Working diagnosis
            - Differential diagnosis
            - Diagnostic workup
            - Treatment plan
            - Disposition
            """
            
        case .soap:
            return """
            SOAP NOTE FORMAT:
            
            SUBJECTIVE:
            - Chief Complaint: [specific clinical presentation]
            - HPI: [detailed narrative using OPQRST framework]
            - ROS: [comprehensive system review]
            - PMH/PSH: [relevant medical/surgical history]
            - Medications: [current medication list]
            - Allergies: [documented allergies with reactions]
            - Social: [relevant social history including risk factors]
            
            OBJECTIVE:
            - Vital Signs: [if mentioned in conversation]
            - Physical Exam: [pertinent findings by system]
            - Diagnostic Results: [labs, imaging, EKG findings if discussed]
            
            ASSESSMENT:
            - Clinical Summary: [synthesis of findings]
            - Differential Diagnosis: [prioritized with clinical reasoning]
            - Risk Stratification: [using validated tools]
            - Medical Decision-Making: [complexity and thought process]
            
            PLAN:
            - Diagnostic: [ordered tests with indications]
            - Therapeutic: [treatments with dosing]
            - Disposition: [admission/discharge with criteria]
            - Follow-up: [specific instructions and timeframe]
            - Patient Education: [documented teaching]
            """
            
        case .progress:
            return """
            PROGRESS NOTE FORMAT:
            
            INTERVAL HISTORY:
            - Changes since last evaluation
            - Response to interventions
            - New symptoms or concerns
            
            CLINICAL UPDATE:
            - Current status and trajectory
            - Diagnostic results review
            - Treatment response assessment
            
            ASSESSMENT & PLAN:
            - Updated differential diagnosis
            - Continued management strategy
            - Disposition planning
            """
            
        case .consult:
            return """
            CONSULTATION NOTE FORMAT:
            
            REASON FOR CONSULTATION:
            - Specific clinical question
            - Urgency of consultation
            
            CONSULTANT'S ASSESSMENT:
            - Independent history and exam
            - Review of available data
            - Clinical interpretation
            
            RECOMMENDATIONS:
            - Diagnostic suggestions
            - Treatment recommendations
            - Follow-up plan
            """
            
        case .handoff:
            return """
            HANDOFF COMMUNICATION (SBAR):
            
            SITUATION:
            - Patient identification
            - Chief complaint and working diagnosis
            - Current clinical status
            
            BACKGROUND:
            - Relevant history
            - Treatments administered
            - Response to interventions
            
            ASSESSMENT:
            - Current clinical picture
            - Pending results/consults
            - Anticipated trajectory
            
            RECOMMENDATION:
            - Immediate action items
            - Contingency planning
            - Follow-up requirements
            """
            
        case .discharge:
            return """
            DISCHARGE SUMMARY FORMAT:
            
            ADMISSION DIAGNOSIS:
            - Presenting complaint
            - Initial clinical assessment
            
            HOSPITAL COURSE:
            - Key interventions and response
            - Significant findings
            - Consultations obtained
            
            DISCHARGE DIAGNOSIS:
            - Final or working diagnosis
            - Secondary diagnoses
            
            DISCHARGE INSTRUCTIONS:
            - Medications (new and continued)
            - Activity restrictions
            - Diet recommendations
            - Follow-up appointments
            - Return precautions (specific red flags)
            - Patient education provided
            """
        }
    }
    
    // MARK: - Enhanced ED Smart Summary Generation
    private func generateEnhancedEDSmartSummary(
        transcription: String,
        encounterID: String,
        phase: EncounterPhase
    ) -> String {
        
        let clinicalData = extractEnhancedClinicalData(
            from: transcription,
            phase: phase
        )
        
        let structuredSummary = structureEnhancedSummary(
            data: clinicalData,
            encounterID: encounterID,
            phase: phase
        )
        
        return formatEnhancedOutput(summary: structuredSummary)
    }
    
    // MARK: - Enhanced Clinical Data Extraction
    private func extractEnhancedClinicalData(
        from transcription: String,
        phase: EncounterPhase
    ) -> EnhancedClinicalData {
        
        let text = transcription.lowercased()
        
        return EnhancedClinicalData(
            chiefComplaint: extractEnhancedChiefComplaint(from: text),
            hpi: extractEnhancedHPI(from: transcription),
            ros: extractEnhancedROS(from: text),
            physicalExam: extractEnhancedPhysicalExam(from: text),
            assessment: extractEnhancedAssessment(from: text),
            mdm: extractEnhancedMDM(from: text),
            plan: extractEnhancedPlan(from: text),
            disposition: extractEnhancedDisposition(from: text)
        )
    }
    
    // MARK: - Enhanced Extraction Methods with Medical Terminology
    
    private func extractEnhancedChiefComplaint(from text: String) -> String {
        var complaints: [String] = []
        
        // Cardiovascular complaints
        if text.contains("chest") {
            if text.contains("pressure") || text.contains("tightness") {
                complaints.append("Chest pressure/tightness concerning for ACS")
            } else if text.contains("pain") {
                if text.contains("sharp") {
                    complaints.append("Sharp chest pain - consider pleuritic vs MSK etiology")
                } else if text.contains("crushing") {
                    complaints.append("Crushing chest pain - high concern for ACS")
                } else {
                    complaints.append("Chest pain, unspecified character")
                }
            }
        }
        
        // Respiratory complaints
        if text.contains("shortness") || text.contains("breath") || text.contains("dyspnea") {
            if text.contains("acute") || text.contains("sudden") {
                complaints.append("Acute dyspnea - evaluate for PE, pneumothorax")
            } else {
                complaints.append("Dyspnea on exertion")
            }
        }
        
        // Neurological complaints
        if text.contains("headache") || text.contains("cephalgia") {
            if text.contains("thunderclap") || text.contains("worst") {
                complaints.append("Thunderclap headache - concern for SAH")
            } else if text.contains("migraine") {
                complaints.append("Migraine-type headache")
            } else {
                complaints.append("Cephalgia")
            }
        }
        
        return complaints.isEmpty ? "Unspecified complaint" : complaints.joined(separator: "; ")
    }
    
    // MARK: - Helper Methods
    private func extractTiming(from text: String) -> String? {
        let timingPatterns = [
            "\\\\d+ hours? ago",
            "\\\\d+ days? ago",
            "\\\\d+ weeks? ago",
            "\\\\d+ minutes? ago",
            "this morning",
            "yesterday",
            "last night",
            "last week"
        ]
        
        for pattern in timingPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                return String(text[range])
            }
        }
        
        return nil
    }
    
    private func extractEnhancedHPI(from transcription: String) -> String {
        let text = transcription.lowercased()
        var hpiElements: [String] = []
        
        // Onset and timing
        let onsetPatterns = [
            "sudden onset": "Acute/sudden onset",
            "gradual": "Gradual onset",
            "\\\\d+ hours? ago": "Onset $0",
            "\\\\d+ days? ago": "Onset $0",
            "this morning": "Onset this morning",
            "last night": "Onset last night"
        ]
        
        for (pattern, description) in onsetPatterns {
            if let range = text.range(of: pattern, options: .regularExpression) {
                hpiElements.append(description.replacingOccurrences(of: "$0", with: String(text[range])))
                break
            }
        }
        
        // Quality descriptors
        let qualityTerms = [
            "sharp": "Sharp/stabbing quality",
            "dull": "Dull/aching quality",
            "burning": "Burning sensation",
            "pressure": "Pressure-like sensation",
            "crushing": "Crushing quality (concerning for cardiac)",
            "tearing": "Tearing sensation (concern for dissection)",
            "colicky": "Colicky/cramping quality"
        ]
        
        for (term, description) in qualityTerms {
            if text.contains(term) {
                hpiElements.append(description)
            }
        }
        
        // Associated symptoms
        let associatedSymptoms = [
            "nausea": "Associated nausea",
            "vomiting": "Associated emesis",
            "diaphoresis": "Associated diaphoresis",
            "syncope": "Associated syncope/presyncope",
            "palpitations": "Associated palpitations",
            "fever": "Associated fever/chills",
            "dizziness": "Associated dizziness/vertigo"
        ]
        
        for (symptom, description) in associatedSymptoms {
            if text.contains(symptom) {
                hpiElements.append(description)
            }
        }
        
        // Aggravating/Alleviating factors
        if text.contains("worse with") {
            if text.contains("movement") || text.contains("walking") {
                hpiElements.append("Exacerbated by physical activity")
            }
            if text.contains("breathing") || text.contains("inspiration") {
                hpiElements.append("Pleuritic component (worse with inspiration)")
            }
        }
        
        if text.contains("better with") || text.contains("relieved by") {
            if text.contains("rest") {
                hpiElements.append("Improved with rest")
            }
            if text.contains("nitroglycerin") || text.contains("nitro") {
                hpiElements.append("Nitro-responsive (suggests cardiac etiology)")
            }
        }
        
        return hpiElements.isEmpty ? "Limited history obtained" : hpiElements.joined(separator: ". ")
    }
    
    private func extractEnhancedROS(from text: String) -> [String: [String]] {
        var ros: [String: [String]] = [:]
        
        // Constitutional
        var constitutional: [String] = []
        if text.contains("fever") { constitutional.append("Fever") }
        if text.contains("chills") { constitutional.append("Chills") }
        if text.contains("weight loss") { constitutional.append("Weight loss") }
        if text.contains("fatigue") { constitutional.append("Fatigue") }
        if !constitutional.isEmpty { ros["Constitutional"] = constitutional }
        
        // Cardiovascular
        var cardiovascular: [String] = []
        if text.contains("chest pain") { cardiovascular.append("Chest pain") }
        if text.contains("palpitations") { cardiovascular.append("Palpitations") }
        if text.contains("edema") { cardiovascular.append("Peripheral edema") }
        if text.contains("orthopnea") { cardiovascular.append("Orthopnea") }
        if text.contains("pnd") || text.contains("paroxysmal nocturnal") {
            cardiovascular.append("PND")
        }
        if !cardiovascular.isEmpty { ros["Cardiovascular"] = cardiovascular }
        
        // Respiratory
        var respiratory: [String] = []
        if text.contains("cough") { respiratory.append("Cough") }
        if text.contains("sputum") { respiratory.append("Sputum production") }
        if text.contains("hemoptysis") { respiratory.append("Hemoptysis") }
        if text.contains("wheezing") { respiratory.append("Wheezing") }
        if text.contains("dyspnea") || text.contains("shortness") {
            respiratory.append("Dyspnea")
        }
        if !respiratory.isEmpty { ros["Respiratory"] = respiratory }
        
        // Gastrointestinal
        var gi: [String] = []
        if text.contains("nausea") { gi.append("Nausea") }
        if text.contains("vomiting") { gi.append("Vomiting") }
        if text.contains("diarrhea") { gi.append("Diarrhea") }
        if text.contains("constipation") { gi.append("Constipation") }
        if text.contains("melena") { gi.append("Melena") }
        if text.contains("hematochezia") { gi.append("Hematochezia") }
        if !gi.isEmpty { ros["Gastrointestinal"] = gi }
        
        // Neurological
        var neuro: [String] = []
        if text.contains("headache") { neuro.append("Headache") }
        if text.contains("dizziness") { neuro.append("Dizziness") }
        if text.contains("syncope") { neuro.append("Syncope") }
        if text.contains("weakness") { neuro.append("Focal weakness") }
        if text.contains("numbness") { neuro.append("Numbness/paresthesias") }
        if text.contains("seizure") { neuro.append("Seizure") }
        if !neuro.isEmpty { ros["Neurological"] = neuro }
        
        return ros
    }
    
    private func extractEnhancedPhysicalExam(from text: String) -> [String: String] {
        var exam: [String: String] = [:]
        
        // Only extract if explicitly mentioned as exam findings
        if text.contains("exam") || text.contains("physical") || text.contains("on examination") {
            
            if text.contains("tender") {
                if text.contains("chest") {
                    exam["Chest"] = "Chest wall tenderness to palpation"
                }
                if text.contains("abdomen") {
                    exam["Abdomen"] = "Abdominal tenderness"
                }
            }
            
            if text.contains("clear") && text.contains("lung") {
                exam["Lungs"] = "Clear to auscultation bilaterally"
            }
            
            if text.contains("regular") && (text.contains("rhythm") || text.contains("rate")) {
                exam["Cardiovascular"] = "Regular rate and rhythm"
            }
        }
        
        return exam
    }
    
    private func extractEnhancedAssessment(from text: String) -> [String] {
        var assessment: [String] = []
        
        // Look for differential diagnosis keywords
        let ddxKeywords = [
            "consider", "concerning for", "evaluate for", "rule out",
            "differential includes", "could be", "possibly", "likely"
        ]
        
        for keyword in ddxKeywords {
            if text.contains(keyword) {
                // Extract specific diagnoses mentioned
                if text.contains("acs") || text.contains("acute coronary") {
                    assessment.append("Acute coronary syndrome")
                }
                if text.contains("pulmonary embolism") || text.contains(" pe ") {
                    assessment.append("Pulmonary embolism")
                }
                if text.contains("pneumonia") {
                    assessment.append("Community-acquired pneumonia")
                }
                if text.contains("chf") || text.contains("heart failure") {
                    assessment.append("Acute decompensated heart failure")
                }
                if text.contains("dissection") {
                    assessment.append("Aortic dissection")
                }
                break
            }
        }
        
        return assessment
    }
    
    private func extractEnhancedMDM(from text: String) -> MDMContent {
        var ddx: [String] = []
        var reasoning = ""
        var riskStratification = ""
        var plan = ""
        
        // Extract differential diagnosis with clinical reasoning
        if text.contains("differential") || text.contains("consider") {
            if text.contains("cardiac") || text.contains("acs") {
                ddx.append("ACS - given chest pain with cardiac risk factors")
            }
            if text.contains("pe") || text.contains("embolism") {
                ddx.append("PE - based on dyspnea and pleuritic pain")
            }
            if text.contains("pneumonia") {
                ddx.append("Pneumonia - considering fever and productive cough")
            }
        }
        
        // Risk stratification
        if text.contains("high risk") {
            riskStratification = "High-risk features present requiring aggressive workup"
        } else if text.contains("low risk") {
            riskStratification = "Low-risk presentation per validated criteria"
        }
        
        // Clinical reasoning
        if text.contains("concerning") || text.contains("worried") {
            reasoning = "Clinical presentation concerning for time-sensitive diagnosis requiring immediate evaluation"
        }
        
        // Diagnostic plan
        var diagnostics: [String] = []
        if text.contains("ekg") || text.contains("ecg") {
            diagnostics.append("EKG to evaluate for ischemic changes")
        }
        if text.contains("troponin") {
            diagnostics.append("High-sensitivity troponin")
        }
        if text.contains("d-dimer") {
            diagnostics.append("D-dimer if low-risk for PE")
        }
        if text.contains("ct") || text.contains("cta") {
            diagnostics.append("CTA chest for PE protocol")
        }
        if text.contains("chest x-ray") || text.contains("cxr") {
            diagnostics.append("CXR to evaluate for pneumonia/pneumothorax")
        }
        
        if !diagnostics.isEmpty {
            plan = diagnostics.joined(separator: ", ")
        }
        
        return MDMContent(
            ddx: ddx.isEmpty ? nil : ddx,
            clinicalReasoning: reasoning.isEmpty ? nil : reasoning,
            plan: plan.isEmpty ? nil : plan
        )
    }
    
    private func extractEnhancedPlan(from text: String) -> [String] {
        var planItems: [String] = []
        
        // Diagnostic workup
        if text.contains("order") || text.contains("get") || text.contains("check") {
            if text.contains("labs") {
                planItems.append("Comprehensive metabolic panel, CBC with differential")
            }
            if text.contains("cardiac") {
                planItems.append("Cardiac biomarkers (troponin, BNP)")
            }
            if text.contains("blood cultures") {
                planItems.append("Blood cultures x2 if febrile")
            }
        }
        
        // Therapeutic interventions
        if text.contains("give") || text.contains("administer") {
            if text.contains("aspirin") {
                planItems.append("Aspirin 325mg PO for ACS protocol")
            }
            if text.contains("nitroglycerin") {
                planItems.append("Nitroglycerin SL PRN chest pain")
            }
            if text.contains("heparin") {
                planItems.append("Heparin per ACS protocol")
            }
            if text.contains("antibiotics") {
                planItems.append("Empiric antibiotics for suspected infection")
            }
        }
        
        // Consultations
        if text.contains("consult") || text.contains("call") {
            if text.contains("cardiology") {
                planItems.append("Cardiology consultation for ACS management")
            }
            if text.contains("surgery") {
                planItems.append("Surgical consultation")
            }
        }
        
        return planItems
    }
    
    private func extractEnhancedDisposition(from text: String) -> String {
        if text.contains("admit") {
            if text.contains("icu") || text.contains("intensive") {
                return "Admit to ICU for critical care monitoring"
            } else if text.contains("telemetry") {
                return "Admit to telemetry for cardiac monitoring"
            } else {
                return "Admit to medicine service"
            }
        } else if text.contains("observation") {
            return "Observation status for serial assessments"
        } else if text.contains("discharge") {
            var dischargeDetails = "Discharge home"
            if text.contains("follow") {
                if text.contains("pcp") || text.contains("primary") {
                    dischargeDetails += " with PCP follow-up in 24-48 hours"
                }
                if text.contains("cardiology") {
                    dischargeDetails += " with cardiology follow-up"
                }
            }
            return dischargeDetails
        } else if text.contains("transfer") {
            return "Transfer to higher level of care"
        }
        
        return "Disposition pending"
    }
    
    // MARK: - Output Formatting
    private func formatEnhancedOutput(summary: StructuredSummary) -> String {
        var output = "# ENHANCED MEDICAL SUMMARY\n\n"
        
        output += "## ENCOUNTER INFORMATION\n"
        output += "- Encounter ID: \(summary.encounterID)\n"
        output += "- Phase: \(summary.phase)\n"
        output += "- Generated: \(Date().ISO8601Format())\n\n"
        
        output += "## CLINICAL SUMMARY\n\n"
        
        if let cc = summary.chiefComplaint {
            output += "**Chief Complaint:** \(cc)\n\n"
        }
        
        if let hpi = summary.hpi {
            output += "**History of Present Illness:**\n\(hpi)\n\n"
        }
        
        if let ros = summary.ros, !ros.isEmpty {
            output += "**Review of Systems:**\n"
            for (system, symptoms) in ros {
                output += "- \(system): \(symptoms.joined(separator: ", "))\n"
            }
            output += "\n"
        }
        
        if let exam = summary.physicalExam, !exam.isEmpty {
            output += "**Physical Examination:**\n"
            for (system, findings) in exam {
                output += "- \(system): \(findings)\n"
            }
            output += "\n"
        }
        
        if let assessment = summary.assessment, !assessment.isEmpty {
            output += "**Assessment:**\n"
            for (index, diagnosis) in assessment.enumerated() {
                output += "\(index + 1). \(diagnosis)\n"
            }
            output += "\n"
        }
        
        if let mdm = summary.mdm {
            output += "**Medical Decision Making:**\n"
            if let ddx = mdm.ddx {
                output += "Differential Diagnosis:\n"
                for diagnosis in ddx {
                    output += "- \(diagnosis)\n"
                }
            }
            if let reasoning = mdm.clinicalReasoning {
                output += "\nClinical Reasoning: \(reasoning)\n"
            }
            if let plan = mdm.plan {
                output += "\nDiagnostic Plan: \(plan)\n"
            }
            output += "\n"
        }
        
        if let plan = summary.plan, !plan.isEmpty {
            output += "**Plan:**\n"
            for item in plan {
                output += "- \(item)\n"
            }
            output += "\n"
        }
        
        if let disposition = summary.disposition {
            output += "**Disposition:** \(disposition)\n\n"
        }
        
        // Add JSON format for EHR integration
        output += "## JSON OUTPUT FOR EHR INTEGRATION\n"
        output += "```json\n"
        output += formatAsJSON(summary: summary)
        output += "\n```\n"
        
        return output
    }
    
    private func formatAsJSON(summary: StructuredSummary) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        if let jsonData = try? encoder.encode(summary),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"error\": \"Failed to encode summary\"}"
    }
    
    private func structureEnhancedSummary(
        data: EnhancedClinicalData,
        encounterID: String,
        phase: EncounterPhase
    ) -> StructuredSummary {
        return StructuredSummary(
            encounterID: encounterID,
            phase: phase,
            chiefComplaint: data.chiefComplaint,
            hpi: data.hpi,
            ros: data.ros,
            physicalExam: data.physicalExam,
            assessment: data.assessment,
            mdm: data.mdm,
            plan: data.plan,
            disposition: data.disposition
        )
    }
}

// MARK: - Supporting Structures
struct EnhancedClinicalData {
    let chiefComplaint: String
    let hpi: String
    let ros: [String: [String]]
    let physicalExam: [String: String]
    let assessment: [String]
    let mdm: MDMContent
    let plan: [String]
    let disposition: String
}

struct StructuredSummary: Codable {
    let encounterID: String
    let phase: EncounterPhase
    let chiefComplaint: String?
    let hpi: String?
    let ros: [String: [String]]?
    let physicalExam: [String: String]?
    let assessment: [String]?
    let mdm: MDMContent?
    let plan: [String]?
    let disposition: String?
}

// MARK: - Medical Terminology Engine
class MedicalTerminologyEngine {
    
    private let medicalAbbreviations = [
        "chest pain": "CP",
        "shortness of breath": "SOB",
        "blood pressure": "BP",
        "heart rate": "HR",
        "emergency department": "ED",
        "acute coronary syndrome": "ACS",
        "pulmonary embolism": "PE",
        "myocardial infarction": "MI",
        "congestive heart failure": "CHF",
        "chronic obstructive pulmonary disease": "COPD",
        "computed tomography": "CT",
        "electrocardiogram": "EKG",
        "complete blood count": "CBC",
        "basic metabolic panel": "BMP",
        "comprehensive metabolic panel": "CMP"
    ]
    
    private let clinicalTermUpgrades = [
        "heart attack": "myocardial infarction",
        "blood clot": "thromboembolism",
        "high blood pressure": "hypertension",
        "sugar diabetes": "diabetes mellitus",
        "mini stroke": "transient ischemic attack (TIA)",
        "water pills": "diuretics",
        "blood thinners": "anticoagulants",
        "pain killers": "analgesics",
        "breathing problems": "respiratory distress",
        "fast heart rate": "tachycardia",
        "slow heart rate": "bradycardia",
        "irregular heartbeat": "arrhythmia"
    ]
    
    func enhanceNote(_ note: String) -> String {
        var enhancedNote = note
        
        // Apply clinical term upgrades
        for (colloquial, medical) in clinicalTermUpgrades {
            enhancedNote = enhancedNote.replacingOccurrences(
                of: colloquial,
                with: medical,
                options: [.caseInsensitive]
            )
        }
        
        // Apply appropriate abbreviations in clinical context
        // Only abbreviate in lists or after first use
        for (full, abbrev) in medicalAbbreviations {
            let pattern = "\\b\(full)\\b(?=.*\\b\(full)\\b)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(location: 0, length: enhancedNote.utf16.count)
                enhancedNote = regex.stringByReplacingMatches(
                    in: enhancedNote,
                    options: [],
                    range: range,
                    withTemplate: "\(full) (\(abbrev))"
                )
            }
        }
        
        return enhancedNote
    }
}

// MARK: - Clinical Reasoning Engine
class ClinicalReasoningEngine {
    
    func generateClinicalReasoning(
        symptoms: [String],
        riskFactors: [String],
        examFindings: [String]
    ) -> String {
        
        var reasoning = "Clinical presentation suggests "
        
        // Analyze symptom patterns
        let hasCardiacSymptoms = symptoms.contains { $0.lowercased().contains("chest") || $0.lowercased().contains("cardiac") }
        let hasRespiratorySymptoms = symptoms.contains { $0.lowercased().contains("breath") || $0.lowercased().contains("cough") }
        let hasNeuroSymptoms = symptoms.contains { $0.lowercased().contains("headache") || $0.lowercased().contains("weakness") }
        
        // Generate reasoning based on patterns
        if hasCardiacSymptoms && !riskFactors.isEmpty {
            reasoning += "possible cardiac etiology given chest pain with \(riskFactors.count) cardiac risk factors. "
        }
        
        if hasRespiratorySymptoms {
            reasoning += "respiratory pathology requiring evaluation for infectious vs embolic causes. "
        }
        
        if hasNeuroSymptoms {
            reasoning += "neurological evaluation indicated to rule out central causes. "
        }
        
        // Add risk stratification
        if riskFactors.count >= 3 {
            reasoning += "High-risk presentation requiring expedited workup and close monitoring."
        } else if riskFactors.count >= 1 {
            reasoning += "Moderate risk profile necessitating systematic evaluation."
        } else {
            reasoning += "Low-risk features but vigilance maintained for occult pathology."
        }
        
        return reasoning
    }
}
