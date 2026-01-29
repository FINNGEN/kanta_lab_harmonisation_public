#
# runAllBase.R
#
# This script is the main script that is called by runAllLocal.R or runAllGitHubAction.R.
#

if (!dir.exists(pathToValidatedVocabularyLabFolder)) {
    dir.create(pathToValidatedVocabularyLabFolder, showWarnings = FALSE, recursive = TRUE)
}

pathToLabFolder <- file.path(pathToVocabularyLabFolder,"LABfi_ALL")
pathToUnitsFolder <- file.path(pathToLabFolder, "UNITSfi")
sourceConceptIdOffset <- 2002400000

# create a temporary copy of the OMOP vocabulary duckdb file
message("Creating temporary copy of the OMOP vocabulary duckdb file")
pathToOMOPVocabularyDuckDBfile <- tempfile(fileext = ".duckdb")

connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "duckdb",
    server = pathToOMOPVocabularyDuckDBfile
)

vocabularyDatabaseSchema <- "main"

connection <- DatabaseConnector::connect(connectionDetails)

ROMOPMappingTools::omopVocabularyCSVsToDuckDB(
    pathToOMOPVocabularyCSVsFolder = pathToOMOPVocabularyCSVsFolder,
    connection = connection,
    vocabularyDatabaseSchema = vocabularyDatabaseSchema
)

DatabaseConnector::disconnect(connection)

#
# Run function
#
message("Validating usagi file")
connection <- DatabaseConnector::connect(
    dbms = "duckdb",
    server = pathToOMOPVocabularyDuckDBfile
)

validationLogTibble <- ROMOPMappingTools::validateUsagiFile(
    pathToUsagiFile,
    connection,
    vocabularyDatabaseSchema,
    pathToUsagiFile,
    sourceConceptIdOffset,
    pathToValidUnitsFile,
    pathToUnitConversionFile,
    pathToValidatedUnitConversionFile
)

DatabaseConnector::disconnect(connection)

#
# Create dashboard
#
if (createDashboard == TRUE & any(validationLogTibble$type != "ERROR")) {
    source("dev/R/labDataSummary.R")
    source("dev/R/buildStatusDasboard.R")

    message("Creating dashboard")
    dir.create(pathToDashboardFolder, showWarnings = FALSE, recursive = TRUE)

    message("Processing lab data summary")
    summary <- processLabDataSummary(pathToCodeCountsLabFolder, pathToValidatedUsagiFile)

    message("Building summary table")
    buildStatusDashboard(summary, pathToDashboardFolder)

    #message("Building CSV file")
    #buildCSVLab(summary, file.path(pathToDashboardFolder, "lab_data_summary.csv"))
}

message("Building validation status markdown file")
validationLogTibble <- validationLogTibble |>
    dplyr::mutate(context = "LABfi_ALL") |>
    dplyr::relocate(context, .before = 1)

ROMOPMappingTools::buildValidationStatusMd(
    validationLogTibble = validationLogTibble,
    pathToValidationStatusMdFile = file.path(pathToVocabularyLabFolder, "VOCABULARIES_VALIDATION_STATUS.md")
)

#
# pass final status to github action
#
FINAL_STATUS <- "SUCCESS"
if (any(validationLogTibble$type == "WARNING")) {
    FINAL_STATUS <- "WARNING"
}
if (any(validationLogTibble$type == "ERROR")) {
    FINAL_STATUS <- "ERROR"
}

message("FINAL_STATUS: ", FINAL_STATUS)

writeLines(FINAL_STATUS, "/tmp/FINAL_STATUS.txt")




