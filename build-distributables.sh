#!/usr/bin/env bash
set -euo pipefail

# Build both distributable files for the bbdbc-tool-batch skill.
# Run from the repo root before committing skill changes.
#
# Produces:
#   bbdbc-tool-batch.skill   — zip archive (via skill-creator's package_skill)
#   bbdbc-tool-batch.aimpack — MIME multipart container with SHA256 checksums

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$REPO_ROOT/.claude/skills/bbdbc-tool-batch"
SKILL_NAME="bbdbc-tool-batch"

# --- .skill (zip archive) ---

PACKAGER_DIR="${SKILL_CREATOR_PATH:-$HOME/.claude/skills/skill-creator}"
if [ ! -f "$PACKAGER_DIR/scripts/package_skill.py" ]; then
  echo "Error: skill-creator not found at $PACKAGER_DIR"
  echo "Set SKILL_CREATOR_PATH to the skill-creator directory."
  exit 1
fi

echo "=== Building ${SKILL_NAME}.skill ==="
(cd "$PACKAGER_DIR" && python -m scripts.package_skill "$SKILL_DIR" "$REPO_ROOT")

# --- .aimpack (MIME multipart) ---

echo ""
echo "=== Building ${SKILL_NAME}.aimpack ==="

FILES=(
  "SKILL.md"
  "references/output-format.md"
  "references/sub-agent-delegation.md"
  "references/skill-creation-guide.md"
  "references/rationale.md"
  "references/tool-manifest.md"
  "scripts/conditional-batch.sh"
  "scripts/mime-batch.sh"
  "scripts/size-gate.sh"
)

# Build manifest
MANIFEST="${SKILL_NAME} skill files:"
for f in "${FILES[@]}"; do
  BYTES=$(wc -c < "$SKILL_DIR/$f")
  MANIFEST="$MANIFEST
  $f ($BYTES bytes)"
done

# Generate collision-free boundary
gen_boundary() { echo "aimpack_$(od -An -tx1 -N8 /dev/urandom | tr -d ' \n')"; }
collision=true
while $collision; do
  BOUNDARY=$(gen_boundary)
  collision=false
  for f in "${FILES[@]}"; do
    if grep -qF "$BOUNDARY" "$SKILL_DIR/$f" 2>/dev/null; then
      collision=true
      break
    fi
  done
done

UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())')

{
  echo "MIME-Version: 1.0"
  echo "Content-Type: multipart/mixed; boundary=\"${BOUNDARY}\""
  echo "X-Aimpack-Container-Id: ${UUID}"
  echo ""

  echo "--${BOUNDARY}"
  echo "Content-Type: text/x-aimpack-meta; role=preamble"
  echo ""
  echo "This is an aimpack container (AI MimePack)."
  echo "Spec: https://github.com/swordsman/aimpack"
  echo ""

  echo "--${BOUNDARY}"
  echo "Content-Type: text/x-aimpack-meta; role=manifest"
  echo ""
  echo "$MANIFEST"
  echo ""

  for f in "${FILES[@]}"; do
    CHECKSUM=$(sha256sum "$SKILL_DIR/$f" | cut -d' ' -f1)
    echo "--${BOUNDARY}"
    echo "Content-Type: text/plain; charset=utf-8"
    echo "Content-Disposition: attachment; filename=\"${f}\""
    echo "X-Aimpack-Checksum-SHA256: ${CHECKSUM}"
    echo ""
    cat "$SKILL_DIR/$f"
    echo ""
  done

  echo "--${BOUNDARY}--"
} > "$REPO_ROOT/${SKILL_NAME}.aimpack"

echo "Created ${SKILL_NAME}.aimpack ($(wc -c < "$REPO_ROOT/${SKILL_NAME}.aimpack") bytes)"
echo ""
echo "Done. Both distributables are ready at the repo root."
