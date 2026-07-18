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

## Agents and self-awareness

Agents generally lack deep understanding of their own execution mechanics — how tool calls work at the API level, what happens to context between turns, how inference cycles relate to token cost. This isn't a deficiency to fix; it's a structural reality. Models' training doesn't (and realistically can't) cover every detail of every execution environment, and those environments change constantly. Competent platforms try to fill gaps via system prompts, but those are written by humans with their own biases and blind spots, and can't catch everything.

This shapes how the skill must be designed:

- **If agents already understood the principles, they wouldn't need the skill.** The skill exists precisely to inject knowledge the agent doesn't have. Never assume the agent understands WHY it should follow the skill's instructions — explain the reasoning.
- **Trigger descriptions must use observable conditions, not taught concepts.** "Multiple tool calls" is something an agent can see about its own task. "Batchable" presupposes understanding of batching. The former triggers reliably; the latter depends on knowledge the skill hasn't loaded yet.
- **Temporal/parallel concepts are unreliable.** Agents' sense of time, if they can be said to have one, is disconnected from human time. "Sequential" may not parse correctly relative to the agent's own experience. "Multiple" was included as a safety net — it catches the same condition from a different angle that doesn't require understanding temporal ordering.

## Skill development rules

### The description is the trigger

The `description` field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes the skill. Claude undertriggers by default — descriptions must be pushy, with explicit trigger phrases covering the contexts where the skill should activate. See `references/skill-creation-guide.md` for the official guidance.

Description triggers must be phrased in terms of conditions the agent can observe about its own task, not in terms of the concepts the skill teaches. See "Agents and self-awareness" above for why. The previous description's use of "batchable" was replaced — the trigger now activates on any work request, which is the most observable condition possible ("the user asked me to do work").

### Don't add features the skill doesn't need

Previous sessions have invented unnecessary mechanisms (persistent retain directories, "native parallel" as a batching strategy). If a proposed change doesn't serve context efficiency, it doesn't belong. Evaluate changes against the core principles above.

### Keep SKILL.md lean

The skill body stays in context for the rest of the session once loaded. Every line is a recurring token cost. Use progressive disclosure — keep essential workflow in SKILL.md, move details to `references/` and `scripts/`.

### Surface lack of understanding

If any instruction, principle, or rationale is unclear, say so explicitly rather than silently complying. An agent that acts on incomplete understanding produces hidden failures — changes that look correct but subtly contradict the intent. This is unacceptable. Ask for clarification before writing code or documentation based on assumptions. The cost of asking is one exchange; the cost of a hidden failure compounds across every future session that builds on the wrong foundation.

### Persist deep insights

When a conversation produces insights that are fundamental, non-obvious, or important to the skill's design rationale — especially insights about how agents work, why certain design choices matter, or principles that inform future decisions — persist them to this file immediately. Conversation context is ephemeral; CLAUDE.md survives across sessions. An insight that isn't written down is an insight that will be re-derived (at best) or lost (at worst) by every future session. Don't wait until the end of a conversation to capture these — write them as they emerge.

### Produce distributable files on every commit

Whenever committing changes to the skill, regenerate both distributable files at the repo root by running `./build-distributables.sh` before committing:

- **`bbdbc-tool-batch.skill`** — a zip archive produced by the skill-creator's `package_skill` script. This is the distributable format that shows a "Save skill" button when presented to users.
- **`bbdbc-tool-batch.aimpack`** — an aimpack (MIME multipart) container bundling all skill files (SKILL.md, references, scripts) with SHA256 checksums per part. This is the full distributable bundle.

Both files must reflect the state of the skill *as it will be committed* — run the script after making skill changes but before `git add`. The script requires the skill-creator to be installed at `~/.claude/skills/skill-creator` (override with `SKILL_CREATOR_PATH`).
