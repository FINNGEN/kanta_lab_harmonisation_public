#
# Flattens the LOINC Group file into ONE group per LOINC code.
#
# The LOINC Group file is not a tree. Each ParentGroup is internally a disjoint
# partition of its own terms, but ParentGroups overlap each other: inside the
# `Flowsheet - laboratory` Category, 334 of 8,551 codes sit in two Groups at
# once (the urine ParentGroups overlap the chem catch-all, and the coarse
# urine+sediment rollup overlaps the finer urine one). A code in two Groups
# cannot be used to score agreement, so this script resolves every collision
# with a fixed precedence -- most specific ParentGroup wins -- and writes a
# flat lookup the report can join on.
#
# Why these Categories: the three `Flowsheet` ones are the lab-facing part of
# the Group project, they are mutually disjoint (0 codes shared between them),
# and their ParentGroups roll up Method -- which is exactly the axis this
# pipeline and the reference most often disagree on.
#
# See RESEARCH/UnderstandingGroups.md sections 3 and 4 for the full analysis.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
groupFileDir <- args[1]
outDir <- args[2]

# The lab-facing Categories, and the ParentGroup precedence used to break a
# tie when a code lands in two of their Groups. Most specific first; the chem
# catch-all `LG100-4` MUST stay last, since its system axis absorbs
# ANYUrineUrineSed and it would otherwise win every urine collision.
#
# Swap `LG97-8` (UrineAndSed, one bucket per urine analyte regardless of how it
# was measured) above `LG74-7` (Urine, one bucket per analyte+property) if a
# coarser urine rollup is wanted. That is the only real modelling choice here;
# everything else is forced.
flowsheetCategories <- c(
  "Flowsheet - laboratory",
  "Flowsheet - vital signs",
  "Flowsheet - weight, height, and head circumference"
)
parentGroupPrecedence <- c(
  "LG78-8",   # UrineMicroalbumin  -- most specific
  "LG74-7",   # Urine
  "LG97-8",   # UrineAndSed
  "LG27-5",   # CellDiffCount
  "LG99-4",   # IsolateSusc
  "LG100-4",  # Chem_DrugTox_Chal_Sero_Allergy -- catch-all, must be last
  "LG47-3",   # VitalsRoutine
  "LG70-5"    # BodyMeasurementsRoutine
)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  groupFileDir = ", groupFileDir)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  categories = ", paste(flowsheetCategories, collapse = "; "))
ParallelLogger::logInfo("  precedence = ", paste(parentGroupPrecedence, collapse = " > "))

#
# --- Input -------------------------------------------------------------
#
# Read with readr's own default missing-value handling: this is an external
# vocabulary distribution, not a table another step in this project wrote.
groupFile <- file.path(groupFileDir, "Group.csv")
groupLoincTermsFile <- file.path(groupFileDir, "GroupLoincTerms.csv")

groups <- readr::read_csv(groupFile, show_col_types = FALSE,
                          col_types = readr::cols(.default = readr::col_character()))
terms <- readr::read_csv(groupLoincTermsFile, show_col_types = FALSE,
                         col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(groups), " groups from ", groupFile)
ParallelLogger::logInfo("Read ", nrow(terms), " group memberships from ", groupLoincTermsFile)

#
# --- Action -------------------------------------------------------------
#
flowsheet <- terms |>
  dplyr::filter(.data$Category %in% flowsheetCategories) |>
  dplyr::left_join(dplyr::select(groups, "GroupId", "ParentGroupId", "Group"), by = "GroupId")

# A membership whose GroupId is absent from Group.csv has no ParentGroup, so it
# has no precedence rank and no rule behind it. The 2.82 Beta ships exactly one
# such row -- GroupId "yes do" for LOINC 60978-4 under Flowsheet - vital signs,
# plainly an editing accident in the release. Drop those rather than emit a code
# whose group_id points at nothing.
orphans <- flowsheet |> dplyr::filter(is.na(.data$ParentGroupId))
if (nrow(orphans) > 0) {
  ParallelLogger::logWarn(
    nrow(orphans), " memberships name a GroupId that is not in Group.csv (",
    paste(unique(orphans$GroupId), collapse = ", "), "); dropping them"
  )
  flowsheet <- flowsheet |> dplyr::filter(!is.na(.data$ParentGroupId))
}

unknownParent <- flowsheet |> dplyr::filter(!.data$ParentGroupId %in% parentGroupPrecedence)
if (nrow(unknownParent) > 0) {
  # A new ParentGroup under one of these Categories would otherwise be ranked
  # arbitrarily. Rank it last rather than discarding it, and say so.
  ParallelLogger::logWarn(
    nrow(unknownParent), " memberships belong to ParentGroups not in the precedence list (",
    paste(unique(unknownParent$ParentGroupId), collapse = ", "),
    "); ranking them last"
  )
}

ranked <- flowsheet |>
  dplyr::mutate(
    .rank = match(.data$ParentGroupId, parentGroupPrecedence),
    .rank = dplyr::coalesce(.data$.rank, length(parentGroupPrecedence) + 1L)
  )

nCodes <- dplyr::n_distinct(ranked$LoincNumber)
collisions <- ranked |>
  dplyr::count(.data$LoincNumber, name = "nGroups") |>
  dplyr::filter(.data$nGroups > 1)
ParallelLogger::logInfo(
  nCodes, " distinct LOINC codes across the Flowsheet categories; ",
  nrow(collisions), " of them sit in more than one Group and are resolved by precedence"
)

# One row per LOINC code. Ties inside a ParentGroup cannot happen -- every
# ParentGroup is a disjoint partition of its own terms -- but GroupId is used
# as a secondary sort anyway so the output is byte-stable across runs.
assigned <- ranked |>
  dplyr::arrange(.data$LoincNumber, .data$.rank, .data$GroupId) |>
  dplyr::distinct(.data$LoincNumber, .keep_all = TRUE)

groupSizes <- assigned |> dplyr::count(.data$GroupId, name = "nGroupMembers")
rawSizes <- terms |>
  dplyr::distinct(.data$GroupId, .data$LoincNumber) |>
  dplyr::count(.data$GroupId, name = "nGroupMembersRaw")

index <- assigned |>
  dplyr::left_join(groupSizes, by = "GroupId") |>
  dplyr::left_join(rawSizes, by = "GroupId") |>
  dplyr::transmute(
    loinc_number = .data$LoincNumber,
    loinc_name = .data$LongCommonName,
    category = .data$Category,
    parent_group_id = .data$ParentGroupId,
    group_id = .data$GroupId,
    group_name = .data$Group,
    n_group_members = .data$nGroupMembers,
    n_group_members_raw = .data$nGroupMembersRaw
  ) |>
  dplyr::arrange(.data$loinc_number)

perParent <- index |> dplyr::count(.data$parent_group_id, name = "nCodes")
for (i in seq_len(nrow(perParent))) {
  ParallelLogger::logInfo("  ", perParent$parent_group_id[i], ": ", perParent$nCodes[i], " codes")
}
ParallelLogger::logInfo(
  nrow(index), " codes assigned to ", dplyr::n_distinct(index$group_id), " groups, exactly one each"
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "loincGroupIndex.tsv")
readr::write_tsv(index, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(index), " rows to ", outFile)
