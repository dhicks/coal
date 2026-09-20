# Probabilities, confidence, thresholds

Sources: /confidence.md, /patterns/confidence-routing.md, /primitives/noul.md, /agent-skill.md (retrieved 2026-09-20).

## What each number means

- `probabilities` (Choice, Score): distribution over options or levels; sums to 1.
- `noul` (Noul): probability of yes.
- `confidence` (Choice, Score only): 0 to 1, how concentrated `probabilities` is. 1.0 means all probability is on one outcome. It describes the model's answer, not a guarantee of correctness. Confidence is not probability: a Choice can have probability 0.61 on its top option and confidence 0.42.

### Confidence formula (derived, not documented as exact)

The docs state `(3 × largest probability − 1) / 2` for three options and describe the API value as computed from the spread. For n options or levels, `(n × max(p) − 1) / (n − 1)`, clamped to [0, 1], reproduces every published example (for instance 4 options with top probability 0.40 gives 0.20; 3 options with 0.57/0.43/0 gives 0.35). To use a different uncertainty measure (entropy, margin between top two), compute it from `probabilities`.

## Three paths

| Confidence | Action |
| ---------- | ------ |
| High | Act automatically |
| Medium | Act with caution: confirm, flag, or gather more information |
| Low | Do not act: route to a human, ask for clarification, or use another system |

Thresholds scale with the cost of a wrong action. Docs' examples: floor of 0.5 or 0.6 for "genuinely unsure → human"; above that, low-stakes actions proceed, destructive actions need > 0.85 or 0.9 or a user confirmation. The values are illustrations; tune on your own labeled data, starting conservative.

Related uses of `probabilities`:

- Notify a second team when a non-top option has probability above some cutoff (docs use 0.25).
- Ask the user instead of guessing when confidence on "what do you want" is below 0.5.
- Hierarchical classification: report the fine-grained group when confidence is high, or fall back to the broader parent category when it is low (cookbook: classification_using_confidence).

## When not to threshold on confidence

- If you only need the best option, take `choice`; do not add a threshold.
- If you have a specific statistical procedure in mind, use `probabilities` directly.
- Noul has no confidence; threshold `noul` itself with two cutoffs (yes above, no below, middle for review).

## Score arithmetic

- Normalize: `score / (n_levels - 1)` puts every Score on 0 to 1.
- Combine with weights held in code (composite scoring, see `patterns.md`). Change weights, not prompts, when priorities shift.
- Rounding a score to the nearest level is a fine way to get one decision (entity-alignment cookbook).
- Do not compare a threshold tuned on a Noul with one tuned on a Choice, and do not expect `P(x) + P(not x) = 1` across separate questions (see `models-and-limits.md`).
