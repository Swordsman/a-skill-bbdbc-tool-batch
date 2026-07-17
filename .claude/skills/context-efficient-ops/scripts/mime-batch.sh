#!/usr/bin/env bash
set -euo pipefail

# Batch-read files into a MIME multipart container with size gating.
# Usage: ./mime-batch.sh file1.py file2.py config.yaml
# Env:
#   BCTB_GATE_THRESHOLD  — max bytes to inline (default: 200000)
#   BCTB_RETAIN_DIR      — where to retain gated output (default: .bctb-retained)

GATE_THRESHOLD="${BCTB_GATE_THRESHOLD:-200000}"
RETAIN_DIR="${BCTB_RETAIN_DIR:-.bctb-retained}"
BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"

mkdir -p "$RETAIN_DIR"

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
    cat "$f"
  else
    RETAINED="${RETAIN_DIR}/$(echo "$f" | tr '/' '_')_$(date +%s)"
    cp "$f" "$RETAINED"
    echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — retained at ${RETAINED}]"
  fi
done
echo "--${BOUNDARY}--"
