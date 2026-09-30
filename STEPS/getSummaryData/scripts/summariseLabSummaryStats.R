#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
labSummaryFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  labSummaryFile = ", labSummaryFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
labSummary <- readr::read_tsv(labSummaryFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(labSummary), " rows from ", labSummaryFile)

#
# --- Action -------------------------------------------------------------
#

# Pulls the four bracketed percentages back out of e.g.
# "[76.84,23.16,0,0]%" -- the only interface back into this table's own
# output, same as every other summarise*Stats.R script in this repo re-reading
# its build script's TSV rather than sharing intermediate values with it.
parseQuad <- function(col) {
  m <- stringr::str_match(col, "^\\[([0-9.]*),([0-9.]*),([0-9.]*),([0-9.]*)\\]%$")
  tibble::tibble(
    a = as.numeric(m[, 2]), b = as.numeric(m[, 3]),
    c = as.numeric(m[, 4]), d = as.numeric(m[, 5])
  )
}

nPairs <- nrow(labSummary)
nWithDeciles <- sum(!is.na(labSummary$value_deciles))
totalRecords <- sum(labSummary$n, na.rm = TRUE)

overview <- tibble::tibble(
  bucket = c("total TEST_NAME/UNIT pairs", "with value_deciles computed"),
  n = c(nPairs, nWithDeciles)
) |>
  dplyr::mutate(pct = sprintf("%.1f%%", 100 * n / nPairs))

# --- Name / Unit / Value coverage -------------------------------------------
#
# `TEST_NAME "NA"` is the upstream extract's stringified missing value (see
# BuildKnownInformationTable/README.md), an empty `UNIT` is a pair with no
# recorded unit, and "no value" means value_missing_p is 100 -- not "no
# value_deciles" (`value_deciles` is empty far more often, for any pair below
# the upstream decile-computation's volume floor, whether or not it has real
# recorded values).
coverage <- labSummary |>
  dplyr::transmute(
    hasName = !(TEST_NAME == "NA" & !is.na(TEST_NAME)),
    hasUnit = !is.na(UNIT) & nzchar(UNIT),
    hasValue = is.na(value_missing_p) | value_missing_p < 100,
    n
  )

# hasName = FALSE combos are omitted: getSummaryData.R already drops every
# TEST_NAME "NA" row before writing labSummary.tsv, so they never occur --
# listing them here would just be four all-zero rows.
combos <- tidyr::expand_grid(hasName = TRUE, hasUnit = c(TRUE, FALSE), hasValue = c(TRUE, FALSE)) |>
  dplyr::arrange(dplyr::desc(hasName), dplyr::desc(hasUnit), dplyr::desc(hasValue))

coverageTable <- coverage |>
  dplyr::group_by(hasName, hasUnit, hasValue) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .groups = "drop") |>
  dplyr::right_join(combos, by = c("hasName", "hasUnit", "hasValue")) |>
  dplyr::mutate(
    n_rows = tidyr::replace_na(n_rows, 0L),
    n_records = tidyr::replace_na(n_records, 0)
  ) |>
  dplyr::arrange(dplyr::desc(hasName), dplyr::desc(hasUnit), dplyr::desc(hasValue)) |>
  dplyr::mutate(
    name = ifelse(hasName, "X", ""),
    unit = ifelse(hasUnit, "X", ""),
    value = ifelse(hasValue, "X", ""),
    pct_rows = sprintf("%.1f%%", 100 * n_rows / nPairs),
    pct_records = sprintf("%.1f%%", 100 * n_records / totalRecords)
  )

# --- Unit / value source composition ----------------------------------------
#
# The bracketed percentage columns are parsed back into counts (n * pct / 100,
# rounded) so each bucket can be reported the same four ways as the coverage
# table above -- n_rows/pct_rows is "how many pairs have any record in this
# bucket", n_records/pct_records is "what share of all records fall in it"
# (the latter is the same figure a records-weighted mean of the percentage
# column would give).
bucketTable <- function(pctTable, labels, n, nPairs, totalRecords) {
  purrr::imap_dfr(list(a = pctTable$a, b = pctTable$b, c = pctTable$c, d = pctTable$d), function(pct, key) {
    counts <- round(n * pct / 100)
    tibble::tibble(
      bucket = labels[[key]],
      n_rows = sum(counts > 0),
      n_records = sum(counts)
    )
  }) |>
    dplyr::mutate(
      pct_rows = sprintf("%.1f%%", 100 * n_rows / nPairs),
      pct_records = sprintf("%.1f%%", 100 * n_records / totalRecords)
    )
}

unitSourceTable <- bucketTable(
  parseQuad(labSummary$unit_source_injection_correction_na_p),
  list(a = "Source", b = "PrimaryInjection", c = "SecondaryCorrection", d = "no unit_source recorded (NA)"),
  labSummary$n, nPairs, totalRecords
)

valueSourceTable <- bucketTable(
  parseQuad(labSummary$value_source_extracted_qcout_na_p),
  list(a = "Source", b = "Extracted", c = "QCOut", d = "no value recorded (NA)"),
  labSummary$n, nPairs, totalRecords
)

ParallelLogger::logInfo("Computed overview, coverage and unit/value source composition stats")

#
# --- Output -------------------------------------------------------------
#
md <- c(
  "# Lab Summary -- Stats",
  "",
  paste0("Source: `", labSummaryFile, "`"),
  "",
  "## Overview",
  "",
  paste0("Total records across all pairs: ", format(totalRecords, big.mark = ",")),
  "",
  "| bucket | n | % |",
  "|---|---|---|",
  sprintf("| %s | %d | %s |", overview$bucket, overview$n, overview$pct),
  "",
  "### Name / unit / value coverage",
  "",
  "Every `TEST_NAME`/`UNIT` pair against the three things it may or may not",
  "carry: a real `TEST_NAME` (not the upstream's stringified missing value,",
  "`\"NA\"`), a recorded `UNIT`, and at least one record with a value",
  "(`value_missing_p` under 100).",
  "",
  "| name | unit | value | n rows | % rows | n records | % records |",
  "|---|---|---|---|---|---|---|",
  sprintf(
    "| %s | %s | %s | %d | %s | %d | %s |",
    coverageTable$name, coverageTable$unit, coverageTable$value,
    coverageTable$n_rows, coverageTable$pct_rows,
    coverageTable$n_records, coverageTable$pct_records
  ),
  sprintf(
    "| **total** | | | %d | %s | %d | %s |",
    nPairs, "100.0%", totalRecords, "100.0%"
  ),
  "",
  "## Unit source composition",
  "",
  "Each `unit_source` bucket: how many pairs have any record in it, and what",
  "share of all records fall in it.",
  "",
  "| bucket | n rows | % rows | n records | % records |",
  "|---|---|---|---|---|",
  sprintf(
    "| %s | %d | %s | %d | %s |",
    unitSourceTable$bucket, unitSourceTable$n_rows, unitSourceTable$pct_rows,
    unitSourceTable$n_records, unitSourceTable$pct_records
  ),
  "",
  "## Value source composition",
  "",
  "Same as above, for `value_source`.",
  "",
  "| bucket | n rows | % rows | n records | % records |",
  "|---|---|---|---|---|",
  sprintf(
    "| %s | %d | %s | %d | %s |",
    valueSourceTable$bucket, valueSourceTable$n_rows, valueSourceTable$pct_rows,
    valueSourceTable$n_records, valueSourceTable$pct_records
  )
)

outFile <- file.path(outDir, "labSummaryStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
