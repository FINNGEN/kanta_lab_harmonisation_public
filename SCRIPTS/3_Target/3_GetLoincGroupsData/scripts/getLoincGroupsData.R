#
# Pulls the LOINC Groups of the standard Measurement concepts from the OMOP vocabulary
# (concept_class_id = 'LOINC Group' ancestors via concept_ancestor).
#
# A LOINC Group is a value set of concepts that differ only in an axis the Group's rule
# rolls up -- Method above all. Two concepts in one Group are the same test measured
# differently.
#
# IMPORTANT: OMOP models a ParentGroup as a 'LOINC Group' concept too -- LG100-4 is a
# concept named "Flowsheet - laboratory" with ~3,500 descendants, LG55-6 is "Mass-Molar
# conversion" with ~4,300. Sharing one of those means "both are lab chemistry" and means
# nothing. They are flagged structurally, as a Group that subsumes OTHER Groups. This script
# drops the ParentGroups from its output; the Flowsheet ones are only used to pick the
# concepts to keep.
#
# Every concept keeps its own Groups: a conventional concept (the mass side of a mass-molar pair)
# and its SI partner are both targets, each in its own Groups.
# Panels are in no Group. The Groups of the "Mass-Molar conversion" ParentGroup (LG55-6) pair
# a mass concept with a substance concept, and those of the "UrineAndSed" ParentGroup (LG97-8)
# mix properties, so both are dropped. So are the panel Groups (e.g. "Supersaturation panel|-|Urine"):
# a Group whose direct children are panel concepts holds the members of the panel, tests ordered
# together (pH, osmolality, 24 h rates, ...), not the same test.
#
# See this step's README.md for the outputs.
#

#
# --- Libraries -------------------------------------------------------------
#
library(FinnGenUtilsR)
library(DatabaseConnector)
library(dplyr)
library(readr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
outDir <- args[1]

environment <- Sys.getenv("FG_DATABASE_ENV")
if (environment == "") {
  stop("FG_DATABASE_ENV is not set")
}

# Matches pullMeasurementConceptAttributes.R, so the two outputs join on concept_id
# without a gap: same domain, same standard flag, same exclusion.
domainId <- "Measurement"
standardConceptFlag <- "S"
excludedVocabularyIds <- c("OMOP Genomic")
excludedVocabularyIdsSql <- paste0("'", excludedVocabularyIds, "'", collapse = ", ")
groupConceptClassId <- "LOINC Group"
# The concepts kept are those in a Group whose name starts with this (the Flowsheet ParentGroups).
groupNamePrefix <- "Flowsheet"
# Size bands used only for the log summary.
sizeBandBreaks <- c(0, 10, 50, 200, 1000, Inf)
sizeBandLabels <- c("2-10", "11-50", "51-200", "201-1000", "> 1000")

# ParentGroups whose child Groups are dropped: "Mass-Molar conversion" (LG55-6) pairs a mass
# concept with a substance concept; "UrineAndSed" (LG97-8) keeps only the component and rolls up
# the property, so it mixes counts per field, per volume, mass and presence (lab2clean does not
# use it either).
excludedParentGroupCodes <- c("LG55-6", "LG97-8")
excludedParentGroupCodesSql <- paste0("'", excludedParentGroupCodes, "'", collapse = ", ")
# The property field of the name of a panel Group is "-" (no single property): only used to check that
# no Group named as a panel is missed by the vocabulary structure. The structure also finds a few Groups
# by component with a panel among their children (e.g. "Hepatitis C virus"); they mix properties too.
panelGroupNamePattern <- "|-|"

pathToLoincGroupsTSV <- file.path(outDir, "loincGroups.tsv")
pathToLoincGroupMembershipTSV <- file.path(outDir, "loincGroupMembership.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  environment = ", environment)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  domainId = ", domainId)
ParallelLogger::logInfo("  standardConceptFlag = ", standardConceptFlag)
ParallelLogger::logInfo("  groupConceptClassId = ", groupConceptClassId)
ParallelLogger::logInfo("  groupNamePrefix = ", groupNamePrefix)
ParallelLogger::logInfo("  excludedParentGroupCodes = ", paste(excludedParentGroupCodes, collapse = ", "))
ParallelLogger::logInfo("  panelGroupNamePattern = ", panelGroupNamePattern)

#
# --- Connections -------------------------------------------------------------
#
info <- FinnGenUtilsR::fg_getDatabaseConnector(environment)
connectionDetails <- info$connectionDetails
vocabularyDatabaseSchema <- info$vocabularyDatabaseSchema

connection <- DatabaseConnector::connect(connectionDetails)
on.exit(DatabaseConnector::disconnect(connection), add = TRUE)

#
# --- Action -------------------------------------------------------------
#

# One row per (concept, Group it belongs to). n_descendants counts only the standard
# Measurement concepts under the Group, i.e. how many of the concepts this pipeline can
# actually choose from the Group covers -- the number the consumer caps on.
sql <- "
WITH parent_groups AS (
    -- A Group that subsumes other Groups is a ParentGroup: a grouping RULE, not a value
    -- set. LG100-4 'Flowsheet - laboratory' subsumes 1,687 Groups; LG55-6 'Mass-Molar
    -- conversion' subsumes 2,270. Two concepts sharing one of those share only a category.
    SELECT DISTINCT ca.ancestor_concept_id
    FROM @vocabularyDatabaseSchema.concept_ancestor ca
    INNER JOIN @vocabularyDatabaseSchema.concept g
        ON g.concept_id = ca.ancestor_concept_id
    INNER JOIN @vocabularyDatabaseSchema.concept cg
        ON cg.concept_id = ca.descendant_concept_id
    WHERE g.concept_class_id = '@groupConceptClassId'
        AND cg.concept_class_id = '@groupConceptClassId'
        AND ca.ancestor_concept_id <> ca.descendant_concept_id
),
excluded_groups AS (
    -- The child Groups of the excluded ParentGroups (Mass-Molar conversion, UrineAndSed).
    SELECT DISTINCT ca.descendant_concept_id AS group_concept_id
    FROM @vocabularyDatabaseSchema.concept_ancestor ca
    INNER JOIN @vocabularyDatabaseSchema.concept p
        ON p.concept_id = ca.ancestor_concept_id
    WHERE p.concept_code IN (@excludedParentGroupCodesSql)
        AND p.concept_class_id = '@groupConceptClassId'
        AND ca.ancestor_concept_id <> ca.descendant_concept_id
),
panels AS (
    SELECT DISTINCT cr.concept_id_1 AS concept_id
    FROM @vocabularyDatabaseSchema.concept_relationship cr
    WHERE cr.relationship_id = 'Panel contains'
        AND cr.invalid_reason IS NULL
),
panel_groups AS (
    -- A Group whose direct children are panel concepts: it holds the members of the panel, tests
    -- ordered together with different properties, not the same test.
    SELECT DISTINCT ca.ancestor_concept_id AS group_concept_id
    FROM @vocabularyDatabaseSchema.concept_ancestor ca
    INNER JOIN @vocabularyDatabaseSchema.concept g
        ON g.concept_id = ca.ancestor_concept_id
    INNER JOIN panels pa
        ON pa.concept_id = ca.descendant_concept_id
    WHERE g.concept_class_id = '@groupConceptClassId'
        AND ca.min_levels_of_separation = 1
),
group_size AS (
    SELECT
        ca.ancestor_concept_id,
        COUNT(DISTINCT ca.descendant_concept_id) AS n_descendants
    FROM @vocabularyDatabaseSchema.concept_ancestor ca
    INNER JOIN @vocabularyDatabaseSchema.concept d
        ON d.concept_id = ca.descendant_concept_id
    INNER JOIN @vocabularyDatabaseSchema.concept g
        ON g.concept_id = ca.ancestor_concept_id
    WHERE g.concept_class_id = '@groupConceptClassId'
        AND g.vocabulary_id = 'LOINC'
        AND d.domain_id = '@domainId'
        AND d.standard_concept = '@standardConceptFlag'
    GROUP BY ca.ancestor_concept_id
)
SELECT
    ca.descendant_concept_id AS concept_id,
    ca.ancestor_concept_id AS group_concept_id,
    g.concept_code AS group_concept_code,
    g.concept_name AS group_concept_name,
    gs.n_descendants AS n_descendants,
    CASE WHEN pg.ancestor_concept_id IS NULL THEN 0 ELSE 1 END AS is_parent_group,
    CASE WHEN eg.group_concept_id IS NULL THEN 0 ELSE 1 END AS is_excluded_group,
    CASE WHEN pgr.group_concept_id IS NULL THEN 0 ELSE 1 END AS is_panel_group,
    CASE WHEN pa.concept_id IS NULL THEN 0 ELSE 1 END AS is_panel
FROM @vocabularyDatabaseSchema.concept_ancestor ca
INNER JOIN @vocabularyDatabaseSchema.concept c
    ON c.concept_id = ca.descendant_concept_id
INNER JOIN @vocabularyDatabaseSchema.concept g
    ON g.concept_id = ca.ancestor_concept_id
INNER JOIN group_size gs
    ON gs.ancestor_concept_id = ca.ancestor_concept_id
LEFT JOIN parent_groups pg
    ON pg.ancestor_concept_id = ca.ancestor_concept_id
LEFT JOIN excluded_groups eg
    ON eg.group_concept_id = ca.ancestor_concept_id
LEFT JOIN panel_groups pgr
    ON pgr.group_concept_id = ca.ancestor_concept_id
LEFT JOIN panels pa
    ON pa.concept_id = ca.descendant_concept_id
WHERE g.concept_class_id = '@groupConceptClassId'
    AND g.vocabulary_id = 'LOINC'
    AND c.domain_id = '@domainId'
    AND c.standard_concept = '@standardConceptFlag'
    AND c.vocabulary_id NOT IN (@excludedVocabularyIdsSql)
ORDER BY concept_id, n_descendants
"

membership <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sql,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  groupConceptClassId = groupConceptClassId,
  excludedParentGroupCodesSql = excludedParentGroupCodesSql,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::rename_with(tolower) |>
  dplyr::mutate(
    is_parent_group = .data$is_parent_group == 1,
    is_excluded_group = .data$is_excluded_group == 1,
    is_panel_group = .data$is_panel_group == 1,
    is_panel = .data$is_panel == 1
  )

# The Flowsheet ParentGroups ("Flowsheet - laboratory", ...) only select the concepts to
# keep: the concepts that are lab tests, vital signs, weight, height or head circumference.
nAllRows <- nrow(membership)
flowsheetConceptIds <- membership |>
  dplyr::filter(startsWith(.data$group_concept_name, groupNamePrefix)) |>
  dplyr::pull(.data$concept_id) |>
  unique()
ParallelLogger::logInfo(
  length(flowsheetConceptIds), " concepts are in a Group whose name starts with '", groupNamePrefix, "'"
)

# What is kept is the real LOINC Groups of those concepts, never the ParentGroups (they are
# grouping rules that subsume other Groups, not sets of equivalent tests), and never the
# Groups of the excluded ParentGroups (mass-molar Groups mix both unit systems, UrineAndSed
# Groups mix properties), and never the panel Groups (the members of a panel). A panel is in no
# Group. A concept can be in
# several Groups and keeps all of them: whether two concepts share a Group is a set
# intersection and needs no precedence rule.
ParallelLogger::logInfo(
  dplyr::n_distinct(membership$concept_id[membership$is_panel & membership$concept_id %in% flowsheetConceptIds]),
  " panel concepts are left out of the Groups; ",
  dplyr::n_distinct(membership$group_concept_id[membership$is_excluded_group]), " Groups of the excluded ParentGroups are dropped"
)

# The panel Groups of the concepts kept, checked against the name: a Group named with "-" as property
# that is not found by structure is logged as a warning.
candidateGroups <- membership |>
  dplyr::filter(.data$concept_id %in% flowsheetConceptIds, !.data$is_parent_group, !.data$is_excluded_group) |>
  dplyr::distinct(.data$group_concept_code, .data$group_concept_name, .data$is_panel_group)
panelGroups <- dplyr::filter(candidateGroups, .data$is_panel_group)
ParallelLogger::logInfo(nrow(panelGroups), " panel Groups are dropped:")
for (i in seq_len(nrow(panelGroups))) {
  ParallelLogger::logInfo("  ", panelGroups$group_concept_code[i], " ", panelGroups$group_concept_name[i])
}
panelGroupsByName <- grepl(panelGroupNamePattern, candidateGroups$group_concept_name, fixed = TRUE)
ParallelLogger::logInfo(
  sum(candidateGroups$is_panel_group & !panelGroupsByName), " of them are not named with '",
  panelGroupNamePattern, "' (Groups by component with a panel among their children)"
)
for (i in which(panelGroupsByName & !candidateGroups$is_panel_group)) {
  ParallelLogger::logWarn(
    "Group named as a panel but with no panel among its children, kept: ",
    candidateGroups$group_concept_code[i], " ", candidateGroups$group_concept_name[i]
  )
}
membership <- membership |>
  dplyr::filter(
    .data$concept_id %in% flowsheetConceptIds,
    !.data$is_parent_group, !.data$is_excluded_group, !.data$is_panel_group, !.data$is_panel
  ) |>
  dplyr::select(-"is_parent_group", -"is_excluded_group", -"is_panel_group", -"is_panel") |>
  dplyr::arrange(.data$concept_id, .data$n_descendants, .data$group_concept_code)
ParallelLogger::logInfo(
  "Kept ", nrow(membership), " of ", nAllRows, " membership rows: ",
  dplyr::n_distinct(membership$concept_id), " concepts in ",
  dplyr::n_distinct(membership$group_concept_id), " Groups"
)

membership <- membership |>
  dplyr::mutate(concept_id = as.character(.data$concept_id)) |>
  dplyr::arrange(as.numeric(.data$concept_id), .data$n_descendants, .data$group_concept_code)
ParallelLogger::logInfo(
  "Membership: ", nrow(membership), " rows, ", dplyr::n_distinct(membership$concept_id), " concepts in ",
  dplyr::n_distinct(membership$group_concept_id), " Groups"
)

groupsPerConcept <- dplyr::count(membership, .data$concept_id)
ParallelLogger::logInfo(
  sum(groupsPerConcept$n > 1), " concepts are in more than one Group (at most ", max(groupsPerConcept$n), ")"
)

sizeBands <- membership |>
  dplyr::distinct(.data$group_concept_id, .data$n_descendants) |>
  dplyr::mutate(band = cut(.data$n_descendants, breaks = sizeBandBreaks, labels = sizeBandLabels)) |>
  dplyr::count(.data$band)
for (i in seq_len(nrow(sizeBands))) {
  ParallelLogger::logInfo("  Groups with ", as.character(sizeBands$band[i]), " descendants: ", sizeBands$n[i])
}


groups <- membership |>
  dplyr::distinct(.data$group_concept_id, .data$group_concept_code, .data$group_concept_name) |>
  dplyr::arrange(.data$group_concept_code)
ParallelLogger::logInfo(nrow(groups), " Groups")

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(groups, pathToLoincGroupsTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(groups), " Groups to ", pathToLoincGroupsTSV)
readr::write_tsv(dplyr::select(membership, "concept_id", "group_concept_id"), pathToLoincGroupMembershipTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(membership), " rows to ", pathToLoincGroupMembershipTSV)
