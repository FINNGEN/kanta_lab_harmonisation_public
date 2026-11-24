#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
measurementFile <- args[1]
targetFile <- args[2]
outDir <- args[3]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  targetFile = ", targetFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
readTsv <- function(file) readr::read_tsv(file, col_types = readr::cols(.default = readr::col_character()), na = "")
measurement <- readTsv(measurementFile)
targetTable <- readTsv(targetFile)
ParallelLogger::logInfo("Read ", nrow(targetTable), " rows from ", targetFile)

#
# --- Action -------------------------------------------------------------
#
fmtInt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
fmtPct <- function(x) sprintf("%.1f%%", x)

mdRow <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
mdTable <- function(df) {
  c(
    mdRow(names(df)),
    mdRow(rep("---", ncol(df))),
    vapply(seq_len(nrow(df)), function(i) mdRow(unlist(df[i, ])), character(1))
  )
}

# One row per concept (a concept in several Groups has several rows, all with the same unit).
concepts <- dplyr::distinct(targetTable, .data$concept_id, .data$is_panel, .data$harmonised_unit, .data$harmonised_unit_source)
nOriginal <- nrow(measurement)
nConcepts <- nrow(concepts)

# Concepts: where the unit came from.
nSource <- function(x) sum(concepts$harmonised_unit_source %in% x)
conceptRows <- tibble::tibble(
  step = c(
    "concepts in `measurementOmopData.tsv`",
    "concepts in the table",
    "panel (no unit)",
    "isQualitative (no unit)",
    "unit from lab2clean",
    "no unit (not in lab2clean)"
  ),
  n = c(
    nOriginal, nConcepts, nSource("panel"), nSource("isQualitative"), nSource("lab2clean"),
    sum(is.na(concepts$harmonised_unit_source))
  )
) |>
  dplyr::mutate(
    `% concepts in the table` = dplyr::if_else(row_number() <= 1, "", fmtPct(100 * n / nConcepts)),
    n = fmtInt(n)
  ) |>
  dplyr::rename(`n concepts` = n)

# Groups.
inGroup <- dplyr::filter(targetTable, !is.na(.data$group_concept_id))
nGroups <- dplyr::n_distinct(inGroup$group_concept_id)
nInGroup <- dplyr::n_distinct(inGroup$concept_id)
groupRows <- tibble::tibble(
  item = c("Groups", "concepts in a Group", "concepts in no Group", "concepts in more than one Group"),
  n = c(
    nGroups, nInGroup, nConcepts - nInGroup,
    sum(dplyr::count(inGroup, .data$concept_id)$n > 1)
  )
) |>
  dplyr::mutate(n = fmtInt(n))

# Where the Group of each concept-Group row came from.
sourceRows <- inGroup |>
  dplyr::count(.data$group_source, name = "n_rows") |>
  dplyr::left_join(
    inGroup |> dplyr::group_by(.data$group_source) |>
      dplyr::summarise(n_groups = dplyr::n_distinct(.data$group_concept_id), n_concepts = dplyr::n_distinct(.data$concept_id)),
    by = "group_source"
  ) |>
  dplyr::arrange(.data$group_source) |>
  dplyr::transmute(
    group_source = .data$group_source, `n concept-Group rows` = fmtInt(.data$n_rows),
    `n Groups` = fmtInt(.data$n_groups), `n concepts` = fmtInt(.data$n_concepts)
  )

md <- c(
  "# targetTable stats",
  "",
  paste0(
    "Summary of `targetTable.tsv`: ", fmtInt(nrow(targetTable)), " rows, one per concept and Group, for ",
    fmtInt(nConcepts), " concepts."
  ),
  "",
  "# Concepts",
  "",
  "Where the `harmonised_unit` of each concept came from (`harmonised_unit_source`).",
  "",
  mdTable(conceptRows),
  "",
  "# Groups",
  "",
  mdTable(groupRows),
  "",
  "Where the Group of a concept came from (`group_source`): `lab2clean` when lab2clean gives the concept that Group, `LOINC` for the other memberships.",
  "",
  mdTable(sourceRows),
  ""
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "targetTable.summary.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
