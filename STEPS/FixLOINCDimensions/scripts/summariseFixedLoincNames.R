#
# Summarises codesWithOmopConcepts.tsv: how many guessed names became real OMOP
# concept ids, what kind of concepts were chosen, and -- by sending
# reflections.md back to the model -- what the recurring findings and suggested
# improvements are across all groups.
#
# The numbers that matter here are about the *route*, not the hit rate: how
# often the search even offered a candidate, and how often the model took one
# that is on the LOINC recommended list or already used in Finland. Whether the
# chosen concept is the RIGHT one is not knowable from this table -- that is
# what MapLOINCToOmop's cross-check against the curated reference mapping is
# for.
#
# The findings section is a second, much cheaper LLM call than the per-group
# mapping: one call over the concatenated reflections, not one per group.
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
mappedFile <- args[1]
candidatesFile <- args[2]
frequencyFile <- args[3]
top2000File <- args[4]
reflectionsFile <- args[5]
outDir <- args[6]

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
ParallelLogger::logInfo("  mappedFile = ", mappedFile)
ParallelLogger::logInfo("  candidatesFile = ", candidatesFile)
ParallelLogger::logInfo("  frequencyFile = ", frequencyFile)
ParallelLogger::logInfo("  top2000File = ", top2000File)
ParallelLogger::logInfo("  reflectionsFile = ", reflectionsFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: every one of these was written by this
# project, so "" is their missing-value marker.
codes <- readr::read_tsv(mappedFile, na = "", col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", mappedFile)

candidates <- readr::read_tsv(candidatesFile, na = "", col_types = readr::cols(
  value = readr::col_character(), concept_name = readr::col_character(),
  concept_id = readr::col_character(), concept_code = readr::col_character(),
  score = readr::col_double()
))
ParallelLogger::logInfo("Read ", nrow(candidates), " cached Hecate candidates from ", candidatesFile)

frequency <- readr::read_tsv(frequencyFile, na = "", col_types = readr::cols(
  concept_id = readr::col_character(), concept_name = readr::col_character(),
  vocabulary_id = readr::col_character(),
  n_codes = readr::col_double(), n_events = readr::col_double()
))

top2000 <- readr::read_tsv(top2000File, na = "", col_types = readr::cols(
  rank = readr::col_integer(), loinc_code = readr::col_character(),
  concept_id = readr::col_character(), omop_concept_name = readr::col_character(),
  loinc_long_common_name = readr::col_character(), loinc_class = readr::col_character()
))

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

wasNamed <- !is.na(codes$loinc_name_guess)
wasMapped <- !is.na(codes$omop_concept_id)

overview <- tibble::tibble(
  bucket = c("total rows",
             "named by FindLOINCDimensions",
             "mapped to an OMOP concept",
             "named but left unmapped",
             "unnamed and unmapped",
             "unnamed but still mapped",
             "distinct concepts chosen"),
  n = c(nRows, sum(wasNamed), sum(wasMapped),
        sum(wasNamed & !wasMapped), sum(!wasNamed & !wasMapped), sum(!wasNamed & wasMapped),
        dplyr::n_distinct(codes$omop_concept_id[wasMapped]))
) |>
  dplyr::mutate(pct = ifelse(bucket == "distinct concepts chosen", "", .formatPct(n / nRows)))

ParallelLogger::logInfo(sum(wasMapped), " / ", nRows, " rows mapped (",
                        sum(wasNamed & !wasMapped), " named rows found no acceptable candidate)")

# Did the search even offer anything for the names the model guessed? A guess
# with no candidate can never be mapped, so this separates "the search failed"
# from "the model rejected what the search found".
guessed <- unique(codes$loinc_name_guess[wasNamed])
withHits <- candidates |>
  dplyr::filter(.data$value %in% guessed, !is.na(.data$concept_id)) |>
  dplyr::group_by(value) |>
  dplyr::summarise(n_hits = dplyr::n(), best_score = max(.data$score, na.rm = TRUE), .groups = "drop")

search <- tibble::tibble(
  bucket = c("distinct names guessed",
             "returned at least one concept",
             "returned nothing",
             "best hit scored >= 0.90",
             "best hit scored 0.75 - 0.90",
             "best hit scored < 0.75"),
  n = c(length(guessed),
        nrow(withHits),
        length(guessed) - nrow(withHits),
        sum(withHits$best_score >= 0.90),
        sum(withHits$best_score >= 0.75 & withHits$best_score < 0.90),
        sum(withHits$best_score < 0.75))
) |>
  dplyr::mutate(pct = .formatPct(n / max(length(guessed), 1)))

# What kind of concept was chosen: on the recommended list, already used in
# Finland, or neither.
chosen <- codes$omop_concept_id[wasMapped]
top2000Ids <- unique(top2000$concept_id[!is.na(top2000$concept_id)])
usedIds <- unique(frequency$concept_id)

provenance <- tibble::tibble(
  bucket = c("mapped rows",
             "chose a LOINC Top 2000 concept",
             "chose a concept already used in Finnish mappings",
             "chose one that is both",
             "chose one that is neither"),
  n = c(length(chosen),
        sum(chosen %in% top2000Ids),
        sum(chosen %in% usedIds),
        sum(chosen %in% top2000Ids & chosen %in% usedIds),
        sum(!(chosen %in% top2000Ids) & !(chosen %in% usedIds)))
) |>
  dplyr::mutate(pct = .formatPct(n / max(length(chosen), 1)))

topConcepts <- if (length(chosen) == 0) NULL else {
  codes |>
    dplyr::filter(wasMapped) |>
    dplyr::count(omop_concept_id, omop_concept_name, name = "n_rows", sort = TRUE) |>
    dplyr::slice_head(n = 20) |>
    dplyr::transmute(
      omop_concept_id = .data$omop_concept_id,
      omop_concept_name = .escapeForMarkdown(.data$omop_concept_name),
      n_rows = .data$n_rows,
      top2000 = ifelse(.data$omop_concept_id %in% top2000Ids, "yes", "")
    )
}

# Findings: send the per-group reflections back to the model and ask it to
# distil the recurring themes across all of them.
findingsType <- ellmer::type_object(
  key_findings = ellmer::type_array(
    ellmer::type_string("One recurring finding about the mapping task or the candidate lists."),
    "The main recurring themes across the group reflections."
  ),
  improvements = ellmer::type_array(
    ellmer::type_string("One concrete, actionable improvement to the process."),
    "Concrete suggested improvements to the mapping process."
  ),
  data_problems = ellmer::type_array(
    ellmer::type_string("One systematic problem in the source data."),
    "Systematic problems in the source lab-code data."
  )
)

findingsPrompt <- paste0(
  "Below are the per-group reflections written by a LOINC mapping expert while choosing the ",
  "real OMOP concept for Finnish local lab codes, from candidate lists retrieved by semantic ",
  "search. Each group was processed independently, so the same issue may be described many ",
  "times in different words.\n\n",
  "Distil them into: the recurring KEY FINDINGS about the task and the candidate lists, ",
  "concrete IMPROVEMENTS to the process, and systematic DATA PROBLEMS in the source lab ",
  "codes.\n\n",
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
  }
} else {
  ParallelLogger::logWarn("No reflections to summarise at ", reflectionsFile)
}

#
# --- Output -------------------------------------------------------------
#
md <- c(
  "# Guessed Names -> OMOP Concepts -- Stats",
  "",
  paste0("Source: `", mappedFile, "`"),
  "",
  paste0("Rows (local `TEST_NAME`/`UNIT` combinations): ", nRows),
  paste0("Similarity groups covered: ", nGroups),
  "",
  "## Overview",
  "",
  "An unmapped row is not automatically a failure: the prompt tells the model to",
  "leave the id empty when no candidate is right, which is the correct answer for",
  "a code too garbled to identify, for a non-laboratory code, and for a test whose",
  "concept the search did not return.",
  "",
  .markdownTable(overview),
  "",
  "## Did the search find anything?",
  "",
  "Per distinct guessed name, whether Hecate returned any concept at all and how",
  "close the best one was. This separates *the search failed* from *the model",
  "rejected what the search found* — two problems with completely different fixes:",
  "the first is about how the guess is phrased, the second about the evidence in",
  "the row.",
  "",
  .markdownTable(search),
  "",
  "## What kind of concept was chosen",
  "",
  "The prompt asks the model to break ties by preferring a concept on the **LOINC",
  "Top 2000+ (SI)** recommended list, and then one Finland already maps codes to.",
  "A high share in neither bucket means the model is routinely landing on obscure",
  "concepts, which is worth a look even when the concept is defensible.",
  "",
  .markdownTable(provenance),
  ""
)

if (is.null(topConcepts)) {
  md <- c(md, "## Most chosen concepts", "", "_(no rows were mapped)_", "")
} else {
  md <- c(
    md,
    "## Most chosen concepts",
    "",
    "The concepts the most local codes were mapped to. A concept collecting a very",
    "large number of rows is worth checking: it may genuinely be the test that",
    "recurs under many local spellings, or it may be where codes the model could",
    "not tell apart ended up.",
    "",
    .markdownTable(topConcepts),
    ""
  )
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

outFile <- file.path(outDir, "fixedLoincNamesStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
