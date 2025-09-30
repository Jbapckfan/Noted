#!/usr/bin/env python3
"""
Medical Vocabulary Enhancement for Whisper Fine-Tuning
=====================================================

Enhances Whisper's vocabulary with medical terminology to improve recognition of:
- Drug names and pharmaceutical terms
- Medical procedures and treatments
- Anatomy and pathology terms
- Clinical measurements and units
- Medical abbreviations and acronyms

This module significantly improves medical transcription accuracy by ensuring
the model properly recognizes domain-specific terminology.
"""

import re
import json
import logging
from typing import List, Dict, Set, Tuple, Optional
from pathlib import Path
from dataclasses import dataclass
from collections import defaultdict, Counter

import requests
import nltk
from nltk.tokenize import word_tokenize
from nltk.corpus import stopwords

logger = logging.getLogger(__name__)

@dataclass
class MedicalEntity:
    """Represents a medical entity with metadata"""
    term: str
    category: str
    frequency: int = 0
    synonyms: List[str] = None
    context: List[str] = None

    def __post_init__(self):
        if self.synonyms is None:
            self.synonyms = []
        if self.context is None:
            self.context = []

class MedicalVocabularyEnhancer:
    """Enhances tokenizer vocabulary with medical terminology"""

    def __init__(self, cache_dir: str = "./medical_vocab_cache"):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)

        # Initialize NLTK components
        try:
            nltk.data.find('tokenizers/punkt')
        except LookupError:
            nltk.download('punkt')

        try:
            nltk.data.find('corpora/stopwords')
        except LookupError:
            nltk.download('stopwords')

        self.stop_words = set(stopwords.words('english'))

        # Load medical vocabularies
        self.medical_entities = self._load_comprehensive_medical_vocabulary()

    def _load_comprehensive_medical_vocabulary(self) -> Dict[str, List[MedicalEntity]]:
        """Load comprehensive medical vocabulary from multiple sources"""
        logger.info("Loading comprehensive medical vocabulary...")

        vocabularies = {
            "drugs": self._load_drug_names(),
            "procedures": self._load_medical_procedures(),
            "anatomy": self._load_anatomy_terms(),
            "pathology": self._load_pathology_terms(),
            "measurements": self._load_clinical_measurements(),
            "abbreviations": self._load_medical_abbreviations(),
            "symptoms": self._load_symptom_terms(),
            "specialties": self._load_medical_specialties()
        }

        # Combine with terms from medical datasets
        dataset_terms = self._extract_terms_from_medical_datasets()
        vocabularies["dataset_derived"] = dataset_terms

        logger.info(f"Loaded medical vocabulary with {sum(len(v) for v in vocabularies.values())} terms")
        return vocabularies

    def _load_drug_names(self) -> List[MedicalEntity]:
        """Load pharmaceutical drug names and medications"""
        drugs = []

        # Common drug names
        common_drugs = [
            # Pain medications
            "acetaminophen", "ibuprofen", "aspirin", "naproxen", "tramadol", "oxycodone",
            "hydrocodone", "codeine", "morphine", "fentanyl", "celecoxib",

            # Antibiotics
            "amoxicillin", "azithromycin", "cephalexin", "ciprofloxacin", "clindamycin",
            "doxycycline", "erythromycin", "levofloxacin", "metronidazole", "penicillin",
            "trimethoprim", "sulfamethoxazole", "vancomycin", "ceftriaxone",

            # Cardiovascular
            "amlodipine", "atenolol", "carvedilol", "enalapril", "furosemide", "hydrochlorothiazide",
            "lisinopril", "losartan", "metoprolol", "propranolol", "simvastatin", "atorvastatin",
            "warfarin", "clopidogrel", "aspirin", "digoxin", "amiodarone",

            # Diabetes
            "metformin", "insulin", "glipizide", "glyburide", "pioglitazone", "sitagliptin",
            "empagliflozin", "liraglutide", "semaglutide",

            # Mental health
            "sertraline", "fluoxetine", "escitalopram", "citalopram", "paroxetine", "venlafaxine",
            "duloxetine", "bupropion", "trazodone", "lorazepam", "alprazolam", "clonazepam",
            "diazepam", "quetiapine", "risperidone", "aripiprazole", "lithium",

            # Respiratory
            "albuterol", "montelukast", "fluticasone", "budesonide", "prednisone", "prednisolone",
            "methylprednisolone", "dexamethasone",

            # Gastrointestinal
            "omeprazole", "lansoprazole", "esomeprazole", "ranitidine", "famotidine",
            "metoclopramide", "ondansetron", "loperamide", "docusate"
        ]

        for drug in common_drugs:
            drugs.append(MedicalEntity(
                term=drug,
                category="medication",
                context=["prescribed", "administered", "dosage", "mg", "ml"]
            ))

        # Add brand names and generic equivalents
        brand_generic_pairs = {
            "Tylenol": "acetaminophen",
            "Advil": "ibuprofen",
            "Motrin": "ibuprofen",
            "Aleve": "naproxen",
            "Lipitor": "atorvastatin",
            "Crestor": "rosuvastatin",
            "Nexium": "esomeprazole",
            "Prilosec": "omeprazole",
            "Zoloft": "sertraline",
            "Prozac": "fluoxetine",
            "Xanax": "alprazolam",
            "Ativan": "lorazepam",
            "Glucophage": "metformin",
            "Lantus": "insulin glargine",
            "Humalog": "insulin lispro"
        }

        for brand, generic in brand_generic_pairs.items():
            drugs.append(MedicalEntity(
                term=brand,
                category="medication_brand",
                synonyms=[generic],
                context=["prescribed", "brand name"]
            ))

        return drugs

    def _load_medical_procedures(self) -> List[MedicalEntity]:
        """Load medical procedures and treatments"""
        procedures = []

        procedure_terms = [
            # Diagnostic procedures
            "endoscopy", "colonoscopy", "bronchoscopy", "cystoscopy", "arthroscopy",
            "laparoscopy", "thoracoscopy", "hysteroscopy",

            # Imaging
            "radiography", "ultrasonography", "echocardiography", "mammography",
            "angiography", "myelography", "arthrography", "tomography",
            "CT scan", "MRI scan", "PET scan", "SPECT scan",

            # Surgical procedures
            "appendectomy", "cholecystectomy", "nephrectomy", "hysterectomy",
            "mastectomy", "prostatectomy", "tonsillectomy", "thyroidectomy",
            "craniotomy", "thoracotomy", "laparotomy", "arthrotomy",

            # Cardiac procedures
            "angioplasty", "stenting", "bypass", "catheterization", "ablation",
            "pacemaker", "defibrillator", "valvuloplasty", "endarterectomy",

            # Therapeutic procedures
            "intubation", "tracheostomy", "dialysis", "chemotherapy", "radiotherapy",
            "physiotherapy", "occupational therapy", "speech therapy",

            # Minor procedures
            "biopsy", "injection", "aspiration", "drainage", "suture", "cauterization",
            "cryotherapy", "electrocautery", "laser therapy"
        ]

        for procedure in procedure_terms:
            procedures.append(MedicalEntity(
                term=procedure,
                category="procedure",
                context=["performed", "underwent", "scheduled", "completed"]
            ))

        return procedures

    def _load_anatomy_terms(self) -> List[MedicalEntity]:
        """Load anatomical terms and body parts"""
        anatomy = []

        anatomical_terms = [
            # Cardiovascular system
            "myocardium", "pericardium", "endocardium", "septum", "ventricle", "atrium",
            "aorta", "vena cava", "pulmonary", "coronary", "carotid", "femoral",

            # Respiratory system
            "alveoli", "bronchi", "bronchioles", "trachea", "larynx", "pharynx",
            "diaphragm", "pleura", "mediastinum",

            # Digestive system
            "esophagus", "duodenum", "jejunum", "ileum", "cecum", "appendix",
            "hepatic", "pancreatic", "gallbladder", "sphincter",

            # Nervous system
            "cerebrum", "cerebellum", "brainstem", "meninges", "ventricles",
            "hippocampus", "amygdala", "thalamus", "hypothalamus", "pituitary",

            # Musculoskeletal system
            "vertebrae", "thoracic", "lumbar", "cervical", "sacral", "coccyx",
            "sternum", "ribs", "scapula", "clavicle", "humerus", "radius", "ulna",
            "femur", "tibia", "fibula", "patella",

            # Urogenital system
            "nephron", "glomerulus", "tubules", "ureter", "bladder", "urethra",
            "prostate", "ovaries", "fallopian", "uterus", "cervix", "vagina"
        ]

        for term in anatomical_terms:
            anatomy.append(MedicalEntity(
                term=term,
                category="anatomy",
                context=["examination", "palpation", "located", "region"]
            ))

        return anatomy

    def _load_pathology_terms(self) -> List[MedicalEntity]:
        """Load pathological conditions and diseases"""
        pathology = []

        pathological_terms = [
            # Cardiovascular diseases
            "myocardial infarction", "angina pectoris", "arrhythmia", "bradycardia",
            "tachycardia", "hypertension", "hypotension", "atherosclerosis",
            "thrombosis", "embolism", "ischemia", "cardiomyopathy",

            # Respiratory diseases
            "pneumonia", "bronchitis", "asthma", "COPD", "emphysema", "pneumothorax",
            "pulmonary edema", "respiratory failure", "bronchospasm",

            # Gastrointestinal diseases
            "gastritis", "peptic ulcer", "gastroesophageal reflux", "cholecystitis",
            "hepatitis", "cirrhosis", "pancreatitis", "inflammatory bowel disease",
            "Crohn's disease", "ulcerative colitis",

            # Neurological diseases
            "stroke", "transient ischemic attack", "seizure", "epilepsy", "migraine",
            "Parkinson's disease", "Alzheimer's disease", "multiple sclerosis",
            "neuropathy", "encephalitis", "meningitis",

            # Infectious diseases
            "sepsis", "bacteremia", "cellulitis", "pneumonia", "urinary tract infection",
            "endocarditis", "osteomyelitis", "abscess",

            # Endocrine diseases
            "diabetes mellitus", "hypothyroidism", "hyperthyroidism", "Cushing's syndrome",
            "Addison's disease", "hyperglycemia", "hypoglycemia"
        ]

        for term in pathological_terms:
            pathology.append(MedicalEntity(
                term=term,
                category="pathology",
                context=["diagnosed", "presents with", "history of", "symptoms"]
            ))

        return pathology

    def _load_clinical_measurements(self) -> List[MedicalEntity]:
        """Load clinical measurements and units"""
        measurements = []

        measurement_terms = [
            # Vital signs
            "blood pressure", "heart rate", "respiratory rate", "temperature",
            "oxygen saturation", "pulse oximetry", "SpO2",

            # Laboratory values
            "hemoglobin", "hematocrit", "white blood cell count", "platelet count",
            "glucose", "creatinine", "BUN", "electrolytes", "sodium", "potassium",
            "chloride", "CO2", "troponin", "CPK", "LDH", "ALT", "AST",
            "bilirubin", "alkaline phosphatase", "albumin", "protein",

            # Units
            "mmHg", "bpm", "mg/dL", "g/dL", "mEq/L", "mmol/L", "U/L", "ng/mL",
            "pg/mL", "IU/L", "celsius", "fahrenheit", "kilograms", "pounds",
            "centimeters", "inches", "milliliters", "liters"
        ]

        for term in measurement_terms:
            measurements.append(MedicalEntity(
                term=term,
                category="measurement",
                context=["measured", "recorded", "elevated", "decreased", "normal"]
            ))

        return measurements

    def _load_medical_abbreviations(self) -> List[MedicalEntity]:
        """Load medical abbreviations and acronyms"""
        abbreviations = []

        abbrev_dict = {
            # Vital signs and measurements
            "BP": "blood pressure",
            "HR": "heart rate",
            "RR": "respiratory rate",
            "T": "temperature",
            "O2 sat": "oxygen saturation",
            "BMI": "body mass index",

            # Laboratory tests
            "CBC": "complete blood count",
            "CMP": "comprehensive metabolic panel",
            "BMP": "basic metabolic panel",
            "LFT": "liver function tests",
            "ABG": "arterial blood gas",
            "UA": "urinalysis",
            "ESR": "erythrocyte sedimentation rate",
            "CRP": "C-reactive protein",
            "PT": "prothrombin time",
            "PTT": "partial thromboplastin time",
            "INR": "international normalized ratio",

            # Imaging
            "CXR": "chest X-ray",
            "CT": "computed tomography",
            "MRI": "magnetic resonance imaging",
            "US": "ultrasound",
            "Echo": "echocardiogram",
            "EKG": "electrocardiogram",
            "ECG": "electrocardiogram",
            "EEG": "electroencephalogram",

            # Medical conditions
            "HTN": "hypertension",
            "DM": "diabetes mellitus",
            "CAD": "coronary artery disease",
            "CHF": "congestive heart failure",
            "COPD": "chronic obstructive pulmonary disease",
            "UTI": "urinary tract infection",
            "DVT": "deep vein thrombosis",
            "PE": "pulmonary embolism",
            "MI": "myocardial infarction",
            "TIA": "transient ischemic attack",
            "CVA": "cerebrovascular accident",

            # Routes and frequencies
            "PO": "by mouth",
            "IV": "intravenous",
            "IM": "intramuscular",
            "SQ": "subcutaneous",
            "BID": "twice daily",
            "TID": "three times daily",
            "QID": "four times daily",
            "PRN": "as needed",
            "QHS": "at bedtime",
            "NPO": "nothing by mouth"
        }

        for abbrev, full_form in abbrev_dict.items():
            abbreviations.append(MedicalEntity(
                term=abbrev,
                category="abbreviation",
                synonyms=[full_form],
                context=["abbreviated", "stands for"]
            ))

        return abbreviations

    def _load_symptom_terms(self) -> List[MedicalEntity]:
        """Load symptom and complaint terms"""
        symptoms = []

        symptom_terms = [
            # Pain descriptors
            "sharp", "dull", "throbbing", "stabbing", "burning", "aching",
            "cramping", "shooting", "radiating", "constant", "intermittent",

            # General symptoms
            "fatigue", "weakness", "malaise", "fever", "chills", "sweats",
            "nausea", "vomiting", "diarrhea", "constipation", "headache",
            "dizziness", "vertigo", "syncope", "palpitations",

            # Respiratory symptoms
            "dyspnea", "shortness of breath", "wheezing", "cough", "sputum",
            "hemoptysis", "chest pain", "pleuritic",

            # Gastrointestinal symptoms
            "abdominal pain", "bloating", "heartburn", "regurgitation",
            "dysphagia", "odynophagia", "melena", "hematochezia",

            # Neurological symptoms
            "confusion", "memory loss", "seizure", "tremor", "numbness",
            "tingling", "weakness", "paralysis", "aphasia", "dysarthria",

            # Psychiatric symptoms
            "anxiety", "depression", "insomnia", "hallucinations",
            "delusions", "agitation", "mood changes"
        ]

        for term in symptom_terms:
            symptoms.append(MedicalEntity(
                term=term,
                category="symptom",
                context=["reports", "complains of", "experiences", "describes"]
            ))

        return symptoms

    def _load_medical_specialties(self) -> List[MedicalEntity]:
        """Load medical specialty terms"""
        specialties = []

        specialty_terms = [
            "cardiology", "neurology", "pulmonology", "gastroenterology",
            "endocrinology", "nephrology", "rheumatology", "hematology",
            "oncology", "dermatology", "psychiatry", "pediatrics",
            "geriatrics", "emergency medicine", "internal medicine",
            "family medicine", "surgery", "anesthesiology", "radiology",
            "pathology", "ophthalmology", "otolaryngology", "urology",
            "gynecology", "obstetrics", "orthopedics", "plastic surgery"
        ]

        for term in specialty_terms:
            specialties.append(MedicalEntity(
                term=term,
                category="specialty",
                context=["consultation", "referral", "specialist"]
            ))

        return specialties

    def _extract_terms_from_medical_datasets(self) -> List[MedicalEntity]:
        """Extract medical terms from existing medical datasets"""
        dataset_terms = []

        # Try to load from MTS-Dialog dataset
        try:
            from pathlib import Path
            mts_path = Path("../MedicalDatasets/MTS-Dialog")

            if mts_path.exists():
                import pandas as pd

                for csv_file in mts_path.glob("*.csv"):
                    try:
                        df = pd.read_csv(csv_file)

                        # Extract text from conversations
                        text_columns = ['conversation', 'text', 'dialogue', 'transcript']
                        text_data = []

                        for col in text_columns:
                            if col in df.columns:
                                text_data.extend(df[col].dropna().tolist())

                        # Extract medical terms from text
                        for text in text_data:
                            terms = self._extract_medical_terms_from_text(str(text))
                            dataset_terms.extend(terms)

                    except Exception as e:
                        logger.warning(f"Could not process {csv_file}: {e}")

        except Exception as e:
            logger.warning(f"Could not extract terms from medical datasets: {e}")

        # Remove duplicates and return
        unique_terms = {}
        for term in dataset_terms:
            if term.term not in unique_terms:
                unique_terms[term.term] = term
            else:
                unique_terms[term.term].frequency += term.frequency

        return list(unique_terms.values())

    def _extract_medical_terms_from_text(self, text: str) -> List[MedicalEntity]:
        """Extract medical terms from free text"""
        terms = []

        # Tokenize and clean text
        tokens = word_tokenize(text.lower())
        tokens = [token for token in tokens if token.isalpha() and token not in self.stop_words]

        # Look for medical patterns
        medical_patterns = [
            r'\b\d+\s?(mg|ml|mcg|g|kg|cc|units?)\b',  # Dosages
            r'\b\d+\s?(mmHg|bpm|degrees?)\b',  # Measurements
            r'\b[A-Z]{2,6}\b',  # Medical abbreviations
            r'\b\w+itis\b',  # Inflammatory conditions
            r'\b\w+ectomy\b',  # Surgical procedures
            r'\b\w+oscopy\b',  # Diagnostic procedures
        ]

        for pattern in medical_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for match in matches:
                if isinstance(match, tuple):
                    term = ' '.join(match)
                else:
                    term = match

                terms.append(MedicalEntity(
                    term=term,
                    category="extracted",
                    frequency=1
                ))

        return terms

    def extract_medical_entities(self, text: str) -> Dict:
        """Extract medical entities from text with categories"""
        entities = {
            "medications": [],
            "procedures": [],
            "conditions": [],
            "anatomy": [],
            "measurements": [],
            "abbreviations": []
        }

        text_lower = text.lower()

        # Search for each category of medical terms
        for category, medical_entities in self.medical_entities.items():
            for entity in medical_entities:
                if entity.term.lower() in text_lower:
                    if category in ["drugs"]:
                        entities["medications"].append(entity.term)
                    elif category in ["procedures"]:
                        entities["procedures"].append(entity.term)
                    elif category in ["pathology", "symptoms"]:
                        entities["conditions"].append(entity.term)
                    elif category in ["anatomy"]:
                        entities["anatomy"].append(entity.term)
                    elif category in ["measurements"]:
                        entities["measurements"].append(entity.term)
                    elif category in ["abbreviations"]:
                        entities["abbreviations"].append(entity.term)

        return entities

    def get_medical_terms(self, max_terms: int = 10000) -> List[str]:
        """Get list of medical terms for vocabulary enhancement"""
        all_terms = []

        for category, entities in self.medical_entities.items():
            for entity in entities:
                all_terms.append(entity.term)
                all_terms.extend(entity.synonyms)

        # Sort by frequency and relevance
        term_counts = Counter(all_terms)
        sorted_terms = [term for term, count in term_counts.most_common(max_terms)]

        logger.info(f"Returning {len(sorted_terms)} medical terms for vocabulary enhancement")
        return sorted_terms

    def get_contextual_terms(self, category: str) -> List[Tuple[str, List[str]]]:
        """Get terms with their contextual usage patterns"""
        if category not in self.medical_entities:
            return []

        contextual_terms = []
        for entity in self.medical_entities[category]:
            contextual_terms.append((entity.term, entity.context))

        return contextual_terms

    def save_vocabulary(self, filepath: str):
        """Save enhanced vocabulary to file"""
        vocab_data = {}

        for category, entities in self.medical_entities.items():
            vocab_data[category] = []
            for entity in entities:
                vocab_data[category].append({
                    "term": entity.term,
                    "category": entity.category,
                    "frequency": entity.frequency,
                    "synonyms": entity.synonyms,
                    "context": entity.context
                })

        with open(filepath, 'w') as f:
            json.dump(vocab_data, f, indent=2)

        logger.info(f"Medical vocabulary saved to {filepath}")

    def load_vocabulary(self, filepath: str):
        """Load enhanced vocabulary from file"""
        with open(filepath, 'r') as f:
            vocab_data = json.load(f)

        self.medical_entities = {}
        for category, entities_data in vocab_data.items():
            self.medical_entities[category] = []
            for entity_data in entities_data:
                entity = MedicalEntity(
                    term=entity_data["term"],
                    category=entity_data["category"],
                    frequency=entity_data["frequency"],
                    synonyms=entity_data.get("synonyms", []),
                    context=entity_data.get("context", [])
                )
                self.medical_entities[category].append(entity)

        logger.info(f"Medical vocabulary loaded from {filepath}")

def main():
    """Test the medical vocabulary enhancer"""
    enhancer = MedicalVocabularyEnhancer()

    # Test term extraction
    test_text = """
    Patient presents with chest pain and shortness of breath.
    Given 5mg of morphine IV. Blood pressure is 150/90 mmHg.
    Ordered CBC, CMP, and troponin levels.
    EKG shows normal sinus rhythm.
    """

    entities = enhancer.extract_medical_entities(test_text)
    print("Extracted medical entities:")
    for category, terms in entities.items():
        if terms:
            print(f"  {category}: {terms}")

    # Get medical terms for vocabulary enhancement
    medical_terms = enhancer.get_medical_terms(max_terms=100)
    print(f"\nFirst 20 medical terms: {medical_terms[:20]}")

    # Save vocabulary
    enhancer.save_vocabulary("medical_vocabulary.json")

if __name__ == "__main__":
    main()