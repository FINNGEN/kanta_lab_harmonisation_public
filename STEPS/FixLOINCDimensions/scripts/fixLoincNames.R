#
# Resolves the guessed LOINC names from FindLOINCDimensions to real OMOP
# concept ids.
#
# FindLOINCDimensions writes one string per local code: the LOINC Long Common
# Name it thinks the code should have. That string is a hypothesis, not a
# concept -- it is spelled like a LOINC name but need not be one. This step
# turns it into an identifier:
#
#   1. every distinct guess is sent to Hecate, a semantic search over the OMOP
#      vocabularies, which returns the closest real standard LOINC concepts in
#      the Measurement domain;
#   2. the hits for all the guesses in one similarity group are pooled and
#      deduplicated, so a concept found by one row's guess is offered to every
#      row of the group -- sibling codes are near-identical strings and the
#      right concept for one is often what another's guess retrieved;
#   3. each candidate is annotated with its rank in the LOINC Top 2000+ (SI)
#      recommended mapping targets, so the model can break ties on an external
#      recommendation rather than on the search score alone. Nothing derived
#      from the curated reference mappings is shown: they are what this
#      pipeline is measured against, so putting them in the prompt would make
#      the evaluation circular;
#   4. the group, its rows and its candidate list go to an LLM, which returns
#      the chosen omop_concept_id per row.
#
# The model may only choose from the candidates it was shown. An id outside
# that set is discarded rather than trusted: the whole value of this step is
# that its output is a real concept, and there is nothing downstream that can
# tell an invented id from a chosen one.
#
# Hecate lookups are deduplicated across the whole run (the same guess recurs
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
top2000File <- args[2]
omopAttributesFile <- args[3]
outDir <- args[4]
nGroups <- if (length(args) >= 5 && nzchar(args[5])) as.integer(args[5]) else NA_integer_
seed <- if (length(args) >= 6 && nzchar(args[6])) as.integer(args[6]) else 1L

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

# Keep candidates at least this similar to a guess. Deliberately looser than
# the 0.75 the axis-based version used: there, the search matched a short axis
# label against another short label of the same kind, and anything below 0.75
# was a different concept. Here it matches a whole invented sentence against
# real LOINC names, so the right concept routinely lands at 0.7-0.8 -- the
# eGFR concepts top out at 0.72 for a well-formed guess. The model is shown the
# score and told what it does and does not mean, so a loose floor costs a few
# extra rows in the prompt rather than a wrong answer.
scoreThreshold <- suppressWarnings(as.numeric(Sys.getenv("HECATE_SCORE_THRESHOLD", "0.5")))
candidateLimit <- suppressWarnings(as.integer(Sys.getenv("HECATE_CANDIDATE_LIMIT", "10")))

cacheDir <- file.path(outDir, "groupsCache")
dir.create(cacheDir, showWarnings = FALSE, recursive = TRUE)
hecateCacheFile <- file.path(outDir, "hecateCandidates.tsv")

pathToMappedTSV <- file.path(outDir, "codesWithOmopConcepts.tsv")
pathToReflectionsMD <- file.path(outDir, "reflections.md")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  inputFile = ", inputFile)
ParallelLogger::logInfo("  top2000File = ", top2000File)
ParallelLogger::logInfo("  omopAttributesFile = ", omopAttributesFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  nGroups = ", if (is.na(nGroups)) "(all)" else nGroups)
ParallelLogger::logInfo("  seed = ", seed)
ParallelLogger::logInfo("  model = ", llmConfig$model)
ParallelLogger::logInfo("  workers = ", workers, " (LLM), ", hecateWorkers, " (Hecate)")
ParallelLogger::logInfo("  scoreThreshold = ", scoreThreshold, ", candidateLimit = ", candidateLimit)

# One entry per input row: the row_id echoed back as the join key, the chosen
# concept id, its name (a cross-check that the id copied is the concept meant),
# a per-part reasoning trail, and one overall certainty. The reasoning is what
# makes a mapping reviewable without re-deriving it: it names the evidence each
# part of the chosen name rests on. All strings, so the model can return "" for
# "no candidate is right".
mappingType <- ellmer::type_object(
  rows = ellmer::type_array(
    ellmer::type_object(
      row_id = ellmer::type_integer("The row_id of the input row, echoed exactly."),
      omop_concept_id = ellmer::type_string("The chosen concept's omop_concept_id, copied digit for digit from the candidate table. Empty if no candidate is right."),
      omop_concept_name = ellmer::type_string("That candidate's omop_concept_name, copied verbatim. Empty if the id is empty."),
      reasoning = ellmer::type_string("Why each part of the chosen name is right: one clause per part, separated by ' ; ', each naming the part and the evidence in the row that carries it. Empty if no concept was chosen."),
      certainty = ellmer::type_string("high | medium | low -- how sure you are, on all the evidence together, that this concept is right for this row. Empty if no concept was chosen.")
    ),
    "One entry per row of the input table."
  ),
  reflection = ellmer::type_string("Short markdown reflection on this group: what could and could not be mapped, gaps in the candidate list, and process problems.")
)

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: all of these files are written by this
# project, so "" (not "NA") is their missing-value marker.
codes <- readr::read_tsv(inputFile, na = "", col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", inputFile)

top2000 <- readr::read_tsv(top2000File, na = "", col_types = readr::cols(
  rank = readr::col_integer(), loinc_code = readr::col_character(),
  concept_id = readr::col_character(), omop_concept_name = readr::col_character(),
  loinc_long_common_name = readr::col_character(), loinc_class = readr::col_character()
))
ParallelLogger::logInfo("Read ", nrow(top2000), " LOINC Top 2000 rows from ", top2000File)

omopAttributes <- readr::read_tsv(omopAttributesFile, na = "", col_types = readr::cols(
  .default = readr::col_character()
))
ParallelLogger::logInfo("Read ", nrow(omopAttributes), " OMOP concepts from ", omopAttributesFile)

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

## Step 1: Hecate candidates for every distinct guessed name.
# Deduplicated across groups -- the same guess recurs in many of them -- and
# cached on disk so a re-run does no network traffic.
wanted <- tibble::tibble(value = sort(unique(selected$loinc_name_guess[!is.na(selected$loinc_name_guess)])))
ParallelLogger::logInfo("Distinct guessed names needing candidates: ", nrow(wanted))

cached <- if (file.exists(hecateCacheFile)) {
  readr::read_tsv(hecateCacheFile, na = "", col_types = readr::cols(
    value = readr::col_character(), concept_name = readr::col_character(),
    concept_id = readr::col_character(), concept_code = readr::col_character(),
    score = readr::col_double()
  ))
} else {
  tibble::tibble(value = character(0), concept_name = character(0),
                 concept_id = character(0), concept_code = character(0), score = numeric(0))
}
# A cached guess may legitimately have zero hits, so presence is tracked by the
# guess having been looked up, not by its having rows.
lookedUp <- if (nrow(cached) > 0) unique(cached$value) else character(0)
todoLookups <- wanted |> dplyr::filter(!.data$value %in% lookedUp)
ParallelLogger::logInfo("Hecate lookups to run: ", nrow(todoLookups),
                        " (", nrow(wanted) - nrow(todoLookups), " already cached)")

if (nrow(todoLookups) > 0) {
  lookupItems <- lapply(todoLookups$value, function(v) list(value = v))
  searchOne <- function(item, hecateFile, candidateLimit) {
    source(hecateFile, local = TRUE)
    hits <- hecateSearch(item$value, limit = candidateLimit)
    if (nrow(hits) == 0) {
      return(list(value = item$value, concept_name = NA_character_,
                  concept_id = NA_character_, concept_code = NA_character_, score = NA_real_))
    }
    lapply(seq_len(nrow(hits)), function(i) {
      list(value = item$value, concept_name = hits$concept_name[i],
           concept_id = hits$concept_id[i], concept_code = hits$concept_code[i],
           score = hits$score[i])
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
    if (!is.null(x$value)) tibble::as_tibble(x) else purrr::map_dfr(x, tibble::as_tibble)
  })
  cached <- dplyr::bind_rows(cached, flat)
  readr::write_tsv(cached, hecateCacheFile, na = "")
  ParallelLogger::logInfo("Cached ", nrow(flat), " new candidate rows to ", hecateCacheFile)
}

# Apply the score threshold, then attach the two priors the prompt asks the
# model to break ties on: the LOINC Top 2000 rank and Finnish usage.
top2000Rank <- top2000 |>
  dplyr::filter(!is.na(.data$concept_id)) |>
  dplyr::group_by(concept_id) |>
  dplyr::summarise(top2000 = min(.data$rank, na.rm = TRUE), .groups = "drop")

# Only the LOINC Top 2000 rank is attached. Finnish usage counts were attached
# here before and are not any more: they are derived from the curated reference
# mappings, which is exactly what this pipeline is measured against, so feeding
# them into the prompt made the evaluation partly circular -- and handed the
# model whatever errors the reference itself carries. The Top 2000 list is an
# independent, external recommendation, so it stays.
candidates <- cached |>
  dplyr::filter(!is.na(.data$concept_name), !is.na(.data$score), .data$score >= scoreThreshold) |>
  dplyr::left_join(top2000Rank, by = "concept_id")
ParallelLogger::logInfo("Kept ", nrow(candidates), " candidate rows at score >= ", scoreThreshold,
                        " (", dplyr::n_distinct(candidates$concept_id), " distinct concepts, ",
                        sum(!is.na(dplyr::distinct(candidates, concept_id, top2000)$top2000)), " of them in the LOINC Top 2000)")

## Step 2: one LLM call per group, with its rows plus the pooled candidate list.
promptColumns <- c(
  "row_id", "TEST_NAME", "UNIT", "unit_share", "evidence_level", "n", "p_missing", "deciles",
  "LongName", "prefix_meaning", "suffix_meaning",
  "loinc_name_guess"
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

renderGroupTable <- function(groupData) {
  renderMarkdownTable(dplyr::select(groupData, dplyr::all_of(promptColumns)))
}

# The candidate set for one group: every concept any of its guesses retrieved,
# deduplicated by concept_id keeping the best score, ordered best first.
candidatesFor <- function(groupData) {
  guesses <- unique(groupData$loinc_name_guess[!is.na(groupData$loinc_name_guess)])
  if (length(guesses) == 0) return(candidates[0, ])
  candidates |>
    dplyr::filter(.data$value %in% guesses) |>
    dplyr::group_by(concept_id) |>
    dplyr::slice_max(.data$score, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::arrange(dplyr::desc(.data$score))
}

renderCandidates <- function(groupCandidates) {
  if (nrow(groupCandidates) == 0) {
    return("(no candidates: the search returned nothing for this group's guesses, or no row was named)")
  }
  renderMarkdownTable(tibble::tibble(
    omop_concept_id = groupCandidates$concept_id,
    omop_concept_name = groupCandidates$concept_name,
    score = sprintf("%.3f", groupCandidates$score),
    top2000 = ifelse(is.na(groupCandidates$top2000), "", as.character(groupCandidates$top2000))
  ))
}

todo <- groupIds[!file.exists(file.path(cacheDir, paste0(groupIds, ".json")))]
ParallelLogger::logInfo("Groups to send to the LLM: ", length(todo),
                        " (", length(groupIds) - length(todo), " already cached)")

todoItems <- lapply(todo, function(gid) {
  groupData <- dplyr::filter(selected, as.integer(.data$group_id) == gid)
  list(gid = gid, table = renderGroupTable(groupData),
       candidates = renderCandidates(candidatesFor(groupData)))
})

fixGroup <- function(item, cacheDir, systemPrompt, mappingType, llmConfig,
                     makeClientFactory, ellmerFixFile = "") {
  gid <- item$gid
  outJson <- file.path(cacheDir, paste0(gid, ".json"))

  userMessage <- paste0(
    "Here is group ", gid, ".\n\n",
    "## Candidate OMOP concepts for this group\n\n",
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
      client$chat_structured(userMessage, echo = "none", type = mappingType)
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
  ParallelLogger::logInfo("Mapping ", length(todoItems), " groups across ", workers, " workers")
  if (workers > 1 && length(todoItems) > 1) {
    cl <- ParallelLogger::makeCluster(workers)
    on.exit(ParallelLogger::stopCluster(cl), add = TRUE)
    ParallelLogger::clusterRequire(cl, "ellmer")
    results <- ParallelLogger::clusterApply(
      cl, todoItems, fixGroup,
      cacheDir = cacheDir, systemPrompt = systemPrompt, mappingType = mappingType,
      llmConfig = llmConfig, makeClientFactory = makeClientFactory,
      ellmerFixFile = ellmerFixFile, progressBar = TRUE
    )
  } else {
    results <- lapply(todoItems, fixGroup, cacheDir = cacheDir, systemPrompt = systemPrompt,
                      mappingType = mappingType, llmConfig = llmConfig,
                      makeClientFactory = makeClientFactory, ellmerFixFile = ellmerFixFile)
  }
  nOk <- sum(vapply(results, function(x) isTRUE(x$ok), logical(1)))
  costUsd <- sum(vapply(results, function(x) as.numeric(x$cost), numeric(1)), na.rm = TRUE)
} else {
  nOk <- 0
  costUsd <- 0
}
ParallelLogger::logInfo("Mapped ", nOk, " groups this run (LLM cost USD ", sprintf("%.4f", costUsd), ")")

## Step 3: read the cached answers back, validate the ids, rebuild the table.
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
    # The model returns "" for "no candidate is right". Normalise it to NA here,
    # at the JSON boundary, so the in-memory table represents missing the same
    # way the rest of the pipeline does (tables are read with na = ""). Without
    # this, "" and NA both write out as empty but compare unequal, so any
    # is.na() check downstream silently misreads the column.
    blankToNA <- function(v) {
      if (is.null(v) || length(v) == 0 || !nzchar(trimws(as.character(v)[1]))) NA_character_
      else trimws(as.character(v)[1])
    }
    # Certainty is normalised to the three allowed words; anything else the
    # model invents becomes NA rather than being carried into the table as a
    # value downstream code would have to guess the meaning of.
    certaintyOf <- function(v) {
      x <- tolower(blankToNA(v))
      if (is.na(x) || !(x %in% c("high", "medium", "low"))) NA_character_ else x
    }
    # A newline in the reasoning would break the TSV row it is written to.
    reasoningOf <- function(v) {
      x <- blankToNA(v)
      if (is.na(x)) NA_character_ else gsub("[\r\n]+", " ", x)
    }
    tibble::tibble(
      group_id = as.character(gid),
      row_id = as.integer(r$row_id %||% NA_integer_),
      omop_concept_id = blankToNA(r$omop_concept_id),
      model_concept_name = blankToNA(r$omop_concept_name),
      reasoning = reasoningOf(r$reasoning),
      certainty = certaintyOf(r$certainty)
    )
  })
}

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
  ParallelLogger::logWarn(length(missingIds), " row(s) got no answer; they stay unmapped")
}

# Validate every returned id against the candidates that row's own group was
# shown. An id from outside that set was not chosen from the evidence -- it was
# produced from memory or invented -- and this step exists precisely so that
# what comes out of it is a concept the search actually found.
offered <- purrr::map_dfr(groupIds, function(gid) {
  groupCandidates <- candidatesFor(dplyr::filter(selected, as.integer(.data$group_id) == gid))
  if (nrow(groupCandidates) == 0) return(NULL)
  tibble::tibble(group_id = as.character(gid), omop_concept_id = groupCandidates$concept_id)
})
answers <- answers |>
  dplyr::mutate(
    offeredHere = paste(.data$group_id, .data$omop_concept_id) %in%
      paste(offered$group_id, offered$omop_concept_id)
  )
nNotOffered <- sum(!is.na(answers$omop_concept_id) & !answers$offeredHere)
if (nNotOffered > 0) {
  ParallelLogger::logWarn(nNotOffered, " returned concept_id(s) were not in that group's candidate list; ",
                          "discarding them (the row stays unmapped)")
  answers$omop_concept_id[!answers$offeredHere] <- NA_character_
}

# The concept NAME comes from the OMOP vocabulary, never from the model: the
# model's copy is only used to detect that it meant a different concept than
# the id it typed.
omopNames <- omopAttributes |> dplyr::select(concept_id, omop_concept_name = concept_name)
answers <- answers |>
  dplyr::left_join(omopNames, by = c("omop_concept_id" = "concept_id"))
# na.rm: an id the vocabulary does not know has no omop_concept_name to compare
# against, so the comparison is NA there. That case is counted separately, just
# below, as nUnknownToOmop.
nNameMismatch <- sum(!is.na(answers$omop_concept_id) & !is.na(answers$model_concept_name) &
                       answers$model_concept_name != answers$omop_concept_name, na.rm = TRUE)
if (nNameMismatch > 0) {
  ParallelLogger::logWarn(nNameMismatch, " row(s) returned a concept name that differs from the ",
                          "OMOP name of the id they chose; keeping the OMOP name")
}
nUnknownToOmop <- sum(!is.na(answers$omop_concept_id) & is.na(answers$omop_concept_name))
if (nUnknownToOmop > 0) {
  ParallelLogger::logWarn(nUnknownToOmop, " chosen concept_id(s) are not in the OMOP attributes table")
}

# A certainty or a reasoning trail only means something next to a concept: if
# the id was discarded as not-offered, or the model returned none, anything it
# wrote describes a choice that is not in the table, so it is cleared with it.
answers <- answers |>
  dplyr::mutate(dplyr::across(
    dplyr::all_of(c("reasoning", "certainty")),
    ~ ifelse(is.na(.data$omop_concept_id), NA_character_, .x)
  ))

result <- selected |>
  dplyr::left_join(
    answers |> dplyr::select(row_id, omop_concept_id, omop_concept_name,
                             reasoning, certainty),
    by = "row_id"
  ) |>
  dplyr::select(-dplyr::all_of("row_id"))

counts <- table(factor(result$certainty, levels = c("high", "medium", "low")), useNA = "no")
ParallelLogger::logInfo("  certainty: ",
                        paste(names(counts), counts, sep = "=", collapse = ", "),
                        ", not stated=", sum(is.na(result$certainty)))
ParallelLogger::logInfo("  reasoning given for ", sum(!is.na(result$reasoning)), " / ",
                        sum(!is.na(result$omop_concept_id)), " mapped rows")

nMapped <- sum(!is.na(result$omop_concept_id))
ParallelLogger::logInfo(nMapped, " / ", nrow(result), " rows were mapped to an OMOP concept (",
                        dplyr::n_distinct(result$omop_concept_id[!is.na(result$omop_concept_id)]),
                        " distinct concepts)")

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
readr::write_tsv(result, pathToMappedTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", pathToMappedTSV)

readr::write_lines(paste(unlist(reflections), collapse = "\n"), pathToReflectionsMD)
ParallelLogger::logInfo("Wrote ", length(reflections), " group reflections to ", pathToReflectionsMD)
