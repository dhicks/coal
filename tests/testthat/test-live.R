## Real API calls. Skipped unless TYPESAFE_API_KEY is set, and always skipped on CI.
## The state is the sample sentence from jev-docs/api.md, so no project data is sent.

skip_live = function() {
    skip_on_ci()
    skip_if(!nzchar(Sys.getenv('TYPESAFE_API_KEY')), 'TYPESAFE_API_KEY is not set')
}

test_that('a real evaluation returns the documented answer shapes', {
    skip_live()

    answers = jev(
        'Help! My payouts have been failing for 3 days.',
        fixture_spec(),
        progress = FALSE
    )

    expect_equal(nrow(answers), 1)
    expect_true(is.na(answers$.jev_error))

    expect_true(answers$department %in% c('billing', 'technical', 'sales'))
    expect_true(answers$department_conf >= 0 && answers$department_conf <= 1)
    expect_equal(sum(answers$department_probs[[1]]), 1, tolerance = 1e-6)

    expect_true(answers$frustration >= 0 && answers$frustration <= 2)
    expect_named(answers$frustration_probs[[1]], c('0', '1', '2'))
    expect_equal(answers$frustration_legend[[1]][['0']], 'Calm')

    expect_true(answers$is_urgent >= 0 && answers$is_urgent <= 1)

    ## The alias resolves to a versioned id, which is what belongs with saved results.
    expect_match(answers$.jev_model, '^jev-\\d+\\.\\d+')
    expect_gt(answers$.jev_input_tokens, 0)
})

test_that('several states come back in order in one call', {
    skip_live()

    answers = jev(
        c('Help! My payouts have been failing for 3 days.',
          'What does the Pro plan cost per seat?'),
        list(department = fixture_spec()$department),
        progress = FALSE
    )

    expect_equal(nrow(answers), 2)
    expect_equal(answers$department, c('billing', 'sales'))
})

test_that('jev_models lists the aliases', {
    skip_live()

    models = jev_models()

    expect_s3_class(models, 'tbl_df')
    expect_named(models, c('name', 'description', 'release_date'))
    expect_true('jev-latest' %in% models$name)
})
