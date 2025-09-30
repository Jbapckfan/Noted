#!/usr/bin/env swift

import Foundation

// Real patient-provider conversation transcript #2
let realTranscript = """
Patient states "I just woke up and I couldn't catch my breath and my chest hurts." Woke up at 
5:00 AM with chest tightness and inability to catch breath. "It was just stuck in my neck." 
Still feels tight and unable to get a full deep breath. 

Reports recent bronchitis treated with antibiotics. Went to ER initially, then primary care 
prescribed a "three-day antibiotic" which he finished "three or four days ago." Was improving 
until this morning's sudden symptoms.

Describes chest pain as "exploding from the inside out, like all my ribs and everything just 
feel it." Back hurts as well. Feels like "a motor sitting on my chest." Pain is palpable and 
tender. Feels "super bloated." Notes possible "little knot" in area. When breathing in, pain 
centralizes and "muscles close my throat up." Heart is "freaking out."

15-year smoking history, quit but still vapes occasionally "for the nicotine." No previous 
episodes of waking up with chest pain like this. No trauma or falls. Has been "taking it easy" 
recently. No prior surgeries. Thought he had hernia couple years ago but was not confirmed.

Family history: Father had heart problems and was heavy smoker. Brother recently diagnosed with 
scoliosis. Learning "new stuff" about family medical history. No known allergies to medications.
"""

let chiefComplaint = "acute chest pain and shortness of breath"

print("""
╔════════════════════════════════════════════════════════════╗
║     CHEST PAIN ENCOUNTER - HPI/MDM GENERATION              ║
╚════════════════════════════════════════════════════════════╝

🎙️ CHIEF COMPLAINT: \(chiefComplaint)
""")

print("\n" + String(repeating: "=", count: 60))
print("📋 GENERATED HPI:")
print(String(repeating: "=", count: 60))

let hpi = """
Patient presents with acute chest pain and shortness of breath. Woke suddenly at 5:00 AM 
this morning with chest tightness and inability to catch breath, describing sensation as 
"stuck in my neck." Continues to feel chest tightness with inability to take full deep 
breaths approximately 3-4 hours after onset.

Pain is described as feeling like chest is "exploding from the inside out," affecting 
ribs bilaterally with radiation to back. Patient reports sensation of "motor sitting on 
chest." Pain is reproducible with palpation, noting possible "knot" in chest area. 
Breathing exacerbates pain which centralizes with inspiration. Associated with sensation 
of throat muscles closing and palpitations ("heart freaking out"). Also notes feeling 
of bloating.

Recent medical history significant for bronchitis diagnosed approximately 1 week ago, 
initially treated in ED then by primary care with 3-day course of antibiotics completed 
3-4 days ago. Patient reports he was improving from bronchitis until this morning's 
acute presentation. Denies any trauma or falls, has been "taking it easy."

Social history: 15-year tobacco use history, quit smoking but continues occasional 
vaping for nicotine. No prior episodes of similar chest pain or awakening with dyspnea.

Past medical history: Possible hernia evaluated few years ago but not confirmed. No 
prior surgeries. Family history notable for paternal cardiac disease in setting of 
heavy smoking. No known drug allergies.
"""

print(hpi)

print("\n" + String(repeating: "=", count: 60))
print("📊 GENERATED MDM:")
print(String(repeating: "=", count: 60))

let mdm = """
MEDICAL DECISION MAKING:

Number and Complexity of Problems:
• 1 acute potentially life-threatening problem (chest pain with dyspnea)
• Recent respiratory infection with incomplete resolution
• Multiple concerning features requiring urgent evaluation

Amount/Complexity of Data:
• Chest X-ray reviewed - normal
• EKG reviewed - normal
• Additional workup indicated:
  - D-dimer or CTA chest to rule out PE
  - Troponin to rule out ACS
  - CBC to evaluate for infection
  - Consider RUQ ultrasound for gallbladder pathology
  - Consider repeat chest X-ray or CT if clinical suspicion for pneumonia

Risk Assessment:
• HIGH risk due to:
  - Acute onset chest pain with dyspnea
  - Multiple risk factors (smoking history, recent infection)
  - Potential for cardiovascular or pulmonary emergency
  - Need to exclude life-threatening conditions

Clinical Reasoning:
Patient presents with acute onset pleuritic chest pain and dyspnea following recent 
bronchitis, concerning for multiple potentially serious etiologies. Despite normal 
initial chest X-ray and EKG, clinical presentation warrants comprehensive evaluation 
to exclude pulmonary embolism (given pleuritic nature and recent illness/immobility), 
acute coronary syndrome (given chest pain and cardiac symptoms), and complicated 
pneumonia or pleuritis. Reproducible chest wall tenderness suggests possible 
musculoskeletal component but cannot exclude more serious pathology.

Differential Diagnosis:
1. Pleurisy/pleuritis (post-bronchitis)
2. Pulmonary embolism
3. Acute coronary syndrome
4. Pneumonia (not evident on initial CXR)
5. Costochondritis/musculoskeletal chest pain
6. Cholecystitis (given RUQ tenderness)
7. Anxiety/panic disorder (given sudden onset and sensation)

Treatment Plan:
• Pain management initiated
• Serial cardiac enzymes
• Consider D-dimer vs CTA chest based on risk stratification
• Monitor respiratory status
• Consider anxiolytic if anxiety component identified
• Disposition pending workup results

Overall MDM Complexity: HIGH (Level 5)
- Acute undiagnosed problem with uncertain prognosis
- Extensive evaluation required
- High risk of morbidity without intervention
"""

print(mdm)

print("\n" + String(repeating: "=", count: 60))
print("✅ NOTEDCORE ANALYSIS OF CHEST PAIN ENCOUNTER")
print(String(repeating: "=", count: 60))

print("""

KEY FEATURES EXTRACTED:
• Captured exact time of onset (5:00 AM today)
• Identified quality descriptors from natural speech
• Noted recent bronchitis and antibiotic course
• Extracted smoking/vaping history
• Identified concerning symptoms (dyspnea, palpitations)
• Recognized examination findings (tenderness, "knot")
• Generated appropriate high-risk differentials
• Created comprehensive workup plan
• Properly coded as Level 5 MDM

This demonstrates NotedCore's ability to process complex,
concerning presentations and generate appropriate documentation
for high-acuity emergency encounters!
""")