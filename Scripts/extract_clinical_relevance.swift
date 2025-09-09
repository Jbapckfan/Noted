#!/usr/bin/env swift

// REAL Medical AI Training - Clinical Relevance Extraction
// This demonstrates what actual medical AI training should accomplish

import Foundation

// Example of REAL patient statements from MTS-Dialog dataset
let realPatientStatements = [
    // Patient rambling statement
    """
    Patient: Well, it started maybe three days ago, no wait, actually it was Tuesday because 
    I remember I was at my daughter's house for dinner. We had chicken, which might be 
    relevant because I felt sick after. But anyway, I started having this pain in my chest, 
    not really bad at first, just annoying. I took some Tums thinking it was heartburn from 
    the spicy food. My daughter makes everything too spicy. The pain got worse yesterday when 
    I was walking up the stairs to get my mail. I had to stop and catch my breath. I've been 
    tired lately too, but I thought that was just from not sleeping well. My husband snores 
    terribly. Oh, and my left arm has been feeling heavy, but I figured I slept on it wrong.
    """,
    
    // What AI should extract (clinically relevant only)
    """
    Chief Complaint: Chest pain x3 days
    HPI: 
    - Onset: 3 days ago (Tuesday)
    - Character: Progressive worsening
    - Associated symptoms: Dyspnea on exertion, fatigue, left arm heaviness
    - Aggravating factors: Physical exertion (climbing stairs)
    - Attempted treatment: Calcium carbonate (Tums) - ineffective
    RED FLAGS: Chest pain + DOE + left arm symptoms → Possible cardiac etiology
    """
]

// Another real example
let complexExample = """
PATIENT RAMBLING:
"Doctor, I don't know what's wrong with me. I've been feeling awful for about a week. 
It started when I was at work - I work at the grocery store, been there 15 years - and 
suddenly I felt like I was going to pass out. My manager, Bob, he's really nice, he let 
me sit down in the break room. I drank some water and felt better. But then it happened 
again the next day. I was stocking shelves, the cereal aisle, and boom - everything went 
black for a second. I didn't actually fall but I had to grab the shelf. I've been 
drinking lots of water because I thought maybe I was dehydrated. My sister said I should 
eat more salt. I've been dizzy on and off since then. Oh, and I forgot to mention, I've 
been having these headaches too. Not terrible, but annoying. And I'm on blood pressure 
medicine, the little white pills, I think they're called lisinopril? I sometimes forget 
to take them though. My blood pressure was really high at the pharmacy machine last month, 
like 190 over something."

WHAT AI SHOULD EXTRACT:
Chief Complaint: Near-syncope episodes x1 week

HPI:
- Two near-syncope episodes in past week
- First episode: At work, resolved with rest and hydration
- Second episode: Next day while standing/working, visual changes ("went black"), 
  required support to prevent fall
- Associated: Intermittent dizziness x1 week, mild headaches
- PMH: Hypertension (poorly controlled)
- Medications: Lisinopril (poor compliance admitted)
- Recent BP: 190/? (pharmacy reading)

ASSESSMENT: 
- Orthostatic hypotension vs medication-related
- Poorly controlled HTN with medication non-compliance
- Rule out cardiac arrhythmia

CRITICAL FINDINGS:
- BP 190 systolic (pharmacy)
- Medication non-compliance
- Recurrent near-syncope episodes
"""

// This is what REAL training would teach:
struct ClinicalExtractionTraining {
    
    // What the AI needs to learn to identify
    static let extractionRules = [
        "TEMPORAL_MARKERS": "Identify when symptoms started, ignore social context",
        "SYMPTOM_PROGRESSION": "Track how symptoms changed over time",
        "RED_FLAGS": "Identify concerning symptom combinations",
        "RELEVANT_HISTORY": "Extract only medically relevant past history",
        "MEDICATION_RELEVANCE": "Identify medications and compliance issues",
        "SOCIAL_FILTER": "Remove social pleasantries and irrelevant details",
        "CLINICAL_PRIORITY": "Rank symptoms by clinical importance"
    ]
    
    // Training examples showing input -> output
    static func demonstrateRealTraining() {
        print("🎯 REAL MEDICAL AI TRAINING EXAMPLES\n")
        print(String(repeating: "=", count: 50))
        
        // Example 1: Filtering irrelevant information
        print("\n📝 EXAMPLE 1: Information Filtering")
        print("\nPATIENT SAYS:")
        print("'My neighbor, she's a nurse, told me I should come in. I was gardening - I love my roses - when I felt this crushing pain in my chest. I thought maybe I pulled a muscle.'")
        
        print("\nAI SHOULD EXTRACT:")
        print("• Chief Complaint: Crushing chest pain")
        print("• Onset: During physical activity (gardening)")
        print("• Character: Crushing")
        print("✂️ FILTERED OUT: Neighbor being a nurse, loving roses")
        
        // Example 2: Identifying buried critical information
        print("\n📝 EXAMPLE 2: Finding Buried Critical Info")
        print("\nPATIENT SAYS:")
        print("'I've had a cold for a week. Lots of coughing. My wife made me chicken soup. Oh, and I've been coughing up blood for two days but I figured that was from coughing so hard.'")
        
        print("\nAI SHOULD EXTRACT:")
        print("🚨 CRITICAL: Hemoptysis x2 days")
        print("• Associated: Cough x1 week")
        print("• RED FLAG: Hemoptysis requires immediate evaluation")
        print("✂️ FILTERED OUT: Wife making soup")
        
        // Example 3: Temporal reconstruction
        print("\n📝 EXAMPLE 3: Timeline Reconstruction")
        print("\nPATIENT SAYS:")
        print("'The pain is really bad today. It was okay yesterday. Actually, thinking about it, it started last Monday. Or was it Tuesday? Definitely earlier this week. It's gotten worse each day.'")
        
        print("\nAI SHOULD EXTRACT:")
        print("• Duration: 5-6 days")
        print("• Pattern: Progressive worsening")
        print("• Current severity: Severe")
        
        print("")
        print(String(repeating: "=", count: 50))
        print("\n🎓 THIS is what medical AI training should accomplish:")
        print("1. Extract clinically relevant information")
        print("2. Filter out social/irrelevant details")
        print("3. Identify red flags and critical findings")
        print("4. Reconstruct accurate timelines")
        print("5. Prioritize by clinical importance")
        print("6. Recognize symptom patterns suggesting specific conditions")
        
        print("\n⚠️  Simple word replacement (tylenol → Acetaminophen) is just")
        print("    formatting, not intelligence. Real training teaches the AI")
        print("    to think like a clinician!")
    }
}

// Run demonstration
ClinicalExtractionTraining.demonstrateRealTraining()

print("\n🔬 REAL TRAINING REQUIREMENTS:")
print("• Needs thousands of patient-doctor conversations")
print("• Requires expert annotation of what's clinically relevant")
print("• Must learn to identify patterns suggesting specific conditions")
print("• Should recognize when information is missing and ask follow-ups")
print("• Must prioritize life-threatening conditions")

print("\n💡 The MTS-Dialog dataset HAS this kind of data!")
print("   We should be training on the conversation→summary relationship,")
print("   not just extracting word patterns!")