summaryOfMappingStatus <- function(summary, pathToSummaryOfSummaryTableFile) {
    summary |> checkmate::assert_tibble()

    toplot <- summary |>
        dplyr::group_by(status) |>
        dplyr::summarise(
            n_warnings = sum(
                stringr::str_detect(message, "WARNING"),
                na.rm = TRUE
            ),
            n_tests = dplyr::n(),
            n_subjects = sum(n_subjects),
            n_records = sum(n_records),
            .groups = "drop"
        ) |>
        dplyr::mutate(
            p_subjects = n_subjects / sum(n_subjects),
            p_records = n_records / sum(n_records)
        )

    toplot |>
        reactable::reactable(
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
        dplyr::select(
            OMOP_CONCEPT_ID,
            TEST_NAME,
            MEASUREMENT_UNIT,
            n_subjects,
            n_records,
            distribution_values
        ) |>
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


summaryOfValues <- function(summary) {
    toprint <- summary |>
        tidyr::unnest(distribution_values) |>
        tidyr::pivot_wider(
            names_from = value,
            values_from = n,
            values_fill = list(n = 0)
        ) |>
        dplyr::mutate(
            n_values = n_records - Missing - QCOut,
            n_values_harmonised = dplyr::if_else(
                purrr::map_lgl(ksTestHarmonized, is.null),
                0,
                n_values
            ),
        ) |>
        dplyr::group_by(local_OMOP_CONCEPT_ID) |>
        dplyr::summarise(
            n_tests = dplyr::n(),
            n_subjects = sum(n_subjects),
            n_records = sum(n_records),
            n_values_missing = sum(Missing, na.rm = TRUE),
            n_values_qcout = sum(QCOut, na.rm = TRUE),
            n_values_harmonised = sum(n_values_harmonised, na.rm = TRUE),
            .groups = "drop"
        ) |> 
        dplyr::filter(local_OMOP_CONCEPT_ID != 0) |> 
        dplyr::summarise(
            n_records = sum(n_records),
            n_values_missing = sum(n_values_missing, na.rm = TRUE),
            n_values_qcout = sum(n_values_qcout, na.rm = TRUE),
            n_values_harmonised = sum(n_values_harmonised, na.rm = TRUE)
        ) |>
        dplyr::mutate(
            n_values_not_harmonised = n_records - n_values_missing - n_values_qcout - n_values_harmonised
        ) |>
        tidyr::pivot_longer(
            cols = c(n_values_missing, n_values_qcout, n_values_harmonised, n_values_not_harmonised),
            names_to = "value_status",
            values_to = "n_events"
        ) |>
        dplyr::mutate(
            value_status = dplyr::case_when(
                value_status == "n_values_missing" ~ "Missing",
                value_status == "n_values_qcout" ~ "QCOut",
                value_status == "n_values_harmonised" ~ "Harmonised",
                value_status == "n_values_not_harmonised" ~ "Not Harmonised"
            ),
            p_events = n_events / n_records,
            order = dplyr::case_when(
                value_status == "Harmonised" ~ 1,
                value_status == "Not Harmonised" ~ 2,
                value_status == "Missing" ~ 3,
                value_status == "QCOut" ~ 4
            )
        ) |>
        dplyr::arrange(order) |>
        dplyr::select(value_status, n_events, p_events)

    toprint |>
        reactable::reactable(
            columns = list(
                value_status = reactable::colDef(
                    name = "Value Status",
                    minWidth = 150,
                    style = function(value) {
                        color <- dplyr::case_when(
                            value == "Harmonised" ~ "#28a745",
                            value == "Not Harmonised" ~ "#ffc107",
                            value == "Missing" ~ "#6c757d",
                            value == "QCOut" ~ "#dc3545",
                            TRUE ~ "#000000"
                        )
                        list(color = color, fontWeight = "bold")
                    }
                ),
                n_events = reactable::colDef(
                    name = "Number of Events",
                    minWidth = 150,
                    format = reactable::colFormat(separators = TRUE)
                ),
                p_events = reactable::colDef(
                    name = "Percentage of Events",
                    minWidth = 150,
                    format = reactable::colFormat(digits = 2, percent = TRUE)
                )
            )
        )
}
