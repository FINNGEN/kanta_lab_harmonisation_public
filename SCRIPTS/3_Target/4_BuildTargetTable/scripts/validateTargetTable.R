#
# Validates the tables of the 3_Target block: the inputs of the step (the concepts, the lab2clean units
# and Groups, the LOINC Groups and their membership) and the target table it builds. Every test is a
# SUCCESS, a WARNING (a finding that does not break the table) or an ERROR. The report is written to
# targetTable.validation.md; the script stops (non-zero exit) when any test is an ERROR, so the steps
# after it do not run on a broken target.
#
# See this step's README.md for the tests.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
measurementFile <- args[1]
groupsFile <- args[2]
membershipFile <- args[3]
unitFile <- args[4]
lab2cleanGroupFile <- args[5]
targetFile <- args[6]
outDir <- args[7]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  groupsFile = ", groupsFile)
ParallelLogger::logInfo("  membershipFile = ", membershipFile)
ParallelLogger::logInfo("  unitFile = ", unitFile)
ParallelLogger::logInfo("  lab2cleanGroupFile = ", lab2cleanGroupFile)
ParallelLogger::logInfo("  targetFile = ", targetFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
readTsv <- function(file) readr::read_tsv(file, col_types = readr::cols(.default = readr::col_character()), na = "")
measurement <- readTsv(measurementFile)
groups <- readTsv(groupsFile)
membership <- readTsv(membershipFile)
lab2cleanUnit <- readTsv(unitFile)
lab2cleanGroup <- readTsv(lab2cleanGroupFile)
targetTable <- readTsv(targetFile)

#
# --- Action -------------------------------------------------------------
#
results <- list()
# Records one test. `bad` flags the failing rows; `what` names the columns shown as examples.
record <- function(table, test, bad, df = NULL, what = NULL, level = "ERROR", message = NULL) {
  bad[is.na(bad)] <- TRUE
  if (is.null(message)) {
    message <- ""
    if (any(bad) && !is.null(df) && !is.null(what)) {
      rows <- df[bad, what, drop = FALSE]
      examples <- unique(apply(rows, 1, function(r) paste0(what, "=", ifelse(is.na(r), "", r), collapse = " ")))
      message <- paste0("e.g. ", paste(utils::head(examples, 3), collapse = "; "))
    }
  }
  results[[length(results) + 1]] <<- tibble::tibble(
    table = table,
    result = if (any(bad)) level else "SUCCESS",
    test = test,
    n_rows = if (any(bad)) format(sum(bad), big.mark = ",", trim = TRUE) else "",
    message = if (any(bad)) message else ""
  )
}
checkColumns <- function(table, df, columns) {
  record(table, paste0("has the columns ", paste(columns, collapse = ", ")), !all(columns %in% names(df)))
  all(columns %in% names(df))
}
checkHaveValue <- function(table, df, columns) {
  for (col in columns) record(table, paste0(col, " has a value"), is.na(df[[col]]), df, intersect(c("concept_id", "group_concept_id", col), names(df)))
}
checkUnique <- function(table, df, columns) {
  record(table, paste0(paste(columns, collapse = " + "), " are unique"), duplicated(df[columns]) | duplicated(df[columns], fromLast = TRUE), df, columns)
}

# measurementOmopData.tsv: the concepts of the target.
if (checkColumns("measurementOmopData.tsv", measurement, c("concept_id", "concept_code", "concept_name", "vocabulary_id", "is_panel", "has_property"))) {
  checkHaveValue("measurementOmopData.tsv", measurement, c("concept_id", "concept_code", "concept_name", "vocabulary_id"))
  checkUnique("measurementOmopData.tsv", measurement, "concept_id")
  record("measurementOmopData.tsv", "is_panel is TRUE or FALSE", !(measurement$is_panel %in% c("TRUE", "FALSE")), measurement, c("concept_id", "is_panel"))
}

# harmonisedUnit_lab2clean.tsv: one unit per concept of the target.
if (checkColumns("harmonisedUnit_lab2clean.tsv", lab2cleanUnit, c("concept_id", "harmonised_unit"))) {
  checkHaveValue("harmonisedUnit_lab2clean.tsv", lab2cleanUnit, c("concept_id", "harmonised_unit"))
  checkUnique("harmonisedUnit_lab2clean.tsv", lab2cleanUnit, "concept_id")
  record(
    "harmonisedUnit_lab2clean.tsv", "concept_id is in measurementOmopData.tsv",
    !(lab2cleanUnit$concept_id %in% measurement$concept_id), lab2cleanUnit, c("concept_id", "harmonised_unit")
  )
}

# harmonisedGroup_lab2clean.tsv: at most one Group per concept, every one of them a membership of the
# LOINC Groups (otherwise group_source = lab2clean is lost).
if (checkColumns("harmonisedGroup_lab2clean.tsv", lab2cleanGroup, c("concept_id", "group_concept_code"))) {
  checkHaveValue("harmonisedGroup_lab2clean.tsv", lab2cleanGroup, c("concept_id", "group_concept_code"))
  checkUnique("harmonisedGroup_lab2clean.tsv", lab2cleanGroup, "concept_id")
  record(
    "harmonisedGroup_lab2clean.tsv", "concept_id is in measurementOmopData.tsv",
    !(lab2cleanGroup$concept_id %in% measurement$concept_id), lab2cleanGroup, c("concept_id", "group_concept_code")
  )
  membershipCodes <- membership |>
    dplyr::inner_join(groups, by = "group_concept_id") |>
    dplyr::transmute(key = paste(concept_id, group_concept_code))
  record(
    "harmonisedGroup_lab2clean.tsv", "every concept + Group is a membership of loincGroupMembership.tsv",
    !(paste(lab2cleanGroup$concept_id, lab2cleanGroup$group_concept_code) %in% membershipCodes$key),
    lab2cleanGroup, c("concept_id", "group_concept_code")
  )
}

# loincGroups.tsv and loincGroupMembership.tsv: the LOINC Groups and who is in them.
if (checkColumns("loincGroups.tsv", groups, c("group_concept_id", "group_concept_code", "group_concept_name"))) {
  checkHaveValue("loincGroups.tsv", groups, c("group_concept_id", "group_concept_code", "group_concept_name"))
  checkUnique("loincGroups.tsv", groups, "group_concept_id")
  checkUnique("loincGroups.tsv", groups, "group_concept_code")
  record(
    "loincGroups.tsv", "every Group has a member in loincGroupMembership.tsv",
    !(groups$group_concept_id %in% membership$group_concept_id), groups, c("group_concept_id", "group_concept_code")
  )
}
if (checkColumns("loincGroupMembership.tsv", membership, c("concept_id", "group_concept_id"))) {
  checkHaveValue("loincGroupMembership.tsv", membership, c("concept_id", "group_concept_id"))
  checkUnique("loincGroupMembership.tsv", membership, c("concept_id", "group_concept_id"))
  record(
    "loincGroupMembership.tsv", "group_concept_id is in loincGroups.tsv",
    !(membership$group_concept_id %in% groups$group_concept_id), membership, c("concept_id", "group_concept_id")
  )
  record(
    "loincGroupMembership.tsv", "concept_id is in measurementOmopData.tsv",
    !(membership$concept_id %in% measurement$concept_id), membership, c("concept_id", "group_concept_id")
  )
  record(
    "loincGroupMembership.tsv", "a panel is in no Group",
    membership$concept_id %in% measurement$concept_id[measurement$is_panel %in% "TRUE"], membership, c("concept_id", "group_concept_id")
  )
}

# targetTable.tsv: the table the step builds.
inGroup <- dplyr::filter(targetTable, !is.na(group_concept_id))
checkUnique("targetTable.tsv", targetTable, c("concept_id", "group_concept_id"))
severalGroups <- dplyr::count(targetTable, concept_id) |> dplyr::filter(n > 1)
record(
  "targetTable.tsv", "concept_id is unique (a concept in several Groups has one row per Group)",
  targetTable$concept_id %in% severalGroups$concept_id, targetTable, "concept_id", level = "WARNING",
  message = paste0(format(nrow(severalGroups), big.mark = ","), " concepts in several Groups")
)
groupUnitsOf <- function(df) df |>
  dplyr::filter(!is.na(harmonised_unit)) |>
  dplyr::summarise(
    units = paste(sort(unique(harmonised_unit)), collapse = ", "),
    n_units = dplyr::n_distinct(harmonised_unit),
    n_concepts = dplyr::n_distinct(concept_id),
    .by = c(group_concept_id, group_concept_code)
  )
lab2cleanGroupUnits <- groupUnitsOf(dplyr::filter(inGroup, group_source == "lab2clean"))
groupUnits <- groupUnitsOf(inGroup)
record(
  "targetTable.tsv", "all concepts of a lab2clean Group have the same harmonised_unit",
  lab2cleanGroupUnits$n_units > 1, lab2cleanGroupUnits, c("group_concept_code", "units")
)
record(
  "targetTable.tsv", "all concepts of a Group (lab2clean or LOINC) have the same harmonised_unit",
  groupUnits$n_units > 1, groupUnits, c("group_concept_code", "units"), level = "WARNING"
)

results <- dplyr::bind_rows(results)
nError <- sum(results$result == "ERROR")
ParallelLogger::logInfo(
  nrow(results), " tests: ", sum(results$result == "SUCCESS"), " SUCCESS, ",
  sum(results$result == "WARNING"), " WARNING, ", nError, " ERROR"
)
for (i in which(results$result != "SUCCESS")) {
  ParallelLogger::logWarn(results$result[i], ": ", results$table[i], ": ", results$test[i], ": ", results$n_rows[i], " rows, ", results$message[i])
}

#
# --- Output -------------------------------------------------------------
#
cell <- function(x) gsub("\\|", "\\\\|", x)
countResults <- function(df) {
  c(SUCCESS = sum(df$result == "SUCCESS"), WARNING = sum(df$result == "WARNING"), ERROR = sum(df$result == "ERROR"))
}
summaryByTable <- do.call(rbind, lapply(unique(results$table), function(tbl) c(table = tbl, countResults(results[results$table == tbl, ]))))
summaryTable <- rbind(summaryByTable, c(table = "ALL", countResults(results)))
mixedGroups <- dplyr::filter(groupUnits, n_units > 1) |> dplyr::arrange(group_concept_code)

md <- c(
  "# targetTable validation",
  "",
  "Validation of the tables of `3_Target`: the inputs of `4_BuildTargetTable` and `targetTable.tsv`. ",
  "The step stops when a test is an ERROR.",
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
  paste0("| ", cell(results$table), " | ", results$result, " | ", cell(results$test), " | ", results$n_rows, " | ", cell(results$message), " |"),
  if (nrow(mixedGroups) > 0) {
    c(
      "",
      "## Groups with more than one harmonised_unit",
      "",
      "| group | n concepts | units |",
      "| --- | --- | --- |",
      paste0("| ", mixedGroups$group_concept_code, " | ", mixedGroups$n_concepts, " | ", cell(mixedGroups$units), " |")
    )
  }
)
outFile <- file.path(outDir, "targetTable.validation.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)

if (nError > 0) {
  stop(nError, " validation tests failed, see ", outFile)
}
