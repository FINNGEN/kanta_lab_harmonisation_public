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
outDir <- args[5]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  summaryTestFile = ", summaryTestFile)
ParallelLogger::logInfo("  summaryUnitSourceFile = ", summaryUnitSourceFile)
ParallelLogger::logInfo("  summaryValuesSourceFile = ", summaryValuesSourceFile)
ParallelLogger::logInfo("  summaryValuesFile = ", summaryValuesFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
summaryTest <- readr::read_tsv(summaryTestFile, show_col_types = FALSE, na = "")
summaryValuesSource <- readr::read_tsv(summaryValuesSourceFile, show_col_types = FALSE, na = "")
summaryValues <- readr::read_tsv(summaryValuesFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(summaryTest), " rows from ", summaryTestFile)
ParallelLogger::logInfo("Read ", nrow(summaryValuesSource), " rows from ", summaryValuesSourceFile)
ParallelLogger::logInfo("Read ", nrow(summaryValues), " rows from ", summaryValuesFile)

# summaryUnitSource.tsv is optional -- run.sh passes "" when it does not exist
# for this SourceKantaData (e.g. a v3-converted one, which never had it).
# An empty table with the right columns makes every pair's unit_source
# breakdown fall out as 100% NA, with no special-casing needed downstream.
summaryUnitSource <- if (nzchar(summaryUnitSourceFile)) {
  readr::read_tsv(summaryUnitSourceFile, show_col_types = FALSE, na = "")
} else {
  ParallelLogger::logWarn("No summaryUnitSourceFile given -- unit_source_injection_correction_na_p will read as 100% NA for every pair")
  tibble::tibble(
    TEST_NAME = character(), MEASUREMENT_UNIT = character(),
    unit_source = character(), n_records = integer()
  )
}
ParallelLogger::logInfo("Read ", nrow(summaryUnitSource), " rows from ", if (nzchar(summaryUnitSourceFile)) summaryUnitSourceFile else "(none)")

#
# --- Action -------------------------------------------------------------
#

# Rounded to 2 decimals and printed without trailing zeros ("30" not "30.00",
# "5.05" stays "5.05"). Used for both the percentage columns and value_deciles.
fmtNum <- function(x) {
  s <- formatC(round(x, 2), format = "f", digits = 2)
  s <- sub("0+$", "", s)
  sub("\\.$", "", s)
}

# One row per TEST_NAME/UNIT, n = total records (the denominator every
# percentage below is taken against).
total <- summaryTest |>
  dplyr::transmute(TEST_NAME, UNIT = MEASUREMENT_UNIT, n = n_records)

# Drop the upstream's stringified missing test name (same case-sensitive,
# exact match as 2_AppendKnownInformation's own filter): records with no
# test name at all arrive as a TEST_NAME of literally "NA" (R's write.table
# default), one row per UNIT they happened to be grouped into. They are not a
# test and carry no information that could be mapped to a lab test. Matching
# case-sensitively matters -- lowercase "na" is a real code and must survive.
isMissingTestName <- total$TEST_NAME == "NA" & !is.na(total$TEST_NAME)
if (any(isMissingTestName)) {
  ParallelLogger::logWarn(
    "Dropping ", sum(isMissingTestName), " row(s) whose TEST_NAME is the literal text \"NA\" ",
    "(the upstream extract's stringified missing value), covering ",
    format(sum(total$n[isMissingTestName]), big.mark = ","),
    " records with no recorded test name"
  )
  total <- total[!isMissingTestName, ]
}

# Widen a long TEST_NAME/UNIT/<labelCol>/n_records table into one row per
# TEST_NAME/UNIT, one column per label in `expectedLabels`. A TEST_NAME/UNIT
# absent from `df` altogether (no record of this kind at all) gets no row
# here -- the caller's left_join + replace_na(0) turns that absence into a
# real 0, which is what makes the "NA" bucket (n minus every known label)
# work out to n itself for those pairs. `df` can have zero rows (no source
# table at all, e.g. no summaryUnitSource.tsv) -- pivot_wider would then
# create no label columns, so any of `expectedLabels` still missing after it
# is added back as all-0.
widenSourceCounts <- function(df, labelCol, expectedLabels) {
  wide <- df |>
    dplyr::rename(UNIT = MEASUREMENT_UNIT) |>
    dplyr::select(TEST_NAME, UNIT, label = dplyr::all_of(labelCol), n_records) |>
    tidyr::pivot_wider(names_from = label, values_from = n_records, values_fill = 0)
  for (lab in setdiff(expectedLabels, names(wide))) wide[[lab]] <- 0
  wide
}

# unit_source: labels are Source (the unit as recorded) / PrimaryInjection
# ("injection") / SecondaryCorrection ("correction"), in that order, then
# "na". Records with none of the three (the TEST_NAME/UNIT pair is missing
# from summaryUnitSource.tsv entirely, or covered by fewer records than
# summaryTest counts) are the "na" bucket: n minus every labeled record.
unitSourceWide <- widenSourceCounts(summaryUnitSource, "unit_source", c("Source", "PrimaryInjection", "SecondaryCorrection"))
unitSource <- total |>
  dplyr::left_join(unitSourceWide, by = c("TEST_NAME", "UNIT")) |>
  dplyr::mutate(dplyr::across(c(Source, PrimaryInjection, SecondaryCorrection), ~ tidyr::replace_na(.x, 0))) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    unit_na = n - (Source + PrimaryInjection + SecondaryCorrection),
    unit_source_injection_correction_na_p = sprintf(
      "[%s,%s,%s,%s]%%",
      fmtNum(100 * Source / n),
      fmtNum(100 * PrimaryInjection / n),
      fmtNum(100 * SecondaryCorrection / n),
      fmtNum(100 * unit_na / n)
    )
  )

# value_source: labels are Source (unmodified value) / Extracted ("extracted",
# a value only recovered from free text) / QCOut ("qcout", failed QC), in that
# order, then "na". Same residual logic: n minus every labeled record is
# "na" -- a record with no usable value at all.
valueSourceWide <- widenSourceCounts(summaryValuesSource, "value_source", c("Source", "Extracted", "QCOut"))
valueSource <- total |>
  dplyr::left_join(valueSourceWide, by = c("TEST_NAME", "UNIT")) |>
  dplyr::mutate(dplyr::across(c(Source, Extracted, QCOut), ~ tidyr::replace_na(.x, 0))) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    value_na = n - (Source + Extracted + QCOut),
    value_missing_p = fmtNum(100 * value_na / n),
    value_source_extracted_qcout_na_p = sprintf(
      "[%s,%s,%s,%s]%%",
      fmtNum(100 * Source / n),
      fmtNum(100 * Extracted / n),
      fmtNum(100 * QCOut / n),
      fmtNum(100 * value_na / n)
    )
  )

# value_deciles: the 9 deciles (0.1 .. 0.9), in order, as "[d1, d2, ..., d9]".
# Only the higher-volume TEST_NAME/UNIT pairs get deciles computed upstream;
# the rest simply have no rows in summaryValues.tsv and are left NA (written
# as "" per development/STYLE.md) by the left_join below.
valueDeciles <- summaryValues |>
  dplyr::rename(UNIT = MEASUREMENT_UNIT) |>
  dplyr::arrange(TEST_NAME, UNIT, decile) |>
  dplyr::group_by(TEST_NAME, UNIT) |>
  dplyr::summarise(
    value_deciles = paste0("[", paste(fmtNum(decile_MEASUREMENT_VALUE), collapse = ", "), "]"),
    .groups = "drop"
  )

result <- total |>
  dplyr::left_join(unitSource |> dplyr::select(-unit_na), by = c("TEST_NAME", "UNIT")) |>
  dplyr::left_join(valueSource |> dplyr::select(-value_na), by = c("TEST_NAME", "UNIT")) |>
  dplyr::left_join(valueDeciles, by = c("TEST_NAME", "UNIT")) |>
  dplyr::arrange(TEST_NAME, UNIT) |>
  dplyr::select(
    TEST_NAME, UNIT, n,
    unit_source_injection_correction_na_p,
    value_missing_p,
    value_source_extracted_qcout_na_p,
    value_deciles
  )

ParallelLogger::logInfo(nrow(result), " TEST_NAME/UNIT pairs written")
ParallelLogger::logInfo(sum(!is.na(result$value_deciles)), " of them carry a value_deciles distribution")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "labSummary.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
