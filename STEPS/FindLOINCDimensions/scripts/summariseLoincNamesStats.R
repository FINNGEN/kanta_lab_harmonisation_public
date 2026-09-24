#
# Summarises codesWithLoincNames.tsv: how often the LLM could name a code at
# all, how closely its guesses follow the LOINC Long Common Name template,
# which names it reaches for most, and -- by sending reflections.md back to the
# model -- what the recurring findings and suggested improvements are across
# all groups.
#
# The template conformance section is the one that matters for the next step:
# the guess is used as a semantic-search query, and a guess shaped like a real
# LOINC name retrieves the right concept far more reliably than a free-text
# description of the test. A falling "parses as the template" number is an
# early warning that the prompt has stopped steering the model.
#
# The findings section is a second, much cheaper LLM call than the per-group
# inference: one call over the concatenated reflections, not one per group.
# It degrades gracefully -- if the call fails, the stats sections are still
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
namesFile <- args[1]
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

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  namesFile = ", namesFile)
ParallelLogger::logInfo("  reflectionsFile = ", reflectionsFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  provider = ", llmConfig$provider)
ParallelLogger::logInfo("  model = ", llmConfig$model)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: this file was written by this project, so
# "" is its missing-value marker. A name the model left blank reads as NA here.
codes <- readr::read_tsv(
  namesFile,
  na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", namesFile)

reflectionsText <- if (file.exists(reflectionsFile)) {
  paste(readLines(reflectionsFile, warn = FALSE), collapse = "\n")
} else {
  ""
}
ParallelLogger::logInfo("Read ", nchar(reflectionsText), " characters of reflections from ", reflectionsFile)

#
# --- Action -------------------------------------------------------------
#
nRows <- nrow(codes)
nGroups <- dplyr::n_distinct(codes$group_id)

.formatPct <- function(x) sprintf("%.1f%%", 100 * x)

# escape markdown table-breaking characters in a value for display
.escapeForMarkdown <- function(x) {
  x |>
    gsub("|", "\\|", x = _, fixed = TRUE) |>
    gsub("\r?\n", " ", x = _)
}

.markdownTable <- function(df) {
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

guesses <- codes$loinc_name_guess
named <- !is.na(guesses)
nNamed <- sum(named)

overview <- tibble::tibble(
  bucket = c("total rows", "named", "left empty (not determinable)",
             "flagged as a panel", "distinct names guessed"),
  n = c(nRows, nNamed, nRows - nNamed,
        sum(codes$is_panel == "TRUE", na.rm = TRUE),
        dplyr::n_distinct(guesses[named]))
) |>
  dplyr::mutate(pct = ifelse(bucket == "distinct names guessed", "", .formatPct(n / nRows)))

# Which parts of the LOINC template each guess carries. The template is
#     <Component> [<Property>] in <System> by <Method>
# and everything after the component is optional in a real LOINC name too, so
# this is a shape profile, not a pass/fail test.
parts <- stringr::str_match(
  guesses,
  "^(?<component>.+?)(?: \\[(?<property>[^\\]]+)\\])?(?: in (?<system>[^\\[]+?))?(?: by (?<method>.+?))?$"
)
hasProperty <- named & !is.na(parts[, "property"])
hasSystem <- named & !is.na(parts[, "system"])
hasMethod <- named & !is.na(parts[, "method"])
isPanelName <- named & grepl(" panel", guesses, fixed = TRUE)

shape <- tibble::tibble(
  part = c("carries a [Property]", "carries an `in <System>`",
           "carries a `by <Method>`", "is a panel name (contains ' panel')",
           "full `C [P] in S` shape"),
  n = c(sum(hasProperty), sum(hasSystem), sum(hasMethod), sum(isPanelName),
        sum(hasProperty & hasSystem))
) |>
  dplyr::mutate(pct_of_named = .formatPct(n / max(nNamed, 1)))

ParallelLogger::logInfo(nNamed, " / ", nRows, " rows named; ",
                        sum(hasProperty & hasSystem), " carry the full '<Component> [<Property>] in <System>' shape")

.topTable <- function(values, label, n = 20) {
  values <- values[!is.na(values)]
  if (length(values) == 0) return(NULL)
  tibble::tibble(value = values) |>
    dplyr::count(value, name = "n", sort = TRUE) |>
    dplyr::slice_head(n = n) |>
    dplyr::transmute(
      "{label}" := .escapeForMarkdown(value),
      n = n,
      pct = .formatPct(n / length(values))
    )
}

topNames <- .topTable(guesses, "guessed LOINC name")
topProperties <- .topTable(parts[, "property"], "[property]", n = 15)
topSystems <- .topTable(parts[, "system"], "in <system>", n = 15)
topMethods <- .topTable(parts[, "method"], "by <method>", n = 15)

# Findings: send the per-group reflections back to the model and ask it to
# distil the recurring themes across all of them.
findingsType <- ellmer::type_object(
  key_findings = ellmer::type_array(
    ellmer::type_string("One recurring finding about the data or the naming task."),
    "The main recurring themes across the group reflections."
  ),
  improvements = ellmer::type_array(
    ellmer::type_string("One concrete, actionable improvement to the process."),
    "Concrete suggested improvements to the naming process."
  ),
  data_problems = ellmer::type_array(
    ellmer::type_string("One systematic problem in the source data."),
    "Systematic problems in the source lab-code data."
  )
)

findingsPrompt <- paste0(
  "Below are the per-group reflections written by a LOINC mapping expert while guessing the ",
  "LOINC Long Common Name of Finnish local lab codes. Each group was processed independently, ",
  "so the same issue may be described many times in different words.\n\n",
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
  "# LOINC Name Guesses -- Stats",
  "",
  paste0("Source: `", namesFile, "`"),
  "",
  paste0("Rows (local `TEST_NAME`/`UNIT` combinations): ", nRows),
  paste0("Similarity groups covered: ", nGroups),
  "",
  "## Overview",
  "",
  "An empty name means the model judged the code not identifiable from its row —",
  "the prompt asks it to leave the name empty rather than invent one, so empties",
  "are expected, not failures.",
  "",
  .markdownTable(overview),
  "",
  "## Name shape",
  "",
  "The guess is a **search query** for the next step, so what matters is whether it",
  "is shaped like a real LOINC Long Common Name:",
  "",
  "```",
  "<Component> [<Property>] in <System> by <Method>",
  "```",
  "",
  "Everything after the component is optional in real LOINC names too (most",
  "chemistry carries no Method; nominal and fraction terms carry no `[Property]`),",
  "so this is a shape profile, not a pass/fail test. A sharp drop in",
  "`carries a [Property]` or `carries an in <System>` means the model has started",
  "describing tests instead of naming them, and retrieval will suffer.",
  "",
  .markdownTable(shape),
  ""
)

renderTop <- function(title, note, tbl) {
  if (is.null(tbl)) return(c(paste0("## ", title), "", "_(none)_", ""))
  c(paste0("## ", title), "", note, "", .markdownTable(tbl), "")
}

md <- c(
  md,
  renderTop(
    "Most frequently guessed names",
    "A name guessed for many rows is usually right — the same test recurs under many local spellings — but a very high count can also mean the model fell back on a generic name for codes it could not tell apart.",
    topNames
  ),
  renderTop(
    "`[Property]` used",
    "Which LOINC property display forms the guesses carry. These should be LOINC's own bracket spellings (`[Moles/volume]`, `[Mass/volume]`), not OMOP attribute names (`Substance Concentration`).",
    topProperties
  ),
  renderTop(
    "`in <System>` used",
    "Which specimens the guesses name.",
    topSystems
  ),
  renderTop(
    "`by <Method>` used",
    "Which methods the guesses name. LOINC omits Method for most chemistry, so a long tail here means the model is inventing methods the codes do not state — which makes the search miss the plain term.",
    topMethods
  )
)

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

outFile <- file.path(outDir, "loincNamesStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
