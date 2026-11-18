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
overwriteFile <- args[5]
outDir <- args[6]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  groupsFile = ", groupsFile)
ParallelLogger::logInfo("  membershipFile = ", membershipFile)
ParallelLogger::logInfo("  unitFile = ", unitFile)
ParallelLogger::logInfo("  overwriteFile = ", overwriteFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
measurement <- readr::read_tsv(measurementFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
groups <- readr::read_tsv(groupsFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
membership <- readr::read_tsv(membershipFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
lab2cleanUnit <- readr::read_tsv(unitFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
overwriteUnit <- readr::read_tsv(overwriteFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
ParallelLogger::logInfo("Read ", nrow(lab2cleanUnit), " lab2clean units from ", unitFile)
ParallelLogger::logInfo("Read ", nrow(overwriteUnit), " unit overwrites from ", overwriteFile)

# A concept of a qualitative property has no unit: its harmonised_unit is empty and its source is
# "isQualitative" (a concept with an overwrite keeps it).
qualitativeProperties <- c("Presence or Threshold")

# The unit of a concept: its overwrite when it has one, else its lab2clean unit. The source is
# "lab2clean", or the note of the overwrite.
unit <- dplyr::bind_rows(
  dplyr::transmute(overwriteUnit, concept_id, harmonised_unit, source = dplyr::coalesce(.data$note, "overwrite")),
  dplyr::transmute(lab2cleanUnit, concept_id, harmonised_unit, source = "lab2clean")
) |>
  dplyr::distinct(.data$concept_id, .keep_all = TRUE) |>
  dplyr::rename(harmonised_unit_source = "source")
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
  dplyr::left_join(unit, by = "concept_id", relationship = "many-to-one") |>
  dplyr::mutate(
    isQualitative = .data$has_property %in% qualitativeProperties & !(.data$concept_id %in% overwriteUnit$concept_id),
    harmonised_unit = dplyr::if_else(isQualitative, NA_character_, harmonised_unit),
    harmonised_unit_source = dplyr::if_else(isQualitative, "isQualitative", harmonised_unit_source)
  ) |>
  dplyr::select(
    concept_id, concept_code, concept_name, vocabulary_id, is_panel,
    has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect,
    group_concept_id, group_concept_code, group_concept_name, harmonised_unit, harmonised_unit_source
  ) |>
  dplyr::arrange(as.numeric(concept_id), group_concept_code)

ParallelLogger::logInfo(
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
