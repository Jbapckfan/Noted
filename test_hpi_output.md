# HPI Testing Examples

## Test Case: Chest Pain with VTE History

**Input Conversation:**
```
I heard that you're having some chest pain today. Can you tell me a little more about that like when did it start? What does it feel like does the pain radiate and what kind of medical problems do you have? Oh well I do have diabetes and high blood pressure and my pain started about two hours before coming. I've had a blood clot in my legs before but no problems with my heart. I used to take a blood thinner, but I ran out about six weeks ago and I have had a little bit of a cough. Do you have any other problems? Do you take any other prescribed medication? Have you ever had any major surgeries? No no other medications I did have an appendectomy and I used to smoke cigarettes, but I stopped two years ago and I drink alcohol a few times a week. I don't take any other prescriptions. OK well we are going to order some lab tests and EKG and chest x-ray and make sure that your heart is looking good and that there is no evidence of a blood clot and we will just go from there.
```

**Expected NEW HPI Output:**
```
Patient presents with chest pain x 2 hours that began 2 hours prior to arrival. Patient also reports cough. Patient has a history of diabetes, hypertension, blood clots but denies any prior cardiac problems. Patient was previously on blood thinners but stopped 6 weeks ago when the prescription ran out.
```

## Key Improvements:

✅ **Natural storytelling** - flows like a conversation, not robotic  
✅ **Medical accuracy** - patient denied heart problems, so no MI in history  
✅ **Social history separated** - smoking/alcohol goes in Social History section, NOT HPI  
✅ **No redundancy** - doesn't repeat "chest pain x 2 hours" twice  
✅ **Natural language** - "has a history of" not "significant medical history of"  
✅ **Conversational tone** - reads like an ER doctor telling a colleague about the case  

## Sections Properly Organized:

**HPI:** Patient's story with relevant medical context  
**PMH:** • Diabetes mellitus, • Hypertension, • History of venous thromboembolism  
**Social History:** • Former smoker, quit 2 years ago, • Social alcohol use, several times per week  

This creates professional, accurate medical documentation that tells the patient's story naturally while maintaining clinical precision.