#
# runAllLocal.R
#
# This script set the variable to run the validation of the vocabularies locally.
# 1. install dependencies
# 2. set the environment variables
# 3. call runAllBase.R
#

#
# install dependencies
#
if (library("remotes", logical.return = TRUE, quietly = TRUE) == FALSE) {
    install.packages("remotes")
}
if (library("ROMOPMappingTools", logical.return = TRUE, quietly = TRUE) == FALSE) {
    remotes::install_github("FinOMOP/ROMOPMappingTools@68-add-tools-for-lab-data", prompt = FALSE)
}


#
# Setting environment
#
devMode <- FALSE
createDashboard <- TRUE
pathToOMOPVocabularyCSVsFolder <- "../../FinOMOP/OMOP_vocabularies/data/input_omop_vocabulary" # SET TO LOCAL PATH
pathToOMOPVocabularyCSVsFolderOutput <- tempdir()
pathToVocabularyLabFolder <- "VOCABULARIES"
pathToValidatedVocabularyLabFolder <- "VOCABULARIES"
pathToCodeCountsLabFolder <- "CODE_COUNTS/databases/LABfi_FinnGenDF13"
pathToDashboardFolder <- here::here("output_data/public")

#
# Run function
#
source("dev/SCRIPTS/runAllBase.R")

#
# Open the dashboard in the browser
#
browseURL(file.path(pathToDashboardFolder, "index.html"))


devMode <- TRUE
pathToHtmlFile <- buildStatusDashboard(summary, pathToDashboardFolder, devMode)
browseURL(pathToHtmlFile)







# source("dev/R/buildSummaryTable.R")
# devMode <- F
# summaryTable <- .summaryTable(summary , devMode)
# pathHtmlFile <- file.path(pathToDashboardFolder, "summary_table.html")
# htmltools::save_html(summaryTable, pathHtmlFile)
# browseURL(pathHtmlFile)



# source("dev/R/buildSummaryTable.R")
# summaryTable <- .summaryTable(summary  |> filter(local_OMOP_CONCEPT_ID == 3000963) , devMode)
# pathHtmlFile <- file.path(pathToDashboardFolder, "summary_table.html")
# htmltools::save_html(summaryTable, pathHtmlFile)
# browseURL(pathHtmlFile)


# a <- readr::read_csv(pathToUsagiFile, col_types = readr::cols(.default = readr::col_character()), na = "")
# a |> dplyr::mutate(
#     conceptId = dplyr::if_else(mappingStatus == "APPROVED" & conceptId==3019069 & stringr::str_detect(sourceCode, "basofii"), '3022096', conceptId)
# ) |> readr::write_csv(pathToUsagiFile, na = "")
