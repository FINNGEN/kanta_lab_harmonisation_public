source("dev/R/labDataSummary.R")
source("dev/R/buildSummaryOfSummaryTable.R")



buildStatusDashboard <- function(summary, pathToDashboardFolder, devMode = FALSE) {
    summary |> checkmate::assert_tibble()
    pathToDashboardFolder |> checkmate::assertDirectoryExists()

    pathToHtmlFile <- file.path(pathToDashboardFolder, "index.html")

    #
    # Function
    #
    rmarkdown::render(file.path("dev", "R", "dashboard.Rmd"),
        params = list(
            summary = summary,
            devMode = devMode
        ),
        output_file = pathToHtmlFile
    )

    return(pathToHtmlFile)
}
