#
# Infers the 6 LOINC axes (+ is_panel) for every local Finnish lab code in
# knownInformationGrouped.tsv, by sending each similarity group to an LLM.
#
# One LLM call per group. The group's rows are rendered as a TSV table and
# appended to scripts/systemPrompt.md; the model returns, per row, only the 7
# NEW fields keyed by `row_id` (not the whole table back). That keeps the
# payload small, makes it impossible for the model to silently alter source
# values (n, deciles, ...), and gives an unambiguous integer join key —
# TEST_NAME alone is not unique within a group (the same code recurs with
# different UNITs).
#
# The attribute columns are named exactly as in GetMeasurementOmopData's
# measurement_concept_attributes.tsv (has_component, has_property, has_method,
# has_scale_type, has_system, has_time_aspect, is_panel) so the inferred axes
# and the OMOP vocabulary's own axes are directly comparable downstream.
#
# Results are cached per group under <outDir>/groupsCache/<group_id>.json, so a
# re-run only calls the LLM for groups that have no cached answer yet.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)
library(ParallelLogger)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
inputFile <- args[1]
outDir <- args[2]
nGroups <- if (length(args) >= 3 && nzchar(args[3])) as.integer(args[3]) else NA_integer_

scriptDir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))
if (is.na(scriptDir) || !nzchar(scriptDir)) scriptDir <- "."
rDir <- file.path(scriptDir, "R")
systemPromptFile <- file.path(scriptDir, "systemPrompt.md")
ellmerFixFile <- file.path(rDir, "ellmerFix.R")

source(file.path(rDir, "clientFactory.R"))

llmConfig <- list(
  provider = Sys.getenv("LLM_PROVIDER", "google_vertex"),
  model = Sys.getenv("LLM_MODEL", "gemini-2.5-pro"),
  project = Sys.getenv("GOOGLE_CLOUD_PROJECT"),
  location = Sys.getenv("GOOGLE_CLOUD_LOCATION"),
  credentials = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS")
)

workersEnv <- Sys.getenv("LLM_PARALLEL_WORKERS", "")
workers <- if (nzchar(workersEnv)) as.integer(workersEnv) else max(parallel::detectCores() - 2L, 1L)

cacheDir <- file.path(outDir, "groupsCache")
dir.create(cacheDir, showWarnings = FALSE, recursive = TRUE)

pathToDimensionsTSV <- file.path(outDir, "codesWithLoincDimensions.tsv")
pathToReflectionsMD <- file.path(outDir, "reflections.md")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  inputFile = ", inputFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  nGroups = ", if (is.na(nGroups)) "(all)" else nGroups)
ParallelLogger::logInfo("  provider = ", llmConfig$provider)
ParallelLogger::logInfo("  model = ", llmConfig$model)
ParallelLogger::logInfo("  project = ", llmConfig$project)
ParallelLogger::logInfo("  location = ", llmConfig$location)
ParallelLogger::logInfo("  workers = ", workers)
ParallelLogger::logInfo("  cacheDir = ", cacheDir)

# Structured-output schema. One entry per input row: the row_id echoed back as
# the join key, the 6 LOINC axes, is_panel, plus a per-group reflection.
# Every axis is a free string so the model can return "" for "not knowable" —
# an enum would force it to pick a value it cannot justify.
dimensionsType <- ellmer::type_object(
  rows = ellmer::type_array(
    ellmer::type_object(
      row_id = ellmer::type_integer("The row_id of the input row, echoed exactly."),
      has_component = ellmer::type_string("The analyte/substance measured, English LOINC-style name. Empty if not determinable."),
      has_property = ellmer::type_string("Full OMOP property name, NOT a LOINC abbreviation (e.g. 'Substance Concentration' not 'SCnc', 'Presence or Threshold' not 'PrThr'). Empty if not determinable."),
      has_time_aspect = ellmer::type_string("Full OMOP time aspect name, NOT an abbreviation (e.g. 'Point in time (spot)' not 'Pt', '24 hours' not '24H'). Empty if not determinable."),
      has_system = ellmer::type_string("Full OMOP system/specimen name, NOT an abbreviation (e.g. 'Serum or Plasma' not 'Ser/Plas', 'Blood' not 'Bld', 'Cerebral spinal fluid' not 'CSF'). Empty if not determinable."),
      has_scale_type = ellmer::type_string("LOINC scale, abbreviated as OMOP stores it: Qn, Ord, SemiQn, Nom, Nar, Doc, OrdQn. Empty if not determinable."),
      has_method = ellmer::type_string("Full OMOP method name, NOT an abbreviation (e.g. 'Nucleic acid amplification with probe detection' not 'NAA+probe'). ONLY when the code indicates a method that changes interpretation. Empty otherwise."),
      is_panel = ellmer::type_boolean("TRUE if the code refers to a panel bundling several separately reported tests.")
    ),
    "One entry per row of the input table, in the same order."
  ),
  reflection = ellmer::type_string("Short markdown reflection: ideas to improve the process, gotchas, ambiguities and data problems specific to this group.")
)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: this file was written by another step in
# this project, so "" (not "NA") is its missing-value marker.
grouped <- readr::read_tsv(
  inputFile,
  na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(grouped), " rows from ", inputFile)

# Stable integer key per row, used as the only join key between the model's
# answer and the table. Assigned over the whole table before any subsetting so
# a row's id does not depend on --ngroups.
grouped <- grouped |>
  dplyr::mutate(row_id = dplyr::row_number())

allGroupIds <- sort(unique(as.integer(grouped$group_id)))
groupIds <- if (!is.na(nGroups) && nGroups > 0 && nGroups < length(allGroupIds)) {
  utils::head(allGroupIds, nGroups)
} else {
  allGroupIds
}
ParallelLogger::logInfo("Processing ", length(groupIds), " of ", length(allGroupIds), " groups")

systemPrompt <- paste(readLines(systemPromptFile, warn = FALSE), collapse = "\n")

#
# --- Action -------------------------------------------------------------
#
# Columns handed to the model: everything that carries information about the
# test, plus row_id as the key. group_path is dropped (it encodes the clustering
# tree, not the test) and group_id is constant within a call.
promptColumns <- c(
  "row_id", "TEST_NAME", "UNIT", "n", "p_missing", "deciles",
  "LongName", "prefix_meaning", "suffix_meaning"
)

# Render a group's rows as a TSV block for the prompt. TSV (not markdown) keeps
# it compact and unambiguous when values themselves contain commas or brackets.
renderGroupTable <- function(groupData) {
  tbl <- groupData |>
    dplyr::select(dplyr::all_of(promptColumns)) |>
    dplyr::mutate(dplyr::across(dplyr::everything(), ~ ifelse(is.na(.x), "", as.character(.x))))
  lines <- c(
    paste(names(tbl), collapse = "\t"),
    apply(tbl, 1, function(r) paste(r, collapse = "\t"))
  )
  paste(lines, collapse = "\n")
}

todo <- groupIds[!file.exists(file.path(cacheDir, paste0(groupIds, ".json")))]
ParallelLogger::logInfo("Groups to send to the LLM: ", length(todo),
                        " (", length(groupIds) - length(todo), " already cached)")

todoItems <- lapply(todo, function(gid) {
  list(
    gid = gid,
    table = renderGroupTable(dplyr::filter(grouped, as.integer(.data$group_id) == gid))
  )
})

# One LLM call for one group: build the user message, call the model with the
# structured schema, cache the answer as JSON. Returns ok/cost for the summary.
resolveGroup <- function(item, cacheDir, systemPrompt, dimensionsType, llmConfig,
                         makeClientFactory, ellmerFixFile = "") {
  gid <- item$gid
  outJson <- file.path(cacheDir, paste0(gid, ".json"))

  userMessage <- paste0(
    "Here is group ", gid, " of the table. Infer the LOINC axes for every row.\n\n",
    item$table, "\n"
  )
  writeLines(
    paste0("[System Prompt]\n", systemPrompt, "\n\n[Prompt]\n", userMessage),
    file.path(cacheDir, paste0(gid, "_prompt.md"))
  )

  # Workers are separate processes, so ellmer's Google credential fix must be
  # applied inside each one. Harmless/idempotent on non-Vertex providers.
  if (nzchar(ellmerFixFile) && file.exists(ellmerFixFile)) source(ellmerFixFile, local = TRUE)

  # Retry with jittered backoff: ellmer resolves Vertex credentials when the
  # client is built, and all workers start at once, so their first token fetches
  # hit the metadata server as one synchronised burst and some get throttled.
  # A random backoff de-synchronises them so the retry succeeds in the same run.
  maxAttempts <- 4L
  res <- NULL
  client <- NULL
  for (attempt in seq_len(maxAttempts)) {
    res <- tryCatch({
      client <- makeClientFactory(llmConfig)()
      client$set_system_prompt(systemPrompt)
      client$chat_structured(userMessage, echo = "none", type = dimensionsType)
    }, error = function(e) {
      ParallelLogger::logWarn("Group ", gid, " attempt ", attempt, "/", maxAttempts,
                              " failed: ", conditionMessage(e))
      NULL
    })
    if (!is.null(res)) break
    if (attempt < maxAttempts) Sys.sleep(stats::runif(1, 0.5, 2.5) * attempt)
  }
  if (is.null(res)) {
    ParallelLogger::logError("Group ", gid, " gave up after ", maxAttempts, " attempts")
    return(list(ok = FALSE, cost = 0))
  }

  jsonlite::write_json(res, outJson, auto_unbox = TRUE, pretty = TRUE)
  cost <- tryCatch(as.numeric(client$get_cost()), error = function(e) NA_real_)
  list(ok = TRUE, cost = if (length(cost) == 0 || is.na(cost)) 0 else cost)
}

if (length(todoItems) > 0) {
  ParallelLogger::logInfo("Resolving ", length(todoItems), " groups across ", workers, " workers")
  if (workers > 1 && length(todoItems) > 1) {
    cl <- ParallelLogger::makeCluster(workers)
    on.exit(ParallelLogger::stopCluster(cl), add = TRUE)
    ParallelLogger::clusterRequire(cl, "ellmer")
    results <- ParallelLogger::clusterApply(
      cl, todoItems, resolveGroup,
      cacheDir = cacheDir, systemPrompt = systemPrompt, dimensionsType = dimensionsType,
      llmConfig = llmConfig, makeClientFactory = makeClientFactory,
      ellmerFixFile = ellmerFixFile,
      progressBar = TRUE
    )
  } else {
    results <- lapply(
      todoItems, resolveGroup,
      cacheDir = cacheDir, systemPrompt = systemPrompt, dimensionsType = dimensionsType,
      llmConfig = llmConfig, makeClientFactory = makeClientFactory,
      ellmerFixFile = ellmerFixFile
    )
  }
  nOk <- sum(vapply(results, function(x) isTRUE(x$ok), logical(1)))
  costUsd <- sum(vapply(results, function(x) as.numeric(x$cost), numeric(1)), na.rm = TRUE)
} else {
  nOk <- 0
  costUsd <- 0
}
ParallelLogger::logInfo("Resolved ", nOk, " groups this run (LLM cost USD ", sprintf("%.4f", costUsd), ")")

# Read every cached group back and assemble the per-row answers.
dimensionColumns <- c(
  "has_component", "has_property", "has_time_aspect",
  "has_system", "has_scale_type", "has_method"
)

`%||%` <- function(x, y) if (is.null(x)) y else x

readGroupRows <- function(gid) {
  f <- file.path(cacheDir, paste0(gid, ".json"))
  if (!file.exists(f)) return(NULL)
  parsed <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(parsed) || length(parsed$rows) == 0) {
    ParallelLogger::logWarn("Group ", gid, ": no rows in cached answer")
    return(NULL)
  }
  purrr::map_dfr(parsed$rows, function(r) {
    out <- list(row_id = as.integer(r$row_id %||% NA_integer_))
    for (col in dimensionColumns) {
      v <- r[[col]]
      out[[col]] <- if (is.null(v) || length(v) == 0) NA_character_ else as.character(v)[1]
    }
    v <- r$is_panel
    out$is_panel <- if (is.null(v) || length(v) == 0) NA else as.logical(v)[1]
    tibble::as_tibble(out)
  })
}

answers <- purrr::map_dfr(groupIds, readGroupRows)
ParallelLogger::logInfo("Collected ", nrow(answers), " per-row answers from ", length(groupIds), " groups")

# Guard the join: the model must echo row_ids that exist, exactly once each.
expectedRowIds <- grouped$row_id[as.integer(grouped$group_id) %in% groupIds]
unknownIds <- setdiff(answers$row_id, expectedRowIds)
if (length(unknownIds) > 0) {
  ParallelLogger::logWarn(length(unknownIds), " returned row_id(s) are not in the processed groups; dropping them")
  answers <- dplyr::filter(answers, .data$row_id %in% expectedRowIds)
}
duplicateIds <- answers$row_id[duplicated(answers$row_id)]
if (length(duplicateIds) > 0) {
  ParallelLogger::logWarn(length(duplicateIds), " row_id(s) returned more than once; keeping the first of each")
  answers <- dplyr::distinct(answers, .data$row_id, .keep_all = TRUE)
}
missingIds <- setdiff(expectedRowIds, answers$row_id)
if (length(missingIds) > 0) {
  ParallelLogger::logWarn(length(missingIds), " row(s) got no answer from the model; their axes stay empty")
}

# Join the inferred axes onto the processed rows of the source table.
result <- grouped |>
  dplyr::filter(as.integer(.data$group_id) %in% groupIds) |>
  dplyr::left_join(answers, by = "row_id") |>
  dplyr::select(-dplyr::all_of("row_id"))

nFilled <- sum(!is.na(result$has_component) & nzchar(result$has_component))
ParallelLogger::logInfo(nFilled, " / ", nrow(result), " rows got a has_component")

# Reflections, one section per group, in group order.
reflectionFor <- function(gid) {
  f <- file.path(cacheDir, paste0(gid, ".json"))
  if (!file.exists(f)) return(NULL)
  parsed <- tryCatch(jsonlite::read_json(f, simplifyVector = FALSE), error = function(e) NULL)
  txt <- parsed$reflection
  if (is.null(txt) || !nzchar(as.character(txt)[1])) return(NULL)
  paste0("# Group ", gid, "\n\n", as.character(txt)[1], "\n")
}
reflections <- purrr::compact(purrr::map(groupIds, reflectionFor))

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(result, pathToDimensionsTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", pathToDimensionsTSV)

readr::write_lines(paste(unlist(reflections), collapse = "\n"), pathToReflectionsMD)
ParallelLogger::logInfo("Wrote ", length(reflections), " group reflections to ", pathToReflectionsMD)
