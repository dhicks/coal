test_that('each answer type parses to its documented columns', {
    resp = httr2::response_json(body = fixture_body(list(
        department = fixture_choice(),
        frustration = fixture_score(),
        is_urgent = fixture_noul()
    )))

    answers = jev_parse(resp, fixture_spec())

    expect_s3_class(answers, 'tbl_df')
    expect_equal(nrow(answers), 1)
    expect_named(answers, c(
        'department', 'department_conf', 'department_probs',
        'frustration', 'frustration_conf', 'frustration_probs', 'frustration_legend',
        'is_urgent',
        '.jev_model', '.jev_input_tokens', '.jev_error'
    ))

    expect_equal(answers$department, 'billing')
    expect_equal(answers$department_conf, 0.81)
    expect_equal(answers$frustration, 1.05)
    expect_equal(answers$is_urgent, 0.91)
    expect_equal(answers$.jev_model, 'jev-1.13.0')
    expect_equal(answers$.jev_input_tokens, 296L)
    expect_true(is.na(answers$.jev_error))
})

test_that('probabilities and legend come back as named vectors in list-columns', {
    resp = httr2::response_json(body = fixture_body(list(frustration = fixture_score())))
    spec = fixture_spec()['frustration']
    answers = jev_parse(resp, spec)

    probs = answers$frustration_probs[[1]]
    expect_type(probs, 'double')
    expect_named(probs, c('0', '1', '2'))
    expect_equal(sum(probs), 1)

    legend = answers$frustration_legend[[1]]
    expect_equal(legend, c('0' = 'Calm', '1' = 'Frustrated', '2' = 'Very angry'))
})

test_that('score levels are ordered by level number, not by wire order', {
    scrambled = fixture_score()
    scrambled$probabilities = scrambled$probabilities[c('2', '0', '1')]
    scrambled$legend = scrambled$legend[c('1', '2', '0')]

    resp = httr2::response_json(body = fixture_body(list(frustration = scrambled)))
    answers = jev_parse(resp, fixture_spec()['frustration'])

    expect_named(answers$frustration_probs[[1]], c('0', '1', '2'))
    expect_equal(unname(answers$frustration_legend[[1]][['0']]), 'Calm')
})

test_that('a structured legend stays a list', {
    structured = fixture_score()
    structured$legend = list(
        '0' = list(what = 'Calm'),
        '1' = list(what = 'Frustrated'),
        '2' = list(what = 'Very angry')
    )
    resp = httr2::response_json(body = fixture_body(list(frustration = structured)))
    answers = jev_parse(resp, fixture_spec()['frustration'])

    legend = answers$frustration_legend[[1]]
    expect_type(legend, 'list')
    expect_equal(legend[['0']]$what, 'Calm')
})

test_that('an error condition becomes a row of NAs with a message', {
    resp = httr2::response_json(body = fixture_body(list(is_urgent = fixture_noul(0.4))))
    failure = rlang::catch_cnd(cli::cli_abort('HTTP 500 Server error.'))

    answers = jev_parse(list(resp, failure), fixture_spec()['is_urgent'])

    expect_equal(nrow(answers), 2)
    expect_equal(answers$is_urgent, c(0.4, NA))
    expect_equal(is.na(answers$.jev_error), c(TRUE, FALSE))
    expect_match(answers$.jev_error[2], 'Server error')
})

test_that('a response missing a required field names the field path', {
    incomplete = fixture_choice()
    incomplete$confidence = NULL
    resp = httr2::response_json(body = fixture_body(list(department = incomplete)))

    expect_error(
        jev_parse(resp, fixture_spec()['department']),
        'answers.department.confidence',
        fixed = TRUE,
        class = 'coal_invalid_response'
    )
})

test_that('a missing answer id names the path', {
    resp = httr2::response_json(body = fixture_body(list(is_urgent = fixture_noul())))
    expect_error(
        jev_parse(resp, fixture_spec()['department']),
        'answers.department',
        fixed = TRUE,
        class = 'coal_invalid_response'
    )
})

test_that('columns come from the responses when no spec is supplied', {
    resp = httr2::response_json(body = fixture_body(list(
        department = fixture_choice(),
        is_urgent = fixture_noul()
    )))
    answers = jev_parse(resp)

    expect_named(answers, c('department', 'department_conf', 'department_probs',
                            'is_urgent', '.jev_model', '.jev_input_tokens', '.jev_error'))
})

test_that('no responses gives a zero-row frame with the right columns', {
    answers = jev_parse(list(), fixture_spec()['is_urgent'])

    expect_equal(nrow(answers), 0)
    expect_named(answers, c('is_urgent', '.jev_model', '.jev_input_tokens', '.jev_error'))
    expect_type(answers$is_urgent, 'double')
})

test_that('question ids that collide with generated column names are rejected', {
    spec = list(
        q = jev_choice('Which?', criteria = c(a = 'A', b = 'B')),
        q_conf = jev_noul('Confident?')
    )
    resp = httr2::response_json(body = fixture_body(list(q = fixture_choice(), q_conf = fixture_noul())))

    expect_error(jev_parse(resp, spec), 'duplicate column names')
})

test_that('jev_normalize divides by the number of levels minus one', {
    expect_equal(jev_normalize(1.05, 3), 0.525)
    expect_equal(jev_normalize(c(0, 2), c(3, 3)), c(0, 1))

    legend = list(c('0' = 'a', '1' = 'b', '2' = 'c'), NULL)
    expect_equal(jev_normalize(c(1.05, NA), legend), c(0.525, NA))
})
