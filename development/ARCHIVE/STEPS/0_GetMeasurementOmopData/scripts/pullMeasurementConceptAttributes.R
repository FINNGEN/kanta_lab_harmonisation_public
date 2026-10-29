#
# Connects to the FinnGen OMOP CDM and pulls, for every STANDARD concept in the Measurement
# domain, one row per concept_id with:
#   concept_id, concept_code, concept_name, vocabulary_id, is_panel, <one column per "Has ..." attribute relationship>
#
# The attribute columns are discovered at run time (Step 1) rather than hard-coded, since
# different vocabularies (LOINC, SNOMED, ...) attach different sets of "Has ..."
# relationships to their Measurement concepts. Step 2 keeps only LOINC's 6 core axes and
# pivots them into columns, using the concept_name of the related concept (concept_id_2),
# not its concept_id. Step 3 flags concepts that are panels (bundle several component
# tests, e.g. a metabolic panel) via the 'Panel contains' relationship.
#
# Reference: Athena (athena.ohdsi.org) shows these same relationships on a concept's page,
# e.g. for a LOINC urine protein test strip concept:
#   Has component -> Protein, Has method -> Test strip, Has property -> Presence or Threshold,
#   Has scale type -> Ord, Has system -> Urine, Has time aspect -> Point in time (spot)
#
# See this step's README.md for what each output column means.
#

#
# --- Libraries -------------------------------------------------------------
#
library(FinnGenUtilsR)
library(DatabaseConnector)
library(dplyr)
library(tidyr)
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

# Kept broad on purpose: all STANDARD concepts in the Measurement domain (any vocabulary),
# except 'OMOP Genomic' — the ~205k gene-variant concepts (Gene DNA/RNA/Protein Variant,
# Genetic Variation, ...), which dominate the domain by count but never carry the 6 core
# LOINC attributes, so they only add noise here.
domainId <- "Measurement"
standardConceptFlag <- "S"
excludedVocabularyIds <- c("OMOP Genomic")
excludedVocabularyIdsSql <- paste0("'", excludedVocabularyIds, "'", collapse = ", ")

# LOINC's 6-axis model — the same attributes Athena shows on a lab test's concept page.
coreAttributeRelationshipIds <- c(
  "Has component",
  "Has method",
  "Has property",
  "Has scale type",
  "Has system",
  "Has time aspect"
)

pathToDiscoveredAttributesTSV <- file.path(outDir, "measurement_attribute_relationships.tsv")
pathToConceptAttributesTSV <- file.path(outDir, "measurement_concept_attributes.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  environment = ", environment)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  domainId = ", domainId)
ParallelLogger::logInfo("  standardConceptFlag = ", standardConceptFlag)
ParallelLogger::logInfo("  excludedVocabularyIds = ", paste(excludedVocabularyIds, collapse = ", "))

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

# Step 1: discover which attribute relationships Measurement concepts use.
# concept_relationship rows where a standard Measurement concept is concept_id_1. This
# includes hierarchical relationships (e.g. "Subsumes", "Is a", "Maps to") as well as the
# attribute relationships we want (they all start with "Has "), so we inspect the full list
# first and then keep only the "Has ..." ones.
sql_discover <- "
SELECT
    cr.relationship_id,
    COUNT(*) AS n_rows
FROM @vocabularyDatabaseSchema.concept_relationship cr
INNER JOIN @vocabularyDatabaseSchema.concept c1
    ON c1.concept_id = cr.concept_id_1
WHERE c1.domain_id = '@domainId'
    AND c1.standard_concept = '@standardConceptFlag'
    AND c1.vocabulary_id NOT IN (@excludedVocabularyIdsSql)
    AND cr.invalid_reason IS NULL
GROUP BY cr.relationship_id
ORDER BY n_rows DESC
"

relationshipCounts <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sql_discover,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble()

ParallelLogger::logInfo("Discovered ", nrow(relationshipCounts), " relationship_id types attached to standard '", domainId, "' concepts")

# Step 1 discovers 40+ "Has ..." relationships, but most of those (has_finding_site,
# has_causative_agent, ...) are SNOMED CT clinical attributes that only occur on non-LOINC
# "finding" concepts, not on lab test protocols. Step 2 keeps only LOINC's 6 core axes.
attributeRelationshipIds <- relationshipCounts |>
  dplyr::filter(relationship_id %in% coreAttributeRelationshipIds) |>
  dplyr::pull(relationship_id)

ParallelLogger::logInfo("Using ", length(attributeRelationshipIds), " core LOINC attribute relationships: ", paste(attributeRelationshipIds, collapse = ", "))

# Step 2: pull concept_id / concept_name / attribute concept_names.
sql_attributes <- "
SELECT
    cr.concept_id_1 AS concept_id,
    cr.relationship_id,
    c2.concept_name AS attribute_concept_name
FROM @vocabularyDatabaseSchema.concept_relationship cr
INNER JOIN @vocabularyDatabaseSchema.concept c1
    ON c1.concept_id = cr.concept_id_1
INNER JOIN @vocabularyDatabaseSchema.concept c2
    ON c2.concept_id = cr.concept_id_2
WHERE c1.domain_id = '@domainId'
    AND c1.standard_concept = '@standardConceptFlag'
    AND c1.vocabulary_id NOT IN (@excludedVocabularyIdsSql)
    AND cr.invalid_reason IS NULL
    AND cr.relationship_id IN (@attributeRelationshipIds)
"

conceptAttributesLong <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sql_attributes,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  attributeRelationshipIds = paste0("'", attributeRelationshipIds, "'", collapse = ", "),
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble()

# column name for each relationship, e.g. "Has component" -> "has_component"
.toSnakeCase <- function(x) {
  x |>
    tolower() |>
    gsub("[^a-z0-9]+", "_", x = _) |>
    gsub("^_|_$", "", x = _)
}

conceptAttributesWide <- conceptAttributesLong |>
  dplyr::mutate(relationship_id = .toSnakeCase(relationship_id)) |>
  dplyr::group_by(concept_id, relationship_id) |>
  dplyr::summarise(
    attribute_concept_name = paste(sort(unique(attribute_concept_name)), collapse = "; "),
    .groups = "drop"
  ) |>
  tidyr::pivot_wider(
    id_cols = concept_id,
    names_from = relationship_id,
    values_from = attribute_concept_name
  )

# Step 3: flag panel concepts (e.g. a metabolic panel bundling several lab tests).
# There is no dedicated concept_class_id for panels; a concept is a panel when it has at
# least one outgoing 'Panel contains' relationship pointing at its component tests.
sql_panels <- "
SELECT DISTINCT cr.concept_id_1 AS concept_id
FROM @vocabularyDatabaseSchema.concept_relationship cr
INNER JOIN @vocabularyDatabaseSchema.concept c1
    ON c1.concept_id = cr.concept_id_1
WHERE c1.domain_id = '@domainId'
    AND c1.standard_concept = '@standardConceptFlag'
    AND c1.vocabulary_id NOT IN (@excludedVocabularyIdsSql)
    AND cr.relationship_id = 'Panel contains'
    AND cr.invalid_reason IS NULL
"

panelConceptIds <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sql_panels,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::pull(concept_id)

ParallelLogger::logInfo("Flagged ", length(panelConceptIds), " concepts as panels (have 'Panel contains' relationships)")

# Base measurement concepts (concept_id, concept_code, concept_name, vocabulary_id).
sql_concepts <- "
SELECT
    concept_id,
    concept_code,
    concept_name,
    vocabulary_id
FROM @vocabularyDatabaseSchema.concept
WHERE domain_id = '@domainId'
    AND standard_concept = '@standardConceptFlag'
    AND vocabulary_id NOT IN (@excludedVocabularyIdsSql)
"

measurementConcepts <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sql_concepts,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  excludedVocabularyIdsSql = excludedVocabularyIdsSql,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble()

# Final table: concept_id, concept_code, concept_name, is_panel, one column per attribute.
measurementConceptAttributes <- measurementConcepts |>
  dplyr::mutate(is_panel = concept_id %in% panelConceptIds) |>
  dplyr::left_join(conceptAttributesWide, by = "concept_id") |>
  dplyr::select(-dplyr::any_of("id")) |>
  dplyr::relocate(concept_id, concept_code) |>
  dplyr::arrange(concept_id)

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(relationshipCounts, pathToDiscoveredAttributesTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(relationshipCounts), " rows to ", pathToDiscoveredAttributesTSV)

readr::write_tsv(measurementConceptAttributes, pathToConceptAttributesTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(measurementConceptAttributes), " standard '", domainId, "' concepts with attributes to ", pathToConceptAttributesTSV)
