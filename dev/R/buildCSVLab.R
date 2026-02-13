buildCSVLab <- function(summary, pathToOutputFile, localMode = TRUE) {
    if (localMode == TRUE) {
        summary <- summary |>
            dplyr::rename(
                OMOP_CONCEPT_ID = local_OMOP_CONCEPT_ID,
                OMOP_CONCEPT_NAME = local_OMOP_CONCEPT_NAME,
                OMOP_QUANTITY = local_OMOP_QUANTITY,
                MEASUREMENT_UNIT = local_MEASUREMENT_UNIT,
                MEASUREMENT_UNIT_HARMONIZED = local_MEASUREMENT_UNIT_HARMONIZED,
                CONVERSION_FACTOR = local_CONVERSION_FACTOR,
                decile_MEASUREMENT_VALUE_HARMONIZED = local_decile_MEASUREMENT_VALUE_HARMONIZED
            )
    } else {
        summary <- summary |>
            dplyr::rename(
                OMOP_CONCEPT_ID = remote_OMOP_CONCEPT_ID,
                OMOP_CONCEPT_NAME = local_OMOP_CONCEPT_NAME,
                OMOP_QUANTITY = remote_OMOP_QUANTITY,
                MEASUREMENT_UNIT = remote_MEASUREMENT_UNIT,
                MEASUREMENT_UNIT_HARMONIZED = remote_MEASUREMENT_UNIT_HARMONIZED,
                CONVERSION_FACTOR = remote_CONVERSION_FACTOR,
                decile_MEASUREMENT_VALUE_HARMONIZED = remote_decile_MEASUREMENT_VALUE_HARMONIZED
            )
    }

    summary |>
        dplyr::mutate(
            testId = paste0(
                TEST_NAME,
                " [",
                dplyr::if_else(is.na(MEASUREMENT_UNIT), "", MEASUREMENT_UNIT),
                "]"
            ),
            p_values_missing_extracted_source = purrr::map_chr(
                distribution_values,
                .distributionToString,
                order = c("Missing", "Extracted", "Source")
            ),
            p_outcomes_NA_N_A_AA_L_LL_H_HH = purrr::map_chr(
                distribution_outcomes,
                .distributionToString,
                order = c("NA", "N", "A", "AA", "L", "LL", "H", "HH")
            ),
            decile_MEASUREMENT_VALUE = purrr::map2_chr(
                decile_MEASUREMENT_VALUE,
                MEASUREMENT_UNIT,
                .decilesToString
            ),
            ksTest_pValue = purrr::map_dbl(ksTest, .ksTestToPValue),
            ksTest_KS = purrr::map_dbl(ksTest, .ksTestToKS),
            decile_MEASUREMENT_VALUE_HARMONIZED = purrr::map2_chr(
                decile_MEASUREMENT_VALUE_HARMONIZED,
                MEASUREMENT_UNIT_HARMONIZED,
                .decilesToString
            ),
            ksTestHarmonized_pValue = purrr::map_dbl(
                ksTestHarmonized,
                .ksTestToPValue
            ),
            ksTestHarmonized_KS = purrr::map_dbl(ksTestHarmonized, .ksTestToKS),
        ) |>
        dplyr::select(
            status,
            OMOP_CONCEPT_ID,
            local_OMOP_CONCEPT_NAME,
            OMOP_QUANTITY,
            testId,
            n_subjects,
            n_records,
            #
            p_values_missing_extracted_source,
            p_outcomes_NA_N_A_AA_L_LL_H_HH,
            decile_MEASUREMENT_VALUE,
            ksTest_pValue,
            ksTest_KS,
            CONVERSION_FACTOR,
            decile_MEASUREMENT_VALUE_HARMONIZED,
            ksTestHarmonized_pValue,
            ksTestHarmonized_KS,
            message
        ) |>
        readr::write_tsv(pathToOutputFile, na = "")
}


.distributionToString <- function(distribution_outcomes, order) {
    distribution_outcomes <- distribution_outcomes |>
        dplyr::mutate(value = factor(value, levels = order)) |>
        dplyr::arrange(value)
    # Compute percent for all outcomes present in 'value' column
    total_n <- sum(distribution_outcomes |> dplyr::pull(n))
    percents <- distribution_outcomes |>
        dplyr::mutate(percent = n / total_n * 100) |>
        dplyr::pull(percent) |>
        round(digits = 1)
    names(percents) <- distribution_outcomes |> dplyr::pull(value)

    paste0("[ ", paste(percents, collapse = ", "), "]%")
}

.decilesToString <- function(deciles, unit) {
    if (is.null(deciles)) {
        return(NA)
    }
    deciles <- deciles |>
        dplyr::arrange(decile) |>
        dplyr::pull(value) |>
        round(digits = 2) |>
        paste0(collapse = ", ")
    paste0("[ ", deciles, " ", unit, " ]")
}

.ksTestToKS <- function(ksTest) {
    if (is.null(ksTest)) {
        return(NA)
    }
    ks <- ksTest |>
        dplyr::pull(KS) |>
        round(digits = 2)
    return(ks)
}

.ksTestToPValue <- function(ksTest) {
    if (is.null(ksTest)) {
        return(NA)
    }
    pValue <- ksTest |>
        dplyr::pull(pValue) |>
        round(digits = 2)
    return(pValue)
}
