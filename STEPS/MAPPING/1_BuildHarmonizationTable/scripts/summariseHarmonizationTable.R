#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
harmonizationTableFile <- args[1]
propertyMismatchWarningFile <- args[2]
propertySharedWarningFile <- args[3]
outDir <- args[4]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  harmonizationTableFile = ", harmonizationTableFile)
ParallelLogger::logInfo("  propertyMismatchWarningFile = ", propertyMismatchWarningFile)
ParallelLogger::logInfo("  propertySharedWarningFile = ", propertySharedWarningFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
harmonizationTable <- readr::read_tsv(
  harmonizationTableFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    PREPROCESED_UNIT = readr::col_character(),
    UNIT = readr::col_character(),
    unit_fix_reasoning = readr::col_character(),
    concept_id = readr::col_integer(),
    ignore_mapping_reason = readr::col_character(),
    mapping_status = readr::col_character(),
    concept_code = readr::col_character(),
    concept_name = readr::col_character(),
    vocabulary_id = readr::col_character(),
    is_panel = readr::col_logical(),
    has_component = readr::col_character(),
    has_property = readr::col_character(),
    has_method = readr::col_character(),
    has_scale_type = readr::col_character(),
    has_system = readr::col_character(),
    has_time_aspect = readr::col_character(),
    group_concept_id = readr::col_character(),
    group_concept_code = readr::col_character(),
    group_concept_name = readr::col_character(),
    HARMONISED_UNIT = readr::col_character(),
    CONVERSION = readr::col_character(),
    mapping_warning_messages = readr::col_character()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(harmonizationTable), " rows from ", harmonizationTableFile)

propertyMismatchWarning <- readr::read_tsv(
  propertyMismatchWarningFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(), UNIT = readr::col_character(),
    message = readr::col_character(), ignore = readr::col_logical()
  ),
  na = ""
)
propertySharedWarning <- readr::read_tsv(
  propertySharedWarningFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(), has_property = readr::col_character(),
    message = readr::col_character(), ignore = readr::col_logical()
  ),
  na = ""
)
ParallelLogger::logInfo(
  "Read ", nrow(propertyMismatchWarning), " rows from ", propertyMismatchWarningFile, " and ",
  nrow(propertySharedWarning), " rows from ", propertySharedWarningFile
)

#
# --- Action -------------------------------------------------------------
#
percent <- function(n, total) paste0(formatC(100 * n / total, format = "f", digits = 1), "%")
count <- function(n) format(n, big.mark = ",", trim = TRUE)

# Every row is a TEST_NAME + PREPROCESED_UNIT pair. mapping_status IGNORE is ignored; APPROVED
# and ERROR (an approved mapping with a warning that is not ignored) are approved; NOT-APPROVED
# is not approved.
harmonizationTable <- harmonizationTable |>
  dplyr::mutate(
    status = dplyr::case_when(
      mapping_status == "IGNORE" ~ "ignored",
      mapping_status %in% c("APPROVED", "ERROR") ~ "approved",
      TRUE ~ "not approved"
    )
  )
nRows <- nrow(harmonizationTable)
# The warning tables are joined to the table (the property mismatch on TEST_NAME + UNIT, the
# shared property on TEST_NAME + has_property). A warning not marked `ignore` is an ERROR on
# an approved row and a WARNING on any other row; an ignored warning is neither.
withWarnings <- harmonizationTable |>
  dplyr::left_join(
    propertyMismatchWarning |> dplyr::select(TEST_NAME, UNIT, mismatch = message, mismatchIgnore = ignore),
    by = c("TEST_NAME", "UNIT"), relationship = "many-to-one"
  ) |>
  dplyr::left_join(
    propertySharedWarning |> dplyr::select(TEST_NAME, has_property, shared = message, sharedIgnore = ignore),
    by = c("TEST_NAME", "has_property"), relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    hasWarning = (!is.na(mismatch) & !dplyr::coalesce(mismatchIgnore, FALSE)) |
      (!is.na(shared) & !dplyr::coalesce(sharedIgnore, FALSE)),
    isError = hasWarning & status == "approved",
    isWarning = hasWarning & status != "approved"
  )
statusTable <- withWarnings |>
  dplyr::summarise(n = dplyr::n(), n_warning = sum(isWarning), n_error = sum(isError), .by = status) |>
  dplyr::right_join(tibble::tibble(status = c("approved", "not approved", "ignored")), by = "status") |>
  dplyr::mutate(dplyr::across(-status, \(x) dplyr::coalesce(x, 0L)))
statusTable <- statusTable[match(c("approved", "not approved", "ignored"), statusTable$status), ]

approved <- harmonizationTable |> dplyr::filter(status == "approved")
nApproved <- nrow(approved)
groupIds <- approved$group_concept_id |>
  stats::na.omit() |>
  strsplit(";", fixed = TRUE) |>
  unlist() |>
  unique()
approvedTable <- tibble::tribble(
  ~what, ~n, ~p,
  "rows (TEST_NAME + PREPROCESED_UNIT)", count(nApproved), "",
  "distinct concept_ids", count(dplyr::n_distinct(approved$concept_id)), "",
  "rows with a group", count(sum(!is.na(approved$group_concept_id))), percent(sum(!is.na(approved$group_concept_id)), nApproved),
  "distinct groups", count(length(groupIds)), "",
  "rows with a conversion", count(sum(!is.na(approved$CONVERSION))), percent(sum(!is.na(approved$CONVERSION)), nApproved)
)
ParallelLogger::logInfo(
  paste0(statusTable$status, ": ", statusTable$n, collapse = ", "), "; ",
  nApproved, " approved rows with ", dplyr::n_distinct(approved$concept_id), " concept_ids"
)

#
# --- Output -------------------------------------------------------------
#
# A markdown table: the first column left, the others right aligned.
mdTable <- function(header, rows) {
  c(
    paste0("| ", paste(header, collapse = " | "), " |"),
    paste0("| ", paste(c("---", rep("---:", length(header) - 1)), collapse = " | "), " |"),
    apply(rows, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}
md <- c(
  "# harmonizationTable",
  "",
  "Summary of `harmonizationTable.tsv`, one row per `TEST_NAME` + `PREPROCESED_UNIT` pair.",
  "",
  "## Mapping status",
  "",
  "A row with an `ignore_mapping_reason` is ignored; otherwise it is approved (`APPROVED` or `ERROR` in `mapping_status`) or not approved. `n with warning` and `n with error` count the rows with a warning that is not marked `ignore`: an error on an approved row, a warning on any other.",
  "",
  mdTable(
    c("status", "n", "%", "n with warning", "n with error"),
    rbind(
      cbind(
        statusTable$status, count(statusTable$n), percent(statusTable$n, nRows),
        count(statusTable$n_warning), count(statusTable$n_error)
      ),
      c(
        "total", count(nRows), "100.0%",
        count(sum(statusTable$n_warning)), count(sum(statusTable$n_error))
      )
    )
  ),
  "",
  "## Approved",
  "",
  mdTable(c("", "n", "% of approved rows"), as.matrix(approvedTable))
)
outFile <- file.path(outDir, "harmonizationTable.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
