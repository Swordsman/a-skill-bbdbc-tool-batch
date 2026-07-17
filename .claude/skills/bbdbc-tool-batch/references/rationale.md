# Why This Skill Exists

Every tool call triggers a full inference round-trip. The entire context window is retransmitted each time — the API is stateless, so every request sends the full conversation history. At 80K context, 5 file reads = ~400K tokens of redundant retransmission — `O(context_size)` cost per `O(1)` operation. And it's worse than that: each tool result joins context permanently, so the window grows with every call, making subsequent retransmissions even larger.

One bad return can destroy the conversation.

## The Ergonomics Mismatch

Shell tools were designed for human terminals in 1969. Their output — scrollable, visual, unbounded — is hostile to AI consumption where every token is permanent and irrecoverable. You almost never need raw output. You need to *know something*.

## Observed Failures

- `ls -la` on a large folder: completely destroyed a context window in a live session.
- `cat` on an 8MB file: crushed context AND exhausted a 5-hour usage quota in one call.
- `grep -r`, `find`, API responses, search results — all unbounded by default.

## The Core Insight

Batching takes N separate tool calls — each a full context retransmission — and performs the work within a single tool call, concatenating the outputs into one well-formed response. This reduces N retransmissions to 1, and that compounds over a conversation: fewer calls means less context growth, which means cheaper subsequent calls, which means dramatically more work per quota. This applies to all agents — head agents and sub-agents alike.

Pipes provide an additional layer of shielding at the command level. Intermediate data stays ephemeral in the pipe buffer and never enters context. `find src/ -name '*.py' | wc -l` produces a number, not a file listing.

Sub-agent delegation is an excellent adjunct to batching. Sub-agent creation cost ≈ regular tool call cost (both are one round-trip), but the sub-agent provides a disposable context — raw output stays there instead of joining the head agent's permanent context. Delegation should always be used when available, but does not replace batching — sub-agents apply the same batching and pipe techniques internally.

What the harness calls "parallel tool calls" (multiple calls in one turn) is not true parallelism — each call still triggers a separate inference cycle retransmitting the full context. The "parallel" just removes the user interaction step between calls. The bottleneck is inference (GPU processing), not I/O (disk reads are negligible). True parallelism requires sub-agents, because each sub-agent is an independent inference process with its own context.
