#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
evaluatedFile <- args[1]
unitFixFile <- args[2]
mismatchWarningFile <- args[3]
sharedWarningFile <- args[4]
contextUnitMissingWarningFile <- args[5]
loincGroupUnitMismatchWarningFile <- args[6]
measurementFile <- args[7]
targetFile <- args[8]
settingsFile <- args[9]
ksWarningFile <- args[10]
changesFile <- args[11]
outDir <- args[12]

# The scripts folder of this step, where the HTML template is.
scriptDir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
templateFile <- file.path(scriptDir, "dashboardTemplate.html")
pathToDashboard <- file.path(outDir, "dashboard.html")

# The no-value thresholds (a pair under either has no values) and the KS thresholds (AGREE under
# ksAgree, DISAGREE over ksDisagree, WARNING in between) come from DATA/settings.yaml, as in
# 5_EvaluateHarmonisedData. The settings of the repo (DATA/settings.yaml), one section per block or step.
readSetting <- function(settingsFile, section, key) {
  value <- yaml::read_yaml(settingsFile)[[section]][[key]]
  if (!is.numeric(value) || length(value) != 1) stop(section, ": ", key, " is missing or not a number in ", settingsFile)
  value
}
minValues <- readSetting(settingsFile, "1_Input", "n_records_no_value_threshold")
minSubjects <- readSetting(settingsFile, "1_Input", "n_subjects_no_value_threshold")
ksAgree <- readSetting(settingsFile, "5_EvaluateHarmonisedData", "ks_agree_threshold")
ksDisagree <- readSetting(settingsFile, "5_EvaluateHarmonisedData", "ks_disagree_threshold")
# The GitHub repository the Change Log column links to.
githubUrl <- sub("/+$", "", yaml::read_yaml(settingsFile)[["7_BuildDashboard"]][["github_url"]])
if (!is.character(githubUrl) || length(githubUrl) != 1) stop("7_BuildDashboard: github_url is missing in ", settingsFile)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  evaluatedFile = ", evaluatedFile)
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  mismatchWarningFile = ", mismatchWarningFile)
ParallelLogger::logInfo("  sharedWarningFile = ", sharedWarningFile)
ParallelLogger::logInfo("  contextUnitMissingWarningFile = ", contextUnitMissingWarningFile)
ParallelLogger::logInfo("  loincGroupUnitMismatchWarningFile = ", loincGroupUnitMismatchWarningFile)
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  targetFile = ", targetFile)
ParallelLogger::logInfo("  templateFile = ", templateFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  ksAgree = ", ksAgree)
ParallelLogger::logInfo("  ksDisagree = ", ksDisagree)
ParallelLogger::logInfo("  changesFile = ", changesFile)
ParallelLogger::logInfo("  githubUrl = ", githubUrl)

#
# --- Input -------------------------------------------------------------
#
chr <- readr::col_character
evaluated <- readr::read_tsv(
  evaluatedFile,
  col_types = readr::cols(
    mapping_status = chr(), harmonisation_values_status = chr(), TEST_NAME = chr(), MEASUREMENT_UNIT = chr(), UNIT = chr(),
    n = readr::col_double(),
    n_subjects = readr::col_double(),
    unit_source_injection_correction_na_p = chr(),
    reference_range = chr(),
    test_outcome = chr(),
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = chr(),
    decile_value = chr(), decile_value_harmonised = chr(), reference_decile_value_harmonised = chr(),
    unit_fix_reasoning = chr(), concept_id = readr::col_integer(), ignore_mapping_reason = chr(),
    concept_code = chr(), concept_name = chr(), vocabulary_id = chr(), is_panel = readr::col_logical(),
    has_component = chr(), has_property = chr(),
    group_concept_id = chr(), group_concept_code = chr(), group_concept_name = chr(),
    target_unit = chr(), target_unit_source = chr(), HARMONISED_UNIT = chr(), CONVERSION = chr(), mapping_warning_messages = chr(),
    KS = readr::col_double(), KS_mlp = readr::col_double(), log10_D5 = readr::col_double(),
    in_reference = readr::col_logical(), reference_type = chr(), reference_group_concept_id = chr(), n_reference_pairs = readr::col_integer()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(evaluated), " rows from ", evaluatedFile)
evaluated <- evaluated |>
  dplyr::arrange(dplyr::desc(n), TEST_NAME, MEASUREMENT_UNIT, UNIT)
unitFix <- readr::read_tsv(unitFixFile, col_types = readr::cols(.default = chr()), na = "")
mismatchWarnings <- readr::read_tsv(mismatchWarningFile, col_types = readr::cols(.default = chr(), ignore = readr::col_logical()), na = "")
sharedWarnings <- readr::read_tsv(sharedWarningFile, col_types = readr::cols(.default = chr(), ignore = readr::col_logical()), na = "")
contextUnitMissingWarnings <- readr::read_tsv(contextUnitMissingWarningFile, col_types = readr::cols(.default = chr(), ignore = readr::col_logical()), na = "")
loincGroupUnitMismatchWarnings <- readr::read_tsv(loincGroupUnitMismatchWarningFile, col_types = readr::cols(.default = chr(), ignore = readr::col_logical()), na = "")
ksWarnings <- readr::read_tsv(ksWarningFile, col_types = readr::cols(.default = chr(), ignore = readr::col_logical()), na = "")
measurement <- readr::read_tsv(measurementFile, col_types = readr::cols(.default = chr()), na = "")
targetTable <- readr::read_tsv(targetFile, col_types = readr::cols(.default = chr()), na = "")
changes <- readr::read_tsv(changesFile, col_types = readr::cols(.default = chr()), na = "")
template <- paste(readLines(templateFile, encoding = "UTF-8"), collapse = "\n")

#
# --- Action -------------------------------------------------------------
#
fmtInt <- function(x) format(round(x), big.mark = ",", scientific = FALSE, trim = TRUE)
fmtPct <- function(x) sprintf("%.2f%%", x)
esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}
htmlTable <- function(header, rows, numericFrom = 2, totalLast = TRUE, rowClasses = NULL) {
  cells <- function(tag, values, class = "") {
    cls <- ifelse(seq_along(values) >= numericFrom, " class=\"num\"", "")
    paste0("<", tag, cls, ">", values, "</", tag, ">", collapse = "")
  }
  body <- vapply(seq_len(nrow(rows)), function(i) {
    last <- totalLast && i == nrow(rows)
    rowClass <- if (last) "total" else if (!is.null(rowClasses) && i <= length(rowClasses)) rowClasses[i] else ""
    paste0("<tr", if (nzchar(rowClass)) paste0(" class=\"", rowClass, "\""), ">", cells("td", unlist(rows[i, ], use.names = FALSE)), "</tr>")
  }, character(1))
  paste0("<table class=\"summary\"><thead><tr>", cells("th", header), "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody></table>")
}
statusSpan <- function(status) paste0("<span class=\"st st-", sub(":.*", "", status), "\">", status, "</span>")

# 1. Harmonised events: the pairs (TEST_NAME + MEASUREMENT_UNIT), their records, and the pairs
#    with a warning message, by mapping_status.
# An ERROR carries its reason (ERROR:<reason>); this table counts them all as ERROR, the next one by reason.
statusOrder <- c("APPROVED", "NOT-APPROVED", "IGNORE", "MISSING", "ERROR")
errorReasons <- tibble::tribble(
  ~reason, ~label,
  "MissingConceptId", "Missing concept_id",
  "MissingConversion", "Missing conversion",
  "PropertyUnitMismatch", "Property and unit mismatch",
  "SharedProperty", "Shared property",
  "LoincGroupUnitsMissmatch", "LOINC Group units mismatch"
)
# Each pair has at most one warning of each warning table; a warning is not ignored when its
# `ignore` is FALSE. A pair that is not in the harmonisation table (MISSING) has none. An empty
# UNIT matches an empty UNIT, as in 4_BuildHarmonisationTable.
isMapped <- evaluated$mapping_status != "MISSING"
warningOf <- function(table, by) {
  hit <- dplyr::left_join(
    dplyr::select(evaluated, dplyr::all_of(names(by))), dplyr::select(table, dplyr::all_of(unname(by)), ignore),
    by = by, na_matches = "na"
  )
  list(total = isMapped & !is.na(hit$ignore), notIgnored = isMapped & hit$ignore %in% FALSE)
}
warnings <- list(
  warningOf(mismatchWarnings, c(TEST_NAME = "TEST_NAME", UNIT = "UNIT")),
  warningOf(sharedWarnings, c(TEST_NAME = "TEST_NAME", has_property = "has_property")),
  warningOf(contextUnitMissingWarnings, c(TEST_NAME = "TEST_NAME", UNIT = "UNIT")),
  warningOf(loincGroupUnitMismatchWarnings, c(TEST_NAME = "TEST_NAME", UNIT = "UNIT"))
)
evaluated$n_warnings <- Reduce(`+`, lapply(warnings, `[[`, "total"))
evaluated$n_warnings_not_ignored <- Reduce(`+`, lapply(warnings, `[[`, "notIgnored"))
stopifnot(identical(evaluated$n_warnings > 0, !is.na(evaluated$mapping_warning_messages)))
events <- evaluated |>
  dplyr::summarise(
    pairs = dplyr::n(), records = sum(n),
    warnings = sum(n_warnings), warnings_not_ignored = sum(n_warnings_not_ignored),
    .by = mapping_status
  ) |>
  dplyr::mutate(mapping_status = sub(":.*", "", mapping_status)) |>
  dplyr::summarise(dplyr::across(dplyr::everything(), sum), .by = mapping_status) |>
  dplyr::right_join(tibble::tibble(mapping_status = statusOrder), by = "mapping_status") |>
  dplyr::mutate(dplyr::across(-mapping_status, \(x) dplyr::coalesce(x, 0))) |>
  dplyr::arrange(match(mapping_status, statusOrder))
totalRecords <- sum(events$records)
eventsTable <- htmlTable(
  c("Status", "Warnings(total)", "Number of test+unit combinations", "Number of records", "Percentage of records"),
  dplyr::bind_rows(
    events |>
      dplyr::transmute(
        statusSpan(mapping_status), paste0(fmtInt(warnings_not_ignored), " (", fmtInt(warnings), ")"), fmtInt(pairs), fmtInt(records),
        fmtPct(100 * records / totalRecords)
      ) |>
      rlang::set_names(paste0("c", 1:5)),
    tibble::tibble(
      c1 = "TOTAL", c2 = paste0(fmtInt(sum(events$warnings_not_ignored)), " (", fmtInt(sum(events$warnings)), ")"), c3 = fmtInt(sum(events$pairs)),
      c4 = fmtInt(totalRecords), c5 = "100.00%"
    )
  )
)
ParallelLogger::logInfo(
  paste0(events$mapping_status, " ", events$pairs, collapse = ", "), " pairs; ", fmtInt(totalRecords), " records"
)

# 1b. Errors: the ERROR pairs by reason, only when there are any.
errors <- evaluated |>
  dplyr::filter(startsWith(mapping_status, "ERROR:")) |>
  dplyr::mutate(reason = sub("^ERROR:", "", mapping_status)) |>
  dplyr::summarise(pairs = dplyr::n(), records = sum(n), .by = reason)
stopifnot(all(errors$reason %in% errorReasons$reason))
errorsTable <- if (nrow(errors) == 0) "" else {
  errorRows <- errorReasons |>
    dplyr::inner_join(errors, by = "reason")
  paste0(
    "<h2>Errors</h2><div class=\"card\">",
    htmlTable(
      c("Status", "Reason", "Number of test+unit combinations", "Number of records", "Percentage of records"),
      dplyr::bind_rows(
        errorRows |>
          dplyr::transmute(statusSpan(paste0("ERROR:", reason)), label, fmtInt(pairs), fmtInt(records), fmtPct(100 * records / totalRecords)) |>
          rlang::set_names(paste0("c", 1:5)),
        tibble::tibble(
          c1 = "TOTAL", c2 = "", c3 = fmtInt(sum(errorRows$pairs)), c4 = fmtInt(sum(errorRows$records)),
          c5 = fmtPct(100 * sum(errorRows$records) / totalRecords)
        )
      ),
      numericFrom = 3
    ),
    "</div><p class=\"note\">The approved pairs with an error, by reason (the first that applies, in this order): ",
    "the concept_id is not in the target table; the property of the concept does not agree with the unit, or the TEST_NAME ",
    "shares a property with another concept (a warning not marked <code>ignore</code>); the pair has a UNIT but no CONVERSION ",
    "from it to the target unit (a pair with no UNIT is not converted, so it is no error); a LOINC Group of ",
    "the concept has approved pairs with different target units. The percentage is of all the records.</p>"
  )
}
ParallelLogger::logInfo(nrow(errors), " error reasons, ", sum(errors$pairs), " ERROR pairs")

# Input data tab: the tables of 1_Input/1_BuildKantaAgregatedTable/kantaAgregatedTable.summary.md, from the
# same pairs (the evaluated table has one row per pair, with the same n and source columns).
fmtPct1 <- function(x) sprintf("%.1f%%", x)
nPairs <- nrow(evaluated)
inputRecords <- sum(evaluated$n)
inputTable <- function(header, keys, counts) {
  # keys: tibble of the leading label columns; counts: n_rows and n_records per row of keys
  htmlTable(
    c(header, "n rows", "% rows", "n records", "% rec"),
    dplyr::bind_rows(
      dplyr::bind_cols(
        keys,
        tibble::tibble(
          nr = fmtInt(counts$n_rows), pr = fmtPct1(100 * counts$n_rows / nPairs),
          nrec = fmtInt(counts$n_records), prec = fmtPct1(100 * counts$n_records / inputRecords)
        )
      ) |> rlang::set_names(paste0("c", seq_len(ncol(keys) + 4))),
      tibble::as_tibble(
        c(as.list(c("total", rep("", ncol(keys) - 1))), list(fmtInt(nPairs), "100%", fmtInt(inputRecords), "100%")),
        .name_repair = function(x) paste0("c", seq_along(x))
      )
    ),
    numericFrom = ncol(keys) + 1
  )
}
# Name / unit / value coverage. The name is always X: the pairs without a TEST_NAME are dropped upstream.
coverage <- evaluated |>
  dplyr::mutate(
    hasUnit = !is.na(MEASUREMENT_UNIT) & nzchar(MEASUREMENT_UNIT),
    hasValue = is.na(value_missing_p) | value_missing_p < 100
  ) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .by = c(hasUnit, hasValue)) |>
  dplyr::right_join(tidyr::expand_grid(hasUnit = c(TRUE, FALSE), hasValue = c(TRUE, FALSE)), by = c("hasUnit", "hasValue")) |>
  dplyr::mutate(dplyr::across(c(n_rows, n_records), \(x) dplyr::coalesce(x, 0))) |>
  dplyr::arrange(dplyr::desc(hasUnit), dplyr::desc(hasValue))
coverageHtml <- inputTable(
  c("name", "unit", "value"),
  tibble::tibble(a = "X", b = ifelse(coverage$hasUnit, "X", ""), c = ifelse(coverage$hasValue, "X", "")),
  coverage
)
# Where the unit / value of the records came from: a pair counts in a source when more than 0% of its records do.
sourceHtml <- function(column, labels) {
  shares <- evaluated[[column]] |>
    stringr::str_remove_all("[\\[\\]%]") |>
    stringr::str_split_fixed(",", length(labels)) |>
    apply(2, as.numeric)
  counts <- tibble::tibble(
    n_rows = vapply(seq_along(labels), \(k) sum(shares[, k] > 0), numeric(1)),
    n_records = vapply(seq_along(labels), \(k) round(sum(evaluated$n * shares[, k] / 100)), numeric(1))
  )
  inputTable("source", tibble::tibble(source = labels), counts)
}
unitSourceHtml <- sourceHtml("unit_source_injection_correction_na_p", c("Source", "PrimaryInjection", "SecondaryCorrection", ""))
valueSourceHtml <- sourceHtml("value_source_extracted_qcout_na_p", c("Source", "Extracted", "QCOut", ""))
# Reference ranges: one row per combination of demographic bins.
bins <- c("AF", "AM", "MF", "MM")
refRanges <- evaluated
for (b in bins) refRanges[[b]] <- stringr::str_detect(tidyr::replace_na(evaluated$reference_range, ""), paste0(b, "\\["))
refRanges <- refRanges |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .by = dplyr::all_of(bins)) |>
  dplyr::arrange(dplyr::desc(n_rows))
refRangeHtml <- inputTable(
  bins,
  dplyr::mutate(refRanges[bins], dplyr::across(dplyr::everything(), \(x) ifelse(x, "X", ""))),
  refRanges
)
# Test outcomes: one row per combination of TEST_OUTCOME, one column per outcome.
outcomeLists <- lapply(stringr::str_match_all(tidyr::replace_na(evaluated$test_outcome, ""), "([^;\\[]+)\\["), \(m) m[, 2])
outcomes <- unique(unlist(outcomeLists))
outcomeOrder <- c("N", "A", "AA", "L", "LL", "H", "HH", "POS", "NEG", "IND", "I")
outcomes <- c(intersect(outcomeOrder, outcomes), sort(setdiff(outcomes, outcomeOrder)))
testOutcomes <- tibble::as_tibble(stats::setNames(lapply(outcomes, \(o) vapply(outcomeLists, \(l) o %in% l, logical(1))), outcomes)) |>
  dplyr::mutate(n = evaluated$n) |>
  dplyr::summarise(n_rows = dplyr::n(), n_records = sum(n), .by = dplyr::all_of(outcomes)) |>
  dplyr::arrange(dplyr::desc(n_rows))
testOutcomeHtml <- inputTable(
  outcomes,
  dplyr::mutate(testOutcomes[outcomes], dplyr::across(dplyr::everything(), \(x) ifelse(x, "X", ""))),
  testOutcomes
)
inputSections <- paste0(
  "<h2>Name Unit Value combinations</h2><div class=\"card\">", coverageHtml, "</div>",
  "<p class=\"note\">Name / unit / value coverage of the Kanta aggregated table, one row per <code>TEST_NAME</code> + <code>MEASUREMENT_UNIT</code> pair. An <code>X</code> under unit means the pair has a recorded unit; under value, that at least one of its records has a value.</p>",
  "<h2>Units</h2><div class=\"card\">", unitSourceHtml, "</div>",
  "<p class=\"note\">Where the unit of the records came from. A pair counts in a source when some of its records come from it, so % rows does not add up to 100%. n records is approximate (shares are rounded). The empty source is the records with no unit source.</p>",
  "<h2>Values</h2><div class=\"card\">", valueSourceHtml, "</div>",
  "<p class=\"note\">Where the value of the records came from. The empty source is the records with no value. Same counting as Units.</p>",
  "<h2>Reference Ranges</h2><div class=\"card\">", refRangeHtml, "</div>",
  "<p class=\"note\">Combinations of demographic bins with a reference range: AF adult female, AM adult male, MF minor female, MM minor male. An X means the pair has a range for that bin; the row with no X has no reference range.</p>",
  "<h2>Test Outcomes</h2><div class=\"card\">", testOutcomeHtml, "</div>",
  "<p class=\"note\">Combinations of test outcomes: N normal, A abnormal, L / H low / high, AA / LL / HH very abnormal / low / high, POS / NEG positive / negative. An X means some records of the pair have that outcome; the row with no X has no test outcome.</p>"
)

# Target data tab: the tables of 3_Target/4_BuildTargetTable/targetTable.summary.md and targetTable.validation.md.
concepts <- dplyr::distinct(targetTable, concept_id, is_panel, harmonised_unit, harmonised_unit_source)
nConcepts <- nrow(concepts)
nSource <- function(x) sum(concepts$harmonised_unit_source %in% x)
conceptRows <- tibble::tibble(
  step = c(
    "concepts in measurementOmopData.tsv", "concepts in the table",
    "panel (no unit)", "isQualitative (no unit)", "unit from lab2clean",
    "no unit (not in lab2clean)"
  ),
  n = c(
    nrow(measurement), nConcepts,
    nSource("panel"), nSource("isQualitative"), nSource("lab2clean"),
    sum(is.na(concepts$harmonised_unit_source))
  )
) |>
  dplyr::mutate(
    pct = dplyr::if_else(dplyr::row_number() <= 1, "", fmtPct1(100 * n / nConcepts)),
    n = fmtInt(n)
  )
conceptsHtml <- htmlTable(c("step", "n concepts", "% concepts in the table"), conceptRows, totalLast = FALSE)

inGroup <- dplyr::filter(targetTable, !is.na(group_concept_id))
nGroups <- dplyr::n_distinct(inGroup$group_concept_id)
nInGroup <- dplyr::n_distinct(inGroup$concept_id)
groupHtml <- htmlTable(
  c("item", "n"),
  tibble::tibble(
    item = c("Groups", "concepts in a Group", "concepts in no Group", "concepts in more than one Group"),
    n = fmtInt(c(nGroups, nInGroup, nConcepts - nInGroup, sum(dplyr::count(inGroup, concept_id)$n > 1)))
  ),
  totalLast = FALSE
)
groupSourceHtml <- htmlTable(
  c("group_source", "n concept-Group rows", "n Groups", "n concepts"),
  inGroup |>
    dplyr::summarise(
      n_rows = dplyr::n(), n_groups = dplyr::n_distinct(group_concept_id), n_concepts = dplyr::n_distinct(concept_id),
      .by = group_source
    ) |>
    dplyr::arrange(group_source) |>
    dplyr::transmute(group_source, fmtInt(n_rows), fmtInt(n_groups), fmtInt(n_concepts)),
  totalLast = FALSE
)

nDuplicatedPairs <- sum(duplicated(targetTable[c("concept_id", "group_concept_id")]))
nSeveralGroups <- sum(dplyr::count(targetTable, concept_id)$n > 1)
groupUnitsOf <- function(df) df |>
  dplyr::filter(!is.na(harmonised_unit)) |>
  dplyr::summarise(
    units = paste(sort(unique(harmonised_unit)), collapse = ", "),
    n_units = dplyr::n_distinct(harmonised_unit), n_concepts = dplyr::n_distinct(concept_id),
    .by = c(group_concept_id, group_concept_code)
  ) |>
  dplyr::filter(n_units > 1)
groupUnits <- groupUnitsOf(inGroup)
lab2cleanGroupUnits <- groupUnitsOf(dplyr::filter(inGroup, group_source == "lab2clean"))
validations <- tibble::tribble(
  ~result, ~test, ~message,
  dplyr::if_else(nDuplicatedPairs == 0, "SUCCESS", "ERROR"),
  "concept_id and Group are unique",
  paste0(fmtInt(nDuplicatedPairs), " duplicated (concept_id, Group) rows"),
  dplyr::if_else(nSeveralGroups == 0, "SUCCESS", "WARNING"),
  "concept_id is unique",
  paste0(fmtInt(nSeveralGroups), " concepts have one row per Group (in several Groups)"),
  dplyr::if_else(nrow(lab2cleanGroupUnits) == 0, "SUCCESS", "ERROR"),
  "all concepts of a lab2clean Group have the same harmonised_unit",
  paste0(
    fmtInt(nrow(lab2cleanGroupUnits)), " of ", fmtInt(dplyr::n_distinct(inGroup$group_concept_id[inGroup$group_source == "lab2clean"])),
    " lab2clean Groups have more than one unit"
  ),
  dplyr::if_else(nrow(groupUnits) == 0, "SUCCESS", "WARNING"),
  "all concepts of a Group (lab2clean or LOINC) have the same harmonised_unit",
  paste0(fmtInt(nrow(groupUnits)), " of ", fmtInt(nGroups), " Groups have more than one unit")
)
validationClass <- c(SUCCESS = "st-APPROVED", WARNING = "st-NOT-APPROVED", ERROR = "st-ERROR")
validationsHtml <- htmlTable(
  c("result", "test", "message"),
  dplyr::mutate(validations, result = paste0("<span class=\"st ", validationClass[result], "\">", result, "</span>")),
  numericFrom = 99, totalLast = FALSE
)
groupUnitsHtml <- if (nrow(groupUnits) > 0) {
  paste0(
    "<p class=\"note\">Groups with more than one <code>harmonised_unit</code> (units of the concepts that have one):</p>",
    "<div class=\"card scroll\">",
    htmlTable(
      c("group", "n concepts", "units"),
      dplyr::transmute(groupUnits, group_concept_code, n_concepts, esc(units)),
      numericFrom = 99, totalLast = FALSE
    ),
    "</div>"
  )
} else ""
targetSections <- paste0(
  "<p class=\"note\">", fmtInt(nrow(targetTable)), " rows of <code>targetTable.tsv</code>, one per concept and Group, for ",
  fmtInt(nConcepts), " concepts.</p>",
  "<h2>Concepts</h2><div class=\"card\">", conceptsHtml, "</div>",
  "<p class=\"note\">Where the <code>harmonised_unit</code> of each concept came from.</p>",
  "<h2>Groups</h2><div class=\"card\">", groupHtml, "</div>",
  "<div class=\"card\" style=\"margin-top:10px\">", groupSourceHtml, "</div>",
  "<p class=\"note\">Where the Group of a concept came from (group_source): lab2clean when lab2clean gives the concept that Group, LOINC for the other memberships.</p>",
  "<h2>Validations</h2><div class=\"card\">", validationsHtml, "</div>",
  groupUnitsHtml
)

# 0. Fixed units: the pairs whose MEASUREMENT_UNIT was changed to a different UNIT (only a mapped
#    pair has the fix applied), in one row.
isUnitFixed <- evaluated$mapping_status != "MISSING" &
  tidyr::replace_na(evaluated$MEASUREMENT_UNIT, "") != tidyr::replace_na(evaluated$UNIT, "")
nFixes <- nrow(unitFix)
fixedPairs <- sum(isUnitFixed)
fixedRecords <- sum(evaluated$n[isUnitFixed])
fixedTable <- htmlTable(
  c("", "Number of test+unit fixes", "Number of test+unit fixed", "Number of records", "Percentage of records"),
  tibble::tibble(
    c1 = "Fixed units", c2 = fmtInt(nFixes), c3 = fmtInt(fixedPairs), c4 = fmtInt(fixedRecords),
    c5 = fmtPct(100 * fixedRecords / sum(evaluated$n))
  ),
  totalLast = FALSE
)
ParallelLogger::logInfo(fixedPairs, " pairs with a fixed unit, ", fmtInt(fixedRecords), " records")

# An approved pair whose concept has no target unit (a qualitative concept, a panel, or a concept with no
# unit) is not compared: shown grey.
noTargetUnit <- evaluated$mapping_status %in% "APPROVED" & is.na(evaluated$target_unit)

# 2. Harmonised values: one row per harmonisation_values_status, in this order, with its label and style.
notCompared <- function(class) paste0("<span class=\"ks ", class, "\">Not compared</span>: ")
valueRows <- tibble::tribble(
  ~valueClass, ~status, ~label, ~rowClass,
  "AGREE", "AGREE", paste0("<span class=\"ks agree\">AGREE</span> KS &lt; ", ksAgree), "",
  "WARNING", "WARNING", paste0("<span class=\"ks warn\">WARNING</span> ", ksAgree, " &le; KS &le; ", ksDisagree), "",
  "DISAGREE", "DISAGREE", paste0("<span class=\"ks dis\">DISAGREE</span> KS &gt; ", ksDisagree), "",
  "no_unit", "Error: values with missing units", "<span class=\"ks dis\">Error</span>: values with missing units", "",
  "no_reference", "Not compared: only one pair per group", "Not compared: only one pair per group", "row-grey",
  "qualitative_panel", "No value: value ignored, is qualitative or panel", "No value: value ignored, is qualitative or panel", "row-grey",
  "no_values", paste0("No value: fewer than ", minValues, " values or ", minSubjects, " subjects"), paste0("No value: fewer than ", minValues, " values or ", minSubjects, " subjects"), "row-grey",
  "not_approved", "Not mapped (NOT-APPROVED, IGNORE, MISSING or ERROR)", "Not mapped (NOT-APPROVED, IGNORE, MISSING or ERROR)", "row-grey"
)
# The status of each pair is its harmonisation_values_status, set by 5_EvaluateHarmonisedData: one of
# the `status` of valueRows (the KS thresholds must match that step).
pairValueClass <- valueRows$valueClass[match(evaluated$harmonisation_values_status, valueRows$status)]
stopifnot(!anyNA(pairValueClass))
# The KS warnings of 5_EvaluateHarmonisedData (ks_test_warning.tsv): a pair has one when it is a
# WARNING or DISAGREE; it is not ignored when its `ignore` is FALSE.
ksHit <- dplyr::left_join(
  dplyr::select(evaluated, TEST_NAME, MEASUREMENT_UNIT, harmonisation_values_status),
  dplyr::select(ksWarnings, TEST_NAME, MEASUREMENT_UNIT, harmonisation_values_status, ignore),
  by = c("TEST_NAME", "MEASUREMENT_UNIT", "harmonisation_values_status"), na_matches = "na"
)
valueClass <- tibble::tibble(
  valueClass = pairValueClass, n = evaluated$n,
  ksWarning = !is.na(ksHit$ignore), ksWarningNotIgnored = ksHit$ignore %in% FALSE
) |>
  dplyr::summarise(
    pairs = dplyr::n(), records = sum(n),
    warnings = sum(ksWarning), warnings_not_ignored = sum(ksWarningNotIgnored),
    .by = valueClass
  )
valueRows <- valueRows |>
  dplyr::left_join(valueClass, by = "valueClass") |>
  dplyr::mutate(dplyr::across(c(pairs, records, warnings, warnings_not_ignored), \(x) dplyr::coalesce(x, 0)))
stopifnot(sum(valueRows$records) == totalRecords)
# The values status of each pair, shown under its mapping status in the Mapping Table: a short label
# and its style (the colour of its row in the Harmonised Values table).
valueStatus <- tibble::tribble(
  ~valueClass, ~short, ~style,
  "AGREE", "AGREE", "ks agree",
  "WARNING", "WARNING", "ks warn",
  "DISAGREE", "DISAGREE", "ks dis",
  "no_unit", "Error: values with missing units", "ks dis",
  "no_reference", "Not compared: one pair per group", "vs-grey",
  "qualitative_panel", "No value: qualitative or panel", "vs-grey",
  "no_values", "No value: too few values", "vs-grey",
  "not_approved", "Not mapped", "vs-grey"
)
stopifnot(all(pairValueClass %in% valueStatus$valueClass))
valuesTable <- htmlTable(
  c("", "Warnings(total)", "Number of codes", "Number of records", "Percentage of records"),
  dplyr::bind_rows(
    valueRows |>
      dplyr::transmute(
        label, paste0(fmtInt(warnings_not_ignored), " (", fmtInt(warnings), ")"),
        fmtInt(pairs), fmtInt(records), fmtPct(100 * records / totalRecords)
      ) |>
      rlang::set_names(paste0("c", 1:5)),
    tibble::tibble(
      c1 = "TOTAL", c2 = paste0(fmtInt(sum(valueRows$warnings_not_ignored)), " (", fmtInt(sum(valueRows$warnings)), ")"),
      c3 = fmtInt(sum(valueRows$pairs)), c4 = fmtInt(totalRecords), c5 = "100.00%"
    )
  ),
  rowClasses = valueRows$rowClass
)
ParallelLogger::logInfo(paste0(valueRows$valueClass, " ", valueRows$pairs, collapse = ", "), " pairs")

# 3. The table of the second tab, one row per pair, as columns of values (compact). Missing
#    values are null. The reference is shown by the name of its LOINC Group, or as the same
#    concept when the concept is in no LOINC Group.
# The Group of a pair: its reference Group when it has one, else the first Group of its concept.
pairGroup <- purrr::pmap(
  list(evaluated$reference_group_concept_id, evaluated$group_concept_id, evaluated$group_concept_name),
  function(refId, ids, names) {
    if (is.na(ids)) return(list(id = NA_character_, name = NA_character_))
    ids <- strsplit(ids, ";", fixed = TRUE)[[1]]
    names <- strsplit(names, ";", fixed = TRUE)[[1]]
    k <- if (!is.na(refId) && refId %in% ids) match(refId, ids) else 1L
    list(id = ids[k], name = if (length(names) == length(ids)) names[k] else NA_character_)
  }
)
groupId <- vapply(pairGroup, \(g) g$id, character(1))
groupName <- vapply(pairGroup, \(g) g$name, character(1))
# Only the approved pairs are counted. Group Concept ID: "(<number of concepts of the Group with an approved
# pair>/<index of the concept>)", the concepts sorted by concept id. Concept: "(<number of approved pairs
# mapped to it>/<index of the pair>)", in the order of the table (largest N records first). A pair that is not
# approved has no position.
approved <- evaluated$mapping_status == "APPROVED"
groupConcepts <- tibble::tibble(group_concept_id = groupId, concept_id = evaluated$concept_id)[approved & !is.na(groupId), ] |>
  dplyr::distinct() |>
  dplyr::arrange(group_concept_id, concept_id) |>
  dplyr::mutate(index = dplyr::row_number(), n = dplyr::n(), .by = group_concept_id)
groupConceptPos <- tibble::tibble(group_concept_id = groupId, concept_id = evaluated$concept_id) |>
  dplyr::left_join(groupConcepts, by = c("group_concept_id", "concept_id"), na_matches = "never")
stopifnot(nrow(groupConceptPos) == nrow(evaluated))
groupPos <- dplyr::if_else(
  !approved | is.na(groupConceptPos$index), NA_character_, paste0("(", groupConceptPos$n, "/", groupConceptPos$index, ")")
)
positionIn <- function(key) {
  key[!approved] <- NA
  position <- stats::ave(seq_along(key), key, FUN = seq_along)
  total <- stats::ave(seq_along(key), key, FUN = length)
  dplyr::if_else(is.na(key), NA_character_, paste0("(", total, "/", position, ")"))
}
conceptKey <- dplyr::if_else(evaluated$concept_id %in% 0L, NA_integer_, evaluated$concept_id)
isNumber <- !is.na(suppressWarnings(as.numeric(evaluated$CONVERSION)))
# The conversion factor (or formula in X), and the harmonised unit only when it is not the UNIT.
conversion <- dplyr::if_else(isNumber, paste0("\u00d7", evaluated$CONVERSION), evaluated$CONVERSION)
conversionUnit <- dplyr::if_else(
  !is.na(evaluated$HARMONISED_UNIT) & evaluated$HARMONISED_UNIT != tidyr::replace_na(evaluated$UNIT, ""),
  evaluated$HARMONISED_UNIT, NA_character_
)
table <- tibble::tibble(
  status = evaluated$mapping_status,
  group_id = suppressWarnings(as.integer(groupId)),
  group_pos = groupPos,
  group_name = groupName,
  concept_id = evaluated$concept_id,
  concept_pos = positionIn(conceptKey),
  concept_name = dplyr::if_else(
    evaluated$is_panel %in% TRUE, paste0(evaluated$concept_name, " (panel)"), evaluated$concept_name
  ),
  harm_unit = evaluated$target_unit,
  quantity = evaluated$has_property,
  unit_change = dplyr::if_else(
    evaluated$mapping_status != "MISSING" &
      tidyr::replace_na(evaluated$MEASUREMENT_UNIT, "") != tidyr::replace_na(evaluated$UNIT, ""),
    paste0(tidyr::replace_na(evaluated$MEASUREMENT_UNIT, ""), "->", tidyr::replace_na(evaluated$UNIT, "")),
    NA_character_
  ),
  # The test with its unit after the fix (UNIT); a pair that is not mapped (MISSING) has no UNIT, so its
  # MEASUREMENT_UNIT is shown. The unit as it came in is in unit_change when it was fixed.
  test = paste0(
    evaluated$TEST_NAME, "[",
    tidyr::replace_na(dplyr::if_else(evaluated$mapping_status == "MISSING", evaluated$MEASUREMENT_UNIT, evaluated$UNIT), ""),
    "]"
  ),
  n = evaluated$n,
  value_source = evaluated$value_source_extracted_qcout_na_p,
  unit_source = evaluated$unit_source_injection_correction_na_p,
  deciles = evaluated$decile_value,
  ref_range = evaluated$reference_range,
  ks = evaluated$KS,
  ks_mlp = evaluated$KS_mlp,
  no_unit = noTargetUnit,
  value_status = valueStatus$short[match(pairValueClass, valueStatus$valueClass)],
  value_style = valueStatus$style[match(pairValueClass, valueStatus$valueClass)],
  conversion = conversion,
  conversion_unit = conversionUnit,
  deciles_h = evaluated$decile_value_harmonised,
  ref_deciles = dplyr::if_else(
    is.na(evaluated$reference_decile_value_harmonised), NA_character_,
    paste0(evaluated$reference_decile_value_harmonised, "(", evaluated$n_reference_pairs, ")")
  ),
  log10_d5 = evaluated$log10_D5,
  message = evaluated$mapping_warning_messages
)
# The Change Log of each pair: the commits (or #<issue>:<commit>) of TestCodeUnitChanges.tsv.
duplicatedChanges <- changes |> dplyr::count(TEST_NAME, MEASUREMENT_UNIT) |> dplyr::filter(n > 1)
if (nrow(duplicatedChanges) > 0) {
  stop("TEST_NAME + MEASUREMENT_UNIT are not unique in ", changesFile, ", e.g. ", duplicatedChanges$TEST_NAME[1])
}
pairChanges <- evaluated |>
  dplyr::select(TEST_NAME, MEASUREMENT_UNIT) |>
  dplyr::left_join(changes, by = c("TEST_NAME", "MEASUREMENT_UNIT"), na_matches = "na")
stopifnot(nrow(pairChanges) == nrow(evaluated))
unknownChanges <- dplyr::anti_join(changes, evaluated, by = c("TEST_NAME", "MEASUREMENT_UNIT"), na_matches = "na")
if (nrow(unknownChanges) > 0) {
  ParallelLogger::logWarn(nrow(unknownChanges), " pairs of ", changesFile, " are not in the Kanta data, e.g. ", unknownChanges$TEST_NAME[1])
}
ParallelLogger::logInfo(sum(!is.na(pairChanges$changes)), " pairs with a Change Log")
table$changes <- pairChanges$changes

toJson <- function(x) {
  json <- jsonlite::toJSON(x, na = "null", digits = NA, auto_unbox = TRUE)
  # "</script>" inside the data must not end the script element
  gsub("</", "<\\/", as.character(json), fixed = TRUE)
}
dataJson <- toJson(as.list(table))
configJson <- toJson(list(
  ksAgree = ksAgree, ksDisagree = ksDisagree, githubUrl = githubUrl,
  statusOrder = c(setdiff(statusOrder, "ERROR"), paste0("ERROR:", errorReasons$reason)),
  valueStatusOrder = valueStatus$short
))
ParallelLogger::logInfo(nrow(table), " rows in the table, ", format(nchar(dataJson, type = "bytes") / 1e6, digits = 3), " MB of data")

fill <- function(template, placeholder, value) {
  i <- regexpr(placeholder, template, fixed = TRUE)
  stopifnot(i > 0)
  paste0(substr(template, 1, i - 1), value, substr(template, i + nchar(placeholder), nchar(template)))
}
html <- template |>
  fill("__INPUT_SECTIONS__", inputSections) |>
  fill("__TARGET_SECTIONS__", targetSections) |>
  fill("__FIXED_TABLE__", fixedTable) |>
  fill("__EVENTS_TABLE__", eventsTable) |>
  fill("__ERRORS_TABLE__", errorsTable) |>
  fill("__VALUES_TABLE__", valuesTable) |>
  fill("__CONFIG_JSON__", configJson) |>
  fill("__DATA_JSON__", dataJson)

#
# --- Output -------------------------------------------------------------
#
writeLines(html, pathToDashboard, useBytes = TRUE)
ParallelLogger::logInfo("Wrote ", pathToDashboard, " (", format(file.size(pathToDashboard) / 1e6, digits = 3), " MB)")
