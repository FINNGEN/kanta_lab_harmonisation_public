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
# gsutil cp gs://fg-production-sandbox-46-red/kanta/v3/2026_02_12/kanta_dev_2026_02_12.txt.gz ~/Documents/Rprojects/LabVa...
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

kanta_parquet_source  <- open_dataset("data/kanta_dev_2026_08_24_RELEASE.parquet")
if(dev==TRUE){
  kanta_parquet_source  <- kanta_parquet_source |> head(10^6)
}

kanta_parquet_source |> glimpse()

kanta_parquet  <- kanta_parquet_source |>
  transmute(
    FINNGENID = FINNGENID,
    TEST_NAME = TEST_NAME,
    MEASUREMENT_UNIT = MEASUREMENT_UNIT_CLEANED,
    MEASUREMENT_VALUE = MEASUREMENT_VALUE_CLEANED,
    TEST_OUTCOME = TEST_OUTCOME,
    #
    unit_source = case_when(
      is.na(MEASUREMENT_UNIT) ~ NA_character_,
      MEASUREMENT_UNIT != MEASUREMENT_UNIT_POST_INJ ~ "SecondaryCorrection",
      MEASUREMENT_UNIT_POST_INJ != MEASUREMENT_UNIT_PRE_INJ ~ "PrimaryInjection",
      IS_UNIT_EXTRACTED == TRUE ~ "PrimaryInjection",
      TRUE ~ "Source"
    ),
    value_source = case_when(
      is.na(MEASUREMENT_VALUE) ~ NA_character_,
      QC_PASS ==  0L ~ "QCOut",
      IS_VALUE_EXTRACTED == TRUE ~ "Extracted",
      TRUE ~ "Source"
    )
  )

kanta_parquet |> glimpse()
#
# Build Summary data
#

# SummaryTestUnit
summaryTest <- kanta_parquet |>
  group_by(TEST_NAME, MEASUREMENT_UNIT) |>
  summarise(
    n_records = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = 'drop'
  ) |>
  filter(n_subjects > nSubjectsMin) |>
  collect()

#check
summaryTest |> count()  |> pull(n_records)
summaryTest |> distinct(TEST_NAME_ABBREVIATION, MEASUREMENT_UNIT)  |> count() |> pull(n_records)


# SummaryUnitSource
summaryUnitSource <- kanta_parquet |>
  filter(!is.na(unit_source))  |>
  group_by(TEST_NAME, MEASUREMENT_UNIT, unit_source) |>
  summarise(
    n_records = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = "drop"
  ) |>
  collect() |>
  filter(n_subjects > nSubjectsMin)


# SummaryValuesSource
summaryValuesSource <- kanta_parquet |>
  filter(!is.na(value_source))  |>
  group_by(TEST_NAME, MEASUREMENT_UNIT, value_source) |>
  summarise(
    n_records = n(),
    n_subjects = n_distinct(FINNGENID),
    .groups = "drop"
  ) |>
  collect() |>
  filter(n_subjects > nSubjectsMin)


summaryValues <- kanta_parquet |>
  filter(!is.na(MEASUREMENT_VALUE)) |>
  group_by(TEST_NAME, MEASUREMENT_UNIT) |>
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
      TRUE ~ type
    )
  ) |>
  dplyr::transmute(
    TEST_NAME = TEST_NAME,
    MEASUREMENT_UNIT = MEASUREMENT_UNIT,
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
  group_by(TEST_NAME, MEASUREMENT_UNIT, TEST_OUTCOME ) |>
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
summaryUnitSource |> glimpse()
summaryValuesSource |> glimpse()
summaryValues   |> glimpse()
summaryOutcomes |> glimpse()


#
# Save
#
summaryTest |> readr::write_tsv("data/kanta_summary/summaryTest.tsv", na = "")
summaryUnitSource |> readr::write_tsv("data/kanta_summary/summaryUnitSource.tsv", na = "")
summaryValuesSource |> readr::write_tsv("data/kanta_summary/summaryValuesSource.tsv", na = "")
summaryValues |> readr::write_tsv("data/kanta_summary/summaryValues.tsv", na = "")
summaryOutcomes |> readr::write_tsv("data/kanta_summary/summaryOutcomes.tsv", na = "")

#
# Read
#

summaryTest |> filter(n_subjects < 5) |> count() |> pull(n) |>expect_equal(0)
summaryValuesSource|> filter(n_subjects < 5) |> count() |> pull(n) |>expect_equal(0)
summaryUnitSource |> filter(n_subjects < 5)|> count() |> pull(n) |>expect_equal(0)
summaryValues |> filter(n_subjects < 5) |> count() |> pull(n) |>expect_equal(0)
summaryOutcomes |> filter(n_subjects < 5)|> count() |> pull(n) |>expect_equal(0)


#
# Download
#
# gsutil cp kanta_summary.duckdb  gs://fg-production-sandbox-46-red/JAVIER/Kanta/v4/kanta_summary.duckdb
#
