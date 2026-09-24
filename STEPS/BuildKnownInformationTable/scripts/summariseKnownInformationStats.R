#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
knownInformationFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  knownInformationFile = ", knownInformationFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
# na = "" (not readr's default c("", "NA")): some TEST_NAME values are
# literally the text "NA" -- a real abbreviation, not a missing value -- and
# knownInformationFile itself only ever writes "" for a genuine missing value.
knownInformation <- readr::read_tsv(knownInformationFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(knownInformation), " rows from ", knownInformationFile)

#
# --- Action -------------------------------------------------------------
#
# Bucket table 1: distinct TEST_NAME + UNIT (one row per knownInformation row).
testUnitBuckets <- tibble::tibble(
  bucket = c("total", "with recorded data (p_missing < 95.0)", "with deciles computed"),
  n = c(
    nrow(knownInformation),
    sum(knownInformation$p_missing < 95.0, na.rm = TRUE),
    sum(!is.na(knownInformation$deciles))
  )
)
testUnitTotal <- testUnitBuckets$n[testUnitBuckets$bucket == "total"]
testUnitBuckets <- testUnitBuckets |>
  dplyr::mutate(pct = sprintf("%.1f%%", 100 * n / testUnitTotal))

# LongName/prefix_meaning/suffix_meaning depend only on TEST_NAME, so they
# are constant across a TEST_NAME's UNIT rows -- collapse to one row per
# TEST_NAME. n is the total observations across all of a TEST_NAME's units.
byTestName <- knownInformation |>
  dplyr::group_by(TEST_NAME) |>
  dplyr::summarise(
    n = sum(n, na.rm = TRUE),
    LongName = dplyr::first(LongName),
    prefix_meaning = dplyr::first(prefix_meaning),
    suffix_meaning = dplyr::first(suffix_meaning),
    .groups = "drop"
  ) |>
  dplyr::mutate(isNumber = grepl("^[0-9]+$", TEST_NAME))

# Bucket table 2: distinct TEST_NAME, one small table per event-volume tier
# (all tests, then progressively higher-volume subsets) so each table stays a
# plain bucket/n/% read with its own, stated denominator -- no column mixes
# counts against different totals.
volumeTiers <- list(
  `All TEST_NAME` = rep(TRUE, nrow(byTestName)),
  `TEST_NAME with n_events > 100` = byTestName$n > 100,
  `TEST_NAME with n_events > 500` = byTestName$n > 500
)
metadataBucketMasks <- list(
  `is number (TEST_NAME is a bare digit code)` = byTestName$isNumber,
  `with long name` = !is.na(byTestName$LongName),
  `with prefix` = !is.na(byTestName$prefix_meaning),
  `with suffix` = !is.na(byTestName$suffix_meaning)
)
tierTables <- purrr::imap(volumeTiers, function(tierMask, tierName) {
  tierTotal <- sum(tierMask)
  bucketRows <- purrr::imap_dfr(metadataBucketMasks, function(bucketMask, bucketName) {
    tibble::tibble(bucket = bucketName, n = sum(tierMask & bucketMask))
  })
  dplyr::bind_rows(tibble::tibble(bucket = "total", n = tierTotal), bucketRows) |>
    dplyr::mutate(pct = sprintf("%.1f%%", 100 * n / tierTotal))
})

prefixTable <- byTestName |>
  dplyr::filter(!is.na(prefix_meaning)) |>
  dplyr::count(prefix_meaning, name = "n_distinct_TEST_NAME") |>
  dplyr::arrange(dplyr::desc(n_distinct_TEST_NAME))
nDistinctPrefixes <- nrow(prefixTable)

suffixTable <- byTestName |>
  dplyr::filter(!is.na(suffix_meaning)) |>
  dplyr::count(suffix_meaning, name = "n_distinct_TEST_NAME") |>
  dplyr::arrange(dplyr::desc(n_distinct_TEST_NAME))
nDistinctSuffixes <- nrow(suffixTable)

ParallelLogger::logInfo("Computed overview and prefix/suffix usage stats")

#
# --- Output -------------------------------------------------------------
#
tierSections <- purrr::imap(tierTables, function(tbl, tierName) {
  tierN <- tbl$n[tbl$bucket == "total"]
  c(
    paste0("**", tierName, "** (n = ", tierN, ")"),
    "",
    "| bucket | n | % |",
    "|---|---|---|",
    sprintf("| %s | %d | %s |", tbl$bucket, tbl$n, tbl$pct),
    ""
  )
}) |> unlist(use.names = FALSE)

md <- c(
  "# Known Information Table -- Stats",
  "",
  paste0("Source: `", knownInformationFile, "`"),
  "",
  "## Overview",
  "",
  "### Distinct TEST_NAME + UNIT",
  "",
  "Each row of `knownInformation.tsv` is one `TEST_NAME`/`UNIT` pair.",
  "`with recorded data` counts pairs that are not almost entirely missing",
  "(`p_missing` < 95%); `with deciles computed` counts pairs that got a",
  "decile summary.",
  "",
  "| bucket | n | % |",
  "|---|---|---|",
  sprintf("| %s | %d | %s |", testUnitBuckets$bucket, testUnitBuckets$n, testUnitBuckets$pct),
  "",
  "### Distinct TEST_NAME",
  "",
  "Collapsing to one row per `TEST_NAME` (summing `n` across its units) shows",
  "how much lab-code metadata is available, and whether that coverage holds",
  "up for the tests that actually have data. The three tables below are the",
  "same buckets applied to three overlapping tiers -- all `TEST_NAME`s, then",
  "only those with more than 100 / more than 500 total events -- and each",
  "table's `%` is relative to that tier's own total, stated in its heading.",
  "",
  "- `is number` -- `TEST_NAME` is a bare digit code, never resolved to an",
  "  abbreviation (likely a raw internal code).",
  "- `with long name` / `with prefix` / `with suffix` -- matched as described",
  "  in this step's `README.md`.",
  "",
  tierSections,
  "## Prefixes",
  "",
  "Among the distinct `TEST_NAME`s with a recognized prefix, how many use",
  "each prefix meaning, sorted by usage descending.",
  "",
  paste0("n distinct prefixes: ", nDistinctPrefixes),
  "",
  "| Prefix meaning | n distinct TEST_NAME |",
  "|---|---|",
  sprintf("| %s | %d |", prefixTable$prefix_meaning, prefixTable$n_distinct_TEST_NAME),
  "",
  "## Suffixes",
  "",
  "Same as Prefixes, for the distinct `TEST_NAME`s with a recognized suffix.",
  "",
  paste0("n distinct suffixes: ", nDistinctSuffixes),
  "",
  "| Suffix meaning | n distinct TEST_NAME |",
  "|---|---|",
  sprintf("| %s | %d |", suffixTable$suffix_meaning, suffixTable$n_distinct_TEST_NAME)
)

outFile <- file.path(outDir, "knownInformationStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
