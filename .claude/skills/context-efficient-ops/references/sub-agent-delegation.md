# Sub-Agent Delegation

The sub-agent runs tools in a fresh, disposable context. Catastrophic output destroys the sub-agent — not the head-agent. The sub-agent extracts knowledge from raw output and returns only what's needed.

## Work Order (= DbC Contract)

Don't send bare tool calls. Send a structured work order — Design by Contract applied to delegation.

| Component | Contract Analog | Purpose |
|---|---|---|
| **Context** | Preamble | What the head-agent is doing and why |
| **Intent** | Task description | Specific goal of this delegation |
| **Output Spec** | Return type | What to return, in what shape — without this, sub-agent dumps raw output, defeating the purpose |
| **Expectations** | Invariants | What normal looks like, bounds on expected results |
| **Fallback** | Error handling | What to do when things go wrong |

### Example
```
CONTEXT: Refactoring auth module. Large monorepo, file sizes unknown.
INTENT: Read Python files under src/auth/, identify module structure + API surface.
OUTPUT SPEC: File list with byte counts. Public functions/classes (name+sig only).
  Import graph. Do NOT return file contents unless <10KB.
EXPECTATIONS: 5-20 files. If >50, report count and stop. Flag files >200KB.
FALLBACK: If src/auth/ missing, check auth/, authentication/. If nothing, report
  that — don't search entire repo. On tool errors, report and continue.
```

## Always Delegate

Sub-agent creation cost ≈ regular tool call cost. There is no cost reason to skip delegation. The only valid reason not to delegate is when delegation is impossible — the harness doesn't support sub-agents, or you're in an environment where only direct tool calls are available.

## Composition Granularity

Choose based on dependency structure, not habit:

- **1 sub-agent : 1 tool call** — max isolation, for high-risk/unpredictable calls
- **1 sub-agent : N tool calls** — dependent chains where intermediate results inform next steps
- **N sub-agents : 1 each** — max parallelism, independent operations
- **Hybrid** — mix as needed

## Return Format

Sub-agents return via MIME containers. See `output-format.md`.
