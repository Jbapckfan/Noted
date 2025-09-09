# Pattern Training Architecture

## Overview
NotedCore uses pre-trained medical patterns extracted from the MTS-Dialog dataset to improve medical note generation. These patterns are compiled directly into the app, so users don't need to perform any training.

## Why This Approach?

### Problems with In-App Training:
- **Wrong Place**: Training should happen during development, not in production
- **Not Shareable**: Each user would need to train separately
- **Requires Datasets**: Users would need access to large medical datasets
- **Performance Impact**: Training would slow down the app
- **No Persistence**: Training results would be lost between sessions

### Benefits of Pre-Trained Patterns:
- **Zero Setup**: Works immediately for all users
- **Consistent Quality**: All users get the same improvements
- **No Dependencies**: No MLX framework or GPU required
- **Fast Performance**: Patterns are compiled into the app
- **Professional Results**: Trained on 1,700+ medical conversations

## Architecture

### 1. Development-Time Training (One-Time)
```
Scripts/train_patterns.swift
    ↓ (reads MTS-Dialog dataset)
    ↓ (extracts medical patterns)
    ↓ (generates Swift file)
PretrainedMedicalPatterns.swift
```

### 2. Compile-Time Integration
```
PretrainedMedicalPatterns.swift
    ↓ (compiled into app)
NotedCore.app
```

### 3. Runtime Usage
```
User speaks → Transcription 
    ↓
MedicalAbbreviationExpander (expand abbreviations)
    ↓
PretrainedMedicalPatterns (apply learned patterns)
    ↓
RealConversationAnalyzer (generate note)
    ↓
Professional Medical Note
```

## How to Update Patterns

### For Developers Only:
1. Download latest MTS-Dialog dataset
2. Run training script:
   ```bash
   cd Scripts
   swift train_patterns.swift
   ```
3. Review generated `PretrainedMedicalPatterns.swift`
4. Build and test the app
5. Commit the updated patterns file

### Pattern Categories:
- **Chief Complaints**: Common ED presentations
- **Demographics**: Age, gender formatting
- **Onset**: Temporal descriptions
- **Symptoms**: Medical terminology
- **Medications**: Drug names and dosages
- **Allergies**: Allergy documentation
- **Examination**: Physical exam findings
- **Assessment**: Clinical reasoning terms
- **Disposition**: Discharge/admission terms
- **Vitals**: BP, HR, temp formatting
- **Timing**: Convert colloquial to medical
- **Severity**: Pain scales and descriptors
- **Location**: Anatomical regions
- **Quality**: Pain/symptom qualities
- **Modifiers**: Symptom modifiers

## What Users See

### Before (Without Patterns):
```
"Patient came in yesterday with really bad stomach pain, 
bp was 120/80, no allergies, taking tylenol"
```

### After (With Patterns):
```
"Patient presented 1 day ago with severe abdominal pain,
BP: 120/80 mmHg, NKDA, taking Acetaminophen"
```

## Privacy & Security
- All patterns are generic medical terminology
- No patient data is included in patterns
- Patterns are read-only and cannot be modified by users
- No data is sent to external servers

## Comparison to Other Apps

| Feature | NotedCore | Other Scribe Apps |
|---------|-----------|-------------------|
| Training Required | No | No |
| Pattern-Based Enhancement | Yes | No |
| Medical Terminology Conversion | Yes | Limited |
| Works Offline | Yes | Some |
| Customizable | Via dev script | No |
| Free | Yes | Usually paid |

## Technical Details

### Pattern Extraction Process:
1. Parse MTS-Dialog CSV files
2. Extract section headers and text
3. Identify medical patterns using regex
4. Categorize by clinical relevance
5. Deduplicate similar patterns
6. Generate Swift code with patterns

### Pattern Application:
1. Case-insensitive matching
2. Preserve context around replacements
3. Apply medical formatting rules
4. Maintain clinical accuracy

## Future Improvements
- Add more datasets (PriMock57, etc.)
- Support for specialty-specific patterns
- User preference for formality level
- Regional terminology variations
- Multi-language support

## Conclusion
By moving training to development time and compiling patterns into the app, NotedCore provides professional medical note generation without requiring users to understand or perform any AI training. This makes the app immediately useful to all healthcare providers while maintaining high quality and consistency.