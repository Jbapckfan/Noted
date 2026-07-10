# Offline summarizer eval

Run the REAL on-device model on transcripts, end-to-end, without a phone.

1. `python3 eval/run_eval.py` — loads `mlx-community/Llama-3.2-3B-Instruct-4bit` and runs the exact
   `MLXNoteEngine` extraction prompt on each `*.txt`, saving `<name>.json`.
2. `swift run --package-path NotedCoreKit nc-summarize eval/<name>.txt eval/<name>.json` — runs the
   SHIPPING pipeline (GroundingVerifier.filtered → NoteTemplate → CalculatorRegistry) on that
   extraction and prints the grounded note, what grounding removed, and the calculator suggestions.

This mirrors what the device does after the model extracts facts. Add transcripts as `*.txt`.
