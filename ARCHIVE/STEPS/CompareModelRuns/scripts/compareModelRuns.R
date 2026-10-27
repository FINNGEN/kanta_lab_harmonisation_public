#
# Compares two or more runs of the LLM steps of this pipeline against each
# other and against the curated reference mapping.
#
# The pipeline's answer depends on which model answered the prompts. Running
# the same 30 similarity groups through a different model writes a parallel
# data folder (DATA, DATA_sonnet, DATA_opus), and this step reads those folders
# side by side and puts the numbers in one table.
#
# Two quite different questions are answered, and they are kept apart:
#
#   1. AGAINST THE REFERENCE -- for each run on its own, how often does it
#      produce the same OMOP concept as the curated Finnish mapping, over the
#      rows both cover? This repeats 6_EvaluateMapping's own cross-check, on the
#      same join key and the same four outcomes, so every run is measured the
#      way that step already measures one. It is agreement, not correctness:
#      the reference is the best mapping available, not ground truth.
#
#   2. AGAINST EACH OTHER -- on the rows all runs share, how often do two runs
#      choose the same concept? This needs no reference at all, so it also
#      covers the ~60% of rows the reference has no APPROVED answer for. Two
#      models agreeing there is weak evidence the concept is right; two models
#      disagreeing marks the row as one a human should look at.
#
# Everything here is deterministic -- no LLM call. The runs have already been
# made; this step only reads them.
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
referenceMappingFile <- args[1]
outDir <- args[2]
runSpecs <- args[-(1:2)]

# Records above which a code counts as high-volume. Same default and same
# reason as 6_EvaluateMapping: the curated reference was built mostly for the
# codes that carry real data volume, so a single agreement figure over the
# whole overlap mixes the codes it was written for with ones it barely touches.
volumeThreshold <- suppressWarnings(as.numeric(Sys.getenv("VOLUME_THRESHOLD", "500")))

# <LABEL>=<PATH>, in the order given on the command line. The first run is the
# BASELINE: pairwise comparisons are drawn against it, and it is the run the
# others are read as alternatives to.
runs <- tibble::tibble(
  label = sub("=.*$", "", runSpecs),
  path = sub("^[^=]*=", "", runSpecs)
)

pathToReportMD <- file.path(outDir, "modelComparisonStats.md")
pathToPerRowTSV <- file.path(outDir, "perRowComparison.tsv")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  referenceMappingFile = ", referenceMappingFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  volumeThreshold = ", volumeThreshold)
for (i in seq_len(nrow(runs))) {
  ParallelLogger::logInfo("  run ", i, ": ", runs$label[i], " = ", runs$path[i],
                          if (i == 1) "  (baseline)" else "")
}

#
# --- Input -------------------------------------------------------------
#
# na = "" per development/STYLE.md: these files were written by this project.
readRun <- function(label, path) {
  f <- file.path(path, "6_EvaluateMapping", "codesWithOMOP.tsv")
  tbl <- readr::read_tsv(f, na = "", col_types = readr::cols(.default = readr::col_character()))
  ParallelLogger::logInfo("Read ", nrow(tbl), " rows from ", f)
  # Columns an older run may not carry. Added empty rather than left missing so
  # one stale run degrades a column instead of aborting the comparison.
  for (col in c("evidence_level", "certainty", "loinc_name_guess",
                "omop_concept_id", "omop_concept_name", "n", "mapped")) {
    if (!col %in% names(tbl)) {
      ParallelLogger::logWarn(label, ": no `", col, "` column; reporting it as empty")
      tbl[[col]] <- NA_character_
    }
  }
  tbl |>
    dplyr::transmute(
      run = label,
      TEST_NAME = .data$TEST_NAME,
      UNIT = .data$UNIT,
      group_id = .data$group_id,
      evidence_level = .data$evidence_level,
      records = suppressWarnings(as.numeric(.data$n)),
      loinc_name_guess = .data$loinc_name_guess,
      omop_concept_id = .data$omop_concept_id,
      omop_concept_name = .data$omop_concept_name,
      certainty = .data$certainty,
      # 6_EvaluateMapping's own flag: a chosen id AND that id present in the OMOP
      # vocabulary snapshot. A handful of ids per run are not (the model copied
      # a real-looking id the snapshot does not carry), and that step counts
      # them as unmapped -- so coverage here counts them the same way, or the
      # two reports would disagree on the same run.
      mapped = .data$mapped == "TRUE"
    )
}

runTables <- purrr::pmap(list(runs$label, runs$path), readRun)
names(runTables) <- runs$label
allRows <- dplyr::bind_rows(runTables)

# What the LLM steps cost, straight out of the line each one logs. Reported
# beside the agreement figures because a model that agrees one point more for
# five times the money is a different proposition from one that does it free.
readCost <- function(path) {
  total <- 0
  found <- FALSE
  for (step in c("4_FindLOINC", "5_FixLOINC")) {
    f <- file.path(path, step, "log.txt")
    if (!file.exists(f)) next
    hits <- grep("LLM cost USD", readLines(f, warn = FALSE), value = TRUE)
    if (length(hits) == 0) next
    amounts <- suppressWarnings(as.numeric(sub(".*LLM cost USD\\s+([0-9.]+).*", "\\1", hits)))
    amounts <- amounts[!is.na(amounts)]
    if (length(amounts) == 0) next
    # One line per run of the step; a resumed run logs only what it paid that
    # time, so the lines are summed rather than the last one taken.
    total <- total + sum(amounts)
    found <- TRUE
  }
  if (found) total else NA_real_
}
runs$cost_usd <- purrr::map_dbl(runs$path, readCost)

reference <- readr::read_tsv(referenceMappingFile, show_col_types = FALSE)
ParallelLogger::logInfo("Read ", nrow(reference), " rows from ", referenceMappingFile)

#
# --- Action -------------------------------------------------------------
#
.formatPct <- function(x, d = 1) ifelse(is.na(x), "", sprintf(paste0("%.", d, "f%%"), 100 * x))

.markdownTable <- function(df) {
  df <- df |> dplyr::mutate(dplyr::across(dplyr::everything(), ~ ifelse(is.na(.x), "", as.character(.x))))
  c(
    paste0("| ", paste(names(df), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|"),
    apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

# A literal "|" would end a markdown cell early and shift every later column.
.escapeCell <- function(x) gsub("|", "\\|", ifelse(is.na(x), "", as.character(x)), fixed = TRUE)

## The reference, reduced to its APPROVED rows, keyed exactly as 6_EvaluateMapping
## keys it: TEST_NAME + UNIT, with an empty UNIT a unit value in its own right.
testIdParts <- stringr::str_match(reference$testId, "^(.*) \\[(.*)\\]$")
approved <- reference |>
  dplyr::mutate(TEST_NAME = testIdParts[, 2], UNIT = dplyr::na_if(testIdParts[, 3], "")) |>
  dplyr::filter(status == "APPROVED", !is.na(.data$TEST_NAME)) |>
  dplyr::distinct(.data$TEST_NAME, .data$UNIT, .data$OMOP_CONCEPT_ID, .data$OMOP_CONCEPT_NAME)
refKey <- paste(approved$TEST_NAME, approved$UNIT, sep = "\r")
refConcept <- stats::setNames(as.character(approved$OMOP_CONCEPT_ID), refKey)
refName <- stats::setNames(as.character(approved$OMOP_CONCEPT_NAME), refKey)
ParallelLogger::logInfo("Reference holds ", length(refKey), " APPROVED TEST_NAME+UNIT rows")

allRows <- allRows |>
  dplyr::mutate(
    key = paste(.data$TEST_NAME, .data$UNIT, sep = "\r"),
    reference_concept_id = unname(refConcept[.data$key]),
    in_reference = !is.na(.data$reference_concept_id),
    # The same four outcomes 6_EvaluateMapping reports, computed the same way, so
    # a per-run figure here can be checked against that run's own report.
    outcome = dplyr::case_when(
      !.data$in_reference ~ "not in reference",
      is.na(.data$omop_concept_id) ~ "not automapped",
      .data$omop_concept_id == .data$reference_concept_id ~ "agreement",
      TRUE ~ "disagreement"
    )
  )

## Table 1: coverage and agreement, one row per run.
perRun <- allRows |>
  dplyr::group_by(run) |>
  dplyr::summarise(
    rows = dplyr::n(),
    named = sum(!is.na(.data$loinc_name_guess)),
    distinct_concepts = dplyr::n_distinct(.data$omop_concept_id[which(.data$mapped)]),
    mapped = sum(.data$mapped, na.rm = TRUE),
    overlap = sum(.data$in_reference),
    answered_in_overlap = sum(.data$in_reference & !is.na(.data$omop_concept_id)),
    agree = sum(.data$outcome == "agreement"),
    agree_evidenced = sum(.data$outcome == "agreement" &
                            .data$evidence_level != "name", na.rm = TRUE),
    overlap_evidenced = sum(.data$in_reference & .data$evidence_level != "name", na.rm = TRUE),
    agree_highvolume = sum(.data$outcome == "agreement" &
                             .data$records >= volumeThreshold, na.rm = TRUE),
    overlap_highvolume = sum(.data$in_reference & .data$records >= volumeThreshold, na.rm = TRUE),
    .groups = "drop"
  ) |>
  # Restore the command-line order: group_by sorts alphabetically, and the
  # baseline must stay first for the report to read as a comparison against it.
  dplyr::arrange(match(.data$run, runs$label)) |>
  dplyr::left_join(dplyr::select(runs, run = label, cost_usd), by = "run")

ParallelLogger::logInfo("Per-run agreement over the reference overlap:")
for (i in seq_len(nrow(perRun))) {
  ParallelLogger::logInfo("  ", perRun$run[i], ": ", perRun$agree[i], " / ", perRun$overlap[i],
                          " = ", .formatPct(perRun$agree[i] / max(perRun$overlap[i], 1)),
                          " (cost USD ", sprintf("%.2f", perRun$cost_usd[i]), ")")
}

# Built with mutate + select rather than one transmute: a transmute that
# rewrites `named` into a display string would shadow the number the next
# expression needs to divide by.
coverageTable <- perRun |>
  dplyr::mutate(
    namedCell = sprintf("%d (%s)", .data$named, .formatPct(.data$named / .data$rows)),
    mappedCell = sprintf("%d (%s)", .data$mapped,
                         .formatPct(.data$mapped / pmax(.data$named, 1))),
    costCell = ifelse(is.na(.data$cost_usd), "", sprintf("%.2f", .data$cost_usd))
  ) |>
  dplyr::select(run = "run", rows = "rows", named = "namedCell",
                mapped_of_named = "mappedCell", distinct_concepts = "distinct_concepts",
                cost_usd = "costCell")

agreementTable <- perRun |>
  dplyr::mutate(
    answeredCell = sprintf("%d (%s)", .data$answered_in_overlap,
                           .formatPct(.data$answered_in_overlap / pmax(.data$overlap, 1))),
    agreementCell = sprintf("%d (%s)", .data$agree, .formatPct(.data$agree / pmax(.data$overlap, 1))),
    agreementOfAnsweredCell = .formatPct(.data$agree / pmax(.data$answered_in_overlap, 1)),
    agreementEvidencedCell = sprintf("%d / %d (%s)", .data$agree_evidenced, .data$overlap_evidenced,
                                     .formatPct(.data$agree_evidenced / pmax(.data$overlap_evidenced, 1))),
    agreementHighVolumeCell = sprintf("%d / %d (%s)", .data$agree_highvolume, .data$overlap_highvolume,
                                      .formatPct(.data$agree_highvolume / pmax(.data$overlap_highvolume, 1)))
  ) |>
  dplyr::select(run = "run", overlap = "overlap", answered = "answeredCell",
                agreement = "agreementCell",
                agreement_of_answered = "agreementOfAnsweredCell",
                agreement_evidenced = "agreementEvidencedCell",
                agreement_highvolume = "agreementHighVolumeCell")

## Table 2: the four outcomes, one column per run.
outcomeLevels <- c("not in reference", "not automapped", "disagreement", "agreement")
outcomeTable <- allRows |>
  dplyr::group_by(run = .data$run, outcome = .data$outcome) |>
  dplyr::summarise(n = dplyr::n(), .groups = "drop") |>
  dplyr::mutate(outcome = factor(.data$outcome, levels = outcomeLevels)) |>
  tidyr::complete(run = runs$label, outcome = factor(outcomeLevels, levels = outcomeLevels),
                  fill = list(n = 0L)) |>
  dplyr::left_join(dplyr::select(perRun, run, rows), by = "run") |>
  dplyr::mutate(cell = sprintf("%d (%s)", .data$n, .formatPct(.data$n / .data$rows))) |>
  dplyr::select("run", "outcome", "cell") |>
  tidyr::pivot_wider(names_from = "run", values_from = "cell") |>
  dplyr::arrange(.data$outcome) |>
  dplyr::select(dplyr::all_of(c("outcome", runs$label)))

## Table 3: agreement by evidence level, one column per run. This is the split
## that matters most: a `name`-only row has nothing to fix its quantity with,
## so it is where the runs are allowed to differ most and where declining is
## the intended answer rather than a failure.
byEvidence <- allRows |>
  dplyr::filter(.data$in_reference) |>
  dplyr::mutate(evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)")) |>
  dplyr::group_by(.data$evidence_level, .data$run) |>
  dplyr::summarise(
    cell = sprintf("%d / %d (%s)", sum(.data$outcome == "agreement"), dplyr::n(),
                   .formatPct(sum(.data$outcome == "agreement") / dplyr::n())),
    n = dplyr::n(), .groups = "drop"
  ) |>
  dplyr::group_by(.data$evidence_level) |>
  dplyr::mutate(order_n = max(.data$n)) |>
  dplyr::ungroup() |>
  dplyr::select(-dplyr::all_of("n")) |>
  tidyr::pivot_wider(names_from = "run", values_from = "cell") |>
  dplyr::arrange(dplyr::desc(.data$order_n)) |>
  dplyr::select(dplyr::all_of(c("evidence_level", runs$label)))

## Table 4: run against run, on the rows they share. Needs no reference, so it
## also covers the rows the reference has no APPROVED answer for -- which is
## most of them.
wide <- allRows |>
  dplyr::select("run", "key", "omop_concept_id") |>
  tidyr::pivot_wider(names_from = "run", values_from = "omop_concept_id")
sharedKeys <- wide |> dplyr::filter(dplyr::if_all(dplyr::all_of(runs$label), ~ TRUE))
ParallelLogger::logInfo("Rows present in every run: ", nrow(sharedKeys))

pairwise <- if (nrow(runs) >= 2) {
  pairs <- utils::combn(runs$label, 2, simplify = FALSE)
  purrr::map_dfr(pairs, function(p) {
    a <- sharedKeys[[p[1]]]
    b <- sharedKeys[[p[2]]]
    bothMapped <- !is.na(a) & !is.na(b)
    tibble::tibble(
      pair = paste(p[1], "vs", p[2]),
      rows = length(a),
      both_mapped = sprintf("%d (%s)", sum(bothMapped), .formatPct(mean(bothMapped))),
      same_concept = sprintf("%d (%s)", sum(bothMapped & a == b),
                             .formatPct(sum(bothMapped & a == b) / max(sum(bothMapped), 1))),
      only_first = sum(!is.na(a) & is.na(b)),
      only_second = sum(is.na(a) & !is.na(b)),
      neither = sum(is.na(a) & is.na(b))
    )
  })
} else {
  tibble::tibble()
}

## Table 5: where the reference has an answer and the runs split on it -- one
## run agrees with the reference and another does not. These are the rows that
## actually separate the models, so they are listed rather than counted.
baseline <- runs$label[1]
splitExamples <- allRows |>
  dplyr::filter(.data$in_reference) |>
  dplyr::select("run", "key", "TEST_NAME", "UNIT", "evidence_level",
                "outcome", "omop_concept_name", "reference_concept_id") |>
  dplyr::group_by(.data$key) |>
  dplyr::filter(dplyr::n_distinct(.data$outcome == "agreement") > 1) |>
  dplyr::ungroup()

nSplit <- dplyr::n_distinct(splitExamples$key)
ParallelLogger::logInfo(nSplit, " reference-covered rows where the runs disagree about the reference")

# Sampled, not headed: taking the head draws ten spellings of one code failing
# the same way. Seeded so a re-run on the same data shows the same examples.
set.seed(1)
shownKeys <- if (nSplit > 0) {
  sample(unique(splitExamples$key), min(nSplit, 15))
} else {
  character(0)
}
splitTable <- if (length(shownKeys) > 0) {
  splitExamples |>
    dplyr::filter(.data$key %in% shownKeys) |>
    dplyr::mutate(cell = paste0(
      ifelse(.data$outcome == "agreement", "OK ", "-- "),
      .escapeCell(dplyr::coalesce(.data$omop_concept_name, "(declined)"))
    )) |>
    dplyr::select("key", "TEST_NAME", "UNIT", "evidence_level", "run", "cell") |>
    tidyr::pivot_wider(names_from = "run", values_from = "cell") |>
    dplyr::mutate(
      TEST_NAME = .escapeCell(.data$TEST_NAME),
      UNIT = .escapeCell(.data$UNIT),
      reference = .escapeCell(unname(refName[.data$key]))
    ) |>
    dplyr::select(dplyr::all_of(c("TEST_NAME", "UNIT", "evidence_level", "reference", runs$label)))
} else {
  tibble::tibble()
}

## The per-row table behind all of the above, written out so the comparison can
## be re-cut without re-deriving it: one row per local code, one column per run.
perRow <- allRows |>
  dplyr::select("run", "key", "TEST_NAME", "UNIT", "group_id",
                "evidence_level", "records", "reference_concept_id",
                "omop_concept_id", "omop_concept_name",
                "loinc_name_guess", "certainty") |>
  tidyr::pivot_wider(
    id_cols = dplyr::all_of(c("key", "TEST_NAME", "UNIT", "group_id", "evidence_level",
                              "records", "reference_concept_id")),
    names_from = "run",
    values_from = dplyr::all_of(c("omop_concept_id", "omop_concept_name",
                                  "loinc_name_guess", "certainty"))
  ) |>
  dplyr::select(-dplyr::all_of("key"))

#
# --- Output -------------------------------------------------------------
#
report <- c(
  "# Model comparison -- Stats",
  "",
  paste0("Runs compared (the first is the baseline): ",
         paste0("`", runs$label, "` (`", runs$path, "`)", collapse = ", "), "."),
  "",
  "Every run processed the same similarity groups of the same input table",
  "through the same system prompts; only the model differs. Two things are",
  "measured, and they answer different questions:",
  "",
  "1. **Against the reference** — how often each run produces the same OMOP",
  "   concept as the curated Finnish mapping, over the rows both cover. This is",
  "   6_EvaluateMapping's own cross-check, repeated per run on the same join key",
  "   (`TEST_NAME` + `UNIT`, an empty `UNIT` counting as a unit) and the same",
  "   four outcomes. It is **agreement, not correctness**: the reference is the",
  "   best mapping available, not ground truth, and carries errors of its own.",
  "2. **Against each other** — how often two runs choose the same concept, on",
  "   the rows they share. This needs no reference, so it also covers the rows",
  "   the reference has no `APPROVED` answer for, which is most of them.",
  "",
  "## Coverage and cost",
  "",
  "`named` is how many rows `4_FindLOINC` could write a LOINC name for;",
  "`mapped` how many of them `5_FixLOINC` then resolved to a real OMOP",
  "concept. Coverage is easy to inflate by never declining, so it is reported",
  "next to agreement, never instead of it. `cost_usd` is what the two LLM steps",
  "logged for that run.",
  "",
  .markdownTable(coverageTable),
  "",
  "## Agreement with the reference",
  "",
  "`overlap` is the rows with an `APPROVED` reference mapping. `agreement` is",
  "over that whole overlap; `agreement_of_answered` drops the rows the run",
  "declined, so the two together show whether a run buys agreement by",
  "abstaining. `agreement_evidenced` restricts to rows carrying a unit, values,",
  paste0("or both; `agreement_highvolume` to codes with >= ", format(volumeThreshold, big.mark = ","),
         " records — the"),
  "range the reference was actually curated for.",
  "",
  .markdownTable(agreementTable),
  "",
  "## Outcomes",
  "",
  "- **not in reference** — no `APPROVED` reference mapping for this row, so",
  "  there is nothing to compare against. Identical across runs by construction:",
  "  it depends on the reference and the input table, not on the model.",
  "- **not automapped** — the reference has the code, the run declined every",
  "  candidate. For a code with no unit and no values that is the intended",
  "  answer, not a failure.",
  "- **disagreement** — the run produced an id, the reference has another.",
  "- **agreement** — same id as the reference.",
  "",
  .markdownTable(outcomeTable),
  "",
  "## Agreement by evidence level",
  "",
  "What the local row actually carried. A `name`-only row has nothing that",
  "fixes its quantity, so `5_FixLOINC` is meant to decline there unless",
  "the name alone settles the concept — which makes this the split where the",
  "models are most free to differ, and where a higher number is not",
  "automatically better.",
  "",
  .markdownTable(byEvidence),
  "",
  "## Run against run",
  "",
  "On the rows every run covers. `same_concept` is out of the rows **both**",
  "runs mapped, so declines do not count as agreement. Rows where two models",
  "independently land on the same concept are weak evidence it is right; rows",
  "where they split are the ones worth a human's time.",
  "",
  if (nrow(pairwise) > 0) .markdownTable(pairwise) else "(only one run — nothing to compare)",
  "",
  "## Where the runs split on the reference",
  "",
  paste0("Rows the reference has an `APPROVED` answer for and where at least one",
         " run agrees with it and at least one does not — ", nSplit, " in total, ",
         length(shownKeys), " shown, sampled by row so one recurring code cannot fill the table."),
  "`OK` marks the run that matched the reference; `--` one that did not, followed",
  "by what it chose instead (or `(declined)` where it chose nothing).",
  "",
  if (nrow(splitTable) > 0) .markdownTable(splitTable) else "(no row splits the runs)",
  ""
)

readr::write_lines(report, pathToReportMD)
ParallelLogger::logInfo("Wrote comparison report to ", pathToReportMD)

readr::write_tsv(perRow, pathToPerRowTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(perRow), " per-row comparisons to ", pathToPerRowTSV)
