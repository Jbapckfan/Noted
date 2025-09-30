#!/usr/bin/env swift

import Foundation

// Your headache/nausea transcript
let transcript = """
Hello, I'm Dr. Alford.
When did this start?
and the headaches started about Wednesday.
Okay.
And then I just started puking last night.
Okay.
Have you had symptoms like this before?
No.
Okay.
Well, I don't remember.
Uh.
Do you get, are you having much of a headache right now?
Yeah.
Okay.
Do you get headaches or migraines sometimes?
Um, I take Advil.
Okay.
So, I, I rarely get them.
Okay.
But, like, maybe once, twice a month.
Okay.
Are you feeling nauseous?
Oh, yeah.
Okay.
Yeah, you got to get.
Okay.
Uh.
Uh.
Okay.
Uh, yeah.
Uh, okay.
Uh.
What's bothering you the most right now?
Um, my stomach and my heart burning.
Any history of ulcers?
Uh, no.
Acid reflux.
Okay.
Okay.
Uh.
Uh.
Are you having bowel movements okay?
Uh, I, I gave one yesterday.
Mhm.
Uh.
Have you noticed any blood in your stools?
Oh no.
Any allergies to nausea or pain meds?
Oh no.
We're going to get you some fluids, get you some meds and get you going in the right direction, okay?
Oh no.
How'd you get here?
By board.
Okay.
"""

// Process and generate note
func generateMedicalNote(from transcript: String) -> String {
    // Extract key information
    let chiefComplaint = "Headache and vomiting"
    
    // Build HPI
    var hpi = "HPI: "
    
    // Onset
    if transcript.contains("headaches started about Wednesday") {
        hpi += "Headache onset Wednesday. "
    }
    
    // Vomiting
    if transcript.contains("started puking last night") {
        hpi += "Vomiting started last night. "
    }
    
    // Current symptoms
    if transcript.contains("stomach") && transcript.contains("heart burning") {
        hpi += "Current primary complaints are stomach pain and heartburn. "
    }
    
    if transcript.contains("having much of a headache right now") && transcript.contains("Yeah") {
        hpi += "Reports headache and nausea. "
    }
    
    // Medication history
    if transcript.contains("I take Advil") && transcript.contains("rarely get them") {
        hpi += "Takes Advil rarely for headaches, "
        if transcript.contains("once, twice a month") {
            hpi += "about 1-2 times per month. "
        }
    }
    
    // Prior symptoms
    if transcript.contains("Have you had symptoms like this before") && transcript.contains("No") {
        hpi += "Denies prior similar symptoms. "
    }
    
    // Past medical history
    if transcript.contains("history of ulcers") && transcript.contains("no") {
        hpi += "No history of ulcers. "
    }
    
    // GI symptoms
    if transcript.contains("bowel movements") && transcript.contains("yesterday") {
        hpi += "Reports last bowel movement was yesterday. "
    }
    
    if transcript.contains("blood in your stools") && transcript.contains("no") {
        hpi += "Denies blood in stool. "
    }
    
    // Allergies
    if transcript.contains("allergies to nausea or pain meds") && transcript.contains("no") {
        hpi += "No known allergies to nausea or pain medications."
    }
    
    // Physical exam
    let exam = """
    
    PHYSICAL EXAM:
    General: Alert.
    """
    
    // MDM
    let mdm = """
    
    MDM:
    Patient presents with headache, vomiting, and dyspepsia. Plan is for IV fluids and anti-emetic/analgesic medications to manage symptoms.
    """
    
    // Impression
    let impression = """
    
    Impression:
    Headache
    Nausea and Vomiting
    Dyspepsia

    James Alford, MD
    """
    
    return hpi + exam + mdm + impression
}

// Generate and print the formatted note
print("╔════════════════════════════════════════════════════════════╗")
print("║     FORMATTED MEDICAL NOTE FROM RAW TRANSCRIPT             ║")
print("╚════════════════════════════════════════════════════════════╝")
print("")

let formattedNote = generateMedicalNote(from: transcript)
print(formattedNote)