#!/bin/bash
# AC-IAP-21-04 regression guard: main app target must not contain *.storekit files
set -euo pipefail
HITS=$(find "$(dirname "$0")/../Havital" -maxdepth 3 -name "*.storekit" 2>/dev/null || true)
if [ -n "$HITS" ]; then
  echo "FAIL: main app target contains .storekit files (violates SPEC AC-IAP-21-01):"
  echo "$HITS"
  exit 1
fi
echo "PASS: no .storekit in main target"
