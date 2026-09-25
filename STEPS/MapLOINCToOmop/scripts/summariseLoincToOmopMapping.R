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

# Records above which a code counts as high-volume. The curated reference was
# built mostly for the codes that carry real data volume -- it covers 97% of
# the rows with >=50,000 records but under 30% of those with <500 -- so the
# agreement figure over the whole overlap mixes the codes it was written for
# with ones it barely touches. This threshold splits them.
volumeThreshold <- suppressWarnings(as.numeric(Sys.getenv("VOLUME_THRESHOLD", "500")))

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithOmopFile = ", codesWithOmopFile)
ParallelLogger::logInfo("  referenceMappingFile = ", referenceMappingFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  volumeThreshold = ", volumeThreshold)

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

  # The join key is TEST_NAME + UNIT, and an empty UNIT is a unit value in its
  # own right -- "sodium with no unit recorded" is a different row from "sodium
  # in mmol/l" on both sides, so they must not collapse into one another.
  checked <- codes |>
    dplyr::inner_join(approved, by = c("TEST_NAME", "UNIT"))

  # Every row of THIS pipeline's table falls into exactly one of four outcomes.
  outcomeOf <- function(inRef, hasId, sameId) {
    dplyr::case_when(
      !inRef ~ "not in reference",
      !hasId ~ "not automapped",
      sameId ~ "agreement",
      TRUE ~ "disagreement"
    )
  }
  refKey <- paste(approved$TEST_NAME, approved$UNIT, sep = "\r")
  refConcept <- stats::setNames(as.character(approved$OMOP_CONCEPT_ID), refKey)
  codesKey <- paste(codes$TEST_NAME, codes$UNIT, sep = "\r")
  codes <- codes |>
    dplyr::mutate(
      outcome = outcomeOf(
        inRef = codesKey %in% refKey,
        hasId = !is.na(.data$omop_concept_id),
        sameId = !is.na(.data$omop_concept_id) &
          .data$omop_concept_id == unname(refConcept[codesKey])
      )
    )
  outcomeCounts <- tibble::tibble(
    outcome = c("not in reference", "not automapped", "disagreement", "agreement")
  ) |>
    dplyr::mutate(
      n = purrr::map_int(outcome, ~ sum(codes$outcome == .x)),
      pct_of_all = .formatPct(n / nRows),
      pct_of_in_reference = ifelse(
        outcome == "not in reference", "",
        .formatPct(n / max(sum(codes$outcome != "not in reference"), 1))
      )
    )
  ParallelLogger::logInfo("Outcomes: ",
                          paste(outcomeCounts$outcome, outcomeCounts$n, sep = "=", collapse = ", "))

  # "not in reference" is the largest bucket by far, and the name oversells it:
  # the cross-check compares against APPROVED rows only, so a row lands here
  # whenever the reference has no APPROVED mapping for it -- which is usually
  # not the same as the reference never having heard of the code. Splitting the
  # bucket by the status the reference does carry separates "nobody has curated
  # this yet" (UNCHECKED) from "a curator looked and found nothing" (NOT-FOUND)
  # from genuine absence. The three call for different follow-up, and lumping
  # them together hides that NOT-FOUND rows we did map are the pipeline's
  # strongest claim to be adding something the reference does not have.
  statusRank <- c("APPROVED" = 1L, "UNCHECKED" = 2L, "NOT-FOUND" = 3L, "IGNORED" = 4L)
  refAll <- reference |>
    dplyr::mutate(TEST_NAME = testIdParts[, 2], UNIT = dplyr::na_if(testIdParts[, 3], "")) |>
    dplyr::filter(!is.na(.data$TEST_NAME)) |>
    dplyr::mutate(rank = dplyr::coalesce(statusRank[.data$status], 9L)) |>
    dplyr::group_by(.data$TEST_NAME, .data$UNIT) |>
    dplyr::slice_min(.data$rank, n = 1, with_ties = FALSE) |>
    dplyr::ungroup()
  refAllKey <- paste(refAll$TEST_NAME, refAll$UNIT, sep = "\r")
  # A code can appear under several statuses; the best one is what the
  # reference effectively says about it, hence slice_min on the rank above.
  refStatus <- refAll$status[match(codesKey, refAllKey)]
  notInRef <- codes$outcome == "not in reference"
  statusBreakdown <- tibble::tibble(
    reference_status = ifelse(is.na(refStatus), "(no row at all)", refStatus)
  )[notInRef, ] |>
    dplyr::mutate(
      automapped = !is.na(codes$omop_concept_id[notInRef]),
      # `n` arrives as character: the table is read with na = "" per
      # development/STYLE.md, so an empty record count is an empty string
      # rather than NA and readr types the whole column as text.
      records = suppressWarnings(as.numeric(codes$n[notInRef]))
    ) |>
    dplyr::group_by(.data$reference_status) |>
    dplyr::summarise(
      rows = dplyr::n(),
      automapped = sprintf("%d (%s)", sum(.data$automapped),
                           .formatPct(mean(.data$automapped))),
      records = format(sum(.data$records, na.rm = TRUE), big.mark = ","),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$rows))

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

  # Five examples of each of the two failure outcomes. Sampling is deduplicated
  # first -- disagreements by their (our concept, reference concept) pair, and
  # declines by TEST_NAME -- because taking the head of the table drew ten
  # spellings of one CRP code failing the same way, and plain random sampling
  # would not have fixed that: a code that recurs under ten spellings is ten
  # times as likely to be drawn. Seeded so re-runs on the same data agree.
  set.seed(1)
  withOutcome <- checked |>
    dplyr::mutate(
      sameId = !is.na(.data$omop_concept_id) &
        .data$omop_concept_id == as.character(.data$OMOP_CONCEPT_ID),
      outcome = dplyr::case_when(
        is.na(.data$omop_concept_id) ~ "not automapped",
        .data$sameId ~ "agreement",
        TRUE ~ "disagreement"
      ),
      evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)")
    )

  exampleTable <- function(outcomeName, dedupe) {
    pool <- withOutcome |> dplyr::filter(.data$outcome == outcomeName)
    pool <- if (dedupe == "pair") {
      dplyr::distinct(pool, .data$omop_concept_id, .data$OMOP_CONCEPT_ID, .keep_all = TRUE)
    } else {
      dplyr::distinct(pool, .data$TEST_NAME, .keep_all = TRUE)
    }
    if (nrow(pool) == 0) return(character(0))
    picked <- pool |>
      dplyr::slice_sample(n = min(5L, nrow(pool))) |>
      dplyr::transmute(
        TEST_NAME = dplyr::coalesce(TEST_NAME, ""),
        UNIT = dplyr::coalesce(UNIT, ""),
        evidence = dplyr::coalesce(evidence_level, ""),
        certainty = dplyr::coalesce(certainty, ""),
        loinc_name_guess = dplyr::coalesce(loinc_name_guess, ""),
        our_omop_concept_name = dplyr::coalesce(omop_concept_name, ""),
        reference_OMOP_CONCEPT_NAME = dplyr::coalesce(OMOP_CONCEPT_NAME, ""),
        reasoning = dplyr::coalesce(reasoning, "")
      )
    c(paste0("*", nrow(pool), " distinct ", outcomeName, " rows; ",
             nrow(picked), " shown:*"),
      "",
      .markdownTable(picked),
      "")
  }

  disagreementLines <- exampleTable("disagreement", "pair")
  declinedLines <- exampleTable("not automapped", "name")
  nNoReasoning <- sum(withOutcome$outcome == "not automapped" &
                        is.na(withOutcome$reasoning))

  # Agreement restricted to rows that carried real evidence. The labels are
  # listed explicitly rather than filtered as "everything except `name`": if one
  # is renamed upstream, an exclusion filter silently keeps every row and the
  # evidenced figure quietly becomes the whole-overlap figure -- the kind of
  # error that still looks like a result. An allow-list drops unknown labels and
  # the warning below makes the drop visible.
  evidencedLabels <- c("name+unit+values", "name+values", "name+unit")
  isEvidenced <- !is.na(checked$evidence_level) & checked$evidence_level %in% evidencedLabels
  nEvid <- sum(isEvidenced)
  nEvidAgree <- sum(agrees[isEvidenced])
  nUnknownLabel <- sum(!is.na(checked$evidence_level) &
                         !(checked$evidence_level %in% c(evidencedLabels, "name")))
  if (nUnknownLabel > 0) {
    ParallelLogger::logWarn(nUnknownLabel, " overlap row(s) carry an unrecognised ",
                            "evidence_level; they are excluded from the evidenced figure")
  }

  byEvidence <- checked |>
    dplyr::mutate(agrees = agrees) |>
    dplyr::group_by(evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)")) |>
    dplyr::summarise(
      n_rows = dplyr::n(),
      n_automapped = sum(!is.na(.data$omop_concept_id)),
      n_agreement = sum(.data$agrees),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      pct_automapped = .formatPct(n_automapped / n_rows),
      pct_agree_of_rows = .formatPct(n_agreement / n_rows),
      pct_agree_of_automapped = .formatPct(n_agreement / pmax(n_automapped, 1))
    ) |>
    dplyr::arrange(dplyr::desc(n_rows))

  # Agreement by how much data the code actually carries: the reference was
  # curated for the codes that matter, so one blended figure mixes the codes it
  # was written for with ones it barely touches.
  checked <- checked |> dplyr::mutate(nRecords = suppressWarnings(as.numeric(.data$n)))
  allByVolume <- codes |> dplyr::mutate(nRecords = suppressWarnings(as.numeric(.data$n)))
  volumeBands <- list(
    list(lo = 0,     hi = 100,   label = "< 100"),
    list(lo = 100,   hi = 500,   label = "100 - 499"),
    list(lo = 500,   hi = 5000,  label = "500 - 4,999"),
    list(lo = 5000,  hi = 50000, label = "5,000 - 49,999"),
    list(lo = 50000, hi = Inf,   label = ">= 50,000")
  )
  byVolume <- purrr::map_dfr(volumeBands, function(b) {
    allSel <- !is.na(allByVolume$nRecords) & allByVolume$nRecords >= b$lo & allByVolume$nRecords < b$hi
    sel <- !is.na(checked$nRecords) & checked$nRecords >= b$lo & checked$nRecords < b$hi
    nOverlap <- sum(sel)
    tibble::tibble(
      records = b$label,
      rows = sum(allSel),
      in_reference = sprintf("%d (%s)", nOverlap, .formatPct(nOverlap / max(sum(allSel), 1))),
      automapped = .formatPct(sum(sel & !is.na(checked$omop_concept_id)) / max(nOverlap, 1)),
      agreement = sprintf("%d (%s)", sum(agrees[sel]), .formatPct(sum(agrees[sel]) / max(nOverlap, 1)))
    )
  })

  highSel <- !is.na(checked$nRecords) & checked$nRecords >= volumeThreshold
  nHigh <- sum(highSel)
  nHighAgree <- sum(agrees[highSel])
  nHighAnswered <- sum(highSel & !is.na(checked$omop_concept_id))
  ParallelLogger::logInfo(
    "Restricted to codes with >= ", volumeThreshold, " records: ",
    nHighAgree, " / ", nHigh, " (", .formatPct(nHighAgree / max(nHigh, 1)), ") agree"
  )

  referenceSection <- c(
    "## Cross-check against the reference mapping",
    "",
    paste0(
      "`", referenceMappingFile, "` holds a separately curated Finnish-code ",
      "-> OMOP mapping. Restricted to its `APPROVED` rows and matched to this ",
      "table by `TEST_NAME`+`UNIT`, it is the only independent read on whether ",
      "the concepts chosen here are the *right* ones."
    ),
    "",
    "The join key is `TEST_NAME` + `UNIT`. An **empty `UNIT` counts as a unit**:",
    "a code with no unit recorded is a different row from the same code in",
    "`mmol/l`, on both sides of the join, and they must not collapse together.",
    "",
    "Every row of this pipeline's table then falls into exactly one of four",
    "outcomes:",
    "",
    "- **not in reference** — the reference has no **`APPROVED`** mapping for this",
    "  `TEST_NAME`+`UNIT`, so there is nothing to compare against. Not a result",
    "  either way, and mostly not a gap in the reference either — see the split",
    "  below.",
    "- **not automapped** — the reference has this code, but the pipeline produced",
    "  no OMOP id: `FixLOINCDimensions` judged no candidate defensible and left it",
    "  empty on purpose. For a code with no unit and no values that is the intended",
    "  answer, not a failure.",
    "- **disagreement** — the pipeline produced an id and the reference has a",
    "  different one.",
    "- **agreement** — the pipeline produced the same id as the reference.",
    "",
    "",
    .markdownTable(outcomeCounts),
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
    "### What \"not in reference\" actually means",
    "",
    "The cross-check uses the reference's `APPROVED` rows only, so that bucket is",
    "*not* \"the reference has never heard of this code\". It mostly is not: the",
    "reference carries a row for these codes under another status. What it says",
    "about them, and what this pipeline did anyway:",
    "",
    .markdownTable(statusBreakdown),
    "",
    "- **`UNCHECKED`** — nobody has curated the code yet. There is no answer to",
    "  compare against, and these are where a working pipeline adds mappings that",
    "  do not exist today.",
    "- **`NOT-FOUND`** — a curator looked and concluded no concept fits; none of",
    "  these rows carries a concept id in the reference. Rows here that the",
    "  pipeline *did* map are its strongest claim to beat the reference — and,",
    "  equally, where a hallucinated concept would hide. They are the highest-value",
    "  set to put in front of a human.",
    "- **`IGNORED`** — deliberately excluded from the curation.",
    "- **`(no row at all)`** — genuinely absent from the reference file.",
    "",
    "### By record volume",
    "",
    paste0("The reference was curated for the codes that carry the data. It covers ",
           "97% of the rows with 50,000+ records and under 30% of those below 500, ",
           "so a single agreement figure over the whole overlap mixes the codes it ",
           "was written for with ones it barely touches."),
    "",
    .markdownTable(byVolume),
    "",
    paste0("**Restricted to codes with >= ", format(volumeThreshold, big.mark = ","),
           " records — the range the reference actually covers: ",
           nHighAgree, " / ", nHigh, " = ", .formatPct(nHighAgree / max(nHigh, 1)),
           "** (", .formatPct(nHighAgree / max(nHighAnswered, 1)), " of the ",
           nHighAnswered, " it automapped)."),
    "",
    "### By evidence level",
    "",
    "What the local row actually carried. The reference gives",
    "more than one concept across a code's units for only ~6% of multi-unit codes,",
    "so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps",
    "`(TEST_NAME, UNIT)`. A `name`-only row has nothing that fixes its quantity, so",
    "`FixLOINCDimensions` takes a concept there only when the name alone settles it",
    "and declines otherwise — which is why those rows both answer less often and",
    "agree less often, and why they are reported apart from the evidenced ones:",
    "",
    .markdownTable(byEvidence),
    if (length(disagreementLines) > 0) c(
      "",
      "### Examples — disagreement",
      "",
      "Five of the rows where the pipeline produced an id and the reference has a",
      "different one, sampled from the *distinct* (our concept, reference concept)",
      "pairs so one recurring disagreement cannot fill the table. `reasoning` is what",
      "`FixLOINCDimensions` gave for that choice, clause by clause — so the mistake",
      "can be read rather than guessed at.",
      "",
      disagreementLines
    ) else character(0),
    if (length(declinedLines) > 0) c(
      "",
      "### Examples — not automapped",
      "",
      "Five of the rows the reference maps but the pipeline left empty. An empty",
      "`loinc_name_guess` means `FindLOINCDimensions` could not name the test at all;",
      "a filled one means the search returned nothing the model would accept.",
      if (nNoReasoning > 0) paste0(
        "`reasoning` is empty on ", nNoReasoning, " of these: the prompt currently asks ",
        "for it only when a concept was chosen, so the pipeline does not record WHY it ",
        "declined. That is the most useful thing it could say about these rows."
      ) else "",
      "",
      declinedLines
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
