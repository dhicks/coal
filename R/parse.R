# Parsing responses ----

#' Parse Jev responses into a data frame
#'
#' Turns responses from [jev_perform()] into one row per response, in the same order.
#'
#' @param resp A list of responses from [jev_perform()], or a single response. Error conditions in the list become rows of `NA` answers with a message in `.jev_error`.
#' @param questions The questions spec that produced `resp`. Supplying it fixes the columns, so a state that failed still gets correctly typed `NA`s. When `NULL`, the columns come from the ids observed across the responses.
#'
#' @return A tibble with one row per element of `resp`. For a question id `q`:
#'
#' | Type | Columns |
#' | ---- | ------- |
#' | noul | `q` (probability of yes) |
#' | choice | `q`, `q_conf`, `q_probs` |
#' | score | `q`, `q_conf`, `q_probs`, `q_legend` |
#'
#' plus `.jev_model` (the versioned model that answered), `.jev_input_tokens`, and `.jev_error`.
#'
#' `q_probs` and `q_legend` are list-columns. For a score, both are named by level number counting from **0**, as strings, matching the wire format; these are not R indices. A legend is a named character vector when every level description is a string and a named list when any is structured.
#'
#' @seealso [jev_normalize()] to put scores from scales of different length on a common range.
#' @export
jev_parse = function(resp, questions = NULL) {
    if (is_http_response(resp) || inherits(resp, 'condition')) resp = list(resp)
    if (!is.list(resp)) {
        cli_abort('{.arg resp} must be a response or a list of responses, not {.obj_type_friendly {resp}}.')
    }

    bodies = lapply(resp, response_body)
    spec = if (is.null(questions)) infer_spec(bodies) else question_spec(questions)
    check_column_names(spec)

    if (length(resp) == 0L) return(vctrs::vec_slice(empty_row(spec), integer(0)))

    vctrs::vec_rbind(!!!Map(parse_one, resp, bodies, MoreArgs = list(spec = spec)))
}

#' Body of a successful response, or NULL for a failure
#' @noRd
response_body = function(x) {
    if (is_http_response(x)) resp_body_json(x, simplifyVector = FALSE) else NULL
}

#' Question id to type, from the spec the user supplied
#' @noRd
question_spec = function(questions) {
    check_questions(questions)
    vapply(questions, function(q) q$type, character(1))
}

#' Question id to type, from the answers that came back
#' @noRd
infer_spec = function(bodies) {
    answers = unlist(lapply(bodies, function(b) b$answers), recursive = FALSE)
    if (is.null(answers)) return(character(0))
    types = vapply(answers, function(a) a$type %||% NA_character_, character(1))
    types[!duplicated(names(types))]
}

#' @noRd
check_column_names = function(spec) {
    generated = unlist(lapply(names(spec), function(id) answer_columns(id, spec[[id]])))
    duplicated_names = unique(generated[duplicated(generated)])
    if (length(duplicated_names) > 0L) {
        cli_abort(c(
            'Question ids produce duplicate column names: {.field {duplicated_names}}.',
            'i' = 'A choice or score id {.val q} also generates {.field q_conf} and {.field q_probs}, so rename whichever id collides.'
        ))
    }
}

#' @noRd
answer_columns = function(id, type) {
    switch(
        type,
        noul = id,
        choice = c(id, paste0(id, c('_conf', '_probs'))),
        score = c(id, paste0(id, c('_conf', '_probs', '_legend')))
    )
}

# One row per response ----

#' @noRd
parse_one = function(resp, body, spec) {
    if (is.null(body)) {
        row = empty_row(spec)
        row$.jev_error = failure_message(resp)
        return(row)
    }
    answers = lapply(
        names(spec),
        function(id) parse_answer(body$answers[[id]], id, spec[[id]])
    )
    vctrs::vec_cbind(
        !!!answers,
        tibble(
            .jev_model = as_string_field(body$model, 'model'),
            .jev_input_tokens = as_int_field(body$usage$input_tokens, 'usage.input_tokens'),
            .jev_error = NA_character_
        )
    )
}

#' @noRd
parse_answer = function(answer, id, type) {
    if (is.null(answer)) invalid_response(paste0('answers.', id))
    path = function(field) paste0('answers.', id, '.', field)
    switch(
        type,
        noul = tibble(!!id := as_dbl_field(answer$noul, path('noul'))),
        choice = tibble(
            !!id := as_string_field(answer$choice, path('choice')),
            !!paste0(id, '_conf') := as_dbl_field(answer$confidence, path('confidence')),
            !!paste0(id, '_probs') := list(as_probabilities(answer$probabilities, path('probabilities')))
        ),
        score = tibble(
            !!id := as_dbl_field(answer$score, path('score')),
            !!paste0(id, '_conf') := as_dbl_field(answer$confidence, path('confidence')),
            !!paste0(id, '_probs') := list(as_probabilities(answer$probabilities, path('probabilities'), sort_levels = TRUE)),
            !!paste0(id, '_legend') := list(as_legend(answer$legend, path('legend')))
        )
    )
}

#' A row of NAs with the columns the spec implies
#' @noRd
empty_row = function(spec) {
    answers = lapply(names(spec), function(id) {
        type = spec[[id]]
        switch(
            type,
            noul = tibble(!!id := NA_real_),
            choice = tibble(
                !!id := NA_character_,
                !!paste0(id, '_conf') := NA_real_,
                !!paste0(id, '_probs') := list(NULL)
            ),
            score = tibble(
                !!id := NA_real_,
                !!paste0(id, '_conf') := NA_real_,
                !!paste0(id, '_probs') := list(NULL),
                !!paste0(id, '_legend') := list(NULL)
            )
        )
    })
    vctrs::vec_cbind(
        !!!answers,
        tibble(
            .jev_model = NA_character_,
            .jev_input_tokens = NA_integer_,
            .jev_error = NA_character_
        )
    )
}

# Field coercion ----

## The API's Score probabilities and legend are keyed by level number as strings, starting at 0. Those names are kept as they arrive; they are level numbers, not R indices.

#' @noRd
as_probabilities = function(x, path, sort_levels = FALSE) {
    if (!is.list(x) || length(x) == 0L) invalid_response(path)
    out = vapply(x, as.double, double(1))
    if (sort_levels) out = out[order(as.integer(names(out)))]
    out
}

#' Named character vector when every description is a string, named list otherwise
#' @noRd
as_legend = function(x, path) {
    if (!is.list(x) || length(x) == 0L) invalid_response(path)
    out = x[order(as.integer(names(x)))]
    is_string = vapply(out, function(el) is.character(el) && length(el) == 1L, logical(1))
    if (all(is_string)) unlist(out) else out
}

#' @noRd
as_dbl_field = function(x, path) {
    if (!is.numeric(x) || length(x) != 1L) invalid_response(path)
    as.double(x)
}

#' @noRd
as_int_field = function(x, path) {
    if (!is.numeric(x) || length(x) != 1L) invalid_response(path)
    as.integer(x)
}

#' @noRd
as_string_field = function(x, path) {
    if (!is.character(x) || length(x) != 1L) invalid_response(path)
    x
}

#' @noRd
invalid_response = function(path, call = caller_env()) {
    cli_abort(
        c('The response is missing {.field {path}} or it has the wrong type.',
          'i' = 'Check the response with {.fun jev_perform} and {.fun httr2::resp_body_json}.'),
        class = 'coal_invalid_response',
        call = call
    )
}

# Score arithmetic ----

#' Put a score on a 0 to 1 range
#'
#' Divides a score by `n_levels - 1`, which is the comparable range for scores from scales of different length. Scores from different scales should not be compared or combined without this.
#'
#' @param score A score, from the column named after a score question.
#' @param legend The matching `_legend` list-column, or the number of levels directly.
#'
#' @return A double vector the same length as `score`, between 0 and 1, or `NA` where the scale has fewer than two levels.
#' @export
#' @examples
#' jev_normalize(1.05, 3)
#'
#' \dontrun{
#' answers |>
#'     dplyr::mutate(frustration_norm = jev_normalize(frustration, frustration_legend))
#' }
jev_normalize = function(score, legend) {
    n_levels = if (is.numeric(legend)) as.integer(legend) else lengths(legend)
    ifelse(n_levels >= 2L, score / (n_levels - 1L), NA_real_)
}
