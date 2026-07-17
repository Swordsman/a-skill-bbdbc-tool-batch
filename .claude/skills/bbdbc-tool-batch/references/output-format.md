# Output Container Format

Tool outputs — from sub-agents or batched bash — use MIME containers for structured, parseable boundaries.

## Tier 1: aimpack (if skill available)

Full aimpack containers — proper MIME multipart/mixed, Content-Type headers, S-expression instructions, edit history. See the aimpack skill.

## Tier 2: Minimal munpack-compatible MIME (default fallback)

```
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="UNIQUE_BOUNDARY"

--UNIQUE_BOUNDARY
Content-Type: text/plain; charset=utf-8
Content-Disposition: attachment; filename="result.txt"

[content]

--UNIQUE_BOUNDARY
Content-Type: application/json
Content-Disposition: inline; name="metadata"

{"status": "ok", "files_read": 3}

--UNIQUE_BOUNDARY--
```

Rules:
- Boundary: randomly generated (e.g., `batch_` + 16 hex chars), **must not appear in any payload** — scan all input files for collisions before emitting any output; regenerate and re-scan if a collision is found. Never regenerate mid-output — earlier parts already used the old boundary, producing malformed MIME.
- Each part gets `Content-Type` and `Content-Disposition` or `name` parameter
- Final boundary gets trailing `--`

## Tier 3: Tagged separators (last resort)

```
=== FILE:config.yaml BOUNDARY:a7f3x9q2 ===
[content]
=== END:config.yaml BOUNDARY:a7f3x9q2 ===
```

**Adversarially fragile.** Any file containing the separator pattern causes content misattribution. Trivially injectable. Use only when Tier 1+2 are genuinely unavailable, never for untrusted input.
