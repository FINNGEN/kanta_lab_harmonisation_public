summaryOfMappingStatus <- function(summary, pathToSummaryOfSummaryTableFile) {
    summary |> checkmate::assert_tibble()

    toplot <- summary |>
        dplyr::group_by(status) |>
        dplyr::summarise(
            n_warnings = sum(stringr::str_detect(message, "WARNING"), na.rm = TRUE),
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
            n_warnings = reactable::colDef(
                name = "Number of warnings",
                minWidth = 100
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


.summaryOfValueSource <- function(summary) {

    summary |>
    dplyr::select(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT, n_subjects, n_records, distribution_values) |>
    tidyr::unnest(distribution_values) |>
    tidyr::pivot_wider(
        names_from = value,
        values_from = n
    ) |>
    dplyr::rename(
        n_values_extracted = Extracted,
        n_values_missing = Missing,
        n_values = Source
    ) |>
    dplyr::group_by(OMOP_CONCEPT_ID) |>
    dplyr::summarise(
        n_tests = dplyr::n(),
        n_subjects = sum(n_subjects),
        n_records = sum(n_records),
        n_values_missing = sum(n_values_missing, na.rm = TRUE),
        n_values = sum(n_values, na.rm = TRUE),
        n_values_extracted = sum(n_values_extracted, na.rm = TRUE),
        .groups = "drop"
    )
}