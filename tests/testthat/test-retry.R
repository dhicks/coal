## httr2 returns a mocked response before it reaches its retry loop (see the mock branch at the top of
## `httr2::req_perform`), so retries cannot be exercised end to end with `local_mocked_responses()`.
## These tests check the policy attached to the request and each policy function on its own, and check
## what a caller sees when a request fails for good.

test_that('the retry policy matches the reference client', {
    local_fake_key()
    req = jev_request('a state', fixture_spec())[[1]]

    expect_equal(req$policies$retry_max_tries, 3)
    expect_equal(req$policies$retry_max_wait, 30)
    expect_true(req$policies$retry_on_failure)
    expect_equal(req$policies$retry_is_transient, jev_is_transient)
    expect_equal(req$policies$retry_backoff, jev_backoff)
    expect_equal(req$policies$retry_after, jev_retry_after)
})

test_that('408, 429, and 5xx are transient; 401 and 422 are not', {
    transient = function(status) jev_is_transient(httr2::response(status_code = status))

    expect_true(transient(408))
    expect_true(transient(429))
    expect_true(transient(500))
    expect_true(transient(529))
    expect_false(transient(401))
    expect_false(transient(422))
    expect_false(transient(404))
})

test_that('backoff doubles from 0.5s, caps at 5s, and stays within the jitter band', {
    delays = vapply(1:6, jev_backoff, numeric(1))

    expect_true(all(delays >= c(0.5, 1, 2, 4, 5, 5) * 0.75))
    expect_true(all(delays <= c(0.5, 1, 2, 4, 5, 5)))
})

test_that('retry-after-ms wins over Retry-After', {
    both = httr2::response(
        status_code = 429,
        headers = list(`retry-after-ms` = '250', `Retry-After` = '30')
    )
    expect_equal(jev_retry_after(both), 0.25)

    seconds_only = httr2::response(status_code = 429, headers = list(`Retry-After` = '30'))
    expect_equal(jev_retry_after(seconds_only), 30)

    neither = httr2::response(status_code = 429)
    expect_true(is.na(jev_retry_after(neither)))
})

test_that('the API explanation and request id reach the caller', {
    local_fake_key()
    httr2::local_mocked_responses(list(httr2::response_json(
        status_code = 422,
        headers = list(`x-typesafe-request-id` = 'req_abc123'),
        body = list(message = 'questions.frustration.criteria must have at least 2 items')
    )))

    expect_warning(
        answers <- jev('a state', fixture_spec()['is_urgent'], progress = FALSE, max_active = 1),
        'failed'
    )

    expect_match(answers$.jev_error, 'at least 2 items')
    expect_match(answers$.jev_error, 'req_abc123')
})

test_that('a non-JSON error body still produces a usable message', {
    local_fake_key()
    httr2::local_mocked_responses(list(httr2::response(
        status_code = 502,
        headers = list(`content-type` = 'text/html'),
        body = charToRaw('<html>Bad gateway</html>')
    )))

    expect_warning(
        answers <- jev('a state', fixture_spec()['is_urgent'], progress = FALSE, max_active = 1),
        'failed'
    )
    expect_match(answers$.jev_error, '502')
})

test_that('the state text never reaches the error message', {
    local_fake_key()
    httr2::local_mocked_responses(list(httr2::response_json(
        status_code = 422,
        body = list(message = 'Bad request')
    )))

    expect_warning(
        answers <- jev('confidential project text', fixture_spec()['is_urgent'],
                       progress = FALSE, max_active = 1),
        'failed'
    )
    expect_no_match(answers$.jev_error, 'confidential', fixed = TRUE)
})
