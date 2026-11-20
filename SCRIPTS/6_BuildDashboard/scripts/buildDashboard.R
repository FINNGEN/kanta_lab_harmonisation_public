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
measurementFile <- args[3]
conversionFile <- args[4]
targetFile <- args[5]
outDir <- args[6]

# The scripts folder of this step, where the HTML template is.
scriptDir <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])))
templateFile <- file.path(scriptDir, "dashboardTemplate.html")
pathToDashboard <- file.path(outDir, "dashboard.html")

# A pair whose values agree with the reference has a KS under ksAgree; above ksDisagree it
# disagrees; in between it is a warning.
ksAgree <- 0.5
ksDisagree <- 0.8

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  evaluatedFile = ", evaluatedFile)
ParallelLogger::logInfo("  unitFixFile = ", unitFixFile)
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  conversionFile = ", conversionFile)
ParallelLogger::logInfo("  targetFile = ", targetFile)
ParallelLogger::logInfo("  templateFile = ", templateFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  ksAgree = ", ksAgree)
ParallelLogger::logInfo("  ksDisagree = ", ksDisagree)

#
# --- Input -------------------------------------------------------------
#
chr <- readr::col_character
evaluated <- readr::read_tsv(
  evaluatedFile,
  col_types = readr::cols(
    mapping_status = chr(), TEST_NAME = chr(), PREPROCESED_UNIT = chr(), UNIT = chr(),
    n = readr::col_double(),
    unit_source_injection_correction_na_p = chr(),
    reference_range = chr(),
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = chr(),
    decile_value = chr(), decile_value_harmonised = chr(), reference_decile_value_harmonised = chr(),
    unit_fix_reasoning = chr(), concept_id = readr::col_integer(), ignore_mapping_reason = chr(),
    concept_code = chr(), concept_name = chr(), vocabulary_id = chr(), is_panel = readr::col_logical(),
    has_component = chr(), has_property = chr(),
    group_concept_id = chr(), group_concept_code = chr(), group_concept_name = chr(),
    HARMONISED_UNIT = chr(), CONVERSION = chr(), mapping_warning_messages = chr(),
    KS = readr::col_double(), KS_mlp = readr::col_double(), log10_D5 = readr::col_double(),
    in_reference = readr::col_logical(), reference_type = chr(), reference_group_concept_id = chr(), n_reference_pairs = readr::col_integer()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(evaluated), " rows from ", evaluatedFile)
evaluated <- evaluated |>
  dplyr::arrange(dplyr::desc(n), TEST_NAME, PREPROCESED_UNIT, UNIT)
unitFix <- readr::read_tsv(unitFixFile, col_types = readr::cols(.default = chr()), na = "")
measurement <- readr::read_tsv(measurementFile, col_types = readr::cols(.default = chr()), na = "")
conversion <- readr::read_tsv(conversionFile, col_types = readr::cols(.default = chr()), na = "")
targetTable <- readr::read_tsv(targetFile, col_types = readr::cols(.default = chr()), na = "")
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
htmlTable <- function(header, rows, numericFrom = 2, totalLast = TRUE) {
  cells <- function(tag, values, class = "") {
    cls <- ifelse(seq_along(values) >= numericFrom, " class=\"num\"", "")
    paste0("<", tag, cls, ">", values, "</", tag, ">", collapse = "")
  }
  body <- vapply(seq_len(nrow(rows)), function(i) {
    last <- totalLast && i == nrow(rows)
    paste0("<tr", if (last) " class=\"total\"", ">", cells("td", unlist(rows[i, ], use.names = FALSE)), "</tr>")
  }, character(1))
  paste0("<table class=\"summary\"><thead><tr>", cells("th", header), "</tr></thead><tbody>", paste(body, collapse = ""), "</tbody></table>")
}
statusSpan <- function(status) paste0("<span class=\"st st-", status, "\">", status, "</span>")

# 1. Harmonised events: the pairs (TEST_NAME + PREPROCESED_UNIT), their records, and the pairs
#    with a warning message, by mapping_status.
statusOrder <- c("APPROVED", "ERROR", "NOT-APPROVED", "IGNORE", "NOT-FOUND")
events <- evaluated |>
  dplyr::summarise(
    pairs = dplyr::n(), records = sum(n),
    with_warning = sum(!is.na(mapping_warning_messages)),
    .by = mapping_status
  ) |>
  dplyr::right_join(tibble::tibble(mapping_status = statusOrder), by = "mapping_status") |>
  dplyr::mutate(dplyr::across(-mapping_status, \(x) dplyr::coalesce(x, 0))) |>
  dplyr::arrange(match(mapping_status, statusOrder))
totalRecords <- sum(events$records)
eventsTable <- htmlTable(
  c("Status", "Pairs with a warning", "Number of test+unit combinations", "Number of records", "Percentage of records"),
  dplyr::bind_rows(
    events |>
      dplyr::transmute(
        statusSpan(mapping_status), fmtInt(with_warning), fmtInt(pairs), fmtInt(records),
        fmtPct(100 * records / totalRecords)
      ) |>
      rlang::set_names(paste0("c", 1:5)),
    tibble::tibble(
      c1 = "TOTAL", c2 = fmtInt(sum(events$with_warning)), c3 = fmtInt(sum(events$pairs)),
      c4 = fmtInt(totalRecords), c5 = "100.00%"
    )
  )
)
ParallelLogger::logInfo(
  paste0(events$mapping_status, " ", events$pairs, collapse = ", "), " pairs; ", fmtInt(totalRecords), " records"
)

# Input data tab: the tables of 1_Input/1_BuildKantaAgregatedTable/kantaAgregatedTable.md, from the
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
    hasUnit = !is.na(PREPROCESED_UNIT) & nzchar(PREPROCESED_UNIT),
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
inputSections <- paste0(
  "<h2>Name Unit Value combinations</h2><div class=\"card\">", coverageHtml, "</div>",
  "<p class=\"note\">Name / unit / value coverage of the Kanta aggregated table, one row per <code>TEST_NAME</code> + <code>PREPROCESED_UNIT</code> pair. An <code>X</code> under unit means the pair has a recorded unit; under value, that at least one of its records has a value.</p>",
  "<h2>Units</h2><div class=\"card\">", unitSourceHtml, "</div>",
  "<p class=\"note\">Where the unit of the records came from. A pair counts in a source when some of its records come from it, so % rows does not add up to 100%. n records is approximate (shares are rounded). The empty source is the records with no unit source.</p>",
  "<h2>Reference Ranges</h2><div class=\"card\">", refRangeHtml, "</div>",
  "<p class=\"note\">Combinations of demographic bins with a reference range: AF adult female, AM adult male, MF minor female, MM minor male. An X means the pair has a range for that bin; the row with no X has no reference range.</p>",
  "<h2>Values</h2><div class=\"card\">", valueSourceHtml, "</div>",
  "<p class=\"note\">Where the value of the records came from. The empty source is the records with no value. Same counting as Units.</p>"
)

# Target data tab: the tables of 3_Target/4_BuildTargetTable/targetTable.md.
concepts <- dplyr::distinct(targetTable, concept_id, is_panel, harmonised_unit, harmonised_unit_source)
nConcepts <- nrow(concepts)
nSource <- function(x) sum(concepts$harmonised_unit_source %in% x)
conceptRows <- tibble::tibble(
  step = c(
    "concepts in measurementOmopData.tsv", "removed: conventional with an SI partner", "concepts in the table",
    "panel (no unit)", "isQualitative (no unit)", "unit from lab2clean", "unit from the overwrite",
    "no unit (not in lab2clean)"
  ),
  n = c(
    nrow(measurement), sum(measurement$concept_id %in% conversion$concept_id), nConcepts,
    nSource("panel"), nSource("isQualitative"), nSource("lab2clean"),
    sum(!concepts$harmonised_unit_source %in% c(NA, "panel", "isQualitative", "lab2clean")),
    sum(is.na(concepts$harmonised_unit_source))
  )
) |>
  dplyr::mutate(
    pct = dplyr::if_else(dplyr::row_number() <= 2, "", fmtPct1(100 * n / nConcepts)),
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

# 0. Fixed units: the pairs whose PREPROCESED_UNIT was changed to a different UNIT (only a mapped
#    pair has the fix applied), in one row.
isUnitFixed <- evaluated$mapping_status != "NOT-FOUND" &
  tidyr::replace_na(evaluated$PREPROCESED_UNIT, "") != tidyr::replace_na(evaluated$UNIT, "")
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

# 2. Harmonised values: each pair has no values, or its values are compared with the reference
#    (AGREE / WARNING / DISAGREE by KS), or they are not compared, and why.
valueClass <- evaluated |>
  dplyr::mutate(
    valueClass = dplyr::case_when(
      dplyr::coalesce(value_missing_p, 0) >= 100 ~ "no_values",
      !is.na(KS) & KS < ksAgree ~ "AGREE",
      !is.na(KS) & KS <= ksDisagree ~ "WARNING",
      !is.na(KS) ~ "DISAGREE",
      mapping_status %in% c("NOT-FOUND", "IGNORE") ~ "not_mapped",
      is.na(decile_value_harmonised) ~ "no_unit",
      TRUE ~ "no_reference"
    )
  ) |>
  dplyr::summarise(pairs = dplyr::n(), records = sum(n), .by = valueClass)
valueRows <- tibble::tribble(
  ~valueClass, ~label,
  "no_values", "No values",
  "AGREE", paste0("<span class=\"ks agree\">AGREE</span> KS &lt; ", ksAgree),
  "WARNING", paste0("<span class=\"ks warn\">WARNING</span> ", ksAgree, " &le; KS &le; ", ksDisagree),
  "DISAGREE", paste0("<span class=\"ks dis\">DISAGREE</span> KS &gt; ", ksDisagree),
  "not_mapped", "Not compared: not mapped (NOT-FOUND or IGNORE)",
  "no_unit", "Not compared: no conversion to a harmonised unit",
  "no_reference", "Not compared: no LOINC Group or concept with enough approved pairs"
) |>
  dplyr::left_join(valueClass, by = "valueClass") |>
  dplyr::mutate(dplyr::across(c(pairs, records), \(x) dplyr::coalesce(x, 0)))
stopifnot(sum(valueRows$records) == totalRecords)
valuesTable <- htmlTable(
  c("", "Number of codes", "Number of records", "Percentage of records"),
  dplyr::bind_rows(
    valueRows |>
      dplyr::transmute(label, fmtInt(pairs), fmtInt(records), fmtPct(100 * records / totalRecords)) |>
      rlang::set_names(paste0("c", 1:4)),
    tibble::tibble(c1 = "TOTAL", c2 = fmtInt(sum(valueRows$pairs)), c3 = fmtInt(totalRecords), c4 = "100.00%")
  )
)
ParallelLogger::logInfo(paste0(valueRows$valueClass, " ", valueRows$pairs, collapse = ", "), " pairs")

# 3. The table of the second tab, one row per pair, as columns of values (compact). Missing
#    values are null. The reference is shown by the name of its LOINC Group, or as the same
#    concept when the concept is in no LOINC Group.
referenceName <- purrr::pmap_chr(
  list(evaluated$reference_group_concept_id, evaluated$group_concept_id, evaluated$group_concept_name),
  function(id, ids, names) {
    if (is.na(id)) return(NA_character_)
    ids <- strsplit(ids, ";", fixed = TRUE)[[1]]
    names <- strsplit(names, ";", fixed = TRUE)[[1]]
    if (length(ids) == length(names) && id %in% ids) names[match(id, ids)] else id
  }
)
isNumber <- !is.na(suppressWarnings(as.numeric(evaluated$CONVERSION)))
# The conversion factor (or formula in X), and the harmonised unit only when it is not the UNIT.
conversion <- dplyr::if_else(isNumber, paste0("\u00d7", evaluated$CONVERSION), evaluated$CONVERSION)
conversionUnit <- dplyr::if_else(
  !is.na(evaluated$HARMONISED_UNIT) & evaluated$HARMONISED_UNIT != tidyr::replace_na(evaluated$UNIT, ""),
  evaluated$HARMONISED_UNIT, NA_character_
)
table <- tibble::tibble(
  status = evaluated$mapping_status,
  concept_id = evaluated$concept_id,
  concept_name = dplyr::if_else(
    evaluated$is_panel %in% TRUE, paste0(evaluated$concept_name, " (panel)"), evaluated$concept_name
  ),
  quantity = evaluated$has_property,
  unit_change = dplyr::if_else(
    evaluated$mapping_status != "NOT-FOUND" &
      tidyr::replace_na(evaluated$PREPROCESED_UNIT, "") != tidyr::replace_na(evaluated$UNIT, ""),
    paste0(tidyr::replace_na(evaluated$PREPROCESED_UNIT, ""), "->", tidyr::replace_na(evaluated$UNIT, "")),
    NA_character_
  ),
  test = paste0(evaluated$TEST_NAME, "[", tidyr::replace_na(evaluated$PREPROCESED_UNIT, ""), "]"),
  n = evaluated$n,
  value_source = evaluated$value_source_extracted_qcout_na_p,
  unit_source = evaluated$unit_source_injection_correction_na_p,
  deciles = evaluated$decile_value,
  ks = evaluated$KS,
  ks_mlp = evaluated$KS_mlp,
  conversion = conversion,
  conversion_unit = conversionUnit,
  deciles_h = evaluated$decile_value_harmonised,
  ref_deciles = dplyr::if_else(
    is.na(evaluated$reference_decile_value_harmonised), NA_character_,
    paste0(evaluated$reference_decile_value_harmonised, "(", evaluated$n_reference_pairs, ")")
  ),
  log10_d5 = evaluated$log10_D5,
  reference = dplyr::case_when(
    evaluated$reference_type %in% "LOINC Group" ~ paste0(referenceName, " (", evaluated$n_reference_pairs, " other approved pairs)"),
    evaluated$reference_type %in% "concept_id" ~ paste0("Same concept (", evaluated$n_reference_pairs, " other approved pairs)"),
    TRUE ~ NA_character_
  ),
  in_reference = dplyr::if_else(evaluated$in_reference %in% TRUE, "yes", NA_character_),
  message = evaluated$mapping_warning_messages
)
toJson <- function(x) {
  json <- jsonlite::toJSON(x, na = "null", digits = NA, auto_unbox = TRUE)
  # "</script>" inside the data must not end the script element
  gsub("</", "<\\/", as.character(json), fixed = TRUE)
}
dataJson <- toJson(as.list(table))
configJson <- toJson(list(ksAgree = ksAgree, ksDisagree = ksDisagree, statusOrder = statusOrder))
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
  fill("__VALUES_TABLE__", valuesTable) |>
  fill("__CONFIG_JSON__", configJson) |>
  fill("__DATA_JSON__", dataJson)

#
# --- Output -------------------------------------------------------------
#
writeLines(html, pathToDashboard, useBytes = TRUE)
ParallelLogger::logInfo("Wrote ", pathToDashboard, " (", format(file.size(pathToDashboard) / 1e6, digits = 3), " MB)")
