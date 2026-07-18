# bbdbc-tool-batch

A Claude Code skill that teaches agents to minimize context window waste from tool calls.

## What it does

Every tool call is a full inference round-trip that retransmits the entire conversation history. Each tool result joins context permanently, so the window grows with every call and subsequent retransmissions get progressively more expensive. A typical multi-operation task might make 5, 10, or several dozen separate tool calls in a single exchange turn.

This skill injects techniques to cut that cost:

- **Pipes** — extract exactly what's needed at the command level so raw output never enters context. `find src/ -name '*.py' | wc -l` produces a number, not a file listing.
- **Size gating** — probe output size before committing to read it. Route large output to a temp file and report the path instead of inlining it.
- **Batching** — combine independent operations into single tool calls using MIME multipart containers, reducing N context retransmissions to 1.
- **Sub-agent delegation** — when available, route work to sub-agents whose disposable contexts shield the head agent from raw output.

These techniques apply to all tool output — bash commands, API responses, MCP tools, file reads, logs, diffs — not just files.

The skill activates automatically on any work request. Once loaded, its instructions stay in context for the rest of the session.

## Installation

### Project-level (this repo only)

Copy the skill directory into your project:

```bash
cp -r bbdbc-tool-batch/.claude/skills/bbdbc-tool-batch .claude/skills/
```

Or, if your project is this repo, the skill is already at `.claude/skills/bbdbc-tool-batch/`.

### Personal (all your local projects)

Copy the skill directory to your personal skills folder:

```bash
cp -r .claude/skills/bbdbc-tool-batch ~/.claude/skills/
```

The skill will be available in every Claude Code session you start locally.

### From the .skill file

The `bbdbc-tool-batch.skill` file at the repo root is a zip archive that can be presented to users via Claude Code's file presentation tools. When presented, it shows a **Save skill** button that installs the skill into the user's profile.

You can also unzip it manually:

```bash
unzip bbdbc-tool-batch.skill -d ~/.claude/skills/
```

### Claude.ai and Cowork (cloud sessions)

Cloud sessions and Cowork don't read `~/.claude/skills/` from your local machine. To make the skill available:

- **Cowork / Claude.ai**: Enable the skill for your claude.ai account from **Customize** in the Desktop app sidebar or from the skills settings on claude.ai.
- **Cloud sessions**: Commit the skill directory to the repository's `.claude/skills/`. Cloud sessions load project skills from the cloned repo.
- **Routines**: Same as cloud sessions — commit the skill to the repo, or ship it in a plugin declared in the repo's `.claude/settings.json`.

### Enterprise

Distribute via [managed settings](https://code.claude.com/docs/en/settings#settings-files) to make the skill available to all users in your organization.

### From the .aimpack file

The `bbdbc-tool-batch.aimpack` is a MIME multipart container bundling all skill files with SHA256 checksums. It's useful for AI-to-AI transfer, aimpack-aware tooling, or inspecting the full skill contents in a single plaintext-readable file.

## Usage

The skill triggers automatically whenever you ask Claude to do work — no manual invocation needed. You can also invoke it explicitly:

```
/bbdbc-tool-batch
```

Once loaded, the skill instructs the agent to:

1. Plan tool operations before executing (enumerate, classify, group into batches)
2. Use pipes to extract exactly what's needed from command output
3. Pre-check sizes before reading unknown content
4. Batch independent operations into single tool calls
5. Delegate to sub-agents when available
6. Gate large output to temp files instead of inlining it

## Repo structure

```
.claude/skills/bbdbc-tool-batch/
  SKILL.md                           # Main skill instructions (loaded into context)
  references/
    rationale.md                     # Why this skill exists — the full argument
    output-format.md                 # MIME container format tiers
    sub-agent-delegation.md          # Work order format and composition patterns
    tool-manifest.md                 # Planning phase for complex tasks
    skill-creation-guide.md          # Skill authoring reference
  scripts/
    mime-batch.sh                    # Batch-read files into MIME containers
    size-gate.sh                     # Size-gate files or piped output
    conditional-batch.sh             # Branch on runtime values, batch-read results

bbdbc-tool-batch.skill               # Distributable zip archive
bbdbc-tool-batch.aimpack             # Distributable MIME container
build-distributables.sh              # Regenerates both distributable files
CLAUDE.md                           # Development context and principles
```

## Building distributables

After making changes to the skill, regenerate both distributable files:

```bash
./build-distributables.sh
```

This produces `bbdbc-tool-batch.skill` (zip) and `bbdbc-tool-batch.aimpack` (MIME) at the repo root. Requires the [skill-creator](https://github.com/anthropics/skills) to be installed at `~/.claude/skills/skill-creator` (override with `SKILL_CREATOR_PATH`).
