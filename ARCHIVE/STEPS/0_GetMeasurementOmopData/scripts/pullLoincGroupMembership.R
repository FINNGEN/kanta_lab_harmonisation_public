#
# Pulls LOINC Group membership for every standard Measurement concept, straight from the
# OMOP vocabulary -- concept_class_id = 'LOINC Group' ancestors via concept_ancestor.
#
# A LOINC Group is a value set of concepts that differ only in an axis the Group's rule
# rolls up -- Method above all. Two concepts in one Group are the same test measured
# differently, which is what 6_EvaluateMapping needs to tell "wrong analyte" apart from
# "right analyte, different decoration".
#
# Taken from the CDM rather than from LOINC's GroupFile distribution because the ancestor
# model answers the question actually being asked -- "do these two concepts share a Group?"
# -- as a set intersection. The GroupFile answers "which Group is this code in?", and since
# its ParentGroups overlap each other (334 of 8,551 codes in the Flowsheet categories sit
# in two Groups), using it meant inventing a precedence rule to force one Group per code,
# then comparing the forced assignments. The intersection needs no precedence and uses all
# ParentGroups at once. It also drops a licensed file from the pipeline's inputs and keeps
# the Groups on the same vocabulary release as every other concept this step pulls.
#
# IMPORTANT: OMOP models a ParentGroup as a 'LOINC Group' concept too -- LG100-4 is a
# concept named "Flowsheet - laboratory" with ~3,500 descendants, LG55-6 is "Mass-Molar
# conversion" with ~4,300. Sharing one of those means "both are lab chemistry" and means
# nothing. They are flagged structurally rather than by a size threshold: a ParentGroup is
# a Group that subsumes OTHER Groups, which picks out exactly the 45 ParentGroups that have
# child Groups and leaves genuine large value sets alone (LG32757-3 "Influenza virus", 460
# descendants, is a real Group and must survive). This script flags but does NOT filter, so
# the policy lives at the point of use.
#
# See RESEARCH/UnderstandingGroups.md for what the Groups are and what they cover.
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
# Size bands used only for the log summary -- the ParentGroup test is structural, not a
# threshold (see the header note).
sizeBandBreaks <- c(0, 10, 50, 200, 1000, Inf)
sizeBandLabels <- c("2-10", "11-50", "51-200", "201-1000", "> 1000")

pathToLoincGroupMembershipTSV <- file.path(outDir, "loinc_group_membership.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  environment = ", environment)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  domainId = ", domainId)
ParallelLogger::logInfo("  standardConceptFlag = ", standardConceptFlag)
ParallelLogger::logInfo("  groupConceptClassId = ", groupConceptClassId)

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
    CASE WHEN pg.ancestor_concept_id IS NULL THEN 0 ELSE 1 END AS is_parent_group
FROM @vocabularyDatabaseSchema.concept_ancestor ca
INNER JOIN @vocabularyDatabaseSchema.concept c
    ON c.concept_id = ca.descendant_concept_id
INNER JOIN @vocabularyDatabaseSchema.concept g
    ON g.concept_id = ca.ancestor_concept_id
INNER JOIN group_size gs
    ON gs.ancestor_concept_id = ca.ancestor_concept_id
LEFT JOIN parent_groups pg
    ON pg.ancestor_concept_id = ca.ancestor_concept_id
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
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::rename_with(tolower) |>
  dplyr::mutate(is_parent_group = .data$is_parent_group == 1)

ParallelLogger::logInfo(
  nrow(membership), " membership rows: ",
  dplyr::n_distinct(membership$concept_id), " concepts in ",
  dplyr::n_distinct(membership$group_concept_id), " Groups"
)

# The ParentGroup-level concepts, called out in the log so a reader of the output knows
# they are in there and why a consumer filters them.
parents <- membership |>
  dplyr::filter(.data$is_parent_group) |>
  dplyr::distinct(.data$group_concept_code, .data$group_concept_name, .data$n_descendants) |>
  dplyr::arrange(dplyr::desc(.data$n_descendants))
ParallelLogger::logInfo(
  nrow(parents), " of the Groups are ParentGroups (they subsume other Groups) -- ",
  "exclude them when testing whether two concepts share a Group:"
)
for (i in seq_len(min(nrow(parents), 10L))) {
  ParallelLogger::logInfo("  ", parents$group_concept_code[i], " (", parents$n_descendants[i],
                          " descendants) ", parents$group_concept_name[i])
}

sizeBands <- membership |>
  dplyr::distinct(.data$group_concept_id, .data$n_descendants, .data$is_parent_group) |>
  dplyr::mutate(band = cut(.data$n_descendants, breaks = sizeBandBreaks, labels = sizeBandLabels)) |>
  dplyr::count(.data$band, .data$is_parent_group)
for (i in seq_len(nrow(sizeBands))) {
  ParallelLogger::logInfo("  Groups with ", as.character(sizeBands$band[i]), " descendants",
                          if (sizeBands$is_parent_group[i]) " (ParentGroup)" else "", ": ", sizeBands$n[i])
}

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(membership, pathToLoincGroupMembershipTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(membership), " rows to ", pathToLoincGroupMembershipTSV)
