#!/usr/bin/env bash
set -euo pipefail

# Batch-read files into a MIME multipart container with size gating.
# Usage: ./mime-batch.sh file1.py file2.py config.yaml
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)

GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"

gen_boundary() { echo "batch_$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"; }

# Generate a boundary that doesn't collide with any input file content.
collision=true
while $collision; do
  BOUNDARY=$(gen_boundary)
  collision=false
  for f in "$@"; do
    if [ -f "$f" ] && grep -qF "$BOUNDARY" "$f" 2>/dev/null; then
      collision=true
      break
    fi
  done
done

echo "MIME-Version: 1.0"
echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
echo ""

for f in "$@"; do
  echo "--${BOUNDARY}"
  echo "Content-Type: text/plain; charset=utf-8"
  echo "Content-Disposition: attachment; filename=\"${f}\""
  echo ""

  if [ ! -f "$f" ]; then
    echo "[NOT FOUND]"
    continue
  fi

  BYTES=$(wc -c < "$f")
  if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
    cat "$f"
  else
    TMPREF=$(mktemp)
    cp "$f" "$TMPREF"
    echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — available at ${TMPREF}]"
  fi
done
echo "--${BOUNDARY}--"
