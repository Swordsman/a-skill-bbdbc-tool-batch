#!/usr/bin/env bash
set -euo pipefail

# Size-gate a single file: inline if under threshold, copy to /tmp otherwise.
# Usage: ./size-gate.sh <file>
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)

FILE="${1:?Usage: size-gate.sh <file>}"
GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"

if [ ! -f "$FILE" ]; then
  echo "[NOT FOUND: ${FILE}]"
  exit 1
fi

BYTES=$(wc -c < "$FILE")
if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
  cat "$FILE"
else
  TMPREF=$(mktemp)
  cp "$FILE" "$TMPREF"
  echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — available at ${TMPREF}]"
fi
