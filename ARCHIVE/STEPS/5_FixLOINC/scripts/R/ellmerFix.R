#
# --- ellmerFix.R --------------------------------------------------------------
#
# Production hot-patch for ellmer's Google credential discovery.
#
# The problem
# -----------
# ellmer:::default_google_credentials() resolves a Vertex/Gemini token with:
#
#     gargle::with_cred_funs(
#       funs   = list(credentials_app_default = gargle::credentials_app_default),
#       { token <- gargle::token_fetch(scopes = gemini_scope) },
#       action = "replace")
#
# `action = "replace"` narrows gargle to ONLY credentials_app_default (the
# application-default-credentials file). On a GCP VM there is usually no ADC
# file; credentials come from the instance metadata server via
# gargle::credentials_gce. Because the replace-wrapper removed that function
# from gargle's chain, token_fetch() returns NULL and ellmer aborts with
#     "No Google credentials are available."
# even though a perfectly good service-account token is one metadata call away.
# This surfaces in production runs (many parallel workers on a VM) but not
# locally, where an ADC file exists from `gcloud auth application-default login`.
#
# The fix
# -------
# Replace default_google_credentials() with a copy that calls
# gargle::token_fetch() WITHOUT the replace-wrapper, so gargle uses its full
# default credential chain (env var -> service-account key -> gcloud ADC ->
# GCE metadata server). Everything else (test/interactive fallbacks, the
# no-credentials abort, token refresh) is kept identical to upstream.
#
# Usage
# -----
#   library(ellmer)
#   source(".../scripts/R/ellmerFix.R")   # defines + applies the patch
#
# assignInNamespace mutates the ellmer namespace of the CURRENT process only,
# so this must be sourced in every process that talks to Vertex -- in this step
# that means each ParallelLogger worker (see buildChartReviews.R::reviewOne).
# The patch is idempotent and safe to source more than once.

applyEllmerGoogleCredentialsFix <- function() {
  if (!requireNamespace("ellmer", quietly = TRUE)) return(invisible(FALSE))

  ns <- asNamespace("ellmer")
  # Only patch a version that still has the function we expect.
  if (!exists("default_google_credentials", envir = ns, inherits = FALSE)) {
    return(invisible(FALSE))
  }

  default_google_credentials_hack <- function(error_call = rlang::caller_env(),
                                              variant = c("gemini", "vertex")) {
    gemini_scope <- "https://www.googleapis.com/auth/cloud-platform"
    # Upstream wrapped this in gargle::with_cred_funs(action = "replace"), which
    # dropped GCE metadata credentials. Call token_fetch() directly so gargle's
    # full default chain (incl. credentials_gce) is used.
    token <- gargle::token_fetch(scopes = gemini_scope)

    if (is.null(token) && is_testing()) {
      testthat::skip("no Google credentials available")
    }
    if (is.null(token) && is_interactive()) {
      return(function() {
        function(req) {
          req_oauth_auth_code(
            req, client = gemini_client(),
            auth_url = "https://accounts.google.com/o/oauth2/auth",
            scope = "https://www.googleapis.com/auth/generative-language.retriever"
          )
        }
      })
    }
    if (is.null(token)) {
      cli::cli_abort(
        c("No Google credentials are available.",
          i = "Try suppling an API key or configuring Google's application default credentials."),
        call = error_call
      )
    }
    if (!token$can_refresh()) {
      return(function() {
        list(Authorization = paste("Bearer", token$credentials$access_token))
      })
    }
    expiry <- Sys.time() + token$credentials$expires_in - 5
    return(function() {
      if (expiry < Sys.time()) {
        token$refresh()
      }
      list(Authorization = paste("Bearer", token$credentials$access_token))
    })
  }

  # Resolve unexported helpers (is_testing, is_interactive, req_oauth_auth_code,
  # gemini_client, ...) against ellmer's namespace by making it the function's
  # enclosing environment before installing it.
  environment(default_google_credentials_hack) <- ns
  assignInNamespace("default_google_credentials", default_google_credentials_hack,
                    ns = "ellmer")
  invisible(TRUE)
}

# Apply on source() so `source(ellmerFix.R)` is all a caller needs.
applyEllmerGoogleCredentialsFix()
