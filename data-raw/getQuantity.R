

path_OMOP_vocabulary_folder <- '~/Documents/REPOS/FinOMOP/FinOMOP_OMOP_vocabulary/OMOP_VOCABULARIES/input_omop_vocabulary/'

concept <- read_tsv(file.path(path_OMOP_vocabulary_folder, 'CONCEPT.csv'))

concept_relationship <- read_tsv(file.path(path_OMOP_vocabulary_folder, 'CONCEPT_RELATIONSHIP.csv'))


LOINC_has_property  <- concept  |>
  filter(vocabulary_id == 'LOINC') |>
  filter(standard_concept == 'S') |>
  filter(domain_id == 'Measurement') |>
  #filter(concept_class_id == 'Lab Test') |>
  select(concept_id) |>
  left_join(
    concept_relationship  |>
      filter(relationship_id == 'Has property'),
    by = c('concept_id' = 'concept_id_1')
  )  |>
  select(concept_id, concept_id_2) |>
  left_join(
    concept |>
      select(concept_id, concept_name) ,
    by = c('concept_id_2' = 'concept_id')
  )  |>
  transmute(
    concept_id = concept_id,
    omop_quantity =  if_else(!is.na(concept_name), concept_name, '-')
  )



LOINC_has_property |>
  write_csv('MAPPING_TABLES/LOINC_has_property.csv')



