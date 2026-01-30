


usagi <- readr::read_csv(
    "VOCABULARIES/LABfi_ALL/LABfi_ALL.usagi.csv",
    col_types = readr::cols(.default = readr::col_character())
) 

idsToRemove <- readr::read_delim(
    "VOCABULARIES/LABfi_ALL/source/KantaIDsToRemove.csv",
    delim = ";",
    col_types = readr::cols(.default = readr::col_character())
)

idsToRemove <- idsToRemove |>
    dplyr::distinct(TEST_NAME, REASON)

if (idsToRemove  |> nrow() != idsToRemove |> dplyr::distinct(TEST_NAME) |> nrow()) {
    stop("Duplicate TEST_NAME in idsToRemove")
}

usagiWithIdsToRemove <- usagi |>
dplyr::left_join(
    idsToRemove,
    by = c("ADD_INFO:testNameAbbreviation" = "TEST_NAME")
) |>  
dplyr::rename(`ADD_INFO:ignoreReason` = REASON)

usagiWithIdsToRemove |> 
dplyr::filter(!is.na(`ADD_INFO:ignoreReason`)) |>
dplyr::filter(mappingStatus == "APPROVED")   |> 
nrow() |> 
testthat::expect_equal(0)

usagiWithIdsToRemove |> 
readr::write_csv("VOCABULARIES/LABfi_ALL/LABfi_ALL.usagi.csv", na = "")






usagi |> 
dplyr::mutate(
    mappingStatus = dplyr::if_else(mappingStatus %in% c("FLAGGED", "INVALID_TARGET"), "UNCHECKED", mappingStatus)
 ) |> 
    readr::write_csv("VOCABULARIES/LABfi_ALL/LABfi_ALL.usagi.csv", na = "")
