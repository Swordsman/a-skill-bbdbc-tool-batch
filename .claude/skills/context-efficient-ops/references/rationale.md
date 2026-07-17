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

Sub-agent creation cost ≈ regular tool call cost (both are one round-trip), but the sub-agent provides a context blast shield for free. There is no cost reason to skip delegation. The only valid exception is when output is **provably** zero-variance and trivially small — in practice, just datetime and single-path existence checks.

"Provably bounded" means you can guarantee output size before execution. Not "probably small," not "usually small" — *provably*.
