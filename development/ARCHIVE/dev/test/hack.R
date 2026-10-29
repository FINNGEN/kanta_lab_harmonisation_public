default_google_credentials2 <- function(
  error_call = caller_env(),
  variant = c("gemini", "vertex")
) {
 

  api_key <- Sys.getenv("GOOGLE_API_KEY")
  if (variant == "gemini" && api_key == "") {
    api_key <- Sys.getenv("GEMINI_API_KEY")
  }
  if (nzchar(api_key)) {
    return(\() api_key)
  }

  gemini_scope <- switch(
    variant,
    gemini = "https://www.googleapis.com/auth/generative-language.retriever",
    # https://github.com/googleapis/python-genai/blob/cc9e470326e0c1b84ec3ce9891c9f96f6c74688e/google/genai/_api_client.py#L184
    vertex = "https://www.googleapis.com/auth/cloud-platform"
  )

  # Detect viewer-based credentials from Posit Connect.
  if (ellmer:::has_connect_viewer_token(scope = gemini_scope)) {
    return(function() {
      token <- connectcreds::connect_viewer_token(scope = gemini_scope)
      list(Authorization = paste("Bearer", token$access_token))
    })
  }



  gargle::with_cred_funs(
    funs = list(
      # We don't want to use *all* of gargle's default credential functions --
      # in particular, we don't want to try and authenticate using the bundled
      # OAuth client -- so winnow down the list.
      credentials_app_default = gargle::credentials_app_default
    ),
    {
      token <- gargle::token_fetch(scopes = gemini_scope)
    },
    action = "replace"
  )

  if (is.null(token) && is_testing()) {
    testthat::skip("no Google credentials available")
  }



  if (is.null(token)) {
    cli::cli_abort(
      c(
        "No Google credentials are available.",
        "i" = "Try suppling an API key or configuring Google's application default credentials."
      ),
      call = error_call
    )
  }

  # gargle emits an httr-style token, which we awkwardly shim into something
  # httr2 can work with.

  if (!token$can_refresh()) {
    # TODO: Not really sure what to do in this case when the token expires.
    return(function() {
      list(Authorization = paste("Bearer", token$credentials$access_token))
    })
  }

  # gargle tokens don't track the expiry time, so we do it ourselves (with a
  # grace period).
  expiry <- Sys.time() + token$credentials$expires_in - 5
  return(function() {
    if (expiry < Sys.time()) {
      token$refresh()
    }
    list(Authorization = paste("Bearer", token$credentials$access_token))
  })
}


assignInNamespace(
  "default_google_credentials",
  default_google_credentials2,
  ns = "ellmer"
)
