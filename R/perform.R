# Sending requests ----

#' Send Jev requests
#'
#' Performs a list of requests from [jev_request()] and returns the raw `httr2` responses, so the unparsed JSON and the HTTP metadata stay available. [jev_parse()] turns them into a data frame.
#'
#' @param reqs A list of requests from [jev_request()].
#' @param on_error What to do when a request still fails after its retries.
#'   * `'warn'`, the default: return an error condition in that position and carry on, so the states that succeeded are not lost.
#'   * `'stop'`: raise an error naming which element of `state` failed.
#' @param max_active Maximum number of concurrent requests. `1` sends them one at a time.
#' @param progress Show a progress bar? Also accepts a string to name the bar.
#'
#' @return A list the same length as `reqs` and in the same order. Each element is an `httr2_response`, or, under `on_error = 'warn'`, an error condition.
#'
#' @section Retries and the state in logs:
#' Requests carry the retry policy set in [jev_request()]. `httr2` does not enforce `max_tries` when requests run in parallel, so the cap of three tries per request holds exactly only at `max_active = 1`; the 30-second budget and the backoff schedule still apply.
#'
#' Do not call [httr2::req_perform()] with `verbosity` above 0 on these requests unless the state is safe to write to the console or a log, because the request body contains it.
#'
#' @export
#' @examples
#' \dontrun{
#' spec = list(is_urgent = jev_noul('Does this convey urgency?'))
#' resps = jev_perform(jev_request('Payouts have failed for 3 days.', spec))
#' resp_body_string(resps[[1]])  # unparsed JSON
#' jev_parse(resps, spec)        # data frame
#' }
jev_perform = function(reqs, on_error = c('warn', 'stop'), max_active = 5, progress = TRUE) {
    on_error = arg_match(on_error)
    if (length(reqs) == 0L) return(list())

    ## Always collect failures rather than letting httr2 abort, so the error message can name which state failed.
    resps = if (max_active == 1L) {
        req_perform_sequential(reqs, on_error = 'continue', progress = progress)
    } else {
        req_perform_parallel(reqs, on_error = 'continue', max_active = max_active, progress = progress)
    }

    failed = which(!vapply(resps, is_http_response, logical(1)))
    if (on_error == 'stop' && length(failed) > 0L) {
        abort_failed_state(resps, failed, n = length(reqs))
    }
    resps
}

#' Report the first failure, identified by its position in `state`
#'
#' The message quotes the status, the API's explanation, and the request id, never the state text, which may hold project data.
#' @noRd
abort_failed_state = function(resps, failed, n, call = caller_env()) {
    i = failed[[1]]
    detail = conditionMessage(resps[[i]])
    n_other = length(failed) - 1L
    cli_abort(
        c('State {i} of {n} failed.',
          'x' = '{detail}',
          if (n_other > 0L) c('i' = '{n_other} other state{?s} also failed.'),
          'i' = 'Use {.code on_error = "warn"} to keep the states that succeeded.'),
        call = call
    )
}

#' Error message for a failed state, for the `.jev_error` column
#' @noRd
failure_message = function(cnd) {
    paste(conditionMessage(cnd), collapse = ' ')
}

#' httr2 keeps `is_response()` internal, so test the class directly
#' @noRd
is_http_response = function(x) {
    inherits(x, 'httr2_response')
}
