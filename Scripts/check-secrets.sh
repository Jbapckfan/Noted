#!/bin/sh
# check-secrets.sh — block credentials from entering the repo.
# Uses gitleaks if installed (better); otherwise falls back to a focused pattern scan.
# Called by .githooks/pre-commit on the staged diff; can also be run over the tree.
#
# Usage:
#   sh scripts/check-secrets.sh --staged    (scan staged changes, for the hook)
#   sh scripts/check-secrets.sh             (scan tracked tree)
set -eu

MODE="${1:-tree}"

if command -v gitleaks >/dev/null 2>&1; then
  if [ "$MODE" = "--staged" ]; then
    gitleaks protect --staged --redact --no-banner && exit 0 || { echo "gitleaks: staged secret detected"; exit 1; }
  else
    gitleaks detect --redact --no-banner && exit 0 || { echo "gitleaks: secret detected in history/tree"; exit 1; }
  fi
fi

# Fallback: no gitleaks. Focused high-signal patterns (low false-positive).
PAT='ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|https://[^/@:]+:[^/@]+@'

if [ "$MODE" = "--staged" ]; then
  scan="$(git diff --cached -U0 | grep -E '^\+' | grep -En "$PAT" || true)"
else
  scan="$(git grep -InE "$PAT" -- ':!Scripts/check-secrets.sh' 2>/dev/null || true)"
fi

if [ -n "$scan" ]; then
  echo "SECRET SCAN FAILED — credential-like string detected (value redacted):"
  printf '%s\n' "$scan" | sed -E 's/(ghp_|github_pat_|sk-|AKIA|xox.-)[A-Za-z0-9_-]+/\1[REDACTED]/g; s#://[^/@:]+:[^/@]+@#://[REDACTED]@#g'
  echo ""
  echo "Remove the secret and revoke it at the provider. (Install gitleaks for deeper scanning: brew install gitleaks)"
  exit 1
fi
exit 0
