.summaryOfSummaryTable <- function(summary, pathToSummaryOfSummaryTableFile) {
    summary |> checkmate::assert_tibble()

    toplot <- summary |>
        dplyr::group_by(status) |>
        dplyr::summarise(
            n_tests = dplyr::n(),
            n_subjects = sum(n_subjects),
            n_records = sum(n_records),
            .groups = "drop"
        ) |>
        dplyr::mutate(
            p_subjects = n_subjects / sum(n_subjects),
            p_records = n_records / sum(n_records)
        )

    toplot |> reactable::reactable(
        columns = list(
            status = reactable::colDef(
                name = "Status",
                minWidth = 100,
                cell = function(value) {
                    .renderStatus(value)
                }
            ),
            n_tests = reactable::colDef(
                name = "Number of test+unit combinations",
                minWidth = 100
            ),
            n_subjects = reactable::colDef(
                name = "Number of subjects",
                minWidth = 100
            ),
            n_records = reactable::colDef(
                name = "Number of records",
                minWidth = 100
            ),
            p_subjects = reactable::colDef(
                name = "Percentage of subjects",
                minWidth = 100,
                format = reactable::colFormat(digits = 2, percent = TRUE)
            ),
            p_records = reactable::colDef(
                name = "Percentage of records",
                minWidth = 100,
                format = reactable::colFormat(digits = 2, percent = TRUE)
            )
        )
    )
}
