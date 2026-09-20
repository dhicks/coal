test_that('jev_request builds one request per state, in order', {
    local_fake_key()
    reqs = jev_request(c('first', 'second', 'third'), fixture_spec())

    expect_length(reqs, 3)
    expect_equal(vapply(reqs, function(r) r$body$data$state, character(1)),
                 c('first', 'second', 'third'))
    expect_match(reqs[[1]]$url, '/v1/systemone')
})

test_that('the request body matches the documented schema', {
    local_fake_key()
    req = jev_request('Help! My payouts have been failing for 3 days.', fixture_spec())[[1]]
    body = jsonlite::fromJSON(request_json(req), simplifyVector = FALSE)

    expect_named(body, c('state', 'model', 'questions'))
    expect_type(body$state, 'character')
    expect_equal(body$model, 'jev-latest')
    expect_named(body$questions, c('department', 'frustration', 'is_urgent'))
    expect_equal(body$questions$department$type, 'choice')
    expect_type(body$questions$frustration$criteria, 'list')
    expect_length(body$questions$frustration$criteria, 3)
})

test_that('the body serializes with the settings the schema needs', {
    local_fake_key()
    spec = list(department = jev_choice('Which team?', criteria = c(billing = 'Payments', sales = NA)))
    req = jev_request('a state', spec)[[1]]

    ## Without auto_unbox the state would be ["a state"]; without null = "null" the empty description would be {}.
    expect_true(req$body$params$auto_unbox)
    expect_equal(req$body$params$null, 'null')

    json = request_json(req)
    expect_match(json, '"state":"a state"', fixed = TRUE)
    expect_match(json, '"sales":null', fixed = TRUE)
})

test_that('the API key is redacted when a request is printed', {
    local_fake_key()
    req = jev_request('a state', fixture_spec())[[1]]
    expect_no_match(paste(capture.output(print(req)), collapse = '\n'), 'test-key', fixed = TRUE)
})

test_that('a state that is not a string or list of strings is rejected', {
    local_fake_key()
    spec = fixture_spec()

    expect_error(jev_request(1:3, spec), 'character vector or a list of single strings')
    expect_error(jev_request(list(c('a', 'b')), spec), 'character vector or a list of single strings')
    expect_error(jev_request(NA_character_, spec), 'character vector or a list of single strings')
})

test_that('a named list is refused rather than guessed at', {
    local_fake_key()
    expect_error(jev_request(list(a = 'x', b = 'y'), fixture_spec()), 'not a named list')
})

test_that('names on a character vector are dropped, not treated as an object', {
    local_fake_key()
    reqs = jev_request(c(first = 'one', second = 'two'), fixture_spec())

    expect_length(reqs, 2)
    expect_equal(reqs[[1]]$body$data$state, 'one')
})

test_that('an empty state vector gives no requests', {
    local_fake_key()
    expect_length(jev_request(character(0), fixture_spec()), 0)
})

test_that('jev_key reports how to set a missing key', {
    withr::local_envvar(c(TYPESAFE_API_KEY = ''))
    expect_error(jev_key(), 'TYPESAFE_API_KEY')
})

test_that('configuration falls back to the documented defaults', {
    withr::local_envvar(c(TYPESAFE_BASE_URL = '', TYPESAFE_DEFAULT_MODEL = ''))
    expect_equal(jev_base_url(), 'https://api.typesafe.ai')
    expect_equal(jev_default_model(), 'jev-latest')

    withr::local_envvar(c(TYPESAFE_DEFAULT_MODEL = 'jev-1.13.0'))
    expect_equal(jev_default_model(), 'jev-1.13.0')
})

test_that('requests are throttled per host', {
    local_fake_key()
    req = jev_request('a state', fixture_spec(), rpm = 600)[[1]]

    ## httr2 keeps the token bucket in an internal pool and records only the realm on the request.
    expect_equal(req$policies$throttle_realm, 'api.typesafe.ai')
})
