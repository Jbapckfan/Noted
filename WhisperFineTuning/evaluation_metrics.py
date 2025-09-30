#!/usr/bin/env python3
"""
Medical Transcription Evaluation Metrics
========================================

Comprehensive evaluation suite for medical transcription accuracy, specifically designed
to measure performance on medical terminology, clinical context, and domain-specific accuracy.

Key Metrics:
1. Medical Word Error Rate (Medical WER) - Weights medical terms more heavily
2. Medical BLEU Score - Considers medical phrase structure
3. Medical Term Accuracy - Precision/recall for medical terminology
4. Clinical Coherence Score - Evaluates clinical logic and flow
5. Dosage Accuracy - Specific to medication dosages and measurements
6. Anatomy Recognition Rate - Anatomical term recognition accuracy
7. Procedure Accuracy - Medical procedure identification accuracy

This evaluation framework ensures that fine-tuned models achieve clinical-grade
accuracy suitable for healthcare applications.
"""

import re
import json
import logging
from typing import List, Dict, Tuple, Set, Optional, Union
from dataclasses import dataclass
from collections import defaultdict, Counter
from pathlib import Path

import numpy as np
from sklearn.metrics import precision_recall_fscore_support
import nltk
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
from nltk.metrics import distance
from nltk.tokenize import word_tokenize

from medical_vocabulary import MedicalVocabularyEnhancer

logger = logging.getLogger(__name__)

@dataclass
class TranscriptionMetrics:
    """Container for transcription evaluation metrics"""
    medical_wer: float = 0.0
    standard_wer: float = 0.0
    medical_bleu: float = 0.0
    medical_term_accuracy: float = 0.0
    clinical_coherence: float = 0.0
    dosage_accuracy: float = 0.0
    anatomy_accuracy: float = 0.0
    procedure_accuracy: float = 0.0
    overall_score: float = 0.0

    # Detailed breakdowns
    medical_term_precision: float = 0.0
    medical_term_recall: float = 0.0
    medical_term_f1: float = 0.0

    # Error analysis
    insertion_errors: int = 0
    deletion_errors: int = 0
    substitution_errors: int = 0
    medical_term_errors: int = 0

@dataclass
class MedicalError:
    """Represents a specific medical transcription error"""
    error_type: str  # 'substitution', 'insertion', 'deletion', 'medical_term'
    reference_word: str
    hypothesis_word: str
    position: int
    category: str  # 'drug', 'procedure', 'anatomy', etc.
    severity: str  # 'critical', 'major', 'minor'

class MedicalTranscriptionEvaluator:
    """Comprehensive evaluator for medical transcription quality"""

    def __init__(self, weights_config: Optional[Dict] = None):
        """
        Initialize evaluator with configurable weights

        Args:
            weights_config: Dictionary containing weights for different error types
        """
        self.medical_vocab = MedicalVocabularyEnhancer()

        # Default weights for different types of errors
        self.weights = {
            'medical_term': 3.0,      # Medical terms are 3x more important
            'dosage': 5.0,            # Dosage errors are critical (5x weight)
            'anatomy': 2.5,           # Anatomical terms are important
            'procedure': 3.5,         # Procedures are very important
            'standard_word': 1.0,     # Standard words have base weight
            'function_word': 0.5      # Function words are less important
        }

        if weights_config:
            self.weights.update(weights_config)

        # Medical term categories for specialized evaluation
        self.medical_categories = self._build_medical_category_sets()

        # Critical terms that must be transcribed correctly
        self.critical_terms = self._build_critical_terms_set()

        # Initialize NLTK components
        try:
            nltk.data.find('tokenizers/punkt')
        except LookupError:
            nltk.download('punkt')

    def _build_medical_category_sets(self) -> Dict[str, Set[str]]:
        """Build sets of medical terms by category"""
        categories = {}

        for category, entities in self.medical_vocab.medical_entities.items():
            term_set = set()
            for entity in entities:
                term_set.add(entity.term.lower())
                term_set.update([syn.lower() for syn in entity.synonyms])
            categories[category] = term_set

        return categories

    def _build_critical_terms_set(self) -> Set[str]:
        """Build set of critical medical terms that must be accurate"""
        critical = set()

        # Dosage-related terms
        critical.update(['mg', 'ml', 'mcg', 'units', 'tablets', 'capsules', 'grams'])

        # Critical conditions
        critical.update(['myocardial infarction', 'stroke', 'sepsis', 'anaphylaxis',
                        'pneumonia', 'diabetes', 'hypertension', 'heart attack'])

        # Critical procedures
        critical.update(['surgery', 'intubation', 'defibrillation', 'cpr',
                        'blood transfusion', 'dialysis'])

        # Critical medications
        critical.update(['epinephrine', 'insulin', 'morphine', 'warfarin',
                        'digoxin', 'chemotherapy'])

        return critical

    def evaluate_single(self, reference: str, hypothesis: str) -> TranscriptionMetrics:
        """Evaluate a single transcription against reference"""
        # Tokenize and normalize
        ref_tokens = self._tokenize_and_normalize(reference)
        hyp_tokens = self._tokenize_and_normalize(hypothesis)

        # Calculate standard WER
        standard_wer = self._calculate_wer(ref_tokens, hyp_tokens)

        # Calculate medical WER (weighted)
        medical_wer = self._calculate_medical_wer(ref_tokens, hyp_tokens)

        # Calculate BLEU score with medical focus
        medical_bleu = self._calculate_medical_bleu(ref_tokens, hyp_tokens)

        # Calculate medical term accuracy
        med_term_metrics = self._calculate_medical_term_accuracy(ref_tokens, hyp_tokens)

        # Calculate clinical coherence
        clinical_coherence = self._calculate_clinical_coherence(reference, hypothesis)

        # Calculate specialized accuracies
        dosage_accuracy = self._calculate_dosage_accuracy(ref_tokens, hyp_tokens)
        anatomy_accuracy = self._calculate_category_accuracy(ref_tokens, hyp_tokens, 'anatomy')
        procedure_accuracy = self._calculate_category_accuracy(ref_tokens, hyp_tokens, 'procedures')

        # Calculate overall score
        overall_score = self._calculate_overall_score(
            medical_wer, medical_bleu, med_term_metrics['f1'],
            clinical_coherence, dosage_accuracy
        )

        # Detailed error analysis
        errors = self._analyze_errors(ref_tokens, hyp_tokens)

        return TranscriptionMetrics(
            medical_wer=medical_wer,
            standard_wer=standard_wer,
            medical_bleu=medical_bleu,
            medical_term_accuracy=med_term_metrics['accuracy'],
            medical_term_precision=med_term_metrics['precision'],
            medical_term_recall=med_term_metrics['recall'],
            medical_term_f1=med_term_metrics['f1'],
            clinical_coherence=clinical_coherence,
            dosage_accuracy=dosage_accuracy,
            anatomy_accuracy=anatomy_accuracy,
            procedure_accuracy=procedure_accuracy,
            overall_score=overall_score,
            insertion_errors=errors['insertions'],
            deletion_errors=errors['deletions'],
            substitution_errors=errors['substitutions'],
            medical_term_errors=errors['medical_errors']
        )

    def evaluate_batch(self, references: List[str], hypotheses: List[str]) -> Dict:
        """Evaluate a batch of transcriptions"""
        if len(references) != len(hypotheses):
            raise ValueError("References and hypotheses must have same length")

        all_metrics = []
        detailed_errors = []

        for ref, hyp in zip(references, hypotheses):
            metrics = self.evaluate_single(ref, hyp)
            all_metrics.append(metrics)

            # Collect detailed errors for analysis
            errors = self._get_detailed_errors(ref, hyp)
            detailed_errors.extend(errors)

        # Aggregate metrics
        aggregated = self._aggregate_metrics(all_metrics)

        # Add error analysis
        aggregated['error_analysis'] = self._analyze_error_patterns(detailed_errors)
        aggregated['sample_count'] = len(references)

        return aggregated

    def _tokenize_and_normalize(self, text: str) -> List[str]:
        """Tokenize and normalize text for evaluation"""
        # Convert to lowercase and tokenize
        tokens = word_tokenize(text.lower())

        # Normalize medical abbreviations
        normalized_tokens = []
        for token in tokens:
            # Handle common medical abbreviations
            normalized_token = self._normalize_medical_token(token)
            normalized_tokens.append(normalized_token)

        return normalized_tokens

    def _normalize_medical_token(self, token: str) -> str:
        """Normalize medical tokens for consistent evaluation"""
        # Handle unit variations
        unit_mappings = {
            'milligrams': 'mg',
            'milligram': 'mg',
            'milliliters': 'ml',
            'milliliter': 'ml',
            'micrograms': 'mcg',
            'microgram': 'mcg',
            'kilograms': 'kg',
            'kilogram': 'kg'
        }

        if token in unit_mappings:
            return unit_mappings[token]

        # Handle common medical term variations
        medical_mappings = {
            'heart attack': 'myocardial infarction',
            'high blood pressure': 'hypertension',
            'sugar diabetes': 'diabetes mellitus'
        }

        return medical_mappings.get(token, token)

    def _calculate_wer(self, reference: List[str], hypothesis: List[str]) -> float:
        """Calculate standard Word Error Rate"""
        if not reference:
            return 1.0 if hypothesis else 0.0

        # Calculate edit distance
        edit_distance = distance.edit_distance(reference, hypothesis)

        # WER = edit_distance / reference_length
        wer = edit_distance / len(reference)

        return min(wer, 1.0)  # Cap at 1.0

    def _calculate_medical_wer(self, reference: List[str], hypothesis: List[str]) -> float:
        """Calculate weighted WER with emphasis on medical terms"""
        if not reference:
            return 1.0 if hypothesis else 0.0

        # Create alignment using dynamic programming
        alignment = self._align_sequences(reference, hypothesis)

        total_weight = 0.0
        error_weight = 0.0

        for ref_token, hyp_token in alignment:
            # Determine weight based on term type
            weight = self._get_token_weight(ref_token)
            total_weight += weight

            # Check for error
            if ref_token != hyp_token:
                error_weight += weight

        return error_weight / total_weight if total_weight > 0 else 0.0

    def _get_token_weight(self, token: str) -> float:
        """Get weight for a token based on its medical importance"""
        if not token:
            return 0.0

        token_lower = token.lower()

        # Critical terms get highest weight
        if token_lower in self.critical_terms:
            return self.weights['dosage']

        # Check medical categories
        if token_lower in self.medical_categories.get('drugs', set()):
            return self.weights['medical_term']

        if token_lower in self.medical_categories.get('procedures', set()):
            return self.weights['procedure']

        if token_lower in self.medical_categories.get('anatomy', set()):
            return self.weights['anatomy']

        # Check if it's a dosage pattern
        if re.match(r'^\d+(\.\d+)?(mg|ml|mcg|g|kg|units?)$', token_lower):
            return self.weights['dosage']

        # Function words get lower weight
        function_words = {'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'}
        if token_lower in function_words:
            return self.weights['function_word']

        # Default weight for standard words
        return self.weights['standard_word']

    def _align_sequences(self, reference: List[str], hypothesis: List[str]) -> List[Tuple[str, str]]:
        """Align sequences using dynamic programming for optimal matching"""
        ref_len = len(reference)
        hyp_len = len(hypothesis)

        # Initialize DP table
        dp = [[0] * (hyp_len + 1) for _ in range(ref_len + 1)]

        # Fill DP table
        for i in range(ref_len + 1):
            for j in range(hyp_len + 1):
                if i == 0:
                    dp[i][j] = j  # All insertions
                elif j == 0:
                    dp[i][j] = i  # All deletions
                else:
                    if reference[i-1] == hypothesis[j-1]:
                        dp[i][j] = dp[i-1][j-1]  # Match
                    else:
                        dp[i][j] = 1 + min(
                            dp[i-1][j],      # Deletion
                            dp[i][j-1],      # Insertion
                            dp[i-1][j-1]     # Substitution
                        )

        # Backtrack to find alignment
        alignment = []
        i, j = ref_len, hyp_len

        while i > 0 or j > 0:
            if i > 0 and j > 0 and reference[i-1] == hypothesis[j-1]:
                alignment.append((reference[i-1], hypothesis[j-1]))
                i -= 1
                j -= 1
            elif i > 0 and j > 0 and dp[i][j] == dp[i-1][j-1] + 1:
                alignment.append((reference[i-1], hypothesis[j-1]))  # Substitution
                i -= 1
                j -= 1
            elif i > 0 and dp[i][j] == dp[i-1][j] + 1:
                alignment.append((reference[i-1], ""))  # Deletion
                i -= 1
            else:
                alignment.append(("", hypothesis[j-1]))  # Insertion
                j -= 1

        return list(reversed(alignment))

    def _calculate_medical_bleu(self, reference: List[str], hypothesis: List[str]) -> float:
        """Calculate BLEU score with medical phrase emphasis"""
        if not reference or not hypothesis:
            return 0.0

        # Standard BLEU calculation
        smoothing = SmoothingFunction()

        # Calculate with different n-gram weights to emphasize medical phrases
        weights = (0.4, 0.3, 0.2, 0.1)  # Emphasize unigrams and bigrams

        try:
            bleu_score = sentence_bleu(
                [reference], hypothesis,
                weights=weights,
                smoothing_function=smoothing.method1
            )
            return bleu_score
        except:
            return 0.0

    def _calculate_medical_term_accuracy(self, reference: List[str], hypothesis: List[str]) -> Dict[str, float]:
        """Calculate precision, recall, and F1 for medical terms"""
        # Extract medical terms from both sequences
        ref_medical = set()
        hyp_medical = set()

        for token in reference:
            if self._is_medical_term(token):
                ref_medical.add(token.lower())

        for token in hypothesis:
            if self._is_medical_term(token):
                hyp_medical.add(token.lower())

        # Calculate metrics
        if not ref_medical and not hyp_medical:
            return {'precision': 1.0, 'recall': 1.0, 'f1': 1.0, 'accuracy': 1.0}

        if not ref_medical:
            return {'precision': 0.0, 'recall': 1.0, 'f1': 0.0, 'accuracy': 0.0}

        if not hyp_medical:
            return {'precision': 1.0, 'recall': 0.0, 'f1': 0.0, 'accuracy': 0.0}

        true_positives = len(ref_medical.intersection(hyp_medical))
        precision = true_positives / len(hyp_medical)
        recall = true_positives / len(ref_medical)

        f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0.0
        accuracy = true_positives / len(ref_medical.union(hyp_medical))

        return {
            'precision': precision,
            'recall': recall,
            'f1': f1,
            'accuracy': accuracy
        }

    def _is_medical_term(self, token: str) -> bool:
        """Check if a token is a medical term"""
        token_lower = token.lower()

        # Check all medical categories
        for category_set in self.medical_categories.values():
            if token_lower in category_set:
                return True

        # Check if it matches medical patterns
        medical_patterns = [
            r'^\d+(\.\d+)?(mg|ml|mcg|g|kg|units?)$',  # Dosages
            r'^\w+itis$',  # Inflammatory conditions
            r'^\w+ectomy$',  # Surgical procedures
            r'^\w+oscopy$',  # Diagnostic procedures
        ]

        for pattern in medical_patterns:
            if re.match(pattern, token_lower):
                return True

        return False

    def _calculate_clinical_coherence(self, reference: str, hypothesis: str) -> float:
        """Evaluate clinical coherence and logical flow"""
        # Extract medical context from both texts
        ref_entities = self.medical_vocab.extract_medical_entities(reference)
        hyp_entities = self.medical_vocab.extract_medical_entities(hypothesis)

        coherence_score = 0.0
        total_checks = 0

        # Check medication-dosage consistency
        coherence_score += self._check_medication_dosage_coherence(ref_entities, hyp_entities)
        total_checks += 1

        # Check symptom-diagnosis coherence
        coherence_score += self._check_symptom_diagnosis_coherence(reference, hypothesis)
        total_checks += 1

        # Check temporal consistency
        coherence_score += self._check_temporal_consistency(reference, hypothesis)
        total_checks += 1

        # Check anatomical consistency
        coherence_score += self._check_anatomical_consistency(ref_entities, hyp_entities)
        total_checks += 1

        return coherence_score / total_checks if total_checks > 0 else 0.0

    def _check_medication_dosage_coherence(self, ref_entities: Dict, hyp_entities: Dict) -> float:
        """Check if medications are mentioned with appropriate dosages"""
        ref_meds = set(ref_entities.get('medications', []))
        hyp_meds = set(hyp_entities.get('medications', []))

        ref_measurements = set(ref_entities.get('measurements', []))
        hyp_measurements = set(hyp_entities.get('measurements', []))

        # If medications are mentioned, there should be dosage information
        score = 1.0

        if ref_meds and not ref_measurements:
            if hyp_meds and not hyp_measurements:
                score = 1.0  # Both missing dosages consistently
            else:
                score = 0.5  # Hypothesis added dosages
        elif ref_meds and ref_measurements:
            if hyp_meds and hyp_measurements:
                score = 1.0  # Both have medication-dosage pairs
            else:
                score = 0.3  # Hypothesis missing dosages

        return score

    def _check_symptom_diagnosis_coherence(self, reference: str, hypothesis: str) -> float:
        """Check logical consistency between symptoms and diagnoses"""
        # Simple pattern matching for common symptom-diagnosis pairs
        coherent_pairs = {
            'chest pain': ['myocardial infarction', 'angina', 'heart attack'],
            'shortness of breath': ['asthma', 'copd', 'pneumonia', 'heart failure'],
            'headache': ['migraine', 'tension headache', 'hypertension'],
            'fever': ['infection', 'pneumonia', 'flu', 'sepsis']
        }

        ref_lower = reference.lower()
        hyp_lower = hypothesis.lower()

        coherence_count = 0
        total_symptoms = 0

        for symptom, diagnoses in coherent_pairs.items():
            if symptom in ref_lower:
                total_symptoms += 1
                ref_has_diagnosis = any(dx in ref_lower for dx in diagnoses)
                hyp_has_diagnosis = any(dx in hyp_lower for dx in diagnoses)

                if ref_has_diagnosis == hyp_has_diagnosis:
                    coherence_count += 1

        return coherence_count / total_symptoms if total_symptoms > 0 else 1.0

    def _check_temporal_consistency(self, reference: str, hypothesis: str) -> float:
        """Check consistency of temporal references"""
        temporal_patterns = [
            r'\b(yesterday|today|tomorrow)\b',
            r'\b\d+\s+(days?|weeks?|months?|years?)\b',
            r'\b(morning|afternoon|evening|night)\b',
            r'\b\d{1,2}:\d{2}\b'  # Time patterns
        ]

        ref_temporals = set()
        hyp_temporals = set()

        for pattern in temporal_patterns:
            ref_temporals.update(re.findall(pattern, reference.lower()))
            hyp_temporals.update(re.findall(pattern, hypothesis.lower()))

        if not ref_temporals and not hyp_temporals:
            return 1.0

        if not ref_temporals or not hyp_temporals:
            return 0.5

        intersection = ref_temporals.intersection(hyp_temporals)
        union = ref_temporals.union(hyp_temporals)

        return len(intersection) / len(union) if union else 1.0

    def _check_anatomical_consistency(self, ref_entities: Dict, hyp_entities: Dict) -> float:
        """Check consistency of anatomical references"""
        ref_anatomy = set(ref_entities.get('anatomy', []))
        hyp_anatomy = set(hyp_entities.get('anatomy', []))

        if not ref_anatomy and not hyp_anatomy:
            return 1.0

        if not ref_anatomy or not hyp_anatomy:
            return 0.5

        intersection = ref_anatomy.intersection(hyp_anatomy)
        union = ref_anatomy.union(hyp_anatomy)

        return len(intersection) / len(union) if union else 1.0

    def _calculate_dosage_accuracy(self, reference: List[str], hypothesis: List[str]) -> float:
        """Calculate accuracy specifically for dosage information"""
        dosage_pattern = r'\b\d+(\.\d+)?\s*(mg|ml|mcg|g|kg|units?|tablets?|capsules?)\b'

        ref_dosages = set(re.findall(dosage_pattern, ' '.join(reference), re.IGNORECASE))
        hyp_dosages = set(re.findall(dosage_pattern, ' '.join(hypothesis), re.IGNORECASE))

        if not ref_dosages and not hyp_dosages:
            return 1.0

        if not ref_dosages or not hyp_dosages:
            return 0.0

        # Convert tuples to strings for comparison
        ref_dosage_strs = set(''.join(dosage) for dosage in ref_dosages)
        hyp_dosage_strs = set(''.join(dosage) for dosage in hyp_dosages)

        intersection = ref_dosage_strs.intersection(hyp_dosage_strs)
        union = ref_dosage_strs.union(hyp_dosage_strs)

        return len(intersection) / len(union) if union else 0.0

    def _calculate_category_accuracy(self, reference: List[str], hypothesis: List[str], category: str) -> float:
        """Calculate accuracy for a specific medical category"""
        if category not in self.medical_categories:
            return 0.0

        category_terms = self.medical_categories[category]

        ref_terms = set(token.lower() for token in reference if token.lower() in category_terms)
        hyp_terms = set(token.lower() for token in hypothesis if token.lower() in category_terms)

        if not ref_terms and not hyp_terms:
            return 1.0

        if not ref_terms or not hyp_terms:
            return 0.0

        intersection = ref_terms.intersection(hyp_terms)
        union = ref_terms.union(hyp_terms)

        return len(intersection) / len(union) if union else 0.0

    def _calculate_overall_score(self, medical_wer: float, medical_bleu: float,
                                medical_term_f1: float, clinical_coherence: float,
                                dosage_accuracy: float) -> float:
        """Calculate weighted overall score"""
        # Convert WER to accuracy (1 - WER)
        medical_accuracy = 1.0 - medical_wer

        # Weighted combination
        weights = {
            'medical_accuracy': 0.3,
            'medical_bleu': 0.2,
            'medical_term_f1': 0.25,
            'clinical_coherence': 0.15,
            'dosage_accuracy': 0.1
        }

        overall = (
            weights['medical_accuracy'] * medical_accuracy +
            weights['medical_bleu'] * medical_bleu +
            weights['medical_term_f1'] * medical_term_f1 +
            weights['clinical_coherence'] * clinical_coherence +
            weights['dosage_accuracy'] * dosage_accuracy
        )

        return overall

    def _analyze_errors(self, reference: List[str], hypothesis: List[str]) -> Dict[str, int]:
        """Analyze error types in detail"""
        alignment = self._align_sequences(reference, hypothesis)

        errors = {
            'insertions': 0,
            'deletions': 0,
            'substitutions': 0,
            'medical_errors': 0
        }

        for ref_token, hyp_token in alignment:
            if ref_token and not hyp_token:
                errors['deletions'] += 1
                if self._is_medical_term(ref_token):
                    errors['medical_errors'] += 1
            elif not ref_token and hyp_token:
                errors['insertions'] += 1
                if self._is_medical_term(hyp_token):
                    errors['medical_errors'] += 1
            elif ref_token != hyp_token:
                errors['substitutions'] += 1
                if self._is_medical_term(ref_token) or self._is_medical_term(hyp_token):
                    errors['medical_errors'] += 1

        return errors

    def _get_detailed_errors(self, reference: str, hypothesis: str) -> List[MedicalError]:
        """Get detailed error analysis for pattern recognition"""
        ref_tokens = self._tokenize_and_normalize(reference)
        hyp_tokens = self._tokenize_and_normalize(hypothesis)
        alignment = self._align_sequences(ref_tokens, hyp_tokens)

        detailed_errors = []

        for i, (ref_token, hyp_token) in enumerate(alignment):
            if ref_token != hyp_token:
                error_type = 'substitution'
                if not ref_token:
                    error_type = 'insertion'
                elif not hyp_token:
                    error_type = 'deletion'

                # Determine category and severity
                category = self._get_token_category(ref_token or hyp_token)
                severity = self._get_error_severity(ref_token, hyp_token, category)

                error = MedicalError(
                    error_type=error_type,
                    reference_word=ref_token or '',
                    hypothesis_word=hyp_token or '',
                    position=i,
                    category=category,
                    severity=severity
                )
                detailed_errors.append(error)

        return detailed_errors

    def _get_token_category(self, token: str) -> str:
        """Get the medical category of a token"""
        if not token:
            return 'unknown'

        token_lower = token.lower()

        for category, terms in self.medical_categories.items():
            if token_lower in terms:
                return category

        if re.match(r'^\d+(\.\d+)?(mg|ml|mcg|g|kg|units?)$', token_lower):
            return 'dosage'

        return 'general'

    def _get_error_severity(self, ref_token: str, hyp_token: str, category: str) -> str:
        """Determine error severity based on context"""
        if category == 'dosage' or (ref_token and ref_token.lower() in self.critical_terms):
            return 'critical'

        if category in ['drugs', 'procedures']:
            return 'major'

        if category in ['anatomy', 'pathology']:
            return 'major'

        return 'minor'

    def _aggregate_metrics(self, metrics_list: List[TranscriptionMetrics]) -> Dict:
        """Aggregate metrics across multiple transcriptions"""
        if not metrics_list:
            return {}

        # Calculate means
        aggregated = {
            'medical_wer': np.mean([m.medical_wer for m in metrics_list]),
            'standard_wer': np.mean([m.standard_wer for m in metrics_list]),
            'medical_bleu': np.mean([m.medical_bleu for m in metrics_list]),
            'medical_term_accuracy': np.mean([m.medical_term_accuracy for m in metrics_list]),
            'medical_term_precision': np.mean([m.medical_term_precision for m in metrics_list]),
            'medical_term_recall': np.mean([m.medical_term_recall for m in metrics_list]),
            'medical_term_f1': np.mean([m.medical_term_f1 for m in metrics_list]),
            'clinical_coherence': np.mean([m.clinical_coherence for m in metrics_list]),
            'dosage_accuracy': np.mean([m.dosage_accuracy for m in metrics_list]),
            'anatomy_accuracy': np.mean([m.anatomy_accuracy for m in metrics_list]),
            'procedure_accuracy': np.mean([m.procedure_accuracy for m in metrics_list]),
            'overall_score': np.mean([m.overall_score for m in metrics_list]),
        }

        # Calculate standard deviations
        for key in aggregated.keys():
            values = [getattr(m, key) for m in metrics_list]
            aggregated[f'{key}_std'] = np.std(values)

        # Error totals
        aggregated['total_insertions'] = sum(m.insertion_errors for m in metrics_list)
        aggregated['total_deletions'] = sum(m.deletion_errors for m in metrics_list)
        aggregated['total_substitutions'] = sum(m.substitution_errors for m in metrics_list)
        aggregated['total_medical_errors'] = sum(m.medical_term_errors for m in metrics_list)

        return aggregated

    def _analyze_error_patterns(self, errors: List[MedicalError]) -> Dict:
        """Analyze error patterns for improvement insights"""
        if not errors:
            return {}

        analysis = {
            'error_distribution': Counter(error.error_type for error in errors),
            'category_errors': Counter(error.category for error in errors),
            'severity_distribution': Counter(error.severity for error in errors),
            'common_substitutions': defaultdict(list),
            'problematic_categories': []
        }

        # Analyze substitution patterns
        for error in errors:
            if error.error_type == 'substitution':
                analysis['common_substitutions'][error.reference_word].append(error.hypothesis_word)

        # Find problematic categories
        category_error_rates = {}
        for category in self.medical_categories.keys():
            category_errors = [e for e in errors if e.category == category]
            if category_errors:
                category_error_rates[category] = len(category_errors)

        # Sort by error count
        sorted_categories = sorted(category_error_rates.items(), key=lambda x: x[1], reverse=True)
        analysis['problematic_categories'] = sorted_categories[:5]

        return analysis

    def save_evaluation_report(self, results: Dict, filepath: str):
        """Save detailed evaluation report"""
        report = {
            'evaluation_timestamp': str(np.datetime64('now')),
            'metrics': results,
            'configuration': {
                'weights': self.weights,
                'critical_terms_count': len(self.critical_terms),
                'medical_categories': {k: len(v) for k, v in self.medical_categories.items()}
            }
        }

        with open(filepath, 'w') as f:
            json.dump(report, f, indent=2, default=str)

        logger.info(f"Evaluation report saved to {filepath}")

def main():
    """Test the medical transcription evaluator"""
    evaluator = MedicalTranscriptionEvaluator()

    # Test cases
    test_cases = [
        {
            'reference': "Patient received 5mg of morphine intravenously for chest pain.",
            'hypothesis': "Patient received 5mg of morphine IV for chest pain."
        },
        {
            'reference': "Blood pressure is 140 over 90 mmHg with heart rate of 85 bpm.",
            'hypothesis': "Blood pressure is 140/90 mmHg with heart rate 85 beats per minute."
        },
        {
            'reference': "Prescribed amoxicillin 500mg three times daily for pneumonia.",
            'hypothesis': "Prescribed amoxicillin 500mg TID for pneumonia."
        }
    ]

    references = [case['reference'] for case in test_cases]
    hypotheses = [case['hypothesis'] for case in test_cases]

    # Evaluate batch
    results = evaluator.evaluate_batch(references, hypotheses)

    print("Medical Transcription Evaluation Results:")
    print(f"Medical WER: {results['medical_wer']:.3f}")
    print(f"Medical BLEU: {results['medical_bleu']:.3f}")
    print(f"Medical Term F1: {results['medical_term_f1']:.3f}")
    print(f"Clinical Coherence: {results['clinical_coherence']:.3f}")
    print(f"Overall Score: {results['overall_score']:.3f}")

    # Save report
    evaluator.save_evaluation_report(results, "evaluation_report.json")

if __name__ == "__main__":
    main()