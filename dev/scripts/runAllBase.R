#
# runAllBase.R
#
# This script is the main script that is called by runAllLocal.R or runAllGitHubAction.R.
#

if (!dir.exists(pathToValidatedVocabularyLabFolder)) {
    dir.create(pathToValidatedVocabularyLabFolder, showWarnings = FALSE, recursive = TRUE)
}

pathToUsagiFile <- file.path(pathToVocabularyLabFolder,"LABfi_ALL", "LABfi_ALL.usagi.csv")
pathToUnitConversionFile <- file.path(pathToVocabularyLabFolder, "LABfi_ALL", "quantity_source_unit_conversion.tsv")
pathToValidUnitsFile <- file.path(pathToVocabularyLabFolder, "UNITSfi", "UNITSfi.usagi.csv")

pathToValidatedUsagiFile <- file.path(pathToValidatedVocabularyLabFolder, "LABfi_ALL", "LABfi_ALL.usagi.csv")
pathToValidatedUnitConversionFile <- file.path(pathToValidatedVocabularyLabFolder, "LABfi_ALL", "quantity_source_unit_conversion.tsv")

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
    source("dev/R/buildStatusDashboardLab.R")
    source("dev/R/buildCSVLab.R")

    message("Creating dashboard")
    dir.create(pathToDashboardFolder, showWarnings = FALSE, recursive = TRUE)

    message("Reading code counts lab folder")
    summary <- .readCodeCountsLabFolder(pathToCodeCountsLabFolder)
    
    message("Calculating KStest")
    summary <- .calcualteKStest(summary)

    message("Appending concept names")
    connection <- DatabaseConnector::connect(
        dbms = "duckdb",
        server = pathToOMOPVocabularyDuckDBfile
    )
    concept <- dplyr::tbl(connection, "CONCEPT") |>
        dplyr::filter(concept_id %in% summary$OMOP_CONCEPT_ID) |>
        dplyr::select(concept_id, concept_name) |>
        dplyr::collect()
    summary <- summary |>
        dplyr::left_join(concept, by = c("OMOP_CONCEPT_ID" = "concept_id"))
    DatabaseConnector::disconnect(connection)

    message("Append usagi file messages")
    usagiFile <- ROMOPMappingTools::readUsagiFile(pathToValidatedUsagiFile)
    approvedUsagiFile <- usagiFile |>
        dplyr::filter(mappingStatus == "APPROVED") |>
        dplyr::select(
            OMOP_CONCEPT_ID = conceptId,
            TEST_NAME = `ADD_INFO:testNameAbbreviation`,
            MEASUREMENT_UNIT = `ADD_INFO:measurementUnit`,
            message = `ADD_INFO:validationMessages`, 
            mappingStatus = mappingStatus
        )

    # set status
    summary <- summary |>
        dplyr::mutate(
            status = dplyr::case_when(
                mappingStatus == "APPROVED" ~ "APPROVED",
                mappingStatus == "REJECTED" ~ "REJECTED",
                TRUE ~ "PENDING"
            )
        )
    
    message("Building summary table")
    .summaryToSummaryTable(summary, pathToDashboardFolder, devMode = TRUE)

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
