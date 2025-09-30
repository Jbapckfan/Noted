import Foundation

class MedicalNotePromptGenerator {

    private let classifier = ChiefComplaintClassifier()
    private let transformer = IntelligentMedicalTransformer()

    func generatePrompt(for transcript: String) -> String {
        let (complaintType, confidence) = classifier.classify(transcript: transcript)
        let transformedText = transformer.transformToMedical(transcript)

        return """
        You are an emergency medicine physician creating a medical note.

        TASK: Convert the following patient encounter into a professional medical note.

        EXAMPLES OF PROPER TRANSFORMATION:

        === UNIVERSAL RULES ===
        1. Convert casual language to medical terminology:
           - "passed out" → "lost consciousness"
           - "heart racing" → "tachycardia"
           - "can't breathe" → "dyspnea"
           - "throwing up" → "vomiting"
           - "swollen" → "edema"

        2. Format pain descriptions:
           - "hurts really bad" → "severe pain"
           - "10 out of 10" → "10/10 pain"
           - Remove pain scale explanations

        3. Clean up speech patterns:
           - Remove: "um", "uh", "you know", profanity
           - Fix corrections: "yesterday, no today" → "today"
           - Clarify times: "a while" → estimate duration

        4. Structure medications properly:
           - Include dose and frequency
           - Note compliance issues
           - Document last dose timing for relevant meds

        === CHIEF COMPLAINT: \(complaintType.rawValue.uppercased()) ===
        Required elements: \(complaintType.requiredElements.joined(separator: ", "))

        === OUTPUT STRUCTURE ===

        Chief Complaint: [One line, primary reason for visit]

        HPI: [Complete narrative including:]
        - Onset and duration
        - Quality and severity
        - Associated symptoms
        - Aggravating/alleviating factors
        - Prior episodes
        - Treatment attempts

        PMH: [List relevant conditions]

        PSH: [Any surgeries mentioned]

        Medications: [Current medications with doses]

        Allergies: [Drug allergies with reactions]

        Social History: [If relevant to case]

        Family History: [If mentioned]

        Review of Systems:
        [Organize by system, include pertinent positives and negatives]

        Physical Exam:
        [Only objective findings, no interpretations]

        Pertinent Labs/Imaging: [If mentioned]

        MDM:
        [Clinical reasoning paragraph including:]
        - Summary of presentation
        - Differential diagnosis
        - Clinical decision making
        - Risk stratification

        Plan:
        - [Immediate interventions]
        - [Diagnostic workup]
        - [Treatments]
        - [Disposition]

        Impression: [Final diagnoses]

        === TRANSCRIPT TO CONVERT ===
        \(transformedText)

        === IMPORTANT ===
        - Only include information explicitly stated or clearly implied
        - Do not add findings not mentioned
        - Maintain clinical accuracy
        - Use proper medical terminology
        """
    }
}