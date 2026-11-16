#
# Pulls the LOINC Groups of the standard Measurement concepts from the OMOP vocabulary
# (concept_class_id = 'LOINC Group' ancestors via concept_ancestor), and gives each Group
# its harmonised unit from lab2clean.
#
# A LOINC Group is a value set of concepts that differ only in an axis the Group's rule
# rolls up -- Method above all. Two concepts in one Group are the same test measured
# differently, so they can share one unit.
#
# IMPORTANT: OMOP models a ParentGroup as a 'LOINC Group' concept too -- LG100-4 is a
# concept named "Flowsheet - laboratory" with ~3,500 descendants, LG55-6 is "Mass-Molar
# conversion" with ~4,300. Sharing one of those means "both are lab chemistry" and means
# nothing. They are flagged structurally, as a Group that subsumes OTHER Groups. This script
# drops the ParentGroups from its output; the Flowsheet ones are only used to pick the
# concepts to keep.
#
# The harmonised unit of a Group is lab2clean's reference_unit (Zayed et al., Int J Med
# Inform 205 (2026) 106131). lab2clean's table loinc_reference_unit_v1 has one row per LOINC
# code with its UCUM reference_unit, and its property_group_id ("<ParentGroupId>/<GroupId>")
# names the Group. lab2clean chooses the unit per Group, so every code of a Group and unit
# system has the same unit. It is read from the lab2clean source package on CRAN.
#
# The Groups are SI only. A concept whose lab2clean unit system is "conventional" (the mass
# side of a mass-molar pair, e.g. ug/L against nmol/L) is put in the Groups of its SI partner
# (lab2clean's mass_molar_loinc), and the conventional/SI conversion is saved for a later step.
# Panels are in no Group. The Groups of the "Mass-Molar conversion" ParentGroup (LG55-6) mix
# both unit systems, so they are dropped.
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

# lab2clean, read from its source tarball on CRAN (pinned version).
lab2cleanVersion <- "2.0.0"
lab2cleanUrl <- paste0("https://cran.r-project.org/src/contrib/lab2clean_", lab2cleanVersion, ".tar.gz")
lab2cleanDataFile <- "lab2clean/data/loinc_reference_unit_v1.rda"
# ParentGroup whose child Groups pair a mass concept with a substance concept.
massMolarParentGroupCode <- "LG55-6"

pathToConversionTSV <- file.path(outDir, "loincSiConventionalConversion.tsv")
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
ParallelLogger::logInfo("  massMolarParentGroupCode = ", massMolarParentGroupCode)
ParallelLogger::logInfo("  lab2cleanUrl = ", lab2cleanUrl)

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

# The harmonised unit of each Group, from lab2clean: the SI reference_unit of the codes whose
# property_group_id ends in the Group's LG code. A Group lab2clean does not have gets no unit.
tarFile <- tempfile(fileext = ".tar.gz")
download.file(lab2cleanUrl, tarFile, mode = "wb", quiet = TRUE)
untar(tarFile, files = lab2cleanDataFile, exdir = tempdir())
lab2cleanEnv <- new.env()
load(file.path(tempdir(), lab2cleanDataFile), envir = lab2cleanEnv)
loincReferenceUnit <- tibble::as_tibble(lab2cleanEnv$loinc_reference_unit_v1)
ParallelLogger::logInfo("Read ", nrow(loincReferenceUnit), " LOINC codes from lab2clean ", lab2cleanVersion)

# SI only. The concepts whose lab2clean unit system is "conventional" are the mass side of a
# mass-molar pair; lab2clean's mass_molar_loinc is their SI partner. They get the Groups of
# the partner instead of their own, and the conversion between the two is saved.
sqlLoincConcepts <- "
SELECT concept_id, concept_code
FROM @vocabularyDatabaseSchema.concept
WHERE domain_id = '@domainId'
    AND standard_concept = '@standardConceptFlag'
    AND vocabulary_id = 'LOINC'
"
loincConcepts <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sqlLoincConcepts,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::rename_with(tolower) |>
  dplyr::mutate(concept_id = as.numeric(.data$concept_id))

conversion <- loincReferenceUnit |>
  dplyr::filter(.data$unit_system == "conventional", !is.na(.data$mass_molar_loinc)) |>
  dplyr::transmute(
    concept_code = .data$loinc_code,
    conventional_unit = .data$reference_unit,
    si_concept_code = .data$mass_molar_loinc,
    si_unit = .data$mass_molar_unit,
    molecular_weight = .data$molecular_weight
  ) |>
  dplyr::left_join(loincConcepts, by = "concept_code") |>
  dplyr::left_join(
    dplyr::rename(loincConcepts, si_concept_id = "concept_id", si_concept_code = "concept_code"),
    by = "si_concept_code"
  ) |>
  dplyr::select(
    "concept_id", "concept_code", "conventional_unit",
    "si_concept_id", "si_concept_code", "si_unit", "molecular_weight"
  ) |>
  dplyr::arrange(.data$concept_code)
ParallelLogger::logInfo(
  "lab2clean has ", nrow(conversion), " conventional codes with an SI partner; ",
  sum(!is.na(conversion$concept_id) & !is.na(conversion$si_concept_id)), " have both concepts in the vocabulary"
)

conventionalToSi <- conversion |>
  dplyr::filter(!is.na(.data$concept_id), !is.na(.data$si_concept_id)) |>
  dplyr::transmute(conventionalId = as.character(.data$concept_id), siId = as.character(.data$si_concept_id))
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


lab2cleanGroupUnit <- loincReferenceUnit |>
  dplyr::filter(!is.na(.data$property_group_id), !is.na(.data$reference_unit), .data$unit_system == "si") |>
  dplyr::mutate(group_concept_code = sub(".*/", "", .data$property_group_id)) |>
  dplyr::group_by(.data$group_concept_code) |>
  dplyr::summarise(
    n_units = dplyr::n_distinct(.data$reference_unit),
    group_harmonised_unit = dplyr::first(.data$reference_unit),
    .groups = "drop"
  )
if (any(lab2cleanGroupUnit$n_units > 1)) {
  ParallelLogger::logWarn(sum(lab2cleanGroupUnit$n_units > 1), " Groups have more than one lab2clean unit; the first is used")
}
ParallelLogger::logInfo("lab2clean gives a unit to ", nrow(lab2cleanGroupUnit), " Groups")

groups <- membership |>
  dplyr::distinct(.data$group_concept_id, .data$group_concept_code, .data$group_concept_name) |>
  dplyr::left_join(
    dplyr::select(lab2cleanGroupUnit, "group_concept_code", "group_harmonised_unit"),
    by = "group_concept_code"
  ) |>
  dplyr::arrange(.data$group_concept_code)
ParallelLogger::logInfo(
  sum(!is.na(groups$group_harmonised_unit)), " of ", nrow(groups), " Groups have a harmonised unit"
)

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(conversion, pathToConversionTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(conversion), " rows to ", pathToConversionTSV)
readr::write_tsv(groups, pathToLoincGroupsTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(groups), " Groups to ", pathToLoincGroupsTSV)
readr::write_tsv(dplyr::select(membership, "concept_id", "group_concept_id"), pathToLoincGroupMembershipTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(membership), " rows to ", pathToLoincGroupMembershipTSV)
