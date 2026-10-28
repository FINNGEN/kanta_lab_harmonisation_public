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

# 3. Append the LOINC Groups, only group_concept_id, group_concept_code and
#    group_concept_name. A concept can be in several Groups; they are joined with ";"
#    (in the same order in the three columns) so the table keeps one row per pair.
groupsPerConcept <- loincGroupMembership |>
  dplyr::arrange(concept_id, n_descendants, group_concept_code) |>
  dplyr::summarise(
    group_concept_id = paste(group_concept_id, collapse = ";"),
    group_concept_code = paste(group_concept_code, collapse = ";"),
    group_concept_name = paste(group_concept_name, collapse = ";"),
    .by = concept_id
  )
result <- result |>
  dplyr::left_join(groupsPerConcept, by = "concept_id")

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
    concept_id, ignore_mapping_reason, APPROVED,
    concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    group_concept_id, group_concept_code, group_concept_name,
    HARMONISED_UNIT, CONVERSION
  ) |>
  dplyr::arrange(TEST_NAME, PREPROCESED_UNIT, UNIT)

# 6. Message: explains the error or warning of a row. A has_property + UNIT without a rule in
#    quantity_source_unit_conversion.tsv means the property of the concept does not agree
#    with the unit: an ERROR if the mapping is APPROVED, otherwise a WARNING.
knownPropertyUnit <- paste(quantitySourceUnitConversion$has_property, quantitySourceUnitConversion$UNIT, sep = "\r")
propertyUnitUnknown <- !is.na(result$has_property) & !is.na(result$UNIT) &
  !(paste(result$has_property, result$UNIT, sep = "\r") %in% knownPropertyUnit)
result <- result |>
  dplyr::mutate(
    Message = dplyr::if_else(
      propertyUnitUnknown,
      paste0(
        dplyr::if_else(APPROVED, "ERROR", "WARNING"),
        ": has_property '", has_property, "' and UNIT '", UNIT,
        "' are not in quantity_source_unit_conversion.tsv: the property of the concept does not agree with the unit"
      ),
      NA_character_
    )
  )
nMessageError <- sum(startsWith(result$Message, "ERROR"), na.rm = TRUE)
nMessageWarning <- sum(startsWith(result$Message, "WARNING"), na.rm = TRUE)
ParallelLogger::logWarn(nMessageError, " rows with an ERROR message, ", nMessageWarning, " rows with a WARNING message")

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
