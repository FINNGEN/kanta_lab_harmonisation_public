#
# --- Table specs -------------------------------------------------------------
#
# The column types of every table the step reads or writes, shared by
# buildHarmonisationTable.R and validateHarmonisationTable.R so both read a table the same way. CONVERSION is
# character because it can be a formula in X; `context` is character because it is a
# LOINC property or a concept id.
chr <- readr::col_character
int <- readr::col_integer
lgl <- readr::col_logical

tableSpecs <- list(
  unitFix = readr::cols(
    TEST_NAME = chr(), MEASUREMENT_UNIT = chr(), UNIT = chr(),
    unit_fix_reasoning = chr(), INJECTION_NOTES = chr()
  ),
  mapping = readr::cols(
    TEST_NAME = chr(), UNIT = chr(), concept_id = int(), ignore_mapping_reason = chr(), APPROVED = lgl()
  ),
  unitHarmonisation = readr::cols(
    context = chr(), UNIT = chr(), HARMONISED_UNIT = chr(), CONVERSION = chr(), VALIDATION_MESSAGES = chr()
  ),
  targetTable = readr::cols(
    concept_id = int(), concept_code = chr(), concept_name = chr(), vocabulary_id = chr(),
    is_panel = lgl(), has_component = chr(), has_property = chr(), has_method = chr(),
    has_scale_type = chr(), has_system = chr(), has_time_aspect = chr(),
    group_concept_id = int(), group_concept_code = chr(), group_concept_name = chr(), group_source = chr(),
    harmonised_unit = chr(), harmonised_unit_source = chr()
  ),
  harmonisationTable = readr::cols(
    mapping_status = chr(), TEST_NAME = chr(), MEASUREMENT_UNIT = chr(), UNIT = chr(), unit_fix_reasoning = chr(),
    concept_id = int(), ignore_mapping_reason = chr(), concept_code = chr(), concept_name = chr(),
    vocabulary_id = chr(), is_panel = lgl(), has_component = chr(), has_property = chr(),
    group_concept_id = chr(), group_concept_code = chr(), group_concept_name = chr(),
    target_unit = chr(), target_unit_source = chr(),
    HARMONISED_UNIT = chr(), CONVERSION = chr(), mapping_warning_messages = chr()
  ),
  lab2cleanUnit = readr::cols(
    concept_id = int(), harmonised_unit = chr()
  ),
  unitOverwrite = readr::cols(
    concept_id = int(), harmonised_unit = chr(), note = chr()
  ),
  propertyMismatchWarning = readr::cols(
    TEST_NAME = chr(), UNIT = chr(), message = chr(), ignore = lgl()
  ),
  propertySharedWarning = readr::cols(
    TEST_NAME = chr(), has_property = chr(), message = chr(), ignore = lgl()
  ),
  contextUnitMissingWarning = readr::cols(
    TEST_NAME = chr(), UNIT = chr(), message = chr(), ignore = lgl()
  ),
  loincGroupUnitMismatchWarning = readr::cols(
    TEST_NAME = chr(), UNIT = chr(), message = chr(), ignore = lgl()
  )
)

# Reads a TSV with the given col_types; "" is read as missing.
readTable <- function(file, colTypes) {
  tbl <- readr::read_tsv(file, col_types = colTypes, na = "")
  ParallelLogger::logInfo("Read ", nrow(tbl), " rows from ", file)
  tbl
}
