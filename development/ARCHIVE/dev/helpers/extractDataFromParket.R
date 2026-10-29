library(arrow)
library(dplyr)
library(testthat)

dev <- FALSE
nSubjectsMin  <- 5

#
# Load data
#

# - Copy file from bucket:
#
# gsutil cp gs://fg-production-sandbox-46-red/kanta/v3/2026_02_03/kanta_dev_2026_02_03.txt.gz ~/Documents/Rprojecs/LabValues/data/kanta_dev.txt.gz
#
# - Convert to parquet:
#
# ~/tools/duckdb -c "
# COPY (
#   SELECT *
#   FROM read_csv(
#     'kanta_dev.txt.gz',
#     delim='\t',
#     nullstr = 'NA',
#     ignore_errors = true
#   )
# )
# TO 'kanta_dev.parquet';
# "

kanta_parquet_source  <- open_dataset("data/kanta_dev.parquet")
if(dev==TRUE){
  kanta_parquet_source  <- kanta_parquet_source |> head(10^6)
}

kanta_parquet_source |> glimpse()

kanta_parquet  <- kanta_parquet_source |>
  transmute(
    FINNGENID = FINNGENID,
    TEST_OUTCOME = TEST_OUTCOME,
    TEST_NAME = `cleaned::TEST_NAME_ABBREVIATION`,
    MEASUREMENT_UNIT_PREFIX = `cleaned-pre-fix::MEASUREMENT_UNIT`,
    MEASUREMENT_UNIT = `cleaned::MEASUREMENT_UNIT`,
    #
    IS_EXTRACTED = if_else(is.na(`cleaned::MEASUREMENT_VALUE`) & !is.na(`extracted::MEASUREMENT_VALUE`), TRUE, FALSE),
    MEASUREMENT_VALUE_TYPE = case_when(
      QC_PASS ==  0L ~ "QCOut",
      IS_EXTRACTED == TRUE ~ "Extracted",
      !is.na(`cleaned::MEASUREMENT_VALUE`) ~ "Source",
      TRUE ~ NA_character_
    ),
    MEASUREMENT_VALUE = case_when(
      MEASUREMENT_VALUE_TYPE == "Extracted" ~ `extracted::MEASUREMENT_VALUE`,
      MEASUREMENT_VALUE_TYPE == "Source" ~ `cleaned::MEASUREMENT_VALUE`,
      TRUE ~ NA_real_
    ),
    #
    MEASUREMENT_VALUE_HARMONIZED = `harmonization_omop::MEASUREMENT_VALUE`,
    MEASUREMENT_UNIT_HARMONIZED = `harmonization_omop::MEASUREMENT_UNIT`,
    CONVERSION_FACTOR = `harmonization_omop::CONVERSION_FACTOR`,
    OMOP_CONCEPT_ID = as.integer(`harmonization_omop::OMOP_ID`),
    omopQuantity = `harmonization_omop::omopQuantity`
  )
#
# Build Summary data
#

summaryTest <- kanta_parquet |>
  group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, IS_EXTRACTED, MEASUREMENT_UNIT_HARMONIZED, omopQuantity, CONVERSION_FACTOR) |>
  summarise(
    n_records = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = 'drop'
  ) |>
  mutate(OMOP_CONCEPT_ID = as.integer(OMOP_CONCEPT_ID)) |>
  filter(n_subjects > nSubjectsMin) |>
  collect()

#check
summaryTest |> count()  |> pull(n)
summaryTest |> distinct(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, IS_EXTRACTED)  |> count() |> pull(n)

summaryValuesSource <- kanta_parquet |>
  filter(!is.na(MEASUREMENT_VALUE_TYPE)) |>
  group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, IS_EXTRACTED, MEASUREMENT_VALUE_TYPE) |>
  summarise(
    n_records = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = "drop"
  ) |>
  collect() |>
  filter(n_subjects > nSubjectsMin)


summaryValues <- kanta_parquet |>
  filter(!is.na(MEASUREMENT_VALUE)) |>
  group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, IS_EXTRACTED) |>
  summarise(
    n_records = n() ,
    n_subjects = n_distinct(FINNGENID),
    # deciles for MEASUREMENT_VALUE (unharmonized)
    decile_1_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.1, na.rm = TRUE),
    decile_2_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.2, na.rm = TRUE),
    decile_3_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.3, na.rm = TRUE),
    decile_4_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.4, na.rm = TRUE),
    decile_5_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.5, na.rm = TRUE),
    decile_6_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.6, na.rm = TRUE),
    decile_7_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.7, na.rm = TRUE),
    decile_8_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.8, na.rm = TRUE),
    decile_9_MEASUREMENT_VALUE = quantile(MEASUREMENT_VALUE, 0.9, na.rm = TRUE),
    # deciles for MEASUREMENT_VALUE_HARMONIZED (harmonized)
    decile_1_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.1, na.rm = TRUE),
    decile_2_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.2, na.rm = TRUE),
    decile_3_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.3, na.rm = TRUE),
    decile_4_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.4, na.rm = TRUE),
    decile_5_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.5, na.rm = TRUE),
    decile_6_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.6, na.rm = TRUE),
    decile_7_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.7, na.rm = TRUE),
    decile_8_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.8, na.rm = TRUE),
    decile_9_MEASUREMENT_VALUE_HARMONIZED = quantile(MEASUREMENT_VALUE_HARMONIZED, 0.9, na.rm = TRUE),
    .groups = 'drop'
  ) |>
  collect() |>
  tidyr::pivot_longer(
    cols = starts_with("decile"),
    names_to = c("decile", "type"),
    names_pattern = "(decile_\\d)_(MEASUREMENT_VALUE(?:_HARMONIZED)?)",
    values_to = "value"
  ) |>
  dplyr::mutate(
    decile = as.numeric(gsub("decile_", "", decile)) / 10,
    type = dplyr::case_when(
      type == "MEASUREMENT_VALUE" ~ "decile_MEASUREMENT_VALUE",
      type == "MEASUREMENT_VALUE_HARMONIZED" ~ "decile_MEASUREMENT_VALUE_HARMONIZED",
      TRUE ~ type
    )
  ) |>
  dplyr::transmute(
    OMOP_CONCEPT_ID,
    TEST_NAME = TEST_NAME,
    MEASUREMENT_UNIT_PREFIX = MEASUREMENT_UNIT_PREFIX,
    MEASUREMENT_UNIT = MEASUREMENT_UNIT,
    IS_EXTRACTED = IS_EXTRACTED,
    type = type,
    value = value,
    n_subjects = floor(n_subjects/10)  |> as.integer(),
    n_records = floor(n_records/10)  |> as.integer(),
    decile = decile
  ) |>
  tidyr::pivot_wider(
    names_from = type,
    values_from = value
  ) |>
  filter(n_subjects > nSubjectsMin)



summaryOutcomes <- kanta_parquet |>
  filter(!is.na(TEST_OUTCOME)) |>
  group_by(OMOP_CONCEPT_ID, TEST_NAME, MEASUREMENT_UNIT_PREFIX, MEASUREMENT_UNIT, IS_EXTRACTED, TEST_OUTCOME) |>
  summarise(
    n_TEST_OUTCOME = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = 'drop'
  ) |>
  collect() |>
  filter(n_subjects > nSubjectsMin)  |>
  arrange(TEST_NAME)


#
# Check data
#
library(validate)


#
#
#
#
#
#
#
# # Checks
# rules <- validator(
#   n.records.is.total.n.values = n_values_missing + n_values_extracted + n_values_source == n_records,
#   n.records.is.total.outcomes = n_outcomes_missing + n_outcomes_inputed + n_outcomes_extracted == n_records
# )
#
# validation_result <- confront(summaryTest, rules)
#
# summary(validation_result)
#
# validation_result
#
# #
# summaryTest |> count(TEST_NAME, MEASUREMENT_UNIT_SOURCE, sort = T) |> filter(n>1)
# summaryTest  |>
#   semi_join(
#     summaryTest |> count(TEST_NAME, MEASUREMENT_UNIT_SOURCE, sort = T) |> filter(n>1),
#     by = c("TEST_NAME", "MEASUREMENT_UNIT_SOURCE")
#   ) |>
#   arrange(TEST_NAME) |>
#   View()
summaryTest |> glimpse()
summaryValuesSource |> glimpse()
summaryValues |> glimpse()
summaryOutcomes |> glimpse()


#
# Save
#
summaryTest |> readr::write_tsv("data/kanta_summary/summaryTest.tsv", na = "")
summaryValuesSource |> readr::write_tsv("data/kanta_summary/summaryValuesSource.tsv", na = "")
summaryValues |> readr::write_tsv("data/kanta_summary/summaryValues.tsv", na = "")
summaryOutcomes |> readr::write_tsv("data/kanta_summary/summaryOutcomes.tsv", na = "")

#
# Read
#

summaryTest |> filter(n_subjects < 5) |> count() |> pull(n) |>expect_equal(0)
summaryValuesSource |> filter(n_subjects < 5)|> count() |> pull(n) |>expect_equal(0)
summaryValues |> filter(n_subjects < 5)|> count() |> pull(n) |>expect_equal(0)
summaryOutcomes |> filter(n_subjects < 5)|> count() |> pull(n) |>expect_equal(0)


#
# Download
#
# gsutil cp kanta_summary.duckdb  gs://fg-production-sandbox-46-red/JAVIER/Kanta/v3/kanta_summary.duckdb
#
# **Table: summaryTest**
#
# Summary for the kanta `TEST_NAME` + `MEASUREMENT_UNIT` pairs
#
# * `OMOP_CONCEPT_ID`: Intege, OMOP concept ID mapped to the `TEST_NAME` + `MEASUREMENT_UNIT` pair
# * `TEST_NAME`: Character,  lab test name
# * `MEASUREMENT_UNIT`: Character, lab test unit
# * `MEASUREMENT_UNIT_HARMONIZED`: Character, lab test unit harmonised unit
# * `omopQuantity`: Character, quantity related to OMOP measurements
# * `CONVERSION_FACTOR`: Character, conversion factors for values to harmonized value
# * `n_records`: Integer, number of records for each `TEST_NAME` + `MEASUREMENT_UNIT` pair
# * `n_subjects`: Integer, number of patients for each `TEST_NAME` + `MEASUREMENT_UNIT` pair (removed if <=5)
# * `n_source_values`: Integer, how many of `n_records` come from a source value (if less than 5 set to 0)
# * `n_extracted_values`: Integer, how many  of `n_records` come from a extracted value (if less than 5 set to 0)
# * `n_outcomes`: Integer, how many of `n_records` have a test ourcome (if less than 5 set to 0)
#
#
# **Table: summaryValues**
#
# Value distributions for the `TEST_NAME` + `MEASUREMENT_UNIT` pairs
#
# * `TEST_NAME`: Character, lab test name
# * `MEASUREMENT_UNIT`: Character, lab test unit
# * `n_subjects`: Integer, number of subjects (removed if <=5)
# * `n_records`: Integer, number of records
# * `decile`: Numeric, decile value
# * `decile_MEASUREMENT_VALUE`: Numeric, decile of measurement value
# * `decile_MEASUREMENT_VALUE_HARMONIZED`: Numeric, decile of harmonized measurement value
#
#
# **Table: summaryOutcomes**
#
# Outcome distributions for the `TEST_NAME` + `MEASUREMENT_UNIT` pairs
#
# * `TEST_NAME`: Character, lab test name
# * `MEASUREMENT_UNIT`: Character, lab test unit
# * `TEST_OUTCOME`: Character, test outcome
# * `n_TEST_OUTCOME`: Integer, number of test outcomes
# * `n_subjects`: Integer, number of subjects (removed if <=5)
# * `n_records`: Integer, number of records


kanta_parquet |> filter(TEST_NAME=="b-erytrosyytit,tilavuusosuus", MEASUREMENT_UNIT_PREFIX=="osuus") |> head() |> collect()  |> View()







