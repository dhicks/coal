# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

An R API client for Jev, TypeSafe's classification model (a "System One" model: it returns typed answers with probabilities, not generated text). TypeSafe publishes Python and JavaScript SDKs only, so this client is built directly against the HTTP API.

The repository root is the R package `coal`. Its user-facing function is `jev()`, which is vectorized over `state` and returns a tibble with one row per state. `jev_request()`, `jev_perform()`, and `jev_parse()` are the three stages `jev()` composes, and they stay public so callers can reach the unparsed JSON and the `httr2` responses. There is no lint configuration; `lintr` is not installed.

## Build, test, check

Run these from the repository root.

```r
devtools::load_all()                            # attach without installing
devtools::document()                            # after changing roxygen comments
devtools::test()                                # mocked tests; no key or network needed
devtools::test(filter = 'parse')                # one test file
devtools::check(document = FALSE, args = '--no-manual')
```

`devtools::check()` reports one NOTE, "unable to verify current time", because the sandbox has no network. Everything else should be clean.

The live tests in `tests/testthat/test-live.R` make real API calls and are skipped unless `TYPESAFE_API_KEY` is set. The R REPL MCP is sandboxed from the network, so run them through `Rscript`:

```bash
Rscript -e "readRenviron('.env'); devtools::load_all(); testthat::test_file('tests/testthat/test-live.R')"
```

## Testing constraints

- `httr2::local_mocked_responses()` returns a mocked response before `req_perform()` reaches its retry loop, so retries cannot be exercised end to end. `tests/testthat/test-retry.R` tests the policy attached to the request and each policy function on its own instead.
- `httr2::req_dry_run()` fails in this environment with an Rcpp error. To inspect a serialized body, use the `request_json()` helper in `tests/testthat/helper-mock.R`, which applies `req$body$params` to `req$body$data` the way httr2 does at send time.
- `req_perform_parallel()` does not enforce `req_retry(max_tries)`. Tests that depend on the exact try count pass `max_active = 1`.

## Documentation

- `jev-docs/` is a condensed local reference. Start with `jev-docs/README.md`. It was written on 2026-09-20 for `jev-1.13.0`.
- Source: https://docs.typesafe.ai. Full index: https://docs.typesafe.ai/llms.txt. Every page has a Markdown version at its URL plus `.md`.
- The Python SDK docs define the reference client behavior (defaults, retries, error types). See `jev-docs/sdk-behavior.md`.

## API essentials

- One evaluation endpoint: `POST https://api.typesafe.ai/v1/systemone` with `Authorization: Bearer <key>` and body `{state, model, questions}`. `GET /v1/models` lists models.
- `questions` is a map from an id you choose to a typed question (`noul`, `choice`, `score`). Answers return under the same ids. Ids are not sent to the model.
- Answers: `noul` has one number in [0, 1]. `choice` has `choice`, `probabilities`, `confidence`. `score` has `score`, `legend`, `probabilities`, `confidence`.
- Score levels are numbered from 0 (array index), and `probabilities` and `legend` use those numbers as **string** keys. R indexing starts at 1, so convert explicitly.
- Use the alias `jev-latest` for exploration. Pin `jev-1.13.0` when thresholds are tuned, and store the response's `model` field with results.
- Retry 408, 429, and 5xx (including 529) with backoff, honoring `Retry-After`. Do not retry 401 or 422.

## Credentials

The API key is in `.env` under the variable `TYPESAFE_API_KEY`. `.env` is gitignored. Do not print, log, or commit its contents. Request logging that includes the state may expose data, so avoid logging bodies.

## Design rules that span several docs pages

- Send all questions for one state in a single request, including ones that only matter for some inputs. Code decides which answers to use. Separate requests are justified only when the second request cannot be built without the first answer.
- Keep arithmetic, counting, and date comparison in R. Jev is unreliable at them (`jev-docs/models-and-limits.md`).
- Normalize a Score by `score / (n_levels - 1)` before combining Scores from scales of different length.
- Keep question text and thresholds in one file so they can be reviewed together.
- Gate actions on `confidence` (Choice, Score) or on two cutoffs of `noul`. Choose thresholds per action based on the cost of an error, and tune them on labeled data.

## R serialization pitfalls

httr2 1.3.0 is installed. The jsonlite output below was run in this environment. The API's reaction to malformed bodies was not tested; those points follow from the documented schema (`jev-docs/api.md`).

- `toJSON()` output with default settings turns scalar strings into one-element arrays (`["text"]`). The schema expects `state` as a string, so use `auto_unbox = TRUE`.
- A Choice option with no description must serialize as JSON `null`. `toJSON(list(a = NULL))` produces `{"a":{}}` by default. Use `null = "null"`.
- `list(a = NULL)` keeps the NULL element, but `x$a <- NULL` deletes it. Build criteria with `list()` or `setNames()`.
- Score `criteria` is documented as an array, so pass an unnamed vector or list. A named list serializes as a JSON object.
- Noul `criteria` names must be exactly `true` and `false` (documented keys).
- `fromJSON()` returns Score `probabilities` and `legend` as lists named `"0"`, `"1"`, and so on.
