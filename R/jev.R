# The user-facing call ----

#' Evaluate states against typed questions
#'
#' Sends each element of `state` to Jev with the same `questions` and returns one row of answers per state. Jev is a classification model: it returns typed answers with probabilities, not generated text.
#'
#' `jev()` runs [jev_request()], [jev_perform()], and [jev_parse()] in sequence. Call those three separately when you need the unparsed JSON or the HTTP metadata.
#'
#' @inheritParams jev_request
#' @inheritParams jev_perform
#'
#' @return A tibble with one row per element of `state`, in the same order, with the columns described in [jev_parse()]. Because the result is a data frame of the right height, [dplyr::mutate()] splices its columns onto the data frame the states came from.
#'
#' @section Asking good questions:
#' Send every question for a state in one call, including ones that matter only for some inputs, and let your own code decide which answers to use; a second call is justified only when it cannot be built without the first answer. Keep arithmetic, counting, and date comparison in R, where they are exact. Gate actions on `_conf` for choices and scores, and on two cutoffs of the value itself for nouls. `jev-docs/` in this repository has the details.
#'
#' @export
#' @examples
#' spec = list(
#'     department = jev_choice(
#'         'Which team should handle this?',
#'         criteria = c(billing = 'Payments, invoicing, refunds',
#'                      technical = 'Bugs, outages, integrations',
#'                      sales = 'Pricing, upgrades, new accounts')
#'     ),
#'     frustration = jev_score(
#'         'How frustrated is the customer?',
#'         criteria = c('Calm', 'Frustrated', 'Very angry')
#'     ),
#'     is_urgent = jev_noul('Does this convey urgency?')
#' )
#'
#' \dontrun{
#' jev('Help! My payouts have been failing for 3 days.', spec)
#'
#' tickets |>
#'     dplyr::mutate(jev(body, questions = spec))
#' }
jev = function(state,
               questions,
               model = jev_default_model(),
               on_error = c('warn', 'stop'),
               max_active = 5,
               progress = TRUE,
               rpm = 1000) {
    on_error = arg_match(on_error)
    reqs = jev_request(state, questions, model = model, rpm = rpm)
    resps = jev_perform(reqs, on_error = on_error, max_active = max_active, progress = progress)
    answers = jev_parse(resps, questions)

    n_failed = sum(!is.na(answers$.jev_error))
    if (n_failed > 0L) {
        cli_warn(c(
            '{n_failed} of {nrow(answers)} state{?s} failed.',
            'i' = 'Their answers are {.code NA}; see the {.field .jev_error} column.'
        ))
    }
    answers
}
