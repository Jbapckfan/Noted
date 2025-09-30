#!/bin/bash

echo "Building NotedCore with new safety features..."

# Compile all the new files together with main file first
swiftc \
  NotedCore/MedicalAbbreviationExpander.swift \
  NotedCore/PretrainedMedicalPatterns.swift \
  NotedCore/NegationHandler.swift \
  NotedCore/ClinicalSafetyDetector.swift \
  NotedCore/MedicationExtractor.swift \
  NotedCore/RealConversationAnalyzer.swift \
  test_advanced_features.swift \
  -o test_improvements

if [ $? -eq 0 ]; then
    echo "✓ Build successful"
    echo ""
    echo "Running tests..."
    echo ""
    ./test_improvements
else
    echo "✗ Build failed"
    exit 1
fi
