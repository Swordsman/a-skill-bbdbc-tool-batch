---
name: bbdbc-tool-batch
description: "Tool call batching (+delegation if able) to improve token efficiency. Use when tool calls are 1) multiple, 2) sequential, 3) batchable, or 4) routable to a sub-agent."
---

# BBDBC Tool Batch

Tool calls retransmit the full context window and output joins context permanently; this skill minimizes both costs. Applies to all tool output — file reads, bash commands, API calls, MCP tools — not just files. For full rationale, see `references/rationale.md`.

## Core Technique: Reduce Output at the Source

Every byte of tool output joins context permanently. Always minimize what enters context — every agent, head or sub-agent, applies these techniques on every tool call.

### Pipes: the cheapest gate

Pipes truncate output before it reaches context. Use them to extract what's needed and discard the rest:

```bash
# Counts instead of listings
find src/ -name '*.py' | wc -l                    # file count, not file list
git log --oneline | wc -l                          # commit count, not full log

# Bounded output
git log --oneline -20                              # last 20, not all history
git diff --stat                                    # summary, not full diff
docker logs app 2>&1 | tail -50                    # last 50 lines, not all logs

# Extract specific data
grep -c 'def ' src/auth/*.py                       # function counts per file
jq '.dependencies | keys' package.json             # dep names, not full lockfile
kubectl get pods -o name                            # names only, not full table
```

The pattern: ask "what do I actually need to know?" and pipe to get exactly that. A count, a summary, the last N lines, a specific field — not the raw dump.

### Pre-check before committing

Before reading unknown content, probe its size:

```bash
wc -c src/auth/*.py                                # byte counts for files
git diff | wc -c                                   # diff size before reading it
curl -sI https://api.example.com/data | grep -i content-length  # API response size
```

### Size gate

Route any output — file or command — through a size gate. Inline if under threshold; otherwise save to a temp file and report the path. See `scripts/size-gate.sh`:

```bash
./scripts/size-gate.sh myfile.py                   # gate a file
git diff HEAD~5 | ./scripts/size-gate.sh           # gate a command via stdin
kubectl logs deploy/app | ./scripts/size-gate.sh   # gate any piped output
```

Threshold is configurable via `BATCH_GATE_THRESHOLD` (default: 200000 bytes). When output is gated, surface this to the user — including the threshold, the actual size, and that the threshold is configurable.

## Batch Multiple Operations

Combine independent operations into single tool calls to reduce round-trips.

### Command batching

```bash
# One call instead of three
echo "=== git status ===" && git status --short
echo "=== recent commits ===" && git log --oneline -10
echo "=== branch ===" && git branch --show-current
```

### MIME-wrapped file batch

For multi-file reads, `scripts/mime-batch.sh` wraps each file in a MIME multipart container with size gating:

```bash
./scripts/mime-batch.sh src/app.py src/config.py src/auth.py
```

### Conditional branching (1 round-trip instead of N)

See `scripts/conditional-batch.sh` — reads a runtime value, branches on it, and batch-reads only the relevant files in one call.

## Sub-Agent Delegation

Batching and pipes apply universally. Sub-agents are an *additional* layer — when available, always use them because they provide a disposable context that shields the head agent from raw output. Sub-agents apply all the same batching and pipe techniques internally. See `references/sub-agent-delegation.md` for work order format and composition patterns.

## Output Format

For MIME tier details (aimpack → munpack-compat → tagged separators), see `references/output-format.md`.

## Planning

For complex multi-operation tasks, plan a tool manifest before executing. See `references/tool-manifest.md`.

## Anti-Patterns

- **Unbounded commands** — `find /`, `grep -r`, `git log`, `docker logs`, `cat unknown_file`. Always pipe to bound output.
- **Serial single-item tool calls** — batch or delegate.
- **Assuming output size** — README.md could be 500 bytes or 500KB. `git diff` could be 3 lines or 3MB. Pre-check or pipe.
- **Re-reading unchanged content** — already in context. Don't re-read.
- **Requesting full output when a summary suffices** — use `--stat`, `--short`, `--oneline`, `| wc -l`, `| head`, `jq` selectors.

## Integration

- **cbtdag/taskdagger**: Work order = contract. Same pattern.
- **aimpack**: Tier 1 output format for structured returns.
- **winnow**: Distilled state informs work order Context sections.
