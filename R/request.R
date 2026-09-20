# Building requests ----

#' Build Jev requests without sending them
#'
#' Turns each element of `state` into one `httr2` request against `POST /v1/systemone`, with the timeout, retry, and rate-limit policy applied. Nothing is sent. Use this to inspect a request, to modify it with further `httr2` verbs, or to separate building from sending; [jev()] does all three stages at once.
#'
#' @param state The text to evaluate, as a character vector or a list of single strings. Each element is one state and gets its own request. JSON object and array states are not supported yet.
#' @param questions A named list of questions, each from [jev_noul()], [jev_choice()], or [jev_score()], or a hand-written list with the same shape. The names are ids you choose; answers come back under them. The ids are not sent to the model.
#' @param model The model to evaluate with. Defaults to [jev_default_model()]. Use `jev-latest` while exploring and pin a versioned id such as `jev-1.13.0` once thresholds are tuned.
#' @param rpm Requests per minute to throttle to. The documented limit is 1,200.
#'
#' @return A list of `httr2_request` objects, one per element of `state`, in the same order.
#' @export
#' @examples
#' ## Building a request needs an API key, though it sends nothing.
#' \dontrun{
#' spec = list(is_urgent = jev_noul('Does this convey urgency?'))
#' reqs = jev_request('Help! My payouts have been failing.', spec)
#' reqs[[1]]
#' }
jev_request = function(state, questions, model = jev_default_model(), rpm = 1000) {
    state = check_state(state)
    check_questions(questions)
    check_string(model, arg = 'model')

    base = jev_base_request(rpm) |>
        req_url_path_append('v1', 'systemone')

    lapply(state, function(one_state) {
        req_body_json(base, list(state = one_state, model = model, questions = questions))
    })
}

#' Base request carrying authentication and the client policy
#'
#' Shared by [jev_request()] and [jev_models()]. `req_auth_bearer_token()` marks the key as a secret, so it is redacted when a request is printed.
#' @noRd
jev_base_request = function(rpm = 1000) {
    request(jev_base_url()) |>
        req_auth_bearer_token(jev_key()) |>
        req_user_agent('coal (R client for Jev)') |>
        req_timeout(10) |>
        req_error(body = jev_error_body) |>
        req_retry(
            max_tries = 3,
            max_seconds = 30,
            retry_on_failure = TRUE,
            is_transient = jev_is_transient,
            backoff = jev_backoff,
            after = jev_retry_after
        ) |>
        req_throttle(capacity = rpm, fill_time_s = 60)
}

# Retry policy ----

## Defaults follow TypeSafe's Python SDK (jev-docs/sdk-behavior.md): 3 tries, a 30 second budget, backoff doubling from 0.5s to a 5s cap with up to 25% subtracted as jitter.

#' Retry 408, 429, and every 5xx, including the 529 the API uses for overload. 401 and 422 are permanent and are not retried.
#' @noRd
jev_is_transient = function(resp) {
    status = resp_status(resp)
    status %in% c(408L, 429L) || status >= 500L
}

#' @noRd
jev_backoff = function(i) {
    delay = min(5, 0.5 * 2^(i - 1))
    delay * runif(1, 0.75, 1)
}

#' Honor the server's own delay, preferring the millisecond header the SDK reads.
#' @noRd
jev_retry_after = function(resp) {
    ms = resp_header(resp, 'retry-after-ms')
    if (!is.null(ms)) {
        seconds = suppressWarnings(as.numeric(ms))
        if (!is.na(seconds)) return(seconds / 1000)
    }
    resp_retry_after(resp)
}

# Errors ----

#' Pull the API's own explanation into the R condition
#'
#' A 422 body names the field that failed validation, which is the most useful thing the API returns. The request id helps TypeSafe support trace a call.
#' @noRd
jev_error_body = function(resp) {
    request_id = resp_header(resp, 'x-typesafe-request-id')
    message = tryCatch(
        {
            body = resp_body_json(resp, simplifyVector = FALSE)
            first_string(body$message, body$error$message, body$error, body$detail)
        },
        error = function(e) NULL
    )
    if (is.null(message)) {
        message = tryCatch(substr(resp_body_string(resp), 1, 200), error = function(e) NULL)
    }
    c(message, if (!is.null(request_id)) c('i' = paste('Request id:', request_id)))
}

#' First argument that is a single non-empty string
#' @noRd
first_string = function(...) {
    for (x in list(...)) {
        if (is.character(x) && length(x) == 1L && nzchar(x)) return(x)
    }
    NULL
}

# Input checks ----

#' Normalize `state` to a list of single strings
#'
#' JSON object and array states are documented but not supported yet, because `list(a = 'x', b = 'y')` reads as either one object-state or two string states.
#' @noRd
check_state = function(state, call = caller_env()) {
    ## Names on a character vector are harmless document labels, so drop them.
    if (is.character(state)) state = as.list(unname(state))

    is_one_string = function(x) is.character(x) && length(x) == 1L && !is.na(x)
    if (!is.list(state) || !all(vapply(state, is_one_string, logical(1)))) {
        cli_abort(
            c('{.arg state} must be a character vector or a list of single strings, not {.obj_type_friendly {state}}.',
              'i' = 'Each element is one state and gets its own request.',
              'i' = 'JSON object and array states are not supported yet.'),
            call = call
        )
    }
    ## A named list reads either as several string states or as one JSON object state, so refuse to guess.
    if (!is.null(names(state))) {
        cli_abort(
            c('{.arg state} must be a character vector or a list of single strings, not a named list.',
              'i' = 'A named list could mean several states or one JSON object state; JSON object states are not supported yet.',
              'i' = 'Use {.code unname()} or a character vector for several states.'),
            call = call
        )
    }
    state
}

#' @noRd
check_string = function(x, arg, call = caller_env()) {
    if (!is.character(x) || length(x) != 1L || is.na(x)) {
        cli_abort(
            '{.arg {arg}} must be a single string, not {.obj_type_friendly {x}}.',
            call = call
        )
    }
    invisible(x)
}
