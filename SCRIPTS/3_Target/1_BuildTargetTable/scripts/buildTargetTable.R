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
outDir <- args[4]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  groupsFile = ", groupsFile)
ParallelLogger::logInfo("  membershipFile = ", membershipFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
measurement <- readr::read_tsv(measurementFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
groups <- readr::read_tsv(groupsFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
membership <- readr::read_tsv(membershipFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
ParallelLogger::logInfo("Read ", nrow(measurement), " concepts from ", measurementFile)
ParallelLogger::logInfo("Read ", nrow(groups), " Groups from ", groupsFile)
ParallelLogger::logInfo("Read ", nrow(membership), " concept/Group rows from ", membershipFile)

#
# --- Action -------------------------------------------------------------
#

# One row per concept and Group it belongs to; a concept in no Group keeps one row with
# empty group_* columns, a concept in several Groups appears once per Group.
targetTable <- measurement |>
  dplyr::left_join(membership, by = "concept_id", relationship = "one-to-many") |>
  dplyr::left_join(groups, by = "group_concept_id", relationship = "many-to-one") |>
  dplyr::select(
    concept_id, concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    group_concept_id, group_concept_code, group_concept_name, group_harmonised_unit
  ) |>
  dplyr::arrange(as.numeric(concept_id), group_concept_code)

ParallelLogger::logInfo(
  nrow(targetTable), " rows, ", dplyr::n_distinct(targetTable$concept_id), " concepts; ",
  dplyr::n_distinct(targetTable$concept_id[!is.na(targetTable$group_concept_id)]), " concepts in a Group, ",
  dplyr::n_distinct(targetTable$concept_id[!is.na(targetTable$group_harmonised_unit)]), " with a harmonised unit"
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "targetTable.tsv")
readr::write_tsv(targetTable, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(targetTable), " rows to ", outFile)
