#
# Reports on the final local-code -> OMOP concept mapping.
#
# The number that actually matters is the last section: how often this
# pipeline's concept AGREES with the curated Finnish mapping on the codes both
# cover. Agreement, not correctness -- the reference is the best mapping
# available, not ground truth, and it carries errors and internal
# inconsistencies of its own. Coverage (how many codes got any concept) is easy
# to inflate by guessing, so it is reported next to agreement, never instead of
# it, and both are broken out by how much evidence the local row actually had.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
codesWithOmopFile <- args[1]
referenceMappingFile <- args[2]
outDir <- args[3]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithOmopFile = ", codesWithOmopFile)
ParallelLogger::logInfo("  referenceMappingFile = ", referenceMappingFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
codes <- readr::read_tsv(codesWithOmopFile, show_col_types = FALSE, na = "",
                         col_types = readr::cols(.default = readr::col_character()))
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", codesWithOmopFile)

# Columns the report reads but an older upstream run may not have written. Added
# as empty rather than left missing so a schema change upstream degrades the
# report by one blank column instead of aborting the whole run.
for (col in c("evidence_level", "certainty", "reasoning")) {
  if (!col %in% names(codes)) {
    ParallelLogger::logWarn("Input has no `", col, "` column; reporting it as empty")
    codes[[col]] <- NA_character_
  }
}

#
# --- Action -------------------------------------------------------------
#
codes <- codes |>
  dplyr::mutate(
    named = !is.na(.data$loinc_name_guess),
    matched = .data$mapped == "TRUE"
  )
nRows <- nrow(codes)

.formatPct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

.markdownTable <- function(df) {
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  c(header, sep, rows)
}

# Table 1: every row, split by whether a name was guessed for it at all.
overviewAll <- tibble::tibble(
  bucket = c("total", "named by FindLOINCDimensions", "left unnamed"),
  n = c(nRows, sum(codes$named), sum(!codes$named))
) |>
  dplyr::mutate(pct = .formatPct(n / nRows))

# Table 2: only rows a mapping was attempted for -- the meaningful denominator.
attempted <- codes |> dplyr::filter(named)
nAttempted <- nrow(attempted)
overviewAttempted <- tibble::tibble(
  bucket = c("attempted (a name was guessed)",
             "mapped to an OMOP concept",
             "unmapped (no candidate was right)",
             "distinct concepts used"),
  n = c(nAttempted, sum(attempted$matched), sum(!attempted$matched),
        dplyr::n_distinct(attempted$omop_concept_id[attempted$matched]))
) |>
  dplyr::mutate(pct = ifelse(bucket == "distinct concepts used", "", .formatPct(n / max(nAttempted, 1))))

ParallelLogger::logInfo(
  sum(codes$named), " / ", nRows, " rows were named; ",
  sum(attempted$matched), " / ", nAttempted, " of those mapped to an OMOP concept"
)

# By domain: the match rate within each specimen/system, taken from the OMOP
# concept that was chosen. Unmapped rows have no system of their own to group
# by -- the axes were never inferred in this approach -- so they are counted
# together under (unmapped).
byDomain <- codes |>
  dplyr::mutate(omop_has_system = ifelse(matched, dplyr::coalesce(.data$omop_has_system, "(none)"), "(unmapped)")) |>
  dplyr::group_by(omop_has_system) |>
  dplyr::summarise(n_rows = dplyr::n(), .groups = "drop") |>
  dplyr::mutate(pct_of_rows = .formatPct(n_rows / nRows)) |>
  dplyr::arrange(dplyr::desc(n_rows))

ParallelLogger::logInfo("Grouped the mapped rows into ", nrow(byDomain) - 1, " OMOP systems")

# Cross-check against DATA/ReferenceMappings/lab_data_summary.csv, a
# separately curated Finnish-code -> OMOP mapping (testId = "TEST_NAME
# [UNIT]"). Degrades gracefully: the rest of the report still gets written if
# this section can't be computed.
referenceSection <- c(
  "## Cross-check against the reference mapping",
  "",
  paste0("`", referenceMappingFile, "` was not found -- skipping this section.")
)
if (file.exists(referenceMappingFile)) {
  reference <- readr::read_tsv(referenceMappingFile, show_col_types = FALSE)
  ParallelLogger::logInfo("Read ", nrow(reference), " rows from ", referenceMappingFile)

  testIdParts <- stringr::str_match(reference$testId, "^(.*) \\[(.*)\\]$")
  approved <- reference |>
    dplyr::mutate(TEST_NAME = testIdParts[, 2], UNIT = dplyr::na_if(testIdParts[, 3], "")) |>
    dplyr::filter(status == "APPROVED", !is.na(TEST_NAME)) |>
    dplyr::distinct(TEST_NAME, UNIT, OMOP_CONCEPT_ID, OMOP_CONCEPT_NAME)

  checked <- codes |>
    dplyr::inner_join(approved, by = c("TEST_NAME", "UNIT"))

  agrees <- !is.na(checked$omop_concept_id) &
    checked$omop_concept_id == as.character(checked$OMOP_CONCEPT_ID)
  nChecked <- nrow(checked)
  nAgree <- sum(agrees)
  # Of the overlap rows this pipeline actually answered, how often did it agree?
  # Coverage and agreement pull in opposite directions, so reporting only the
  # first would let a step look good by mapping everything.
  nAnswered <- sum(!is.na(checked$omop_concept_id))
  ParallelLogger::logInfo(
    nChecked, " rows overlap an APPROVED reference mapping; ",
    nAnswered, " of them got a concept; ",
    nAgree, " (", .formatPct(nAgree / max(nChecked, 1)), " of the overlap, ",
    .formatPct(nAgree / max(nAnswered, 1)), " of those answered) agree with it"
  )

  # Examples of disagreement, up to 5 per evidence_level. Taking the first 10 of
  # the table drew them all from one similarity group -- ten spellings of the
  # same CRP code, disagreeing the same way -- which says nothing about how the
  # mapping fails anywhere else. Two guards fix that: distinct (our concept,
  # reference concept) pairs are kept first, so one recurring disagreement
  # cannot fill the sample, and the draw is then seeded so re-runs on the same
  # data show the same examples.
  #
  # dplyr::coalesce(..., "") rather than leaving NA: sprintf("%s", NA) prints
  # the literal text "NA", which the Table output rule in development/STYLE.md
  # forbids in a table this project produces.
  set.seed(1)
  disagreeing <- checked[!agrees & !is.na(checked$omop_concept_id), ] |>
    dplyr::mutate(evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)"))

  exampleFor <- function(lvl) {
    pool <- disagreeing |>
      dplyr::filter(.data$evidence_level == lvl) |>
      dplyr::distinct(.data$omop_concept_id, .data$OMOP_CONCEPT_ID, .keep_all = TRUE)
    if (nrow(pool) == 0) return(character(0))
    picked <- pool |>
      dplyr::slice_sample(n = min(5L, nrow(pool))) |>
      dplyr::transmute(
        TEST_NAME = dplyr::coalesce(TEST_NAME, ""),
        UNIT = dplyr::coalesce(UNIT, ""),
        certainty = dplyr::coalesce(certainty, ""),
        loinc_name_guess = dplyr::coalesce(loinc_name_guess, ""),
        our_omop_concept_name = dplyr::coalesce(omop_concept_name, ""),
        reference_OMOP_CONCEPT_NAME = dplyr::coalesce(OMOP_CONCEPT_NAME, "")
      )
    c(paste0("*`", lvl, "` — ", nrow(pool), " distinct disagreements, ",
             nrow(picked), " shown:*"),
      "",
      .markdownTable(picked),
      "")
  }

  exampleLines <- unlist(lapply(
    c("unit+values", "unit only", "values only", "name only", "(unknown)"),
    exampleFor
  ))
  if (is.null(exampleLines)) exampleLines <- character(0)

  # Broken out by evidence_level, because the reference is in practice a
  # TEST_NAME -> concept mapping: it gives more than one concept across a code's
  # units for only ~6% of multi-unit codes. This pipeline maps (TEST_NAME, UNIT)
  # and leaves a name-only row unmapped rather than assuming, so on exactly
  # those rows the two targets differ by construction. Reporting one blended
  # percentage would hide that; the `name only` line is where the two
  # definitions disagree, and the evidenced lines are the ones that measure
  # whether this pipeline picks the right concept.
  byEvidence <- checked |>
    dplyr::mutate(agrees = agrees) |>
    dplyr::group_by(evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)")) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      n_answered = sum(!is.na(.data$omop_concept_id)),
      n_agree = sum(.data$agrees),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      pct_answered = .formatPct(n_answered / n_rows),
      pct_agree_of_rows = .formatPct(n_agree / n_rows),
      pct_agree_of_answered = .formatPct(n_agree / pmax(n_answered, 1))
    ) |>
    dplyr::arrange(dplyr::desc(n_rows))

  evidenced <- checked[!is.na(checked$evidence_level) & checked$evidence_level != "name only", ]
  nEvid <- nrow(evidenced)
  nEvidAgree <- sum(agrees[!is.na(checked$evidence_level) & checked$evidence_level != "name only"])

  referenceSection <- c(
    "## Cross-check against the reference mapping",
    "",
    paste0(
      "`", referenceMappingFile, "` holds a separately curated Finnish-code ",
      "-> OMOP mapping. Restricted to its `APPROVED` rows and matched to this ",
      "table by `TEST_NAME`+`UNIT`, it is the only independent read on whether ",
      "the concepts chosen here are the *right* ones:"
    ),
    "",
    .markdownTable(tibble::tibble(
      bucket = c("rows overlapping an APPROVED reference mapping",
                 "of those, this pipeline chose a concept",
                 "of those, it chose the reference's concept"),
      n = c(nChecked, nAnswered, nAgree),
      pct = c("", .formatPct(nAnswered / max(nChecked, 1)), .formatPct(nAgree / max(nAnswered, 1)))
    )),
    "",
    paste0("Agreement over the whole overlap: **",
           nAgree, " / ", nChecked, " = ", .formatPct(nAgree / max(nChecked, 1)), "**. ",
           "Restricted to rows that carry real evidence (a unit, values, or both): **",
           nEvidAgree, " / ", nEvid, " = ", .formatPct(nEvidAgree / max(nEvid, 1)), "**."),
    "",
    "The reference is the best mapping available, not ground truth — it contains",
    "errors of its own (it sends the rapid-test code `c-reaktiivinenproteiini,pika`",
    "to a high-sensitivity CRP concept, though that row's values floor at 5 mg/l),",
    "and it is internally inconsistent on some panel families. Read the figures",
    "below as *agreement*, not as correctness.",
    "",
    "By `evidence_level` — what the local row actually carried. The reference gives",
    "more than one concept across a code's units for only ~6% of multi-unit codes,",
    "so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps",
    "`(TEST_NAME, UNIT)` and leaves a `name only` row unmapped rather than assuming a",
    "quantity. On those rows the two targets differ by construction, which is why",
    "they are reported apart from the evidenced ones:",
    "",
    .markdownTable(byEvidence),
    if (length(exampleLines) > 0) c(
      "",
      "**Example disagreements.** Up to 5 per `evidence_level`, drawn at random",
      "from the *distinct* (our concept, reference concept) pairs so that one",
      "recurring disagreement cannot fill the sample. The `reasoning` column of",
      "`DATA/FixLOINCDimensions/codesWithOmopConcepts.tsv` says, clause by clause,",
      "what each of these choices rested on.",
      "",
      exampleLines
    ) else character(0)
  )
}

#
# --- Output -------------------------------------------------------------
#
md <- c(
  "# LOINC -> OMOP Mapping -- Stats",
  "",
  paste0("Source: `", codesWithOmopFile, "`"),
  "",
  "## Overview",
  "",
  "Each local code carries the OMOP concept `FixLOINCDimensions` chose for it",
  "from a shortlist that a semantic search over the LOINC vocabulary returned for",
  "the name `FindLOINCDimensions` guessed. This step only resolves that id",
  "against the vocabulary — there is no tuple join to succeed or fail, so",
  "\"unmapped\" here means the model declined every candidate, not that a join",
  "missed.",
  "",
  .markdownTable(overviewAll),
  "",
  "Of the rows a mapping was attempted for:",
  "",
  .markdownTable(overviewAttempted),
  "",
  "## By domain (the chosen concept's `has_system`)",
  "",
  "Which specimens the mapped codes ended up in, most common first. Unmapped",
  "rows are grouped together: this approach never infers a system of its own, so",
  "an unmapped row has no specimen to be counted under.",
  "",
  .markdownTable(byDomain),
  "",
  referenceSection
)

outFile <- file.path(outDir, "loincToOmopMappingStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
