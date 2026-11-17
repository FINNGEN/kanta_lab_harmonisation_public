#
# Gets the harmonised unit lab2clean (Zayed et al., Int J Med Inform 205 (2026) 106131) gives
# to every OMOP concept it has, every concept in an SI unit.
#
# lab2clean's table loinc_reference_unit_v1 has one row per LOINC code with its UCUM
# reference_unit and its unit_system: "si" or "conventional". The conventional codes (1,662)
# are the mass side of a mass-molar pair (e.g. ug/L against nmol/L); mass_molar_loinc is the
# SI partner, mass_molar_unit its unit and molecular_weight what converts between the two.
# The table is read from the lab2clean source package on CRAN.
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

# Same domain and standard flag as 1_GetMeasurementOmopData, so the concept_ids match.
domainId <- "Measurement"
standardConceptFlag <- "S"
vocabularyId <- "LOINC"

# lab2clean, read from its source tarball on CRAN (pinned version).
lab2cleanVersion <- "2.0.0"
lab2cleanUrl <- paste0("https://cran.r-project.org/src/contrib/lab2clean_", lab2cleanVersion, ".tar.gz")
lab2cleanDataFile <- "lab2clean/data/loinc_reference_unit_v1.rda"

pathToHarmonisedUnitTSV <- file.path(outDir, "harmonisedUnit_lab2clean.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  environment = ", environment)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  domainId = ", domainId)
ParallelLogger::logInfo("  standardConceptFlag = ", standardConceptFlag)
ParallelLogger::logInfo("  vocabularyId = ", vocabularyId)
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
# --- Input -------------------------------------------------------------
#
tarFile <- tempfile(fileext = ".tar.gz")
download.file(lab2cleanUrl, tarFile, mode = "wb", quiet = TRUE)
untar(tarFile, files = lab2cleanDataFile, exdir = tempdir())
lab2cleanEnv <- new.env()
load(file.path(tempdir(), lab2cleanDataFile), envir = lab2cleanEnv)
loincReferenceUnit <- tibble::as_tibble(lab2cleanEnv$loinc_reference_unit_v1)
ParallelLogger::logInfo("Read ", nrow(loincReferenceUnit), " LOINC codes from lab2clean ", lab2cleanVersion)

# The LOINC code of each standard Measurement concept.
sqlLoincConcepts <- "
SELECT concept_id, concept_code
FROM @vocabularyDatabaseSchema.concept
WHERE domain_id = '@domainId'
    AND standard_concept = '@standardConceptFlag'
    AND vocabulary_id = '@vocabularyId'
"
loincConcepts <- DatabaseConnector::renderTranslateQuerySql(
  connection = connection,
  sql = sqlLoincConcepts,
  vocabularyDatabaseSchema = vocabularyDatabaseSchema,
  domainId = domainId,
  standardConceptFlag = standardConceptFlag,
  vocabularyId = vocabularyId,
  snakeCaseToCamelCase = FALSE
) |>
  tibble::as_tibble() |>
  dplyr::rename_with(tolower)
ParallelLogger::logInfo("Read ", nrow(loincConcepts), " ", vocabularyId, " concepts from the vocabulary")

#
# --- Action -------------------------------------------------------------
#

# The unit lab2clean harmonises every concept to, in SI: a conventional code takes the SI unit
# of its partner (mass_molar_unit), the others keep their own reference_unit.
lab2cleanUnit <- loincReferenceUnit |>
  dplyr::transmute(
    concept_code = .data$loinc_code,
    harmonised_unit = dplyr::if_else(
      .data$unit_system == "conventional" & !is.na(.data$mass_molar_unit),
      .data$mass_molar_unit,
      .data$reference_unit
    ),
    unit_system = .data$unit_system
  ) |>
  dplyr::inner_join(loincConcepts, by = "concept_code") |>
  dplyr::filter(!is.na(.data$harmonised_unit)) |>
  dplyr::select("concept_id", "harmonised_unit", "unit_system") |>
  dplyr::arrange(as.numeric(.data$concept_id))
ParallelLogger::logInfo(
  nrow(lab2cleanUnit), " of ", nrow(loincReferenceUnit), " lab2clean codes are concepts of the vocabulary with a unit"
)

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(dplyr::select(lab2cleanUnit, "concept_id", "harmonised_unit"), pathToHarmonisedUnitTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(lab2cleanUnit), " rows to ", pathToHarmonisedUnitTSV)
