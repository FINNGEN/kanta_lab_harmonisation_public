#
# Builds the LOINC axis frequency reference table.
#
# Joins the already-curated Finnish code -> OMOP mappings
# (ReferenceMappings/lab_data_summary.csv) to the OMOP vocabulary's own axis
# values (GetMeasurementOmopData/measurement_concept_attributes.tsv) on
# concept_id, then counts how often each axis VALUE is actually used in Finnish
# lab data -- by number of local codes and by number of records.
#
# The result is a prior over axis values: when a fuzzy search offers several
# plausible LOINC terms for the same axis, the one Finland actually uses is
# usually the right one. FixLOINCDimensions attaches these counts to its
# Hecate candidates so the model can break ties on real usage instead of
# guessing.
#
# Only status == "APPROVED" rows are counted. Those are the human-verified
# mappings; UNCHECKED ones would add volume but also add unverified (possibly
# wrong) concept assignments into what is meant to be a trustworthy prior.
#
# Each axis value's own concept_id is resolved through Hecate, because
# measurement_concept_attributes.tsv stores the related concept's NAME only,
# not its id. Only an exact (score == 1) name match is accepted as the id --
# anything less would be asserting an identity the data does not support.
#
# This is a reference-table builder, not part of the step's per-run action:
# it writes into DATA/SourceLabelingData/ alongside the other curated lookup
# tables (code_prefixes.tsv, code_suffixes.tsv) and only needs re-running when
# the reference mappings or the OMOP vocabulary snapshot change.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
referenceFile <- args[1]
omopAttributesFile <- args[2]
outFile <- args[3]

scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
if (is.na(scriptDir) || !nzchar(scriptDir)) scriptDir <- "."
source(file.path(scriptDir, "R", "hecate.R"))

workersEnv <- Sys.getenv("HECATE_PARALLEL_WORKERS", "")
workers <- if (nzchar(workersEnv)) as.integer(workersEnv) else 4L

# Map the output's bare axe_name to the column it comes from.
axisColumns <- c(
  component = "has_component",
  property = "has_property",
  method = "has_method",
  system = "has_system",
  scale_type = "has_scale_type",
  time_aspect = "has_time_aspect"
)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  referenceFile = ", referenceFile)
ParallelLogger::logInfo("  omopAttributesFile = ", omopAttributesFile)
ParallelLogger::logInfo("  outFile = ", outFile)
ParallelLogger::logInfo("  workers = ", workers)

#
# --- Input -------------------------------------------------------------
#
# lab_data_summary.csv comes from outside this project, so it keeps readr's
# default missing-value handling.
reference <- readr::read_tsv(referenceFile, col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(reference), " rows from ", referenceFile)

# na = "" per development/STYLE.md: written by this project.
omopAttributes <- readr::read_tsv(
  omopAttributesFile, na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(omopAttributes), " rows from ", omopAttributesFile)

#
# --- Action -------------------------------------------------------------
#
approved <- reference |>
  dplyr::filter(
    .data$status == "APPROVED",
    !is.na(.data$OMOP_CONCEPT_ID), .data$OMOP_CONCEPT_ID != "", .data$OMOP_CONCEPT_ID != "NA"
  ) |>
  dplyr::mutate(n_records_num = suppressWarnings(as.numeric(.data$n_records)))
ParallelLogger::logInfo("Kept ", nrow(approved), " APPROVED reference rows with a concept_id")

joined <- approved |>
  dplyr::inner_join(omopAttributes, by = c("OMOP_CONCEPT_ID" = "concept_id"))
ParallelLogger::logInfo("Joined ", nrow(joined), " rows to the OMOP attributes table (",
                        dplyr::n_distinct(joined$OMOP_CONCEPT_ID), " distinct concepts)")

# One row per (axis, value): how many local codes use it, and how many records
# those codes cover.
counts <- purrr::map_dfr(names(axisColumns), function(axis) {
  column <- axisColumns[[axis]]
  joined |>
    dplyr::filter(!is.na(.data[[column]])) |>
    dplyr::group_by(name = .data[[column]]) |>
    dplyr::summarise(
      n_codes = dplyr::n(),
      n_events = sum(.data$n_records_num, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::mutate(axe_name = axis, .before = 1)
})
ParallelLogger::logInfo("Counted ", nrow(counts), " distinct (axis, value) pairs")

# Resolve each value's own concept_id through Hecate. Exact matches only.
lookups <- counts |> dplyr::select(axe_name, name) |> dplyr::distinct()
ParallelLogger::logInfo("Resolving ", nrow(lookups), " axis values to concept_ids via Hecate (",
                        workers, " workers)")

resolveOne <- function(item, hecateFile) {
  source(hecateFile, local = TRUE)
  hits <- hecateSearch(item$name, item$axis, limit = 3)
  # Exact name match only: Hecate scores 1.0 when the term IS the concept name.
  # A near match would be a different concept, so leave the id empty instead.
  exact <- hits[!is.na(hits$score) & hits$score >= 0.999 &
                  tolower(hits$concept_name) == tolower(item$name), , drop = FALSE]
  list(
    axe_name = item$axis,
    name = item$name,
    concept_id = if (nrow(exact) > 0) exact$concept_id[1] else NA_character_
  )
}

lookupItems <- purrr::pmap(
  list(lookups$axe_name, lookups$name),
  function(axis, name) list(axis = axis, name = name)
)

hecateFile <- file.path(scriptDir, "R", "hecate.R")
if (workers > 1 && length(lookupItems) > 1) {
  cl <- ParallelLogger::makeCluster(workers)
  on.exit(ParallelLogger::stopCluster(cl), add = TRUE)
  resolved <- ParallelLogger::clusterApply(
    cl, lookupItems, resolveOne, hecateFile = hecateFile, progressBar = TRUE
  )
} else {
  resolved <- lapply(lookupItems, resolveOne, hecateFile = hecateFile)
}
resolvedTbl <- purrr::map_dfr(resolved, tibble::as_tibble)

nResolved <- sum(!is.na(resolvedTbl$concept_id))
ParallelLogger::logInfo(nResolved, " / ", nrow(resolvedTbl),
                        " axis values resolved to an exact-match concept_id")

result <- counts |>
  dplyr::left_join(resolvedTbl, by = c("axe_name", "name")) |>
  dplyr::select(axe_name, name, concept_id, n_codes, n_events) |>
  dplyr::arrange(.data$axe_name, dplyr::desc(.data$n_events), dplyr::desc(.data$n_codes))

#
# --- Output -------------------------------------------------------------
#
dir.create(dirname(outFile), recursive = TRUE, showWarnings = FALSE)
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
