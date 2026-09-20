# Reference client behavior (from the Python SDK)

Source: /sdk/python/*.md, /sdk/python/api/{constants,retries,exceptions}.md (retrieved 2026-09-20). TypeSafe ships Python (`typesafe-sdk`, Python ≥ 3.10) and JavaScript (`@typesafe-ai/sdk`) clients only. There is no R client. Use these defaults as the specification when building one.

## Configuration

| Setting | Env var | Default |
| ------- | ------- | ------- |
| API key (required) | `TYPESAFE_API_KEY` | none |
| Base URL | `TYPESAFE_BASE_URL` | `https://api.typesafe.ai` |
| Model | `TYPESAFE_DEFAULT_MODEL` | `jev-latest` |
| Log level | `TYPESAFE_LOG_LEVEL` (`debug`, `info`, `warning`, `error`, `off`) | unset |
| HTTP timeout per operation | none | 10.0 s |

## Retry policy defaults

| Field | Default |
| ----- | ------- |
| `max_retries` (after first attempt; 0 disables) | 2 |
| `backoff_initial` (seconds, doubled each attempt) | 0.5 |
| `backoff_max` (seconds) | 5.0 |
| `backoff_jitter` (fraction of each delay randomly subtracted) | 0.25 |
| Retried HTTP statuses | 408, 429, and 500–599 |
| Honor `Retry-After` and `retry-after-ms` headers | yes |
| Retry connection errors and timeouts | yes |
| Total retry budget per call (including delays) | 30.0 s; stop before a retry whose delay would reach the budget and re-raise the last error |

## Error classes

| Class | Condition |
| ----- | --------- |
| `TypeSafeAPIError` (base for HTTP errors) | Fields: `status`, `body` (JSON, text, or none), `headers`, `endpoint` (method and URL without credentials or query), `request_id` (from `x-typesafe-request-id`) |
| BadRequest | 400 |
| Authentication | 401 |
| PermissionDenied | 403 |
| NotFound | 404 |
| UnprocessableEntity | 422 |
| RateLimit | 429; carries `retry_after_ms` parsed from headers |
| InternalServer | 5xx |
| APIConnectionError | no HTTP response |
| APITimeoutError | request exceeded timeout (subclass of connection error) |
| ResponseValidationError | 2xx response missing or malformed required data; carries `field_path` such as `answers.tone.confidence` |

## Response conveniences in the Python SDK

- `response.answers[id]` gives each typed answer; `response.nouls`, `.choices`, `.scores` filter by type.
- The SDK keys Score `probabilities` and `legend` by integer level (the wire format uses string keys).
- Unrecognized answer kinds are logged and skipped; unknown extra response fields are ignored.
- Unknown request fields pass through (`extra_body`, raw question dicts), which is the forward-compatibility path for new API features.
- Logging redacts authorization headers but **not** request and response bodies; the state you send appears in debug logs.
