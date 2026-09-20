as_json = function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null'))

test_that('a choice without a description serializes as JSON null', {
    question = jev_choice('Which team?', criteria = c(billing = 'Payments', sales = NA))
    expect_named(question$criteria, c('billing', 'sales'))
    expect_null(question$criteria$sales)
    expect_match(as_json(question$criteria), '"sales":null', fixed = TRUE)
})

test_that('a choice takes list criteria with structured descriptions', {
    question = jev_choice(
        'Which team?',
        criteria = list(billing = list(what = 'Payments', not_for = 'Bugs'), sales = NULL)
    )
    expect_equal(question$criteria$billing$what, 'Payments')
    expect_match(as_json(question$criteria), '"sales":null', fixed = TRUE)
})

test_that('a choice rejects unnamed criteria and more than 255 options', {
    expect_error(jev_choice('Which team?', criteria = c('billing', 'sales')), 'named')
    too_many = setNames(as.list(rep('x', 256)), paste0('option', 1:256))
    expect_error(jev_choice('Which team?', criteria = too_many), '255')
})

test_that('score criteria serialize as an array, even with one level', {
    question = jev_score('How frustrated?', criteria = c('Calm', 'Frustrated', 'Very angry'))
    expect_null(names(question$criteria))
    expect_equal(as_json(question$criteria), '["Calm","Frustrated","Very angry"]')

    ## The level count check blocks a one-level score, so test the array coercion on the internal path.
    expect_equal(as_json(unname(as.list('Calm'))), '["Calm"]')
})

test_that('a score rejects fewer than 2 or more than 10 levels', {
    expect_error(jev_score('How frustrated?', criteria = 'Calm'), '2 and 10')
    expect_error(jev_score('How frustrated?', criteria = letters[1:11]), '2 and 10')
})

test_that('noul criteria must be named true and false', {
    question = jev_noul('Urgent?', criteria = c(true = 'Deadline stated', false = 'No deadline'))
    expect_named(question$criteria, c('true', 'false'))

    expect_error(jev_noul('Urgent?', criteria = c(yes = 'a', no = 'b')), 'true')
    expect_error(jev_noul('Urgent?', criteria = c('a', 'b')), 'true')
})

test_that('a question without criteria omits the field entirely', {
    question = jev_noul('Urgent?')
    expect_named(question, c('type', 'instructions'))
})

test_that('extra fields pass through for forward compatibility', {
    question = jev_noul('Urgent?', some_new_field = 'value')
    expect_equal(question$some_new_field, 'value')
})

test_that('instructions accept a string or a list, nothing else', {
    expect_no_error(jev_noul(list(question = 'Same person?', record = list(name = 'J Smith'))))
    expect_error(jev_noul(42), 'single string or a list')
    expect_error(jev_noul(c('a', 'b')), 'single string or a list')
})

test_that('check_questions rejects specs jev_parse could not read', {
    expect_error(check_questions(list()), 'non-empty list')
    expect_error(check_questions(list(jev_noul('Urgent?'))), 'distinct name')
    expect_error(check_questions(list(a = list(instructions = 'x'))), 'type')
    expect_error(check_questions(list(a = list(type = 'ranking'))), 'cannot parse')
})
