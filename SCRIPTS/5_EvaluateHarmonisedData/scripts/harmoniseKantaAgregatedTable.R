#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
kantaAgregatedTableFile <- args[1]
harmonisationTableFile <- args[2]
outDir <- args[3]

pathToHarmonisedTSV <- file.path(outDir, "harmonisedKantaAgregatedTable.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  kantaAgregatedTableFile = ", kantaAgregatedTableFile)
ParallelLogger::logInfo("  harmonisationTableFile = ", harmonisationTableFile)
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
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = readr::col_character(),
    decile = readr::col_double(),
    decile_value = readr::col_double()
  ),
  na = ""
)
# The unit of the Kanta table is the one that arrives after the preprocessing: the
# PREPROCESED_UNIT of the harmonisation table.
kantaAgregatedTable <- kantaAgregatedTable |>
  dplyr::rename(PREPROCESED_UNIT = MEASUREMENT_UNIT)
ParallelLogger::logInfo("Read ", nrow(kantaAgregatedTable), " rows from ", kantaAgregatedTableFile)

harmonisationTable <- readr::read_tsv(
  harmonisationTableFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    PREPROCESED_UNIT = readr::col_character(),
    UNIT = readr::col_character(),
    unit_fix_reasoning = readr::col_character(),
    concept_id = readr::col_integer(),
    ignore_mapping_reason = readr::col_character(),
    mapping_status = readr::col_character(),
    concept_code = readr::col_character(),
    concept_name = readr::col_character(),
    vocabulary_id = readr::col_character(),
    is_panel = readr::col_logical(),
    has_component = readr::col_character(),
    has_property = readr::col_character(),
    group_concept_id = readr::col_character(),
    group_concept_code = readr::col_character(),
    group_concept_name = readr::col_character(),
    target_unit = readr::col_character(),
    target_unit_source = readr::col_character(),
    HARMONISED_UNIT = readr::col_character(),
    CONVERSION = readr::col_character(),
    mapping_warning_messages = readr::col_character()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(harmonisationTable), " rows from ", harmonisationTableFile)

#
# --- Action -------------------------------------------------------------
#

# 1. Join the harmonisation table on TEST_NAME + PREPROCESED_UNIT, the key of both tables. The
#    table adds the UNIT (the unit after the fix) and the rest of its columns.
stopifnot(!anyDuplicated(harmonisationTable[c("TEST_NAME", "PREPROCESED_UNIT")]))

harmonised <- kantaAgregatedTable |>
  dplyr::left_join(harmonisationTable, by = c("TEST_NAME", "PREPROCESED_UNIT")) |>
  dplyr::relocate(UNIT, .after = PREPROCESED_UNIT) |>
  dplyr::mutate(mapping_status = dplyr::coalesce(mapping_status, "MISSING")) |>
  dplyr::relocate(mapping_status)

pairs <- dplyr::distinct(harmonised, TEST_NAME, PREPROCESED_UNIT, concept_id)
ParallelLogger::logInfo(
  nrow(pairs), " TEST_NAME + PREPROCESED_UNIT pairs, ", sum(is.na(pairs$concept_id)),
  " not in the harmonisation table"
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
nBadConversion <- harmonised |>
  dplyr::filter(!is.na(CONVERSION), is.na(suppressWarnings(as.numeric(CONVERSION))), !grepl("^[0-9eE.+*/() X-]+$", CONVERSION)) |>
  dplyr::distinct(CONVERSION) |>
  nrow()
if (nBadConversion > 0) {
  ParallelLogger::logWarn(nBadConversion, " CONVERSION values are not a number or a formula in X: left missing")
}

harmonised <- harmonised |>
  dplyr::mutate(
    decile_value_harmonised = applyConversion(CONVERSION, decile_value),
    .after = decile_value
  )

withValue <- !is.na(harmonised$decile_value)
ParallelLogger::logInfo(
  sum(withValue), " decile values, ", sum(!is.na(harmonised$decile_value_harmonised)),
  " harmonised (", sum(withValue & is.na(harmonised$CONVERSION)), " without a CONVERSION)"
)

# 3. Sorted by n from largest to smallest; the rows of a pair stay together and in decile order.
harmonised <- harmonised |>
  dplyr::arrange(dplyr::desc(n), TEST_NAME, PREPROCESED_UNIT, decile)

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(harmonised, pathToHarmonisedTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(harmonised), " rows to ", pathToHarmonisedTSV)
