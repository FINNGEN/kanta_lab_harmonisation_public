

check_lab_usagi_file <- function(
    pathInputFile,
    pathValidQuantityFile,
    pathValidQuantityUnitsFile,
    pathOutputFile = pathInputFile) {

  #check file exists
  if (!file.exists(pathInputFile)) {
    stop("File pathInputFile does not exist")
  }
  if (!file.exists(pathValidQuantityFile)) {
    stop("File pathValidQuantityFile does not exist")
  }
  if (!file.exists(pathValidQuantityUnitsFile)) {
    stop("File pathValidQuantityUnitsFile does not exist")
  }


  #read files
  quantity   <- read_csv(pathValidQuantityFile) |>
    select(concept_id, omop_quantity) |>
    distinct()

  quantity_unit <- read_tsv(pathValidQuantityUnitsFile) |>
    distinct(omop_quantity,	source_unit_valid)


  lab_usagi <- read_csv(pathInputFile)

  lab_usagi_checked <- lab_usagi |>
    left_join(
      quantity,
      by = c('conceptId' = 'concept_id')
    )|>
    left_join(
      quantity_unit  |> mutate(quantity_correct = TRUE),
      by = c('omop_quantity' = 'omop_quantity', `ADD_INFO:measurementUnit` = 'source_unit_valid')
    ) |>
    mutate(
      status = case_when(
        conceptId == 0 ~ '',
        is.na(omop_quantity) ~ 'ERROR; Mapping: Wrong mapping',
        is.na(quantity_correct) ~ 'ERROR; Units: Units dont match quantity',
        TRUE ~ ''
      )
    ) |>
    mutate(
      mappingStatus = case_when(
        status != ''  ~ 'FLAGGED',
        status == '' & conceptId != 0 ~ 'APPROVED',
        TRUE ~ mappingStatus
      ),
      `ADD_INFO:omopQuantity` = omop_quantity,
      comment = status
    ) |>
    select(-omop_quantity, -status, -quantity_correct) |>
    arrange(desc(sourceFrequency))

  lab_usagi_checked |> write_csv(pathOutputFile, na = '')
}




#
# check_lab_usagi_file(
#   pathInputFile = 'mapping_tables/LABfi_ALL.usagi.csv',
#   pathValidQuantityFile = 'data/LOINC_has_property.csv',
#   pathValidQuantityUnitsFile = 'mapping_tables/valid_quantity_units.tsv',
#   pathOutputFile = 'mapping_tables/LABfi_ALL.usagi.checked.csv'
# )

update_usagi_counts_values <- function(
    pathInputFile,
    summary_data_2,
    pathOutputFile = pathInputFile) {

  pathInputFile |> checkmate::assertFileExists()
  summary_data_2 |> checkmate::assertTibble()
  c('TEST_NAME_ABBREVIATION', 'source_unit_valid', 'n_records', 'value_percentiles')  |>
    checkmate::assertSubset(summary_data_2 |> names())

  # update usagi with current counts and values
  labfi_usagi <- read_csv(pathInputFile) |>
    left_join(
      summary_data_2  |>
        filter(!is.na(source_unit_valid)) |>
        distinct(TEST_NAME_ABBREVIATION, source_unit_valid, .keep_all = TRUE) |>
        transmute(
          sourceCode = paste0(TEST_NAME_ABBREVIATION, '[', if_else(is.na(source_unit_valid), '', source_unit_valid), ']'),
          n_records = n_records,
          value_percentiles = value_percentiles
        ),
      by = c('sourceCode')) |>
    mutate(
      sourceFrequency = if_else(is.na(n_records), 0, n_records),
      `ADD_INFO:Valuepercentiles` = value_percentiles
    )  |>
    select(-n_records, -value_percentiles) |>
    arrange(desc(sourceFrequency))


  labfi_usagi |> write_csv(pathOutputFile, na = '')

}


















