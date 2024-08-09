

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





# corrections by elisa and mervi
# from https://docs.google.com/spreadsheets/d/1otxRpPVGkzABmH69_guESops-bV4SikCdB79xkCuil4/edit?usp=sharing
fixes <- read_csv('~/Downloads/missing kanta mappings v3 - missing kanta mappings v4.csv')|>
  filter(measurement_concept_id != 0 | is.na(measurement_concept_id)) |>
  mutate(concept_code = str_remove_all(concept_code, ' '))

pathInputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.csv'
lab_usagi <- read_csv(pathInputFile)

lab_usagi_new <- lab_usagi |> inner_join(fixes  |> select(concept_code, measurement_concept_id, COMMENTS), by = c('sourceCode' = 'concept_code'))

path_OMOP_vocabulary_folder <- '~/Documents/REPOS/FinOMOP/FinOMOP_OMOP_vocabulary/OMOP_VOCABULARIES/input_omop_vocabulary/'

concept <- read_tsv(file.path(path_OMOP_vocabulary_folder, 'CONCEPT.csv'))

lab_usagi_new_formated  <- lab_usagi_new  |> left_join(concept, by = c('measurement_concept_id' = 'concept_id')) |>
  transmute(
    sourceCode = sourceCode,
    sourceName = sourceCode,
    sourceFrequency = sourceFrequency,
    sourceAutoAssignedConceptIds = sourceAutoAssignedConceptIds,
    `ADD_INFO:measurementUnit` = `ADD_INFO:measurementUnit`,
    `ADD_INFO:sourceConceptId` = `ADD_INFO:sourceConceptId`,
    `ADD_INFO:sourceName_fi` = `ADD_INFO:sourceName_fi`,
    `ADD_INFO:sourceConceptClass` =  `ADD_INFO:sourceConceptClass`,
    `ADD_INFO:sourceDomain` =  `ADD_INFO:sourceDomain`,
    `ADD_INFO:sourceValidStartDate` =  as_datetime(ymd('1970-01-01')),
    `ADD_INFO:sourceValidEndDate` = as_datetime(ymd('2099-12-31')),
    `ADD_INFO:Valuepercentiles` = `ADD_INFO:Valuepercentiles`,
    `ADD_INFO:omopQuantity` = NA_character_,
    `ADD_INFO:testNameAbbreviation` = `ADD_INFO:testNameAbbreviation`,
    matchScore = 0,
    mappingStatus =  'APPROVED',
    equivalence = NA_character_,
    statusSetBy = 'Elisa&Mervi',
    statusSetOn = as.integer(as_datetime(now()))*1000,
    conceptId = if_else(is.na(measurement_concept_id), 0, measurement_concept_id),
    conceptName = concept_name,
    domainId = domain_id,
    mappingType = NA_character_,
    comment = COMMENTS,
    createdBy = 'AUTO',
    createdOn = statusSetOn,
    assignedReviewer = NA_character_
  )



lab_usagi_new_formated_save <- bind_rows(
  lab_usagi  |> anti_join(lab_usagi_new_formated, by = 'sourceCode'),
  lab_usagi_new_format) |>
  distinct(sourceCode, .keep_all = TRUE)

lab_usagi_new_formated_save |> write_csv(pathInputFile, na = '')








