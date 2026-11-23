#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
measurementFile <- args[1]
conversionFile <- args[2]
targetFile <- args[3]
outDir <- args[4]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  conversionFile = ", conversionFile)
ParallelLogger::logInfo("  targetFile = ", targetFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
readTsv <- function(file) readr::read_tsv(file, col_types = readr::cols(.default = readr::col_character()), na = "")
measurement <- readTsv(measurementFile)
conversion <- readTsv(conversionFile)
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
nRemoved <- sum(measurement$concept_id %in% conversion$concept_id)
nConcepts <- nrow(concepts)

# Concepts: where the unit came from.
nSource <- function(x) sum(concepts$harmonised_unit_source %in% x)
conceptRows <- tibble::tibble(
  step = c(
    "concepts in `measurementOmopData.tsv`",
    "removed: conventional with an SI partner",
    "concepts in the table",
    "panel (no unit)",
    "isQualitative (no unit)",
    "unit from lab2clean",
    "no unit (not in lab2clean)"
  ),
  n = c(
    nOriginal, nRemoved, nConcepts, nSource("panel"), nSource("isQualitative"), nSource("lab2clean"),
    sum(is.na(concepts$harmonised_unit_source))
  )
) |>
  dplyr::mutate(
    `% concepts in the table` = dplyr::if_else(row_number() <= 2, "", fmtPct(100 * n / nConcepts)),
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

# Validations.
nDuplicatedPairs <- sum(duplicated(targetTable[c("concept_id", "group_concept_id")]))
nSeveralGroups <- sum(dplyr::count(targetTable, .data$concept_id)$n > 1)
groupUnitsOf <- function(df) df |>
  dplyr::filter(!is.na(.data$harmonised_unit)) |>
  dplyr::group_by(.data$group_concept_id, .data$group_concept_code) |>
  dplyr::summarise(
    units = paste(sort(unique(.data$harmonised_unit)), collapse = ", "),
    n_units = dplyr::n_distinct(.data$harmonised_unit),
    n_concepts = dplyr::n_distinct(.data$concept_id),
    .groups = "drop"
  ) |>
  dplyr::filter(.data$n_units > 1)
groupUnits <- groupUnitsOf(inGroup)
lab2cleanGroupUnits <- groupUnitsOf(dplyr::filter(inGroup, .data$group_source == "lab2clean"))
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
for (i in seq_len(nrow(validations))) {
  ParallelLogger::logInfo(validations$result[i], ": ", validations$test[i], " - ", validations$message[i])
}

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
  "",
  "# Validations",
  "",
  mdTable(validations),
  if (nrow(groupUnits) > 0) {
    c(
      "",
      "Groups with more than one `harmonised_unit` (units of the concepts that have one):",
      "",
      mdTable(dplyr::transmute(
        groupUnits, group = .data$group_concept_code, `n concepts` = .data$n_concepts, units = .data$units
      ))
    )
  }
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "targetTable.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
if (any(validations$result == "ERROR")) {
  stop("Validation failed, see ", outFile)
}
