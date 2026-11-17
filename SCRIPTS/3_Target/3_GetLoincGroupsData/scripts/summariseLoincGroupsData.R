#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
groupsFile <- args[1]
membershipFile <- args[2]
measurementFile <- args[3]
conversionFile <- args[4]
outDir <- args[5]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  groupsFile = ", groupsFile)
ParallelLogger::logInfo("  membershipFile = ", membershipFile)
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  conversionFile = ", conversionFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
groups <- readr::read_tsv(groupsFile, col_types = readr::cols(.default = readr::col_character()), na = "")
membership <- readr::read_tsv(membershipFile, col_types = readr::cols(.default = readr::col_character()), na = "")
ParallelLogger::logInfo("Read ", nrow(groups), " Groups from ", groupsFile)
ParallelLogger::logInfo("Read ", nrow(membership), " concept/Group rows from ", membershipFile)
measurement <- readr::read_tsv(
  measurementFile,
  col_types = readr::cols(.default = readr::col_character()),
  na = ""
) |>
  dplyr::select("concept_id", "has_property")
ParallelLogger::logInfo("Read ", nrow(measurement), " concepts from ", measurementFile)
conventionalConceptIds <- readr::read_tsv(
  conversionFile,
  col_types = readr::cols(.default = readr::col_character()),
  na = ""
) |>
  dplyr::pull("concept_id")
ParallelLogger::logInfo("Read ", length(conventionalConceptIds), " conventional concepts from ", conversionFile)

#
# --- Action -------------------------------------------------------------
#
nGroups <- nrow(groups)

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

# The property of a Group is the has_property of its concepts, leaving out the conventional
# concepts mapped to the Group from their SI partner (a mass concentration in a molar Group
# is converted, it is not a second property) and "Presence or Threshold" (psProperty): the one the rest share, "(several)" when they differ. A Group with
# only "Presence or Threshold" concepts has that property; one with no property at all is
# "(none)". hasPs marks the Groups that also hold "Presence or Threshold" concepts next to
# another property: their concepts also map to a presence/threshold result, which has no
# unit. (The Group name is not used: some names leave the property out, e.g.
# `Bilirubin|Moment in time|Urine`.)
psProperty <- "Presence or Threshold"
groupProperty <- membership |>
  dplyr::filter(!.data$concept_id %in% conventionalConceptIds) |>
  dplyr::left_join(measurement, by = "concept_id") |>
  dplyr::group_by(.data$group_concept_id) |>
  dplyr::summarise(
    hasPsConcept = any(.data$has_property == psProperty, na.rm = TRUE),
    nOther = dplyr::n_distinct(.data$has_property[.data$has_property != psProperty], na.rm = TRUE),
    other = dplyr::first(stats::na.omit(.data$has_property[.data$has_property != psProperty])),
    nAny = dplyr::n_distinct(.data$has_property, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::mutate(
    has_property = dplyr::case_when(
      .data$nOther > 1 ~ "(several)",
      .data$nOther == 1 ~ .data$other,
      .data$hasPsConcept ~ psProperty,
      TRUE ~ "(none)"
    ),
    hasPs = .data$hasPsConcept & .data$nOther > 0
  )
groups <- groups |>
  dplyr::left_join(dplyr::select(groupProperty, "group_concept_id", "has_property", "hasPs"), by = "group_concept_id") |>
  dplyr::mutate(
    has_property = dplyr::coalesce(.data$has_property, "(none)"),
    hasPs = dplyr::coalesce(.data$hasPs, FALSE)
  )

nConcepts <- dplyr::n_distinct(membership$concept_id)
nSeveralGroups <- sum(dplyr::count(membership, .data$concept_id)$n > 1)

groupsTable <- tibble::tibble(
  what = c("Groups", "concepts in a Group", "concepts in more than one Group"),
  n = fmtInt(c(nGroups, nConcepts, nSeveralGroups))
)

propertyTable <- groups |>
  dplyr::group_by(.data$has_property) |>
  dplyr::summarise(n = dplyr::n(), nPs = sum(.data$hasPs), .groups = "drop") |>
  dplyr::arrange(dplyr::desc(.data$n)) |>
  dplyr::transmute(
    has_property,
    `n groups` = fmtInt(n),
    `% groups` = fmtPct(100 * n / nGroups),
    `n also PS` = fmtInt(nPs)
  ) |>
  dplyr::bind_rows(
    tibble::tibble(
      has_property = "total", `n groups` = fmtInt(nGroups), `% groups` = "100%",
      `n also PS` = fmtInt(sum(groups$hasPs))
    )
  )

md <- c(
  "# loincGroups stats",
  "",
  paste0(
    "Summary of `loincGroups.tsv`: ", fmtInt(nGroups), " LOINC Groups holding ",
    fmtInt(nConcepts), " standard `Measurement` concepts (`loincGroupMembership.tsv`)."
  ),
  "",
  "# Groups",
  "",
  mdTable(groupsTable),
  "",
  "# has_property",
  "",
  paste0(
    "The kind of quantity of the Group, the `has_property` of its concepts ",
    "(`measurementOmopData.tsv`) leaving out the conventional concepts mapped from their SI partner ",
    "(they are converted, not a property of their own) and `Presence or Threshold`: `(several)` when the rest differ, ",
    "`(none)` when no concept has one. `n also PS` is the Groups that also hold ",
    "`Presence or Threshold` concepts next to that property."
  ),
  "",
  mdTable(propertyTable)
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "loincGroups.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
