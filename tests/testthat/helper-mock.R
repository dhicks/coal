# Fixtures and mocks ----

## Answers follow the examples in jev-docs/api.md.

#' Set a key so jev_request() can build a request without one in the environment
local_fake_key = function(env = parent.frame()) {
    withr::local_envvar(c(TYPESAFE_API_KEY = 'test-key'), .local_envir = env)
}

#' Serialize a request body the way httr2 will at send time
#'
#' `req_dry_run()` fails in this environment, so read the stored data and the serializer settings httr2 recorded and apply them here.
request_json = function(req) {
    as.character(do.call(jsonlite::toJSON, c(list(req$body$data), req$body$params)))
}

#' A full response body
fixture_body = function(answers, model = 'jev-1.13.0', input_tokens = 296L) {
    list(
        model = model,
        answers = answers,
        usage = list(input_tokens = input_tokens, output_tokens = 20L)
    )
}

fixture_noul = function(noul = 0.91) {
    list(type = 'noul', noul = noul)
}

fixture_choice = function(choice = 'billing') {
    list(
        type = 'choice',
        choice = choice,
        probabilities = list(billing = 0.88, technical = 0.12, sales = 0.0),
        confidence = 0.81
    )
}

fixture_score = function(score = 1.05) {
    list(
        type = 'score',
        score = score,
        legend = list('0' = 'Calm', '1' = 'Frustrated', '2' = 'Very angry'),
        probabilities = list('0' = 0.0, '1' = 0.95, '2' = 0.05),
        confidence = 0.92
    )
}

fixture_spec = function() {
    list(
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
}

#' A mock that answers from the state, so responses can be matched to requests
#'
#' The noul comes back as the number embedded in a state like `'doc 3'`, divided by 10, which makes row order checkable.
mock_by_state = function(fail_states = character(0)) {
    function(req) {
        state = req$body$data$state
        if (state %in% fail_states) {
            return(httr2::response_json(
                status_code = 500,
                headers = list(`x-typesafe-request-id` = 'req_test'),
                body = list(message = 'Server error')
            ))
        }
        n = as.numeric(sub('\\D+', '', state))
        httr2::response_json(body = fixture_body(list(
            department = fixture_choice(),
            frustration = fixture_score(),
            is_urgent = fixture_noul(n / 10)
        )))
    }
}
