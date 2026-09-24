#
# Summarises codesWithLoincDimensions.tsv: how completely the LLM could fill
# each LOINC axis, what the most-used value of each axis is, and — by sending
# reflections.md back to the model — what the recurring findings and suggested
# improvements are across all groups.
#
# The findings section is a second, much cheaper LLM call than the per-group
# inference: one call over the concatenated reflections, not one per group.
# It degrades gracefully — if the call fails, the stats sections are still
# written and the findings section says so.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
dimensionsFile <- args[1]
reflectionsFile <- args[2]
outDir <- args[3]

scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
if (is.na(scriptDir) || !nzchar(scriptDir)) scriptDir <- "."
rDir <- file.path(scriptDir, "R")
ellmerFixFile <- file.path(rDir, "ellmerFix.R")

source(file.path(rDir, "clientFactory.R"))

llmConfig <- list(
  provider = Sys.getenv("LLM_PROVIDER", "google_vertex"),
  model = Sys.getenv("LLM_MODEL", "gemini-2.5-pro"),
  project = Sys.getenv("GOOGLE_CLOUD_PROJECT"),
  location = Sys.getenv("GOOGLE_CLOUD_LOCATION"),
  credentials = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS")
)

# The 6 LOINC axes plus is_panel, in the order they are reported.
dimensionColumns <- c(
  "has_component", "has_property", "has_time_aspect",
  "has_system", "has_scale_type", "has_method"
)

dimensionDescriptions <- c(
  has_component = "The analyte/substance measured — the core identity of the test.",
  has_property = "The kind of quantity reported (`MCnc` mass concentration, `SCnc` substance concentration, `PrThr` presence or threshold, ...), independent of the unit.",
  has_time_aspect = "The timing of the collection (`Pt` for a spot sample, `24H` for a 24-hour collection, ...).",
  has_system = "The specimen or body system the sample was taken from (`Ser`, `Plas`, `Bld`, `Urine`, `CSF`, ...).",
  has_scale_type = "The measurement scale of the result (`Qn` quantitative, `Ord` ordinal, `Nom` nominal, `Nar` narrative, `Doc` document).",
  has_method = "The analytical method, populated only when the code indicates one that changes clinical interpretation. Mostly empty by design.",
  is_panel = "Whether the code bundles several separately reported component tests rather than being one reportable result."
)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  dimensionsFile = ", dimensionsFile)
ParallelLogger::logInfo("  reflectionsFile = ", reflectionsFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  provider = ", llmConfig$provider)
ParallelLogger::logInfo("  model = ", llmConfig$model)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: this file was written by this project, so
# "" is its missing-value marker. An axis the model left blank reads as NA here.
dimensions <- readr::read_tsv(
  dimensionsFile,
  na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(dimensions), " rows from ", dimensionsFile)

reflectionsText <- if (file.exists(reflectionsFile)) {
  paste(readLines(reflectionsFile, warn = FALSE), collapse = "\n")
} else {
  ""
}
ParallelLogger::logInfo("Read ", nchar(reflectionsText), " characters of reflections from ", reflectionsFile)

#
# --- Action -------------------------------------------------------------
#
nRows <- nrow(dimensions)
nGroups <- dplyr::n_distinct(dimensions$group_id)

.formatPct <- function(x) sprintf("%.1f%%", 100 * x)

# escape markdown table-breaking characters in a value for display
.escapeForMarkdown <- function(x) {
  x |>
    gsub("\\|", "\\\\|", x = _) |>
    gsub("\\r?\\n", " ", x = _)
}

.markdownTable <- function(df) {
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

# Completeness of every axis: how many rows the model could fill.
reportedColumns <- c(dimensionColumns, "is_panel")
completeness <- tibble::tibble(dimension = reportedColumns) |>
  dplyr::mutate(
    n_filled = purrr::map_int(dimension, ~ sum(!is.na(dimensions[[.x]]))),
    pct_filled = .formatPct(n_filled / nRows),
    n_empty = nRows - n_filled,
    pct_empty = .formatPct(n_empty / nRows),
    n_unique = purrr::map_int(dimension, ~ dplyr::n_distinct(dimensions[[.x]], na.rm = TRUE))
  )
ParallelLogger::logInfo("Computed completeness for ", nrow(completeness), " dimensions")

# How many of the 6 core axes each row got, as a distribution.
nAxesFilled <- rowSums(!is.na(dimensions[dimensionColumns]))
axesPerRow <- tibble::tibble(n_axes = seq(0, length(dimensionColumns))) |>
  dplyr::mutate(
    n_rows = purrr::map_int(n_axes, ~ sum(nAxesFilled == .x)),
    pct_rows = .formatPct(n_rows / nRows)
  )

.top10Table <- function(column, n = 10) {
  filled <- dimensions[[column]][!is.na(dimensions[[column]])]
  if (length(filled) == 0) return(NULL)
  tibble::tibble(value = filled) |>
    dplyr::count(value, name = "n", sort = TRUE) |>
    dplyr::slice_head(n = n) |>
    dplyr::transmute(
      value = .escapeForMarkdown(value),
      n = n,
      pct_of_filled = .formatPct(n / length(filled))
    )
}

# Findings: send the per-group reflections back to the model and ask it to
# distil the recurring themes across all of them.
findingsType <- ellmer::type_object(
  key_findings = ellmer::type_array(
    ellmer::type_string("One recurring finding about the data or the mapping task."),
    "The main recurring themes across the group reflections."
  ),
  improvements = ellmer::type_array(
    ellmer::type_string("One concrete, actionable improvement to the process."),
    "Concrete suggested improvements to the inference process."
  ),
  data_problems = ellmer::type_array(
    ellmer::type_string("One systematic problem in the source data."),
    "Systematic problems in the source lab-code data."
  )
)

findingsPrompt <- paste0(
  "Below are the per-group reflections written by a LOINC mapping expert while inferring ",
  "LOINC axes for Finnish local lab codes. Each group was processed independently, so the ",
  "same issue may be described many times in different words.\n\n",
  "Distil them into: the recurring KEY FINDINGS about the task and data, concrete ",
  "IMPROVEMENTS to the process, and systematic DATA PROBLEMS in the source lab codes.\n\n",
  "Merge duplicates across groups into one entry and order each list by how often or how ",
  "strongly the reflections raise it. Be specific and actionable; do not invent anything ",
  "that is not supported by the reflections.\n\n",
  "--- REFLECTIONS ---\n\n",
  reflectionsText
)

findings <- NULL
if (nzchar(trimws(reflectionsText))) {
  if (nzchar(ellmerFixFile) && file.exists(ellmerFixFile)) source(ellmerFixFile, local = TRUE)
  maxAttempts <- 3L
  for (attempt in seq_len(maxAttempts)) {
    findings <- tryCatch({
      client <- makeClientFactory(llmConfig)()
      client$chat_structured(findingsPrompt, echo = "none", type = findingsType)
    }, error = function(e) {
      ParallelLogger::logWarn("Findings attempt ", attempt, "/", maxAttempts, " failed: ", conditionMessage(e))
      NULL
    })
    if (!is.null(findings)) break
    if (attempt < maxAttempts) Sys.sleep(stats::runif(1, 0.5, 2.5) * attempt)
  }
  if (is.null(findings)) {
    ParallelLogger::logError("Could not summarise the reflections after ", maxAttempts, " attempts")
  } else {
    ParallelLogger::logInfo("Summarised reflections into ",
                            length(findings$key_findings), " findings, ",
                            length(findings$improvements), " improvements, ",
                            length(findings$data_problems), " data problems")
  }
} else {
  ParallelLogger::logWarn("No reflections to summarise at ", reflectionsFile)
}

#
# --- Output -------------------------------------------------------------
#
md <- c(
  "# LOINC Dimensions -- Stats",
  "",
  paste0("Source: `", dimensionsFile, "`"),
  "",
  paste0("Rows (local `TEST_NAME`/`UNIT` combinations): ", nRows),
  paste0("Similarity groups covered: ", nGroups),
  "",
  "## Dimension completeness",
  "",
  "How many rows the model could fill for each axis. An empty value means the",
  "model judged the axis not determinable from that row — the prompt asks it to",
  "leave an axis empty rather than guess, so empties are expected, not failures.",
  "",
  .markdownTable(completeness),
  "",
  "**Core axes filled per row** (of the 6 LOINC axes, excluding `is_panel`):",
  "",
  .markdownTable(axesPerRow),
  ""
)

for (col in reportedColumns) {
  top10 <- .top10Table(col)
  nFilled <- sum(!is.na(dimensions[[col]]))
  md <- c(
    md,
    paste0("## `", col, "`"),
    "",
    dimensionDescriptions[[col]],
    "",
    paste0("- Filled: ", nFilled, " / ", nRows, " (", .formatPct(nFilled / nRows), ")"),
    paste0("- Unique values: ", dplyr::n_distinct(dimensions[[col]], na.rm = TRUE)),
    ""
  )
  if (is.null(top10)) {
    md <- c(md, "No values were assigned for this dimension.", "")
  } else {
    md <- c(
      md,
      paste0("**Top ", nrow(top10), " most used values:**"),
      "",
      .markdownTable(top10),
      ""
    )
  }
}

md <- c(
  md,
  "## Findings",
  "",
  paste0("Distilled by `", llmConfig$model, "` from the per-group reflections in `",
         reflectionsFile, "`."),
  ""
)

if (is.null(findings)) {
  md <- c(
    md,
    "_The reflections could not be summarised on this run (no reflections, or the",
    "model call failed — see `log.txt`). The per-group reflections themselves are",
    paste0("in `", reflectionsFile, "`.)_"),
    ""
  )
} else {
  renderList <- function(title, items) {
    if (length(items) == 0) return(c(paste0("### ", title), "", "_(none reported)_", ""))
    c(paste0("### ", title), "", paste0("- ", unlist(items)), "")
  }
  md <- c(
    md,
    renderList("Key findings", findings$key_findings),
    renderList("Suggested improvements", findings$improvements),
    renderList("Systematic data problems", findings$data_problems)
  )
}

outFile <- file.path(outDir, "loincDimensionsStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
