#!/usr/bin/env bash
set -euo pipefail

# Conditional batch: branch on a runtime value, then batch-read the
# relevant files. 1 round-trip instead of N.
# Usage: ./conditional-batch.sh
# Env:
#   BCTB_GATE_THRESHOLD  — max bytes to inline (default: 200000)
#   BCTB_RETAIN_DIR      — where to retain gated output (default: .bctb-retained)

GATE_THRESHOLD="${BCTB_GATE_THRESHOLD:-200000}"
RETAIN_DIR="${BCTB_RETAIN_DIR:-.bctb-retained}"
BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"

mkdir -p "$RETAIN_DIR"

AUTH_TYPE=$(grep -Po '(?<=AUTH_BACKEND=)\w+' .env 2>/dev/null || echo "unknown")
echo "--${BOUNDARY}"
echo "Content-Disposition: inline; name=\"auth_type\""
echo ""
echo "$AUTH_TYPE"

if [ "$AUTH_TYPE" = "oauth" ]; then
  FILES="src/oauth.py src/tokens.py"
else
  FILES="src/jwt.py src/claims.py"
fi

for f in $FILES; do
  echo "--${BOUNDARY}"
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
