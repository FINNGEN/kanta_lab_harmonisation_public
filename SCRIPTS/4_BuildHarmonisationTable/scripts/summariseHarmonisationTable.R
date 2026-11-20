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
harmonisationTableFile <- args[1]
propertyMismatchWarningFile <- args[2]
propertySharedWarningFile <- args[3]
outDir <- args[4]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  harmonisationTableFile = ", harmonisationTableFile)
ParallelLogger::logInfo("  propertyMismatchWarningFile = ", propertyMismatchWarningFile)
ParallelLogger::logInfo("  propertySharedWarningFile = ", propertySharedWarningFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
harmonisationTable <- readTable(harmonisationTableFile, tableSpecs$harmonisationTable)
propertyMismatchWarning <- readTable(propertyMismatchWarningFile, tableSpecs$propertyMismatchWarning)
propertySharedWarning <- readTable(propertySharedWarningFile, tableSpecs$propertySharedWarning)

#
# --- Action -------------------------------------------------------------
#
percent <- function(n, total) paste0(formatC(100 * n / total, format = "f", digits = 1), "%")
count <- function(n) format(n, big.mark = ",", trim = TRUE)

# Every row is a TEST_NAME + PREPROCESED_UNIT pair. mapping_status IGNORE is ignored; APPROVED
# and ERROR:<reason> (an approved mapping with an error) are approved; NOT-APPROVED
# is not approved.
harmonisationTable <- harmonisationTable |>
  dplyr::mutate(
    status = dplyr::case_when(
      mapping_status == "IGNORE" ~ "ignored",
      grepl("^(APPROVED|ERROR)", mapping_status) ~ "approved",
      TRUE ~ "not approved"
    )
  )
nRows <- nrow(harmonisationTable)
# The warning tables are joined to the table (the property mismatch on TEST_NAME + UNIT, the
# shared property on TEST_NAME + has_property). A warning not marked `ignore` is an ERROR on
# an approved row and a WARNING on any other row; an ignored warning is neither.
withWarnings <- harmonisationTable |>
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
    isError = grepl("^ERROR", mapping_status),
    isWarning = hasWarning & status != "approved"
  )
statusTable <- withWarnings |>
  dplyr::summarise(n = dplyr::n(), n_warning = sum(isWarning), n_error = sum(isError), .by = status) |>
  dplyr::right_join(tibble::tibble(status = c("approved", "not approved", "ignored")), by = "status") |>
  dplyr::mutate(dplyr::across(-status, \(x) dplyr::coalesce(x, 0L)))
statusTable <- statusTable[match(c("approved", "not approved", "ignored"), statusTable$status), ]

approved <- harmonisationTable |> dplyr::filter(status == "approved")
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
  "# harmonisationTable",
  "",
  "Summary of `harmonisationTable.tsv`, one row per `TEST_NAME` + `PREPROCESED_UNIT` pair.",
  "",
  "## Mapping status",
  "",
  "A row with an `ignore_mapping_reason` is ignored; otherwise it is approved (`APPROVED` or `ERROR:<reason>` in `mapping_status`) or not approved. `n with warning` and `n with error` count the rows with a warning that is not marked `ignore`: an error on an approved row, a warning on any other.",
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
outFile <- file.path(outDir, "harmonisationTable.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
