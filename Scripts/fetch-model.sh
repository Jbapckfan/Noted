#!/bin/sh
# fetch-model.sh — populate Models/<name> from HuggingFace so the app can BUNDLE the on-device model.
#
# The Xcode project already wires `Models/` as a blue folder reference in the app's resources
# (see docs/MODEL-BUNDLING.md), and `Models/` is gitignored (it's a ~1.8 GB build artifact, not
# source). Run this ONCE on a fresh checkout before building for device; the app then loads the
# model from its bundle with no network (MLXNoteEngine.resolveLocalModelDirectory).
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="Llama-3.2-3B-Instruct-4bit"
REPO="mlx-community/$NAME"
DEST="$ROOT/Models/$NAME"

if [ -f "$DEST/model.safetensors" ]; then
  echo "model already present: $DEST"
  exit 0
fi

echo "fetching $REPO -> $DEST  (~1.8 GB, one time)"
mkdir -p "$DEST"

# Prefer a local HF cache copy if it exists (deref symlinks); else download.
SNAP="$(ls -d "$HOME"/.cache/huggingface/hub/models--mlx-community--"$NAME"/snapshots/*/ 2>/dev/null | head -1 || true)"
if [ -n "${SNAP:-}" ] && [ -f "${SNAP}model.safetensors" ]; then
  echo "copying from HF cache: $SNAP"
  cp -RL "$SNAP"* "$DEST"/
else
  python3 -m pip install -q -U huggingface_hub 2>/dev/null || true
  huggingface-cli download "$REPO" --local-dir "$DEST" --local-dir-use-symlinks False
fi

echo "done — Models/$NAME populated ($(du -sh "$DEST" | cut -f1)). Now build for device."
