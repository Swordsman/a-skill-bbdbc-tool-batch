#!/usr/bin/env bash
set -euo pipefail

# Size-gate a file or piped command output.
# Usage:
#   ./size-gate.sh <file>              # gate a file
#   some_command | ./size-gate.sh      # gate piped output
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)

GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"

if [ $# -ge 1 ]; then
  FILE="$1"
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
else
  TMPREF=$(mktemp)
  cat > "$TMPREF"
  BYTES=$(wc -c < "$TMPREF")
  if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
    cat "$TMPREF"
    rm -f "$TMPREF"
  else
    echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — available at ${TMPREF}]"
  fi
fi
