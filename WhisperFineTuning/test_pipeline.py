#!/usr/bin/env python3
"""
Medical Whisper Fine-Tuning Pipeline Test Suite
===============================================

Comprehensive test suite to validate the medical Whisper fine-tuning pipeline.
Tests all components including data preprocessing, vocabulary enhancement,
evaluation metrics, and integration.
"""

import os
import sys
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch, MagicMock
import numpy as np

# Add current directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from medical_vocabulary import MedicalVocabularyEnhancer, MedicalEntity
    from evaluation_metrics import MedicalTranscriptionEvaluator, TranscriptionMetrics
    from data_preprocessing import MedicalDataPreprocessor, AudioSample
except ImportError as e:
    print(f"Import error: {e}")
    print("Please ensure all required dependencies are installed.")
    sys.exit(1)

class TestMedicalVocabularyEnhancer(unittest.TestCase):
    """Test medical vocabulary enhancement functionality"""

    def setUp(self):
        self.enhancer = MedicalVocabularyEnhancer()

    def test_medical_term_extraction(self):
        """Test extraction of medical terms from text"""
        test_text = """
        Patient presents with chest pain and shortness of breath.
        Prescribed amoxicillin 500mg twice daily.
        Blood pressure is 140/90 mmHg.
        """

        entities = self.enhancer.extract_medical_entities(test_text)

        # Check that medical entities are extracted
        self.assertIn("medications", entities)
        self.assertIn("measurements", entities)

        # Check specific terms
        medications = [med.lower() for med in entities.get("medications", [])]
        self.assertTrue(any("amoxicillin" in med for med in medications))

    def test_get_medical_terms(self):
        """Test getting medical terms for vocabulary enhancement"""
        terms = self.enhancer.get_medical_terms(max_terms=100)

        self.assertIsInstance(terms, list)
        self.assertGreater(len(terms), 0)
        self.assertLessEqual(len(terms), 100)

        # Check that common medical terms are included
        terms_lower = [term.lower() for term in terms]
        common_medical_terms = ["pneumonia", "hypertension", "mg", "blood pressure"]

        found_terms = sum(1 for term in common_medical_terms if any(term in t for t in terms_lower))
        self.assertGreater(found_terms, 0, "Should find at least some common medical terms")

    def test_vocabulary_persistence(self):
        """Test saving and loading vocabulary"""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            temp_path = f.name

        try:
            # Save vocabulary
            self.enhancer.save_vocabulary(temp_path)
            self.assertTrue(os.path.exists(temp_path))

            # Load vocabulary
            new_enhancer = MedicalVocabularyEnhancer()
            new_enhancer.load_vocabulary(temp_path)

            # Verify loaded vocabulary
            original_terms = self.enhancer.get_medical_terms(max_terms=50)
            loaded_terms = new_enhancer.get_medical_terms(max_terms=50)

            # Should have substantial overlap
            overlap = len(set(original_terms) & set(loaded_terms))
            self.assertGreater(overlap, len(original_terms) * 0.8)

        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)

class TestMedicalTranscriptionEvaluator(unittest.TestCase):
    """Test medical transcription evaluation metrics"""

    def setUp(self):
        self.evaluator = MedicalTranscriptionEvaluator()

    def test_perfect_match_evaluation(self):
        """Test evaluation with perfect match"""
        reference = "Patient received 5mg of morphine for chest pain."
        hypothesis = "Patient received 5mg of morphine for chest pain."

        metrics = self.evaluator.evaluate_single(reference, hypothesis)

        self.assertIsInstance(metrics, TranscriptionMetrics)
        self.assertEqual(metrics.medical_wer, 0.0)
        self.assertEqual(metrics.standard_wer, 0.0)
        self.assertGreater(metrics.medical_bleu, 0.9)

    def test_medical_term_substitution(self):
        """Test evaluation with medical term errors"""
        reference = "Patient received morphine for pain management."
        hypothesis = "Patient received codeine for pain management."

        metrics = self.evaluator.evaluate_single(reference, hypothesis)

        # Should have higher error rate due to medical term substitution
        self.assertGreater(metrics.medical_wer, metrics.standard_wer)
        self.assertGreater(metrics.medical_term_errors, 0)

    def test_dosage_accuracy(self):
        """Test dosage-specific accuracy evaluation"""
        reference = "Prescribed 500mg amoxicillin three times daily."
        hypothesis_correct = "Prescribed 500mg amoxicillin three times daily."
        hypothesis_wrong = "Prescribed 250mg amoxicillin three times daily."

        # Correct dosage
        metrics_correct = self.evaluator.evaluate_single(reference, hypothesis_correct)
        self.assertEqual(metrics_correct.dosage_accuracy, 1.0)

        # Wrong dosage
        metrics_wrong = self.evaluator.evaluate_single(reference, hypothesis_wrong)
        self.assertLess(metrics_wrong.dosage_accuracy, 1.0)

    def test_batch_evaluation(self):
        """Test batch evaluation functionality"""
        references = [
            "Patient has hypertension and diabetes.",
            "Prescribed lisinopril 10mg daily.",
            "Blood pressure is 140/90 mmHg."
        ]

        hypotheses = [
            "Patient has hypertension and diabetes.",
            "Prescribed lisinopril 10mg daily.",
            "Blood pressure is 140/90 mmHg."
        ]

        results = self.evaluator.evaluate_batch(references, hypotheses)

        self.assertIsInstance(results, dict)
        self.assertIn("medical_wer", results)
        self.assertIn("medical_bleu", results)
        self.assertIn("sample_count", results)
        self.assertEqual(results["sample_count"], 3)

    def test_clinical_coherence(self):
        """Test clinical coherence evaluation"""
        # Coherent medical statement
        reference_coherent = "Patient with chest pain given aspirin and nitroglycerin."
        hypothesis_coherent = "Patient with chest pain given aspirin and nitroglycerin."

        # Incoherent medical statement
        reference_incoherent = "Patient with chest pain given antibiotics for heart attack."
        hypothesis_incoherent = "Patient with chest pain given antibiotics for heart attack."

        metrics_coherent = self.evaluator.evaluate_single(reference_coherent, hypothesis_coherent)
        metrics_incoherent = self.evaluator.evaluate_single(reference_incoherent, hypothesis_incoherent)

        # Clinical coherence should be detectable
        self.assertIsNotNone(metrics_coherent.clinical_coherence)
        self.assertIsNotNone(metrics_incoherent.clinical_coherence)

class TestDataPreprocessing(unittest.TestCase):
    """Test data preprocessing functionality"""

    def setUp(self):
        # Create temporary config for testing
        self.temp_config = {
            "data_dir": "test_data",
            "output_dir": "test_output",
            "data": {
                "sampling_rate": 16000,
                "max_audio_length": 30,
                "augmentation": {"enabled": False}
            },
            "synthetic_data": {"generate_synthetic": False},
            "medical_specialties": {
                "general_medicine": {"enabled": True, "weight": 1.0}
            }
        }

        # Save temp config
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            json.dump(self.temp_config, f)
            self.config_path = f.name

    def tearDown(self):
        if os.path.exists(self.config_path):
            os.unlink(self.config_path)

    @patch('data_preprocessing.MedicalDataPreprocessor._initialize_tts_engines')
    def test_preprocessor_initialization(self, mock_tts):
        """Test data preprocessor initialization"""
        mock_tts.return_value = {}

        preprocessor = MedicalDataPreprocessor(self.config_path)

        self.assertEqual(preprocessor.sampling_rate, 16000)
        self.assertEqual(preprocessor.max_duration, 30)

    def test_medical_specialty_determination(self):
        """Test medical specialty determination"""
        # Mock the preprocessor with minimal setup
        with patch('data_preprocessing.MedicalDataPreprocessor._initialize_tts_engines'):
            preprocessor = MedicalDataPreprocessor(self.config_path)

        # Test cardiology
        cardio_text = "Patient has chest pain and elevated blood pressure."
        cardio_entities = {"medications": [], "conditions": ["chest pain"]}
        specialty = preprocessor._determine_medical_specialty(cardio_text, cardio_entities)
        self.assertEqual(specialty, "cardiology")

        # Test general medicine (default)
        general_text = "Patient feels tired and weak."
        general_entities = {"medications": [], "conditions": []}
        specialty = preprocessor._determine_medical_specialty(general_text, general_entities)
        self.assertEqual(specialty, "general_medicine")

    def test_text_quality_calculation(self):
        """Test text quality scoring"""
        with patch('data_preprocessing.MedicalDataPreprocessor._initialize_tts_engines'):
            preprocessor = MedicalDataPreprocessor(self.config_path)

        # High quality medical text
        good_text = "Patient presents with chest pain, prescribed 5mg morphine, blood pressure 140/90."
        good_entities = {
            "medications": ["morphine"],
            "measurements": ["5mg", "140/90"],
            "conditions": ["chest pain"]
        }
        good_score = preprocessor._calculate_text_quality(good_text, good_entities)

        # Low quality text
        bad_text = "Um, yeah, so like..."
        bad_entities = {"medications": [], "measurements": [], "conditions": []}
        bad_score = preprocessor._calculate_text_quality(bad_text, bad_entities)

        self.assertGreater(good_score, bad_score)
        self.assertGreater(good_score, 0.5)  # Should be reasonably high
        self.assertLess(bad_score, 0.5)     # Should be low

class TestIntegration(unittest.TestCase):
    """Test integration between components"""

    def test_vocabulary_and_evaluation_integration(self):
        """Test integration between vocabulary enhancer and evaluator"""
        enhancer = MedicalVocabularyEnhancer()
        evaluator = MedicalTranscriptionEvaluator()

        # Test text with medical content
        test_text = "Patient received amoxicillin 500mg for pneumonia treatment."

        # Extract entities
        entities = enhancer.extract_medical_entities(test_text)

        # Evaluate perfect transcription
        metrics = evaluator.evaluate_single(test_text, test_text)

        # Should have high medical term accuracy
        self.assertEqual(metrics.medical_term_accuracy, 1.0)
        self.assertGreater(len(entities.get("medications", [])), 0)

    def test_end_to_end_workflow(self):
        """Test simplified end-to-end workflow"""
        # Create temporary directories
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Create mock dataset
            (temp_path / "MedicalDatasets" / "MTS-Dialog").mkdir(parents=True)

            # Create mock CSV data
            mock_csv_content = """conversation
Patient: I have chest pain. Doctor: How long? Patient: Two days. Doctor: Take aspirin.
Patient: Headache for hours. Doctor: Rate 1-10? Patient: Seven. Doctor: Here's medication.
"""
            with open(temp_path / "MedicalDatasets" / "MTS-Dialog" / "test.csv", 'w') as f:
                f.write(mock_csv_content)

            # Create config
            config = {
                "data_dir": str(temp_path / "MedicalDatasets"),
                "output_dir": str(temp_path / "output"),
                "data": {
                    "sampling_rate": 16000,
                    "max_audio_length": 30,
                    "augmentation": {"enabled": False}
                },
                "synthetic_data": {"generate_synthetic": False},
                "medical_specialties": {
                    "general_medicine": {"enabled": True, "weight": 1.0}
                }
            }

            config_path = temp_path / "config.json"
            with open(config_path, 'w') as f:
                json.dump(config, f)

            # Test vocabulary enhancement
            enhancer = MedicalVocabularyEnhancer()
            terms = enhancer.get_medical_terms(max_terms=10)
            self.assertGreater(len(terms), 0)

            # Test evaluation
            evaluator = MedicalTranscriptionEvaluator()
            test_ref = "Patient has chest pain and takes aspirin."
            test_hyp = "Patient has chest pain and takes aspirin."
            metrics = evaluator.evaluate_single(test_ref, test_hyp)
            self.assertIsInstance(metrics, TranscriptionMetrics)

            print("✓ End-to-end workflow test passed")

def run_performance_tests():
    """Run performance tests for the pipeline"""
    print("\n🚀 Running Performance Tests")
    print("=" * 40)

    # Test vocabulary loading performance
    print("Testing vocabulary loading performance...")
    import time

    start_time = time.time()
    enhancer = MedicalVocabularyEnhancer()
    vocab_load_time = time.time() - start_time
    print(f"✓ Vocabulary loaded in {vocab_load_time:.2f} seconds")

    # Test term extraction performance
    print("Testing term extraction performance...")
    test_text = """
    Patient is a 45-year-old male presenting with acute onset chest pain.
    Past medical history significant for hypertension and diabetes mellitus.
    Current medications include lisinopril 10mg daily, metformin 500mg twice daily.
    Physical examination reveals blood pressure 150/90, heart rate 85 bpm.
    Recommended starting aspirin 81mg daily and atorvastatin 40mg at bedtime.
    """ * 10  # Repeat to make it larger

    start_time = time.time()
    entities = enhancer.extract_medical_entities(test_text)
    extraction_time = time.time() - start_time
    print(f"✓ Entity extraction completed in {extraction_time:.3f} seconds")

    # Test evaluation performance
    print("Testing evaluation performance...")
    evaluator = MedicalTranscriptionEvaluator()

    references = [
        "Patient received 5mg morphine for chest pain management.",
        "Blood pressure reading shows 140 over 90 millimeters of mercury.",
        "Prescribed amoxicillin 500 milligrams three times daily for infection.",
    ] * 20  # Repeat for batch testing

    hypotheses = [
        "Patient received 5mg morphine for chest pain management.",
        "Blood pressure reading shows 140/90 mmHg.",
        "Prescribed amoxicillin 500mg TID for infection.",
    ] * 20

    start_time = time.time()
    results = evaluator.evaluate_batch(references, hypotheses)
    eval_time = time.time() - start_time
    print(f"✓ Batch evaluation of {len(references)} samples completed in {eval_time:.3f} seconds")

    print(f"\nPerformance Summary:")
    print(f"- Vocabulary loading: {vocab_load_time:.2f}s")
    print(f"- Entity extraction: {extraction_time:.3f}s")
    print(f"- Batch evaluation: {eval_time:.3f}s")

def main():
    """Main test runner"""
    print("🧪 Medical Whisper Fine-Tuning Pipeline Test Suite")
    print("=" * 55)

    # Run unit tests
    print("\n📋 Running Unit Tests")
    print("-" * 25)

    # Create test suite
    test_suite = unittest.TestSuite()

    # Add test cases
    test_suite.addTest(unittest.makeSuite(TestMedicalVocabularyEnhancer))
    test_suite.addTest(unittest.makeSuite(TestMedicalTranscriptionEvaluator))
    test_suite.addTest(unittest.makeSuite(TestDataPreprocessing))
    test_suite.addTest(unittest.makeSuite(TestIntegration))

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(test_suite)

    # Run performance tests
    if result.wasSuccessful():
        run_performance_tests()

    # Summary
    print(f"\n📊 Test Summary")
    print("=" * 20)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")

    if result.wasSuccessful():
        print("✅ All tests passed! Pipeline is ready for use.")
        return 0
    else:
        print("❌ Some tests failed. Please check the errors above.")
        return 1

if __name__ == "__main__":
    sys.exit(main())