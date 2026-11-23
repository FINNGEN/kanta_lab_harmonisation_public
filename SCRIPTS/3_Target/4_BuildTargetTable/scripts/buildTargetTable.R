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
outDir <- args[6]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  groupsFile = ", groupsFile)
ParallelLogger::logInfo("  membershipFile = ", membershipFile)
ParallelLogger::logInfo("  unitFile = ", unitFile)
ParallelLogger::logInfo("  lab2cleanGroupFile = ", lab2cleanGroupFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
measurement <- readr::read_tsv(measurementFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
groups <- readr::read_tsv(groupsFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
membership <- readr::read_tsv(membershipFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
lab2cleanUnit <- readr::read_tsv(unitFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
lab2cleanGroup <- readr::read_tsv(lab2cleanGroupFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c")) |>
  dplyr::mutate(group_source = "lab2clean")
ParallelLogger::logInfo("Read ", nrow(lab2cleanUnit), " lab2clean units from ", unitFile)

# A panel and a concept of a qualitative property have no unit: its harmonised_unit is empty and
# its source is "panel" or "isQualitative". (The units set by hand are applied later, in
# 4_BuildHarmonisationTable, from 2_Harmonisation/harmonisedUnitOverwrite.tsv.)
qualitativeProperties <- c("Presence or Threshold")

ParallelLogger::logInfo("Read ", nrow(measurement), " concepts from ", measurementFile)
ParallelLogger::logInfo("Read ", nrow(groups), " Groups from ", groupsFile)
ParallelLogger::logInfo("Read ", nrow(membership), " concept/Group rows from ", membershipFile)

#
# --- Action -------------------------------------------------------------
#

# Every concept is a target: a conventional concept (the mass side of a mass-molar pair) and its SI
# partner are both kept, and the mapping decides which one a test goes to.

# The unit of each concept (lab2clean, replaced by empty for a panel or a qualitative concept), then one
# row per concept and Group it belongs to; a concept in no Group keeps one row with
# empty group_* columns, a concept in several Groups appears once per Group.
targetTable <- measurement |>
  dplyr::left_join(lab2cleanUnit, by = "concept_id", relationship = "many-to-one") |>
  dplyr::mutate(
    harmonised_unit_source = dplyr::if_else(is.na(.data$harmonised_unit), NA_character_, "lab2clean"),
    isPanel = .data$is_panel %in% "TRUE",
    isQualitative = .data$has_property %in% qualitativeProperties,
    harmonised_unit = dplyr::if_else(isPanel | isQualitative, NA_character_, .data$harmonised_unit),
    harmonised_unit_source = dplyr::case_when(
      isPanel ~ "panel",
      isQualitative ~ "isQualitative",
      .default = .data$harmonised_unit_source
    )
  ) |>
  dplyr::left_join(membership, by = "concept_id", relationship = "one-to-many") |>
  dplyr::left_join(groups, by = "group_concept_id", relationship = "many-to-one") |>
  dplyr::left_join(lab2cleanGroup, by = c("concept_id", "group_concept_code"), relationship = "many-to-one") |>
  dplyr::mutate(group_source = dplyr::if_else(is.na(.data$group_concept_id), NA_character_, dplyr::coalesce(.data$group_source, "LOINC"))) |>
  dplyr::select(
    concept_id, concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    group_concept_id, group_concept_code, group_concept_name, group_source, harmonised_unit, harmonised_unit_source
  ) |>
  dplyr::arrange(as.numeric(concept_id), group_concept_code)

ParallelLogger::logInfo(
  dplyr::n_distinct(targetTable$concept_id[targetTable$harmonised_unit_source %in% "panel"]), " panels and ",
  dplyr::n_distinct(targetTable$concept_id[targetTable$harmonised_unit_source %in% "isQualitative"]), " qualitative concepts (no unit)"
)
ParallelLogger::logInfo(
  nrow(targetTable), " rows, ", dplyr::n_distinct(targetTable$concept_id), " concepts; ",
  dplyr::n_distinct(targetTable$concept_id[!is.na(targetTable$group_concept_id)]), " concepts in a Group, ",
  dplyr::n_distinct(targetTable$concept_id[!is.na(targetTable$harmonised_unit)]), " with a harmonised unit"
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "targetTable.tsv")
readr::write_tsv(targetTable, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(targetTable), " rows to ", outFile)
