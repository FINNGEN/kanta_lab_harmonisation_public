#
# make_test_unit_counts_table.R
#
# Reads CODE_COUNTS/test_unit_counts.txt (one row per local test NAME + UNIT
# combination, with COUNT records and %MISSING) and writes an interactive
# HTML reactable table, rows grouped by NAME so each test's unit variants
# collapse into one expandable group.
#
# Run from the repo root:
#   Rscript EXPERIMENTS/input_data/make_test_unit_counts_table.R
#

#
# --- Libraries --------------------------------------------------------------
#
library(dplyr)
library(readr)
library(reactable)
library(htmltools)

#
# --- Configuration -----------------------------------------------------------
#
pathToInputTXT  <- "CODE_COUNTS/test_unit_counts.txt"
pathToOutputHTML <- "EXPERIMENTS/input_data/output/test_unit_counts_table.html"

#
# --- Read data ----------------------------------------------------------------
#
# na = character(0): keep literal "NA" unit values as visible text ("no unit
# recorded" for that test) instead of collapsing them into an empty cell.
data <- readr::read_tsv(
    pathToInputTXT,
    col_types = readr::cols(
        NAME = readr::col_character(),
        UNIT = readr::col_character(),
        COUNT = readr::col_double(),
        `%MISSING` = readr::col_double()
    ),
    na = character(0)
) |>
    dplyr::rename(PCT_MISSING = `%MISSING`) |>
    dplyr::arrange(NAME, dplyr::desc(COUNT))

#
# --- Table ----------------------------------------------------------------------
#
# Weighted-average %missing for a group: rows with more COUNT contribute more
# to the group's %MISSING than rows with few records.
weightedPctMissingJS <- reactable::JS("
function(values, rows) {
    var totalCount = 0, weightedSum = 0
    rows.forEach(function(row, i) {
        totalCount += row['COUNT']
        weightedSum += row['COUNT'] * values[i]
    })
    return totalCount === 0 ? 0 : weightedSum / totalCount
}
")

table <- reactable::reactable(
    data,
    groupBy = "NAME",
    searchable = TRUE,
    bordered = TRUE,
    striped = TRUE,
    highlight = TRUE,
    resizable = TRUE,
    defaultPageSize = 25,
    showPageSizeOptions = TRUE,
    pageSizeOptions = c(10, 25, 50, 100, 500),
    defaultSorted = list(COUNT = "desc"),
    columns = list(
        NAME = reactable::colDef(
            name = "Name",
            minWidth = 220
        ),
        UNIT = reactable::colDef(
            name = "Unit",
            aggregate = "unique"
        ),
        COUNT = reactable::colDef(
            name = "Count",
            aggregate = "sum",
            format = reactable::colFormat(separators = TRUE),
            align = "right"
        ),
        PCT_MISSING = reactable::colDef(
            name = "% Missing",
            aggregate = weightedPctMissingJS,
            format = reactable::colFormat(suffix = "%", digits = 2),
            align = "right"
        )
    )
)

page <- htmltools::browsable(
    htmltools::tagList(
        htmltools::tags$h2("Test / unit counts"),
        htmltools::tags$p(
            "Source: ", htmltools::tags$code(pathToInputTXT),
            ". Rows grouped by test name; expand a group to see its unit variants. ",
            dplyr::n_distinct(data$NAME), " test names, ", nrow(data), " name/unit combinations."
        ),
        table
    )
)

htmltools::save_html(page, pathToOutputHTML)
message("Wrote ", dplyr::n_distinct(data$NAME), " test names (", nrow(data), " rows) to: ", pathToOutputHTML)
