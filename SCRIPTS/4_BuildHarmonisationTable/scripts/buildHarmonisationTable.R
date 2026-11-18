#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

# the column types shared with validateHarmonisationTable.R
scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(scriptDir, "readTables.R"))

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
unitFixFile <- args[1]
mappingFile <- args[2]
unitHarmonisationFile <- args[3]
targetTableFile <- args[4]
outDir <- args[5]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  mappingFile = ", mappingFile)
ParallelLogger::logInfo("  unitHarmonisationFile = ", unitHarmonisationFile)
ParallelLogger::logInfo("  targetTableFile = ", targetTableFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
unitFix <- readTable(unitFixFile, tableSpecs$unitFix)
mapping <- readTable(mappingFile, tableSpecs$mapping)
unitHarmonisation <- readTable(unitHarmonisationFile, tableSpecs$unitHarmonisation)
targetTable <- readTable(targetTableFile, tableSpecs$targetTable)

#
# --- Action -------------------------------------------------------------
#

# 1. Base: one row per TEST_NAME + UNIT with its concept_id, with the unit fix put
#    first. unitFix is joined on TEST_NAME + UNIT; a pair that is not in it keeps its
#    UNIT as the PREPROCESED_UNIT. A UNIT fixed from several PREPROCESED_UNITs takes
#    one row per PREPROCESED_UNIT.
unitFixNotUsed <- dplyr::anti_join(unitFix, mapping, by = c("TEST_NAME", "UNIT"))
if (nrow(unitFixNotUsed) > 0) {
  ParallelLogger::logWarn(nrow(unitFixNotUsed), " unitFix rows have a TEST_NAME + UNIT that is not in the mapping")
}
result <- mapping |>
  dplyr::left_join(
    unitFix |> dplyr::transmute(TEST_NAME, PREPROCESED_UNIT, UNIT, unit_fix_reasoning, inUnitFix = TRUE),
    by = c("TEST_NAME", "UNIT"),
    relationship = "one-to-many"
  ) |>
  # A fix can have an empty PREPROCESED_UNIT, so the fix is told by inUnitFix, not by a value.
  dplyr::mutate(PREPROCESED_UNIT = dplyr::if_else(inUnitFix %in% TRUE, PREPROCESED_UNIT, UNIT)) |>
  dplyr::select(-inUnitFix)

# 2. Append the concept attributes and its harmonised unit by concept_id. The target table has
#    a row per concept and Group, so the concept columns repeat on every row of a concept.
concepts <- targetTable |>
  dplyr::distinct(
    concept_id, concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    HARMONISED_UNIT = harmonised_unit
  )
if (anyDuplicated(concepts$concept_id) > 0) {
  ParallelLogger::logWarn(
    sum(duplicated(concepts$concept_id)), " concept_ids have more than one set of attributes or units in the target table"
  )
}
result <- result |>
  dplyr::left_join(concepts, by = "concept_id", relationship = "many-to-one")

# 3. Append the LOINC Groups, only group_concept_id, group_concept_code and
#    group_concept_name. A concept can be in several Groups; they are joined with ";"
#    (in the same order in the three columns, by group code) so the table keeps one row per pair.
groupsPerConcept <- targetTable |>
  dplyr::filter(!is.na(group_concept_id)) |>
  dplyr::arrange(concept_id, group_concept_code) |>
  dplyr::summarise(
    group_concept_id = paste(group_concept_id, collapse = ";"),
    group_concept_code = paste(group_concept_code, collapse = ";"),
    group_concept_name = paste(group_concept_name, collapse = ";"),
    .by = concept_id
  )
result <- result |>
  dplyr::left_join(groupsPerConcept, by = "concept_id")

# 4. Append the conversion by context + UNIT + HARMONISED_UNIT, keeping only CONVERSION. The
#    context of a rule is a LOINC property (it applies to every concept with that has_property)
#    or a concept id (it applies only to that concept, and wins over the rule of the property
#    with the same units).
isConceptContext <- grepl("^[0-9]+$", unitHarmonisation$context)
conversionGeneral <- unitHarmonisation[!isConceptContext, ] |>
  dplyr::transmute(has_property = context, UNIT, HARMONISED_UNIT, CONVERSION)
conversionConcept <- unitHarmonisation[isConceptContext, ] |>
  dplyr::transmute(
    concept_id = as.integer(context), UNIT, HARMONISED_UNIT, CONVERSION_CONCEPT = CONVERSION
  )
ParallelLogger::logInfo(
  nrow(conversionGeneral), " conversion rules of a property, ",
  nrow(conversionConcept), " conversion rules of a concept"
)

result <- result |>
  dplyr::left_join(conversionGeneral, by = c("has_property", "UNIT", "HARMONISED_UNIT")) |>
  dplyr::left_join(conversionConcept, by = c("concept_id", "UNIT", "HARMONISED_UNIT")) |>
  dplyr::mutate(CONVERSION = dplyr::coalesce(CONVERSION_CONCEPT, CONVERSION)) |>
  dplyr::select(
    TEST_NAME, PREPROCESED_UNIT, UNIT, unit_fix_reasoning,
    concept_id, ignore_mapping_reason, APPROVED,
    concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property,
    group_concept_id, group_concept_code, group_concept_name,
    HARMONISED_UNIT, CONVERSION
  ) |>
  dplyr::arrange(TEST_NAME, PREPROCESED_UNIT, UNIT)

# 5. The warnings go to their own tables (written below), not into this table. Each has a
#    message with the details and an `ignore` flag, set to TRUE by hand to accept the
#    warning. They are only edited when a warning appears or goes away (syncWarnings).
#    - testname_unit_property_missmatch_warning.tsv, one row per TEST_NAME + UNIT: a
#      has_property + UNIT without a rule in unitHarmonisation.tsv, so the property of the
#      concept does not agree with the unit.
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

# A has_property + UNIT is known when the table has a rule of the property with that UNIT, or a rule of
# the concept itself (a concept-specific rule, e.g. HbA1c) with that UNIT.
knownPropertyUnit <- paste(conversionGeneral$has_property, conversionGeneral$UNIT, sep = "\r")
knownConceptUnit <- paste(conversionConcept$concept_id, conversionConcept$UNIT, sep = "\r")
propertyMismatchFile <- file.path(outDir, "testname_unit_property_missmatch_warning.tsv")
propertyMismatch <- result |>
  dplyr::filter(
    !is.na(has_property), !is.na(UNIT),
    !(paste(has_property, UNIT, sep = "\r") %in% knownPropertyUnit),
    !(paste(concept_id, UNIT, sep = "\r") %in% knownConceptUnit)
  ) |>
  dplyr::distinct(TEST_NAME, UNIT, has_property) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    message = paste0(
      "has_property '", has_property, "' and UNIT '", UNIT,
      "' are not in unitHarmonisation.tsv: the property of the concept does not agree with the unit"
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

# 6. mapping_status, the first column, replaces APPROVED:
#    IGNORE if there is an ignore_mapping_reason; ERROR if the mapping is APPROVED and has a
#    warning that is not marked `ignore` (in either warning table); APPROVED if it is
#    APPROVED; NOT-APPROVED otherwise.
#    mapping_warning_messages, the last column, has every message of the warning tables that
#    joins to the row (ignored or not), each starting with its type (WrongProperty: for the
#    property mismatch, SharedProperty: for the shared property), separated by " | ".
result <- result |>
  dplyr::left_join(
    propertyMismatch |>
      dplyr::transmute(TEST_NAME, UNIT, mismatch = paste0("WrongProperty: ", message), mismatchIgnore = ignore),
    by = c("TEST_NAME", "UNIT"), relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    propertyShared |>
      dplyr::transmute(TEST_NAME, has_property, shared = paste0("SharedProperty: ", message), sharedIgnore = ignore),
    by = c("TEST_NAME", "has_property"), relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    hasWarning = (!is.na(mismatch) & !mismatchIgnore) | (!is.na(shared) & !sharedIgnore),
    mapping_warning_messages = dplyr::case_when(
      !is.na(mismatch) & !is.na(shared) ~ paste(mismatch, shared, sep = " | "),
      !is.na(mismatch) ~ mismatch,
      TRUE ~ shared
    ),
    mapping_status = dplyr::case_when(
      !is.na(ignore_mapping_reason) ~ "IGNORE",
      APPROVED %in% TRUE & hasWarning ~ "ERROR",
      APPROVED %in% TRUE ~ "APPROVED",
      TRUE ~ "NOT-APPROVED"
    )
  ) |>
  dplyr::select(-APPROVED, -mismatch, -mismatchIgnore, -shared, -sharedIgnore, -hasWarning) |>
  dplyr::relocate(mapping_status) |>
  dplyr::relocate(mapping_warning_messages, .after = dplyr::last_col())
ParallelLogger::logInfo(
  paste(names(table(result$mapping_status)), table(result$mapping_status), collapse = ", "), " (mapping_status)"
)

nPairs <- nrow(dplyr::distinct(result, TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logInfo(nPairs, " TEST_NAME/PREPROCESED_UNIT/UNIT pairs in ", nrow(result), " rows")
ParallelLogger::logInfo(
  dplyr::n_distinct(result$TEST_NAME[is.na(result$concept_code)], result$PREPROCESED_UNIT[is.na(result$concept_code)], result$UNIT[is.na(result$concept_code)]),
  " pairs whose concept_id is not in the target table"
)
# A HARMONISED_UNIT without a CONVERSION cannot be applied, so it is set to missing.
nNoConversion <- nrow(dplyr::distinct(result |> dplyr::filter(!is.na(HARMONISED_UNIT), is.na(CONVERSION)), TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logWarn(nNoConversion, " pairs have a HARMONISED_UNIT but no CONVERSION: HARMONISED_UNIT set to empty")
result <- result |>
  dplyr::mutate(HARMONISED_UNIT = dplyr::if_else(is.na(CONVERSION), NA_character_, HARMONISED_UNIT))
nNoTarget <- nrow(dplyr::distinct(result |> dplyr::filter(is.na(HARMONISED_UNIT)), TEST_NAME, PREPROCESED_UNIT, UNIT))
ParallelLogger::logWarn(nNoTarget, " pairs have no HARMONISED_UNIT")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "harmonisationTable.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
