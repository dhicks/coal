# Question constructors ----

## These return plain lists matching the JSON request body. A questions spec can mix them freely with hand-written lists.

#' Build a Jev question
#'
#' Construct one typed question for the `questions` argument of [jev()]. Each returns a plain list matching the JSON body, so a spec can also contain hand-written lists.
#'
#' @param instructions What to judge. A string, or a named list when the question refers to data by name (see `vignette`-free notes in `jev-docs/questions.md`).
#' @param criteria Descriptions of the possible answers; see Details.
#' @param ... Further fields passed into the question unchanged. The API ignores fields it does not recognize, so this is the path to features newer than this package.
#'
#' @details
#' `jev_noul()` asks whether one condition holds and returns a probability. `criteria` is optional; when given it is a named list or character vector whose only allowed names are `true` and `false`.
#'
#' `jev_choice()` picks one option from an unordered set. `criteria` is a named character vector or list mapping each option to a description. Use `NA` or `NULL` for an option whose name speaks for itself; it is sent as JSON `null`. At most 255 options.
#'
#' `jev_score()` places the state on an ordered scale. `criteria` is an ordered vector or list of level descriptions, 2 to 10 of them. Level numbers are positions in that vector counting from 0, and the model never sees the numbers, so do not put them in the descriptions.
#'
#' @return A named list with a `type` element.
#' @name jev_question
#' @examples
#' jev_noul('Does this convey urgency?')
#'
#' jev_choice(
#'     'Which team should handle this?',
#'     criteria = c(billing = 'Payments, invoicing, refunds',
#'                  technical = 'Bugs, outages, integrations',
#'                  sales = NA)
#' )
#'
#' jev_score(
#'     'How frustrated is the customer?',
#'     criteria = c('Calm', 'Frustrated', 'Very angry')
#' )
NULL

#' @rdname jev_question
#' @export
jev_noul = function(instructions, criteria = NULL, ...) {
    check_instructions(instructions)
    if (!is.null(criteria)) {
        criteria = null_out_missing(as.list(criteria))
        extra = setdiff(names2(criteria), c('true', 'false'))
        if (length(criteria) == 0L || any(!nzchar(names2(criteria)))) {
            cli_abort('{.arg criteria} for a noul must be named {.val true} and {.val false}.')
        }
        if (length(extra) > 0L) {
            cli_abort(c(
                'A noul accepts only the criteria names {.val true} and {.val false}.',
                'x' = 'Also got {.val {extra}}.'
            ))
        }
    }
    compact_question(list(type = 'noul', instructions = instructions, criteria = criteria), ...)
}

#' @rdname jev_question
#' @export
jev_choice = function(instructions, criteria, ...) {
    check_instructions(instructions)
    criteria = null_out_missing(as.list(criteria))
    if (length(criteria) == 0L || any(!nzchar(names2(criteria)))) {
        cli_abort(c(
            '{.arg criteria} for a choice must be a named vector or list mapping each option to a description.',
            'i' = 'Use {.code NA} for an option whose name needs no description.'
        ))
    }
    if (length(criteria) > 255L) {
        cli_abort('A choice accepts at most 255 options, not {length(criteria)}.')
    }
    compact_question(list(type = 'choice', instructions = instructions, criteria = criteria), ...)
}

#' @rdname jev_question
#' @export
jev_score = function(instructions, criteria, ...) {
    check_instructions(instructions)
    ## Unnamed so the levels serialize as a JSON array; as.list() keeps a single level from unboxing to a scalar.
    criteria = unname(as.list(criteria))
    if (length(criteria) < 2L || length(criteria) > 10L) {
        cli_abort(c(
            'A score needs between 2 and 10 levels, not {length(criteria)}.',
            'i' = '{.arg criteria} is an ordered vector or list of level descriptions.'
        ))
    }
    compact_question(list(type = 'score', instructions = instructions, criteria = criteria), ...)
}

# Internal helpers ----

#' Drop NULL fields and merge in forward-compatibility fields
#' @noRd
compact_question = function(question, ...) {
    c(question[!vapply(question, is.null, logical(1))], list(...))
}

#' Replace NA and NULL descriptions with NULL elements, which serialize as JSON null
#'
#' `x[i] <- list(NULL)` sets the elements to NULL while keeping their names; `x[[i]] <- NULL` would delete them.
#' @noRd
null_out_missing = function(x) {
    is_missing = vapply(
        x,
        function(el) is.null(el) || (is.atomic(el) && length(el) == 1L && is.na(el)),
        logical(1)
    )
    x[is_missing] = list(NULL)
    x
}

#' @noRd
check_instructions = function(instructions, call = caller_env()) {
    ok = (is.character(instructions) && length(instructions) == 1L && !is.na(instructions)) ||
        is.list(instructions)
    if (!ok) {
        cli_abort(
            '{.arg instructions} must be a single string or a list, not {.obj_type_friendly {instructions}}.',
            call = call
        )
    }
    invisible(instructions)
}

#' Validate a questions spec
#'
#' Checks the structure this package relies on and leaves everything else alone, so unrecognized fields reach the API untouched.
#' @noRd
check_questions = function(questions, call = caller_env()) {
    if (!is.list(questions) || length(questions) == 0L) {
        cli_abort(
            '{.arg questions} must be a non-empty list, not {.obj_type_friendly {questions}}.',
            call = call
        )
    }
    ids = names2(questions)
    if (any(!nzchar(ids)) || anyDuplicated(ids) > 0L) {
        cli_abort(
            c('Every question needs a distinct name, which becomes its id in the response.',
              'i' = 'Ids are not sent to the model and do not affect inference.'),
            call = call
        )
    }
    for (id in ids) {
        question = questions[[id]]
        if (!is.list(question) || is.null(question$type)) {
            cli_abort('Question {.val {id}} must be a list with a {.field type} element.', call = call)
        }
        if (!question$type %in% c('noul', 'choice', 'score')) {
            cli_abort(
                'Question {.val {id}} has type {.val {question$type}}, which this package cannot parse. Expected {.val noul}, {.val choice}, or {.val score}.',
                call = call
            )
        }
    }
    invisible(questions)
}
