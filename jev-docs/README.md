# Jev quick reference

Agent-oriented condensation of the TypeSafe docs (https://docs.typesafe.ai). Retrieved 2026-09-20 for model `jev-1.13.0`. These files omit most examples and all Python and JavaScript SDK API detail. For anything not covered, fetch the source page.

Jev is TypeSafe's first "System One" model: it evaluates a `state` against typed questions (Choice, Score, Noul) and returns probabilities and confidence, not generated text.

| File | Read it when |
| ---- | ------------ |
| [api.md](api.md) | Building or debugging requests and response parsing: endpoints, schemas, errors |
| [questions.md](questions.md) | Writing or reviewing questions, criteria, state structure |
| [confidence-and-thresholds.md](confidence-and-thresholds.md) | Deciding what to do with answers: thresholds, score normalization |
| [models-and-limits.md](models-and-limits.md) | Choosing a model, checking rate limits and cost, avoiding known failure modes |
| [sdk-behavior.md](sdk-behavior.md) | Implementing client behavior: environment variables, retries, error types |
| [patterns.md](patterns.md) | Designing a workflow; finding a relevant cookbook |

## Fetching source pages

Every docs page has a Markdown version at the page URL plus `.md`. The full index is https://docs.typesafe.ai/llms.txt. Pages contain embedded JavaScript components; strip lines from `export function` to the closing `}` before reading.

```bash
curl -sL https://docs.typesafe.ai/primitives/choice.md
```

Not condensed here: JavaScript SDK class and interface pages, Python SDK client and type pages (`/sdk/python/api/...`), changelogs, legal, and individual cookbook bodies.

## Other sources

- Playground: https://console.typesafe.ai/playground
- API keys: https://console.typesafe.ai/keys
- TypeSafe agent skill (Claude Code plugin `typesafe@typesafe-ai`, or `npx skills add typesafe-ai/skills --skill typesafe-ai`): https://github.com/typesafe-ai/skills/blob/main/skills/typesafe-ai/SKILL.md
- Support: Discord (link on the jaggedness page), sales@typesafe.ai for higher rate limits
