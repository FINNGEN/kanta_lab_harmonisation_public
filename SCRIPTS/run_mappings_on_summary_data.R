
library(tidyverse)
source('R/fct_modify_usagi.R')
source('R/fct_values.R')
source('R/fct_dashboard.R')

summary_data <- read_tsv('INPUT_SUMMARY_DATA/finngen_summary_data.tsv') |>
  mutate(status = NA_character_) |>
  mutate(
    source_unit_clean = if_else(is.na(source_unit_clean), '', source_unit_clean),
    value_percentiles = str_replace_all(value_percentiles, ',  \\]', ' ]')
  )

# if missing p_missing_values column add it
if (!'p_missing_values' %in% colnames(summary_data)) {
  summary_data <- summary_data |>
    mutate(p_missing_values = NA_real_)
}

# checks
summary_data |> count(TEST_NAME_ABBREVIATION,source_unit_clean)  |> filter(n > 1) |> nrow() |>
  testthat::expect_equal(0)

#
# STEP 1: fix units within abbreviations context
# - we can see that some units do not agree with the abbreviation, these are fixed based on the table in fix_unit_based_in_abbreviation.tsv
#

fix_unit_based_on_abbreviation  <- read_tsv('MAPPING_TABLES/fix_unit_based_in_abbreviation.tsv')

summary_data_1  <- summary_data |>
  left_join(fix_unit_based_on_abbreviation, by = c('TEST_NAME_ABBREVIATION', 'source_unit_clean')) |>
  mutate(
    source_unit_clean_fix = if_else(is.na(source_unit_clean_fix), source_unit_clean, source_unit_clean_fix)
  )  |>
  select(TEST_NAME_ABBREVIATION, source_unit_clean, source_unit_clean_fix, n_records, value_percentiles, p_missing_values, status)


#check if units are comparable,
# plot changes units with the similar ones, check similarity in value distribution
summary_data |>
  left_join(fix_unit_based_on_abbreviation, by = c('TEST_NAME_ABBREVIATION', 'source_unit_clean')) |>
  semi_join(fix_unit_based_on_abbreviation, by = c('TEST_NAME_ABBREVIATION')) # |>View()

# summary_data_2 |> filter(!is.na(status))  |> count(source_unit_clean, sort=TRUE)


#
# STEP 2: validate units
# - check if the units in the source exist in the list of valid units UNITSfi.usagi.csv file
#
usagi_units <- read_csv('MAPPING_TABLES/UNITSfi.usagi.csv') |>
  transmute(
    source_unit_clean_fix = sourceCode,
    source_unit_valid = sourceCode
  ) |>
  # add no unit to be valid
  add_row(source_unit_clean_fix = '', source_unit_valid = '')

summary_data_2  <- summary_data_1 |>
  left_join(usagi_units, by = c('source_unit_clean_fix')) |>
  mutate(
    status = if_else(is.na(status) & is.na(source_unit_valid), 'ERROR: Units: invalid source_unit_clean', status)
  ) |>
  select(TEST_NAME_ABBREVIATION, source_unit_clean, source_unit_clean_fix, source_unit_valid, n_records, value_percentiles, p_missing_values, status)

# CHECKS
summary_data_2 |> filter(!is.na(status))  |>
  group_by(source_unit_clean)  |>
  summarise(n = n(), n_records = sum(n_records), .groups = 'drop')  |>
  arrange(desc(n_records))

#
# STEP 3: Harmonize abbreviation unit pairs
# - check if the abbreviation+unit pairs are in the MAPPING_TABLES/LABfi_ALL.usagi.csv file
#

# Optionaly, usagi file can be updated with current counts and values
if (FALSE) {
  update_usagi_counts_values(
    pathInputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.bootstrap.checked.csv',
    summary_data_2 = summary_data_2,
    pathOutputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.csv'
  )
}
# Optionaly, if mappings in the usagi file have change, these changes must be checked if correct
if (FALSE) {
  check_lab_usagi_file(
    pathInputFile = 'MAPPING_TABLES/LABfi_ALL.usagi.csv',
    pathValidQuantityFile = 'MAPPING_TABLES/LOINC_has_property.csv',
    pathValidQuantityUnitsFile = 'MAPPING_TABLES/quantity_source_unit_conversion.tsv'
  )
}

labfi_usagi <- read_csv('MAPPING_TABLES/LABfi_ALL.usagi.csv')|>
  transmute(
    TEST_NAME_ABBREVIATION = str_remove(sourceCode, '\\[.*\\]'),
    source_unit_valid = str_remove_all(str_extract(sourceCode, '\\[.*\\]'), '\\[|\\]'),
    source_unit_valid = if_else(source_unit_valid == '', NA_character_, source_unit_valid),
    omop_quantity = `ADD_INFO:omopQuantity`,
    measurement_concept_id = if_else(mappingStatus == 'APPROVED', conceptId, 0),
    error_message = if_else(mappingStatus == 'FLAGGED', comment, NA_character_),
    concept_name = conceptName
  )

summary_data_3  <- summary_data_2 |>
  left_join(
    labfi_usagi,
    by = c('TEST_NAME_ABBREVIATION', 'source_unit_valid')
  ) |>
  mutate(
    status = if_else(is.na(status) & is.na(measurement_concept_id), 'ERROR: Mapping: unknown abbreviation+unit', status),
    status = if_else(is.na(status) & measurement_concept_id == 0 &  is.na(error_message), 'ERROR: Mapping: missing mapping', status),
    status = if_else(is.na(status) & measurement_concept_id == 0 & !is.na(error_message), error_message, status)
  ) |>
  select(TEST_NAME_ABBREVIATION, source_unit_clean, source_unit_clean_fix, source_unit_valid, n_records, value_percentiles, p_missing_values, status,omop_quantity, measurement_concept_id,
         concept_name)

# summary_data_3 |> filter(!is.na(status))  |> count(source_unit_clean, sort=TRUE)

#
# STEP 4: Harmonize values
# - For each omop group, the most common unit is chosen, the other units are converted to this unit using quantity_source_unit_conversion.tsv table
#

unit_conversion <- read_tsv('MAPPING_TABLES/quantity_source_unit_conversion.tsv')

summary_data_4  <- summary_data_3 |>
  # get most common unit for the group
  group_by(measurement_concept_id) |>
  arrange(measurement_concept_id, desc(n_records)) |>
  nest() |>
  mutate(
    to_source_unit_valid = map_chr(data, ~{
      .x |> pull(source_unit_valid) |> first()
    }),
    to_source_unit_valid = if_else(is.na(measurement_concept_id) | measurement_concept_id==1, NA_character_, to_source_unit_valid),
    ref_value_percentiles = map_chr(data, ~{
      .x |> pull(value_percentiles) |> first()
    }),
    ref_value_percentiles = if_else(is.na(measurement_concept_id) | measurement_concept_id==1, NA_character_, ref_value_percentiles)
  )  |>
  unnest(cols = c(data)) |>
  # join with conversion table
  left_join(unit_conversion, by = c('omop_quantity', 'source_unit_valid', 'to_source_unit_valid'))  |>
  # check if conversion is possible
  mutate(
    status = if_else(is.na(status) & is.na(conversion), 'ERROR: Value: missing units conversion', status)
  ) |>
  # multiply by conversion factor
  mutate(
    to_value_percentiles = map2_chr(value_percentiles, conversion, ~{
      if (is.na(.x) | is.na(.y)) return(NA_character_)
      if (.y == 1) return(.x)
      a <- .x  |> str_remove_all(' ')  |> str_replace_all('\\[|\\]', '') |> str_split(',')  |> unlist()
      a <- suppressWarnings(as.numeric(a))  * .y
      a[is.na(a)] <- '_'
      paste0('[ ', paste0(a, collapse = ', '), ' ]')
    })
  )

# summary_data_4 |> filter(conversion != 1)  |> view()
# summary_data_4 |> filter(status == 'ERROR: Value: missing units conversion')  |> view()



#
# STEP 5: Check if values are comparable
# - For each omop group, values for each abbreviation+unit pair is are compare to the most common abbreviation+unit pair in the group using a KS-test
#

pass_value  <- 0.2

summary_data_5 <- summary_data_4 |>
  # convert string values to tibble
  mutate(
    to_value_percentiles_tibble = map(to_value_percentiles, value_percentiles_to_tibble),
    ref_value_percentiles_tibble= map(ref_value_percentiles, value_percentiles_to_tibble),
    group_value_min = map_dbl(to_value_percentiles_tibble, ~{ if (is.null(.x)) return(NA_real_); .x$value |> min(na.rm = TRUE)}),
    group_value_max = map_dbl(to_value_percentiles_tibble, ~{ if (is.null(.x)) return(NA_real_); .x$value |> max(na.rm = TRUE)})
  ) |>
  # calculate max and min for the group
  group_by(measurement_concept_id)  |>
  mutate(
    group_value_min = min(group_value_min, na.rm = TRUE),
    group_value_max =  max(group_value_max, na.rm = TRUE)
  )  |>
  ungroup() |>
  #summary_data_5 |> #slice(2935) |>
  mutate(
    KS_test= pmap_dbl(list(to_value_percentiles_tibble, ref_value_percentiles_tibble, group_value_min, group_value_max), ~{
      if (is.null(..1) | is.null(..2) | is.na(..3) | is.na(..4)) return(NA_real_)

      a <- ..1  |> distinct(value, .keep_all = T)
      b <- ..2  |> distinct(value, .keep_all = T)
      if(nrow(a) < 2) return(NA_real_)
      if(nrow(b) < 2) return(NA_real_)
      #browser()
      new_percentiles_value <- seq(..3, ..4, length.out = 100)
      new_percentiles_points_a  <- approx(x = a$value, y = a$percentile, xout = new_percentiles_value, yleft = 0, yright = 1)$y
      new_percentiles_points_b  <- approx(x = b$value, y = b$percentile, xout = new_percentiles_value, yleft = 0, yright = 1)$y

      max(abs(new_percentiles_points_a - new_percentiles_points_b))
    })
  ) |>
  # if there is not info in the ks test, then it is an error
  mutate(
    status = if_else( is.na(status) & is.na(KS_test), 'WARNING: Value: KS test failed', status)
  )|>
  # if the test dont pass, then it is an warning
  mutate(
    status = if_else( is.na(status) & KS_test > pass_value , 'WARNING: Value: Values are significalty different', status)
  )

#
# summary_data_5  |>
#   semi_join(
#     summary_data_5  |> filter(KS_test > pass_value),
#     by = c('TEST_NAME_ABBREVIATION')
#   )  |>
#   arrange(measurement_concept_id, desc(n_records))  |>
#   view()


#
# PLOT status and table
#

# ATM keep this commented to not colide with github actions
dashboard <-  buildStatusDashboard(summary_data_5)
browseURL(dashboard)


