

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

  # check if wrong mapping or units dont match quantity
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
      comment = case_when(
        conceptId == 0 ~ '',
        is.na(omop_quantity) ~ 'ERROR; Mapping: Wrong mapping',
        is.na(quantity_correct) ~ 'ERROR; Units: Units dont match quantity',
        TRUE ~ ''
      ),
      `ADD_INFO:omopQuantity` = omop_quantity
    )|>
    select(-omop_quantity, -quantity_correct)

  # check if wrong group mapping
  valid_test_quantity_conceptId   <-  lab_usagi  |>
    filter(mappingStatus == 'APPROVED') |>
    group_by(`ADD_INFO:testNameAbbreviation`, `ADD_INFO:omopQuantity`) |>
    summarise(
      conceptIds = paste(unique(conceptId), collapse = ','),
      nConcepts = n_distinct(conceptId),
      .groups = 'drop'
    )

  ambiguous_mappings <- valid_test_quantity_conceptId |>
    filter(nConcepts > 1)

  if (nrow(ambiguous_mappings) > 0) {
    lab_usagi_checked <- lab_usagi_checked |>
      left_join(
        ambiguous_mappings,
        by = c('ADD_INFO:testNameAbbreviation', 'ADD_INFO:omopQuantity')
      ) |>
      mutate(
        comment = if_else(
          !is.na(nConcepts),
          paste('ERROR; Mapping: Ambiguous mapping, same abbrebiation',`ADD_INFO:testNameAbbreviation`,
                ' and ', `ADD_INFO:omopQuantity`,
                'maps to different concepts',conceptIds),
          comment)
      ) |>
      select(-conceptIds, -nConcepts)
  }

  # create mapping to abbreviations with no units
  #stop('not run is breaking the existing mappins to code with no units FIX')
  valid_test_quantity_conceptId_with_units   <-  lab_usagi  |>
    filter(mappingStatus == 'APPROVED') |>
    filter(!str_detect(sourceCode, '\\[\\]')) |>
    group_by(`ADD_INFO:testNameAbbreviation`, `ADD_INFO:omopQuantity`) |>
    summarise(
      conceptIds = paste(unique(conceptId), collapse = ','),
      nConcepts = n_distinct(conceptId),
      .groups = 'drop'
    )

    valid_test_one_quantity_conceptid <- valid_test_quantity_conceptId_with_units  |>
    filter(nConcepts == 1) |>
    mutate(conceptId = as.numeric(conceptIds)) |>
    group_by(`ADD_INFO:testNameAbbreviation`) |>
    summarise(
      conceptIds = paste(unique(conceptId), collapse = ','),
      nConcepts = n_distinct(conceptId),
      .groups = 'drop'
    ) |>
    arrange(desc(nConcepts)) |>
    mutate(conceptId = suppressWarnings(as.numeric(conceptIds)))

  new_mappings <- valid_test_one_quantity_conceptid |>
    # add info from usagi file witn units
    left_join(
      lab_usagi |>
        filter(!is.na(conceptId)) |> filter(conceptId!=0) |>
        distinct(conceptId, conceptName, domainId, `ADD_INFO:omopQuantity`),
      by = c('conceptId')
    ) |>
  #
  transmute(
    sourceCode = paste0(`ADD_INFO:testNameAbbreviation`, '[]'),
    sourceName = sourceCode,
    sourceFrequency = 0,
    sourceAutoAssignedConceptIds = NA_integer_,
    `ADD_INFO:measurementUnit` = '',
    `ADD_INFO:sourceConceptId` = 2002410000+row_number(),
    `ADD_INFO:sourceName_fi` = '',
    `ADD_INFO:sourceConceptClass` =  'LABfi_ALL Level 0',
    `ADD_INFO:sourceDomain` =  'Measurement',
    `ADD_INFO:sourceValidStartDate` =  as_datetime(ymd('1970-01-01')),
    `ADD_INFO:sourceValidEndDate` = as_datetime(ymd('2099-12-31')),
    `ADD_INFO:Valuepercentiles` = NA_character_,
    `ADD_INFO:omopQuantity` = `ADD_INFO:omopQuantity`,
    `ADD_INFO:testNameAbbreviation` = `ADD_INFO:testNameAbbreviation`,
    matchScore = 0,
    mappingStatus = if_else(nConcepts==1, 'APPROVED', 'FLAGGED'),
    equivalence = NA_character_,
    statusSetBy = 'AUTO',
    statusSetOn = as.integer(as_datetime(now()))*1000,
    conceptId = if_else(nConcepts==1, conceptId, 0),
    conceptName = conceptName,
    domainId = domainId,
    mappingType = NA_character_,
    comment = if_else(nConcepts==1, '',
                      paste('ERROR; Mapping: cannot map without unit, multiple targets')
    ),
    createdBy = 'AUTO',
    createdOn = statusSetOn,
    assignedReviewer = NA_character_
  )

  # remove all the codes that will be modified
  n_codes_no_units <- intersect(lab_usagi_checked$sourceCode , new_mappings$sourceCode) |>
    length()

  lab_usagi_checked <- lab_usagi_checked |>
    anti_join(new_mappings, by = 'sourceCode')

  lab_usagi_checked <- bind_rows(lab_usagi_checked, new_mappings)

  warning(paste('Removed', n_codes_no_units, 'codes with no units, added', nrow(new_mappings), 'codes with no units'))

  # update mapping status and write file
  lab_usagi_checked |>
    mutate(
      mappingStatus = case_when(
        comment != ''  ~ 'FLAGGED',
        comment == '' & conceptId != 0 ~ 'APPROVED',
        TRUE ~ mappingStatus
      ),
    )  |>
    arrange(desc(sourceFrequency)) |>
    write_csv(pathOutputFile, na = '')
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



# append missing no unit abbreviations
#
# new  <- summary_data_5  |>
#   filter(status == 'ERROR: Mapping: unknown abbreviation+unit') |> filter(source_unit_clean=='') |>
#   transmute(
#     sourceCode = paste0(TEST_NAME_ABBREVIATION, '[]'),
#     sourceName = sourceCode,
#     sourceFrequency = n_records,
#     sourceAutoAssignedConceptIds = NA_integer_,
#     `ADD_INFO:measurementUnit` = '',
#     `ADD_INFO:sourceConceptId` = 2002420000+row_number(),
#     `ADD_INFO:sourceName_fi` = '',
#     `ADD_INFO:sourceConceptClass` =  'LABfi_ALL Level 0',
#     `ADD_INFO:sourceDomain` =  'Measurement',
#     `ADD_INFO:sourceValidStartDate` =  as_datetime(ymd('1970-01-01')),
#     `ADD_INFO:sourceValidEndDate` = as_datetime(ymd('2099-12-31')),
#     `ADD_INFO:Valuepercentiles` = NA_character_,
#     `ADD_INFO:omopQuantity` = omop_quantity,
#     `ADD_INFO:testNameAbbreviation` = TEST_NAME_ABBREVIATION,
#     matchScore = 0,
#     mappingStatus =  'UNCHECKED',
#     equivalence = NA_character_,
#     statusSetBy = 'AUTO',
#     statusSetOn = as.integer(as_datetime(now()))*1000,
#     conceptId = 0,
#     conceptName =  '',
#     domainId = '',
#     mappingType = NA_character_,
#     comment = '',
#     createdBy = 'AUTO',
#     createdOn = statusSetOn,
#     assignedReviewer = NA_character_
#   )
#
# pathInputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.csv'
# lab_usagi <- read_csv(pathInputFile)
#
# lab_usagi_new <- bind_rows(lab_usagi, new) |>
#   distinct(sourceCode, .keep_all = TRUE)
#
# lab_usagi_new |> write_csv(pathInputFile, na = '')
#
#
#
#




















