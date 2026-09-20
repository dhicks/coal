# Jev HTTP API

Source: https://docs.typesafe.ai/api.md, /models.md, /introduction/quickstart.md (retrieved 2026-09-20; `jev-1.13.0`).

## Endpoints

| Method | URL | Purpose |
| ------ | --- | ------- |
| POST | `https://api.typesafe.ai/v1/systemone` | Evaluate one `state` against many typed `questions` |
| GET | `https://api.typesafe.ai/v1/models` | List model names and aliases the account can use |

Headers: `Authorization: Bearer <API_KEY>`, `Content-Type: application/json`.

## Request body

```json
{
  "state": "string | object | array",
  "model": "jev-latest",
  "questions": { "<id you choose>": { "type": "...", "instructions": "...", "criteria": "..." } }
}
```

- `state` (required): text to evaluate. String, JSON object, or array of text values. Text only (no images, audio, video). Prefer an object with named fields for anything beyond one passage.
- `model` (required): `jev-latest` or a versioned ID such as `jev-1.13.0`. See `models-and-limits.md`.
- `questions` (required): map from an id you choose to a question. The id is not sent to the model and does not affect inference. Answers come back under the same ids.
- All questions see the same state and are evaluated independently and in parallel. One answer never becomes context for another.

## Question types

All have `type` and `instructions`. `instructions` and every description inside `criteria` accept a string, object, array, or `null` (see `questions.md`).

| Type | `criteria` | Limits |
| ---- | ---------- | ------ |
| `noul` | optional object `{"true": ..., "false": ...}` describing yes and no | |
| `choice` | required map `{option: description-or-null}` | max 255 options |
| `score` | required ordered array of level descriptions | min 2 (advised), max 10 levels |

## Response body

```json
{
  "model": "jev-1.13.0",
  "answers": { "<id>": { "type": "...", "...": "..." } },
  "usage": { "input_tokens": 296, "output_tokens": 20 }
}
```

`model` is the versioned ID that answered (log it; aliases move). Output tokens are free; price is per input token.

### Answer shapes

| Type | Fields |
| ---- | ------ |
| `noul` | `noul`: number in [0, 1], probability of yes. No `confidence`. |
| `choice` | `choice`: highest-probability option. `probabilities`: `{option: p}`, sums to 1. `confidence`: 0 to 1. |
| `score` | `score`: probability-weighted mean level number (can fall between levels, range 0 to n−1). `legend`: `{"0": description, ...}`. `probabilities`: `{"0": p, ...}` keyed by level number **as strings**, sums to 1. `confidence`: 0 to 1. |

Example (choice, 3 options): `{"type":"choice","choice":"billing","probabilities":{"billing":0.88,"technical":0.12,"sales":0.0},"confidence":0.81}`

Example (score, 3 levels): `{"type":"score","score":1.05,"legend":{"0":"Calm","1":"Frustrated","2":"Very angry"},"probabilities":{"0":0.0,"1":0.95,"2":0.05},"confidence":0.92}`

When a level or option description was structured (object), `legend` returns that object, not a string.

## Errors

JSON body describing the problem. The docs list these statuses:

| Status | Meaning | Retry? |
| ------ | ------- | ------ |
| 401 | Missing or invalid API key | no |
| 422 | Body failed validation (body names the offending field) | no |
| 429 | Rate limit exceeded | yes, exponential backoff |
| 529 | Overloaded | yes, exponential backoff |

The Python SDK also maps 400 (bad request), 403 (permission denied), 404 (not found), and 5xx (server error), and reads the `x-typesafe-request-id` response header. See `sdk-behavior.md`.

## Minimal cURL

```bash
curl -X POST https://api.typesafe.ai/v1/systemone \
  -H "Authorization: Bearer $TYPESAFE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "state": "Help! My payouts have been failing for 3 days.",
    "model": "jev-latest",
    "questions": {
      "department": {"type": "choice", "instructions": "Which team should handle this?",
        "criteria": {"billing": "Payments, invoicing, refunds", "technical": "Bugs, outages, integrations", "sales": "Pricing, upgrades, new accounts"}},
      "frustration": {"type": "score", "instructions": "How frustrated is the customer?",
        "criteria": ["Calm", "Frustrated", "Very angry"]},
      "is_urgent": {"type": "noul", "instructions": "Does this convey urgency?"}
    }
  }'
```
