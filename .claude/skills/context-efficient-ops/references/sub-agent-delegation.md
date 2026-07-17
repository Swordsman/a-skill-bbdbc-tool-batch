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
OUTPUT SPEC: File list with line counts. Public functions/classes (name+sig only).
  Import graph. Do NOT return file contents unless <50 lines.
EXPECTATIONS: 5-20 files. If >50, report count and stop. Flag files >1000 lines.
FALLBACK: If src/auth/ missing, check auth/, authentication/. If nothing, report
  that — don't search entire repo. On tool errors, report and continue.
```

## When NOT to Delegate

Delegation has overhead (sub-agent spin-up, work order construction, result parsing). Skip it when:

- Output is **provably tiny** — `date`, `test -f path`, `echo $VAR` — and you know the exact shape before execution
- You're already inside a sub-agent — avoid nesting unless the inner call is itself high-risk
- The harness supports native parallel tool calls and the operations are simple independent reads with known-small files

"Provably tiny" means you can guarantee output size before execution. Not "probably small" — *provably*.

## Composition Granularity

Choose based on dependency structure, not habit:

- **1 sub-agent : 1 tool call** — max isolation, for high-risk/unpredictable calls
- **1 sub-agent : N tool calls** — dependent chains where intermediate results inform next steps
- **N sub-agents : 1 each** — max parallelism, independent operations
- **Hybrid** — mix as needed

## Return Format

Sub-agents return via MIME containers. See `output-format.md`.
