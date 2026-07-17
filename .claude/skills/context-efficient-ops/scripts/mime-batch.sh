#!/usr/bin/env bash
set -euo pipefail

# Batch-read files into a MIME multipart container with size gating.
# Usage: ./mime-batch.sh file1.py file2.py config.yaml
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)

GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"
BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"

for f in "$@"; do
  echo "--${BOUNDARY}"
  echo "Content-Type: text/plain"
  echo "Content-Disposition: attachment; filename=\"${f}\""
  echo ""

  if [ ! -f "$f" ]; then
    echo "[NOT FOUND]"
    continue
  fi

  BYTES=$(wc -c < "$f")
  if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
    if grep -qF "$BOUNDARY" "$f"; then
      BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"
    fi
    cat "$f"
  else
    TMPREF=$(mktemp)
    cp "$f" "$TMPREF"
    echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — available at ${TMPREF}]"
  fi
done
echo "--${BOUNDARY}--"
