# Tool Batch Skill — Development Context

This repo contains a single Claude Code skill at `.claude/skills/bbdbc-tool-batch/`. The skill teaches agents to minimize context window waste from tool calls.

## Core Principles (do not contradict these)

### Tool call economics

Every tool call is a full inference round-trip. The API is stateless — each request retransmits the entire conversation history. Each tool result joins context permanently, so the window grows with every call, making subsequent retransmissions progressively more expensive.

### Why batching matters

Without batching, a typical multi-operation task might make 5, 10, or even several dozen separate tool calls in a single user-assistant exchange turn. Each one retransmits the full (and growing) context window to the API endpoint. Batching takes those N tool calls and performs the work within a single tool call, intelligently concatenating the outputs into one well-formed, standards-based response (MIME multipart) that any AI can parse reliably.

This reduces N full context retransmissions to 1 — and that compounds over a conversation. Fewer calls means less context growth, which means cheaper subsequent calls, which means dramatically more work accomplished within the same quota. Less load on servers, more useful AI. This applies to agentic work and to regular chat involving tool calls.

### Batching is universal; delegation is additive

Batching is always beneficial. All agents — head agents and sub-agents alike — should plan ahead and batch their work strategically. When sub-agents are available, their context compartmentalization is an excellent adjunct to batching. Sub-agent delegation should always be utilized unless specific instructions exist indicating otherwise. But delegation does not replace batching — a sub-agent that doesn't batch internally is still wasting tokens within its own context.

### All tool output, not just files

The skill applies to all tool output — bash commands, API responses, MCP tools, logs, diffs — not just file reads. Any tool call that produces output is a candidate for batching, piping, or size gating. Previous sessions have regressed to file-read-only patterns; do not repeat this.

### Pipes reduce output at the source

Pipes keep intermediate data ephemeral — it exists in the pipe buffer but never enters context. `find src/ -name '*.py' | wc -l` produces a single number instead of a potentially massive file listing. This is a form of shielding analogous to sub-agent delegation, but at the command level. Pipes are the cheapest gate available and should be used wherever possible to extract exactly what's needed.

### "Parallel" tool calls are not parallel

What the harness calls "parallel tool calls" (multiple tool calls in a single turn) is not true parallelism. Each call still triggers a separate inference cycle that retransmits the full context. The "parallel" just removes the user interaction step between calls — it's sequential execution without manual iteration. Each call still burns the full context window.

True parallelism requires sub-agents, because each sub-agent is an independent inference process with its own context.

### The bottleneck is inference, not I/O

Disk reads take negligible time. The bottleneck is GPU inference — the agent's own thinking. You can't parallelize that within a single agent. Sub-agents are the only mechanism for parallel inference, because each one runs independently.

### This skill is about context efficiency, not speed

Parallelism is orthogonal. The skill teaches how to minimize context growth from tool output (via size gating, MIME batching, pipes, and delegation). Speed optimizations (fewer round-trips, faster I/O) are a separate concern and do not belong in this skill.

## Skill development rules

### The description is the trigger

The `description` field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes the skill. Claude undertriggers by default — descriptions must be pushy, with explicit trigger phrases covering the contexts where the skill should activate. See `references/skill-creation-guide.md` for the official guidance.

Description triggers must be phrased in terms of conditions the agent can observe about its own task, not in terms of the concepts the skill teaches. Agents generally lack deep understanding of their own execution mechanics — if they already understood the principles, they wouldn't need the skill. Terms like "multiple" and "sequential" describe observable task properties; terms like "batchable" presuppose understanding of batching and are ambiguous (does it mean "can be" or "should be"). The current description's use of "batchable" is a known weak point — revisit it periodically to see if a more observable trigger phrase emerges from real usage patterns.

### Don't add features the skill doesn't need

Previous sessions have invented unnecessary mechanisms (persistent retain directories, "native parallel" as a batching strategy). If a proposed change doesn't serve context efficiency, it doesn't belong. Evaluate changes against the core principles above.

### Keep SKILL.md lean

The skill body stays in context for the rest of the session once loaded. Every line is a recurring token cost. Use progressive disclosure — keep essential workflow in SKILL.md, move details to `references/` and `scripts/`.

### Surface lack of understanding

If any instruction, principle, or rationale is unclear, say so explicitly rather than silently complying. An agent that acts on incomplete understanding produces hidden failures — changes that look correct but subtly contradict the intent. This is unacceptable. Ask for clarification before writing code or documentation based on assumptions. The cost of asking is one exchange; the cost of a hidden failure compounds across every future session that builds on the wrong foundation.
