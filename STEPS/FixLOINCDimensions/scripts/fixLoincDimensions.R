#
# Corrects the LOINC axis labels produced by FindLOINCDimensions so they are
# real OMOP vocabulary terms.
#
# FindLOINCDimensions writes the axes as free text. Measured against the
# curated Finnish mappings, most values were real OMOP terms but the wrong one,
# and has_component drifted off the controlled vocabulary entirely (~75% of its
# mismatches were near-miss paraphrases such as "Transglutaminase IgA Ab" for
# OMOP's "Tissue Transglutaminase IgA"). Because the downstream mapping joins
# on exact axis values, a near miss fails exactly as hard as nonsense.
#
# This step therefore, for each of the four free-text axes (component,
# property, method, system):
#   1. asks Hecate -- a semantic search over the OMOP vocabularies -- for the
#      closest real LOINC terms to the current value, keeping those scoring
#      >= the threshold;
#   2. attaches how often each candidate is actually used in Finland, from
#      DATA/SourceLabelingData/loinc_axes_frequency.tsv;
#   3. sends each similarity group to an LLM with its rows and the candidate
#      lists, and asks which label each row should carry.
#
# has_scale_type and has_time_aspect are not searched: they already come from
# closed lists embedded in FindLOINCDimensions' prompt, so they are carried
# through as-is.
#
# Hecate lookups are deduplicated across the whole run (the same value recurs
# in many groups) and cached on disk, so re-runs cost no network traffic. LLM
# answers are cached per group exactly as in FindLOINCDimensions.
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
hecateFile <- file.path(rDir, "hecate.R")

source(file.path(rDir, "clientFactory.R"))
source(hecateFile)

llmConfig <- list(
  provider = Sys.getenv("LLM_PROVIDER", "google_vertex"),
  model = Sys.getenv("LLM_MODEL", "gemini-2.5-pro"),
  project = Sys.getenv("GOOGLE_CLOUD_PROJECT"),
  location = Sys.getenv("GOOGLE_CLOUD_LOCATION"),
  credentials = Sys.getenv("GOOGLE_APPLICATION_CREDENTIALS")
)

workersEnv <- Sys.getenv("LLM_PARALLEL_WORKERS", "")
workers <- if (nzchar(workersEnv)) as.integer(workersEnv) else max(parallel::detectCores() - 2L, 1L)

hecateWorkersEnv <- Sys.getenv("HECATE_PARALLEL_WORKERS", "")
hecateWorkers <- if (nzchar(hecateWorkersEnv)) as.integer(hecateWorkersEnv) else 4L

# Keep only candidates at least this similar to the current value. Below this,
# the search is returning a different concept rather than a spelling variant.
scoreThreshold <- suppressWarnings(as.numeric(Sys.getenv("HECATE_SCORE_THRESHOLD", "0.75")))
candidateLimit <- suppressWarnings(as.integer(Sys.getenv("HECATE_CANDIDATE_LIMIT", "5")))

# The four free-text axes this step corrects, and their column names.
fixedAxes <- c(
  component = "has_component",
  property = "has_property",
  method = "has_method",
  system = "has_system"
)
carriedAxes <- c("has_scale_type", "has_time_aspect")

cacheDir <- file.path(outDir, "groupsCache")
dir.create(cacheDir, showWarnings = FALSE, recursive = TRUE)
hecateCacheFile <- file.path(outDir, "hecateCandidates.tsv")

pathToFixedTSV <- file.path(outDir, "codesWithFixedLoincDimensions.tsv")
pathToReflectionsMD <- file.path(outDir, "reflections.md")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  inputFile = ", inputFile)
ParallelLogger::logInfo("  frequencyFile = ", frequencyFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  nGroups = ", if (is.na(nGroups)) "(all)" else nGroups)
ParallelLogger::logInfo("  seed = ", seed)
ParallelLogger::logInfo("  model = ", llmConfig$model)
ParallelLogger::logInfo("  workers = ", workers, " (LLM), ", hecateWorkers, " (Hecate)")
ParallelLogger::logInfo("  scoreThreshold = ", scoreThreshold, ", candidateLimit = ", candidateLimit)

# Same shape as FindLOINCDimensions' schema, so the output table is identical.
dimensionsType <- ellmer::type_object(
  rows = ellmer::type_array(
    ellmer::type_object(
      row_id = ellmer::type_integer("The row_id of the input row, echoed exactly."),
      has_component = ellmer::type_string("Chosen OMOP component term, taken verbatim from the candidate list. Empty if none is right."),
      has_property = ellmer::type_string("Chosen OMOP property term, taken verbatim from the candidate list. Empty if none is right."),
      has_time_aspect = ellmer::type_string("Carried through from the input row unchanged."),
      has_system = ellmer::type_string("Chosen OMOP system term, taken verbatim from the candidate list. Empty if none is right."),
      has_scale_type = ellmer::type_string("Carried through from the input row unchanged."),
      has_method = ellmer::type_string("Chosen OMOP method term, taken verbatim from the candidate list. Empty if none is right or the code states no method."),
      is_panel = ellmer::type_boolean("Carried through from the input row unchanged.")
    ),
    "One entry per row of the input table."
  ),
  reflection = ellmer::type_string("Short markdown reflection on this group: corrections made and why, gaps in the candidate lists, and process problems.")
)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: both files are written by this project.
codes <- readr::read_tsv(inputFile, na = "", col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", inputFile)

frequency <- readr::read_tsv(frequencyFile, na = "", col_types = readr::cols(
  axe_name = readr::col_character(), name = readr::col_character(),
  concept_id = readr::col_character(),
  n_codes = readr::col_double(), n_events = readr::col_double()
))
ParallelLogger::logInfo("Read ", nrow(frequency), " axis-frequency rows from ", frequencyFile)

systemPrompt <- paste(readLines(systemPromptFile, warn = FALSE), collapse = "\n")

# row_id is re-derived here: FindLOINCDimensions drops it before writing, and
# the rows keep their order, so row_number() reproduces the same key.
codes <- codes |> dplyr::mutate(row_id = dplyr::row_number())

allGroupIds <- sort(unique(as.integer(codes$group_id)))
groupIds <- if (!is.na(nGroups) && nGroups > 0 && nGroups < length(allGroupIds)) {
  set.seed(seed)
  sort(sample(allGroupIds, nGroups))
} else {
  allGroupIds
}
ParallelLogger::logInfo("Processing ", length(groupIds), " of ", length(allGroupIds), " groups",
                        if (length(groupIds) < length(allGroupIds)) paste0(" (random sample, seed ", seed, ")") else "")

selected <- codes |> dplyr::filter(as.integer(.data$group_id) %in% groupIds)

#
# --- Action -------------------------------------------------------------
#

## Step 1: Hecate candidates for every distinct (axis, current value).
# Deduplicated across groups -- the same value recurs in many of them -- and
# cached on disk so a re-run does no network traffic.
wanted <- purrr::map_dfr(names(fixedAxes), function(axis) {
  column <- fixedAxes[[axis]]
  tibble::tibble(axe_name = axis, value = unique(selected[[column]][!is.na(selected[[column]])]))
})
ParallelLogger::logInfo("Distinct (axis, value) pairs needing candidates: ", nrow(wanted))

cached <- if (file.exists(hecateCacheFile)) {
  readr::read_tsv(hecateCacheFile, na = "", col_types = readr::cols(
    axe_name = readr::col_character(), value = readr::col_character(),
    concept_name = readr::col_character(), concept_id = readr::col_character(),
    score = readr::col_double()
  ))
} else {
  tibble::tibble(axe_name = character(0), value = character(0),
                 concept_name = character(0), concept_id = character(0), score = numeric(0))
}
# A cached pair may legitimately have zero surviving candidates, so presence is
# tracked by the pair having been looked up, not by having rows.
lookedUp <- if (nrow(cached) > 0) unique(paste(cached$axe_name, cached$value, sep = "\r")) else character(0)
todoLookups <- wanted |> dplyr::filter(!paste(.data$axe_name, .data$value, sep = "\r") %in% lookedUp)
ParallelLogger::logInfo("Hecate lookups to run: ", nrow(todoLookups),
                        " (", nrow(wanted) - nrow(todoLookups), " already cached)")

if (nrow(todoLookups) > 0) {
  lookupItems <- purrr::pmap(
    list(todoLookups$axe_name, todoLookups$value),
    function(axis, value) list(axis = axis, value = value)
  )
  searchOne <- function(item, hecateFile, candidateLimit) {
    source(hecateFile, local = TRUE)
    hits <- hecateSearch(item$value, item$axis, limit = candidateLimit)
    if (nrow(hits) == 0) {
      return(list(axe_name = item$axis, value = item$value,
                  concept_name = NA_character_, concept_id = NA_character_, score = NA_real_))
    }
    lapply(seq_len(nrow(hits)), function(i) {
      list(axe_name = item$axis, value = item$value,
           concept_name = hits$concept_name[i], concept_id = hits$concept_id[i], score = hits$score[i])
    })
  }
  if (hecateWorkers > 1 && length(lookupItems) > 1) {
    hcl <- ParallelLogger::makeCluster(hecateWorkers)
    fetched <- ParallelLogger::clusterApply(
      hcl, lookupItems, searchOne, hecateFile = hecateFile,
      candidateLimit = candidateLimit, progressBar = TRUE
    )
    ParallelLogger::stopCluster(hcl)
  } else {
    fetched <- lapply(lookupItems, searchOne, hecateFile = hecateFile, candidateLimit = candidateLimit)
  }
  # searchOne returns either one record or a list of them; flatten both shapes.
  flat <- purrr::map_dfr(fetched, function(x) {
    if (!is.null(x$axe_name)) tibble::as_tibble(x) else purrr::map_dfr(x, tibble::as_tibble)
  })
  cached <- dplyr::bind_rows(cached, flat)
  readr::write_tsv(cached, hecateCacheFile, na = "")
  ParallelLogger::logInfo("Cached ", nrow(flat), " new candidate rows to ", hecateCacheFile)
}

# Apply the score threshold and attach Finnish usage counts.
candidates <- cached |>
  dplyr::filter(!is.na(.data$concept_name), !is.na(.data$score), .data$score >= scoreThreshold) |>
  dplyr::left_join(
    frequency |> dplyr::select(axe_name, name, n_codes, n_events),
    by = c("axe_name" = "axe_name", "concept_name" = "name")
  ) |>
  dplyr::mutate(
    n_codes = ifelse(is.na(.data$n_codes), 0, .data$n_codes),
    n_events = ifelse(is.na(.data$n_events), 0, .data$n_events)
  ) |>
  dplyr::arrange(.data$axe_name, .data$value, dplyr::desc(.data$score))
ParallelLogger::logInfo("Kept ", nrow(candidates), " candidates at score >= ", scoreThreshold)

## Step 2: one LLM call per group, with its rows plus the candidate lists.
promptColumns <- c(
  "row_id", "TEST_NAME", "UNIT", "n", "p_missing", "deciles",
  "LongName", "prefix_meaning", "suffix_meaning",
  "has_component", "has_property", "has_method", "has_system",
  "has_scale_type", "has_time_aspect", "is_panel"
)

# Make one value safe to put in a markdown table cell: a literal "|" would end
# the cell early and silently shift every later column, and a real newline
# would end the row. Neither occurs in the data today; escaping them keeps a
# future value from corrupting the table the model reads.
escapeMarkdownCell <- function(x) {
  x |>
    gsub("|", "\\|", x = _, fixed = TRUE) |>
    gsub("\r?\n", " ", x = _)
}

# Render a group's rows as a markdown table for the prompt.
renderGroupTable <- function(groupData) {
  tbl <- groupData |>
    dplyr::select(dplyr::all_of(promptColumns)) |>
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

# The candidate block for one group: one markdown table per axis, covering only
# the values that group actually uses. Rows where no candidate cleared the
# threshold are still listed, with an empty "possible fix", so the model can
# see that the value was searched and nothing was found -- rather than the
# value simply being absent and looking like an oversight.
renderCandidates <- function(groupData) {
  blocks <- purrr::map_chr(names(fixedAxes), function(axis) {
    column <- fixedAxes[[axis]]
    values <- sort(unique(groupData[[column]][!is.na(groupData[[column]])]))
    if (length(values) == 0) return("")
    rows <- purrr::map_dfr(values, function(v) {
      hits <- candidates |> dplyr::filter(.data$axe_name == axis, .data$value == v)
      if (nrow(hits) == 0) {
        return(tibble::tibble(
          current = v,
          `possible fix` = paste0("(none scored >= ", scoreThreshold, ")"),
          score = "", n_codes = "", n_events = ""
        ))
      }
      tibble::tibble(
        current = v,
        `possible fix` = hits$concept_name,
        score = sprintf("%.3f", hits$score),
        n_codes = format(as.integer(hits$n_codes), big.mark = ","),
        n_events = format(as.integer(hits$n_events), big.mark = ",")
      )
    }) |>
      dplyr::mutate(dplyr::across(dplyr::everything(), ~ escapeMarkdownCell(trimws(as.character(.x)))))
    paste0(
      "### ", axis, "\n\n",
      "| ", paste(names(rows), collapse = " | "), " |\n",
      "|", paste(rep("---", ncol(rows)), collapse = "|"), "|\n",
      paste(apply(rows, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), collapse = "\n")
    )
  })
  blocks <- blocks[nzchar(blocks)]
  if (length(blocks) == 0) return("(no candidates: this group has no filled free-text axes)")
  paste(blocks, collapse = "\n\n")
}

todo <- groupIds[!file.exists(file.path(cacheDir, paste0(groupIds, ".json")))]
ParallelLogger::logInfo("Groups to send to the LLM: ", length(todo),
                        " (", length(groupIds) - length(todo), " already cached)")

todoItems <- lapply(todo, function(gid) {
  groupData <- dplyr::filter(selected, as.integer(.data$group_id) == gid)
  list(gid = gid, table = renderGroupTable(groupData), candidates = renderCandidates(groupData))
})

fixGroup <- function(item, cacheDir, systemPrompt, dimensionsType, llmConfig,
                     makeClientFactory, ellmerFixFile = "") {
  gid <- item$gid
  outJson <- file.path(cacheDir, paste0(gid, ".json"))

  userMessage <- paste0(
    "Here is group ", gid, ".\n\n",
    "## Candidate OMOP terms for the values used in this group\n\n",
    item$candidates, "\n\n",
    "## The rows\n\n",
    item$table, "\n"
  )
  writeLines(
    paste0("[System Prompt]\n", systemPrompt, "\n\n[Prompt]\n", userMessage),
    file.path(cacheDir, paste0(gid, "_prompt.md"))
  )

  if (nzchar(ellmerFixFile) && file.exists(ellmerFixFile)) source(ellmerFixFile, local = TRUE)

  maxAttempts <- 4L
  res <- NULL
  client <- NULL
  for (attempt in seq_len(maxAttempts)) {
    res <- tryCatch({
      client <- makeClientFactory(llmConfig)()
      client$set_system_prompt(systemPrompt)
      client$chat_structured(userMessage, echo = "none", type = dimensionsType)
    }, error = function(e) {
      ParallelLogger::logWarn("Group ", gid, " attempt ", attempt, "/", maxAttempts, " failed: ", conditionMessage(e))
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
  ParallelLogger::logInfo("Fixing ", length(todoItems), " groups across ", workers, " workers")
  if (workers > 1 && length(todoItems) > 1) {
    cl <- ParallelLogger::makeCluster(workers)
    on.exit(ParallelLogger::stopCluster(cl), add = TRUE)
    ParallelLogger::clusterRequire(cl, "ellmer")
    results <- ParallelLogger::clusterApply(
      cl, todoItems, fixGroup,
      cacheDir = cacheDir, systemPrompt = systemPrompt, dimensionsType = dimensionsType,
      llmConfig = llmConfig, makeClientFactory = makeClientFactory,
      ellmerFixFile = ellmerFixFile, progressBar = TRUE
    )
  } else {
    results <- lapply(todoItems, fixGroup, cacheDir = cacheDir, systemPrompt = systemPrompt,
                      dimensionsType = dimensionsType, llmConfig = llmConfig,
                      makeClientFactory = makeClientFactory, ellmerFixFile = ellmerFixFile)
  }
  nOk <- sum(vapply(results, function(x) isTRUE(x$ok), logical(1)))
  costUsd <- sum(vapply(results, function(x) as.numeric(x$cost), numeric(1)), na.rm = TRUE)
} else {
  nOk <- 0
  costUsd <- 0
}
ParallelLogger::logInfo("Fixed ", nOk, " groups this run (LLM cost USD ", sprintf("%.4f", costUsd), ")")

## Step 3: read the cached answers back and rebuild the table.
answerColumns <- c(unname(fixedAxes), carriedAxes)

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
    for (col in answerColumns) {
      v <- r[[col]]
      # The model returns "" for "not determinable". Normalise it to NA here,
      # at the JSON boundary, so the in-memory table represents missing the
      # same way the rest of the pipeline does (tables are read with na = "").
      # Without this, "" and NA both write out as empty but compare unequal,
      # so any is.na() check downstream silently misreads the column.
      out[[col]] <- if (is.null(v) || length(v) == 0 || !nzchar(trimws(as.character(v)[1]))) {
        NA_character_
      } else {
        trimws(as.character(v)[1])
      }
    }
    v <- r$is_panel
    out$is_panel <- if (is.null(v) || length(v) == 0) NA else as.logical(v)[1]
    tibble::as_tibble(out)
  })
}
`%||%` <- function(x, y) if (is.null(x)) y else x

answers <- purrr::map_dfr(groupIds, readGroupRows)
ParallelLogger::logInfo("Collected ", nrow(answers), " per-row answers from ", length(groupIds), " groups")

# Same join guards as FindLOINCDimensions: a model that echoes an unknown or
# duplicated row_id must not be allowed to shift the table.
expectedRowIds <- selected$row_id
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
  ParallelLogger::logWarn(length(missingIds), " row(s) got no answer; keeping their ORIGINAL axis values")
}

# Replace the seven axis columns with the corrected ones, falling back to the
# original values for any row the model did not answer -- never to empty.
original <- selected |>
  dplyr::select(-dplyr::all_of(c(answerColumns, "is_panel")))
result <- original |>
  dplyr::left_join(answers, by = "row_id") |>
  dplyr::left_join(
    selected |> dplyr::select(row_id, dplyr::all_of(c(answerColumns, "is_panel"))) |>
      dplyr::rename_with(~ paste0(.x, "__orig"), -row_id),
    by = "row_id"
  )
for (col in c(answerColumns, "is_panel")) {
  origCol <- paste0(col, "__orig")
  result[[col]] <- ifelse(result$row_id %in% missingIds, result[[origCol]], result[[col]])
}
result <- result |>
  dplyr::select(-dplyr::ends_with("__orig")) |>
  dplyr::relocate(dplyr::all_of(c(answerColumns, "is_panel")), .after = dplyr::last_col())

# How much actually changed, per axis -- the headline number for this step.
# Joined on row_id rather than compared positionally: a positional comparison
# silently reports nonsense if any join above reorders or drops a row.
changeCounts <- selected |>
  dplyr::select(row_id, dplyr::all_of(unname(fixedAxes))) |>
  dplyr::rename_with(~ paste0(.x, "__before"), -row_id) |>
  dplyr::inner_join(
    result |> dplyr::select(row_id, dplyr::all_of(unname(fixedAxes))),
    by = "row_id"
  )
for (col in unname(fixedAxes)) {
  before <- changeCounts[[paste0(col, "__before")]]
  after <- changeCounts[[col]]
  changed <- sum(!(before == after | (is.na(before) & is.na(after))), na.rm = TRUE) +
    sum(is.na(before) != is.na(after))
  ParallelLogger::logInfo("  ", col, ": ", changed, " / ", nrow(changeCounts), " values changed")
}

result <- result |> dplyr::select(-dplyr::all_of("row_id"))

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
readr::write_tsv(result, pathToFixedTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", pathToFixedTSV)

readr::write_lines(paste(unlist(reflections), collapse = "\n"), pathToReflectionsMD)
ParallelLogger::logInfo("Wrote ", length(reflections), " group reflections to ", pathToReflectionsMD)
