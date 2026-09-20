# Writing questions

Sources: /primitives.md, /primitives/{choice,score,noul,advanced}.md, /concepts/state.md (retrieved 2026-09-20).

Jev is a "System One" model: it makes one fast, focused judgment per question and returns typed answers with probabilities. It does not generate text or explain reasoning. Ask for a judgment a knowledgeable person makes in a second. If a task needs slow multi-step reasoning, split it into small questions and combine the answers in code.

## Choosing a type

| Need | Type | Notes |
| ---- | ---- | ----- |
| One of a fixed, unordered set | `choice` | Give the full list. Add `other` / `none_of_the_above` when the list may not cover every input. |
| Position on a spectrum you can describe in steps | `score` | Levels are ordered; describe situations, not degrees. |
| Is this true? | `noul` | The probability itself is the signal. Not a measure of degree. |

Prefer the type whose answer code can act on directly: Choice maps to code paths, Score to thresholds, Noul to an `if`.

## Noul

- One condition per question. "Angry and asking for a refund?" is two Nouls combined in code.
- Phrase so that high = yes. Avoid "Is X free of Y?".
- A statement works as well as a question ("The customer is requesting a refund").
- Make the yes/no boundary unambiguous ("any Python experience" beats "strong in Python"). If subtle, add `criteria.true` / `criteria.false`. Try with and without criteria and keep the better one on your data.
- A value of 0.5 means "yes and no equally likely", not "medium". Use a Score for degree.
- No `confidence` field; the value is both answer and certainty.
- Yes/no/uncertain thresholds are chosen in code. Example: `NO = 0.2`, `YES = 0.8`, middle goes to review.

## Choice

- `criteria` is a map `option → description`. Both option names and descriptions are sent to the model, so write descriptions that separate neighboring options. Use `null` when the name is self-explanatory.
- Up to 255 options; extra options cost a few tokens each. Send the full list rather than a shortlist.
- For deep taxonomies, ask one Choice per level and walk the tree in code (each option's value can be its subtree), or beam search over probabilities (see `patterns.md`).
- For confusable options, use object descriptions with `what`, `not_for`, `examples` (field names are yours; none are reserved).

## Score

- `criteria` is an ordered array. Level number = array index starting at 0. The model sees only descriptions, never the numbers, so numbers in descriptions or instructions do not help (levels `["0","1","2"]` performed badly in the docs' test).
- One dimension per Score. "punctual and smart and experienced" is three Scores.
- Up to 10 levels; use only as many as you can describe distinctly. Give a rare extreme its own level.
- `score` is a probability-weighted mean: Σ level × probability. The same score can come from different distributions; read `probabilities` and `confidence` too.
- Normalize before combining scores from scales of different length: `score / (n_levels - 1)`.
- Object levels with `what` and `examples` can shift results; examples help only when they resemble real inputs. Validate on labeled data. Higher confidence alone does not show a change is better.
- Do not interpolate between levels to recover an exact number (levels are weakly calibrated numerically).

## Structure in `state` and `instructions`

`instructions`, Choice option descriptions, Score level descriptions, and Noul `criteria.true/false` accept string, object, array, or `null`. Field names inside objects are yours; the model sees names and values.

Put the question in one field and data it refers to in others; refer to data by name in backticks:

```json
"instructions": {
  "potential_duplicate": {"name": "John Smith", "location": "Oakland, California"},
  "question": "Is the resume for the same person as `potential_duplicate`?"
}
```

Point at nested state with backticked dot-and-index paths: `` `ticket.messages[0].text` ``, `` `order.charges` ``. Use this whenever the state has several parts and a question concerns one of them.

Useful when: a question has several parts (labeled keys clarify), or supporting data (schema, taxonomy, database row) is already JSON. Start with plain strings and add structure when the model confuses neighbors.

## State

- Include only what the questions need. Accuracy falls as irrelevant content grows. Filter or retrieve in code first; a Noul can filter for relevance when code cannot.
- Keep related material together when a decision compares parts (message + order + policy in one object).
- Separate content (state) from judgments (questions). Do not rely on model weights for current facts; put them in state.
- English is best supported; other languages including CJK are accepted with lower accuracy.

## Batching

- Send every question for a state in one request, including speculative ones that matter only for some inputs; the code ignores answers it does not need. Cost is input tokens only. The docs' benchmark: 13 questions in one call was 12.2× cheaper and 10.0× faster than 13 calls with unchanged answers.
- Two requests are justified only when the second cannot be built without the first answer (fetching more data, choosing the next options, deciding what the state consists of).
- Questions cannot see each other's answers.
- Keep questions and thresholds in one file so they are easy to review. Agents write weak questions; expect to edit them by hand.
