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

# --- Name / Unit / Value(-or-deciles) coverage ------------------------------
#
# An empty `UNIT` is a pair with no recorded unit. "Name" is always X --
# getSummaryData.R already drops every TEST_NAME "NA" row (the upstream
# extract's stringified missing value) before writing labSummary.tsv -- kept
# as a static column only so this table's shape matches the deciles one below.
# "Value" and "deciles" are deliberately different facts: value_missing_p under
# 100 means at least one record has a real value, `value_deciles` is empty far
# more often, for any pair below the upstream decile-computation's volume
# floor, whether or not it has real recorded values (see Action).
coverage <- labSummary |>
  dplyr::transmute(
    hasUnit = !is.na(UNIT) & nzchar(UNIT),
    hasValue = is.na(value_missing_p) | value_missing_p < 100,
    hasDeciles = !is.na(value_deciles),
    n
  )

# One pair of yes/no facts (e.g. hasUnit x hasValue) against every
# TEST_NAME/UNIT pair: all four combinations, even ones with zero rows, plus
# a totals row's worth of context (nPairs/totalRecords, passed in rather than
# recomputed so every coverage table is read against the same denominator).
buildCoverageTable <- function(df, col1, label1, col2, label2, nPairs, totalRecords) {
  combos <- tidyr::expand_grid(a = c(TRUE, FALSE), b = c(TRUE, FALSE)) |>
    dplyr::arrange(dplyr::desc(a), dplyr::desc(b))
  df |>
    dplyr::rename(a = dplyr::all_of(col1), b = dplyr::all_of(col2)) |>
    dplyr::group_by(a, b) |>
    dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .groups = "drop") |>
    dplyr::right_join(combos, by = c("a", "b")) |>
    dplyr::mutate(
      n_rows = tidyr::replace_na(n_rows, 0L),
      n_records = tidyr::replace_na(n_records, 0)
    ) |>
    dplyr::arrange(dplyr::desc(a), dplyr::desc(b)) |>
    dplyr::mutate(
      name = "X",
      !!label1 := ifelse(a, "X", ""),
      !!label2 := ifelse(b, "X", ""),
      pct_rows = sprintf("%.1f%%", 100 * n_rows / nPairs),
      pct_records = sprintf("%.1f%%", 100 * n_records / totalRecords)
    )
}

valueCoverageTable <- buildCoverageTable(coverage, "hasUnit", "unit", "hasValue", "value", nPairs, totalRecords)
decilesCoverageTable <- buildCoverageTable(coverage, "hasUnit", "unit", "hasDeciles", "deciles", nPairs, totalRecords)

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
    valueCoverageTable$name, valueCoverageTable$unit, valueCoverageTable$value,
    valueCoverageTable$n_rows, valueCoverageTable$pct_rows,
    valueCoverageTable$n_records, valueCoverageTable$pct_records
  ),
  sprintf(
    "| **total** | | | %d | %s | %d | %s |",
    nPairs, "100.0%", totalRecords, "100.0%"
  ),
  "",
  "### Name / unit / deciles coverage",
  "",
  "Same as above, with `value_deciles` computed in place of `value`. These",
  "are different facts, not two views of the same thing: `value_deciles` is",
  "empty for any pair below the upstream decile-computation's volume floor,",
  "whether or not it actually has recorded values (see Action) -- so this",
  "table's `X`s are a strict subset of the value-coverage table's.",
  "",
  "| name | unit | deciles | n rows | % rows | n records | % records |",
  "|---|---|---|---|---|---|---|",
  sprintf(
    "| %s | %s | %s | %d | %s | %d | %s |",
    decilesCoverageTable$name, decilesCoverageTable$unit, decilesCoverageTable$deciles,
    decilesCoverageTable$n_rows, decilesCoverageTable$pct_rows,
    decilesCoverageTable$n_records, decilesCoverageTable$pct_records
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
