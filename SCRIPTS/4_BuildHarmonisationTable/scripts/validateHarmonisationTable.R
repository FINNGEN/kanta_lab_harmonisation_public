#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

# the column types shared with buildHarmonisationTable.R
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

conceptIds <- targetTable$concept_id

# unitFix.tsv
checkTypes("unitFix.tsv", unitFix)
checkHaveValue("unitFix.tsv", unitFix, "TEST_NAME")
checkUnique("unitFix.tsv", unitFix, c("TEST_NAME", "PREPROCESED_UNIT"))
# A fix that does not change the unit does nothing.
record(
  "unitFix.tsv", "UNIT differs from PREPROCESED_UNIT",
  bad = !is.na(unitFix$UNIT) & !is.na(unitFix$PREPROCESED_UNIT) & unitFix$UNIT == unitFix$PREPROCESED_UNIT,
  df = unitFix, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT")
)
# The output is built from mapping.tsv (a left join of the fixes), so a fix for a pair that is
# not there is not an error, only never used.
record(
  "unitFix.tsv", "TEST_NAME + UNIT is used downstream (it is in mapping.tsv)",
  bad = !(paste(unitFix$TEST_NAME, unitFix$UNIT) %in% paste(mapping$TEST_NAME, mapping$UNIT)),
  df = unitFix, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT"),
  extra = "not used downstream", level = "WARNING"
)

# A preprocessed unit that unitFix.tsv fixes must not also be a row of the base table:
# the pair would then have two answers (the fix and the unfixed row). An empty unit
# counts as a unit here.
pairKey <- function(test, unit) paste(test, tidyr::replace_na(unit, ""), sep = "\r")
record(
  "unitFix.tsv", "TEST_NAME + PREPROCESED_UNIT must not appear in mapping.tsv",
  bad = pairKey(unitFix$TEST_NAME, unitFix$PREPROCESED_UNIT) %in%
    pairKey(mapping$TEST_NAME, mapping$UNIT),
  df = unitFix, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT")
)

# mapping.tsv
checkTypes("mapping.tsv", mapping)
checkHaveValue("mapping.tsv", mapping, c("TEST_NAME", "concept_id"))
checkUnique("mapping.tsv", mapping, c("TEST_NAME", "UNIT"))
# APPROVED is always the text TRUE or FALSE (read as text, since a logical column also
# accepts T, F, true and false).
approvedText <- readr::read_tsv(
  mappingFile,
  col_types = readr::cols(.default = readr::col_character()), na = ""
)$APPROVED
record(
  "mapping.tsv", "APPROVED must be TRUE or FALSE",
  bad = !(approvedText %in% c("TRUE", "FALSE")),
  df = tibble::tibble(APPROVED = approvedText), what = "APPROVED"
)
# A concept_id of 0 (no concept) is only allowed with an ignore_mapping_reason.
record(
  "mapping.tsv", "concept_id must not be 0, unless there is an ignore_mapping_reason",
  bad = mapping$concept_id == 0L & is.na(mapping$ignore_mapping_reason),
  df = mapping, what = c("TEST_NAME", "UNIT", "concept_id")
)
# A row with an ignore_mapping_reason is not mapped, so its concept_id needs no attributes.
withConcept <- mapping |> dplyr::filter(is.na(ignore_mapping_reason))
record(
  "mapping.tsv", "concept_id is in targetTable.tsv, unless there is an ignore_mapping_reason",
  bad = !(withConcept$concept_id %in% conceptIds),
  df = withConcept, what = c("TEST_NAME", "UNIT", "concept_id")
)

# unitHarmonisation.tsv: only checks of the table itself (no input or target data).
checkTypes("unitHarmonisation.tsv", unitHarmonisation)
# An empty HARMONISED_UNIT is a unit that maps to no unit (a qualitative result, e.g. `estimate`).
checkHaveValue("unitHarmonisation.tsv", unitHarmonisation, c("context", "UNIT", "CONVERSION"))
checkUnique("unitHarmonisation.tsv", unitHarmonisation, c("context", "UNIT", "HARMONISED_UNIT"))
record(
  "unitHarmonisation.tsv", "CONVERSION is a number or a formula in X",
  bad = is.na(suppressWarnings(as.numeric(unitHarmonisation$CONVERSION))) &
    !grepl("\\bX\\b", unitHarmonisation$CONVERSION),
  df = unitHarmonisation, what = c("context", "UNIT", "HARMONISED_UNIT", "CONVERSION")
)
# harmonisedUnitOverwrite.tsv: the target units set by hand. Each row needs a concept of the target and
# a note; a row that gives the concept the unit it already has is not needed; nothing converts to a unit
# with no rule in unitHarmonisation.tsv.
checkTypes("harmonisedUnitOverwrite.tsv", unitOverwrite)
checkHaveValue("harmonisedUnitOverwrite.tsv", unitOverwrite, c("concept_id", "harmonised_unit", "note"))
checkUnique("harmonisedUnitOverwrite.tsv", unitOverwrite, c("concept_id"))
record(
  "harmonisedUnitOverwrite.tsv", "concept_id is in targetTable.tsv",
  bad = !(unitOverwrite$concept_id %in% conceptIds),
  df = unitOverwrite, what = c("concept_id", "harmonised_unit")
)
overwriteVsTarget <- unitOverwrite |>
  dplyr::left_join(
    targetTable |> dplyr::distinct(concept_id, has_property, targetUnit = harmonised_unit),
    by = "concept_id", relationship = "many-to-one"
  )
record(
  "harmonisedUnitOverwrite.tsv", "harmonised_unit differs from the harmonised_unit of the concept in targetTable.tsv",
  bad = !is.na(overwriteVsTarget$targetUnit) & overwriteVsTarget$harmonised_unit == overwriteVsTarget$targetUnit,
  df = overwriteVsTarget, what = c("concept_id", "harmonised_unit"), level = "WARNING"
)
record(
  "harmonisedUnitOverwrite.tsv", "harmonised_unit has a rule in unitHarmonisation.tsv (for the has_property or the concept_id)",
  bad = !(paste(overwriteVsTarget$has_property, overwriteVsTarget$harmonised_unit, sep = "\r") %in%
    paste(unitHarmonisation$context, unitHarmonisation$HARMONISED_UNIT, sep = "\r") |
    paste(overwriteVsTarget$concept_id, overwriteVsTarget$harmonised_unit, sep = "\r") %in%
      paste(unitHarmonisation$context, unitHarmonisation$HARMONISED_UNIT, sep = "\r")),
  df = overwriteVsTarget, what = c("concept_id", "has_property", "harmonised_unit"), level = "WARNING"
)

# targetTable.tsv
checkTypes("targetTable.tsv", targetTable)
checkHaveValue(
  "targetTable.tsv", targetTable,
  c("concept_id", "concept_code", "concept_name", "vocabulary_id", "is_panel")
)
checkUnique("targetTable.tsv", targetTable, c("concept_id", "group_concept_id"))

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
  "# harmonisationTable validation",
  "",
  "Validation of the input tables of `4_BuildHarmonisationTable`: the tables of `2_Harmonisation` and `targetTable.tsv`. The problems of the mappings themselves are in the two warning tables and in `mapping_status` (`ERROR:<reason>`).",
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
outFile <- file.path(outDir, "harmonisationTable.validation.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
