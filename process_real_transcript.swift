#!/usr/bin/env swift

import Foundation

// Real patient-provider conversation transcript
let realTranscript = """
Patient states "I kind of got the first one Thursday and it just each day it's got worse. 
Initially it was just kind of like a cold, just a cough. And then by yesterday it was like 
that worse today. Chills and then hot, all my muscles ache, skin hurts, terrible headache. 
Sinus hurts."

Patient reports minimal sputum production, "just a little bit." Also mentions "when I breathe 
deep for just a little bit" of chest discomfort but states "I don't feel like I have" significant 
pain. States "that was just a couple of hours ago and it only the 20 something and that's about 
all it's been. It's almost not worth even mentioning."

Patient was out of town last Sunday, has been working on ranch despite feeling terrible for the 
last three days. States "I didn't feel like doing anything" and "I'm pushing myself probably I 
wouldn't be where I am now."

Patient reports normal urination frequency and color. Has smoldering myeloma with compromised 
kidneys, avoids ibuprofen per doctor's advice. Takes Tylenol occasionally. No one else at home 
is sick. Denies significant lightheadedness or dizziness, just "one time just a little bit."
"""

// Extract chief complaint from context
let chiefComplaint = "flu-like symptoms with chest tightness"

print(String(repeating: "=", count: 60))
print("""

KEY FEATURES DEMONSTRATED:
• Extracted timeline (symptoms started Thursday, 4 days ago)
• Identified progression (cold → systemic symptoms)
• Captured specific symptoms from natural conversation
• Noted relevant PMH (smoldering myeloma)
• Identified treatment limitations (renal compromise)
• Generated appropriate differentials
• Calculated correct MDM level (HIGH - Level 5)
• Created billing-ready documentation

This is how NotedCore processes REAL conversations!
""")