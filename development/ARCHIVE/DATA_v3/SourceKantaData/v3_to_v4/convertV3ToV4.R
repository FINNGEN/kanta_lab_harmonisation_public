#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
scriptArg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
scriptDir <- dirname(sub("^--file=", "", scriptArg))
if (length(scriptDir) == 0 || is.na(scriptDir) || !nzchar(scriptDir)) scriptDir <- "."
sourceDir <- file.path(scriptDir, "..", "source")
outDir <- file.path(scriptDir, "..")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  sourceDir = ", sourceDir)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
summaryTestV3 <- readr::read_tsv(file.path(sourceDir, "summaryTest.tsv"), show_col_types = FALSE, na = "")
summaryValuesSourceV3 <- readr::read_tsv(file.path(sourceDir, "summaryValuesSource.tsv"), show_col_types = FALSE, na = "")
summaryValuesV3 <- readr::read_tsv(file.path(sourceDir, "summaryValues.tsv"), show_col_types = FALSE, na = "")
summaryOutcomesV3 <- readr::read_tsv(file.path(sourceDir, "summaryOutcomes.tsv"), show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(summaryTestV3), " rows from summaryTest.tsv")
ParallelLogger::logInfo("Read ", nrow(summaryValuesSourceV3), " rows from summaryValuesSource.tsv")
ParallelLogger::logInfo("Read ", nrow(summaryValuesV3), " rows from summaryValues.tsv")
ParallelLogger::logInfo("Read ", nrow(summaryOutcomesV3), " rows from summaryOutcomes.tsv")

#
# --- Action -------------------------------------------------------------
#

# summaryTest: v3 keys a row by OMOP_CONCEPT_ID + IS_EXTRACTED too (v4 does
# not); n_records/n_subjects are counts, so summing across whichever v3 rows
# share a TEST_NAME/MEASUREMENT_UNIT_PREFIX is always valid regardless of what
# gets merged together.
summaryTestV4 <- summaryTestV3 |>
  dplyr::group_by(TEST_NAME, MEASUREMENT_UNIT = MEASUREMENT_UNIT_PREFIX) |>
  dplyr::summarise(
    n_records = sum(n_records, na.rm = TRUE),
    n_subjects = sum(n_subjects, na.rm = TRUE),
    .groups = "drop"
  )

# summaryValuesSource: same as above, with MEASUREMENT_VALUE_TYPE (renamed
# value_source) added to the grouping key.
summaryValuesSourceV4 <- summaryValuesSourceV3 |>
  dplyr::group_by(TEST_NAME, MEASUREMENT_UNIT = MEASUREMENT_UNIT_PREFIX, value_source = MEASUREMENT_VALUE_TYPE) |>
  dplyr::summarise(
    n_records = sum(n_records, na.rm = TRUE),
    n_subjects = sum(n_subjects, na.rm = TRUE),
    .groups = "drop"
  )

# summaryOutcomes: same pattern again, TEST_OUTCOME added to the grouping key.
summaryOutcomesV4 <- summaryOutcomesV3 |>
  dplyr::group_by(TEST_NAME, MEASUREMENT_UNIT = MEASUREMENT_UNIT_PREFIX, TEST_OUTCOME) |>
  dplyr::summarise(
    n_TEST_OUTCOME = sum(n_TEST_OUTCOME, na.rm = TRUE),
    n_subjects = sum(n_subjects, na.rm = TRUE),
    .groups = "drop"
  )

# summaryValues: decile_MEASUREMENT_VALUE is a quantile, not a count -- it
# cannot be summed across colliding v3 rows the way the tables above can. A
# TEST_NAME/MEASUREMENT_UNIT_PREFIX collides when v3 carries more than one
# OMOP_CONCEPT_ID and/or an IS_EXTRACTED split for it; each such subgroup's
# n_records is constant across its own 9 decile rows, so picking the
# subgroup with the largest n_records (once per TEST_NAME/UNIT, not
# per-decile) always keeps all 9 of its deciles together rather than mixing
# deciles from different subgroups.
winningSubgroups <- summaryValuesV3 |>
  dplyr::distinct(TEST_NAME, MEASUREMENT_UNIT_PREFIX, OMOP_CONCEPT_ID, IS_EXTRACTED, n_records) |>
  dplyr::group_by(TEST_NAME, MEASUREMENT_UNIT_PREFIX) |>
  dplyr::slice_max(n_records, n = 1, with_ties = FALSE) |>
  dplyr::ungroup() |>
  dplyr::select(TEST_NAME, MEASUREMENT_UNIT_PREFIX, OMOP_CONCEPT_ID, IS_EXTRACTED)

summaryValuesV4 <- summaryValuesV3 |>
  dplyr::inner_join(winningSubgroups, by = c("TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "OMOP_CONCEPT_ID", "IS_EXTRACTED")) |>
  dplyr::transmute(
    TEST_NAME, MEASUREMENT_UNIT = MEASUREMENT_UNIT_PREFIX,
    n_subjects, n_records, decile, decile_MEASUREMENT_VALUE
  ) |>
  dplyr::arrange(TEST_NAME, MEASUREMENT_UNIT, decile)

ParallelLogger::logInfo(nrow(summaryTestV4), " rows in converted summaryTest.tsv")
ParallelLogger::logInfo(nrow(summaryValuesSourceV4), " rows in converted summaryValuesSource.tsv")
ParallelLogger::logInfo(nrow(summaryValuesV4), " rows in converted summaryValues.tsv")
ParallelLogger::logInfo(nrow(summaryOutcomesV4), " rows in converted summaryOutcomes.tsv")

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(summaryTestV4, file.path(outDir, "summaryTest.tsv"), na = "")
readr::write_tsv(summaryValuesSourceV4, file.path(outDir, "summaryValuesSource.tsv"), na = "")
readr::write_tsv(summaryValuesV4, file.path(outDir, "summaryValues.tsv"), na = "")
readr::write_tsv(summaryOutcomesV4, file.path(outDir, "summaryOutcomes.tsv"), na = "")
ParallelLogger::logInfo("Wrote ", file.path(outDir, "summaryTest.tsv"))
ParallelLogger::logInfo("Wrote ", file.path(outDir, "summaryValuesSource.tsv"))
ParallelLogger::logInfo("Wrote ", file.path(outDir, "summaryValues.tsv"))
ParallelLogger::logInfo("Wrote ", file.path(outDir, "summaryOutcomes.tsv"))
