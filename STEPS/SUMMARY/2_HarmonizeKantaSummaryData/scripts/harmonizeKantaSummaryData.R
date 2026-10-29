#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
kantaSummaryDataFile <- args[1]
harmonizationTableFile <- args[2]
outDir <- args[3]

pathToHarmonizedTSV <- file.path(outDir, "harmonizedKantaSummaryData.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  kantaSummaryDataFile = ", kantaSummaryDataFile)
ParallelLogger::logInfo("  harmonizationTableFile = ", harmonizationTableFile)
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

harmonizationTable <- readr::read_tsv(
  harmonizationTableFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    PREPROCESED_UNIT = readr::col_character(),
    UNIT = readr::col_character(),
    unit_fix_reasoning = readr::col_character(),
    concept_id = readr::col_integer(),
    ignore_mapping_reason = readr::col_character(),
    APPROVED = readr::col_logical(),
    concept_code = readr::col_character(),
    concept_name = readr::col_character(),
    vocabulary_id = readr::col_character(),
    is_panel = readr::col_logical(),
    has_component = readr::col_character(),
    has_property = readr::col_character(),
    has_method = readr::col_character(),
    has_scale_type = readr::col_character(),
    has_system = readr::col_character(),
    has_time_aspect = readr::col_character(),
    group_concept_id = readr::col_character(),
    group_concept_code = readr::col_character(),
    group_concept_name = readr::col_character(),
    HARMONISED_UNIT = readr::col_character(),
    CONVERSION = readr::col_character()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(harmonizationTable), " rows from ", harmonizationTableFile)

#
# --- Action -------------------------------------------------------------
#

# 1. Join the harmonization table on TEST_NAME + UNIT. The UNIT of the summary data is the
#    unit after the fix, the UNIT of the harmonization table. A UNIT fixed from several
#    PREPROCESED_UNITs takes several rows of the table that differ only in the columns
#    dropped here, so a pair joins once.
harmonizationByUnit <- harmonizationTable |>
  dplyr::select(-PREPROCESED_UNIT, -unit_fix_reasoning) |>
  dplyr::distinct()
stopifnot(!anyDuplicated(harmonizationByUnit[c("TEST_NAME", "UNIT")]))

harmonized <- kantaSummaryData |>
  dplyr::left_join(harmonizationByUnit, by = c("TEST_NAME", "UNIT"))

pairs <- dplyr::distinct(harmonized, TEST_NAME, UNIT, concept_id)
ParallelLogger::logInfo(
  nrow(pairs), " TEST_NAME + UNIT pairs, ", sum(is.na(pairs$concept_id)),
  " not in the harmonization table"
)

# 2. decile_value_harmonised = CONVERSION applied to decile_value. CONVERSION is a factor or
#    a formula in X (the value), e.g. 0.703*X+0. Without a CONVERSION (or a decile_value)
#    it is missing. Only a number or a formula of numbers, X and + - * / ( ) is evaluated.
applyConversion <- function(conversion, value) {
  formulaOk <- grepl("^[0-9eE.+*/() X-]+$", conversion)
  asNumber <- suppressWarnings(as.numeric(conversion))
  out <- rep(NA_real_, length(value))
  isNumber <- !is.na(asNumber)
  out[isNumber] <- value[isNumber] * asNumber[isNumber]
  for (f in unique(conversion[!isNumber & formulaOk])) {
    rows <- which(!isNumber & formulaOk & conversion == f)
    out[rows] <- eval(parse(text = f), list(X = value[rows]))
  }
  out
}
nBadConversion <- harmonized |>
  dplyr::filter(!is.na(CONVERSION), is.na(suppressWarnings(as.numeric(CONVERSION))), !grepl("^[0-9eE.+*/() X-]+$", CONVERSION)) |>
  dplyr::distinct(CONVERSION) |>
  nrow()
if (nBadConversion > 0) {
  ParallelLogger::logWarn(nBadConversion, " CONVERSION values are not a number or a formula in X: left missing")
}

harmonized <- harmonized |>
  dplyr::mutate(
    decile_value_harmonised = applyConversion(CONVERSION, decile_value),
    .after = decile_value
  )

withValue <- !is.na(harmonized$decile_value)
ParallelLogger::logInfo(
  sum(withValue), " decile values, ", sum(!is.na(harmonized$decile_value_harmonised)),
  " harmonised (", sum(withValue & is.na(harmonized$CONVERSION)), " without a CONVERSION)"
)

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(harmonized, pathToHarmonizedTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(harmonized), " rows to ", pathToHarmonizedTSV)
