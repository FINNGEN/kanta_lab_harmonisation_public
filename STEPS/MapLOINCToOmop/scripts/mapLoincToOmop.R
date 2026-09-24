#
# Attaches the OMOP vocabulary's own record of each concept chosen by
# FixLOINCDimensions.
#
# There is no matching to do here any more. FixLOINCDimensions already returns
# an omop_concept_id per local code, chosen from concepts a semantic search
# actually found, so this step's job is to look each id up and carry the
# vocabulary's authoritative name, code and axes alongside it -- and to say so
# loudly if an id is not in the vocabulary at all.
#
# The earlier version of this step did the mapping itself, by joining the six
# LLM-inferred LOINC axes plus is_panel against the same seven columns on every
# OMOP concept. That join fires only when all seven land exactly right, which
# is combinatorially fragile: on a 30-group sample it matched 287 of 1,940 rows
# (14.8%), and of the rows that overlapped the curated Finnish mapping only
# 11.3% agreed with it. Choosing one concept from a retrieved shortlist
# replaces seven independent chances to be wrong with one.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
codesWithOmopConceptsFile <- args[1]
measurementConceptAttributesFile <- args[2]
outDir <- args[3]

# The vocabulary's own axes, carried through for reporting: they describe the
# concept that was chosen, not the local code, and they are what the stats
# report breaks the match rate down by.
omopAxes <- c("has_component", "has_property", "has_method",
              "has_scale_type", "has_system", "has_time_aspect")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithOmopConceptsFile = ", codesWithOmopConceptsFile)
ParallelLogger::logInfo("  measurementConceptAttributesFile = ", measurementConceptAttributesFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
codes <- readr::read_tsv(codesWithOmopConceptsFile, show_col_types = FALSE, na = "",
                         col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", codesWithOmopConceptsFile)

concepts <- readr::read_tsv(measurementConceptAttributesFile, show_col_types = FALSE, na = "",
                            col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(concepts), " rows from ", measurementConceptAttributesFile)

#
# --- Action -------------------------------------------------------------
#
lookup <- concepts |>
  dplyr::distinct(concept_id, .keep_all = TRUE) |>
  dplyr::select(
    concept_id,
    omop_concept_name = concept_name,
    omop_concept_code = concept_code,
    omop_vocabulary_id = vocabulary_id,
    omop_is_panel = is_panel,
    dplyr::all_of(omopAxes)
  ) |>
  dplyr::rename_with(~ paste0("omop_", .x), dplyr::all_of(omopAxes))

# The input already carries omop_concept_name, copied from the candidate list.
# Drop it and take the vocabulary's: the vocabulary is the authority on how a
# concept is spelled, and keeping two columns that can disagree invites a
# reader to trust the wrong one.
result <- codes |>
  dplyr::select(-dplyr::any_of("omop_concept_name")) |>
  dplyr::left_join(lookup, by = c("omop_concept_id" = "concept_id")) |>
  dplyr::mutate(mapped = !is.na(.data$omop_concept_id) & !is.na(.data$omop_concept_name)) |>
  dplyr::relocate(mapped, .after = dplyr::last_col())

nChosen <- sum(!is.na(result$omop_concept_id))
nUnknown <- sum(!is.na(result$omop_concept_id) & is.na(result$omop_concept_name))
if (nUnknown > 0) {
  ParallelLogger::logWarn(nUnknown, " row(s) carry a concept_id that is not in the OMOP ",
                          "attributes table; they are reported as unmapped")
}
ParallelLogger::logInfo(
  nChosen, " / ", nrow(result), " rows carry a concept_id; ",
  sum(result$mapped), " resolved to an OMOP concept (",
  dplyr::n_distinct(result$omop_concept_id[result$mapped]), " distinct concepts)"
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "codesWithOMOP.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
