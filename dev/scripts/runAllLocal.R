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
createDashboard <- TRUE
pathToOMOPVocabularyCSVsFolder <- "../../FinOMOP/OMOP_vocabularies/data/input_omop_vocabulary" # SET TO LOCAL PATH
pathToOMOPVocabularyCSVsFolderOutput <- tempdir()
pathToVocabularyLabFolder <- "VOCABULARIES"
pathToValidatedVocabularyLabFolder <- "VOCABULARIES"
pathToCodeCountsLabFolder <- "CODE_COUNTS/databases/LABfi_FinnGenDF13"
pathToDashboardFolder <- "output_data/public"

#
# Run function
#
source("dev/SCRIPTS/runAllBase.R")

#
# Open the dashboard in the browser
#
browseURL(file.path(pathToDashboardFolder, "index.html"))



source("dev/R/buildStatusDashboardLab.R")
.summaryToSummaryTable(summary, pathToDashboardFolder, devMode = TRUE)
browseURL(file.path(pathToDashboardFolder, "index.html"))

