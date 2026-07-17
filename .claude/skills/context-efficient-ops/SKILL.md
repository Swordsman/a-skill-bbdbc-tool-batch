---
name: blackcontract-tool-batch
description: "Batch tool calls, gate output by size, delegate to sub-agents. Minimizes token waste and protects the context window."
---

# Blackcontract Tool Batch

Tool calls retransmit the full context window and output joins context permanently; this skill minimizes both costs. For full rationale, see `references/rationale.md`.

## Decision: Native Parallel Calls vs. Bash Batch

Many tool harnesses (including Claude Code) support issuing multiple tool calls in a single turn. Use that when available — it's the simplest form of batching. Use bash MIME batching when you need:

- **Conditional logic** — next file depends on a previous result
- **Unified size gating** — one guard across all outputs
- **Harness doesn't support parallel calls** — or you're in a sub-agent with only bash

When in doubt: native parallel calls for independent reads, bash batch for dependent chains.

## Core Technique: Batch Everything

Combine multiple tool operations into single calls. This applies universally — head-agents, sub-agents, any context where tools are called.

### Pre-check before committing

Before reading unknown files, use lightweight probes to avoid blowing up context:

```bash
wc -l src/auth/*.py          # line counts — decides batch vs. delegate
head -20 src/app.py           # structure check without full read
find src/ -name '*.py' | wc -l  # file count — decides parallelism strategy
```

### MIME-wrapped bash batch
```bash
BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"
TMPOUT=$(mktemp)
GATE_THRESHOLD="${BCTB_GATE_THRESHOLD:-200000}"
trap 'rm -f "$TMPOUT"' EXIT

for f in file1.py file2.py config.yaml; do
  echo "--${BOUNDARY}"
  echo "Content-Type: text/plain"
  echo "Content-Disposition: attachment; filename=\"${f}\""
  echo ""
  cat "$f" > "$TMPOUT" 2>/dev/null
  BYTES=$(wc -c < "$TMPOUT")
  if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
    cat "$TMPOUT"
  else
    echo "[GATED: ${BYTES} bytes — retained at ${TMPOUT} for targeted processing]"
  fi
done
echo "--${BOUNDARY}--"
```

### With conditional branching (1 round-trip instead of 3)
```bash
BOUNDARY="batch_$(head -c 8 /dev/urandom | xxd -p)"
TMPOUT=$(mktemp)
GATE_THRESHOLD="${BCTB_GATE_THRESHOLD:-200000}"
trap 'rm -f "$TMPOUT"' EXIT

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
  cat "$f" > "$TMPOUT" 2>/dev/null
  if [ $? -ne 0 ]; then
    echo "[NOT FOUND]"
  else
    BYTES=$(wc -c < "$TMPOUT")
    if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
      cat "$TMPOUT"
    else
      echo "[GATED: ${BYTES} bytes — retained at ${TMPOUT} for targeted processing]"
    fi
  fi
done
echo "--${BOUNDARY}--"
```

### Size guards (ALWAYS include)

Route output to a temp file first. Return inline only if under threshold; otherwise retain and report so it can be processed intelligently (sub-agent summarization, targeted grep, etc.). Never discard output.

Threshold is configurable. Default is permissive — override via environment variable or work order parameter when stricter gating is needed.

When output is gated, surface this to the user — including the threshold value, the actual size, and that the threshold is configurable. Assume the user wants to know unless there's tangible evidence they're already aware or wouldn't care (e.g., they configured the threshold themselves, or they've acknowledged a prior gating event in the same session).

```bash
TMPOUT=$(mktemp)
trap 'rm -f "$TMPOUT"' EXIT
cat "$f" > "$TMPOUT"
BYTES=$(wc -c < "$TMPOUT")
GATE_THRESHOLD="${BCTB_GATE_THRESHOLD:-200000}"
if [ "$BYTES" -le "$GATE_THRESHOLD" ]; then
  cat "$TMPOUT"
else
  echo "[GATED: ${BYTES} bytes — retained at ${TMPOUT} for targeted processing]"
fi
```

## Sub-Agent Delegation

If sub-agents are available, delegate tool calls through them as a context blast shield. Sub-agents should also batch internally using the patterns above. See `references/sub-agent-delegation.md`.

## Output Format

For MIME tier details (aimpack → munpack-compat → tagged separators), see `references/output-format.md`.

## Planning

For complex multi-operation tasks, plan a tool manifest before executing. See `references/tool-manifest.md`.

## Anti-Patterns

- **Serial single-file reads** — most common waste. Batch or delegate.
- **Unbounded commands without guards** — `find /`, `grep -r`, `cat unknown_file`. Always guard.
- **Assuming output size** — README.md could be 5 lines or 5000. Don't guess; pre-check with `wc -l`.
- **Re-reading unchanged files** — already in context. Don't re-read.
- **Speculative reads** — reading "just to check" without a plan. Batch with purpose.
- **Ignoring native parallelism** — issuing 5 sequential tool calls when the harness supports parallel calls in one turn.

## Integration

- **cbtdag/taskdagger**: Work order = contract. Same pattern.
- **aimpack**: Tier 1 output format for structured returns.
- **winnow**: Distilled state informs work order Context sections.
