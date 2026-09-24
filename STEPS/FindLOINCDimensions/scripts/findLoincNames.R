#
# Guesses the LOINC Long Common Name of every local Finnish lab code in
# knownInformationGrouped.tsv, by sending each similarity group to an LLM.
#
# The model is asked for the NAME, not for the six LOINC axes. The axes are
# still how it reasons -- component, property, time, system, scale, method --
# but it returns the single string they compose into, spelled the way LOINC
# spells its Long Common Names:
#
#     <Component> [<Property>] in <System> by <Method>
#
# The guess is not expected to be a real LOINC name. It is a SEARCH QUERY:
# FixLOINCDimensions feeds it to a semantic search over the LOINC vocabulary
# and asks a second pass to pick the real concept it was aiming at. Guessing
# one string well is a far easier target than guessing six axis labels that
# must ALL land exactly right for a tuple join to fire, which is what the
# earlier axis-based version of this step required.
#
# One LLM call per group. The group's rows are rendered as a markdown table and
# appended to scripts/systemPrompt.md; the model returns, per row, only the 2
# NEW fields keyed by `row_id` (not the whole table back). That keeps the
# payload small, makes it impossible for the model to silently alter source
# values (n, deciles, ...), and gives an unambiguous integer join key --
# TEST_NAME alone is not unique within a group (the same code recurs with
# different UNITs).
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
frequencyFile <- args[2]
outDir <- args[3]
nGroups <- if (length(args) >= 4 && nzchar(args[4])) as.integer(args[4]) else NA_integer_
seed <- if (length(args) >= 5 && nzchar(args[5])) as.integer(args[5]) else 1L

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

# How many of the most-used Finnish LOINC names to show the model as worked
# examples. 100 covers ~90% of all records in the curated mappings, so it shows
# the model nearly every test it will actually meet, while staying short enough
# to read as examples rather than as a list to pick from.
nExamplesEnv <- Sys.getenv("FINNISH_NAME_EXAMPLES", "")
nExamples <- if (nzchar(nExamplesEnv)) as.integer(nExamplesEnv) else 100L

cacheDir <- file.path(outDir, "groupsCache")
dir.create(cacheDir, showWarnings = FALSE, recursive = TRUE)

pathToNamesTSV <- file.path(outDir, "codesWithLoincNames.tsv")
pathToReflectionsMD <- file.path(outDir, "reflections.md")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  inputFile = ", inputFile)
ParallelLogger::logInfo("  frequencyFile = ", frequencyFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  nGroups = ", if (is.na(nGroups)) "(all)" else nGroups)
ParallelLogger::logInfo("  seed = ", seed)
ParallelLogger::logInfo("  nExamples = ", nExamples)
ParallelLogger::logInfo("  provider = ", llmConfig$provider)
ParallelLogger::logInfo("  model = ", llmConfig$model)
ParallelLogger::logInfo("  project = ", llmConfig$project)
ParallelLogger::logInfo("  location = ", llmConfig$location)
ParallelLogger::logInfo("  workers = ", workers)
ParallelLogger::logInfo("  cacheDir = ", cacheDir)

# Structured-output schema. One entry per input row: the row_id echoed back as
# the join key, the guessed name, is_panel, plus a per-group reflection.
# The name is a free string so the model can return "" for "not knowable" --
# the prompt is explicit that an empty name beats an invented one.
namesType <- ellmer::type_object(
  rows = ellmer::type_array(
    ellmer::type_object(
      row_id = ellmer::type_integer("The row_id of the input row, echoed exactly."),
      loinc_name_guess = ellmer::type_string(
        paste0("The LOINC Long Common Name this code would have, spelled as LOINC spells it: ",
               "'<Component> [<Property>] in <System> by <Method>', e.g. ",
               "'Creatinine [Moles/volume] in Serum or Plasma'. ",
               "Empty if you cannot tell what the test measures.")
      ),
      is_panel = ellmer::type_boolean("TRUE if the code orders a panel bundling several separately reported tests.")
    ),
    "One entry per row of the input table, in the same order."
  ),
  reflection = ellmer::type_string("Short markdown reflection: ideas to improve the process, gotchas, ambiguities and data problems specific to this group.")
)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: these files were written by this project,
# so "" (not "NA") is their missing-value marker.
grouped <- readr::read_tsv(
  inputFile,
  na = "",
  col_types = readr::cols(.default = readr::col_character())
)
ParallelLogger::logInfo("Read ", nrow(grouped), " rows from ", inputFile)

frequency <- readr::read_tsv(frequencyFile, na = "", col_types = readr::cols(
  concept_id = readr::col_character(), concept_name = readr::col_character(),
  vocabulary_id = readr::col_character(),
  n_codes = readr::col_double(), n_events = readr::col_double()
))
ParallelLogger::logInfo("Read ", nrow(frequency), " Finnish name-frequency rows from ", frequencyFile)

# Stable integer key per row, used as the only join key between the model's
# answer and the table. Assigned over the whole table before any subsetting so
# a row's id does not depend on --ngroups.
grouped <- grouped |>
  dplyr::mutate(row_id = dplyr::row_number())

allGroupIds <- sort(unique(as.integer(grouped$group_id)))
groupIds <- if (!is.na(nGroups) && nGroups > 0 && nGroups < length(allGroupIds)) {
  # A RANDOM sample, not the first N. The groups come out of the clustering in
  # tree order, so the first N are all neighbours in the dendrogram -- the
  # original --ngroups 50 run drew 50 consecutive microbiology groups and said
  # nothing about how the step behaves on chemistry, haematology or narrative
  # codes. Sampling spreads the subset across the whole table.
  # Seeded so a given --seed/--ngroups pair is reproducible across re-runs.
  set.seed(seed)
  sort(sample(allGroupIds, nGroups))
} else {
  allGroupIds
}
ParallelLogger::logInfo("Processing ", length(groupIds), " of ", length(allGroupIds), " groups",
                        if (length(groupIds) < length(allGroupIds)) paste0(" (random sample, seed ", seed, ")") else "")

#
# --- Action -------------------------------------------------------------
#
# Make one value safe to put in a markdown table cell: a literal "|" would end
# the cell early and silently shift every later column, and a real newline
# would end the row. Neither occurs in the data today; escaping them keeps a
# future value from corrupting the table the model reads.
escapeMarkdownCell <- function(x) {
  x |>
    gsub("|", "\\|", x = _, fixed = TRUE) |>
    gsub("\r?\n", " ", x = _)
}

# Render a data frame as a markdown table.
renderMarkdownTable <- function(tbl) {
  tbl <- tbl |>
    dplyr::mutate(dplyr::across(
      dplyr::everything(),
      ~ escapeMarkdownCell(ifelse(is.na(.x), "", as.character(.x)))
    ))
  paste(c(
    paste0("| ", paste(names(tbl), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(tbl)), collapse = "|"), "|"),
    apply(tbl, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |"))
  ), collapse = "\n")
}

# The worked-examples block the prompt's {{FINNISH_NAME_EXAMPLES}} placeholder
# is replaced with. Injected at run time rather than pasted into the prompt file
# so the examples cannot drift from the reference table they come from, and so
# the exact list sent is recoverable from the cached <group>_prompt.md.
examplesTable <- frequency |>
  dplyr::arrange(dplyr::desc(.data$n_events), dplyr::desc(.data$n_codes)) |>
  dplyr::slice_head(n = nExamples) |>
  dplyr::transmute(
    `LOINC Long Common Name` = .data$concept_name,
    n_codes = format(as.integer(.data$n_codes), big.mark = ","),
    n_events = format(as.integer(.data$n_events), big.mark = ",")
  )

systemPrompt <- paste(readLines(systemPromptFile, warn = FALSE), collapse = "\n")
if (!grepl("{{FINNISH_NAME_EXAMPLES}}", systemPrompt, fixed = TRUE)) {
  stop("systemPrompt.md has no {{FINNISH_NAME_EXAMPLES}} placeholder to fill")
}
systemPrompt <- sub("{{FINNISH_NAME_EXAMPLES}}", renderMarkdownTable(examplesTable),
                    systemPrompt, fixed = TRUE)
ParallelLogger::logInfo("Injected ", nrow(examplesTable), " Finnish name examples into the system prompt")

# Columns handed to the model: everything that carries information about the
# test, plus row_id as the key. group_path is dropped (it encodes the clustering
# tree, not the test) and group_id is constant within a call.
promptColumns <- c(
  "row_id", "TEST_NAME", "UNIT", "n", "p_missing", "deciles",
  "LongName", "prefix_meaning", "suffix_meaning"
)

renderGroupTable <- function(groupData) {
  renderMarkdownTable(dplyr::select(groupData, dplyr::all_of(promptColumns)))
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
resolveGroup <- function(item, cacheDir, systemPrompt, namesType, llmConfig,
                         makeClientFactory, ellmerFixFile = "") {
  gid <- item$gid
  outJson <- file.path(cacheDir, paste0(gid, ".json"))

  userMessage <- paste0(
    "Here is group ", gid, " of the table. Write the LOINC Long Common Name for every row.\n\n",
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
      client$chat_structured(userMessage, echo = "none", type = namesType)
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
      cacheDir = cacheDir, systemPrompt = systemPrompt, namesType = namesType,
      llmConfig = llmConfig, makeClientFactory = makeClientFactory,
      ellmerFixFile = ellmerFixFile,
      progressBar = TRUE
    )
  } else {
    results <- lapply(
      todoItems, resolveGroup,
      cacheDir = cacheDir, systemPrompt = systemPrompt, namesType = namesType,
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
    v <- r$loinc_name_guess
    # The model returns "" for "not determinable". Normalise it to NA here,
    # at the JSON boundary, so the in-memory table represents missing the
    # same way the rest of the pipeline does (tables are read with na = "").
    # Without this, "" and NA both write out as empty but compare unequal,
    # so any is.na() check downstream silently misreads the column.
    name <- if (is.null(v) || length(v) == 0 || !nzchar(trimws(as.character(v)[1]))) {
      NA_character_
    } else {
      trimws(as.character(v)[1])
    }
    p <- r$is_panel
    tibble::tibble(
      row_id = as.integer(r$row_id %||% NA_integer_),
      loinc_name_guess = name,
      is_panel = if (is.null(p) || length(p) == 0) NA else as.logical(p)[1]
    )
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
  ParallelLogger::logWarn(length(missingIds), " row(s) got no answer from the model; their name stays empty")
}

# Join the guessed names onto the processed rows of the source table.
result <- grouped |>
  dplyr::filter(as.integer(.data$group_id) %in% groupIds) |>
  dplyr::left_join(answers, by = "row_id") |>
  dplyr::select(-dplyr::all_of("row_id"))

nNamed <- sum(!is.na(result$loinc_name_guess))
ParallelLogger::logInfo(nNamed, " / ", nrow(result), " rows got a LOINC name guess")

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
readr::write_tsv(result, pathToNamesTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", pathToNamesTSV)

readr::write_lines(paste(unlist(reflections), collapse = "\n"), pathToReflectionsMD)
ParallelLogger::logInfo("Wrote ", length(reflections), " group reflections to ", pathToReflectionsMD)
