#
# runAllBase.R
#
# This script is the main script that is called by runAllLocal.R or runAllGitHubAction.R.
#

if (!dir.exists(pathToValidatedVocabularyLabFolder)) {
    dir.create(pathToValidatedVocabularyLabFolder, showWarnings = FALSE, recursive = TRUE)
}

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

sourceConceptIdOffset <- 2002400000
pathToUsagiFile <- file.path(pathToVocabularyLabFolder, "LABfi_ALL", "LABfi_ALL.usagi.csv")
pathToUnitConversionFile <- file.path(pathToVocabularyLabFolder, "LABfi_ALL", "quantity_source_unit_conversion.tsv")
pathToUnitFixFile <- file.path(pathToVocabularyLabFolder, "LABfi_ALL", "fix_unit_based_in_abbreviation.tsv")
pathToValidUnitsFile <- file.path(pathToVocabularyLabFolder, "UNITSfi", "UNITSfi.usagi.csv")

ROMOPMappingTools::updateUsagiFile(
    pathToUsagiFile,
    connection,
    vocabularyDatabaseSchema,
    pathToUpdatedUsagiFile = pathToUsagiFile,
    appendOrClearAutoUpdatingInfo = "append",
    skipValidation = TRUE
)

validationLogTibble <- ROMOPMappingTools::validateUsagiFile(
    pathToUsagiFile,
    connection,
    vocabularyDatabaseSchema,
    pathToValidatedUsagiFile = pathToUsagiFile,
    sourceConceptIdOffset,
    pathToValidUnitsFile = pathToValidUnitsFile,
    pathToUnitConversionFile = pathToUnitConversionFile,
    pathToValidatedUnitConversionFile = pathToUnitConversionFile
)

# usagiFile <- ROMOPMappingTools::readUsagiFile(pathToUsagiFile) |> 
#     dplyr::transmute(
#         test_name = `ADD_INFO:testNameAbbreviation`,
#         measurement_unit = `ADD_INFO:measurementUnit`
#     ) |> dplyr::distinct()

DatabaseConnector::disconnect(connection)

#
# Create dashboard
#
if (createDashboard == TRUE & any(validationLogTibble$type != "ERROR")) {
    source("dev/R/labDataSummary.R")
    source("dev/R/buildStatusDasboard.R")
    source("dev/R/buildSummaryTable.R")

    message("Creating dashboard")
    dir.create(pathToDashboardFolder, showWarnings = FALSE, recursive = TRUE)

    message("Processing lab data summary")
    summary <- processLabDataSummary(
        pathToCodeCountsLabFolder,
        pathToUsagiFile,
        pathToUnitConversionFile
    )

    message("Building summary table")
    # buildStatusDashboard(summary, pathToDashboardFolder, devMode = devMode)
    summaryTable <- .summaryTable(summary , devMode)
    pathHtmlFile <- file.path(pathToDashboardFolder, "index.html")
    htmltools::save_html(summaryTable, pathHtmlFile)

    # message("Building CSV file")
    # buildCSVLab(summary, file.path(pathToDashboardFolder, "lab_data_summary.csv"))
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
