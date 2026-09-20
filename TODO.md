# TODO

- [ ] Accept JSON object and array `state` values, not just strings. Needs an explicit rule distinguishing one object-state from several string states, since `jev(list(a = 'x', b = 'y'))` reads as either; the current code refuses a named list rather than guessing. Object states matter when a question refers to one named part of the state (`jev-docs/questions.md`).
- [ ] Decide whether response caching across pipeline runs is worth adding. `httr2::req_cache()` handles GET only, so it cannot cache `POST /v1/systemone`; `memoise` or saving `jev()` output as an `Rds` file are the alternatives.
- [ ] Consider a helper for the confidence formula `(n × max(p) − 1) / (n − 1)` and for other uncertainty measures computed from `_probs` (entropy, margin between the top two).
