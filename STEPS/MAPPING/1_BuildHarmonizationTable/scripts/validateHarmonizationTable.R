#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

# the column types shared with buildHarmonizationTable.R
scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(scriptDir, "readTables.R"))

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
unitFixFile <- args[1]
unitsFile <- args[2]
testnameUnitToConceptidFile <- args[3]
measurementConceptAttributesFile <- args[4]
loincGroupMembershipFile <- args[5]
conceptidTargetUnitFile <- args[6]
quantitySourceUnitConversionFile <- args[7]
harmonizationTableFile <- args[8]
outDir <- args[9]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  unitsFile = ", unitsFile)
ParallelLogger::logInfo("  testnameUnitToConceptidFile = ", testnameUnitToConceptidFile)
ParallelLogger::logInfo("  measurementConceptAttributesFile = ", measurementConceptAttributesFile)
ParallelLogger::logInfo("  loincGroupMembershipFile = ", loincGroupMembershipFile)
ParallelLogger::logInfo("  conceptidTargetUnitFile = ", conceptidTargetUnitFile)
ParallelLogger::logInfo("  quantitySourceUnitConversionFile = ", quantitySourceUnitConversionFile)
ParallelLogger::logInfo("  harmonizationTableFile = ", harmonizationTableFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
unitFix <- readTable(unitFixFile, tableSpecs$unitFix)
units <- readTable(unitsFile, tableSpecs$units)
testnameUnitToConceptid <- readTable(testnameUnitToConceptidFile, tableSpecs$testnameUnitToConceptid)
measurementConceptAttributes <- readTable(measurementConceptAttributesFile, tableSpecs$measurementConceptAttributes)
loincGroupMembership <- readTable(loincGroupMembershipFile, tableSpecs$loincGroupMembership)
conceptidTargetUnit <- readTable(conceptidTargetUnitFile, tableSpecs$conceptidTargetUnit)
quantitySourceUnitConversion <- readTable(quantitySourceUnitConversionFile, tableSpecs$quantitySourceUnitConversion)
harmonizationTable <- readTable(harmonizationTableFile, tableSpecs$harmonizationTable)

#
# --- Action -------------------------------------------------------------
#
results <- list()

# Shows the failing rows as examples. A test and its unit are written TEST_NAME[unit],
# as in the Usagi sourceCode (an empty unit is TEST_NAME[]), and a chain of units
# is joined with "->": TEST_NAME[PREPROCESED_UNIT->UNIT]. Any other column is shown
# as column=value. Never "|", which is the separator of a markdown table.
formatExamples <- function(rows, what) {
  unitCols <- intersect(what, c("PREPROCESED_UNIT", "UNIT", "HARMONISED_UNIT"))
  otherCols <- setdiff(what, c("TEST_NAME", unitCols))
  text <- function(x) ifelse(is.na(x), "", as.character(x))
  units <- if (length(unitCols) > 0) {
    do.call(paste, c(lapply(rows[unitCols], text), sep = "->"))
  } else {
    NULL
  }
  if ("TEST_NAME" %in% what && !is.null(units)) {
    shown <- paste0(rows$TEST_NAME, "[", units, "]")
  } else if ("TEST_NAME" %in% what) {
    shown <- as.character(rows$TEST_NAME)
  } else if (!is.null(units)) {
    shown <- ifelse(units == "", "(empty)", units)
  } else {
    shown <- rep("", nrow(rows))
  }
  for (col in otherCols) shown <- trimws(paste0(shown, " ", col, "=", text(rows[[col]])))
  shown
}

# Records one test. `bad` is a logical vector over the rows of `df`, TRUE where the
# row fails; `what` says how to show a failing row (the columns pasted together).
# `text` replaces the default message of a failing test.
# `level` is the result of a failing test: "ERROR", or "WARNING" for a finding that
# does not break the table.
record <- function(table, test, bad, df = NULL, what = NULL, extra = NULL, level = "ERROR", text = NULL, n = NULL) {
  bad[is.na(bad)] <- TRUE
  nBad <- if (is.null(n)) sum(bad) else n
  message <- ""
  if (any(bad)) {
    examples <- if (!is.null(df) && !is.null(what)) {
      unique(formatExamples(df[bad, , drop = FALSE], what))
    } else {
      character(0)
    }
    parts <- character(0)
    if (!is.null(extra)) parts <- c(parts, extra)
    if (length(examples) > 0) {
      parts <- c(parts, paste0("e.g. ", paste(utils::head(examples, 3), collapse = "; ")))
    }
    message <- paste(parts, collapse = ", ")
    if (!is.null(text)) message <- text
  }
  results[[length(results) + 1]] <<- tibble::tibble(
    table = table,
    result = ifelse(!any(bad), "SUCCESS", level),
    test = test,
    n_rows = if (any(bad)) format(nBad, big.mark = ",", trim = TRUE) else "",
    message = message
  )
}

# The values of the columns parse with the types declared in tableSpecs.
checkTypes <- function(table, df) {
  problems <- readr::problems(df)
  record(
    table, "columns match their declared types",
    bad = seq_len(nrow(problems)) > 0,
    df = problems, what = intersect(c("col", "expected", "actual"), names(problems))
  )
}

# The columns have a value in every row.
checkHaveValue <- function(table, df, cols) {
  missingByCol <- vapply(cols, function(col) sum(is.na(df[[col]])), numeric(1))
  anyMissing <- Reduce(`|`, lapply(cols, function(col) is.na(df[[col]])))
  record(
    table, paste0(paste(cols, collapse = ", "), " must have a value"),
    bad = anyMissing,
    extra = paste(paste0(names(missingByCol)[missingByCol > 0], ": ", missingByCol[missingByCol > 0]), collapse = ", ")
  )
}

# The combination of columns is unique; every row of a repeated combination fails.
checkUnique <- function(table, df, cols) {
  dup <- duplicated(df[cols]) | duplicated(df[cols], fromLast = TRUE)
  record(
    table, paste0(paste(cols, collapse = " + "), " are unique"),
    bad = dup, df = df, what = cols,
    extra = paste0(format(nrow(dplyr::distinct(df[dup, cols, drop = FALSE])), big.mark = ","), " repeated values")
  )
}

# The unit is defined in UNITSfi.tsv. A qualitative test has no unit, so an empty one
# is also valid where `allowEmpty` is TRUE.
validUnits <- units$UNIT
checkValidUnit <- function(table, df, col, allowEmpty = TRUE) {
  isEmpty <- is.na(df[[col]])
  notInUnits <- !isEmpty & !(df[[col]] %in% validUnits)
  record(
    table,
    paste0(col, " must be a valid unit in UNITSfi.tsv", if (allowEmpty) " (or empty)" else ""),
    bad = notInUnits | (!allowEmpty & isEmpty),
    df = df, what = col,
    extra = paste0(dplyr::n_distinct(df[[col]][notInUnits]), " units not in UNITSfi.tsv")
  )
}

conceptIds <- measurementConceptAttributes$concept_id

# unit_fix.tsv
checkTypes("unit_fix.tsv", unitFix)
checkHaveValue("unit_fix.tsv", unitFix, "TEST_NAME")
checkValidUnit("unit_fix.tsv", unitFix, "UNIT")
checkUnique("unit_fix.tsv", unitFix, c("TEST_NAME", "PREPROCESED_UNIT"))
# The output is built from testname_unit_to_conceptid.tsv (a right join of the fixes),
# so a fix for a pair that is not there is not an error, only never used.
record(
  "unit_fix.tsv", "TEST_NAME + UNIT is used downstream (it is in testname_unit_to_conceptid.tsv)",
  bad = !(paste(unitFix$TEST_NAME, unitFix$UNIT) %in% paste(testnameUnitToConceptid$TEST_NAME, testnameUnitToConceptid$UNIT)),
  df = unitFix, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT"),
  extra = "not used downstream", level = "WARNING"
)

# A preprocessed unit that unit_fix.tsv fixes must not also be a row of the base table:
# the pair would then have two answers (the fix and the unfixed row). An empty unit
# counts as a unit here.
pairKey <- function(test, unit) paste(test, tidyr::replace_na(unit, ""), sep = "\r")
record(
  "unit_fix.tsv", "TEST_NAME + PREPROCESED_UNIT must not appear in testname_unit_to_conceptid.tsv",
  bad = pairKey(unitFix$TEST_NAME, unitFix$PREPROCESED_UNIT) %in%
    pairKey(testnameUnitToConceptid$TEST_NAME, testnameUnitToConceptid$UNIT),
  df = unitFix, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT")
)

# UNITSfi.tsv
checkTypes("UNITSfi.tsv", units)
checkHaveValue("UNITSfi.tsv", units, c("UNIT", "concept_id", "UNIQUE_FOR_LAB"))
checkUnique("UNITSfi.tsv", units, "UNIT")

# testname_unit_to_conceptid.tsv
checkTypes("testname_unit_to_conceptid.tsv", testnameUnitToConceptid)
checkHaveValue("testname_unit_to_conceptid.tsv", testnameUnitToConceptid, c("TEST_NAME", "concept_id"))
checkValidUnit("testname_unit_to_conceptid.tsv", testnameUnitToConceptid, "UNIT")
checkUnique("testname_unit_to_conceptid.tsv", testnameUnitToConceptid, c("TEST_NAME", "UNIT"))
# APPROVED is always the text TRUE or FALSE (read as text, since a logical column also
# accepts T, F, true and false).
approvedText <- readr::read_tsv(
  testnameUnitToConceptidFile,
  col_types = readr::cols(.default = readr::col_character()), na = ""
)$APPROVED
record(
  "testname_unit_to_conceptid.tsv", "APPROVED must be TRUE or FALSE",
  bad = !(approvedText %in% c("TRUE", "FALSE")),
  df = tibble::tibble(APPROVED = approvedText), what = "APPROVED"
)
# A concept_id of 0 (no concept) is only allowed with an ignore_mapping_reason.
record(
  "testname_unit_to_conceptid.tsv", "concept_id must not be 0, unless there is an ignore_mapping_reason",
  bad = testnameUnitToConceptid$concept_id == 0L & is.na(testnameUnitToConceptid$ignore_mapping_reason),
  df = testnameUnitToConceptid, what = c("TEST_NAME", "UNIT", "concept_id")
)
# A row with an ignore_mapping_reason is not mapped, so its concept_id needs no attributes.
withConcept <- testnameUnitToConceptid |> dplyr::filter(is.na(ignore_mapping_reason))
record(
  "testname_unit_to_conceptid.tsv", "concept_id is in measurement_concept_attributes.tsv, unless there is an ignore_mapping_reason",
  bad = !(withConcept$concept_id %in% conceptIds),
  df = withConcept, what = c("TEST_NAME", "UNIT", "concept_id")
)

# measurement_concept_attributes.tsv
checkTypes("measurement_concept_attributes.tsv", measurementConceptAttributes)
checkHaveValue(
  "measurement_concept_attributes.tsv", measurementConceptAttributes,
  c("concept_id", "concept_code", "concept_name", "vocabulary_id", "is_panel")
)
checkUnique("measurement_concept_attributes.tsv", measurementConceptAttributes, "concept_id")

# flowsheet_loinc_groups.tsv: a concept can be in several Groups, but only once in each.
checkTypes("flowsheet_loinc_groups.tsv", loincGroupMembership)
checkHaveValue(
  "flowsheet_loinc_groups.tsv", loincGroupMembership,
  c("concept_id", "group_concept_id", "group_concept_code", "group_concept_name")
)
checkUnique("flowsheet_loinc_groups.tsv", loincGroupMembership, c("concept_id", "group_concept_id"))
record(
  "flowsheet_loinc_groups.tsv", "concept_id is in measurement_concept_attributes.tsv",
  bad = !(loincGroupMembership$concept_id %in% conceptIds),
  df = loincGroupMembership, what = c("concept_id", "group_concept_id")
)

# conceptid_target_unit.tsv
checkTypes("conceptid_target_unit.tsv", conceptidTargetUnit)
checkHaveValue("conceptid_target_unit.tsv", conceptidTargetUnit, c("concept_id", "HARMONISED_UNIT"))
checkValidUnit("conceptid_target_unit.tsv", conceptidTargetUnit, "HARMONISED_UNIT", allowEmpty = FALSE)
checkUnique("conceptid_target_unit.tsv", conceptidTargetUnit, "concept_id")
record(
  "conceptid_target_unit.tsv", "concept_id is in measurement_concept_attributes.tsv",
  bad = !(conceptidTargetUnit$concept_id %in% conceptIds),
  df = conceptidTargetUnit, what = c("concept_id", "HARMONISED_UNIT")
)

# quantity_source_unit_conversion.tsv
checkTypes("quantity_source_unit_conversion.tsv", quantitySourceUnitConversion)
checkHaveValue(
  "quantity_source_unit_conversion.tsv", quantitySourceUnitConversion,
  c("has_property", "UNIT", "HARMONISED_UNIT", "CONVERSION")
)
checkValidUnit("quantity_source_unit_conversion.tsv", quantitySourceUnitConversion, "UNIT", allowEmpty = FALSE)
checkValidUnit("quantity_source_unit_conversion.tsv", quantitySourceUnitConversion, "HARMONISED_UNIT", allowEmpty = FALSE)
checkUnique(
  "quantity_source_unit_conversion.tsv", quantitySourceUnitConversion,
  c("has_property", "UNIT", "HARMONISED_UNIT", "ONLY_TO_OMOP_CONCEPTS")
)
record(
  "quantity_source_unit_conversion.tsv", "CONVERSION is a number or a formula in X",
  bad = is.na(suppressWarnings(as.numeric(quantitySourceUnitConversion$CONVERSION))) &
    !grepl("\\bX\\b", quantitySourceUnitConversion$CONVERSION),
  df = quantitySourceUnitConversion, what = c("has_property", "UNIT", "HARMONISED_UNIT", "CONVERSION")
)
record(
  "quantity_source_unit_conversion.tsv", "has_property is a has_property of measurement_concept_attributes.tsv",
  bad = !is.na(quantitySourceUnitConversion$has_property) &
    !(quantitySourceUnitConversion$has_property %in% c("-", measurementConceptAttributes$has_property)),
  df = quantitySourceUnitConversion, what = c("has_property", "UNIT", "HARMONISED_UNIT")
)
onlyIds <- quantitySourceUnitConversion |>
  dplyr::filter(!is.na(ONLY_TO_OMOP_CONCEPTS)) |>
  tidyr::separate_longer_delim(ONLY_TO_OMOP_CONCEPTS, delim = ";") |>
  dplyr::mutate(ONLY_TO_OMOP_CONCEPTS = trimws(ONLY_TO_OMOP_CONCEPTS))
record(
  "quantity_source_unit_conversion.tsv", "ONLY_TO_OMOP_CONCEPTS are concept ids in measurement_concept_attributes.tsv",
  bad = !(suppressWarnings(as.integer(onlyIds$ONLY_TO_OMOP_CONCEPTS)) %in% conceptIds),
  df = onlyIds, what = c("has_property", "ONLY_TO_OMOP_CONCEPTS")
)

# harmonizationTable.tsv
checkTypes("harmonizationTable.tsv", harmonizationTable)
checkUnique("harmonizationTable.tsv", harmonizationTable, c("TEST_NAME", "PREPROCESED_UNIT"))
# The table only appends columns to testname_unit_to_conceptid.tsv joined with
# unit_fix.tsv (a UNIT fixed from several PREPROCESED_UNITs takes one row for each).
# The later joins add no rows, so the row count is that of the first join.
nBase <- nrow(
  dplyr::left_join(
    testnameUnitToConceptid[c("TEST_NAME", "UNIT")],
    unitFix[c("TEST_NAME", "UNIT")],
    by = c("TEST_NAME", "UNIT"),
    relationship = "one-to-many"
  )
)
nOut <- nrow(harmonizationTable)
record(
  "harmonizationTable.tsv", "has as many rows as testname_unit_to_conceptid.tsv joined with unit_fix.tsv",
  bad = nOut != nBase,
  n = abs(nOut - nBase),
  text = paste0(
    format(nOut, big.mark = ","), " rows, testname_unit_to_conceptid.tsv joined with unit_fix.tsv has ",
    format(nBase, big.mark = ","), " (", format(abs(nOut - nBase), big.mark = ","),
    if (nOut > nBase) " more" else " fewer", ")"
  )
)
record(
  "harmonizationTable.tsv", "every TEST_NAME + UNIT of testname_unit_to_conceptid.tsv is kept",
  bad = !(paste(testnameUnitToConceptid$TEST_NAME, testnameUnitToConceptid$UNIT) %in%
    paste(harmonizationTable$TEST_NAME, harmonizationTable$UNIT)),
  df = testnameUnitToConceptid, what = c("TEST_NAME", "UNIT")
)
record(
  "harmonizationTable.tsv", "concept_id has its attributes, unless there is an ignore_mapping_reason",
  bad = is.na(harmonizationTable$concept_code) & is.na(harmonizationTable$ignore_mapping_reason),
  df = harmonizationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "concept_id")
)
record(
  "harmonizationTable.tsv", "a row with a HARMONISED_UNIT has a CONVERSION",
  bad = !is.na(harmonizationTable$HARMONISED_UNIT) & is.na(harmonizationTable$CONVERSION),
  df = harmonizationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "HARMONISED_UNIT")
)
# A has_property + UNIT without a rule in quantity_source_unit_conversion.tsv means the
# property of the mapped concept does not agree with the unit. The Message column of the
# table (written by buildHarmonizationTable.R) says it: an ERROR if the mapping is
# APPROVED, a WARNING if not. Rows without a has_property or a UNIT are not checked.
propertyUnitMessage <- "are not in quantity_source_unit_conversion.tsv"
propertyUnitTest <- "has_property + UNIT is in quantity_source_unit_conversion.tsv (the concept's property agrees with the unit)"
for (level in c("ERROR", "WARNING")) {
  record(
    "harmonizationTable.tsv",
    paste0(propertyUnitTest, if (level == "ERROR") ", for an APPROVED mapping" else ", for a mapping that is not APPROVED"),
    bad = startsWith(tidyr::replace_na(harmonizationTable$Message, ""), level) &
      grepl(propertyUnitMessage, tidyr::replace_na(harmonizationTable$Message, ""), fixed = TRUE),
    df = harmonizationTable, what = c("TEST_NAME", "UNIT", "has_property"),
    extra = "property does not agree with the unit", level = level
  )
}

# A TEST_NAME with the same has_property (the old omop_quantity) should map to one concept.
# Several concept_ids (e.g. the same analyte in blood and in urine) are a WARNING to review.
# Ignored rows and rows without a concept are not checked.
mapped <- harmonizationTable |>
  dplyr::filter(is.na(ignore_mapping_reason), !is.na(concept_name)) |>
  dplyr::distinct(TEST_NAME, has_property, concept_id, concept_name)
severalConcepts <- mapped |>
  dplyr::arrange(TEST_NAME, has_property, concept_id) |>
  dplyr::summarise(
    n_concepts = dplyr::n(),
    concepts = paste0(concept_id, " (", concept_name, ")", collapse = " | "),
    .by = c(TEST_NAME, has_property)
  ) |>
  dplyr::filter(n_concepts > 1)
severalConceptsText <- paste0(
  "testName '", severalConcepts$TEST_NAME, "' with omop_quantity '",
  tidyr::replace_na(severalConcepts$has_property, ""), "' maps to different concept ids: ",
  severalConcepts$concepts
)
record(
  "harmonizationTable.tsv", "a TEST_NAME with the same has_property maps to one concept_id",
  bad = nrow(severalConcepts) > 0,
  level = "WARNING",
  n = nrow(severalConcepts),
  text = paste0(
    "TEST_NAME + has_property map to different concept ids, e.g. ",
    paste(utils::head(severalConceptsText, 2), collapse = "; ")
  )
)

results <- dplyr::bind_rows(results)
nError <- sum(results$result == "ERROR")
nWarning <- sum(results$result == "WARNING")
ParallelLogger::logInfo(
  nrow(results), " tests: ", sum(results$result == "SUCCESS"), " SUCCESS, ",
  nWarning, " WARNING, ", nError, " ERROR"
)
for (i in which(results$result != "SUCCESS")) {
  ParallelLogger::logWarn(results$table[i], ": ", results$test[i], ": ", results$n_rows[i], " rows, ", results$message[i])
}

#
# --- Output -------------------------------------------------------------
#
cell <- function(x) gsub("\\|", "\\\\|", x)

# Validation summary: the tests of each table by result, then all of them.
countResults <- function(df) {
  c(
    SUCCESS = sum(df$result == "SUCCESS"),
    WARNING = sum(df$result == "WARNING"),
    ERROR = sum(df$result == "ERROR")
  )
}
summaryByTable <- do.call(rbind, lapply(unique(results$table), function(tbl) {
  c(table = tbl, countResults(results[results$table == tbl, ]))
}))
summaryAll <- c(table = "ALL", countResults(results))
summaryTable <- rbind(summaryByTable, summaryAll)

md <- c(
  "# harmonizationTable validation",
  "",
  "Validation of the input and output tables of `1_BuildHarmonizationTable`.",
  "",
  "## Validation summary",
  "",
  "| table | SUCCESS | WARNING | ERROR |",
  "| --- | --- | --- | --- |",
  apply(summaryTable, 1, function(row) paste0("| ", paste(cell(row), collapse = " | "), " |")),
  "",
  "## Tests",
  "",
  "| table | result | test | n rows | message |",
  "| --- | --- | --- | ---: | --- |",
  paste0(
    "| ", cell(results$table), " | ", results$result, " | ", cell(results$test), " | ",
    results$n_rows, " | ", cell(results$message), " |"
  )
)
outFile <- file.path(outDir, "harmonizationTableValidation.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
