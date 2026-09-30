#
# --- Client factory -----------------------------------------------------------
#
# Returns a zero-argument factory that builds a fresh chat client. A fresh
# client per call keeps parallel workers isolated (no shared conversation state).
# The provider/model and (for Vertex) GCP settings are captured in `config` so
# workers do not depend on inheriting environment variables.
#
# Two families of backend are supported and are interchangeable at the call
# site, since both answer to `set_system_prompt()` / `chat_structured()` /
# `get_cost()`:
#
#   * the ellmer providers below, which talk to an HTTP API directly;
#   * `claude_code`, which shells out to the `claude` CLI -- see
#     `claudeClient.R` for what that wrapper does and does not do.
makeClientFactory <- function(config) {
  force(config)
  function() {
    if (identical(config$provider, "claude_code")) {
      # Sourced lazily and by path so the ellmer-only paths do not depend on
      # this file, and so parallel workers (separate processes, which inherit
      # no sourced functions) can load it themselves from `config$claudeClientFile`.
      if (!exists("makeClaudeClient", mode = "function")) {
        source(config$claudeClientFile)
      }
      return(makeClaudeClient(config))
    }
    if (!is.null(config$credentials) && nzchar(config$credentials)) {
      Sys.setenv(GOOGLE_APPLICATION_CREDENTIALS = config$credentials)
    }
    if (identical(config$provider, "google_vertex")) {
      ellmer::chat_google_vertex(
        location = config$location,
        project_id = config$project,
        model = config$model
      )
    } else if (identical(config$provider, "google_gemini")) {
      ellmer::chat_google_gemini(model = config$model)
    } else if (identical(config$provider, "anthropic")) {
      ellmer::chat_anthropic(model = config$model)
    } else if (identical(config$provider, "openai")) {
      ellmer::chat_openai(model = config$model)
    } else {
      stop("Unsupported LLM_PROVIDER: ", config$provider)
    }
  }
}
