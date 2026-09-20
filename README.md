# coal

An R client for [Jev](https://docs.typesafe.ai), TypeSafe's classification model. Jev evaluates a text `state` against typed questions and returns probabilities and confidence, not generated text. TypeSafe publishes Python and JavaScript SDKs only, so this package is built directly against the HTTP API.

The package is a thin wrapper: argument names are the HTTP field names, the main function is vectorized over states, and the raw responses stay reachable.

## Install

```r
devtools::install_local('.')
## or, while working on the package
devtools::load_all()
```

Put the API key in a `.env` file at the project root and load it before calling anything:

```
TYPESAFE_API_KEY=sk-...
```

```r
readRenviron('.env')
```

`.env` is gitignored. `TYPESAFE_BASE_URL` and `TYPESAFE_DEFAULT_MODEL` are also read if set.

## Use

Write the questions once, in one object, so the wording and the thresholds can be reviewed together:

```r
library(coal)

spec = list(
    department = jev_choice(
        'Which team should handle this?',
        criteria = c(billing = 'Payments, invoicing, refunds',
                     technical = 'Bugs, outages, integrations',
                     sales = 'Pricing, upgrades, new accounts')
    ),
    frustration = jev_score(
        'How frustrated is the customer?',
        criteria = c('Calm', 'Frustrated', 'Very angry')
    ),
    is_urgent = jev_noul('Does this convey urgency?')
)
```

`jev()` takes a vector of states and returns one row per state, in the same order:

```r
jev('Help! My payouts have been failing for 3 days.', spec)
#> # A tibble: 1 × 11
#>   department department_conf department_probs frustration frustration_conf ...
#>   <chr>                <dbl> <list>                 <dbl>            <dbl>
#> 1 billing               0.81 <named dbl [3]>         1.05             0.92
```

Because the result is a data frame of the right height, `mutate()` splices its columns onto the data frame the states came from:

```r
library(dplyr)

tickets |>
    select(id, body) |>
    mutate(jev(body, questions = spec)) |>
    filter(is_urgent > 0.8, department_conf > 0.6)
```

Questions can also be written as plain lists, which is the path to API features newer than this package:

```r
spec = list(is_urgent = list(type = 'noul', instructions = 'Does this convey urgency?'))
```

## Columns

For a question id `q`:

| Type | Columns |
| ---- | ------- |
| noul | `q`, the probability of yes |
| choice | `q`, `q_conf`, `q_probs` |
| score | `q`, `q_conf`, `q_probs`, `q_legend` |

plus `.jev_model`, `.jev_input_tokens`, and `.jev_error`. `q_probs` and `q_legend` are list-columns.

Score levels are numbered from **0**, and `q_probs` and `q_legend` use those numbers as names. They are level numbers, not R indices, so convert explicitly. `jev_normalize()` divides a score by `n_levels - 1`, which is what makes scores from scales of different length comparable:

```r
answers |>
    mutate(frustration_norm = jev_normalize(frustration, frustration_legend))
```

Keep `.jev_model` with saved results. `jev-latest` points at a new model when TypeSafe ships a release, so answers can change without any change to your code; pin a versioned id once thresholds are tuned.

## Raw JSON and HTTP responses

`jev()` runs three stages that can also be called separately. `httr2`'s own accessors work on the middle one:

```r
reqs = jev_request(docs, spec)   # httr2 requests, nothing sent
resps = jev_perform(reqs)        # httr2 responses

resp_body_string(resps[[1]])     # unparsed JSON
resp_body_json(resps[[1]])       # parsed list
resp_headers(resps[[1]])         # includes x-typesafe-request-id

jev_parse(resps, spec)           # the same data frame jev() returns
```

Do not raise `httr2::req_perform()`'s `verbosity` on these requests unless the state is safe to write to a log; the request body contains it.

## Failures

By default a state that fails after its retries becomes a row of `NA` answers with the message in `.jev_error`, and `jev()` warns. `on_error = 'stop'` raises instead, naming which element of `state` failed.

Requests are retried on 408, 429, and 5xx with backoff, honoring `Retry-After` and `retry-after-ms`; 401 and 422 are not retried. `httr2` does not enforce `max_tries` when requests run in parallel, so the cap of three tries per request holds exactly only at `max_active = 1`.

There is no response cache. `httr2::req_cache()` handles GET only, so it cannot cache `POST /v1/systemone`; use `memoise` or save `jev()` output as an `Rds` file.

## Limits

`state` must be a character vector or a list of single strings. The API also accepts JSON objects and arrays, which is worth having when a question refers to one named part of the state; that is not supported yet.

## Design notes

`jev-docs/` in this repository is a condensed local copy of the TypeSafe documentation. The points that shape how questions should be written:

- Send every question for a state in one request, including ones that matter only for some inputs, and let your code ignore the answers it does not need. A second request is justified only when it cannot be built without the first answer.
- Keep arithmetic, counting, and date comparison in R. Jev is unreliable at them.
- Gate actions on `_conf` for choices and scores, and on two cutoffs of the value itself for nouls. Choose thresholds per action from the cost of an error, and tune them on labeled data.
