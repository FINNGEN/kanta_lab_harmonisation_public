#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
kantaAgregatedTableFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  kantaAgregatedTableFile = ", kantaAgregatedTableFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
kantaAgregatedTable <- readr::read_tsv(
  kantaAgregatedTableFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    MEASUREMENT_UNIT = readr::col_character(),
    n = readr::col_double(),
    unit_source_injection_correction_na_p = readr::col_character(),
    reference_range = readr::col_character(),
    test_outcome = readr::col_character(),
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = readr::col_character(),
    decile = readr::col_double(),
    decile_value = readr::col_double()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(kantaAgregatedTable), " rows from ", kantaAgregatedTableFile)

#
# --- Action -------------------------------------------------------------
#

# One row per TEST_NAME + MEASUREMENT_UNIT pair: the file has one row per decile, with the
# pair's n and percentages repeated on each.
pairs <- kantaAgregatedTable |>
  dplyr::distinct(
    TEST_NAME, MEASUREMENT_UNIT, n, value_missing_p,
    unit_source_injection_correction_na_p, reference_range, test_outcome,
    value_source_extracted_qcout_na_p
  )

nPairs <- nrow(pairs)
totalRecords <- sum(pairs$n)
ParallelLogger::logInfo(nPairs, " TEST_NAME/MEASUREMENT_UNIT pairs, ", format(totalRecords, big.mark = ","), " records")

# Name / unit / value coverage: one row per combination of three yes/no facts
# about a pair. Name is always X: buildKantaAgregatedTable drops the pairs whose
# TEST_NAME is the stringified missing value "NA". A pair has a value when
# value_missing_p is under 100, i.e. at least one record has a value.
coverage <- pairs |>
  dplyr::transmute(
    hasUnit = !is.na(MEASUREMENT_UNIT) & nzchar(MEASUREMENT_UNIT),
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
mdTable <- function(df) {
  c(
    mdRow(names(df)),
    mdRow(rep("---", ncol(df))),
    vapply(seq_len(nrow(df)), function(i) mdRow(unlist(df[i, ])), character(1))
  )
}

# Source tables (Units, Values): one row per source label. A pair counts as a row
# of a source when that source has more than 0% of its records; n records is the
# sum over pairs of n * share. Shares are stored rounded to 2 decimals, so n
# records is approximate. Rows overlap (a pair can have several sources), so
# % rows does not add up to 100.
sourceTable <- function(pctColumn, labels) {
  shares <- pairs[[pctColumn]] |>
    stringr::str_remove_all("[\\[\\]%]") |>
    stringr::str_split_fixed(",", length(labels)) |>
    apply(2, as.numeric)
  colnames(shares) <- labels
  out <- lapply(labels, function(lab) {
    present <- shares[, lab] > 0
    nRecords <- round(sum(pairs$n * shares[, lab] / 100))
    tibble::tibble(
      source = if (lab == "na") "" else lab,
      `n rows` = fmtInt(sum(present)),
      `% rows` = fmtPct(100 * sum(present) / nPairs),
      `n records` = fmtInt(nRecords),
      `% rec` = fmtPct(100 * nRecords / totalRecords)
    )
  })
  dplyr::bind_rows(out) |>
    dplyr::bind_rows(
      tibble::tibble(
        source = "total", `n rows` = fmtInt(nPairs), `% rows` = "100%",
        `n records` = fmtInt(totalRecords), `% rec` = "100%"
      )
    )
}

unitSourceTable <- sourceTable(
  "unit_source_injection_correction_na_p", c("Source", "PrimaryInjection", "SecondaryCorrection", "na")
)
valueSourceTable <- sourceTable(
  "value_source_extracted_qcout_na_p", c("Source", "Extracted", "QCOut", "na")
)

# Reference ranges: one row per combination of demographic bins present in a
# pair's reference_range (AF, AM, MF, MM), most frequent first. The row with no
# bin is the pairs with no reference range.
bins <- c("AF", "AM", "MF", "MM")
refRange <- pairs |>
  dplyr::transmute(
    AF = stringr::str_detect(reference_range, "AF\\["),
    AM = stringr::str_detect(reference_range, "AM\\["),
    MF = stringr::str_detect(reference_range, "MF\\["),
    MM = stringr::str_detect(reference_range, "MM\\["),
    n
  ) |>
  tidyr::replace_na(list(AF = FALSE, AM = FALSE, MF = FALSE, MM = FALSE))
refRangeTable <- refRange |>
  dplyr::group_by(AF, AM, MF, MM) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(n_rows)) |>
  dplyr::transmute(
    dplyr::across(dplyr::all_of(bins), ~ ifelse(.x, "X", "")),
    `n rows` = fmtInt(n_rows),
    `% rows` = fmtPct(100 * n_rows / nPairs),
    `n records` = fmtInt(n_records),
    `% rec` = fmtPct(100 * n_records / totalRecords)
  ) |>
  dplyr::bind_rows(
    tibble::tibble(
      AF = "total", AM = "", MF = "", MM = "",
      `n rows` = fmtInt(nPairs), `% rows` = "100%",
      `n records` = fmtInt(totalRecords), `% rec` = "100%"
    )
  )

# Test outcomes: one row per combination of TEST_OUTCOME present in a pair's test_outcome, most frequent
# first, with one column per outcome in the order of the test_outcome strings. The row with no outcome is
# the pairs with no test outcome.
outcomeLists <- stringr::str_match_all(tidyr::replace_na(pairs$test_outcome, ""), "([^;\\[]+)\\[")
outcomeLists <- lapply(outcomeLists, function(m) m[, 2])
outcomes <- unique(unlist(outcomeLists))
outcomeOrder <- c("N", "A", "AA", "L", "LL", "H", "HH", "POS", "NEG", "IND", "I")
outcomes <- c(intersect(outcomeOrder, outcomes), sort(setdiff(outcomes, outcomeOrder)))
outcomePresence <- tibble::as_tibble(
  stats::setNames(lapply(outcomes, function(o) vapply(outcomeLists, function(l) o %in% l, logical(1))), outcomes)
)
outcomeTable <- dplyr::bind_cols(outcomePresence, n = pairs$n) |>
  dplyr::group_by(dplyr::across(dplyr::all_of(outcomes))) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(n_rows)) |>
  dplyr::transmute(
    dplyr::across(dplyr::all_of(outcomes), ~ ifelse(.x, "X", "")),
    `n rows` = fmtInt(n_rows),
    `% rows` = fmtPct(100 * n_rows / nPairs),
    `n records` = fmtInt(n_records),
    `% rec` = fmtPct(100 * n_records / totalRecords)
  )
outcomeTotal <- stats::setNames(as.list(c("total", rep("", length(outcomes) - 1))), outcomes)
outcomeTable <- dplyr::bind_rows(
  outcomeTable,
  tibble::as_tibble(c(outcomeTotal, list(`n rows` = fmtInt(nPairs), `% rows` = "100%", `n records` = fmtInt(totalRecords), `% rec` = "100%")))
)

md <- c(
  "# Name Unit Value combinations",
  "",
  paste0(
    "Name / unit / value coverage of `kantaAgregatedTable.tsv`, one row per ",
    "`TEST_NAME` + `MEASUREMENT_UNIT` pair. An `X` under unit means the pair has a recorded unit; ",
    "under value, that at least one of its records has a value."
  ),
  "",
  mdTable(rows),
  "",
  "# Units",
  "",
  paste0(
    "Where the unit of the records came from (`unit_source_injection_correction_na_p`). ",
    "A pair counts in a source when some of its records come from it, so `% rows` does not add up to 100%. ",
    "`n records` is approximate (shares are rounded)."
  ),
  "",
  mdTable(unitSourceTable),
  "",
  "# Values",
  "",
  paste0(
    "Where the value of the records came from (`value_source_extracted_qcout_na_p`); `na` is records with no value. ",
    "Same counting as Units."
  ),
  "",
  mdTable(valueSourceTable),
  "",
  "# Reference Ranges",
  "",
  paste0(
    "Combinations of demographic bins with a reference range (`reference_range`): ",
    "`AF` adult female, `AM` adult male, `MF` minor female, `MM` minor male. ",
    "An `X` means the pair has a range for that bin; the row with no `X` has no reference range."
  ),
  "",
  mdTable(refRangeTable),
  "",
  "# Test Outcomes",
  "",
  paste0(
    "Combinations of test outcomes (`test_outcome`, from `summaryOutcomes.tsv`), e.g. `N` normal, `A` abnormal, ",
    "`L` / `H` low / high, `AA` / `LL` / `HH` very abnormal / low / high, `POS` / `NEG` positive / negative. ",
    "An `X` means some records of the pair have that outcome; the row with no `X` has no test outcome."
  ),
  "",
  mdTable(outcomeTable)
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "kantaAgregatedTable.summary.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
