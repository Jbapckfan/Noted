#!/bin/sh
# offline-guard.sh — fails if any network-egress code path exists in NotedCore engine sources.
# NotedCore is a FULLY OFFLINE on-device medical scribe. Local model files (MLX weights),
# WhisperKit ANE/CPU inference, and on-device Speech are all fine — they are NOT network.
# Only outbound network is the enemy. This is the enforced form of the offline guarantee:
# the offline claim is a passing test, not a comment.
#
# Usage: sh scripts/offline-guard.sh          (scans the whole engine surface)
# CI/pre-push: run it; nonzero exit == a network path leaked back in.
#
# ALLOWLIST: files that legitimately mention a URL/host in a NON-egress way (docs strings,
# settings copy) go here, one grep -vE pattern per line, kept as tight as possible.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/NotedCore"

# Directories never scanned (deleted/build/vendored).
EXCLUDE='NotedCore_disabled_files|NotedCore_backups|/\.build/|DerivedData|\.xcodeproj'

# Egress signatures. Extend if a new client sneaks in.
PATTERNS='URLSession|URLRequest\(|\.dataTask|\.uploadTask|\.downloadTask|https?://[a-z0-9.-]+\.(com|ai|io|net|org)|api\.anthropic\.com|api\.openai\.com|api\.groq\.com|Reachability'

# Non-egress matches to ignore (keep TIGHT, each with a reason):
#  - comment lines (//, ///, *): commented code does not execute
#  - WCSession reachability: Apple Watch connectivity, not network
#  - FHIR/terminology canonical URIs (loinc/snomed/hl7/ucum/nlm): identifiers, never fetched
ALLOW=':[0-9]+:[[:space:]]*(//|///|\*)|sessionReachabilityDidChange|isReachable|loinc\.org|snomed\.info|hl7\.org|ucum\.org|nlm\.nih\.gov'

echo "== offline-guard: scanning $SRC for network egress =="
hits="$(grep -rInE "$PATTERNS" --include='*.swift' "$SRC" 2>/dev/null \
        | grep -vE "$EXCLUDE" \
        | grep -vE "$ALLOW" || true)"

if [ -n "$hits" ]; then
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  echo "OFFLINE GUARD FAILED — $n network-egress site(s) still present:"
  printf '%s\n' "$hits"
  echo ""
  echo "Each must be deleted or excised before the offline guarantee holds."
  exit 1
fi

echo "offline-guard: PASS — no network egress in engine sources."
