#!/usr/bin/env bash
set -euo pipefail

# Conditional batch: branch on a runtime value, then batch-read the
# relevant files. 1 round-trip instead of N.
# Usage: ./conditional-batch.sh
# Env:
#   BATCH_GATE_THRESHOLD  — max bytes to inline (default: 200000)

GATE_THRESHOLD="${BATCH_GATE_THRESHOLD:-200000}"

gen_boundary() { echo "batch_$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"; }

AUTH_TYPE=$(grep -Po '(?<=AUTH_BACKEND=)\w+' .env 2>/dev/null || echo "unknown")

if [ "$AUTH_TYPE" = "oauth" ]; then
  FILES="src/oauth.py src/tokens.py"
else
  FILES="src/jwt.py src/claims.py"
fi

# Generate a boundary that doesn't collide with any input file content.
collision=true
while $collision; do
  BOUNDARY=$(gen_boundary)
  collision=false
  for f in $FILES; do
    if [ -f "$f" ] && grep -qF "$BOUNDARY" "$f" 2>/dev/null; then
      collision=true
      break
    fi
  done
done

echo "MIME-Version: 1.0"
echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
echo ""

echo "--${BOUNDARY}"
echo "Content-Disposition: inline; name=\"auth_type\""
echo ""
echo "$AUTH_TYPE"

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
    TMPREF=$(mktemp)
    cp "$f" "$TMPREF"
    echo "[GATED: ${BYTES} bytes > ${GATE_THRESHOLD} threshold — available at ${TMPREF}]"
  fi
done
echo "--${BOUNDARY}--"
