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
summaryUnitSource <- readr::read_tsv(summaryUnitSourceFile, show_col_types = FALSE, na = "")
summaryValuesSource <- readr::read_tsv(summaryValuesSourceFile, show_col_types = FALSE, na = "")
summaryValues <- readr::read_tsv(summaryValuesFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(summaryTest), " rows from ", summaryTestFile)
ParallelLogger::logInfo("Read ", nrow(summaryUnitSource), " rows from ", summaryUnitSourceFile)
ParallelLogger::logInfo("Read ", nrow(summaryValuesSource), " rows from ", summaryValuesSourceFile)
ParallelLogger::logInfo("Read ", nrow(summaryValues), " rows from ", summaryValuesFile)

#
# --- Action -------------------------------------------------------------
#

# Rounded to 2 decimals and printed without trailing zeros ("30" not "30.00").
fmtNum <- function(x) {
  s <- formatC(round(x, 2), format = "f", digits = 2)
  s <- sub("0+$", "", s)
  sub("\\.$", "", s)
}

# One row per TEST_NAME/UNIT, n = total records (the denominator every
# percentage below is taken against).
total <- summaryTest |>
  dplyr::transmute(TEST_NAME, UNIT = MEASUREMENT_UNIT, n = n_records)

# Drop the upstream's stringified missing test name: records with no test name
# arrive as a TEST_NAME of literally "NA". Case-sensitive, lowercase "na" is a
# real code and must survive.
isMissingTestName <- total$TEST_NAME == "NA" & !is.na(total$TEST_NAME)
if (any(isMissingTestName)) {
  ParallelLogger::logWarn(
    "Dropping ", sum(isMissingTestName), " row(s) whose TEST_NAME is the literal text \"NA\", covering ",
    format(sum(total$n[isMissingTestName]), big.mark = ","), " records"
  )
  total <- total[!isMissingTestName, ]
}

# Widen a long TEST_NAME/UNIT/<labelCol>/n_records table into one row per
# TEST_NAME/UNIT with one column per label. A pair absent from `df` gets no
# row here; the caller's left_join + replace_na(0) turns that into a real 0.
widenSourceCounts <- function(df, labelCol, expectedLabels) {
  wide <- df |>
    dplyr::rename(UNIT = MEASUREMENT_UNIT) |>
    dplyr::select(TEST_NAME, UNIT, label = dplyr::all_of(labelCol), n_records) |>
    tidyr::pivot_wider(names_from = label, values_from = n_records, values_fill = 0)
  for (lab in setdiff(expectedLabels, names(wide))) wide[[lab]] <- 0
  wide
}

# unit_source: Source / PrimaryInjection / SecondaryCorrection, then "na" =
# n minus every labeled record.
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

# value_source: Source / Extracted / QCOut, then "na" = n minus every labeled
# record, i.e. a record with no usable value at all.
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

# Deciles stay long: one row per pair and decile (0.1 .. 0.9). Pairs with no
# deciles upstream keep one row with an empty decile / decile_value.
valueDeciles <- summaryValues |>
  dplyr::transmute(
    TEST_NAME, UNIT = MEASUREMENT_UNIT, decile,
    decile_value = decile_MEASUREMENT_VALUE
  )

result <- total |>
  dplyr::left_join(unitSource |> dplyr::select(-unit_na), by = c("TEST_NAME", "UNIT")) |>
  dplyr::left_join(valueSource |> dplyr::select(-value_na), by = c("TEST_NAME", "UNIT")) |>
  dplyr::left_join(valueDeciles, by = c("TEST_NAME", "UNIT")) |>
  dplyr::arrange(TEST_NAME, UNIT, decile) |>
  dplyr::select(
    TEST_NAME, UNIT, n,
    unit_source_injection_correction_na_p,
    value_missing_p,
    value_source_extracted_qcout_na_p,
    decile, decile_value
  )

ParallelLogger::logInfo(dplyr::n_distinct(result$TEST_NAME, result$UNIT), " TEST_NAME/UNIT pairs")
ParallelLogger::logInfo(sum(!is.na(result$decile)), " decile rows")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "kantaSummaryData.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
