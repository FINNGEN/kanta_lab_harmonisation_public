#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
harmonizationTableFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  harmonizationTableFile = ", harmonizationTableFile)
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
    APPROVED = readr::col_logical(),
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
    Message = readr::col_character()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(harmonizationTable), " rows from ", harmonizationTableFile)

#
# --- Action -------------------------------------------------------------
#
percent <- function(n, total) paste0(formatC(100 * n / total, format = "f", digits = 1), "%")
count <- function(n) format(n, big.mark = ",", trim = TRUE)

# Every row is a TEST_NAME + PREPROCESED_UNIT pair. A row with an ignore_mapping_reason is
# ignored, whatever its APPROVED; the rest are approved or not approved.
harmonizationTable <- harmonizationTable |>
  dplyr::mutate(
    status = dplyr::case_when(
      !is.na(ignore_mapping_reason) ~ "ignored",
      APPROVED ~ "approved",
      TRUE ~ "not approved"
    )
  )
nRows <- nrow(harmonizationTable)
# The Message column of the table says which rows have a warning or an error.
statusTable <- harmonizationTable |>
  dplyr::summarise(
    n = dplyr::n(),
    n_warning = sum(startsWith(dplyr::coalesce(Message, ""), "WARNING")),
    n_error = sum(startsWith(dplyr::coalesce(Message, ""), "ERROR")),
    .by = status
  ) |>
  dplyr::right_join(tibble::tibble(status = c("approved", "not approved", "ignored")), by = "status") |>
  dplyr::mutate(dplyr::across(c(n, n_warning, n_error), \(x) dplyr::coalesce(x, 0L)))
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
  "A row with an `ignore_mapping_reason` is ignored; otherwise it is approved or not approved by `APPROVED`. `n with warning` and `n with error` count the rows whose `Message` is a WARNING or an ERROR.",
  "",
  mdTable(
    c("status", "n", "%", "n with warning", "n with error"),
    rbind(
      cbind(
        statusTable$status, count(statusTable$n), percent(statusTable$n, nRows),
        count(statusTable$n_warning), count(statusTable$n_error)
      ),
      c("total", count(nRows), "100.0%", count(sum(statusTable$n_warning)), count(sum(statusTable$n_error)))
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
