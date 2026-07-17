#!/usr/bin/env bash
set -euo pipefail

# Size-gate a single file: inline if under threshold, retain otherwise.
# Usage: ./size-gate.sh <file>
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)
#   BATCH_RETAIN_DIR      — where to retain gated output (default: .batch-retained)

FILE="${1:?Usage: size-gate.sh <file>}"
GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"
RETAIN_DIR="${BATCH_RETAIN_DIR:-.batch-retained}"

if [ ! -f "$FILE" ]; then
  echo "[NOT FOUND: ${FILE}]"
  exit 1
fi

mkdir -p "$RETAIN_DIR"

BYTES=$(wc -c < "$FILE")
if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
  cat "$FILE"
else
  RETAINED="${RETAIN_DIR}/$(echo "$FILE" | tr '/' '_')_$(date +%s)"
  cp "$FILE" "$RETAINED"
  echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — retained at ${RETAINED}]"
fi
