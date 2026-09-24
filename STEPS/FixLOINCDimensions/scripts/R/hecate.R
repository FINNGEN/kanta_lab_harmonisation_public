#
# --- Hecate client -------------------------------------------------------------
#
# Hecate (https://hecate.pantheon-hds.com) is a semantic similarity search over
# the OMOP vocabularies. Given a free-text term and a concept class, it returns
# the closest real vocabulary concepts with a similarity score in [0, 1].
#
# Response shape (one element per matched concept NAME, which may itself cover
# several concept rows):
#   [ { "concept_name": "...", "score": 0.89,
#       "concepts": [ { "concept_id": 123, "concept_class_id": "...", ... } ] }, ... ]
#
# We keep the first concept row of each name: the axis values we are resolving
# are vocabulary terms, so a name maps to one concept in practice.

HECATE_BASE_URL <- "https://hecate.pantheon-hds.com/api/search"

# Concept class in the OMOP vocabulary for each LOINC axis. The axis names are
# the bare ones used in loinc_axes_frequency.tsv's `axe_name`.
HECATE_AXIS_CLASS <- c(
  component = "LOINC Component",
  property = "LOINC Property",
  method = "LOINC Method",
  system = "LOINC System",
  scale_type = "LOINC Scale",
  time_aspect = "LOINC Time"
)

# Search Hecate for one term within one axis. Returns a tibble with columns
# concept_name, concept_id, score (0 rows when nothing is found).
#
# Network errors are retried with a jittered backoff and then give up returning
# 0 rows, so one flaky lookup never aborts a whole run. `limit` is how many
# candidates to ask for; the caller applies the score threshold.
hecateSearch <- function(term, axis, limit = 5, maxAttempts = 3L) {
  emptyResult <- tibble::tibble(
    concept_name = character(0), concept_id = character(0), score = numeric(0)
  )
  if (is.na(term) || !nzchar(trimws(term))) return(emptyResult)

  conceptClass <- HECATE_AXIS_CLASS[[axis]]
  url <- paste0(
    HECATE_BASE_URL,
    "?q=", utils::URLencode(term, reserved = TRUE),
    "&vocabulary_id=LOINC",
    "&concept_class_id=", utils::URLencode(conceptClass, reserved = TRUE),
    "&limit=", limit
  )

  for (attempt in seq_len(maxAttempts)) {
    parsed <- tryCatch(
      jsonlite::fromJSON(url, simplifyVector = FALSE),
      error = function(e) {
        if (attempt == maxAttempts) {
          ParallelLogger::logWarn("Hecate lookup failed for ", axis, " '", term, "': ", conditionMessage(e))
        }
        NULL
      }
    )
    if (!is.null(parsed)) {
      if (length(parsed) == 0) return(emptyResult)
      return(purrr::map_dfr(parsed, function(hit) {
        conceptId <- if (length(hit$concepts) > 0) as.character(hit$concepts[[1]]$concept_id) else NA_character_
        tibble::tibble(
          concept_name = as.character(hit$concept_name),
          concept_id = conceptId,
          score = as.numeric(hit$score)
        )
      }))
    }
    if (attempt < maxAttempts) Sys.sleep(stats::runif(1, 0.3, 1.2) * attempt)
  }
  emptyResult
}
