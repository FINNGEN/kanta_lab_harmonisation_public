
#' Build Status Dashboard
#'
#' This function generates a status dashboard for mapping status.
#'
#' @param usagi_mapping_tables A tibble containing USAGI mapping tables.
#' @param vocabulary_info_mapping_tables A tibble containing vocabulary info mapping tables.
#' @param results_DQD A list of results from the DQD (Data Quality Dashboard).
#' @param databases_code_counts_tables A tibble containing databases code counts tables.
#' @param mapping_status Mapping status information.
#' @param output_file_html The path to the output HTML file.
#'
#' @return The path to the output HTML file.
#'
#' @importFrom checkmate assertTibble assertList
#' @importFrom dplyr select mutate filter if_else
#' @importFrom rmarkdown render
#' @importFrom reactable reactable
#' @importFrom shiny div
#'
#' @export
buildStatusDashboard <- function(
    summary_data_5,
    output_file_html = file.path(tempdir(), "MappingStatusDashboard.html"),
    gh_pages = FALSE) {

  if (gh_pages) {
    # if dir exist remove all contents if not create it
    if (dir.exists(here::here("docs"))) {
      fs::dir_delete(here::here("docs"), recursive = TRUE)
    } else {
      dir.create(here::here("docs"))
    }
    output_file_html <- here::here("docs", "index.html")
  }


  #
  # validate inputs
  #


  #
  # Function
  #
  rmarkdown::render(here::here("inst", "rmd", "MappingStatusDashboard.Rmd"),
                    params = list(
                      summary_data_5 = summary_data_5
                    ),
                    output_file = output_file_html)

  return(output_file_html)
}


