# NotedCore — LoRA training track

The quality that beats a cloud scribe on ED notes comes from a **domain adapter**, not a bigger
model. This is the recipe. It runs on a Mac with Apple Silicon (`mlx_lm` is already installed);
nothing here touches the phone until you ship an adapter.

## 0. What's here
- `convert.py` — builds the training corpus from the datasets in the repo. **Already run** →
  `data/train.jsonl` (1,146) + `data/valid.jsonl` (60), mlx_lm chat format, task-tagged
  (`note` from MTS-Dialog, `extraction` from the 5 gold ED cases).
- `lora_config.yaml` — the `mlx_lm.lora` config (base model + hyperparameters).
- `data/` — the generated JSONL.

## 1. Data (done + the two gaps to fill)
```bash
python3 training/convert.py     # regenerate any time
```
Two gaps to close before this beats Suki/Heidi on ED specifically:
- **Synthetic ED extraction** (biggest gap — only 5 real ED extraction rows today). Generate
  ~5–10k `{ED transcript → ClinicalFacts JSON}` pairs across the ED complaint distribution using a
  **free-tier/OAuth** LLM (OpenRouter `:free`, Groq, Google AI Studio). Zero PHI — fully synthetic,
  so cloud is fine. Inject distractors, negations, and interruptions to match ambient audio. Append
  to `data/` in the same chat schema.
- **Your real pairs** (highest value): WhisperKit STT locally → **Philter** (Safe Harbor) →
  **Presidio** surrogate substitution → **100% manual review of every row** → append. Raw audio and
  pre-scrub transcripts NEVER leave the device. `TrainingFlywheel.pairs(from:)` in NotedCoreKit emits
  these from signed encounters (pre-scrub) — run them through de-id before training.

## 2. Train
```bash
# 3B (phone-safe default). Downloads the base on first run.
python3 -m mlx_lm lora --config training/lora_config.yaml
# adapter lands in training/adapters/note/
```
Train `extraction` first (the factual backbone), then `note`, then `discharge` — one adapter each
(edit `adapter_path` + filter `data/` by task). Watch valid loss; ~1000–2000 iters.

## 3. Try it
```bash
python3 -m mlx_lm generate \
  --model mlx-community/Llama-3.2-3B-Instruct-4bit \
  --adapter-path training/adapters/note \
  --prompt "Summarize this ED encounter into an HPI: <transcript>"
```

## 4. Eval gates (before shipping any adapter)
On a held-out real-ED split (never trained on), gate hard:
- hallucination ≤ **1.47%**, omission ≤ **3.45%** (the ED-dangerous error), structure validity ~100%.
Use `AdapterGate` (NotedCoreKit) for the thresholds; grounding is checked with `GroundingVerifier`.
**Re-run the gate on the quantized shipped artifact** — quantization moves error rates.

## 5. Ship
- Do **NOT** fuse (fusing triples shipped weight). Ship one shared 4-bit base + the small adapters.
- Bundle base + tokenizer + adapters as app resources or a first-run download.
- The app auto-uses the real engine once `mlx-swift-examples` is linked AND the model dir is present
  (`NoteEngineFactory` guards on both); otherwise it stays on the deterministic mock.

## Base model — 3B vs 7B (the on-device benchmark)
`Llama-3.2-3B-Instruct-4bit` (~1.8 GB) is the safe default. An 8 GB iPhone 16 Pro Max can likely run
`Qwen2.5-7B-Instruct-4bit` (~4.3 GB) with the increased-memory entitlement — a real jump in fluency
that closes most of the gap with cloud. Benchmark both on the phone (tokens/sec, peak memory, note
quality on your gold cases) before committing; the adapter must be trained on whichever base ships.
