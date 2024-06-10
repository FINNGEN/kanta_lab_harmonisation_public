


value_percentiles_to_tibble <- function(value_percentile_text) {
  if (is.na(value_percentile_text))   return(NULL)
  values <- value_percentile_text |> str_remove_all(' ')  |> str_replace_all('\\[|\\]', '') |> str_split(',')  |> unlist()
  values <- suppressWarnings(as.numeric(values))
  if (length(values) != 11)  stop('The input must have 11 values')
  percentiles  <- seq(0,1,0.1)
  tibble(value = values, percentile = percentiles) |>
    filter(!is.na(value)) |>
    distinct(value, .keep_all = TRUE) |>
    arrange(value)
}


# value_percentiles_to_tibble('[ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 ]')
# value_percentiles_to_tibble('[ _, 2, 3, 4, 5, 6, _, 8, 9, 10, 11 ]')
# value_percentiles_to_tibble('[ _, _, _, _, _, _, _, _, _, _, _ ]')
# value_percentiles_to_tibble('[ _, 1 ]')
