#
# runAllGitHubAction.R
#
# This script set the variable to run the validation of the vocabularies in the GitHub Action.
# 1. set the environment variables
# 2. call runAllBase.R
#

#
# validate arguments
#
if (Sys.getenv("BUILD_DASHBOARD") == "TRUE" | Sys.getenv("BUILD_DASHBOARD") == "true") {
    createDashboard <- TRUE
} else if (Sys.getenv("BUILD_DASHBOARD") == "FALSE" | Sys.getenv("BUILD_DASHBOARD") == "false") {
    createDashboard <- FALSE
} else {
    stop("BUILD_DASHBOARD is not set to TRUE or FALSE")
}

githubWorkspace <- Sys.getenv("GITHUB_WORKSPACE")
if (is.null(githubWorkspace)) {
    stop("GITHUB_WORKSPACE is not set")
}

devMode <- TRUE

#
# Setting environment
#
pathToOMOPVocabularyCSVsFolder <- file.path(githubWorkspace, "input_data/input_omop_vocabulary")
pathToOMOPVocabularyCSVsFolderOutput <- file.path(githubWorkspace, "output_data")
pathToVocabularyLabFolder <- file.path(githubWorkspace, "VOCABULARIES")
pathToValidatedVocabularyLabFolder <- file.path(githubWorkspace, "VOCABULARIES")
pathToCodeCountsLabFolder <- file.path(githubWorkspace, "CODE_COUNTS/databases/LABfi_FinnGenDF13")
pathToDashboardFolder <- file.path(githubWorkspace, "output_data/public")

#
# Run function
#
source("dev/scripts/runAllBase.R")