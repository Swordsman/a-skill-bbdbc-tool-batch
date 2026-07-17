# Tool Manifest: Planning Phase

Before executing any tool operations, enumerate needs and plan batches. This is pure reasoning — zero tool calls, saves many round-trips.

## Steps

1. **List all operations** — files, commands, queries, API calls needed
2. **Classify each** — provably bounded? Dependencies between operations?
3. **Group into batches** — independent ops batch together; dependent chains stay in a single sub-agent
4. **Choose strategy** — sub-agent (default), batched bash (dependent chains or no sub-agents), direct (provably tiny)
5. **Specify output contracts** — for each batch/delegation, define what you need back

## Example

```
TASK: Understand project structure for refactoring
OPS:
  1. List Python files in src/       [unbounded count]
  2. Read src/app.py                 [unknown size]
  3. Read src/settings.py            [unknown size]
  4. Check coverage report           [potentially huge]
  5. Read requirements.txt           [unknown size]
PLAN:
  Sub-agent A (ops 1-3): dependent chain. Return file list + contents if <50KB each.
  Sub-agent B (op 4): high-risk. Return summary stats only.
  Sub-agent C (op 5): Return full contents. Fallback: if >100KB, dependency names only.
```
