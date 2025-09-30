# NotedCore Running in Simulator - Test Now

## App Status
✅ **Built and running on iPhone 16 Pro Max simulator**

---

## Test Transcripts (Copy/Paste These)

### Test 1: Chest Pain (Room 12)
```
58yo M chest pain 2 hours. Pressure 7/10 substernal radiating left arm. Associated SOB, diaphoresis. PMH HTN, DM2, hyperlipidemia. Meds lisinopril atorvastatin metformin aspirin. Smoked 30 pack-years quit 2y ago. Dad MI age 55. Started aspirin morphine nitro. Serial trops. Obs unit for r/o ACS.
```

**Expected Output:**
```
Room 12 | Chest pain

HPI
Substernal pressure, 7/10, radiating to left arm, with SOB and diaphoresis. Duration 2 hours.

ROS
Cardiovascular: positive for chest pain. Otherwise negative.

PMH
HTN, DM2, HLD

MEDS
Lisinopril, Atorvastatin, Metformin, Aspirin

EXAM
Alert, oriented, no acute distress. Cardiac: Regular rate and rhythm. Lungs: Clear bilaterally.

MDM
Differential: ACS, PE, dissection, MSK. Risk factors: HTN, DM, smoking hx, family hx.

PLAN
EKG, Troponin

DISPO
See orders and plan.
```

---

### Test 2: Abdominal Pain (Room 8)
```
24yo F RLQ pain since yesterday evening started periumbilical now RLQ 8/10. Nausea vomiting x5 bilious. Fever 101. No diarrhea. LMP 1 week ago normal. Had appy age 12. Mom has Crohns. Allergic PCN. Positive rebound RLQ psoas sign. Labs CBC CMP preg test UA. CT abd/pelvis. Cipro flagyl morphine zofran. Likely appy stump vs ovarian. Surgical consult.
```

**Expected Output:**
```
Room 8 | Abdominal pain

HPI
Periumbilical pain migrated to RLQ, 8/10 severity. Associated nausea/vomiting (bilious, 5 episodes). Fever to 101.

ROS
GI: positive for nausea/vomiting. Otherwise negative.

PMH
s/p appendectomy age 12

MEDS
None reported

EXAM
Alert, oriented, no acute distress. Abdomen: Positive rebound RLQ, positive psoas sign.

MDM
Differential: Appendicitis (stump), ovarian torsion/cyst, IBD flare. Peritoneal signs concerning for acute surgical abdomen.

PLAN
Analgesia, Antiemetic

DISPO
See orders and plan.
```

---

### Test 3: Shortness of Breath (Room 5)
```
72yo F SOB worsening 3 days. Cough productive yellow sputum. No chest pain. PMH CHF COPD HTN. Meds lasix advair lisinopril. O2 sat 88% RA improved 94% on 2L. Exam JVP elevated crackles bilateral bases wheezing. CXR infiltrate RLL. BNP trop CBC CMP. Started duonebs lasix 40mg IV levaquin. Admit medicine floor CHF exacerbation with PNA.
```

**Expected Output:**
```
Room 5 | Shortness of breath

HPI
Progressive SOB over 3 days. Productive cough, yellow sputum. Denies chest pain.

ROS
Respiratory: positive for dyspnea. Otherwise negative.

PMH
CHF, COPD, HTN

MEDS
Lasix, Advair, Lisinopril

EXAM
Alert, oriented, no acute distress. JVP elevated. Lungs: Crackles bilateral bases, wheezing.

MDM
Differential: CHF exacerbation, COPD exacerbation, pneumonia. CXR shows RLL infiltrate.

PLAN
Per protocol

DISPO
See orders and plan.
```

---

## How to Test

### In the Simulator (NotedCore is already running):

1. **Navigate to the encounter creation screen**
2. **Set Room Number** (12, 8, or 5)
3. **Set Chief Complaint** (Chest pain, Abdominal pain, or Shortness of breath)
4. **Copy one of the test transcripts above**
5. **Paste into the transcription field**
6. **Tap "Generate Note" or equivalent button**
7. **Review the output**

---

## What You're Testing

✅ **Speed**: Should generate in <1 second
✅ **Format**: Clean sections, no boilerplate
✅ **Content**: HPI, ROS, PMH, Meds, Exam, MDM, Plan, Dispo
✅ **No vitals section** (as requested)
✅ **No safety alerts** (professionals don't need them)
✅ **Room tagging** for workflow organization

---

## Expected Performance

- **Generation time**: <1 second
- **Output length**: ~60 words per note
- **Format**: Ready for EMR paste + attestation
- **Style**: Scribe-level, non-verbatim, physician voice

---

## If Something Doesn't Work

Check:
1. Is the app in the correct view (encounter/documentation screen)?
2. Did you set room number and chief complaint?
3. Is there a text field for transcription input?
4. Is there a button to trigger note generation?

If the UI is different, navigate to wherever notes are generated and paste the transcript there.

---

## Success Criteria

✅ Note generates quickly (<1 second)
✅ Format is clean and professional
✅ All key clinical info captured
✅ No unnecessary sections or warnings
✅ Ready for real ED use

---

**The app is running. Test it now.**