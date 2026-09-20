# Models, limits, known failure modes

Sources: /models.md, /model-jaggedness/jev-1.13.md (last reviewed by TypeSafe 2026-09-17), /concepts/system-one.md (retrieved 2026-09-20).

## Current model

| | |
| - | - |
| Versioned ID | `jev-1.13.0` |
| Price | $42 per billion input tokens ($0.042 per million). Output tokens free. |
| Rate limits | 250,000 tokens/second, 1,200 requests/minute; exceeding either returns 429. TypeSafe says limits change without notice. |
| Context | 64k tokens per request (state + all questions); 32k for state + the single longest question |
| Input | Text only: string, JSON object, array of text values |
| Typical latency | About 100 ms per query (TypeSafe's claim) |
| Data handling | Not trained on customer requests or responses. Zero data retention for enterprise. Details at /legal. |
| Customization | None per account (no fine-tuning). Shape behavior through `state`, `instructions`, `criteria`. |

Aliases: `jev-latest` → `jev-1.13.0` (latest stable; SDK default). `jev-preview` → `jev-1.13.0` (no preview build exists now). An alias moves when a release ships, so answers can change without code changes. Pin the versioned ID if thresholds are tuned, and record the response's `model` field with each result.

`GET /v1/models` returns `{"models": [{"name", "description", "release_date"}]}`. It currently lists aliases only; versioned IDs are accepted even when absent from the list.

## Jev 1.13 failure modes and what to do

| Failure mode | Do instead |
| ------------ | ---------- |
| Literal reading: answers the words written, not the intent | State the exact condition; put boundary cases in `criteria`; split interpretation into two literal questions |
| Counting, arithmetic, numeric comparison | Do it in code. To count matches, ask one Noul per item and sum in code |
| Numbers as hex, RGB, binary, assembly | Convert in code; pass computed numbers or named buckets |
| Interpolating between Score levels for an exact magnitude | Use score only for thresholds and ranking |
| Dates read as text (ordering, distance, windows) | Extract parts with Choices (month, day, year, with a "not stated" option); assemble and compare in code |
| Indirection, double negatives, multi-hop questions | Write directly; name the relevant part of state |
| Large state with irrelevant detail (context rot) | Filter in code first; send only needed fields |
| Adversarial content in state (injected instructions) | Precise criteria; test edge cases before deployment |
| `instructions` and `criteria` contradict (e.g. `true` means no) | Align them; treat criteria as part of the instruction |
| Assuming structural invariants across questions | Do not assume `noul` ≈ Choice `yes` probability, or P(x) + P(not x) = 1. A Choice is relative (which option); each Noul is absolute |
| Text generation | Not a generator. Extract candidates with regex or an LLM, then have Jev pick |

Avoid: asking something code can compute exactly; hiding several judgments in one question; multi-layer reasoning tasks; more state than the question needs.

## Non-English

English is the primary training language. Other languages work with lower accuracy; test on your content and rely on confidence for routing.
