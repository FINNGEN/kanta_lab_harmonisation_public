#
# Install the packages
#

renv::install("FinOMOP/ROMOPMappingTools@68-add-tools-for-lab-data", prompt = FALSE)

#
# Build the OMOP vocabulary duckdb file
#
pathToFullOMOPVocabularyCSVsFolder <- "../../FinOMOP/OMOP_vocabularies/data/input_omop_vocabulary"

# convert to duckdb
pathToFullOMOPVocabularyDuckDBfile <- tempfile()

connectionDetails <- DatabaseConnector::createConnectionDetails(
    dbms = "duckdb",
    server = pathToFullOMOPVocabularyDuckDBfile
)

connection <- DatabaseConnector::connect(connectionDetails)

ROMOPMappingTools::omopVocabularyCSVsToDuckDB(
    pathToOMOPVocabularyCSVsFolder = pathToFullOMOPVocabularyCSVsFolder,
    connection = connection,
    vocabularyDatabaseSchema = "main"
)

DatabaseConnector::disconnect(connection)

pathToOMOPVocabularyDuckDBfile <- pathToFullOMOPVocabularyDuckDBfile


#
# Validate the LAB fi usagi file
#
pathToUsagiFile <- "MAPPING_TABLES/LABfi_ALL.usagi.csv"
pathToUnitConversionFile <- "MAPPING_TABLES/quantity_source_unit_conversion.tsv"
pathToValidUnitsFile <- "MAPPING_TABLES/UNITSfi.usagi.csv"

pathToValidatedUsagiFile <- tempfile(fileext = ".csv")
pathToValidatedUnitConversionFile <- tempfile(fileext = ".tsv")
vocabularyDatabaseSchema <- "main"
sourceConceptIdOffset <- 2002400000


