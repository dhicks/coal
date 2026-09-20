# coal 0.0.0.9000 (development version)

- Added `jev()`, which sends a vector of states to `POST /v1/systemone` and returns one row of typed answers per state, in input order.
- Added `jev_request()`, `jev_perform()`, and `jev_parse()`, the three stages `jev()` composes, so the unparsed JSON and the HTTP responses stay reachable through `httr2`'s own accessors.
- Added `jev_noul()`, `jev_choice()`, and `jev_score()` to build questions; `jev()` also accepts hand-written lists, so new API features need no package update.
- Added `jev_models()` for `GET /v1/models` and `jev_normalize()` for putting scores from scales of different length on a common range.
- Added `jev_key()`, `jev_base_url()`, and `jev_default_model()`, which read the same environment variables as TypeSafe's Python SDK.
- Requests carry the Python SDK's timeout and retry policy: a 10 second timeout, three tries within a 30 second budget, backoff doubling from 0.5s to a 5s cap with jitter, and `Retry-After` and `retry-after-ms` honored. 408, 429, and 5xx are retried; 401 and 422 are not.
- A state that fails returns a row of `NA` answers with the message in `.jev_error`; `on_error = 'stop'` raises instead, naming which state failed.
