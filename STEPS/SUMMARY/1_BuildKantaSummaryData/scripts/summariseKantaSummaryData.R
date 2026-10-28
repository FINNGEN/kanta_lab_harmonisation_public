#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
kantaSummaryDataFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  kantaSummaryDataFile = ", kantaSummaryDataFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
kantaSummaryData <- readr::read_tsv(
  kantaSummaryDataFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    UNIT = readr::col_character(),
    n = readr::col_double(),
    unit_source_injection_correction_na_p = readr::col_character(),
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = readr::col_character(),
    decile = readr::col_double(),
    decile_value = readr::col_double()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(kantaSummaryData), " rows from ", kantaSummaryDataFile)

#
# --- Action -------------------------------------------------------------
#

# One row per TEST_NAME + UNIT pair: the file has one row per decile, with the
# pair's n and percentages repeated on each.
pairs <- kantaSummaryData |>
  dplyr::distinct(TEST_NAME, UNIT, n, value_missing_p)

nPairs <- nrow(pairs)
totalRecords <- sum(pairs$n)
ParallelLogger::logInfo(nPairs, " TEST_NAME/UNIT pairs, ", format(totalRecords, big.mark = ","), " records")

# Name / unit / value coverage: one row per combination of three yes/no facts
# about a pair. Name is always X: buildKantaSummaryData drops the pairs whose
# TEST_NAME is the stringified missing value "NA". A pair has a value when
# value_missing_p is under 100, i.e. at least one record has a value.
coverage <- pairs |>
  dplyr::transmute(
    hasUnit = !is.na(UNIT) & nzchar(UNIT),
    hasValue = is.na(value_missing_p) | value_missing_p < 100,
    n
  )

combos <- tidyr::expand_grid(hasUnit = c(TRUE, FALSE), hasValue = c(TRUE, FALSE))
coverageTable <- coverage |>
  dplyr::group_by(hasUnit, hasValue) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .groups = "drop") |>
  dplyr::right_join(combos, by = c("hasUnit", "hasValue")) |>
  dplyr::mutate(
    n_rows = tidyr::replace_na(n_rows, 0L),
    n_records = tidyr::replace_na(n_records, 0)
  ) |>
  dplyr::arrange(dplyr::desc(hasUnit), dplyr::desc(hasValue))

fmtInt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
fmtPct <- function(x) sprintf("%.1f%%", x)

rows <- coverageTable |>
  dplyr::transmute(
    name = "X",
    unit = ifelse(hasUnit, "X", ""),
    value = ifelse(hasValue, "X", ""),
    `n rows` = fmtInt(n_rows),
    `% rows` = fmtPct(100 * n_rows / nPairs),
    `n records` = fmtInt(n_records),
    `% rec` = fmtPct(100 * n_records / totalRecords)
  ) |>
  dplyr::bind_rows(
    tibble::tibble(
      name = "total", unit = "", value = "",
      `n rows` = fmtInt(nPairs), `% rows` = "100%",
      `n records` = fmtInt(totalRecords), `% rec` = "100%"
    )
  )

mdRow <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
md <- c(
  "# kantaSummaryData stats",
  "",
  paste0(
    "Name / unit / value coverage of `kantaSummaryData.tsv`, one row per ",
    "`TEST_NAME` + `UNIT` pair. An `X` under unit means the pair has a recorded unit; ",
    "under value, that at least one of its records has a value."
  ),
  "",
  mdRow(names(rows)),
  mdRow(rep("---", ncol(rows))),
  vapply(seq_len(nrow(rows)), function(i) mdRow(unlist(rows[i, ])), character(1))
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "kantaSummaryDataStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
