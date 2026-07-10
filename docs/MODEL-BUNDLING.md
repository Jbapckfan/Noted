# Bundling the on-device model (the "fully offline" step)

NotedCore must run with **no network, ever** — audio and inference never leave the phone.
That means the LLM ships **inside the app bundle** and is loaded from disk. The code is already
wired for this; these are the owner steps to actually put the model there.

## How the code resolves the model (already done)

`MLXNoteEngine.resolveLocalModelDirectory()` looks for the model as a LOCAL directory only:

1. an absolute on-disk path (a dev override), or
2. a folder bundled in the app under `Models/<name>` (or `<name>`), keyed by the model's short name.

It **never** builds a `ModelConfiguration(id:)` (that would resolve a HuggingFace repo and download
on first run). If the folder isn't found, it **fails closed** — `ModelHost` shows "model not
bundled" and the app degrades to transcript-only. `Scripts/offline-guard.sh` fails CI if a live
`ModelConfiguration(id:)` / `HubApi` download path is ever reintroduced.

Default model short name: **`Llama-3.2-3B-Instruct-4bit`**
(`NoteEngineFactory.defaultModelID = "mlx-community/Llama-3.2-3B-Instruct-4bit"`; only the last path
component is used as the bundle folder name).

## Step 1 — get the model files locally

The MLX 4-bit weights are a folder of `config.json`, `*.safetensors`, and tokenizer files.

```sh
# one-time, on the Mac (needs network HERE — this is a build step, not the app)
pip install -U huggingface_hub
huggingface-cli download mlx-community/Llama-3.2-3B-Instruct-4bit \
  --local-dir ~/models/Llama-3.2-3B-Instruct-4bit --local-dir-use-symlinks False
```

Confirm the folder contains `config.json`, `tokenizer.json`, and the `*.safetensors` weights
(~1.8 GB total).

## Step 2 — add it to the app bundle as a FOLDER REFERENCE

In Xcode:

1. Drag `Llama-3.2-3B-Instruct-4bit` into the project navigator, dropping it **onto the `NotedCore`
   app group**.
2. In the dialog: **Copy items if needed** = ON; **Create folder references** (blue folder, *not*
   yellow group) so the directory structure is preserved in the bundle; **Add to target: NotedCore**.
3. Put it under a `Models/` folder so it lands at `Models/Llama-3.2-3B-Instruct-4bit` in the bundle
   (matches `resolveLocalModelDirectory()`'s `subdirectory: "Models"` lookup; the bare-name lookup
   is a fallback).

A blue folder reference is important — a yellow group flattens the files and the loader won't find
the model directory.

## Step 3 — memory entitlement

The ~2 GB 4-bit model plus KV/prompt buffers exceeds the default jetsam budget. Add the entitlement:

1. Create `NotedCore/NotedCore.entitlements` (Signing & Capabilities → + Capability →
   *Increased Memory Limit*, or add the key by hand):
   ```xml
   <key>com.apple.developer.kernel.increased-memory-limit</key>
   <true/>
   ```
2. Set the target's **Code Signing Entitlements** build setting to that file.

(Requires the paid Apple Developer account — which you have.)

## Step 4 — verify it's actually offline

1. Build + install on the iPhone 16 Pro Max.
2. Put the phone in **airplane mode**.
3. Launch, record a short encounter. The banner should read "Loading on-device AI model…" then
   clear, and a real note should generate — with **no** network. If you see "AI model unavailable —
   model not bundled", the folder reference didn't make it into the bundle (Step 2).
4. On the Mac: `sh Scripts/offline-guard.sh` must print `PASS`.

## App Store note (later)

A ~1.8 GB model baked into the binary is fine for a **TestFlight / personal pilot**, but pushes the
app past comfortable App Store limits. For store distribution, move the model to **On-Demand
Resources** (still no third-party network; Apple-hosted, downloaded once on first launch with the
user's consent) or app thinning. That's a distribution change, not a runtime one — the loader stays
the same. Keep it bundled for the pilot.
