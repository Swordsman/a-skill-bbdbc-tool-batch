# Official Skill Creation Guide

Consolidated from Anthropic's official sources:
- https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md
- https://github.com/anthropics/claude-plugins-official/blob/main/plugins/skill-creator/skills/skill-creator/SKILL.md
- https://code.claude.com/docs/en/skills
- "The Complete Guide to Building Skills for Claude" (Anthropic PDF)

---

## Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

## Progressive Disclosure

Skills use a three-level loading system to manage context efficiently:

1. **Metadata** (name + description) - Always in context (~100 words)
2. **SKILL.md body** - When skill triggers (<500 lines / <5k words)
3. **Bundled resources** - As needed by Claude (unlimited; scripts can execute without reading into context)

Key patterns:
- Keep SKILL.md under 500 lines
- If approaching this limit, add hierarchy with clear pointers to reference files
- Reference files clearly from SKILL.md with guidance on when to read them
- For large reference files (>300 lines), include a table of contents
- Prefer references files for detailed information unless it's truly core to the skill
- Keep only essential procedural instructions and workflow guidance in SKILL.md
- Move detailed reference material, schemas, and examples to references files
- Information should live in either SKILL.md or references files, not both

## YAML Frontmatter

```yaml
---
name: skill-name-in-kebab-case
description: What it does and when to use it.
---
```

### Required fields
- **name**: kebab-case only, should match folder name
- **description**: Must include WHAT + WHEN, under 1024 characters, no XML tags

### Naming rules
- Folder name uses kebab-case (no spaces, capitals, or underscores)
- No "claude" or "anthropic" in skill name
- No README.md inside skill folder
- SKILL.md must be exact (case-sensitive)

### Description best practices

The description field is the primary mechanism that determines whether Claude invokes a skill. Claude has a tendency to "undertrigger" skills — to not use them when they'd be useful. To combat this, make descriptions a little bit "pushy."

Structure: [What it does] + [When to use] + [Key capabilities]

Good: "Analyzes Figma design files and generates developer handoff documentation. Use when uploading .fig files or asking for design specs."

Bad: "Helps with projects" (too vague, missing triggers)

Instead of: "How to build a simple fast dashboard to display internal data."

Write: "How to build a simple fast dashboard to display internal data. Make sure to use this skill whenever the user mentions dashboards, data visualization, internal metrics, or wants to display any kind of company data, even if they don't explicitly ask for a 'dashboard.'"

Put the key use case first: the combined description and when_to_use text is truncated at 1,536 characters in the skill listing.

### Optional frontmatter fields

| Field                      | Description                                                                |
|:---------------------------|:---------------------------------------------------------------------------|
| `when_to_use`              | Additional trigger context, appended to description                        |
| `argument-hint`            | Hint shown during autocomplete, e.g. `[issue-number]`                      |
| `arguments`                | Named positional arguments for `$name` substitution                        |
| `disable-model-invocation` | Set `true` to prevent auto-invocation (manual `/name` only)                |
| `user-invocable`           | Set `false` to hide from `/` menu (background knowledge only)              |
| `allowed-tools`            | Tools Claude can use without asking permission during the invoking turn     |
| `disallowed-tools`         | Tools removed from Claude's pool while skill is active                     |
| `model`                    | Model override for this skill's turn                                       |
| `effort`                   | Effort level override (`low`, `medium`, `high`, `xhigh`, `max`)            |
| `context`                  | Set to `fork` to run in a forked subagent context                          |
| `agent`                    | Which subagent type to use when `context: fork` is set                     |
| `hooks`                    | Hooks scoped to this skill's lifecycle                                     |
| `paths`                    | Glob patterns limiting when skill activates                                |
| `shell`                    | Shell for `!command` blocks (`bash` or `powershell`)                       |

## Writing Style

- Write the entire skill using **imperative/infinitive form** (verb-first instructions), not second person
- Use objective, instructional language (e.g., "To accomplish X, do Y" rather than "You should do X" or "If you need to do X")
- Explain the **why** behind everything — today's LLMs are smart and work better when they understand reasoning rather than following rigid MUSTs
- If you find yourself writing ALWAYS or NEVER in all caps, that's a yellow flag — reframe and explain the reasoning instead
- Make the skill general and not super-narrow to specific examples
- Use theory of mind

## Skill Content Types

### Reference content
Adds knowledge Claude applies to current work — conventions, patterns, style guides, domain knowledge. Runs inline alongside conversation context.

### Task content
Step-by-step instructions for specific actions. Often invoked directly with `/skill-name`. Consider `disable-model-invocation: true` and `context: fork`.

## Skill Content Lifecycle

When invoked, the rendered SKILL.md content enters the conversation as a single message and stays there for the rest of the session. Once a skill loads, its content stays in context across turns, so every line is a recurring token cost. State what to do rather than narrating how or why.

## Dynamic Context Injection

The `!command` syntax runs shell commands before the skill content is sent to Claude:

```yaml
---
name: pr-summary
description: Summarize changes in a pull request
context: fork
---

## Pull request context
- PR diff: !`gh pr diff`
- Changed files: !`gh pr diff --name-only`

## Your task
Summarize this pull request...
```

## String Substitutions

| Variable                | Description                                   |
|:------------------------|:----------------------------------------------|
| `$ARGUMENTS`            | All arguments passed when invoking the skill   |
| `$ARGUMENTS[N]`         | Specific argument by 0-based index             |
| `$N`                    | Shorthand for `$ARGUMENTS[N]`                  |
| `$name`                 | Named argument from `arguments` frontmatter    |
| `${CLAUDE_SESSION_ID}`  | Current session ID                             |
| `${CLAUDE_EFFORT}`      | Current effort level                           |
| `${CLAUDE_SKILL_DIR}`   | Directory containing the SKILL.md file         |
| `${CLAUDE_PROJECT_DIR}` | Project root directory                         |

## Supporting Files

```
my-skill/
├── SKILL.md (required - overview and navigation)
├── reference.md (detailed API docs - loaded when needed)
├── examples.md (usage examples - loaded when needed)
└── scripts/
    └── helper.py (utility script - executed, not loaded)
```

Reference supporting files from SKILL.md so Claude knows what each file contains and when to load it.

### Scripts (`scripts/`)
- When the same code is being rewritten repeatedly or deterministic reliability is needed
- Token efficient, deterministic, may be executed without loading into context
- Scripts may still need to be read by Claude for patching or environment-specific adjustments

### References (`references/`)
- Documentation Claude should reference while working
- Keeps SKILL.md lean, loaded only when Claude determines it's needed
- If files are large (>10k words), include grep search patterns in SKILL.md

### Assets (`assets/`)
- Files used within the output Claude produces (templates, images, fonts)
- Not intended to be loaded into context

## Domain Organization

When a skill supports multiple domains/frameworks, organize by variant:

```
cloud-deploy/
├── SKILL.md (workflow + selection)
└── references/
    ├── aws.md
    ├── gcp.md
    └── azure.md
```

Claude reads only the relevant reference file.

## Writing Patterns

### Defining output formats
```
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

### Examples pattern
```
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

## Anti-patterns

- Overly rigid MUSTs and NEVERs without explaining why
- Overfitting to specific examples rather than generalizing
- Including information in both SKILL.md and reference files (duplication)
- Skills that could surprise users in their intent
- Descriptions that are too vague to trigger properly
- Skill body that's too long (wastes tokens every turn it stays in context)

## Evaluation and Iteration

### Triggering issues
- **Undertriggering**: Skill doesn't load when needed → add detail and nuance to description
- **Overtriggering**: Skill loads for irrelevant queries → add negative triggers, be more specific

### Testing approach
1. Triggering tests — does it fire on relevant prompts and not on unrelated ones?
2. Functional tests — does it produce correct output?
3. Performance comparison — tokens consumed, API calls, back-and-forth messages

### Iteration signals
- Read transcripts, not just final outputs
- Look for repeated work across test cases (bundle those scripts)
- Remove instructions that aren't pulling their weight
- Generalize from feedback rather than overfitting to examples
