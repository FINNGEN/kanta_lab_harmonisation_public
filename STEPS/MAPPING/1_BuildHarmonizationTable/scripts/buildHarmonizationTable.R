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

# 6. The warnings go to their own tables (written below), not into this table. Each has a
#    message with the details and an `ignore` flag, set to TRUE by hand to accept the
#    warning. They are only edited when a warning appears or goes away (syncWarnings).
#    - testname_unit_property_missmatch_warning.tsv, one row per TEST_NAME + UNIT: a
#      has_property + UNIT without a rule in quantity_source_unit_conversion.tsv, so the
#      property of the concept does not agree with the unit.
#    - testname_property_shared_warning.tsv, one row per TEST_NAME + has_property: the
#      TEST_NAME maps to more than one concept_id with the same has_property (e.g. the
#      same analyte in blood and in urine). Ignored rows and rows without a concept
#      are not checked.
# Brings a warning table up to date and writes it only if something changed: a warning that
# is not in the file yet is added (ignore FALSE), a warning that is gone is removed, and a
# warning already in the file is left as it is. A warning is the key plus its message, so a
# changed message is a new warning (ignore FALSE again). Sorted by the key.
syncWarnings <- function(warnings, file, spec, keys) {
  warnings <- warnings |>
    dplyr::mutate(ignore = FALSE) |>
    dplyr::arrange(dplyr::across(dplyr::all_of(keys)))
  previous <- if (file.exists(file)) readTable(file, spec) else NULL
  if (!is.null(previous)) {
    warnings <- warnings |>
      dplyr::left_join(
        previous |> dplyr::select(dplyr::all_of(keys), message, previous_ignore = ignore),
        by = c(keys, "message")
      ) |>
      dplyr::mutate(ignore = dplyr::coalesce(previous_ignore, FALSE), previous_ignore = NULL)
    nAdded <- nrow(dplyr::anti_join(warnings, previous, by = c(keys, "message")))
    nRemoved <- nrow(dplyr::anti_join(previous, warnings, by = c(keys, "message")))
  } else {
    nAdded <- nrow(warnings)
    nRemoved <- 0L
  }
  unchanged <- !is.null(previous) && identical(as.data.frame(warnings), as.data.frame(previous))
  if (unchanged) {
    ParallelLogger::logInfo("Unchanged ", file, " (", nrow(warnings), " rows)")
  } else {
    readr::write_tsv(warnings, file, na = "")
    ParallelLogger::logInfo(
      "Wrote ", nrow(warnings), " rows to ", file, " (", nAdded, " added, ", nRemoved, " removed)"
    )
  }
  warnings
}

knownPropertyUnit <- paste(quantitySourceUnitConversion$has_property, quantitySourceUnitConversion$UNIT, sep = "\r")
propertyMismatchFile <- file.path(outDir, "testname_unit_property_missmatch_warning.tsv")
propertyMismatch <- result |>
  dplyr::filter(
    !is.na(has_property), !is.na(UNIT),
    !(paste(has_property, UNIT, sep = "\r") %in% knownPropertyUnit)
  ) |>
  dplyr::distinct(TEST_NAME, UNIT, has_property) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    message = paste0(
      "has_property '", has_property, "' and UNIT '", UNIT,
      "' are not in quantity_source_unit_conversion.tsv: the property of the concept does not agree with the unit"
    )
  ) |>
  syncWarnings(propertyMismatchFile, tableSpecs$propertyMismatchWarning, c("TEST_NAME", "UNIT"))

propertySharedFile <- file.path(outDir, "testname_property_shared_warning.tsv")
propertyShared <- result |>
  dplyr::filter(is.na(ignore_mapping_reason), !is.na(concept_name)) |>
  dplyr::distinct(TEST_NAME, has_property, concept_id, concept_name) |>
  dplyr::arrange(TEST_NAME, has_property, concept_id) |>
  dplyr::summarise(
    n_concepts = dplyr::n(),
    concepts = paste0(concept_id, " (", concept_name, ")", collapse = " | "),
    .by = c(TEST_NAME, has_property)
  ) |>
  dplyr::filter(n_concepts > 1) |>
  dplyr::transmute(
    TEST_NAME, has_property,
    message = paste0(
      "a TEST_NAME with the same has_property maps to one concept_id, but has_property '",
      tidyr::replace_na(has_property, ""), "' maps to different concept ids: ", concepts
    )
  ) |>
  syncWarnings(propertySharedFile, tableSpecs$propertySharedWarning, c("TEST_NAME", "has_property"))

ParallelLogger::logWarn(
  nrow(propertyMismatch), " TEST_NAME + UNIT with a property mismatch (", sum(propertyMismatch$ignore), " ignored), ",
  nrow(propertyShared), " TEST_NAME + has_property shared by several concept_ids (", sum(propertyShared$ignore), " ignored)"
)

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
