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
harmonisationTableFile <- args[5]
propertyMismatchWarningFile <- args[6]
propertySharedWarningFile <- args[7]
lab2cleanUnitFile <- args[8]
unitOverwriteFile <- args[9]
outDir <- args[10]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  mappingFile = ", mappingFile)
ParallelLogger::logInfo("  unitHarmonisationFile = ", unitHarmonisationFile)
ParallelLogger::logInfo("  targetTableFile = ", targetTableFile)
ParallelLogger::logInfo("  harmonisationTableFile = ", harmonisationTableFile)
ParallelLogger::logInfo("  propertyMismatchWarningFile = ", propertyMismatchWarningFile)
ParallelLogger::logInfo("  propertySharedWarningFile = ", propertySharedWarningFile)
ParallelLogger::logInfo("  lab2cleanUnitFile = ", lab2cleanUnitFile)
ParallelLogger::logInfo("  unitOverwriteFile = ", unitOverwriteFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
unitFix <- readTable(unitFixFile, tableSpecs$unitFix)
mapping <- readTable(mappingFile, tableSpecs$mapping)
unitHarmonisation <- readTable(unitHarmonisationFile, tableSpecs$unitHarmonisation)
targetTable <- readTable(targetTableFile, tableSpecs$targetTable)
harmonisationTable <- readTable(harmonisationTableFile, tableSpecs$harmonisationTable)
propertyMismatchWarning <- readTable(propertyMismatchWarningFile, tableSpecs$propertyMismatchWarning)
propertySharedWarning <- readTable(propertySharedWarningFile, tableSpecs$propertySharedWarning)
lab2cleanUnit <- readTable(lab2cleanUnitFile, tableSpecs$lab2cleanUnit)
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

# unitHarmonisation.tsv
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
# The context is a has_property of the target table, or a concept id of it.
isConceptContext <- grepl("^[0-9]+$", unitHarmonisation$context)
record(
  "unitHarmonisation.tsv", "context is a has_property or a concept_id of targetTable.tsv",
  bad = !is.na(unitHarmonisation$context) & !(
    ifelse(isConceptContext, suppressWarnings(as.integer(unitHarmonisation$context)) %in% conceptIds,
      unitHarmonisation$context %in% c("-", targetTable$has_property))
  ),
  df = unitHarmonisation, what = c("context", "UNIT", "HARMONISED_UNIT")
)

# The HARMONISED_UNIT of the table are the units the target table uses: those of lab2clean, or those
# of the unit overwrite table.
knownTargetUnits <- unique(c(lab2cleanUnit$harmonised_unit, unitOverwrite$harmonised_unit))
record(
  "unitHarmonisation.tsv", "HARMONISED_UNIT is a lab2clean unit (or a unit of the unit overwrite table)",
  bad = !is.na(unitHarmonisation$HARMONISED_UNIT) & !(unitHarmonisation$HARMONISED_UNIT %in% knownTargetUnits),
  df = unitHarmonisation, what = c("context", "UNIT", "HARMONISED_UNIT"),
  extra = paste0(
    dplyr::n_distinct(unitHarmonisation$HARMONISED_UNIT[!is.na(unitHarmonisation$HARMONISED_UNIT) & !(unitHarmonisation$HARMONISED_UNIT %in% knownTargetUnits)]),
    " units not in lab2clean"
  )
)
# The target unit of every approved concept needs a rule in the table: a rule of its has_property
# with that HARMONISED_UNIT, or a rule of the concept itself.
approvedTargets <- harmonisationTable |>
  dplyr::filter(mapping_status %in% c("APPROVED", "ERROR")) |>
  dplyr::distinct(concept_id) |>
  dplyr::inner_join(
    targetTable |> dplyr::distinct(concept_id, has_property, harmonised_unit),
    by = "concept_id"
  ) |>
  dplyr::filter(!is.na(harmonised_unit))
hasRule <- paste(approvedTargets$has_property, approvedTargets$harmonised_unit, sep = "\r") %in%
  paste(unitHarmonisation$context, unitHarmonisation$HARMONISED_UNIT, sep = "\r") |
  paste(approvedTargets$concept_id, approvedTargets$harmonised_unit, sep = "\r") %in%
  paste(unitHarmonisation$context, unitHarmonisation$HARMONISED_UNIT, sep = "\r")
targetUnits <- approvedTargets |> dplyr::mutate(hasRule = hasRule) |>
  dplyr::summarise(hasRule = any(hasRule), nConcepts = dplyr::n(), .by = c(has_property, harmonised_unit))
record(
  "unitHarmonisation.tsv", "the target unit of an approved concept (targetTable.tsv) has a rule for its has_property",
  bad = !targetUnits$hasRule,
  df = targetUnits, what = c("has_property", "harmonised_unit"),
  extra = paste0(sum(targetUnits$nConcepts[!targetUnits$hasRule]), " approved concepts, ", sum(!targetUnits$hasRule), " has_property + unit")
)

# targetTable.tsv
checkTypes("targetTable.tsv", targetTable)
checkHaveValue(
  "targetTable.tsv", targetTable,
  c("concept_id", "concept_code", "concept_name", "vocabulary_id", "is_panel")
)
checkUnique("targetTable.tsv", targetTable, c("concept_id", "group_concept_id"))

# harmonisationTable.tsv
checkTypes("harmonisationTable.tsv", harmonisationTable)
checkUnique("harmonisationTable.tsv", harmonisationTable, c("TEST_NAME", "PREPROCESED_UNIT"))
# The table only appends columns to mapping.tsv joined with unitFix.tsv (a UNIT fixed from
# several PREPROCESED_UNITs takes one row for each). The later joins add no rows, so the row
# count is that of the first join.
nBase <- nrow(
  dplyr::left_join(
    mapping[c("TEST_NAME", "UNIT")],
    unitFix[c("TEST_NAME", "UNIT")],
    by = c("TEST_NAME", "UNIT"),
    relationship = "one-to-many"
  )
)
nOut <- nrow(harmonisationTable)
record(
  "harmonisationTable.tsv", "has as many rows as mapping.tsv joined with unitFix.tsv",
  bad = nOut != nBase,
  n = abs(nOut - nBase),
  text = paste0(
    format(nOut, big.mark = ","), " rows, mapping.tsv joined with unitFix.tsv has ",
    format(nBase, big.mark = ","), " (", format(abs(nOut - nBase), big.mark = ","),
    if (nOut > nBase) " more" else " fewer", ")"
  )
)
record(
  "harmonisationTable.tsv", "every TEST_NAME + UNIT of mapping.tsv is kept",
  bad = !(paste(mapping$TEST_NAME, mapping$UNIT) %in%
    paste(harmonisationTable$TEST_NAME, harmonisationTable$UNIT)),
  df = mapping, what = c("TEST_NAME", "UNIT")
)
record(
  "harmonisationTable.tsv", "concept_id has its attributes, unless there is an ignore_mapping_reason",
  bad = is.na(harmonisationTable$concept_code) & is.na(harmonisationTable$ignore_mapping_reason),
  df = harmonisationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "concept_id")
)
record(
  "harmonisationTable.tsv", "mapping_status is IGNORE, ERROR, APPROVED or NOT-APPROVED",
  bad = !(harmonisationTable$mapping_status %in% c("IGNORE", "ERROR", "APPROVED", "NOT-APPROVED")),
  df = harmonisationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "mapping_status")
)
record(
  "harmonisationTable.tsv", "mapping_status is IGNORE if and only if there is an ignore_mapping_reason",
  bad = (harmonisationTable$mapping_status %in% "IGNORE") != !is.na(harmonisationTable$ignore_mapping_reason),
  df = harmonisationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "mapping_status")
)
record(
  "harmonisationTable.tsv", "a row with mapping_status ERROR has mapping_warning_messages",
  bad = harmonisationTable$mapping_status %in% "ERROR" & is.na(harmonisationTable$mapping_warning_messages),
  df = harmonisationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "mapping_status")
)
record(
  "harmonisationTable.tsv", "a row with a HARMONISED_UNIT has a CONVERSION",
  bad = !is.na(harmonisationTable$HARMONISED_UNIT) & is.na(harmonisationTable$CONVERSION),
  df = harmonisationTable, what = c("TEST_NAME", "PREPROCESED_UNIT", "HARMONISED_UNIT")
)
# The target unit of the concept needs a CONVERSION: an approved pair with a unit whose concept has a
# target unit in targetTable.tsv but no CONVERSION is not harmonised. (The build clears a HARMONISED_UNIT
# without a CONVERSION, so the unit is taken from the target table, not from the output.) A pair with no
# unit cannot be converted by any table, so it is a WARNING of its own.
conceptTargetUnit <- targetTable |> dplyr::distinct(concept_id, targetUnit = harmonised_unit)
notHarmonised <- harmonisationTable |>
  dplyr::filter(mapping_status %in% c("APPROVED", "ERROR")) |>
  dplyr::left_join(conceptTargetUnit, by = "concept_id", relationship = "many-to-one") |>
  dplyr::filter(!is.na(targetUnit), is.na(CONVERSION)) |>
  dplyr::mutate(TARGET = targetUnit)
withUnit <- notHarmonised |> dplyr::filter(!is.na(UNIT))
noUnit <- notHarmonised |> dplyr::filter(is.na(UNIT))
record(
  "harmonisationTable.tsv", "an APPROVED pair with a UNIT whose concept has a target unit has a CONVERSION to it",
  bad = rep(TRUE, nrow(withUnit)),
  df = withUnit, what = c("TEST_NAME", "PREPROCESED_UNIT", "UNIT", "TARGET"),
  extra = paste0(dplyr::n_distinct(withUnit$concept_id), " concepts")
)
record(
  "harmonisationTable.tsv", "an APPROVED pair whose concept has a target unit has a UNIT (no unit cannot be converted)",
  bad = rep(TRUE, nrow(noUnit)),
  df = noUnit, what = c("TEST_NAME", "PREPROCESED_UNIT", "TARGET"),
  extra = paste0(dplyr::n_distinct(noUnit$concept_id), " concepts"), level = "WARNING"
)
# The warning tables: one row per warning, with a message and an `ignore` flag set to TRUE
# by hand to accept the warning.
checkTypes("testname_unit_property_missmatch_warning.tsv", propertyMismatchWarning)
checkHaveValue("testname_unit_property_missmatch_warning.tsv", propertyMismatchWarning, c("TEST_NAME", "message", "ignore"))
checkUnique("testname_unit_property_missmatch_warning.tsv", propertyMismatchWarning, c("TEST_NAME", "UNIT"))
checkTypes("testname_property_shared_warning.tsv", propertySharedWarning)
checkHaveValue("testname_property_shared_warning.tsv", propertySharedWarning, c("TEST_NAME", "message", "ignore"))
checkUnique("testname_property_shared_warning.tsv", propertySharedWarning, c("TEST_NAME", "has_property"))

# A warning that is not marked `ignore` fails: an ERROR if it affects an APPROVED mapping, a
# WARNING if it only affects mappings that are not approved. A warning marked `ignore` is
# neither. A warning is joined to harmonisationTable.tsv on its key and is APPROVED if any
# row it joins to is approved (not ignored by an ignore_mapping_reason). `n rows` is the
# number of warnings (rows of the warning table) of the test.
recordWarnings <- function(table, test, notIgnored, level, examples) {
  n <- nrow(notIgnored)
  results[[length(results) + 1]] <<- tibble::tibble(
    table = table,
    result = ifelse(n == 0, "SUCCESS", level),
    test = test,
    n_rows = if (n > 0) format(n, big.mark = ",", trim = TRUE) else "",
    message = if (n > 0) paste0("e.g. ", paste(utils::head(examples, 3), collapse = "; ")) else ""
  )
}
approvedRow <- harmonisationTable$mapping_status %in% c("APPROVED", "ERROR")
withApproved <- harmonisationTable |> dplyr::mutate(approvedRow = approvedRow)

# A has_property + UNIT without a rule in unitHarmonisation.tsv means the
# property of the mapped concept does not agree with the unit. Joined on TEST_NAME + UNIT.
approvedByPair <- withApproved |>
  dplyr::summarise(approved = any(approvedRow), .by = c(TEST_NAME, UNIT))
mismatch <- propertyMismatchWarning |>
  dplyr::filter(!ignore) |>
  dplyr::inner_join(approvedByPair, by = c("TEST_NAME", "UNIT"), relationship = "one-to-one")
propertyUnitTest <- "has_property + UNIT is in unitHarmonisation.tsv (the concept's property agrees with the unit)"
for (level in c("ERROR", "WARNING")) {
  inLevel <- mismatch[mismatch$approved == (level == "ERROR"), ]
  recordWarnings(
    "harmonisationTable.tsv",
    paste0(propertyUnitTest, if (level == "ERROR") ", for an APPROVED mapping" else ", for a mapping that is not APPROVED"),
    inLevel, level = level,
    examples = formatExamples(inLevel, c("TEST_NAME", "UNIT"))
  )
}

# A TEST_NAME with the same has_property should map to one concept_id. Joined on
# TEST_NAME + has_property.
approvedByProperty <- withApproved |>
  dplyr::summarise(approved = any(approvedRow), .by = c(TEST_NAME, has_property))
shared <- propertySharedWarning |>
  dplyr::filter(!ignore) |>
  dplyr::inner_join(approvedByProperty, by = c("TEST_NAME", "has_property"), relationship = "one-to-one")
sharedTest <- "a TEST_NAME with the same has_property maps to one concept_id"
for (level in c("ERROR", "WARNING")) {
  inLevel <- shared[shared$approved == (level == "ERROR"), ]
  recordWarnings(
    "harmonisationTable.tsv",
    paste0(sharedTest, if (level == "ERROR") ", for an APPROVED mapping" else ", for a mapping that is not APPROVED"),
    inLevel, level = level,
    examples = inLevel$message
  )
}

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
  "Validation of the input and output tables of `4_BuildHarmonisationTable`.",
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
outFile <- file.path(outDir, "harmonisationTableValidation.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
