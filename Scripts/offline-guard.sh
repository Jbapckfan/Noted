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
#  - ModelConfiguration(id:) resolves a HuggingFace repo and DOWNLOADS on first run — the offline
#    build must load from a local directory (ModelConfiguration(directory:)) instead, so the `id:`
#    form is treated as egress. Also catch the swift-transformers Hub download entry points.
PATTERNS='URLSession|URLRequest\(|\.dataTask|\.uploadTask|\.downloadTask|https?://[a-z0-9.-]+\.(com|ai|io|net|org)|api\.anthropic\.com|api\.openai\.com|api\.groq\.com|Reachability|ModelConfiguration\([[:space:]]*id:|HubApi|snapshot\(from:|hubApi'

# Non-egress matches to ignore (keep TIGHT, each with a reason):
#  - comment lines (//, ///, *): commented code does not execute
#  - WCSession reachability: Apple Watch connectivity, not network
#  - FHIR/terminology canonical URIs (loinc/snomed/hl7/ucum/nlm): identifiers, never fetched
ALLOW=':[0-9]+:[[:space:]]*(//|///|\*)|sessionReachabilityDidChange|isReachable|loinc\.org|snomed\.info|hl7\.org|ucum\.org|nlm\.nih\.gov'

echo "== offline-guard: scanning $SRC for network egress =="
# Strip comments before matching so only LIVE code counts: `//` to end-of-line and `/* … */`
# blocks (multi-line), preserving newlines so reported line numbers stay accurate. This stops a
# commented-out example (e.g. a `/* HuggingFaceHub().download(...) */`) from failing the guard,
# while still catching any egress that actually compiles.
hits="$(
  find "$SRC" -name '*.swift' 2>/dev/null | grep -vE "$EXCLUDE" | while IFS= read -r f; do
    perl -0777 -pe 's{//[^\n]*}{}g; s{/\*.*?\*/}{ my $m=$&; $m =~ tr/\n//cd; $m }ges' "$f" 2>/dev/null \
      | grep -nE "$PATTERNS" \
      | grep -vE "$ALLOW" \
      | sed "s|^|$f:|"
  done || true
)"

if [ -n "$hits" ]; then
  n="$(printf '%s\n' "$hits" | grep -c . || true)"
  echo "OFFLINE GUARD FAILED — $n network-egress site(s) still present:"
  printf '%s\n' "$hits"
  echo ""
  echo "Each must be deleted or excised before the offline guarantee holds."
  exit 1
fi

echo "offline-guard: PASS — no network egress in engine sources."
