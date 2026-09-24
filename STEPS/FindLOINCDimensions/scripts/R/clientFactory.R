#
# --- Client factory -----------------------------------------------------------
#
# Returns a zero-argument factory that builds a fresh ellmer chat client. A fresh
# client per call keeps parallel workers isolated (no shared conversation state).
# The provider/model and (for Vertex) GCP settings are captured in `config` so
# workers do not depend on inheriting environment variables.
makeClientFactory <- function(config) {
  force(config)
  function() {
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
