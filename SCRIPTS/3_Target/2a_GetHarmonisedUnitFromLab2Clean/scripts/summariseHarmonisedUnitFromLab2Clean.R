#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
harmonisedUnitFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  harmonisedUnitFile = ", harmonisedUnitFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
harmonisedUnit <- readr::read_tsv(harmonisedUnitFile, col_types = readr::cols(.default = readr::col_character()), na = "")
ParallelLogger::logInfo("Read ", nrow(harmonisedUnit), " rows from ", harmonisedUnitFile)

#
# --- Action -------------------------------------------------------------
#
nConcepts <- nrow(harmonisedUnit)

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

unitTable <- harmonisedUnit |>
  dplyr::count(.data$harmonised_unit, sort = TRUE) |>
  dplyr::transmute(
    harmonised_unit,
    `n concepts` = fmtInt(n),
    `% concepts` = fmtPct(100 * n / nConcepts)
  ) |>
  dplyr::bind_rows(
    tibble::tibble(harmonised_unit = "total", `n concepts` = fmtInt(nConcepts), `% concepts` = "100%")
  )

md <- c(
  "# harmonisedUnit_lab2clean stats",
  "",
  paste0(
    "Summary of `harmonisedUnit_lab2clean.tsv`: ", fmtInt(nConcepts),
    " standard `Measurement` concepts with a lab2clean unit, every one in an SI unit (a conventional code takes the unit of its SI partner)."
  ),
  "",
  "# harmonised_unit",
  "",
  mdTable(unitTable)
)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "harmonisedUnit_lab2clean.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote ", outFile)
