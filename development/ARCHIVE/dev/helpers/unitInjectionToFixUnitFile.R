# take paths from runAllLocal.R

unitInjection <- readr::read_tsv(
  "dev/helpers/tmp.tsv",
  col_types = readr::cols(.default = readr::col_character()),
  na = "NA"
)
fixUnitTibble <- ROMOPMappingTools::readFixUnitFile(pathToUnitFixFile)


unitInjection <- unitInjection |>
  dplyr::transmute(
    TEST_NAME_ABBREVIATION = TEST_ABBR,
    source_unit_clean = ORIG_UNIT,
    source_unit_clean_fix = SUGGESTED_UNIT,
    notes = dplyr::if_else(NOTES == "SUCCESS", NA_character_, NOTES)
  ) |>
  dplyr::filter(!is.na(source_unit_clean_fix))

newFixUnitTibble <- dplyr::bind_rows(
  fixUnitTibble,
  unitInjection
)

res <- ROMOPMappingTools::validateFixUnitTibble(
  newFixUnitTibble,
  validNameUnitsTibble
)

res$fixUnitTibble |> readr::write_tsv(pathToUnitFixFile, na = "")


# Append to usagi file these that are not there 
missing <- res$fixUnitTibble |> 
  dplyr::filter(stringr::str_detect(validation_messages, "TEST_NAME_ABBREVIATION"))  |> 
  dplyr::select(-notes, -validation_messages)
  
usagiTibble <- ROMOPMappingTools::readUsagiFile(pathToUsagiFile)
lastSourceConceptId <- usagiTibble |> dplyr::pull(`ADD_INFO:sourceConceptId`) |> as.integer() |> max(na.rm = TRUE)

toAppend <- usagiTibble  |> 
  dplyr::inner_join(missing, by = c("ADD_INFO:testNameAbbreviation" = "TEST_NAME_ABBREVIATION", "ADD_INFO:measurementUnit" = "source_unit_clean")) |> 
  dplyr::mutate(
    sourceCode = sourceCode |> stringr::str_remove("\\[\\]") |> paste0("[", source_unit_clean_fix, "]"),
    sourceName = sourceName |> stringr::str_remove("\\[\\]") |> paste0("[", source_unit_clean_fix, "]"), 
    `ADD_INFO:measurementUnit` = source_unit_clean_fix
  ) |> 
  dplyr::select( -source_unit_clean_fix)

usagiTibble  <- dplyr::bind_rows(
  usagiTibble,
  toAppend
) 

ROMOPMappingTools::writeUsagiFile(usagiTibble, pathToUsagiFile)
