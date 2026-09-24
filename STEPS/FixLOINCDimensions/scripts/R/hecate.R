#
# --- Hecate client -------------------------------------------------------------
#
# Hecate (https://hecate.pantheon-hds.com) is a semantic similarity search over
# the OMOP vocabularies. Given a free-text term it returns the closest real
# vocabulary concepts with a similarity score in [0, 1].
#
# Response shape (one element per matched concept NAME, which may itself cover
# several concept rows):
#   [ { "concept_name": "...", "score": 0.89,
#       "concepts": [ { "concept_id": 123, "concept_code": "...", ... } ] }, ... ]
#
# We keep the first concept row of each name. With the filters below that row is
# a standard, valid, Measurement-domain LOINC concept, and in practice a LOINC
# name identifies exactly one such concept.

HECATE_BASE_URL <- "https://hecate.pantheon-hds.com/api/search"

# Search Hecate for one LOINC Long Common Name. Returns a tibble with columns
# concept_name, concept_id, concept_code, score (0 rows when nothing is found).
#
# The search is restricted to LOINC concepts in the Measurement domain that are
# STANDARD (`standard_concept=S`). Without the standard filter the top hit is
# regularly a deprecated concept -- searching the real LOINC name
# "Glucose [Mass or Moles/volume] in Serum or Plasma" scores its own deprecated
# concept 1.000 and pushes the two live glucose concepts below it -- and mapping
# local data onto a deprecated concept is worse than not mapping it at all.
# No concept_class_id filter is applied, so panels and clinical observations
# stay reachable alongside ordinary lab tests.
#
# Network errors are retried with a jittered backoff and then give up returning
# 0 rows, so one flaky lookup never aborts a whole run. `limit` is how many
# candidates to ask for; the caller applies any score threshold.
hecateSearch <- function(term, limit = 10, maxAttempts = 3L) {
  emptyResult <- tibble::tibble(
    concept_name = character(0), concept_id = character(0),
    concept_code = character(0), score = numeric(0)
  )
  if (is.na(term) || !nzchar(trimws(term))) return(emptyResult)

  url <- paste0(
    HECATE_BASE_URL,
    "?q=", utils::URLencode(term, reserved = TRUE),
    "&vocabulary_id=LOINC",
    "&domain_id=Measurement",
    "&standard_concept=S",
    "&limit=", limit
  )

  for (attempt in seq_len(maxAttempts)) {
    parsed <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = FALSE),
      error = function(e) {
        if (attempt == maxAttempts) {
          ParallelLogger::logWarn("Hecate lookup failed for '", term, "': ", conditionMessage(e))
        }
        NULL
      }
    )
    if (!is.null(parsed)) {
      if (length(parsed) == 0) return(emptyResult)
      return(purrr::map_dfr(parsed, function(hit) {
        top <- if (length(hit$concepts) > 0) hit$concepts[[1]] else list()
        tibble::tibble(
          concept_name = as.character(hit$concept_name),
          concept_id = if (is.null(top$concept_id)) NA_character_ else as.character(top$concept_id),
          concept_code = if (is.null(top$concept_code)) NA_character_ else as.character(top$concept_code),
          score = as.numeric(hit$score)
        )
      }))
    }
    if (attempt < maxAttempts) Sys.sleep(stats::runif(1, 0.3, 1.2) * attempt)
  }
  emptyResult
}
