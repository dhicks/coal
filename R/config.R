# Configuration ----

## These read the same environment variables as TypeSafe's Python SDK, with the same defaults.

#' Jev API configuration
#'
#' Read the API key, base URL, and default model from environment variables. The variables and defaults match TypeSafe's Python SDK.
#'
#' @details
#' | Function | Variable | Default |
#' | -------- | -------- | ------- |
#' | `jev_key()` | `TYPESAFE_API_KEY` | none; unset is an error |
#' | `jev_base_url()` | `TYPESAFE_BASE_URL` | `https://api.typesafe.ai` |
#' | `jev_default_model()` | `TYPESAFE_DEFAULT_MODEL` | `jev-latest` |
#'
#' Keep the key in a `.env` file that is not under version control, and load it with [readRenviron()] or `dotenv::load_dot_env()`.
#'
#' @return A string.
#' @name jev_config
#' @examples
#' jev_base_url()
#' jev_default_model()
NULL

#' @rdname jev_config
#' @export
jev_key = function() {
    key = Sys.getenv('TYPESAFE_API_KEY')
    if (!nzchar(key)) {
        cli_abort(c(
            'No Jev API key found.',
            'i' = 'Set the {.envvar TYPESAFE_API_KEY} environment variable, or put it in a {.file .env} file and load that file with {.fun readRenviron}.',
            'i' = 'Keys are at {.url https://console.typesafe.ai/keys}.'
        ))
    }
    key
}

#' @rdname jev_config
#' @export
jev_base_url = function() {
    url = Sys.getenv('TYPESAFE_BASE_URL')
    if (nzchar(url)) url else 'https://api.typesafe.ai'
}

#' @rdname jev_config
#' @export
jev_default_model = function() {
    model = Sys.getenv('TYPESAFE_DEFAULT_MODEL')
    if (nzchar(model)) model else 'jev-latest'
}
