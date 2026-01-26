source("SCRIPTS/setEnviroment.R")

# Create connection to test database


#
# Build the status dashboard
#
pathToCodeCountsLabFolder <- "CODE_COUNTS/databases/LABfi_FinnGenDF13"
pathToVocabularyLabFolder <- "MAPPING_TABLES"

connection <- DatabaseConnector::connect(
    dbms = "duckdb",
    server = pathToOMOPVocabularyDuckDBfile
)
# DatabaseConnector::disconnect(connection)

dashboardFolder <- tempdir()





#
# Find similar test names
#

toMatchSummary <- summary |>
    dplyr::filter(is.na(as.numeric(TEST_NAME))) |>
    dplyr::filter(n_records > 500) |>
    dplyr::mutate(testId = paste0(TEST_NAME, " [", dplyr::if_else(is.na(MEASUREMENT_UNIT), "", MEASUREMENT_UNIT), "]")) |>
    select(OMOP_CONCEPT_ID, testId, n_records)


YESmapped <- toMatchSummary |>
    dplyr::filter(OMOP_CONCEPT_ID >= 1)

NOmapped <- toMatchSummary |>
    dplyr::filter(OMOP_CONCEPT_ID < 1)


distance <- stringdist::stringdistmatrix(YESmapped$testId, NOmapped$testId, method = "jw")
distanceMatrix <- as.matrix(distance)
namedDistanceMatrix <- list(
    YESmapped = YESmapped,
    NOmapped = NOmapped,
    distanceMatrix = distanceMatrix
)


testId <- "p-krea []"

.findClosestOMOPIds <- function(testId, namedDistanceMatrix, n = 10) {
    YESmapped <- namedDistanceMatrix$YESmapped
    NOmapped <- namedDistanceMatrix$NOmapped
    distanceMatrix <- namedDistanceMatrix$distanceMatrix

    idx <- which(NOmapped$testId == testId)
    if (length(idx) == 0) {
        return(NULL)
    }
    distances <- distanceMatrix[, idx]
    closestN_idx <- order(distances)[1:n]
    closestN_distances <- distances[closestN_idx]

    result <- YESmapped |>
        dplyr::slice(closestN_idx) |>
        dplyr::mutate(distance = closestN_distances) |>
        dplyr::group_by(OMOP_CONCEPT_ID) |>
        dplyr::summarise(
            n_closest = n(),
            testIds = paste(testId, collapse = " | "),
            mean_distance = mean(distance)
        ) |>
        dplyr::arrange(mean_distance) |> 
        dplyr::slice(1:3)

    return(result)
}

.closestToGoogle <- function(closest) {
    if (is.null(closest)) {
        return(tibble::tibble(formula = character(0)))
    }
    closest |>
    dplyr::mutate(
        formula = paste0(
            "=HYPERLINK(\"https://risteys.finngen.fi/lab-tests/", OMOP_CONCEPT_ID, "\", \"",
            OMOP_CONCEPT_ID, "\"&CHAR(10)&\"", n_closest, " testIds: ", testIds, "\"&CHAR(10)&\"distance: ", round(mean_distance, 3), "\")"
        )
    ) |>
    dplyr::select(formula) 
}

#
NOmappedClosest <- NOmapped  |> 
dplyr::mutate(
    closest = purrr::map(testId, .findClosestOMOPIds, namedDistanceMatrix, n = 10),
    closest_google = purrr::map(closest, .closestToGoogle)
) 


pathToClosestOMOPIdsCSV <- file.path("~/Downloads", "closest_omop_ids.csv")

NOmappedClosest |>
 select(testId, n_records, closest_google) |>
 tidyr::unnest(closest_google, keep_empty = TRUE) |>
 dplyr::group_by(testId, n_records) |>
 dplyr::mutate(row_num = dplyr::row_number()) |>
 dplyr::ungroup() |>
 tidyr::pivot_wider(
   names_from = row_num,
   values_from = formula,
   names_prefix = "closest_omop_"
 ) |>
 dplyr::select(testId, n_records, dplyr::starts_with("closest_omop_"))  |> 
 readr::write_csv(pathToClosestOMOPIdsCSV, na = "")
 
