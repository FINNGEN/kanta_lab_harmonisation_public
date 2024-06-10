# read summary data
summary_data <- read_tsv('INPUT_SUMMARY_DATA/formatingTables/synthetic_data_summary.txt')


clean_units <- function(unit){
  unit  |>
    tolower() |>
    str_replace_all(" ", "") |>
    str_replace_all("\\.", "") |>
    str_replace_all(",", "") |>
    str_replace_all("_", "")  |>
    str_replace_all("10e", "e")|>
    str_replace_all("µ", "u")
}

# tmp
summary_data_formated  <- summary_data |>
  rename(
    TEST_NAME_ABBREVIATION = ABBR,
    source_unit_clean = UNIT,
    n_records = TOT_COUNT
  ) |>
  nest(data=c(DECILE,VALUE)) |>
  mutate(
    data = map_chr(data, ~ {
      a <- .x |>
        arrange(DECILE) |>
        pull(VALUE) |>
        paste0(collapse = ', ')
      paste0('[ ', a, ', _ ]')
    }
    )
  ) |>
  transmute(
    TEST_NAME_ABBREVIATION,
    source_unit_clean = clean_units(source_unit_clean),
    n_records,
    value_percentiles = data
  )


summary_data_formated  |> write_tsv('INPUT_SUMMARY_DATA/synthetic_summary_data.tsv')
