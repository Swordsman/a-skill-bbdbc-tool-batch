# Why This Skill Exists

Every tool call triggers a full inference round-trip. The entire context window — including all prior tool results — is retransmitted each time. Context grows with each result: if you start at 80K tokens and make 5 file reads returning 10K tokens each, the 5th call retransmits ~120K tokens. Total input across all calls: ~500K tokens for 50K tokens of actual content. The cost is `O(n * context_size)` where context_size grows with each result — worse than linear.

Tool output also joins context permanently — one bad return can destroy the conversation.

## The Ergonomics Mismatch

Shell tools were designed for human terminals in 1969. Their output — scrollable, visual, unbounded — is hostile to AI consumption where every token is permanent and irrecoverable. You almost never need raw output. You need to *know something*.

## Observed Failures

- `ls -la` on a large folder: completely destroyed a context window in a live session.
- `cat` on an 8MB file: crushed context AND exhausted a 5-hour usage quota in one call.
- `grep -r`, `find`, API responses, search results — all unbounded by default.

## The Core Insight

Sub-agent creation cost ≈ regular tool call cost (both are one round-trip), but the sub-agent provides a context blast shield for free. There is no cost reason to skip delegation. The only valid exception is when output is **provably** zero-variance and trivially small — in practice, just datetime and single-path existence checks.

"Provably bounded" means you can guarantee output size before execution. Not "probably small," not "usually small" — *provably*.
