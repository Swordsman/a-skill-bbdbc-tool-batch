---
name: blackcontract-tool-batch
description: "Batch tool calls, gate output by size, delegate to sub-agents. Minimizes token waste and protects the context window."
---

# Blackcontract Tool Batch

Tool calls retransmit the full context window and output joins context permanently; this skill minimizes both costs. For full rationale, see `references/rationale.md`.

## Core Technique: Batch Everything

Combine multiple tool operations into single calls. This applies universally — head-agents, sub-agents, any context where tools are called.

### Pre-check before committing

Before reading unknown files, use lightweight probes to avoid blowing up context:

```bash
wc -c src/auth/*.py           # byte counts — token burn correlates with bytes, not lines
head -c 500 src/app.py        # structure check without full read
find src/ -name '*.py' | wc -l  # file count — decides batching strategy
```

### MIME-wrapped bash batch

See `scripts/mime-batch.sh` for the executable version. Core pattern:

```bash
# Usage: ./scripts/mime-batch.sh file1.py file2.py config.yaml
# Env: BATCH_GATE_THRESHOLD (default 200000 bytes)
#      BATCH_RETAIN_DIR     (default .batch-retained)
```

Reads each file, wraps it in a MIME multipart boundary. Files exceeding the gate threshold are copied to the retain directory and a gating notice is emitted instead of the content. The retain directory persists across sessions — gated output is never lost.

### With conditional branching (1 round-trip instead of 3)

See `scripts/conditional-batch.sh`. Reads a runtime value, branches on it, and batch-reads only the relevant files — all in one tool call.

### Size guards (ALWAYS include)

Every file read must be gated by byte count. See `scripts/size-gate.sh` for the standalone version.

Route output through the gate. Return inline only if under threshold; otherwise retain to the persistent directory and report. Never discard output.

Threshold is configurable via `BATCH_GATE_THRESHOLD` (default: 200000 bytes). Retain directory is configurable via `BATCH_RETAIN_DIR` (default: `.batch-retained`).

When output is gated, surface this to the user — including the threshold value, the actual size, and that the threshold is configurable. Assume the user wants to know unless there's tangible evidence they're already aware or wouldn't care (e.g., they configured the threshold themselves, or they've acknowledged a prior gating event in the same session).

## Sub-Agent Delegation

If sub-agents are available, delegate tool calls through them as a context blast shield. Sub-agents should also batch internally using the patterns above. See `references/sub-agent-delegation.md`.

## Output Format

For MIME tier details (aimpack → munpack-compat → tagged separators), see `references/output-format.md`.

## Planning

For complex multi-operation tasks, plan a tool manifest before executing. See `references/tool-manifest.md`.

## Anti-Patterns

- **Serial single-file reads** — most common waste. Batch or delegate.
- **Unbounded commands without guards** — `find /`, `grep -r`, `cat unknown_file`. Always guard.
- **Assuming output size** — README.md could be 500 bytes or 500KB. Don't guess; pre-check with `wc -c`.
- **Re-reading unchanged files** — already in context. Don't re-read.
- **Speculative reads** — reading "just to check" without a plan. Batch with purpose.
- **Volatile temp files** — `mktemp` in `/tmp` is wiped on reboot. Gated output must persist. Use `BATCH_RETAIN_DIR`.

## Integration

- **cbtdag/taskdagger**: Work order = contract. Same pattern.
- **aimpack**: Tier 1 output format for structured returns.
- **winnow**: Distilled state informs work order Context sections.
