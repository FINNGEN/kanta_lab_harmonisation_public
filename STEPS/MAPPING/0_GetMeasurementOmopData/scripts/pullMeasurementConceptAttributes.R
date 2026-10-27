#
# Connects to the FinnGen OMOP CDM and pulls, for every STANDARD concept in the Measurement
# domain, one row per concept_id with:
#   concept_id, concept_code, concept_name, vocabulary_id, is_panel, <one column per "Has ..." attribute relationship>
#
# Step 1 keeps only LOINC's 6 core axes and pivots them into columns, using the
# concept_name of the related concept (concept_id_2), not its concept_id. Step 2 flags
# concepts that are panels (bundle several component tests, e.g. a metabolic panel) via the
# 'Panel contains' relationship.
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

# Step 1: pull concept_id / attribute concept_names for LOINC's 6 core axes.
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
  attributeRelationshipIds = paste0("'", coreAttributeRelationshipIds, "'", collapse = ", "),
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

# Step 2: flag panel concepts (e.g. a metabolic panel bundling several lab tests).
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
readr::write_tsv(measurementConceptAttributes, pathToConceptAttributesTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(measurementConceptAttributes), " standard '", domainId, "' concepts with attributes to ", pathToConceptAttributesTSV)
