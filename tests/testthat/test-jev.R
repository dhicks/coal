test_that('jev returns one row per state, in input order', {
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state())

    states = paste('doc', 1:5)
    answers = jev(states, fixture_spec(), progress = FALSE)

    expect_equal(nrow(answers), length(states))
    expect_equal(answers$is_urgent, (1:5) / 10)
})

test_that('mutate splices the answers onto the source data frame', {
    skip_if_not_installed('dplyr')
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state())

    docs = tibble::tibble(id = letters[1:3], content = paste('doc', 1:3))
    out = dplyr::mutate(docs, jev(content, questions = fixture_spec(), progress = FALSE))

    expect_equal(nrow(out), 3)
    expect_equal(out$id, letters[1:3])
    expect_equal(out$is_urgent, (1:3) / 10)
    expect_true(all(c('department', 'department_conf', 'frustration_legend') %in% names(out)))
})

test_that('an empty state vector gives a zero-row frame', {
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state())

    answers = jev(character(0), fixture_spec(), progress = FALSE)

    expect_equal(nrow(answers), 0)
    expect_true('is_urgent' %in% names(answers))
})

test_that('on_error = "warn" keeps the states that succeeded', {
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state(fail_states = 'doc 2'))

    expect_warning(
        answers <- jev(paste('doc', 1:3), fixture_spec(), progress = FALSE, max_active = 1),
        '1 of 3 states failed'
    )

    expect_equal(nrow(answers), 3)
    expect_equal(answers$is_urgent, c(0.1, NA, 0.3))
    expect_equal(is.na(answers$.jev_error), c(TRUE, FALSE, TRUE))
    expect_match(answers$.jev_error[2], '500')
})

test_that('on_error = "stop" names which state failed', {
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state(fail_states = 'doc 2'))

    expect_error(
        jev(paste('doc', 1:3), fixture_spec(), on_error = 'stop', progress = FALSE, max_active = 1),
        'State 2 of 3 failed'
    )
})

test_that('on_error = "stop" counts the other failures', {
    local_fake_key()
    httr2::local_mocked_responses(mock_by_state(fail_states = c('doc 2', 'doc 3')))

    expect_error(
        jev(paste('doc', 1:3), fixture_spec(), on_error = 'stop', progress = FALSE, max_active = 1),
        '1 other state also failed'
    )
})

test_that('jev passes the model through and records the one that answered', {
    local_fake_key()
    seen = NULL
    httr2::local_mocked_responses(function(req) {
        seen <<- req$body$data$model
        httr2::response_json(body = fixture_body(list(is_urgent = fixture_noul())))
    })

    answers = jev('a state', fixture_spec()['is_urgent'], model = 'jev-1.13.0', progress = FALSE)

    expect_equal(seen, 'jev-1.13.0')
    expect_equal(answers$.jev_model, 'jev-1.13.0')
})
