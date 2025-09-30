import Foundation

/// Detects life-threatening clinical presentations in medical transcripts
/// Provides automated red flag alerts for critical conditions requiring immediate attention
class ClinicalSafetyDetector {

    // MARK: - Red Flag Categories

    enum RedFlagCategory: String {
        case stemi = "STEMI (ST-Elevation Myocardial Infarction)"
        case stroke = "Acute Stroke"
        case subarachnoidHemorrhage = "Subarachnoid Hemorrhage"
        case aorticDissection = "Aortic Dissection"
        case pulmonaryEmbolism = "Pulmonary Embolism"
        case sepsis = "Severe Sepsis/Septic Shock"
        case rupturedAAA = "Ruptured Abdominal Aortic Aneurysm"
        case meningitis = "Bacterial Meningitis"
        case bowelPerforation = "Bowel Perforation/Peritonitis"
        case acuteAbdomen = "Acute Surgical Abdomen"
        case dka = "Diabetic Ketoacidosis"
        case anaphylaxis = "Anaphylaxis"
        case severeAsthma = "Status Asthmaticus"
        case giBleed = "Severe GI Bleeding"
        case seizure = "Status Epilepticus"
    }

    enum RedFlagSeverity {
        case critical   // Immediate life threat - activate code team
        case urgent     // Serious, needs rapid evaluation within minutes
        case warning    // Concerning, accelerated workup needed
    }

    // MARK: - Red Flag Structure

    struct RedFlag {
        let category: RedFlagCategory
        let severity: RedFlagSeverity
        let findings: [String]
        let recommendation: String
        let confidence: Double // 0.0 to 1.0
    }

    // MARK: - Main Detection Function

    static func detectRedFlags(in transcript: String) -> [RedFlag] {
        let text = transcript.lowercased()
        var redFlags: [RedFlag] = []

        // Check for each critical presentation
        if let stemiFlag = detectSTEMI(in: text) {
            redFlags.append(stemiFlag)
        }

        if let strokeFlag = detectStroke(in: text) {
            redFlags.append(strokeFlag)
        }

        if let sahFlag = detectSAH(in: text) {
            redFlags.append(sahFlag)
        }

        if let aorticFlag = detectAorticDissection(in: text) {
            redFlags.append(aorticFlag)
        }

        if let peFlag = detectPE(in: text) {
            redFlags.append(peFlag)
        }

        if let sepsisFlag = detectSepsis(in: text) {
            redFlags.append(sepsisFlag)
        }

        if let aaaFlag = detectRupturedAAA(in: text) {
            redFlags.append(aaaFlag)
        }

        if let meningitisFlag = detectMeningitis(in: text) {
            redFlags.append(meningitisFlag)
        }

        if let perforationFlag = detectBowelPerforation(in: text) {
            redFlags.append(perforationFlag)
        }

        if let dkaFlag = detectDKA(in: text) {
            redFlags.append(dkaFlag)
        }

        if let anaphylaxisFlag = detectAnaphylaxis(in: text) {
            redFlags.append(anaphylaxisFlag)
        }

        if let asthmaFlag = detectSevereAsthma(in: text) {
            redFlags.append(asthmaFlag)
        }

        if let giBleedFlag = detectGIBleed(in: text) {
            redFlags.append(giBleedFlag)
        }

        return redFlags.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Individual Detection Functions

    private static func detectSTEMI(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Primary symptom
        if text.contains("chest pain") || text.contains("chest pressure") || text.contains("crushing") {
            findings.append("Chest pain/pressure")
            score += 0.3
        } else {
            return nil // Must have chest complaint
        }

        // Radiation patterns
        if text.contains("left arm") || text.contains("jaw") || text.contains("radiation") || text.contains("radiating") {
            findings.append("Pain radiation to arm/jaw")
            score += 0.2
        }

        // Associated symptoms
        if text.contains("diaphoresis") || text.contains("sweating") || text.contains("diaphoretic") {
            findings.append("Diaphoresis")
            score += 0.15
        }

        if text.contains("nausea") || text.contains("vomiting") {
            findings.append("Nausea/vomiting")
            score += 0.1
        }

        if text.contains("shortness of breath") || text.contains("dyspnea") || text.contains("sob") {
            findings.append("Dyspnea")
            score += 0.1
        }

        // Risk factors
        if text.contains("diabetic") || text.contains("diabetes") {
            findings.append("Diabetes")
            score += 0.05
        }

        if text.contains("hypertension") || text.contains("high blood pressure") {
            findings.append("Hypertension")
            score += 0.05
        }

        if text.contains("smoker") || text.contains("smoking") {
            findings.append("Smoking history")
            score += 0.05
        }

        // Need at least moderate suspicion
        if score >= 0.5 {
            return RedFlag(
                category: .stemi,
                severity: .critical,
                findings: findings,
                recommendation: "ACTIVATE CATH LAB ALERT. EKG STAT. Troponins, aspirin, antiplatelet therapy.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectStroke(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Classic stroke symptoms (FAST)
        if text.contains("weakness") || text.contains("weak") {
            findings.append("Unilateral weakness")
            score += 0.25
        }

        if text.contains("facial droop") || text.contains("face droop") || text.contains("facial asymmetry") {
            findings.append("Facial droop")
            score += 0.25
        }

        if text.contains("slurred") || text.contains("speech") && (text.contains("difficult") || text.contains("trouble")) {
            findings.append("Speech difficulty")
            score += 0.25
        }

        if text.contains("vision") && (text.contains("loss") || text.contains("blurred") || text.contains("double")) {
            findings.append("Vision changes")
            score += 0.15
        }

        if text.contains("confusion") || text.contains("altered") {
            findings.append("Altered mental status")
            score += 0.15
        }

        // Timing
        if text.contains("sudden") || text.contains("suddenly") {
            findings.append("Sudden onset")
            score += 0.2
        }

        if score >= 0.5 {
            return RedFlag(
                category: .stroke,
                severity: .critical,
                findings: findings,
                recommendation: "ACTIVATE STROKE ALERT. CT head STAT. Check last known well time. Consider tPA window.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectSAH(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Classic "worst headache of life"
        if (text.contains("worst") && text.contains("headache")) ||
           (text.contains("thunderclap") && text.contains("headache")) {
            findings.append("Worst headache of life")
            score += 0.5
        } else if text.contains("severe headache") && text.contains("sudden") {
            findings.append("Sudden severe headache")
            score += 0.4
        } else {
            return nil // Must have severe headache
        }

        // Associated features
        if text.contains("neck stiff") || text.contains("nuchal rigidity") {
            findings.append("Neck stiffness")
            score += 0.2
        }

        if text.contains("photophobia") || text.contains("light sensitivity") {
            findings.append("Photophobia")
            score += 0.1
        }

        if text.contains("nausea") || text.contains("vomiting") {
            findings.append("Nausea/vomiting")
            score += 0.1
        }

        if text.contains("syncope") || text.contains("passed out") || text.contains("loss of consciousness") {
            findings.append("Loss of consciousness")
            score += 0.15
        }

        if score >= 0.6 {
            return RedFlag(
                category: .subarachnoidHemorrhage,
                severity: .critical,
                findings: findings,
                recommendation: "CT head STAT. If negative, LP for xanthochromia. Neurosurgery consult.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectAorticDissection(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Characteristic pain
        if (text.contains("tearing") || text.contains("ripping")) && (text.contains("chest") || text.contains("back")) {
            findings.append("Tearing/ripping chest or back pain")
            score += 0.4
        } else if text.contains("chest pain") && text.contains("back pain") {
            findings.append("Chest and back pain")
            score += 0.3
        } else {
            return nil
        }

        // Risk factors
        if text.contains("hypertension") || text.contains("high blood pressure") {
            findings.append("Hypertension")
            score += 0.15
        }

        if text.contains("marfan") {
            findings.append("Marfan syndrome")
            score += 0.2
        }

        // Physical exam findings (if mentioned)
        if text.contains("blood pressure") && (text.contains("different") || text.contains("asymmetric")) {
            findings.append("BP differential between arms")
            score += 0.25
        }

        if score >= 0.5 {
            return RedFlag(
                category: .aorticDissection,
                severity: .critical,
                findings: findings,
                recommendation: "CTA chest STAT. BP control. Cardiothoracic surgery consult.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectPE(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Primary symptoms
        if text.contains("shortness of breath") || text.contains("dyspnea") || text.contains("sob") {
            findings.append("Dyspnea")
            score += 0.2
        }

        if text.contains("chest pain") && (text.contains("pleuritic") || text.contains("breathing")) {
            findings.append("Pleuritic chest pain")
            score += 0.2
        }

        // Risk factors
        if text.contains("recent surgery") || text.contains("surgery") && (text.contains("last week") || text.contains("last month")) {
            findings.append("Recent surgery")
            score += 0.2
        }

        if text.contains("dvt") || (text.contains("leg") && (text.contains("swelling") || text.contains("swollen"))) {
            findings.append("DVT or leg swelling")
            score += 0.2
        }

        if text.contains("birth control") || text.contains("oral contraceptive") {
            findings.append("Oral contraceptive use")
            score += 0.1
        }

        if text.contains("immobilization") || text.contains("bed rest") || text.contains("long flight") {
            findings.append("Recent immobilization")
            score += 0.15
        }

        // Additional features
        if text.contains("hemoptysis") || text.contains("coughing blood") {
            findings.append("Hemoptysis")
            score += 0.25
        }

        if text.contains("tachycardia") || (text.contains("heart rate") && text.contains("high")) {
            findings.append("Tachycardia")
            score += 0.1
        }

        if score >= 0.5 {
            return RedFlag(
                category: .pulmonaryEmbolism,
                severity: .urgent,
                findings: findings,
                recommendation: "CTA PE protocol. D-dimer if appropriate. Anticoagulation if high suspicion.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectSepsis(in text: String) -> RedFlag? {
        var findings: [String] = []
        var count = 0

        // SIRS criteria + source
        if text.contains("fever") || text.contains("febrile") {
            findings.append("Fever")
            count += 1
        }

        if text.contains("tachycardia") || (text.contains("heart rate") && (text.contains("fast") || text.contains("high"))) {
            findings.append("Tachycardia")
            count += 1
        }

        if text.contains("hypotension") || text.contains("low blood pressure") || (text.contains("bp") && text.contains("low")) {
            findings.append("Hypotension")
            count += 1
        }

        if text.contains("altered") || text.contains("confusion") || text.contains("lethargic") {
            findings.append("Altered mental status")
            count += 1
        }

        // Suspected source
        var hasSource = false
        if text.contains("infection") || text.contains("infected") {
            findings.append("Suspected infection")
            hasSource = true
        }

        if text.contains("cellulitis") || text.contains("abscess") {
            findings.append("Soft tissue infection")
            hasSource = true
        }

        if text.contains("pneumonia") || (text.contains("cough") && text.contains("fever")) {
            findings.append("Possible pneumonia")
            hasSource = true
        }

        if text.contains("uti") || text.contains("urinary") {
            findings.append("Possible UTI/urosepsis")
            hasSource = true
        }

        // Need SIRS + source
        if count >= 2 && hasSource {
            let severity: RedFlagSeverity = count >= 3 ? .critical : .urgent
            return RedFlag(
                category: .sepsis,
                severity: severity,
                findings: findings,
                recommendation: "SEPSIS ALERT. Lactate, blood cultures x2, broad-spectrum antibiotics within 1 hour. 30mL/kg fluid bolus.",
                confidence: Double(count) / 4.0
            )
        }

        return nil
    }

    private static func detectRupturedAAA(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Classic triad: abdominal pain + back pain + pulsatile mass
        if text.contains("abdominal pain") || text.contains("belly pain") {
            findings.append("Abdominal pain")
            score += 0.25
        } else {
            return nil
        }

        if text.contains("back pain") {
            findings.append("Back pain")
            score += 0.25
        }

        if text.contains("pulsatile") || text.contains("pulsating mass") {
            findings.append("Pulsatile abdominal mass")
            score += 0.4
        }

        // Risk factors
        if text.contains("aaa") || text.contains("aneurysm") {
            findings.append("Known AAA")
            score += 0.3
        }

        // Age and demographics often mentioned
        let agePattern = "(\\d{2,3})\\s*year"
        if let regex = try? NSRegularExpression(pattern: agePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let ageRange = Range(match.range(at: 1), in: text),
           let age = Int(text[ageRange]), age > 60 {
            findings.append("Age >60")
            score += 0.1
        }

        if text.contains("smoker") || text.contains("smoking") {
            findings.append("Smoking history")
            score += 0.1
        }

        if score >= 0.5 {
            return RedFlag(
                category: .rupturedAAA,
                severity: .critical,
                findings: findings,
                recommendation: "ACTIVATE TRAUMA/VASCULAR SURGERY. CT angio abdomen STAT (if stable). Type and cross 6 units.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectMeningitis(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Classic triad: headache, fever, neck stiffness
        if text.contains("headache") {
            findings.append("Headache")
            score += 0.25
        }

        if text.contains("fever") || text.contains("febrile") {
            findings.append("Fever")
            score += 0.25
        }

        if text.contains("neck stiff") || text.contains("nuchal rigidity") {
            findings.append("Neck stiffness")
            score += 0.3
        }

        if text.contains("photophobia") || text.contains("light sensitivity") {
            findings.append("Photophobia")
            score += 0.15
        }

        if text.contains("altered") || text.contains("confusion") {
            findings.append("Altered mental status")
            score += 0.2
        }

        if text.contains("rash") && (text.contains("petechial") || text.contains("purpura")) {
            findings.append("Petechial/purpuric rash")
            score += 0.3
        }

        if score >= 0.6 {
            return RedFlag(
                category: .meningitis,
                severity: .critical,
                findings: findings,
                recommendation: "Blood cultures, LP, broad-spectrum antibiotics + vancomycin STAT. CT head before LP if AMS.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectBowelPerforation(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Peritoneal signs
        if text.contains("rebound") || text.contains("peritoneal signs") {
            findings.append("Rebound tenderness")
            score += 0.3
        }

        if text.contains("guarding") || text.contains("rigid abdomen") {
            findings.append("Guarding/rigid abdomen")
            score += 0.25
        }

        if text.contains("severe abdominal pain") || (text.contains("abdominal pain") && text.contains("severe")) {
            findings.append("Severe abdominal pain")
            score += 0.2
        }

        if text.contains("distended") && text.contains("abdomen") {
            findings.append("Abdominal distension")
            score += 0.15
        }

        if text.contains("absent bowel sounds") || text.contains("no bowel sounds") {
            findings.append("Absent bowel sounds")
            score += 0.2
        }

        if score >= 0.5 {
            return RedFlag(
                category: .bowelPerforation,
                severity: .urgent,
                findings: findings,
                recommendation: "NPO, IV fluids, broad-spectrum antibiotics. CT abdomen. Surgical consult STAT.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectDKA(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Must have diabetes context
        if text.contains("diabetic") || text.contains("diabetes") {
            findings.append("Diabetic")
            score += 0.2
        } else {
            return nil
        }

        if text.contains("nausea") && text.contains("vomiting") {
            findings.append("Nausea/vomiting")
            score += 0.15
        }

        if text.contains("abdominal pain") {
            findings.append("Abdominal pain")
            score += 0.15
        }

        if text.contains("shortness of breath") || text.contains("kussmaul") {
            findings.append("Dyspnea/Kussmaul respirations")
            score += 0.2
        }

        if text.contains("altered") || text.contains("confusion") {
            findings.append("Altered mental status")
            score += 0.2
        }

        if text.contains("blood sugar") && (text.contains("high") || text.contains("elevated")) {
            findings.append("Hyperglycemia")
            score += 0.25
        }

        if score >= 0.5 {
            return RedFlag(
                category: .dka,
                severity: .urgent,
                findings: findings,
                recommendation: "BMP, glucose, VBG, beta-hydroxybutyrate. IV fluids, insulin drip protocol.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectAnaphylaxis(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Trigger
        if text.contains("allergic reaction") || text.contains("allergy") {
            findings.append("Allergic reaction")
            score += 0.2
        }

        // Respiratory
        if text.contains("wheezing") || text.contains("stridor") {
            findings.append("Wheezing/stridor")
            score += 0.3
        }

        if text.contains("throat swelling") || text.contains("tongue swelling") {
            findings.append("Angioedema")
            score += 0.3
        }

        // Cardiovascular
        if text.contains("hypotension") || text.contains("low blood pressure") {
            findings.append("Hypotension")
            score += 0.3
        }

        // Skin
        if text.contains("hives") || text.contains("urticaria") || text.contains("rash") {
            findings.append("Urticaria/rash")
            score += 0.15
        }

        if score >= 0.5 {
            return RedFlag(
                category: .anaphylaxis,
                severity: .critical,
                findings: findings,
                recommendation: "EPINEPHRINE IM STAT. Antihistamines, steroids, albuterol. Airway assessment.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectSevereAsthma(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        if text.contains("asthma") || text.contains("wheezing") {
            findings.append("Asthma/wheezing")
            score += 0.2
        } else {
            return nil
        }

        if text.contains("can't breathe") || text.contains("severe dyspnea") {
            findings.append("Severe dyspnea")
            score += 0.25
        }

        if text.contains("accessory muscles") || text.contains("tripod") {
            findings.append("Accessory muscle use")
            score += 0.25
        }

        if text.contains("can't speak") || text.contains("can't talk") {
            findings.append("Unable to speak in full sentences")
            score += 0.25
        }

        if text.contains("oxygen") && (text.contains("low") || text.contains("desaturat")) {
            findings.append("Hypoxia")
            score += 0.25
        }

        if score >= 0.5 {
            return RedFlag(
                category: .severeAsthma,
                severity: .urgent,
                findings: findings,
                recommendation: "Continuous albuterol, steroids, magnesium sulfate. ICU evaluation if not improving.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    private static func detectGIBleed(in text: String) -> RedFlag? {
        var findings: [String] = []
        var score = 0.0

        // Type of bleeding
        if text.contains("hematemesis") || text.contains("vomiting blood") || text.contains("coffee ground") {
            findings.append("Hematemesis")
            score += 0.4
        }

        if text.contains("melena") || text.contains("black stool") {
            findings.append("Melena")
            score += 0.35
        }

        if text.contains("hematochezia") || text.contains("bright red blood") && text.contains("rectum") {
            findings.append("Hematochezia")
            score += 0.3
        }

        // Signs of shock
        if text.contains("lightheaded") || text.contains("dizzy") {
            findings.append("Lightheadedness")
            score += 0.15
        }

        if text.contains("tachycardia") || text.contains("fast heart") {
            findings.append("Tachycardia")
            score += 0.15
        }

        if text.contains("hypotension") || text.contains("low blood pressure") {
            findings.append("Hypotension")
            score += 0.25
        }

        if score >= 0.5 {
            let severity: RedFlagSeverity = score >= 0.7 ? .critical : .urgent
            return RedFlag(
                category: .giBleed,
                severity: severity,
                findings: findings,
                recommendation: "Type and cross, CBC, coags. Two large-bore IVs. GI consult. Consider massive transfusion protocol if unstable.",
                confidence: min(score, 1.0)
            )
        }

        return nil
    }

    // MARK: - Formatting and Reporting

    static func generateRedFlagReport(_ redFlags: [RedFlag]) -> String {
        if redFlags.isEmpty {
            return "No critical red flags detected."
        }

        var report = "⚠️ RED FLAG ALERTS DETECTED:\n\n"

        for (index, flag) in redFlags.enumerated() {
            let severityIcon = getSeverityIcon(flag.severity)
            report += "\(index + 1). \(severityIcon) \(flag.category.rawValue)\n"
            report += "   Severity: \(flag.severity)\n"
            report += "   Confidence: \(Int(flag.confidence * 100))%\n"
            report += "   Findings: \(flag.findings.joined(separator: ", "))\n"
            report += "   Recommendation: \(flag.recommendation)\n\n"
        }

        return report
    }

    private static func getSeverityIcon(_ severity: RedFlagSeverity) -> String {
        switch severity {
        case .critical: return "🔴"
        case .urgent: return "🟠"
        case .warning: return "🟡"
        }
    }
}
