# Tool Batch Skill — Development Context

This repo contains a single Claude Code skill at `.claude/skills/context-efficient-ops/`. The skill teaches agents to minimize context window waste from tool calls.

## Core Principles (do not contradict these)

### Tool call economics

Every tool call is a full inference round-trip. The API is stateless — each request retransmits the entire conversation history. Each tool result joins context permanently, so the window grows with every call, making subsequent retransmissions progressively more expensive.

### "Parallel" tool calls are not parallel

What the harness calls "parallel tool calls" (multiple tool calls in a single turn) is not true parallelism. Each call still triggers a separate inference cycle that retransmits the full context. The "parallel" just removes the user interaction step between calls — it's sequential execution without manual iteration. Each call still burns the full context window.

True parallelism requires sub-agents, because each sub-agent is an independent inference process with its own context.

### The bottleneck is inference, not I/O

Disk reads take negligible time. The bottleneck is GPU inference — the agent's own thinking. You can't parallelize that within a single agent. Sub-agents are the only mechanism for parallel inference, because each one runs independently.

### Always delegate

Sub-agent creation cost ≈ direct tool call cost (both are one round-trip retransmitting full context). Delegation at worst breaks even, and for anything non-trivial it's strictly better because raw output stays in the sub-agent's disposable context instead of joining the head agent's permanent context. There is no valid efficiency reason to skip delegation — only skip it when delegation is impossible (no sub-agent support in the environment).

### This skill is about context efficiency, not speed

Parallelism is orthogonal. The skill teaches how to minimize context growth from tool output (via size gating, MIME batching, and delegation). Speed optimizations (fewer round-trips, faster I/O) are a separate concern and do not belong in this skill.

## Skill development rules

### The description is the trigger

The `description` field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes the skill. Claude undertriggers by default — descriptions must be pushy, with explicit trigger phrases covering the contexts where the skill should activate. See `references/skill-creation-guide.md` for the official guidance.

### Don't add features the skill doesn't need

Previous sessions have invented unnecessary mechanisms (persistent retain directories, "native parallel" as a batching strategy). If a proposed change doesn't serve context efficiency, it doesn't belong. Evaluate changes against the core principles above.

### Keep SKILL.md lean

The skill body stays in context for the rest of the session once loaded. Every line is a recurring token cost. Use progressive disclosure — keep essential workflow in SKILL.md, move details to `references/` and `scripts/`.
