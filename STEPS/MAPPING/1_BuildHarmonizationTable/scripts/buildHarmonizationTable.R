#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

# the column types shared with validateHarmonizationTable.R
scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(scriptDir, "readTables.R"))

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
unitFixFile <- args[1]
testnameUnitToConceptidFile <- args[2]
measurementConceptAttributesFile <- args[3]
loincGroupMembershipFile <- args[4]
conceptidTargetUnitFile <- args[5]
quantitySourceUnitConversionFile <- args[6]
outDir <- args[7]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  testnameUnitToConceptidFile = ", testnameUnitToConceptidFile)
ParallelLogger::logInfo("  measurementConceptAttributesFile = ", measurementConceptAttributesFile)
ParallelLogger::logInfo("  loincGroupMembershipFile = ", loincGroupMembershipFile)
ParallelLogger::logInfo("  conceptidTargetUnitFile = ", conceptidTargetUnitFile)
ParallelLogger::logInfo("  quantitySourceUnitConversionFile = ", quantitySourceUnitConversionFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
unitFix <- readTable(unitFixFile, tableSpecs$unitFix)
testnameUnitToConceptid <- readTable(testnameUnitToConceptidFile, tableSpecs$testnameUnitToConceptid)
measurementConceptAttributes <- readTable(measurementConceptAttributesFile, tableSpecs$measurementConceptAttributes)
loincGroupMembership <- readTable(loincGroupMembershipFile, tableSpecs$loincGroupMembership)
conceptidTargetUnit <- readTable(conceptidTargetUnitFile, tableSpecs$conceptidTargetUnit)
quantitySourceUnitConversion <- readTable(quantitySourceUnitConversionFile, tableSpecs$quantitySourceUnitConversion)

#
# --- Action -------------------------------------------------------------
#

# 1. Base: one row per TEST_NAME + UNIT with its concept_id, with the unit fix put
#    first. unit_fix.tsv is joined on TEST_NAME + UNIT; a pair that is not in it
#    keeps its UNIT as the PREPROCESED_UNIT. A UNIT fixed from several
#    PREPROCESED_UNITs takes one row per PREPROCESED_UNIT.
unitFixNotUsed <- dplyr::anti_join(unitFix, testnameUnitToConceptid, by = c("TEST_NAME", "UNIT"))
if (nrow(unitFixNotUsed) > 0) {
  ParallelLogger::logWarn(nrow(unitFixNotUsed), " unit_fix rows have a TEST_NAME + UNIT that is not in testname_unit_to_conceptid")
}
result <- testnameUnitToConceptid |>
  dplyr::left_join(
    unitFix |> dplyr::select(TEST_NAME, PREPROCESED_UNIT, UNIT, unit_fix_reasoning),
    by = c("TEST_NAME", "UNIT"),
    relationship = "one-to-many"
  ) |>
  dplyr::mutate(PREPROCESED_UNIT = dplyr::coalesce(PREPROCESED_UNIT, UNIT))

# 2. Append the measurement concept attributes by concept_id.
result <- result |>
  dplyr::left_join(measurementConceptAttributes, by = "concept_id")

# 3. Append the LOINC Group, only group_concept_id, group_concept_code and
#    group_concept_name. A concept belongs to several Groups, so this adds one row
#    per Group.
result <- result |>
  dplyr::left_join(
    loincGroupMembership |> dplyr::select(concept_id, group_concept_id, group_concept_code, group_concept_name),
    by = "concept_id",
    relationship = "many-to-many"
  )

# 4. Append the target unit by concept_id (one target unit per concept).
result <- result |>
  dplyr::left_join(conceptidTargetUnit, by = "concept_id")

# 5. Append the conversion by has_property + UNIT + HARMONISED_UNIT, keeping only
#    CONVERSION. A rule with no ONLY_TO_OMOP_CONCEPTS applies to any concept; a rule
#    with ONLY_TO_OMOP_CONCEPTS applies only to those concept_ids, and wins over the
#    general rule of the same keys.
conversion <- quantitySourceUnitConversion |>
  dplyr::transmute(
    has_property,
    UNIT,
    HARMONISED_UNIT,
    CONVERSION,
    ONLY_TO_OMOP_CONCEPTS
  )
conversionGeneral <- conversion |>
  dplyr::filter(is.na(ONLY_TO_OMOP_CONCEPTS)) |>
  dplyr::select(-ONLY_TO_OMOP_CONCEPTS)
conversionConcept <- conversion |>
  dplyr::filter(!is.na(ONLY_TO_OMOP_CONCEPTS)) |>
  tidyr::separate_longer_delim(ONLY_TO_OMOP_CONCEPTS, delim = ";") |>
  dplyr::transmute(
    has_property, UNIT, HARMONISED_UNIT,
    concept_id = as.integer(trimws(ONLY_TO_OMOP_CONCEPTS)),
    CONVERSION_CONCEPT = CONVERSION
  )
ParallelLogger::logInfo(
  nrow(conversionGeneral), " general conversion rules, ",
  nrow(conversionConcept), " concept-specific conversion rules"
)

result <- result |>
  dplyr::left_join(conversionGeneral, by = c("has_property", "UNIT", "HARMONISED_UNIT")) |>
  dplyr::left_join(conversionConcept, by = c("has_property", "UNIT", "HARMONISED_UNIT", "concept_id")) |>
  dplyr::mutate(CONVERSION = dplyr::coalesce(CONVERSION_CONCEPT, CONVERSION)) |>
  dplyr::select(
    TEST_NAME, PREPROCESED_UNIT, UNIT, unit_fix_reasoning,
    concept_id, ignore_mapping_reason,
    concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    group_concept_id, group_concept_code, group_concept_name,
    HARMONISED_UNIT, CONVERSION
  ) |>
  dplyr::arrange(TEST_NAME, PREPROCESED_UNIT, UNIT, group_concept_id)

nPairs <- nrow(dplyr::distinct(result, TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logInfo(nPairs, " TEST_NAME/PREPROCESED_UNIT/UNIT pairs in ", nrow(result), " rows")
ParallelLogger::logInfo(
  dplyr::n_distinct(result$TEST_NAME[is.na(result$concept_code)], result$PREPROCESED_UNIT[is.na(result$concept_code)], result$UNIT[is.na(result$concept_code)]),
  " pairs whose concept_id is not in measurement_concept_attributes"
)
# A HARMONISED_UNIT without a CONVERSION cannot be applied, so it is set to missing.
# It is cleared after the join above, which uses it as a key.
nNoConversion <- nrow(dplyr::distinct(result |> dplyr::filter(!is.na(HARMONISED_UNIT), is.na(CONVERSION)), TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logWarn(nNoConversion, " pairs have a HARMONISED_UNIT but no CONVERSION: HARMONISED_UNIT set to empty")
result <- result |>
  dplyr::mutate(HARMONISED_UNIT = dplyr::if_else(is.na(CONVERSION), NA_character_, HARMONISED_UNIT))
nNoTarget <- nrow(dplyr::distinct(result |> dplyr::filter(is.na(HARMONISED_UNIT)), TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logWarn(nNoTarget, " pairs have no HARMONISED_UNIT")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "harmonizationTable.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
