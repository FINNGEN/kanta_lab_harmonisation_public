#
# Reports on the final local-code -> OMOP concept mapping.
#
# The number that actually matters is in the Compare with reference section:
# how often this pipeline's concept AGREES with the curated Finnish mapping on
# the codes both cover. Agreement, not correctness -- the reference is the
# best mapping available, not ground truth, and it carries errors and
# internal inconsistencies of its own. Coverage (how many codes got any
# concept) is easy to inflate by guessing, so it is reported next to
# agreement, never instead of it, and both are broken out by how much
# evidence the local row actually had and by how many records it carries.
#
# Agreement is scored twice: on the concept id (exact), and on whether the two
# concepts SHARE a LOINC Group. The second one exists because the most common
# way the two mappings differ is not the analyte but the decoration around it --
# method (Automated count / Microscopy / Test strip / Refractometry) and
# granularity. A LOINC Group rolls those up, so two different concept ids in one
# Group are the same test measured differently.
#
# "Share a Group" is a set intersection, which is why Group membership is taken
# from the OMOP vocabulary (0_GetMeasurementOmopData/loinc_group_membership.tsv)
# rather than from LOINC's GroupFile distribution. A concept belongs to several
# Groups at once, and the intersection asks the question directly. The earlier
# GroupFile version had to force ONE Group per code with a precedence rule,
# because its ParentGroups overlap each other -- which answered a different,
# harder question and needed a licensed file as an input.
# See RESEARCH/UnderstandingGroups.md.
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
# Optional: without it the report is scored on concept ids alone and the LOINC
# Group section is skipped.
loincGroupMembershipFile <- if (length(args) >= 4) args[4] else NA_character_

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  codesWithOmopFile = ", codesWithOmopFile)
ParallelLogger::logInfo("  referenceMappingFile = ", referenceMappingFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  loincGroupMembershipFile = ", loincGroupMembershipFile)

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

# concept_id -> the LOINC Groups it belongs to. Keyed by concept_id straight
# from the vocabulary, so nothing has to be resolved through a LOINC number and
# a non-LOINC concept simply has no Groups. Absent file is not an error -- the
# report drops to concept-id-only scoring and says so.
#
# ParentGroups are excluded. OMOP models them as 'LOINC Group' concepts too, so
# LG100-4 ("Flowsheet - laboratory", 3,538 descendants) and LG55-6 ("Mass-Molar
# conversion", 4,296) would otherwise make any two lab chemistry concepts
# "share a Group". They are flagged structurally upstream -- a ParentGroup is a
# Group that subsumes other Groups -- not by a size threshold, which would also
# have thrown away genuine large value sets like LG32757-3 "Influenza virus"
# (460 descendants).
groupScoringAvailable <- !is.na(loincGroupMembershipFile) &&
  nzchar(loincGroupMembershipFile) && file.exists(loincGroupMembershipFile)
conceptGroups <- list()
groupName <- character(0)
groupSize <- integer(0)

if (groupScoringAvailable) {
  membership <- readr::read_tsv(loincGroupMembershipFile, show_col_types = FALSE, na = "",
                                col_types = readr::cols(.default = readr::col_character()))
  ParallelLogger::logInfo("Read ", nrow(membership), " concept -> Group rows from ", loincGroupMembershipFile)
  nParent <- dplyr::n_distinct(membership$group_concept_id[membership$is_parent_group == "TRUE"])
  membership <- membership |> dplyr::filter(.data$is_parent_group != "TRUE")

  conceptGroups <- split(membership$group_concept_id, membership$concept_id)
  groupName <- stats::setNames(membership$group_concept_name, membership$group_concept_id)
  groupSize <- stats::setNames(as.integer(membership$n_descendants), membership$group_concept_id)
  ParallelLogger::logInfo(
    length(conceptGroups), " concepts belong to ",
    dplyr::n_distinct(membership$group_concept_id), " Groups after excluding ",
    nParent, " ParentGroups"
  )
} else {
  ParallelLogger::logWarn("No LOINC Group membership file -- scoring agreement on concept ids only")
}

#
# --- Action -------------------------------------------------------------
#
codes <- codes |>
  dplyr::mutate(
    named = !is.na(.data$loinc_name_guess),
    matched = .data$mapped == "TRUE",
    # `n` arrives as character: the table is read with na = "" per
    # development/STYLE.md, so an empty record count is an empty string
    # rather than NA and readr types the whole column as text.
    nRecords = suppressWarnings(as.numeric(.data$n))
  )
nRows <- nrow(codes)
totalEvents <- sum(codes$nRecords, na.rm = TRUE)

.formatPct <- function(x, d = 1) sprintf(paste0("%.", d, "f%%"), 100 * x)

.markdownTable <- function(df) {
  # A literal "|" inside a cell ends the column early and silently mangles the
  # whole table. LOINC Group names are built out of "|" (e.g.
  # "Calcium.ionized|SCnc|Pt|ANYBldSerPl"), so escape every cell, not just
  # the ones expected to need it.
  esc <- function(x) gsub("|", "\\|", x, fixed = TRUE)
  header <- paste0("| ", paste(esc(names(df)), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- apply(df, 1, function(row) paste0("| ", paste(esc(row), collapse = " | "), " |"))
  c(header, sep, rows)
}

ParallelLogger::logInfo(
  sum(codes$named), " / ", nRows, " rows were named; ",
  sum(codes$named & codes$matched), " / ", sum(codes$named), " of those mapped to an OMOP concept"
)

# Cross-check against DATA/ReferenceMappings/lab_data_summary.csv, a
# separately curated Finnish-code -> OMOP mapping (testId = "TEST_NAME
# [UNIT]"). Degrades gracefully: the rest of the report still gets written if
# this section can't be computed -- `outcome` stays NA, and the Overview
# table's two reference-dependent rows print "-" instead of a count.
codes$outcome <- NA_character_
referenceAvailable <- file.exists(referenceMappingFile)
# Filled in by the reference block when Group scoring is on; stay NA otherwise
# so the Overview funnel prints "-" for that row rather than a wrong zero.
nAgreeGroupOverview <- NA_integer_
eventsAgreeGroupOverview <- NA_real_
compareSection <- c(
  "## Compare with reference",
  "",
  paste0("`", referenceMappingFile, "` was not found -- skipping this section.")
)

if (referenceAvailable) {
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
  refKey <- paste(approved$TEST_NAME, approved$UNIT, sep = "\r")
  refConcept <- stats::setNames(as.character(approved$OMOP_CONCEPT_ID), refKey)
  codesKey <- paste(codes$TEST_NAME, codes$UNIT, sep = "\r")

  # Every row of this pipeline's table falls into exactly one of four
  # outcomes -- "not in reference" uses the reference's APPROVED rows only:
  # a code with only an UNCHECKED/NOT-FOUND/IGNORED reference row counts as
  # absent from it here.
  codes <- codes |>
    dplyr::mutate(
      outcome = dplyr::case_when(
        !(codesKey %in% refKey) ~ "not in reference",
        is.na(.data$omop_concept_id) ~ "not automapped",
        .data$omop_concept_id == unname(refConcept[codesKey]) ~ "agreement",
        TRUE ~ "disagreement"
      )
    )

  checked <- codes |>
    dplyr::filter(.data$outcome != "not in reference") |>
    dplyr::inner_join(approved, by = c("TEST_NAME", "UNIT")) |>
    dplyr::mutate(agrees = .data$outcome == "agreement")

  # Group-level agreement. Two concepts that share a LOINC Group are the same
  # test measured differently -- the Group's rule rolls up Method, and for some
  # rules property or specimen granularity, which is where most of the
  # pipeline-vs-reference disagreement actually sits. Scored on top of concept
  # agreement, never instead of it: a row that already agrees on the id stays
  # agreeing, and a row with no Group on either side can only be judged on the
  # id.
  #
  # A concept belongs to several Groups, so the shared Group reported is the
  # most specific one -- fewest descendants -- which is the tightest claim the
  # vocabulary supports for that pair.
  .groupsOf <- function(ids) lapply(as.character(ids), function(id) {
    g <- conceptGroups[[id]]
    if (is.null(g)) character(0) else g
  })
  ourGroupSets <- .groupsOf(checked$omop_concept_id)
  refGroupSets <- .groupsOf(checked$OMOP_CONCEPT_ID)
  sharedGroup <- vapply(seq_len(nrow(checked)), function(i) {
    shared <- intersect(ourGroupSets[[i]], refGroupSets[[i]])
    if (length(shared) == 0) return(NA_character_)
    shared[which.min(groupSize[shared])]
  }, character(1))

  checked <- checked |>
    dplyr::mutate(
      groupComparable = lengths(ourGroupSets) > 0 & lengths(refGroupSets) > 0,
      sharedGroupId = sharedGroup,
      sharedGroupName = unname(groupName[sharedGroup]),
      sharedGroupSize = unname(groupSize[sharedGroup]),
      agreesGroup = .data$agrees | !is.na(.data$sharedGroupId),
      recoveredByGroup = .data$agreesGroup & !.data$agrees
    )

  nChecked <- nrow(checked)
  nAgree <- sum(checked$agrees)
  nAgreeGroup <- sum(checked$agreesGroup)
  nRecovered <- sum(checked$recoveredByGroup)
  nComparable <- sum(checked$groupComparable)
  ParallelLogger::logInfo(
    nChecked, " / ", nRows, " codes carry an APPROVED reference mapping; ",
    nAgree, " (", .formatPct(nAgree / max(nChecked, 1)), ") agree with it"
  )
  if (groupScoringAvailable) {
    ParallelLogger::logInfo(
      nComparable, " of those carry a LOINC Group on both sides; agreement rises to ",
      nAgreeGroup, " (", .formatPct(nAgreeGroup / max(nChecked, 1)), ") at Group level, ",
      "recovering ", nRecovered, " disagreements"
    )
  }

  # One grouping column (evidence_level, or a record-volume band) broken down
  # two ways -- by codes and by events (the `n` each code carries) -- always
  # restricted to `checked` (the codes with an APPROVED reference mapping),
  # since that is the only population this section has anything to say about.
  # `p_codes`/`p_events` is the row's share of the grand total (so the rows
  # add up to `total`). `p_ai_mapped` is relative to that row's OWN
  # n_codes/n_events -- "of the codes/records at THIS evidence level or
  # volume band, how many got AI-mapped at all". `p_agree` is relative to
  # that row's own n_ai_mapped, not n_codes/n_events -- "of the ones THIS row
  # actually mapped, how many agreed" -- so a `name`-only row's low p_agree
  # cannot be blamed on rows it never answered in the first place.
  # `n_agree_group`/`p_agree_group` is the same count scored on the LOINC Group
  # instead of the concept id, on the same n_ai_mapped denominator so the two
  # agreement columns can be read against each other. It is always >= p_agree:
  # a row that agrees on the id agrees on the Group by construction.
  buildBreakdown <- function(df, groupLabels, groupCol, metric, order = NULL) {
    grouped <- df |>
      dplyr::mutate(.group = groupLabels) |>
      dplyr::group_by(.data$.group) |>
      dplyr::summarise(
        n = if (metric == "codes") dplyr::n() else sum(.data$nRecords, na.rm = TRUE),
        n_ai_mapped = if (metric == "codes") {
          sum(!is.na(.data$omop_concept_id))
        } else {
          sum(.data$nRecords[!is.na(.data$omop_concept_id)], na.rm = TRUE)
        },
        n_agree = if (metric == "codes") {
          sum(.data$agrees)
        } else {
          sum(.data$nRecords[.data$agrees], na.rm = TRUE)
        },
        n_agree_group = if (metric == "codes") {
          sum(.data$agreesGroup)
        } else {
          sum(.data$nRecords[.data$agreesGroup], na.rm = TRUE)
        },
        .groups = "drop"
      )
    if (!is.null(order)) {
      grouped <- grouped |> dplyr::arrange(match(.data$.group, order))
    } else {
      grouped <- grouped |> dplyr::arrange(dplyr::desc(.data$n))
    }
    total <- tibble::tibble(.group = "total", n = sum(grouped$n),
                            n_ai_mapped = sum(grouped$n_ai_mapped), n_agree = sum(grouped$n_agree),
                            n_agree_group = sum(grouped$n_agree_group))
    out <- dplyr::bind_rows(grouped, total) |>
      dplyr::mutate(
        p = .formatPct(.data$n / max(sum(grouped$n), 1)),
        p_ai_mapped = .formatPct(.data$n_ai_mapped / pmax(.data$n, 1)),
        p_agree = .formatPct(.data$n_agree / pmax(.data$n_ai_mapped, 1)),
        p_agree_group = .formatPct(.data$n_agree_group / pmax(.data$n_ai_mapped, 1))
      )
    # Without a Group index `agreesGroup` collapses onto `agrees`, so the two
    # extra columns would just be a duplicate pair. Drop them rather than print
    # a column that silently means something else.
    if (!groupScoringAvailable) {
      out <- out |> dplyr::select(-"n_agree_group", -"p_agree_group")
    }
    if (metric == "codes") {
      out <- out |> dplyr::rename(n_codes = n, p_codes = p)
    } else {
      out <- out |>
        dplyr::mutate(dplyr::across(dplyr::any_of(c("n", "n_ai_mapped", "n_agree", "n_agree_group")),
                                    ~ format(.x, big.mark = ","))) |>
        dplyr::rename(n_events = n, p_events = p)
    }
    names(out)[1] <- groupCol
    out
  }

  byEvidenceCodes <- buildBreakdown(checked, dplyr::coalesce(checked$evidence_level, "(unknown)"),
                                    "evidence_level", "codes")
  byEvidenceEvents <- buildBreakdown(checked, dplyr::coalesce(checked$evidence_level, "(unknown)"),
                                     "evidence_level", "events")

  # Record-volume bands, in ascending order rather than by count, since the
  # point is to read agreement as volume rises, not to rank the bands.
  volumeBands <- list(
    list(lo = 0,     hi = 100,   label = "< 100"),
    list(lo = 100,   hi = 500,   label = "100 - 499"),
    list(lo = 500,   hi = 5000,  label = "500 - 4,999"),
    list(lo = 5000,  hi = 50000, label = "5,000 - 49,999"),
    list(lo = 50000, hi = Inf,   label = ">= 50,000")
  )
  bandLabel <- function(x) {
    lbl <- rep(NA_character_, length(x))
    for (b in volumeBands) {
      sel <- !is.na(x) & x >= b$lo & x < b$hi
      lbl[sel] <- b$label
    }
    lbl
  }
  volumeOrder <- vapply(volumeBands, function(b) b$label, character(1))
  checkedVolume <- checked |> dplyr::mutate(.band = bandLabel(.data$nRecords))

  byVolumeCodes <- buildBreakdown(checkedVolume, checkedVolume$.band, "records", "codes", order = volumeOrder)
  byVolumeEvents <- buildBreakdown(checkedVolume, checkedVolume$.band, "records", "events", order = volumeOrder)

  # The LOINC Group section. Three numbers carry it: how many of the checked
  # codes can be judged at Group level at all (both sides need a Group), what
  # agreement becomes when they are, and which disagreements that recovers.
  groupSection <- character(0)
  if (groupScoringAvailable) {
    eventsOf <- function(sel) sum(checked$nRecords[sel], na.rm = TRUE)
    checkedEvents <- sum(checked$nRecords, na.rm = TRUE)
    levels <- tibble::tibble(
      level = c("agrees on the concept id (exact)",
                "agrees on the LOINC Group",
                "— of which recovered by the Group"),
      n_codes = c(nAgree, nAgreeGroup, nRecovered),
      n_events = c(eventsOf(checked$agrees), eventsOf(checked$agreesGroup),
                   eventsOf(checked$recoveredByGroup))
    ) |>
      dplyr::mutate(
        p_codes = .formatPct(.data$n_codes / max(nChecked, 1)),
        p_events = .formatPct(.data$n_events / max(checkedEvents, 1)),
        n_codes = format(.data$n_codes, big.mark = ","),
        n_events = format(.data$n_events, big.mark = ",")
      ) |>
      dplyr::select("level", "n_codes", "p_codes", "n_events", "p_events")

    # How tight was the Group that did the recovering. A pair sharing a 4-member
    # Group is a strong claim; one sharing a 200-member Group is a weak one, and
    # this is the column that lets a reader discount the weak ones rather than
    # take the headline figure on trust.
    sizeBands <- list(
      list(lo = 0,   hi = 10,  label = "2 - 10"),
      list(lo = 10,  hi = 50,  label = "11 - 50"),
      list(lo = 50,  hi = 200, label = "51 - 200"),
      list(lo = 200, hi = Inf, label = "> 200")
    )
    recoveredBySize <- checked |>
      dplyr::filter(.data$recoveredByGroup) |>
      dplyr::mutate(.band = vapply(.data$sharedGroupSize, function(x) {
        hit <- Filter(function(b) !is.na(x) && x > b$lo && x <= b$hi, sizeBands)
        if (length(hit) == 0) "(unknown)" else hit[[1]]$label
      }, character(1))) |>
      dplyr::count(.data$.band, name = "n_codes") |>
      dplyr::arrange(match(.data$.band, vapply(sizeBands, function(b) b$label, character(1)))) |>
      dplyr::rename(shared_group_size = ".band")

    nAgreeGroupOverview <- nAgreeGroup
    eventsAgreeGroupOverview <- eventsOf(checked$agreesGroup)

    recoveredExamples <- checked |>
      dplyr::filter(.data$recoveredByGroup) |>
      dplyr::distinct(.data$omop_concept_id, .data$OMOP_CONCEPT_ID, .keep_all = TRUE)
    nRecoveredDistinct <- nrow(recoveredExamples)
    recoveredLines <- character(0)
    if (nRecoveredDistinct > 0) {
      picked <- recoveredExamples |>
        dplyr::slice_sample(n = min(5L, nRecoveredDistinct)) |>
        dplyr::transmute(
          TEST_NAME = dplyr::coalesce(TEST_NAME, ""),
          UNIT = dplyr::coalesce(UNIT, ""),
          our_omop_concept_name = dplyr::coalesce(omop_concept_name, ""),
          reference_OMOP_CONCEPT_NAME = dplyr::coalesce(OMOP_CONCEPT_NAME, ""),
          shared_loinc_group = dplyr::coalesce(sharedGroupName, ""),
          group_size = dplyr::coalesce(as.character(sharedGroupSize), "")
        )
      recoveredLines <- c(
        paste0("*", nRecoveredDistinct, " distinct recovered (our concept, reference concept) pairs; ",
               nrow(picked), " shown:*"),
        "",
        .markdownTable(picked)
      )
    }

    groupSection <- c(
      "",
      "### Agreement at LOINC Group level",
      "",
      strwrap(paste0(
        "A LOINC Group is a value set of concepts that differ only in an axis ",
        "the Group's rule rolls up -- Method above all, which is where this ",
        "pipeline and the reference most often part company (`Automated count` ",
        "vs methodless, `Test strip`, `Refractometry`, `Microscopy`). Two ",
        "different concept ids inside one Group are the same test measured ",
        "differently, so scoring on the Group as well as on the id separates ",
        "\"wrong analyte\" from \"right analyte, different decoration\"."
      ), width = 80),
      "",
      strwrap(paste0(
        "Group membership comes from the OMOP vocabulary itself ",
        "(`0_GetMeasurementOmopData/loinc_group_membership.tsv`), keyed by ",
        "`concept_id`. A concept belongs to several Groups, so the test is ",
        "whether the two concepts share one, and the Group reported is the ",
        "most specific shared one. ParentGroups are excluded -- OMOP models ",
        "those as Groups too, and LG100-4 \"Flowsheet - laboratory\" would make ",
        "any two lab chemistry concepts look related."
      ), width = 80),
      "",
      strwrap(paste0(
        "**", nComparable, " / ", nChecked, " (", .formatPct(nComparable / max(nChecked, 1)),
        ") of the checked codes carry a Group on both sides** and can be judged ",
        "this way at all; the rest are scored on the concept id alone, so the ",
        "Group row below is a floor, not a ceiling."
      ), width = 80),
      "",
      .markdownTable(levels),
      "",
      "How tight was the Group that did the recovering — the count of standard",
      "Measurement concepts it holds. A pair sharing a 4-member Group is a much",
      "stronger claim than one sharing a 200-member Group:",
      "",
      .markdownTable(recoveredBySize),
      if (length(recoveredLines) > 0) c(
        "",
        "Rows the concept-id score counts as disagreements and the Group score",
        "counts as agreements — read the two concept names side by side to judge",
        "whether the rollup is fair in each case:",
        "",
        recoveredLines
      ) else character(0)
    )
  }

  # Five examples of each of the two failure outcomes. Sampling is deduplicated
  # first -- disagreements by their (our concept, reference concept) pair, and
  # declines by TEST_NAME -- because taking the head of the table drew ten
  # spellings of one CRP code failing the same way, and plain random sampling
  # would not have fixed that: a code that recurs under ten spellings is ten
  # times as likely to be drawn. Seeded so re-runs on the same data agree.
  set.seed(1)
  withOutcome <- checked |>
    dplyr::mutate(evidence_level = dplyr::coalesce(.data$evidence_level, "(unknown)"))

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

  compareSection <- c(
    "## Compare with reference",
    "",
    strwrap(paste0(
      "`", referenceMappingFile, "` holds a separately curated Finnish-code ",
      "-> OMOP mapping, restricted here to its `APPROVED` rows and matched to ",
      "this table by `TEST_NAME` + `UNIT` (an empty `UNIT` counts as a unit of ",
      "its own, so a code with no unit recorded is a different row from the ",
      "same code in `mmol/l`, on both sides of the join)."
    ), width = 80),
    "",
    strwrap(paste0(
      "**", nChecked, " / ", nRows, " codes (", .formatPct(nChecked / nRows),
      ") carry an APPROVED reference mapping** for their `TEST_NAME`+`UNIT`. ",
      "The rest of this section focuses only on those ", nChecked, " codes -- ",
      "the ones with something to compare against; a code with no APPROVED ",
      "reference row has nothing to agree or disagree with and is dropped ",
      "from every table and example below."
    ), width = 80),
    "",
    "The reference is the best mapping available, not ground truth — it contains",
    "errors of its own (it sends the rapid-test code `c-reaktiivinenproteiini,pika`",
    "to a high-sensitivity CRP concept, though that row's values floor at 5 mg/l),",
    "and it is internally inconsistent on some panel families. Read the figures",
    "below as *agreement*, not as correctness.",
    "",
    "### By evidence level",
    "",
    "What the local row actually carried. The reference gives",
    "more than one concept across a code's units for only ~6% of multi-unit codes,",
    "so it is in practice a `TEST_NAME` -> concept mapping, while this pipeline maps",
    "`(TEST_NAME, UNIT)`. A `name`-only row has nothing that fixes its quantity, so",
    "`5_FixLOINC` takes a concept there only when the name alone settles it",
    "and declines otherwise — which is why those rows both get AI-mapped less",
    "often and agree less often. `p_codes` is this row's share of all",
    paste0(nChecked, " codes in the reference; `p_ai_mapped` is of this row's"),
    "own codes, how many got AI-mapped; `p_agree` is of the ones this row",
    "actually mapped, how many agreed:",
    "",
    .markdownTable(byEvidenceCodes),
    "",
    "The same breakdown weighted by records instead of codes:",
    "",
    .markdownTable(byEvidenceEvents),
    "",
    "### By record volume",
    "",
    strwrap(paste0(
      "The reference was curated for the codes that carry the data: it covers ",
      "97% of the rows with 50,000+ records and under 30% of those below 500. ",
      "Grouping by how many records a code actually has -- restricted, like the ",
      "rest of this section, to the ", nChecked, " codes with an APPROVED ",
      "reference mapping -- shows whether agreement holds up for the ",
      "high-volume codes the reference was written for, or only for the tail ",
      "it barely touches."
    ), width = 80),
    "",
    .markdownTable(byVolumeCodes),
    "",
    "The same breakdown weighted by records instead of codes:",
    "",
    .markdownTable(byVolumeEvents),
    groupSection,
    if (length(declinedLines) > 0) c(
      "",
      "### Examples — not automapped",
      "",
      "Five of the rows the reference maps but the pipeline left empty. An empty",
      "`loinc_name_guess` means `4_FindLOINC` could not name the test at all;",
      "a filled one means the search returned nothing the model would accept.",
      if (nNoReasoning > 0) paste0(
        "`reasoning` is empty on ", nNoReasoning, " of these: the prompt currently asks ",
        "for it only when a concept was chosen, so the pipeline does not record WHY it ",
        "declined. That is the most useful thing it could say about these rows."
      ) else "",
      "",
      declinedLines
    ) else character(0),
    if (length(disagreementLines) > 0) c(
      "",
      "### Examples — disagreement",
      "",
      "Five of the rows where the pipeline produced an id and the reference has a",
      "different one, sampled from the *distinct* (our concept, reference concept)",
      "pairs so one recurring disagreement cannot fill the table. `reasoning` is what",
      "`5_FixLOINC` gave for that choice, clause by clause — so the mistake",
      "can be read rather than guessed at.",
      "",
      disagreementLines
    ) else character(0)
  )
}

# Overview: one funnel, every step this pipeline takes from a raw local code
# to an agreed OMOP concept. The last two rows depend on the reference and
# print "-" when it is unavailable, same as the rest of the report degrading
# gracefully.
refCount <- function(cond) if (referenceAvailable) sum(cond, na.rm = TRUE) else NA_integer_
refSum <- function(x, cond) if (referenceAvailable) sum(x[cond], na.rm = TRUE) else NA_real_

overviewN <- c(
  nRows,
  sum(codes$named),
  sum(codes$named & codes$matched),
  refCount(codes$outcome != "not in reference"),
  refCount(codes$outcome == "agreement"),
  nAgreeGroupOverview
)
overviewEvents <- c(
  totalEvents,
  sum(codes$nRecords[codes$named], na.rm = TRUE),
  sum(codes$nRecords[codes$named & codes$matched], na.rm = TRUE),
  refSum(codes$nRecords, codes$outcome != "not in reference"),
  refSum(codes$nRecords, codes$outcome == "agreement"),
  eventsAgreeGroupOverview
)
overview <- tibble::tibble(
  step = c("total", "has a guessed loinc", "has a fixed loinc", "exists in reference",
           "agrees with reference (concept id)", "agrees with reference (LOINC Group)"),
  n_codes = ifelse(is.na(overviewN), "-", format(overviewN, big.mark = ",")),
  p_codes = ifelse(is.na(overviewN), "-", .formatPct(overviewN / nRows)),
  n_events = ifelse(is.na(overviewEvents), "-", format(overviewEvents, big.mark = ",")),
  p_events = ifelse(is.na(overviewEvents), "-", .formatPct(overviewEvents / totalEvents))
)

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
  "Each local code carries the OMOP concept `5_FixLOINC` chose for it",
  "from a shortlist that a semantic search over the LOINC vocabulary returned for",
  "the name `4_FindLOINC` guessed. One funnel, from a raw local code",
  "to a concept that agrees with the separately curated reference mapping:",
  "",
  .markdownTable(overview),
  "",
  "\"Reference\" here and below means the reference's **`APPROVED`** rows",
  "only — a code with only an `UNCHECKED`/`NOT-FOUND`/`IGNORED` reference row",
  "counts as absent from it, not as a match or a miss (see Compare with",
  "reference).",
  "",
  compareSection
)

outFile <- file.path(outDir, "loincToOmopMappingStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
