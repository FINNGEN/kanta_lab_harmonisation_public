#' Read code counts lab folder
#'
#' Reads the three TSV files from a lab code counts folder and returns them as tibbles
#' with the correct column types.
#'
#' @param pathToCodeCountsLabFolder Path to folder containing lab code counts files
#'
#' @return A list containing three tibbles: summaryTest, summaryValues, and summaryOutcomes
#'
#' @importFrom checkmate assert_directory assert_file_exists
#' @importFrom readr read_tsv cols
#' @importFrom dplyr group_by summarise left_join mutate if_else distinct pull select filter ungroup bind_rows arrange case_when
#' @importFrom tibble tibble
#' @importFrom tidyr crossing
#' @importFrom purrr map2
.readCodeCountsLabFolder <- function(pathToCodeCountsLabFolder) {
    pathToCodeCountsLabFolder |> checkmate::assert_directory()
    pathToCodeCountsLabFolder |>
        file.path("summaryTest.tsv") |>
        checkmate::assert_file_exists()
    pathToCodeCountsLabFolder |>
        file.path("summaryValuesSource.tsv") |>
        checkmate::assert_file_exists()
    pathToCodeCountsLabFolder |>
        file.path("summaryValues.tsv") |>
        checkmate::assert_file_exists()
    pathToCodeCountsLabFolder |>
        file.path("summaryOutcomes.tsv") |>
        checkmate::assert_file_exists()

    # Read summaryTest.tsv
    summaryTest <- readr::read_tsv(
        file = pathToCodeCountsLabFolder |> file.path("summaryTest.tsv"),
        col_types = readr::cols(
            OMOP_CONCEPT_ID = "i",
            TEST_NAME = "c",
            MEASUREMENT_UNIT_PREFIX = "c",
            MEASUREMENT_UNIT = "c",
            MEASUREMENT_UNIT_HARMONIZED = "c",
            omopQuantity = "c",
            CONVERSION_FACTOR = "c",
            n_records = "i",
            n_subjects = "i"
        ),
        show_col_types = FALSE,
        na = ""
    )

    # Read summaryValuesSource.tsv
    summaryValuesSource <- readr::read_tsv(
        file = pathToCodeCountsLabFolder |> file.path("summaryValuesSource.tsv"),
        col_types = readr::cols(
            OMOP_CONCEPT_ID = "i",
            TEST_NAME = "c",
            MEASUREMENT_UNIT_PREFIX = "c",
            MEASUREMENT_UNIT = "c",
            value_source = "c",
            n_subjects = "i",
            n_records = "i"
        ),
        show_col_types = FALSE,
        na = ""
    )

    # Read summaryValues.tsv
    summaryValues <- readr::read_tsv(
        file = pathToCodeCountsLabFolder |> file.path("summaryValues.tsv"),
        col_types = readr::cols(
            OMOP_CONCEPT_ID = "i",
            TEST_NAME = "c",
            MEASUREMENT_UNIT_PREFIX = "c",
            MEASUREMENT_UNIT = "c",
            n_subjects = "i",
            n_records = "i",
            decile = "d",
            decile_MEASUREMENT_VALUE = "d",
            decile_MEASUREMENT_VALUE_HARMONIZED = "d"
        ),
        show_col_types = FALSE,
        na = ""
    )

    # Read summaryOutcomes.tsv
    summaryOutcomes <- readr::read_tsv(
        file = pathToCodeCountsLabFolder |> file.path("summaryOutcomes.tsv"),
        col_types = readr::cols(
            OMOP_CONCEPT_ID = "i",
            TEST_NAME = "c",
            MEASUREMENT_UNIT_PREFIX = "c",
            MEASUREMENT_UNIT = "c",
            TEST_OUTCOME = "c",
            n_TEST_OUTCOME = "i",
            n_subjects = "i"
        ),
        show_col_types = FALSE,
        na = ""
    )

    #
    # summaryValuesSource
    # - calculate distribution of values
    totalRecords <- summaryTest |>
        dplyr::distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, n_records)
    totalValues <- summaryValuesSource |>
        dplyr::group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        dplyr::summarise(n_values = sum(n_records), .groups = "drop")
    missingValues <- totalRecords |>
        dplyr::left_join(totalValues, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT")) |>
        dplyr::transmute(
            OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT,
            n_records = dplyr::coalesce(n_records, 0L) - dplyr::coalesce(n_values, 0L)
        ) 


    summaryValuesSourceToJoin <- dplyr::bind_rows(
        summaryValuesSource |>
            dplyr::select(-n_subjects),
        missingValues |>
            dplyr::mutate(value_source = "Missing")
    )

    summaryValuesSourceToJoin <- summaryValuesSourceToJoin |>
        dplyr::distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        tidyr::crossing(value_source = summaryValuesSourceToJoin |> dplyr::pull(value_source) |> unique()) |>
        dplyr::left_join(summaryValuesSourceToJoin, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT", "value_source")) |>
        dplyr::mutate(n_records = dplyr::if_else(is.na(n_records), 0L, n_records)) |>
        dplyr::rename(value = value_source, n = n_records) |>
        tidyr::nest(distribution_values = c(value, n))


    # summaryValues
    # - calculate distribution of deciles
    summaryValuesA <- summaryValues |>
        dplyr::filter(!is.na(decile_MEASUREMENT_VALUE)) |>
        dplyr::group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        dplyr::summarise(
            decile_MEASUREMENT_VALUE = list(tibble::tibble(
                decile = decile,
                value = decile_MEASUREMENT_VALUE
            )),
            .groups = "drop"
        )
    summaryValuesB <- summaryValues |>
        dplyr::filter(!is.na(decile_MEASUREMENT_VALUE_HARMONIZED)) |>
        dplyr::group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        dplyr::summarise(
            decile_MEASUREMENT_VALUE_HARMONIZED = list(tibble::tibble(
                decile = decile,
                value = decile_MEASUREMENT_VALUE_HARMONIZED
            )),
            .groups = "drop"
        )
    summaryValuesToJoin <- dplyr::left_join(summaryValuesA, summaryValuesB, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT"))


    #
    # summaryOutcomes
    # - calculate distribution of outcomes
    totalRecords <- summaryTest |>
        dplyr::distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, n_records)
    totalOutcomes <- summaryOutcomes |>
        dplyr::group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        dplyr::summarise(n_outcomes = sum(n_TEST_OUTCOME), .groups = "drop")
    missingOutcomes <- totalRecords |>
        dplyr::left_join(totalOutcomes, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT")) |>
        dplyr::mutate(
            n_records = dplyr::if_else(is.na(n_records), 0L, n_records),
            n_outcomes = dplyr::if_else(is.na(n_outcomes), 0L, n_outcomes),
            n_missing = n_records - n_outcomes
        ) |>
        dplyr::select(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, n_TEST_OUTCOME = n_missing)

    summaryOutcomesToJoin <- dplyr::bind_rows(
        summaryOutcomes |>
            dplyr::select(-n_subjects),
        missingOutcomes |>
            dplyr::mutate(TEST_OUTCOME = "NA")
    )
    summaryOutcomesToJoin <- summaryOutcomesToJoin |>
        dplyr::distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |>
        tidyr::crossing(TEST_OUTCOME = summaryOutcomesToJoin |> dplyr::pull(TEST_OUTCOME) |> unique()) |>
        dplyr::left_join(summaryOutcomesToJoin, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT", "TEST_OUTCOME")) |>
        dplyr::mutate(n_TEST_OUTCOME = dplyr::if_else(is.na(n_TEST_OUTCOME), 0L, n_TEST_OUTCOME)) |>
        dplyr::rename(value = TEST_OUTCOME, n = n_TEST_OUTCOME) |>
        tidyr::nest(distribution_outcomes = c(value, n))


    summary <- summaryTest |>
        dplyr::left_join(summaryValuesSourceToJoin, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT")) |>
        dplyr::left_join(summaryValuesToJoin, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT")) |>
        dplyr::left_join(summaryOutcomesToJoin, by = c("OMOP_CONCEPT_ID", "TEST_NAME", "MEASUREMENT_UNIT_PREFIX", "MEASUREMENT_UNIT"))


    # checks
    summary |>
        nrow() |>
        testthat::expect_equal(summary |> dplyr::distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT) |> nrow())
    summary |> 
    dplyr::mutate(
        n_values = purrr::map_dbl(distribution_values, ~ sum(.x$n))
    ) |> 
    dplyr::filter(n_values != n_records)  |> nrow() |> testthat::expect_equal(0)

    summary <- summary |>
        dplyr::rename(
            remote_OMOP_CONCEPT_ID = OMOP_CONCEPT_ID,
            TEST_NAME = TEST_NAME,
            MEASUREMENT_UNIT_PREFIX = MEASUREMENT_UNIT_PREFIX,
            MEASUREMENT_UNIT = MEASUREMENT_UNIT,
            remote_MEASUREMENT_UNIT_HARMONIZED = MEASUREMENT_UNIT_HARMONIZED,
            remote_OMOP_QUANTITY = omopQuantity,
            remote_CONVERSION_FACTOR = CONVERSION_FACTOR, 
            remote_decile_MEASUREMENT_VALUE_HARMONIZED = decile_MEASUREMENT_VALUE_HARMONIZED
        ) |>
        dplyr::mutate(
            remote_REFERENCE_TEST_NAME = ""
        )
    return(summary)
}


processLabDataSummary <- function(pathToCodeCountsLabFolder, pathToUnitFixFile) {
    pathToLabFolder |> checkmate::assertDirectoryExists()
    pathToUnitFixFile |> checkmate::assertFileExists()

    pathToUsagiFile <- pathToLabFolder |> file.path("LABfi_ALL.usagi.csv")
    pathToUnitConversionFile <- pathToLabFolder |> file.path("quantity_source_unit_conversion.tsv")
    pathToUnitFixFile <- pathToLabFolder |> file.path("fix_unit_based_in_abbreviation.tsv")

    pathToUsagiFile |> checkmate::assertFileExists()
    pathToUnitConversionFile |> checkmate::assertFileExists()
    pathToUnitFixFile |> checkmate::assertFileExists()

    # Reading code counts lab folder
    summary <- .readCodeCountsLabFolder(pathToCodeCountsLabFolder)

    inNrows <- summary |> nrow()

    # Append unit fix info
    # unitFixTibble <- readr::read_tsv(pathToUnitFixFile, col_types = readr::cols(
    #     TEST_NAME_ABBREVIATION = "c",
    #     source_unit_clean = "c",
    #     source_unit_clean_fix = "c"
    # )) |> dplyr::rename(
    #     TEST_NAME = TEST_NAME_ABBREVIATION,
    #     MEASUREMENT_UNIT_PREFIX = source_unit_clean,
    #     local_MEASUREMENT_UNIT = source_unit_clean_fix
    # )
    #
    # summary <- summary |>
    #     dplyr::left_join(unitFixTibble, by = c("TEST_NAME", "MEASUREMENT_UNIT_PREFIX")) |>
    #     dplyr::mutate(
    #         local_MEASUREMENT_UNIT = dplyr::if_else(is.na(local_MEASUREMENT_UNIT), MEASUREMENT_UNIT_PREFIX, local_MEASUREMENT_UNIT)
    #     )

    # Append usagi info
    usagiTibble <- ROMOPMappingTools::readUsagiFile(pathToUsagiFile) |>
        dplyr::select(
            TEST_NAME = `ADD_INFO:testNameAbbreviation`,
            MEASUREMENT_UNIT = `ADD_INFO:measurementUnit`,
            local_OMOP_CONCEPT_ID = conceptId,
            local_OMOP_CONCEPT_NAME = conceptName,
            local_OMOP_QUANTITY = `ADD_INFO:omopQuantity`,
            message = `ADD_INFO:validationMessages`,
            mappingStatus = mappingStatus,
            ignoreReason = `ADD_INFO:ignoreReason`
        ) |>
        dplyr::distinct(TEST_NAME, MEASUREMENT_UNIT, .keep_all = TRUE)

    summary <- summary |>
        dplyr::left_join(usagiTibble, by = c("TEST_NAME", "MEASUREMENT_UNIT")) |>
        dplyr::mutate(
            status = dplyr::case_when(
                mappingStatus == "APPROVED" ~ "APPROVED",
                !is.na(ignoreReason) ~ "IGNORED",
                !is.na(mappingStatus) ~ mappingStatus,
                TRUE ~ "NOT-FOUND"
            ),
            message = dplyr::if_else(is.na(ignoreReason), message, paste0("IGNORED: ", ignoreReason, "; ", message))
        ) |>
        dplyr::select(-ignoreReason, -mappingStatus)

    # Calculate the local_MEASUREMENT_UNIT_HARMONIZED 
    mostCommonUnitPerConceptId <- summary |>
        dplyr::filter(status == "APPROVED") |>
        dplyr::filter(!is.na(MEASUREMENT_UNIT)) |>
        dplyr::group_by(local_OMOP_CONCEPT_ID, MEASUREMENT_UNIT) |>
        dplyr::summarise(n_records = sum(n_records), .groups = "drop") |>
        dplyr::arrange(dplyr::desc(n_records)) |>
        dplyr::distinct(local_OMOP_CONCEPT_ID, .keep_all = TRUE) |>
        dplyr::transmute(
            local_OMOP_CONCEPT_ID = local_OMOP_CONCEPT_ID,
            local_MEASUREMENT_UNIT_HARMONIZED = MEASUREMENT_UNIT
        )

    summary <- summary |>
        dplyr::left_join(mostCommonUnitPerConceptId, by = c("local_OMOP_CONCEPT_ID"))
    
    # calculate local_REFERENCE_TEST_NAME and local_REFERENCE_UNIT_PREFIX
    referenceDistribution <- summary |>
        dplyr::filter(status == "APPROVED") |>
        dplyr::filter(!is.na(MEASUREMENT_UNIT)) |>
        dplyr::arrange(dplyr::desc(n_records)) |>
        dplyr::distinct(local_OMOP_CONCEPT_ID, .keep_all = TRUE) |>
        dplyr::transmute(
            local_OMOP_CONCEPT_ID = local_OMOP_CONCEPT_ID,
            local_REFERENCE_TEST_NAME = TEST_NAME,
            local_REFERENCE_UNIT_PREFIX = MEASUREMENT_UNIT_PREFIX
        )

    summary <- summary |>
        dplyr::left_join(referenceDistribution, by = c("local_OMOP_CONCEPT_ID"))

    # Calculate conversion factor and harmonize unit
    quantityConversionTibble <- ROMOPMappingTools::readUnitConversionFile(pathToUnitConversionFile) |> 
    # tmp
    dplyr::filter(!is.na(source_unit_valid) & !is.na(to_source_unit_valid)) |>
    # end tmp
        dplyr::rename(
            local_OMOP_QUANTITY = omop_quantity,
            MEASUREMENT_UNIT = source_unit_valid,
            local_MEASUREMENT_UNIT_HARMONIZED = to_source_unit_valid,
            local_CONVERSION_FACTOR = conversion
        ) |>
        dplyr::select(-validation_messages)

    summary <- summary |>
        dplyr::left_join(quantityConversionTibble, by = c("local_OMOP_QUANTITY", "MEASUREMENT_UNIT", "local_MEASUREMENT_UNIT_HARMONIZED")) |>
        dplyr::mutate(
            local_CONVERSION_FACTOR = dplyr::if_else(!is.na(only_to_omop_concepts) & only_to_omop_concepts != local_OMOP_CONCEPT_ID, NA_character_, local_CONVERSION_FACTOR),
            local_MEASUREMENT_UNIT_HARMONIZED_target = dplyr::if_else(is.na(MEASUREMENT_UNIT) , NA_character_, local_MEASUREMENT_UNIT_HARMONIZED), 
            local_MEASUREMENT_UNIT_HARMONIZED = dplyr::if_else(is.na(local_CONVERSION_FACTOR), NA_character_, local_MEASUREMENT_UNIT_HARMONIZED)
        )

    # calculate local_decile_MEASUREMENT_VALUE_HARMONIZED
    summary <- summary |>
        dplyr::mutate(
            local_decile_MEASUREMENT_VALUE_HARMONIZED = purrr::map2(.x = decile_MEASUREMENT_VALUE, .y = local_CONVERSION_FACTOR, .f = function(deciles, conversion_factor) {
                if (is.na(conversion_factor) || is.null(deciles)) {
                    return(NULL)
                }
                suppressWarnings({
                    if (is.numeric(as.numeric(conversion_factor))) {
                        deciles |> dplyr::mutate(value = value * as.numeric(conversion_factor))
                    } else {
                        # the it is a*X+b, where a and b are numeric
                        a <- as.numeric(sub(".*\\*", "", conversion_factor))
                        b <- as.numeric(sub(".*\\+", "", conversion_factor))
                        deciles |> dplyr::mutate(value = a * value + b)
                    }
                })
            })
        )

    # Calculate KS test for each OMOP_CONCEPT_ID
    summary <- .calcualteKStest(summary)

    # Calculate Differences between remote and local
    summary <- summary |>
        dplyr::mutate(
            diff_concept_id = dplyr::if_else(status == "APPROVED" & local_OMOP_CONCEPT_ID != remote_OMOP_CONCEPT_ID, paste0("Concept ID: ", remote_OMOP_CONCEPT_ID), NA_character_),
            diff_quantity = dplyr::if_else(status == "APPROVED" & dplyr::coalesce(local_OMOP_QUANTITY, "") != dplyr::coalesce(remote_OMOP_QUANTITY, ""), paste0("Quantity: ", remote_OMOP_QUANTITY), NA_character_),
            diff_conversion_factor = dplyr::if_else(status == "APPROVED" & dplyr::coalesce(local_CONVERSION_FACTOR, "") != dplyr::coalesce(remote_CONVERSION_FACTOR, ""), paste0("Conversion Factor: ", remote_CONVERSION_FACTOR), NA_character_),
            diff_harmonized_unit = dplyr::if_else(status == "APPROVED" & dplyr::coalesce(local_MEASUREMENT_UNIT_HARMONIZED, "") != dplyr::coalesce(remote_MEASUREMENT_UNIT_HARMONIZED, ""), paste0("Harmonized Unit: ", remote_MEASUREMENT_UNIT_HARMONIZED), NA_character_),
            differences = paste0(
                dplyr::if_else(!is.na(diff_concept_id), paste0(diff_concept_id, "<br>"), ""),
                dplyr::if_else(!is.na(diff_quantity), paste0(diff_quantity, "<br>"), ""),
                dplyr::if_else(!is.na(diff_conversion_factor), paste0(diff_conversion_factor, "<br>"), ""),
                dplyr::if_else(!is.na(diff_harmonized_unit), diff_harmonized_unit, "")
            )
        ) |> 
        dplyr::select(-diff_concept_id, -diff_quantity, -diff_conversion_factor, -diff_harmonized_unit)


    summary |> nrow() |> testthat::expect_equal(inNrows)

    return(summary)
}


.calcualteKStest <- function(summary) {
    summary |> checkmate::assert_tibble()

    referenceConcepts <- summary |>
        dplyr::filter(!is.na(local_OMOP_CONCEPT_ID) & !is.na(local_REFERENCE_TEST_NAME) & !is.na(local_MEASUREMENT_UNIT_HARMONIZED)) |>
        dplyr::distinct(local_OMOP_CONCEPT_ID, local_REFERENCE_TEST_NAME, local_MEASUREMENT_UNIT_HARMONIZED, local_REFERENCE_UNIT_PREFIX)

    # keys to join are local_OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT, MEASUREMENT_UNIT_PREFIX
    referenceDistribution <- summary |>
        dplyr::semi_join(
            referenceConcepts,
            by = c("local_OMOP_CONCEPT_ID", "TEST_NAME" = "local_REFERENCE_TEST_NAME", "MEASUREMENT_UNIT" = "local_MEASUREMENT_UNIT_HARMONIZED", "MEASUREMENT_UNIT_PREFIX" = "local_REFERENCE_UNIT_PREFIX")
        ) |>
        dplyr::transmute(
            local_OMOP_CONCEPT_ID,
            TEST_NAME,
            MEASUREMENT_UNIT,
            MEASUREMENT_UNIT_PREFIX,
            #
            decile_MEASUREMENT_VALUE_reference = decile_MEASUREMENT_VALUE,
            local_decile_MEASUREMENT_VALUE_HARMONIZED_reference = local_decile_MEASUREMENT_VALUE_HARMONIZED, 
            n_values_reference = purrr::map_dbl(distribution_values, ~ sum(.x$n[.x$value != "Missing"])),
            n_values_harmonized_reference = purrr::map_dbl(distribution_values, ~ sum(.x$n[.x$value == "Source"]))
        )


    # calculate KS test for each OMOP_CONCEPT_ID
    summary <- summary |>
        dplyr::left_join(referenceDistribution, by = c(
            "local_OMOP_CONCEPT_ID" = "local_OMOP_CONCEPT_ID", 
            "local_REFERENCE_TEST_NAME" = "TEST_NAME", 
            "local_MEASUREMENT_UNIT_HARMONIZED" = "MEASUREMENT_UNIT", 
            "local_REFERENCE_UNIT_PREFIX" = "MEASUREMENT_UNIT_PREFIX")
        ) |> 
        dplyr::mutate(
            n_values = purrr::map_dbl(distribution_values, ~ sum(.x$n[.x$value != "Missing"])),
            n_values_harmonized = purrr::map_dbl(distribution_values, ~ sum(.x$n[.x$value == "Source"])),
            ksTest = purrr::pmap(
                list(
                    decile_MEASUREMENT_VALUE, decile_MEASUREMENT_VALUE_reference,
                    n_values, n_values_reference
                ),
                .ksTest
            ),
            ksTestHarmonized = purrr::pmap(
                list(
                    local_decile_MEASUREMENT_VALUE_HARMONIZED, local_decile_MEASUREMENT_VALUE_HARMONIZED_reference,
                    n_values, n_values_reference
                ),
                .ksTest
            )
        ) |> 
        dplyr::select(
            -n_values, -n_values_reference,
             -n_values_harmonized, -n_values_harmonized_reference, 
             -decile_MEASUREMENT_VALUE_reference,-local_decile_MEASUREMENT_VALUE_HARMONIZED_reference
        )

    return(summary)
}


.ksTest <- function(deciles1, deciles2, n1, n2) {
    n1 <- as.double(n1)
    n2 <- as.double(n2)
    # Validate input parameters with checkmate
    if (is.null(deciles1) || is.null(deciles2)) {
        return(NULL)
    }

    checkmate::assert_tibble(deciles1, min.rows = 9, null.ok = FALSE)
    checkmate::assert_tibble(deciles2, min.rows = 9, null.ok = FALSE)
    checkmate::assert_subset(c("decile", "value"), names(deciles1))
    checkmate::assert_subset(c("decile", "value"), names(deciles2))
    if (!all(deciles1$decile == deciles2$decile)) stop("deciles1 and deciles2 must have the same deciles")

    if (n1 < 2 || n2 < 2) {
        return(NULL)
    }

    deciles <- deciles1$decile
    v1 <- deciles1$value
    v2 <- deciles2$value

    if (any(is.na(v1)) || any(is.na(v2))) {
        return(NULL)
    }

    # CDF from deciles
    cdf <- function(x, p, v) {
        sapply(x, function(z) {
            if (z < min(v)) {
                0
            } else {
                max(p[v <= z])
            }
        })
    }

    # Evaluation grid
    x_all <- sort(unique(c(v1, v2)))

    # CDF values
    F1 <- cdf(x_all, deciles, v1)
    F2 <- cdf(x_all, deciles, v2)

    # KS statistic (lower bound)
    D_hat <- max(abs(F1 - F2))

    # Effective sample size
    n_eff <- (n1 * n2) / (n1 + n2)

    # KS p-value approximation
    lambda <- sqrt(n_eff) * D_hat

    p_value <- 2 * sum(
        sapply(1:100, function(k) {
            (-1)^(k - 1) * exp(-2 * k^2 * lambda^2)
        })
    )

    # Clamp to [0,1]
    p_value <- max(min(p_value, 1), 0)

    return(
        tibble::tibble(
            KS = D_hat,
            pValue = p_value
        )
    )
}


