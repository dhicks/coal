# Model listing ----

#' List the models the account can use
#'
#' Calls `GET /v1/models`.
#'
#' @return A tibble with columns `name`, `description`, and `release_date`. The endpoint currently lists aliases such as `jev-latest` only; versioned ids such as `jev-1.13.0` are accepted by [jev()] even when absent here.
#'
#' @section Aliases move:
#' An alias points at a new model when TypeSafe ships a release, so answers can change without any change to your code. Pin a versioned id once thresholds are tuned, and keep the `.jev_model` column with your results.
#'
#' @export
#' @examples
#' \dontrun{
#' jev_models()
#' }
jev_models = function() {
    body = jev_base_request() |>
        req_url_path_append('v1', 'models') |>
        req_perform() |>
        resp_body_json(simplifyVector = FALSE)

    models = body$models %||% list()
    tibble(
        name = vapply(models, function(m) m$name %||% NA_character_, character(1)),
        description = vapply(models, function(m) m$description %||% NA_character_, character(1)),
        release_date = vapply(models, function(m) m$release_date %||% NA_character_, character(1))
    )
}
