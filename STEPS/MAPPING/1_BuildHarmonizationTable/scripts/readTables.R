#
# --- Table specs -------------------------------------------------------------
#
# The column types of every table the step reads or writes, shared by
# buildHarmonizationTable.R and validateHarmonizationTable.R so both read a table
# the same way. CONVERSION is character because it can be a formula in X;
# ONLY_TO_OMOP_CONCEPTS is character because it can list several concept ids.
chr <- readr::col_character
int <- readr::col_integer
lgl <- readr::col_logical

tableSpecs <- list(
  unitFix = readr::cols(
    TEST_NAME = chr(), PREPROCESED_UNIT = chr(), UNIT = chr(),
    unit_fix_reasoning = chr(), INJECTION_NOTES = chr()
  ),
  units = readr::cols(
    UNIT = chr(), concept_id = int(), UNIQUE_FOR_LAB = lgl()
  ),
  testnameUnitToConceptid = readr::cols(
    TEST_NAME = chr(), UNIT = chr(), concept_id = int(), ignore_mapping_reason = chr()
  ),
  measurementConceptAttributes = readr::cols(
    concept_id = int(), concept_code = chr(), concept_name = chr(), vocabulary_id = chr(),
    is_panel = lgl(), has_component = chr(), has_property = chr(), has_method = chr(),
    has_scale_type = chr(), has_system = chr(), has_time_aspect = chr()
  ),
  loincGroupMembership = readr::cols(
    concept_id = int(), group_concept_id = int(), group_concept_code = chr(),
    group_concept_name = chr(), n_descendants = int(), is_parent_group = lgl()
  ),
  conceptidTargetUnit = readr::cols(
    concept_id = int(), HARMONISED_UNIT = chr()
  ),
  quantitySourceUnitConversion = readr::cols(
    has_property = chr(), UNIT = chr(), HARMONISED_UNIT = chr(), CONVERSION = chr(),
    ONLY_TO_OMOP_CONCEPTS = chr(), VALIDATION_MESSAGES = chr()
  ),
  harmonizationTable = readr::cols(
    TEST_NAME = chr(), PREPROCESED_UNIT = chr(), UNIT = chr(), unit_fix_reasoning = chr(),
    concept_id = int(), ignore_mapping_reason = chr(), concept_code = chr(), concept_name = chr(),
    vocabulary_id = chr(), is_panel = lgl(), has_component = chr(), has_property = chr(),
    has_method = chr(), has_scale_type = chr(), has_system = chr(), has_time_aspect = chr(),
    group_concept_id = int(), group_concept_code = chr(), group_concept_name = chr(),
    HARMONISED_UNIT = chr(), CONVERSION = chr()
  )
)

# Reads a TSV with the given col_types; "" is read as missing.
readTable <- function(file, colTypes) {
  tbl <- readr::read_tsv(file, col_types = colTypes, na = "")
  ParallelLogger::logInfo("Read ", nrow(tbl), " rows from ", file)
  tbl
}
