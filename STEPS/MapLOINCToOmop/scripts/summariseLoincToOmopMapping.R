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

contentAxes <- c("has_component", "has_property", "has_method", "has_scale_type", "has_system", "has_time_aspect")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithOmopFile = ", codesWithOmopFile)
ParallelLogger::logInfo("  referenceMappingFile = ", referenceMappingFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
codes <- readr::read_tsv(codesWithOmopFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(codes), " rows from ", codesWithOmopFile)

#
# --- Action -------------------------------------------------------------
#
codes <- codes |>
  dplyr::mutate(
    hasAxisInfo = rowSums(!is.na(dplyr::across(dplyr::all_of(contentAxes)))) > 0,
    matched = n_omop_matches > 0
  )

# Table 1: every row, split by whether a match was even attempted.
overviewAll <- tibble::tibble(
  bucket = c("total", "with >=1 axis known", "no axis known"),
  n = c(nrow(codes), sum(codes$hasAxisInfo), sum(!codes$hasAxisInfo))
) |>
  dplyr::mutate(pct = sprintf("%.1f%%", 100 * n / nrow(codes)))

# Table 2: only rows a match was attempted for (>=1 axis known) -- the
# meaningful denominator for "did the join work".
attempted <- codes |> dplyr::filter(hasAxisInfo)
nAttempted <- nrow(attempted)
overviewAttempted <- tibble::tibble(
  bucket = c("attempted", "matched (>=1 OMOP concept)", "unmatched (0 OMOP concepts)",
             "matched uniquely (1 concept)", "matched ambiguously (>1 concept)"),
  n = c(
    nAttempted,
    sum(attempted$matched),
    sum(!attempted$matched),
    sum(attempted$n_omop_matches == 1),
    sum(attempted$n_omop_matches > 1)
  )
) |>
  dplyr::mutate(pct = sprintf("%.1f%%", 100 * n / nAttempted))

ParallelLogger::logInfo(
  sum(codes$hasAxisInfo), " / ", nrow(codes), " rows had >=1 axis known; ",
  sum(attempted$matched), " / ", nAttempted, " of those matched >=1 OMOP concept"
)

# By domain (has_system): match rate within each specimen/system value,
# including rows with no has_system value at all.
byDomain <- codes |>
  dplyr::mutate(has_system = dplyr::coalesce(has_system, "(unknown)")) |>
  dplyr::group_by(has_system) |>
  dplyr::summarise(n_rows = dplyr::n(), n_matched = sum(matched), .groups = "drop") |>
  dplyr::mutate(pct_matched = sprintf("%.1f%%", 100 * n_matched / n_rows)) |>
  dplyr::arrange(dplyr::desc(n_rows))

ParallelLogger::logInfo("Computed match rate for ", nrow(byDomain), " has_system domains")

# Bonus cross-check against DATA/ReferenceMappings/lab_data_summary.csv, a
# previously curated Finnish-code -> OMOP mapping (testId = "TEST_NAME
# [UNIT]"), if present. Degrades gracefully: the rest of the report still
# gets written if this section can't be computed.
referenceSection <- c(
  "## Cross-check against the reference mapping",
  "",
  paste0("`", referenceMappingFile, "` was not found -- skipping this section.")
)
if (file.exists(referenceMappingFile)) {
  reference <- readr::read_tsv(referenceMappingFile, show_col_types = FALSE, na = "")
  ParallelLogger::logInfo("Read ", nrow(reference), " rows from ", referenceMappingFile)

  testIdParts <- stringr::str_match(reference$testId, "^(.*) \\[(.*)\\]$")
  approved <- reference |>
    dplyr::mutate(TEST_NAME = testIdParts[, 2], UNIT = dplyr::na_if(testIdParts[, 3], "")) |>
    dplyr::filter(status == "APPROVED", !is.na(TEST_NAME)) |>
    dplyr::distinct(TEST_NAME, UNIT, OMOP_CONCEPT_ID, OMOP_CONCEPT_NAME)

  checked <- codes |>
    dplyr::inner_join(approved, by = c("TEST_NAME", "UNIT"))

  agrees <- purrr::map2_lgl(checked$omop_concept_id, checked$OMOP_CONCEPT_ID, function(ours, ref) {
    ours <- as.character(ours) # readr may guess this column as logical when every
                                # sampled value is NA/""; force character before strsplit()
    !is.na(ours) && as.character(ref) %in% strsplit(ours, "; ", fixed = TRUE)[[1]]
  })
  nChecked <- nrow(checked)
  nAgree <- sum(agrees)
  ParallelLogger::logInfo(
    nChecked, " rows overlap an APPROVED reference mapping; ",
    nAgree, " (", sprintf("%.1f%%", 100 * nAgree / max(nChecked, 1)), ") agree with it"
  )

  # dplyr::coalesce(..., "") rather than leaving NA: sprintf("%s", NA) prints
  # the literal text "NA", which the Table output rule in development/STYLE.md
  # forbids in a table this project produces.
  examplesDisagree <- checked[!agrees, ] |>
    dplyr::transmute(
      TEST_NAME = dplyr::coalesce(TEST_NAME, ""),
      UNIT = dplyr::coalesce(UNIT, ""),
      our_omop_concept_id = dplyr::coalesce(as.character(omop_concept_id), ""),
      our_omop_concept_name = dplyr::coalesce(omop_concept_name, ""),
      reference_OMOP_CONCEPT_ID = dplyr::coalesce(as.character(OMOP_CONCEPT_ID), ""),
      reference_OMOP_CONCEPT_NAME = dplyr::coalesce(OMOP_CONCEPT_NAME, "")
    ) |>
    dplyr::slice_head(n = 5)

  exampleLines <- if (nrow(examplesDisagree) > 0) {
    c(
      "| TEST_NAME | UNIT | our omop_concept_id | our omop_concept_name | reference OMOP_CONCEPT_ID | reference OMOP_CONCEPT_NAME |",
      "|---|---|---|---|---|---|",
      sprintf(
        "| %s | %s | %s | %s | %s | %s |",
        examplesDisagree$TEST_NAME, examplesDisagree$UNIT,
        examplesDisagree$our_omop_concept_id, examplesDisagree$our_omop_concept_name,
        examplesDisagree$reference_OMOP_CONCEPT_ID, examplesDisagree$reference_OMOP_CONCEPT_NAME
      )
    )
  } else {
    character(0)
  }

  referenceSection <- c(
    "## Cross-check against the reference mapping",
    "",
    paste0(
      "`", referenceMappingFile, "` holds a previously curated Finnish-code ",
      "-> OMOP mapping. Restricted to its `APPROVED` rows and matched to this ",
      "table by `TEST_NAME`+`UNIT`:"
    ),
    "",
    paste0("- n rows overlapping an APPROVED reference mapping: ", nChecked),
    paste0(
      "- of those, our join's OMOP concept(s) include the reference's approved ",
      "concept: ", nAgree, " / ", nChecked, " (", sprintf("%.1f%%", 100 * nAgree / max(nChecked, 1)), ")"
    ),
    if (length(exampleLines) > 0) c("", "**Example disagreements:**", "", exampleLines) else character(0)
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
  "Local codes are joined to OMOP concepts by requiring an exact match on all",
  "6 LOINC axes (`has_component`, `has_property`, `has_method`,",
  "`has_scale_type`, `has_system`, `has_time_aspect`) plus `is_panel`. A row",
  "with none of the 6 axes known is never attempted -- there is nothing to",
  "join by -- rather than being matched against every equally-unknown OMOP",
  "concept.",
  "",
  "| bucket | n | % |",
  "|---|---|---|",
  sprintf("| %s | %d | %s |", overviewAll$bucket, overviewAll$n, overviewAll$pct),
  "",
  "Of the rows a match was attempted for:",
  "",
  "| bucket | n | % |",
  "|---|---|---|",
  sprintf("| %s | %d | %s |", overviewAttempted$bucket, overviewAttempted$n, overviewAttempted$pct),
  "",
  "## By domain (has_system)",
  "",
  "Match rate broken down by specimen/system (`has_system`), most common",
  "first. `(unknown)` groups rows with no `has_system` value at all.",
  "",
  "| has_system | n rows | n matched | % matched |",
  "|---|---|---|---|",
  sprintf("| %s | %d | %d | %s |", byDomain$has_system, byDomain$n_rows, byDomain$n_matched, byDomain$pct_matched),
  "",
  referenceSection
)

outFile <- file.path(outDir, "loincToOmopMappingStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
