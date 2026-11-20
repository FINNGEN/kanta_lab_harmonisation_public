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
# The Groups are SI only. A conventional concept (the mass side of a mass-molar pair, e.g.
# ug/L against nmol/L) is put in the Groups of its SI partner instead of its own, using the
# conversion table of lab2clean, saved by 2a_GetHarmonisedUnitFromLab2Clean.
# Panels are in no Group. The Groups of the "Mass-Molar conversion" ParentGroup (LG55-6) pair
# a mass concept with a substance concept, so they are dropped.
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
conversionFile <- args[2]

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

# ParentGroup whose child Groups pair a mass concept with a substance concept.
massMolarParentGroupCode <- "LG55-6"

pathToLoincGroupsTSV <- file.path(outDir, "loincGroups.tsv")
pathToLoincGroupMembershipTSV <- file.path(outDir, "loincGroupMembership.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  environment = ", environment)
ParallelLogger::logInfo("  conversionFile = ", conversionFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  domainId = ", domainId)
ParallelLogger::logInfo("  standardConceptFlag = ", standardConceptFlag)
ParallelLogger::logInfo("  groupConceptClassId = ", groupConceptClassId)
ParallelLogger::logInfo("  groupNamePrefix = ", groupNamePrefix)
ParallelLogger::logInfo("  massMolarParentGroupCode = ", massMolarParentGroupCode)

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
mass_molar_groups AS (
    -- The child Groups of the Mass-Molar conversion ParentGroup.
    SELECT DISTINCT ca.descendant_concept_id AS group_concept_id
    FROM @vocabularyDatabaseSchema.concept_ancestor ca
    INNER JOIN @vocabularyDatabaseSchema.concept p
        ON p.concept_id = ca.ancestor_concept_id
    WHERE p.concept_code = '@massMolarParentGroupCode'
        AND p.concept_class_id = '@groupConceptClassId'
        AND ca.ancestor_concept_id <> ca.descendant_concept_id
),
panels AS (
    SELECT DISTINCT cr.concept_id_1 AS concept_id
    FROM @vocabularyDatabaseSchema.concept_relationship cr
    WHERE cr.relationship_id = 'Panel contains'
        AND cr.invalid_reason IS NULL
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
    CASE WHEN mm.group_concept_id IS NULL THEN 0 ELSE 1 END AS is_mass_molar_group,
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
LEFT JOIN mass_molar_groups mm
    ON mm.group_concept_id = ca.ancestor_concept_id
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
  massMolarParentGroupCode = massMolarParentGroupCode,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::rename_with(tolower) |>
  dplyr::mutate(
    is_parent_group = .data$is_parent_group == 1,
    is_mass_molar_group = .data$is_mass_molar_group == 1,
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
# mass-molar Groups (they mix both unit systems). A panel is in no Group. A concept can be in
# several Groups and keeps all of them: whether two concepts share a Group is a set
# intersection and needs no precedence rule.
ParallelLogger::logInfo(
  dplyr::n_distinct(membership$concept_id[membership$is_panel & membership$concept_id %in% flowsheetConceptIds]),
  " panel concepts are left out of the Groups; ",
  dplyr::n_distinct(membership$group_concept_id[membership$is_mass_molar_group]), " mass-molar Groups are dropped"
)
membership <- membership |>
  dplyr::filter(
    .data$concept_id %in% flowsheetConceptIds,
    !.data$is_parent_group, !.data$is_mass_molar_group, !.data$is_panel
  ) |>
  dplyr::select(-"is_parent_group", -"is_mass_molar_group", -"is_panel") |>
  dplyr::arrange(.data$concept_id, .data$n_descendants, .data$group_concept_code)
ParallelLogger::logInfo(
  "Kept ", nrow(membership), " of ", nAllRows, " membership rows: ",
  dplyr::n_distinct(membership$concept_id), " concepts in ",
  dplyr::n_distinct(membership$group_concept_id), " Groups"
)

# SI only. The conventional concepts take the Groups of their SI partner instead of their own;
# one whose partner is in no Group is in no Group.
conversion <- readr::read_tsv(conversionFile, show_col_types = FALSE, na = "", col_types = readr::cols(.default = "c"))
ParallelLogger::logInfo("Read ", nrow(conversion), " conventional-to-SI codes from ", conversionFile)
conventionalToSi <- conversion |>
  dplyr::filter(!is.na(.data$concept_id), !is.na(.data$si_concept_id)) |>
  dplyr::transmute(conventionalId = .data$concept_id, siId = .data$si_concept_id)
membership <- membership |>
  dplyr::mutate(concept_id = as.character(.data$concept_id))
siMembership <- membership |>
  dplyr::inner_join(conventionalToSi, by = c("concept_id" = "siId"), relationship = "many-to-many") |>
  dplyr::mutate(concept_id = .data$conventionalId) |>
  dplyr::select(-"conventionalId")
nConventional <- dplyr::n_distinct(siMembership$concept_id)
membership <- membership |>
  dplyr::filter(!.data$concept_id %in% conventionalToSi$conventionalId) |>
  dplyr::bind_rows(siMembership) |>
  dplyr::distinct() |>
  dplyr::arrange(as.numeric(.data$concept_id), .data$n_descendants, .data$group_concept_code)
ParallelLogger::logInfo(
  nConventional, " conventional concepts are mapped to the Groups of their SI partner; ",
  "the rest of the conventional concepts are in no Group"
)
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
