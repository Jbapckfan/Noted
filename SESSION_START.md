# CLAUDE CODE SESSION START - NOTEDCORE PROJECT

## 🚨 MANDATORY READING - READ ALL BEFORE ANY ACTIONS

**Project:** NotedCore - AI-Enhanced Medical Transcription App
**Status:** 80% Complete - MLX Integration Phase  
**Last Updated:** July 10, 2025
**Current Priority:** Complete Phi-3 Mini AI Backend Integration

## 📋 NOTEDCORE PROJECT OVERVIEW

### What NotedCore Is:
- **Professional iOS medical transcription app** for healthcare providers
- **Real-time audio capture** with AI-powered medical note generation
- **100% on-device processing** for HIPAA compliance
- **Dual transcription engines** (Apple Speech + WhisperKit backup)
- **Microsoft Phi-3 Mini integration** for medical note generation

### Current Project Status (80% Complete):
- ✅ **Audio Pipeline:** Fully functional with professional-grade processing
- ✅ **Transcription Services:** Apple Speech + WhisperKit working perfectly
- ✅ **User Interface:** Complete 3-tab interface with real-time visualization
- ✅ **State Management:** CoreAppState singleton pattern implemented
- ✅ **Session Management:** Save/load/delete with 10-session limit
- 🔄 **AI Backend:** Needs MLX framework integration (Phi3MLXService.swift)
- 🔄 **Medical Prompting:** Needs sophisticated medical note generation

## 🎯 IMMEDIATE SESSION FOCUS

### PRIMARY GOAL: Complete MLX Integration
**Target File:** `Phi3MLXService.swift`
**Objective:** Get Microsoft Phi-3 Mini (3.8B params) working with MLX framework
**Success Criteria:** Basic medical note generation from transcription text

### SECONDARY GOAL: Medical Prompting System
**Objective:** Implement professional medical prompts for:
- SOAP Notes (Subjective, Objective, Assessment, Plan)
- Narrative Notes (Clinical storytelling)
- Structured Notes (Organized sections)
- Differential Diagnosis (Clinical reasoning)

## 🚨 CRITICAL FILES - NEVER MODIFY (WORKING PERFECTLY)

### Audio & Transcription Services (DO NOT TOUCH):
- **AudioCaptureService.swift** (434 lines) - Core audio engine with AVAudioEngine
- **SpeechRecognitionService.swift** - Apple Speech Recognition (95% accuracy)
- **WhisperService.swift** (413 lines) - WhisperKit backup with hallucination filtering
- **AudioUtilities.swift** - DSP utilities (CircularBuffer, NoiseGate, etc.)

### User Interface (DO NOT TOUCH):
- **ContentView.swift** (589 lines) - Main UI with 3-tab interface, perfect as-is
- **MedicalNotesView.swift** - Medical note generation UI, working
- **CoreAppState.swift** (134 lines) - State management, may need minor updates only

## 🔧 FILES THAT NEED WORK

### Primary Focus:
- **Phi3MLXService.swift** - Main AI service, needs MLX framework integration
- **MedicalSummarizerService.swift** (448 lines) - Service wrapper, needs connection to Phi-3

### Project Structure: