#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
measurementFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  measurementFile = ", measurementFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
measurement <- readr::read_tsv(
  measurementFile,
  col_types = readr::cols(.default = readr::col_character()),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(measurement), " rows from ", measurementFile)

#
# --- Action -------------------------------------------------------------
#
nConcepts <- nrow(measurement)

fmtInt <- function(x) format(x, big.mark = ",", scientific = FALSE, trim = TRUE)
fmtPct <- function(x) sprintf("%.1f%%", x)

mdRow <- function(cells) paste0("| ", paste(cells, collapse = " | "), " |")
mdTable <- function(df) {
  c(
    mdRow(names(df)),
    mdRow(rep("---", ncol(df))),
    vapply(seq_len(nrow(df)), function(i) mdRow(unlist(df[i, ])), character(1))
  )
}

# One row per value of a column, most frequent first, then a total row. A missing
# value is reported as "(none)".
countTable <- function(column) {
  measurement |>
    dplyr::mutate(value = dplyr::coalesce(.data[[column]], "(none)")) |>
    dplyr::count(value, sort = TRUE) |>
    dplyr::transmute(
      !!column := value,
      `n concepts` = fmtInt(n),
      `% concepts` = fmtPct(100 * n / nConcepts)
    ) |>
    dplyr::bind_rows(
      tibble::tibble(!!column := "total", `n concepts` = fmtInt(nConcepts), `% concepts` = "100%")
    )
}

md <- c(
  "# measurementOmopData stats",
  "",
  paste0(
    "Summary of `measurementOmopData.tsv`: ", fmtInt(nConcepts),
    " standard `Measurement` concepts, one row per concept."
  ),
  "",
  "# vocabulary_id",
  "",
  mdTable(countTable("vocabulary_id")),
  "",
  "# is_panel",
  "",
  "A panel is a concept with a `Panel contains` relationship.",
  "",
  mdTable(countTable("is_panel")),
  "",
  "# has_property",
  "",
  "The kind of quantity reported; `(none)` is a concept with no `Has property` relationship.",
  "",
  mdTable(countTable("has_property"))
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "measurementOmopData.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
