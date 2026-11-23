#
# Validates the Kanta summary tables of 0_KantaAgregatedData before they are combined. Every test
# is a SUCCESS, a WARNING (a finding that does not break the build) or an ERROR. The report is
# written to kantaAgregatedTable.validation.md; the script stops (non-zero exit) when any test is
# an ERROR, so the build does not run on broken input.
#
# See this step's README.md for the tests.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
summaryTestFile <- args[1]
summaryUnitSourceFile <- args[2]
summaryValuesSourceFile <- args[3]
summaryValuesFile <- args[4]
summaryReferenceFile <- args[5]
summaryOutcomesFile <- args[6]
settingsFile <- args[7]
outDir <- args[8]

# The pair key of every table.
pairKey <- c("TEST_NAME", "MEASUREMENT_UNIT")
# Small counts are removed upstream: no row may have this many subjects or fewer.
maxRemovedSubjects <- 5
# A pair with at least this many records with a value must have its deciles: n_records_no_value_threshold and n_subjects_no_value_threshold of
# upstreamSettings.yaml, under which a pair counts as having no values (the whole repo uses it).
readSetting <- function(settingsFile, key) {
  value <- yaml::read_yaml(settingsFile)[[key]]
  if (!is.numeric(value) || length(value) != 1) stop(key, " is missing or not a number in ", settingsFile)
  value
}
minValues <- readSetting(settingsFile, "n_records_no_value_threshold")
minSubjects <- readSetting(settingsFile, "n_subjects_no_value_threshold")
unitSources <- c("Source", "PrimaryInjection")
valueSources <- c("Source", "Extracted", "QCOut")
demographicsBins <- c("Adult-Female", "Adult-Male", "Minor-Female", "Minor-Male")
deciles <- c("0.1", "0.2", "0.3", "0.4", "0.5", "0.6", "0.7", "0.8", "0.9")

# The columns of each table, in order, and which are numbers.
tableSpecs <- list(
  summaryTest.tsv = list(
    file = summaryTestFile, key = pairKey,
    columns = c("TEST_NAME", "MEASUREMENT_UNIT", "n_records", "n_subjects"),
    counts = c("n_records", "n_subjects"), numbers = character(0)
  ),
  summaryUnitSource.tsv = list(
    file = summaryUnitSourceFile, key = c(pairKey, "unit_source"),
    columns = c("TEST_NAME", "MEASUREMENT_UNIT", "unit_source", "n_records", "n_subjects"),
    counts = c("n_records", "n_subjects"), numbers = character(0)
  ),
  summaryValuesSource.tsv = list(
    file = summaryValuesSourceFile, key = c(pairKey, "value_source"),
    columns = c("TEST_NAME", "MEASUREMENT_UNIT", "value_source", "n_records", "n_subjects"),
    counts = c("n_records", "n_subjects"), numbers = character(0)
  ),
  summaryValues.tsv = list(
    file = summaryValuesFile, key = c(pairKey, "decile"),
    columns = c("TEST_NAME", "MEASUREMENT_UNIT", "n_subjects", "n_records", "decile", "decile_MEASUREMENT_VALUE"),
    counts = c("n_records", "n_subjects"), numbers = c("decile_MEASUREMENT_VALUE")
  ),
  summaryReference.tsv = list(
    file = summaryReferenceFile, key = c(pairKey, "DEMOGRAPHICS_BIN"),
    columns = c(
      "TEST_NAME", "MEASUREMENT_UNIT", "DEMOGRAPHICS_BIN", "REFERENCE_RANGE_LOW_MEAN", "REFERENCE_RANGE_HIGH_MEAN",
      "n_records", "n_subjects"
    ),
    counts = c("n_records", "n_subjects"), numbers = c("REFERENCE_RANGE_LOW_MEAN", "REFERENCE_RANGE_HIGH_MEAN")
  ),
  summaryOutcomes.tsv = list(
    file = summaryOutcomesFile, key = c(pairKey, "TEST_OUTCOME"),
    columns = c("TEST_NAME", "MEASUREMENT_UNIT", "TEST_OUTCOME", "n_TEST_OUTCOME", "n_subjects"),
    counts = c("n_TEST_OUTCOME", "n_subjects"), numbers = character(0)
  )
)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
for (name in names(tableSpecs)) ParallelLogger::logInfo("  ", name, " = ", tableSpecs[[name]]$file)
ParallelLogger::logInfo("  settingsFile = ", settingsFile, " (n_records_no_value_threshold = ", minValues, ", n_subjects_no_value_threshold = ", minSubjects, ")")
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
# Every column is read as text, so the tests see the values as they are in the file.
tables <- lapply(tableSpecs, function(spec) {
  readr::read_tsv(spec$file, col_types = readr::cols(.default = readr::col_character()), na = "")
})
for (name in names(tables)) ParallelLogger::logInfo("Read ", nrow(tables[[name]]), " rows from ", tableSpecs[[name]]$file)

#
# --- Action -------------------------------------------------------------
#
results <- list()
# Records one test. `bad` flags the failing rows; `what` names the columns shown as examples.
record <- function(table, test, bad, df = NULL, what = NULL, level = "ERROR") {
  bad[is.na(bad)] <- TRUE
  message <- ""
  if (any(bad) && !is.null(df) && !is.null(what)) {
    rows <- df[bad, what, drop = FALSE]
    examples <- unique(apply(rows, 1, function(r) paste0(what, "=", ifelse(is.na(r), "", r), collapse = " ")))
    message <- paste0("e.g. ", paste(utils::head(examples, 3), collapse = "; "))
  }
  results[[length(results) + 1]] <<- tibble::tibble(
    table = table,
    result = if (any(bad)) level else "SUCCESS",
    test = test,
    n_rows = if (any(bad)) format(sum(bad), big.mark = ",", trim = TRUE) else "",
    message = message
  )
}
asNumber <- function(x) suppressWarnings(as.numeric(x))

summaryTest <- tables$summaryTest.tsv
testPairs <- dplyr::distinct(summaryTest, dplyr::across(dplyr::all_of(pairKey)))

# Tests every table shares.
for (name in names(tableSpecs)) {
  spec <- tableSpecs[[name]]
  df <- tables[[name]]
  record(name, paste0("columns are ", paste(spec$columns, collapse = ", ")), !identical(names(df), spec$columns))
  if (!identical(names(df), spec$columns)) next
  record(name, "TEST_NAME has a value", is.na(df$TEST_NAME), df, pairKey)
  record(name, paste0(paste(spec$key, collapse = " + "), " are unique"), duplicated(df[spec$key]), df, spec$key)
  for (col in spec$counts) {
    x <- asNumber(df[[col]])
    record(name, paste0(col, " is a whole number above 0"), is.na(x) | x <= 0 | x != round(x), df, c(pairKey, col))
  }
  for (col in spec$numbers) {
    record(name, paste0(col, " is a number"), !is.na(df[[col]]) & is.na(asNumber(df[[col]])), df, c(pairKey, col))
  }
  record(
    name, paste0("n_subjects is above ", maxRemovedSubjects, " (small counts are removed)"),
    asNumber(df$n_subjects) <= maxRemovedSubjects, df, c(pairKey, "n_subjects")
  )
  recordsColumn <- intersect(c("n_records", "n_TEST_OUTCOME"), names(df))[1]
  record(
    name, paste0(recordsColumn, " is at least n_subjects"),
    asNumber(df[[recordsColumn]]) < asNumber(df$n_subjects), df, c(pairKey, recordsColumn, "n_subjects")
  )
  if (name != "summaryTest.tsv") {
    record(
      name, "every TEST_NAME + MEASUREMENT_UNIT is in summaryTest.tsv",
      is.na(match(paste(df$TEST_NAME, df$MEASUREMENT_UNIT), paste(testPairs$TEST_NAME, testPairs$MEASUREMENT_UNIT))),
      df, pairKey
    )
  }
}

# The share tables: their labels, and their records add up to no more than the pair's records
# (rows with few subjects are removed upstream, so they can add up to less).
checkShares <- function(name, labelColumn, labels) {
  df <- tables[[name]]
  if (!identical(names(df), tableSpecs[[name]]$columns)) return(invisible())
  record(name, paste0(labelColumn, " is one of ", paste(labels, collapse = ", ")), !(df[[labelColumn]] %in% labels), df, c(pairKey, labelColumn))
  sums <- df |>
    dplyr::summarise(n_records_sum = sum(asNumber(n_records)), .by = dplyr::all_of(pairKey)) |>
    dplyr::inner_join(summaryTest |> dplyr::transmute(TEST_NAME, MEASUREMENT_UNIT, n_records = asNumber(n_records)), by = pairKey)
  record(
    name, "the n_records of a pair add up to no more than its n_records in summaryTest.tsv",
    sums$n_records_sum > sums$n_records, sums, c(pairKey, "n_records_sum", "n_records")
  )
}
checkShares("summaryUnitSource.tsv", "unit_source", unitSources)
checkShares("summaryValuesSource.tsv", "value_source", valueSources)

# summaryValues.tsv: the nine deciles of each pair, in order.
values <- tables$summaryValues.tsv
if (identical(names(values), tableSpecs$summaryValues.tsv$columns)) {
  record("summaryValues.tsv", paste0("decile is one of ", paste(deciles, collapse = ", ")), !(values$decile %in% deciles), values, c(pairKey, "decile"))
  perPair <- values |>
    dplyr::mutate(decileNumber = asNumber(decile), value = asNumber(decile_MEASUREMENT_VALUE)) |>
    dplyr::arrange(TEST_NAME, MEASUREMENT_UNIT, decileNumber) |>
    dplyr::summarise(
      n_deciles = dplyr::n(),
      decreasing = any(diff(value) < 0, na.rm = TRUE),
      .by = dplyr::all_of(pairKey)
    )
  record("summaryValues.tsv", "every pair has the 9 deciles", perPair$n_deciles != length(deciles), perPair, c(pairKey, "n_deciles"))
  record("summaryValues.tsv", "the deciles of a pair do not decrease", perPair$decreasing, perPair, pairKey)
  # A pair with enough values (the records of summaryValuesSource.tsv, which all have a value) and enough
  # subjects (summaryTest.tsv) needs its deciles: without them its values cannot be harmonised or compared.
  withValues <- tables$summaryValuesSource.tsv |>
    dplyr::summarise(n_values = sum(asNumber(n_records)), .by = dplyr::all_of(pairKey)) |>
    dplyr::inner_join(summaryTest |> dplyr::transmute(TEST_NAME, MEASUREMENT_UNIT, n_subjects = asNumber(n_subjects)), by = pairKey) |>
    dplyr::filter(n_values >= minValues, n_subjects >= minSubjects)
  noDeciles <- dplyr::anti_join(withValues, dplyr::distinct(values, dplyr::across(dplyr::all_of(pairKey))), by = pairKey)
  record(
    "summaryValues.tsv", paste0(
      "every pair with at least ", minValues, " values (summaryValuesSource.tsv) and ", minSubjects,
      " subjects (summaryTest.tsv) has its deciles"
    ),
    rep(TRUE, nrow(noDeciles)), noDeciles, pairKey
  )
}

# summaryReference.tsv: the bins, and a low limit that is not above the high one.
reference <- tables$summaryReference.tsv
if (identical(names(reference), tableSpecs$summaryReference.tsv$columns)) {
  record(
    "summaryReference.tsv", paste0("DEMOGRAPHICS_BIN is one of ", paste(demographicsBins, collapse = ", ")),
    !(reference$DEMOGRAPHICS_BIN %in% demographicsBins), reference, c(pairKey, "DEMOGRAPHICS_BIN")
  )
  record(
    "summaryReference.tsv", "REFERENCE_RANGE_LOW_MEAN is not above REFERENCE_RANGE_HIGH_MEAN",
    dplyr::coalesce(asNumber(reference$REFERENCE_RANGE_LOW_MEAN) > asNumber(reference$REFERENCE_RANGE_HIGH_MEAN), FALSE),
    reference, c(pairKey, "DEMOGRAPHICS_BIN", "REFERENCE_RANGE_LOW_MEAN", "REFERENCE_RANGE_HIGH_MEAN"),
    level = "WARNING"
  )
}

results <- dplyr::bind_rows(results) |>
  dplyr::arrange(factor(table, levels = names(tableSpecs)))
nError <- sum(results$result == "ERROR")
ParallelLogger::logInfo(
  nrow(results), " tests: ", sum(results$result == "SUCCESS"), " SUCCESS, ",
  sum(results$result == "WARNING"), " WARNING, ", nError, " ERROR"
)
for (i in which(results$result != "SUCCESS")) {
  ParallelLogger::logWarn(results$result[i], ": ", results$table[i], ": ", results$test[i], ": ", results$n_rows[i], " rows, ", results$message[i])
}

#
# --- Output -------------------------------------------------------------
#
cell <- function(x) gsub("\\|", "\\\\|", x)
countResults <- function(df) {
  c(SUCCESS = sum(df$result == "SUCCESS"), WARNING = sum(df$result == "WARNING"), ERROR = sum(df$result == "ERROR"))
}
summaryByTable <- do.call(rbind, lapply(unique(results$table), function(tbl) c(table = tbl, countResults(results[results$table == tbl, ]))))
summaryTable <- rbind(summaryByTable, c(table = "ALL", countResults(results)))

md <- c(
  "# kantaAgregatedTable validation",
  "",
  "Validation of the input tables of `1_BuildKantaAgregatedTable` (`DATA/1_Input/0_KantaAgregatedData/`). ",
  "The step stops when a test is an ERROR.",
  "",
  "## Validation summary",
  "",
  "| table | SUCCESS | WARNING | ERROR |",
  "| --- | --- | --- | --- |",
  apply(summaryTable, 1, function(row) paste0("| ", paste(cell(row), collapse = " | "), " |")),
  "",
  "## Tests",
  "",
  "| table | result | test | n rows | message |",
  "| --- | --- | --- | ---: | --- |",
  paste0("| ", cell(results$table), " | ", results$result, " | ", cell(results$test), " | ", results$n_rows, " | ", cell(results$message), " |")
)
outFile <- file.path(outDir, "kantaAgregatedTable.validation.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)

if (nError > 0) {
  stop(nError, " validation tests failed, see ", outFile)
}
