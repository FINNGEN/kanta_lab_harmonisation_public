# Codes with no units were initially not included in the mapping
# When added, we tried to find a mapping based on the existing mappings
# However, many did not exist with a unit either
# this script finds these in the original FinOMOP mappings and add them to usagi


# 1. run run_mappings_on_summary_data.R script first to get summary_data_5

code_no_unit_missing  <- summary_data_5  |>
  filter(status == 'ERROR: Mapping: unknown abbreviation+unit') |>
  filter(source_unit_valid == '')  |>
  select(TEST_NAME_ABBREVIATION, n_records)


finomop_mappings <- read_csv('SCRIPTS/source/thl_hus_tku_tmp_lab_codes.csv') |>
  select(source, abbreviation, name_fi, concept_id = concept_id_omop_grouped) |>
  mutate(concept_id = suppressWarnings(as.integer(concept_id)))|>
  filter(!is.na(concept_id)) |>
  # take only distinct mappings
  distinct(abbreviation, .keep_all = TRUE)


path_OMOP_vocabulary_folder <- '~/Documents/REPOS/FinOMOP/FinOMOP_OMOP_vocabulary/OMOP_VOCABULARIES/input_omop_vocabulary/'

concept <- read_tsv(file.path(path_OMOP_vocabulary_folder, 'CONCEPT.csv'))

quantity   <- read_csv('MAPPING_TABLES/LOINC_has_property.csv') |>
  select(concept_id, omop_quantity) |>
  distinct()

new_mappings  <- code_no_unit_missing |>
  left_join(finomop_mappings, by = c('TEST_NAME_ABBREVIATION' = 'abbreviation'))   |>
  filter(!is.na(concept_id)) |>
  left_join(concept, by = 'concept_id')  |>
  left_join(quantity, by = 'concept_id')  |>
  #
  transmute(
    sourceCode = paste0(TEST_NAME_ABBREVIATION, '[]'),
    sourceName = sourceCode,
    sourceFrequency = n_records,
    sourceAutoAssignedConceptIds = NA_integer_,
    `ADD_INFO:measurementUnit` = '',
    `ADD_INFO:sourceConceptId` = 2002420000+row_number(),
    `ADD_INFO:sourceName_fi` = name_fi,
    `ADD_INFO:sourceConceptClass` =  'LABfi_ALL Level 0',
    `ADD_INFO:sourceDomain` =  'Measurement',
    `ADD_INFO:sourceValidStartDate` =  as_datetime(ymd('1970-01-01')),
    `ADD_INFO:sourceValidEndDate` = as_datetime(ymd('2099-12-31')),
    `ADD_INFO:Valuepercentiles` = NA_character_,
    `ADD_INFO:testNameAbbreviation` = TEST_NAME_ABBREVIATION,
    `ADD_INFO:omopQuantity` = omop_quantity,
    matchScore = 0,
    mappingStatus = 'APPROVED',
    equivalence = NA_character_,
    statusSetBy = source,
    statusSetOn = as.integer(as_datetime(now()))*1000,
    conceptId = concept_id,
    conceptName = concept_name,
    domainId = domain_id,
    mappingType = NA_character_,
    comment = '',
    createdBy = 'AUTO',
    createdOn = statusSetOn,
    assignedReviewer = NA_character_
  )

lab_usagi <- read_csv('MAPPING_TABLES/LABfi_ALL.usagi.csv')

new_lab_usagi <- bind_rows(lab_usagi, new_mappings)

if (nrow(new_lab_usagi) != nrow(new_lab_usagi |> distinct(sourceCode))) {
  new_lab_usagi |> count(sourceCode, sort = T)
  stop('Something went wrong')
}

new_lab_usagi  |>  write_csv('MAPPING_TABLES/LABfi_ALL.usagi.csv', na = '')
