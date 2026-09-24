#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
codesWithLoincDimensionsFile <- args[1]
measurementConceptAttributesFile <- args[2]
outDir <- args[3]

contentAxes <- c("has_component", "has_property", "has_method", "has_scale_type", "has_system", "has_time_aspect")
allAxes <- c(contentAxes, "is_panel")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithLoincDimensionsFile = ", codesWithLoincDimensionsFile)
ParallelLogger::logInfo("  measurementConceptAttributesFile = ", measurementConceptAttributesFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  join key = ", paste(allAxes, collapse = ", "))

#
# --- Input -------------------------------------------------------------
#
codes <- readr::read_tsv(codesWithLoincDimensionsFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", codesWithLoincDimensionsFile)

concepts <- readr::read_tsv(measurementConceptAttributesFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(concepts), " rows from ", measurementConceptAttributesFile)

#
# --- Action -------------------------------------------------------------
#

# One summary row per distinct axis tuple actually observed among the OMOP
# concepts, listing every concept that shares it. Concepts with none of the 6
# content axes known (mostly non-LOINC concepts in the Measurement domain,
# e.g. SNOMED clinical findings) are dropped first: joining on "everything is
# unknown" would match a local code with no axis information at all against
# every one of them, which is not a real match, just two unknowns lining up.
omopByTuple <- concepts |>
  dplyr::filter(rowSums(!is.na(dplyr::across(dplyr::all_of(contentAxes)))) > 0) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(allAxes))) |>
  dplyr::summarise(
    omop_concept_id = paste(unique(concept_id), collapse = "; "),
    omop_concept_name = paste(unique(concept_name), collapse = "; "),
    omop_vocabulary_id = paste(unique(vocabulary_id), collapse = "; "),
    n_omop_matches = dplyr::n_distinct(concept_id),
    .groups = "drop"
  )
ParallelLogger::logInfo(
  "Built ", nrow(omopByTuple), " distinct OMOP axis tuples from ",
  sum(omopByTuple$n_omop_matches), " concepts (",
  nrow(concepts) - sum(omopByTuple$n_omop_matches), " concepts with no axis known were excluded as join targets)"
)

result <- codes |>
  dplyr::left_join(omopByTuple, by = allAxes) |>
  dplyr::mutate(n_omop_matches = tidyr::replace_na(n_omop_matches, 0L))

hasAxisInfo <- rowSums(!is.na(codes[contentAxes])) > 0
nMatched <- sum(result$n_omop_matches > 0)
ParallelLogger::logInfo(
  sum(hasAxisInfo), " / ", nrow(result), " rows have at least one axis known; ",
  nMatched, " / ", nrow(result), " rows matched at least one OMOP concept"
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "codesWithOMOP.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
