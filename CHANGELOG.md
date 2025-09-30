# Changelog

All notable changes to the NotedCore project will be documented in this file.

## [Unreleased] - 2025-09-16

### Added
- Apple Intelligence integration for on-device AI summarization (iOS 18+)
- ED-specific note format with proper structure (CC, HPI, MDM, Disposition)
- Progressive note building system with 5 encounter phases
- Reassessment/MDM quick encounter mode
- Medical accuracy enhancer for drug names, dosages, and anatomical terms
- Smart section handling (only includes sections with content)
- Pertinent negatives detection for comprehensive documentation
- Time-stamped encounter phase tracking
- Test views for ED note format validation
- Guided generation with @Generable macros for structured output
- Few-shot learning examples for note formatting

### Changed
- Transcription now uses enhanced medical vocabulary
- Note generation adapts to available information density
- MDM and discharge instructions only generated after workup complete
- Vital signs automatically standardized (BP, HR, SpO2 format)
- Temporal expressions parsed to medical format (x 3 hours, 2 days PTA)

### Fixed
- Drug name recognition and correction
- Anatomical term confusion (humeral vs humoral)
- Dosage standardization (BID, TID, QID, PRN)
- Empty section placeholders removed
- Premature MDM documentation prevented

### Technical
- Created AppleIntelligenceSummarizer.swift
- Created MedicalNoteFormats.swift
- Created MedicalAccuracyEnhancer.swift
- Created ReassessmentService.swift
- Created ProgressiveNoteBuilder.swift
- Added comprehensive test scripts

## [0.2.0] - 2025-09-15

### Added
- Watch companion app with full functionality
- Multi-patient workflow support
- Enhanced documentation service
- Voice command integration
- Speaker diarization for multi-speaker scenarios

### Changed
- Improved WhisperKit integration
- Enhanced audio processing pipeline
- Optimized memory usage

### Fixed
- Microphone permission handling
- Background audio processing
- Transcription accuracy for medical terms

## [0.1.0] - 2025-09-01

### Initial Release
- Basic transcription functionality
- SOAP note generation
- Simple UI for recording
- WhisperKit integration
- Local storage of notes

---

## TODO List

### High Priority
- [ ] Real-world clinical testing
- [ ] EHR system integration (Epic, Cerner)
- [ ] Custom specialty vocabularies
- [ ] Multi-provider collaboration
- [ ] Automated coding suggestions (ICD-10, CPT)

### Medium Priority  
- [ ] Enhanced speaker identification
- [ ] Ambient noise suppression
- [ ] Custom templates by specialty
- [ ] Quality scoring metrics
- [ ] Offline model updates

### Low Priority
- [ ] Additional language support
- [ ] Advanced voice commands
- [ ] Clinical data visualization
- [ ] Research study features
- [ ] Training mode for students

### Known Issues
- Metal toolchain missing for MLX builds
- Some drug names need phonetic matching improvements
- Background noise affects accuracy in busy EDs
- Sheet presentations need UI polish

### Performance Targets
- Transcription accuracy: 95%+ (currently ~90% for medical terms)
- Processing latency: <2 seconds (currently meeting target)
- Memory usage: <500MB (currently ~400MB)
- Battery impact: <10% per hour (currently ~8%)

---

## Contributing

See CONTRIBUTING.md for details on our code of conduct and development process.

## License

This project is licensed under the MIT License - see LICENSE file for details.