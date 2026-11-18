#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
evaluatedFile <- args[1]
outDir <- args[2]

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
  fill("__EVENTS_TABLE__", eventsTable) |>
  fill("__VALUES_TABLE__", valuesTable) |>
  fill("__CONFIG_JSON__", configJson) |>
  fill("__DATA_JSON__", dataJson)

#
# --- Output -------------------------------------------------------------
#
writeLines(html, pathToDashboard, useBytes = TRUE)
ParallelLogger::logInfo("Wrote ", pathToDashboard, " (", format(file.size(pathToDashboard) / 1e6, digits = 3), " MB)")
