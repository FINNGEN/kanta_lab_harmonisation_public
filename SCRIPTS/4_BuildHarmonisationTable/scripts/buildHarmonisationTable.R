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
unitOverwriteFile <- args[5]
outDir <- args[6]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  mappingFile = ", mappingFile)
ParallelLogger::logInfo("  unitHarmonisationFile = ", unitHarmonisationFile)
ParallelLogger::logInfo("  targetTableFile = ", targetTableFile)
ParallelLogger::logInfo("  unitOverwriteFile = ", unitOverwriteFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
unitFix <- readTable(unitFixFile, tableSpecs$unitFix)
mapping <- readTable(mappingFile, tableSpecs$mapping)
unitHarmonisation <- readTable(unitHarmonisationFile, tableSpecs$unitHarmonisation)
targetTable <- readTable(targetTableFile, tableSpecs$targetTable)
unitOverwrite <- readTable(unitOverwriteFile, tableSpecs$unitOverwrite)

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
    target_unit = harmonised_unit, target_unit_source = harmonised_unit_source
  ) |>
  # The target unit set by hand (2_Harmonisation/harmonisedUnitOverwrite.tsv) wins over the one of the
  # target table, also for a qualitative concept or a panel; its source is the note.
  dplyr::left_join(
    unitOverwrite |> dplyr::transmute(concept_id, overwrite_unit = harmonised_unit, overwrite_note = dplyr::coalesce(note, "overwrite")),
    by = "concept_id", relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    target_unit_source = dplyr::if_else(is.na(overwrite_unit), target_unit_source, overwrite_note),
    target_unit = dplyr::coalesce(overwrite_unit, target_unit),
    HARMONISED_UNIT = target_unit
  ) |>
  dplyr::select(-overwrite_unit, -overwrite_note)
ParallelLogger::logInfo(
  sum(concepts$concept_id %in% unitOverwrite$concept_id), " concepts take their target unit from ", unitOverwriteFile
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
    target_unit, target_unit_source, HARMONISED_UNIT, CONVERSION
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

# The LOINC Groups whose approved pairs have more than one target unit (HARMONISED_UNIT, before it is
# cleared below). A pair with a target unit is in a mismatched Group when any of its Groups is; a pair
# with no target unit (e.g. a qualitative concept) is not.
groupUnits <- result |>
  dplyr::filter(APPROVED %in% TRUE, is.na(ignore_mapping_reason), !is.na(group_concept_id), !is.na(HARMONISED_UNIT)) |>
  dplyr::distinct(group_concept_id, HARMONISED_UNIT) |>
  tidyr::separate_longer_delim(group_concept_id, ";") |>
  dplyr::distinct(group_concept_id, HARMONISED_UNIT) |>
  dplyr::count(group_concept_id, name = "n_units")
mismatchedGroups <- groupUnits$group_concept_id[groupUnits$n_units > 1]
ParallelLogger::logInfo(length(mismatchedGroups), " LOINC Groups with approved pairs of more than one target unit")
# The units of each mismatched Group, for the message.
mismatchedGroupUnits <- result |>
  dplyr::filter(APPROVED %in% TRUE, is.na(ignore_mapping_reason), !is.na(group_concept_id), !is.na(HARMONISED_UNIT)) |>
  dplyr::select(group_concept_id, group_concept_code, HARMONISED_UNIT) |>
  tidyr::separate_longer_delim(c(group_concept_id, group_concept_code), ";") |>
  dplyr::filter(group_concept_id %in% mismatchedGroups) |>
  dplyr::summarise(
    units = paste(sort(unique(HARMONISED_UNIT)), collapse = ", "),
    .by = c(group_concept_id, group_concept_code)
  )

# test_unit_context_unit_missing_warning.tsv, one row per TEST_NAME + UNIT: the pair has a UNIT but its values
# cannot be converted, because its concept has no target unit (it is not qualitative or a panel, but lab2clean
# has no unit for it and harmonisedUnitOverwrite.tsv has no row), or because unitHarmonisation.tsv has no rule
# (for the has_property or the concept_id) from that UNIT to the target unit. Ignored rows, and concepts that
# are not in the target table (MissingConceptId), are not checked.
contextUnitMissingFile <- file.path(outDir, "test_unit_context_unit_missing_warning.tsv")
contextUnitMissing <- result |>
  dplyr::filter(
    is.na(ignore_mapping_reason), !is.na(UNIT), !is.na(concept_code), is.na(CONVERSION),
    !is.na(HARMONISED_UNIT) | !(target_unit_source %in% c("isQualitative", "panel"))
  ) |>
  dplyr::distinct(TEST_NAME, UNIT, concept_id, has_property, HARMONISED_UNIT) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    message = dplyr::if_else(
      is.na(HARMONISED_UNIT),
      paste0(
        "concept_id ", concept_id, " has no target unit (not in lab2clean, no row in harmonisedUnitOverwrite.tsv), ",
        "so UNIT '", UNIT, "' cannot be converted"
      ),
      paste0(
        "no rule in unitHarmonisation.tsv from UNIT '", UNIT, "' to the target unit '", HARMONISED_UNIT,
        "' for has_property '", tidyr::replace_na(has_property, ""), "' or concept_id ", concept_id
      )
    )
  ) |>
  syncWarnings(contextUnitMissingFile, tableSpecs$contextUnitMissingWarning, c("TEST_NAME", "UNIT"))

# test_unit_loinc_group_unit_mismatch_warning.tsv, one row per TEST_NAME + UNIT: the pair has a target unit
# and a LOINC Group of its concept has approved pairs with different target units, so its values cannot be
# compared with the Group. Ignored rows are not checked.
loincGroupUnitMismatchFile <- file.path(outDir, "test_unit_loinc_group_unit_mismatch_warning.tsv")
pairGroups <- result |>
  dplyr::filter(is.na(ignore_mapping_reason), !is.na(HARMONISED_UNIT), !is.na(group_concept_id)) |>
  dplyr::distinct(TEST_NAME, UNIT, group_concept_id, group_concept_code) |>
  tidyr::separate_longer_delim(c(group_concept_id, group_concept_code), ";") |>
  dplyr::inner_join(dplyr::select(mismatchedGroupUnits, group_concept_id, units), by = "group_concept_id")
loincGroupUnitMismatch <- pairGroups |>
  dplyr::arrange(TEST_NAME, UNIT, group_concept_code) |>
  dplyr::summarise(
    groups = paste0(group_concept_code, " (", units, ")", collapse = "; "),
    .by = c(TEST_NAME, UNIT)
  ) |>
  dplyr::transmute(
    TEST_NAME, UNIT,
    message = paste0("LOINC Group with approved pairs in more than one target unit: ", groups)
  ) |>
  syncWarnings(loincGroupUnitMismatchFile, tableSpecs$loincGroupUnitMismatchWarning, c("TEST_NAME", "UNIT"))
ParallelLogger::logWarn(
  nrow(contextUnitMissing), " TEST_NAME + UNIT with no conversion to the target unit (", sum(contextUnitMissing$ignore), " ignored), ",
  nrow(loincGroupUnitMismatch), " TEST_NAME + UNIT in a LOINC Group with mixed units (", sum(loincGroupUnitMismatch$ignore), " ignored)"
)

# 6. mapping_status, the first column, replaces APPROVED:
#    IGNORE if there is an ignore_mapping_reason; ERROR:<reason> if the mapping is APPROVED and
#    has an error; APPROVED if it is APPROVED; NOT-APPROVED otherwise. The reason is the first
#    of (in this order):
#    - MissingConceptId: the concept_id is not in the target table;
#    - PropertyUnitMismatch: a property mismatch warning not marked `ignore`;
#    - SharedProperty: a shared property warning not marked `ignore`;
#    - MissingConversion: a context unit missing warning not marked `ignore` (the pair has a UNIT
#      and the concept a target unit, but there is no CONVERSION; a pair with no UNIT is not
#      converted, so it is no error);
#    - LoincGroupUnitsMissmatch: a LOINC Group unit mismatch warning not marked `ignore`.
#    mapping_warning_messages, the last column, has every message of the warning tables that
#    joins to the row (ignored or not), each starting with its type (WrongProperty:,
#    SharedProperty:, MissingConversion:, LoincGroupUnitsMismatch:), separated by " | ".
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
  dplyr::left_join(
    contextUnitMissing |>
      dplyr::transmute(TEST_NAME, UNIT, conversionMissing = paste0("MissingConversion: ", message), conversionMissingIgnore = ignore),
    by = c("TEST_NAME", "UNIT"), relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    loincGroupUnitMismatch |>
      dplyr::transmute(TEST_NAME, UNIT, groupMismatch = paste0("LoincGroupUnitsMismatch: ", message), groupMismatchIgnore = ignore),
    by = c("TEST_NAME", "UNIT"), relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    errorReason = dplyr::case_when(
      is.na(concept_code) ~ "MissingConceptId",
      !is.na(mismatch) & !mismatchIgnore ~ "PropertyUnitMismatch",
      !is.na(shared) & !sharedIgnore ~ "SharedProperty",
      !is.na(conversionMissing) & !conversionMissingIgnore ~ "MissingConversion",
      !is.na(groupMismatch) & !groupMismatchIgnore ~ "LoincGroupUnitsMissmatch"
    ),
    mapping_warning_messages = purrr::pmap_chr(
      list(mismatch, shared, conversionMissing, groupMismatch),
      function(...) { m <- c(...); m <- m[!is.na(m)]; if (length(m) == 0) NA_character_ else paste(m, collapse = " | ") }
    ),
    mapping_status = dplyr::case_when(
      !is.na(ignore_mapping_reason) ~ "IGNORE",
      APPROVED %in% TRUE & !is.na(errorReason) ~ paste0("ERROR:", errorReason),
      APPROVED %in% TRUE ~ "APPROVED",
      TRUE ~ "NOT-APPROVED"
    )
  ) |>
  dplyr::select(-APPROVED, -mismatch, -mismatchIgnore, -shared, -sharedIgnore, -conversionMissing, -conversionMissingIgnore,
    -groupMismatch, -groupMismatchIgnore, -errorReason) |>
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
