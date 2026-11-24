#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
harmonisedFile <- args[1]
settingsFile <- args[2]
outDir <- args[3]

# A pair is only tested when its reference is made of at least this many other pairs.
minReferencePairs <- 2
# A pair with fewer non-missing values than this counts as having no values: it is neither tested
# nor part of a reference. n_records_no_value_threshold and n_subjects_no_value_threshold of DATA/settings.yaml.
# The settings of the repo (DATA/settings.yaml), one section per block or step.
readSetting <- function(settingsFile, section, key) {
  value <- yaml::read_yaml(settingsFile)[[section]][[key]]
  if (!is.numeric(value) || length(value) != 1) stop(section, ": ", key, " is missing or not a number in ", settingsFile)
  value
}
minValues <- readSetting(settingsFile, "1_Input", "n_records_no_value_threshold")
minSubjects <- readSetting(settingsFile, "1_Input", "n_subjects_no_value_threshold")
# KS thresholds of harmonisation_values_status: AGREE under ksAgree, WARNING up to ksDisagree,
# DISAGREE above.
ksAgree <- readSetting(settingsFile, "5_EvaluateHarmonisedData", "ks_agree_threshold")
ksDisagree <- readSetting(settingsFile, "5_EvaluateHarmonisedData", "ks_disagree_threshold")

pathToEvaluatedTSV <- file.path(outDir, "evaluatedHarmonisedKantaAgregatedTable.tsv")
pathToKsWarningTSV <- file.path(outDir, "ks_test_warning.tsv")
pairKey <- c("TEST_NAME", "MEASUREMENT_UNIT")

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  harmonisedFile = ", harmonisedFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  settingsFile = ", settingsFile, " (n_records_no_value_threshold = ", minValues, ", n_subjects_no_value_threshold = ", minSubjects, ")")
ParallelLogger::logInfo("  minReferencePairs = ", minReferencePairs)

#
# --- Input -------------------------------------------------------------
#
harmonised <- readr::read_tsv(
  harmonisedFile,
  col_types = readr::cols(
    TEST_NAME = readr::col_character(),
    MEASUREMENT_UNIT = readr::col_character(),
    UNIT = readr::col_character(),
    n = readr::col_double(),
    n_subjects = readr::col_double(),
    unit_source_injection_correction_na_p = readr::col_character(),
    reference_range = readr::col_character(),
    value_missing_p = readr::col_double(),
    value_source_extracted_qcout_na_p = readr::col_character(),
    decile = readr::col_double(),
    decile_value = readr::col_double(),
    decile_value_harmonised = readr::col_double(),
    unit_fix_reasoning = readr::col_character(),
    concept_id = readr::col_integer(),
    ignore_mapping_reason = readr::col_character(),
    mapping_status = readr::col_character(),
    concept_code = readr::col_character(),
    concept_name = readr::col_character(),
    vocabulary_id = readr::col_character(),
    is_panel = readr::col_logical(),
    has_component = readr::col_character(),
    has_property = readr::col_character(),
    group_concept_id = readr::col_character(),
    group_concept_code = readr::col_character(),
    group_concept_name = readr::col_character(),
    target_unit = readr::col_character(),
    target_unit_source = readr::col_character(),
    HARMONISED_UNIT = readr::col_character(),
    CONVERSION = readr::col_character(),
    mapping_warning_messages = readr::col_character()
  ),
  na = ""
)
ParallelLogger::logInfo("Read ", nrow(harmonised), " rows from ", harmonisedFile)

#
# --- Action -------------------------------------------------------------
#

# 1. One row per pair: the columns that do not change with the decile, and the
#    deciles of decile_value and decile_value_harmonised as a matrix (pair x decile 1..9).
pairs <- harmonised |>
  dplyr::select(-decile, -decile_value, -decile_value_harmonised) |>
  dplyr::distinct()
stopifnot(!anyDuplicated(pairs[pairKey]))

decileMatrix <- function(valueColumn) {
  wide <- harmonised |>
    dplyr::filter(!is.na(decile)) |>
    dplyr::transmute(
      dplyr::across(dplyr::all_of(pairKey)),
      d = paste0("d", round(decile * 10)),
      value = .data[[valueColumn]]
    ) |>
    tidyr::pivot_wider(names_from = d, values_from = value)
  for (d in setdiff(paste0("d", 1:9), names(wide))) wide[[d]] <- NA_real_
  joined <- dplyr::left_join(pairs[pairKey], wide, by = pairKey)
  as.matrix(joined[paste0("d", 1:9)])
}
deciles <- decileMatrix("decile_value")
decilesHarmonised <- decileMatrix("decile_value_harmonised")

# 2. The reference of a pair is the LOINC Group of its concept: all the approved pairs in
#    the Group. A concept can be in several Groups, the most specific first (the order of
#    group_concept_id): the first one that has at least minReferencePairs OTHER approved
#    pairs gives the reference. If the concept is in no LOINC Group, the reference is the
#    concept: all the approved pairs with the same concept_id. Only the pairs with the same
#    HARMONISED_UNIT as the tested pair count, as the values of other units are not on the
#    same scale. The pair itself is never part of its reference. A pair is approved when its mapping_status is APPROVED (not
#    ERROR, IGNORE or NOT-APPROVED). The reference deciles are, for each decile, the median
#    of the harmonised deciles of those pairs, each weighted by sqrt(n values), so a very
#    large pair does not take over. A pair with no HARMONISED_UNIT (a qualitative concept, a
#    panel, or a concept with no target unit) is neither tested nor part of a reference. Only
#    the APPROVED pairs are tested (NOT-APPROVED, ERROR, IGNORE and MISSING pairs are not).
nValues <- pairs$n * (1 - dplyr::coalesce(pairs$value_missing_p, 0) / 100)
hasDeciles <- complete.cases(decilesHarmonised) & nValues >= minValues & dplyr::coalesce(pairs$n_subjects, 0) >= minSubjects
isApproved <- pairs$mapping_status %in% "APPROVED"
hasUnit <- !is.na(pairs$HARMONISED_UNIT)
isReference <- hasDeciles & isApproved & hasUnit

referenceKeysOfPair <- purrr::map2(pairs$group_concept_id, pairs$concept_id, function(groups, conceptId) {
  if (!is.na(groups)) {
    paste0("group:", strsplit(groups, ";", fixed = TRUE)[[1]])
  } else if (!is.na(conceptId) && conceptId > 0) {
    paste0("concept:", conceptId)
  } else {
    character(0)
  }
})
referenceIndex <- which(isReference)
referenceByKey <- split(
  rep(referenceIndex, lengths(referenceKeysOfPair[referenceIndex])),
  unlist(referenceKeysOfPair[referenceIndex])
)

weightedMedian <- function(x, w) {
  o <- order(x)
  x <- x[o]
  cumulative <- cumsum(w[o])
  x[which(cumulative >= cumulative[length(cumulative)] / 2)[1]]
}

# 3. KS between the deciles of the pair and the reference. Each set of deciles is a step CDF
#    (the CDF at a value is the highest decile level at or below it, 0 below the lowest decile).
#    KS is the largest gap between the two CDFs over the decile values of both. The p-value is
#    the asymptotic one, with n values of the pair and of the reference (sum of the pairs).
decileLevels <- 1:9 / 10
ksTest <- function(deciles1, deciles2, n1, n2) {
  v1 <- sort(deciles1)
  v2 <- sort(deciles2)
  x <- sort(unique(c(v1, v2)))
  F1 <- c(0, decileLevels)[findInterval(x, v1) + 1]
  F2 <- c(0, decileLevels)[findInterval(x, v2) + 1]
  D <- max(abs(F1 - F2))
  lambda <- sqrt(n1 * n2 / (n1 + n2)) * D
  pValue <- if (D == 0) 1 else 2 * sum((-1)^(1:100 - 1) * exp(-2 * (1:100)^2 * lambda^2))
  c(KS = D, pValue = max(min(pValue, 1), 0))
}

testable <- which(hasDeciles & hasUnit & isApproved & lengths(referenceKeysOfPair) > 0)
ks <- rep(NA_real_, nrow(pairs))
pValue <- rep(NA_real_, nrow(pairs))
log10D5 <- rep(NA_real_, nrow(pairs))
referenceGroup <- rep(NA_character_, nrow(pairs))
referenceType <- rep(NA_character_, nrow(pairs))
referenceDeciles <- matrix(NA_real_, nrow(pairs), 9)
nReferencePairs <- rep(NA_integer_, nrow(pairs))

for (i in testable) {
  for (key in referenceKeysOfPair[[i]]) {
    others <- setdiff(referenceByKey[[key]], i)
    others <- others[pairs$HARMONISED_UNIT[others] %in% pairs$HARMONISED_UNIT[i]]
    if (length(others) < minReferencePairs) next
    weights <- sqrt(nValues[others])
    referenceDeciles[i, ] <- apply(decilesHarmonised[others, , drop = FALSE], 2, weightedMedian, w = weights)
    result <- ksTest(decilesHarmonised[i, ], referenceDeciles[i, ], nValues[i], sum(nValues[others]))
    ks[i] <- result[["KS"]]
    pValue[i] <- result[["pValue"]]
    if (decilesHarmonised[i, 5] > 0 && referenceDeciles[i, 5] > 0) {
      log10D5[i] <- log10(decilesHarmonised[i, 5] / referenceDeciles[i, 5])
    }
    isGroup <- startsWith(key, "group:")
    referenceType[i] <- if (isGroup) "LOINC Group" else "concept_id"
    referenceGroup[i] <- if (isGroup) sub("^group:", "", key) else NA_character_
    nReferencePairs[i] <- length(others)
    break
  }
}

ParallelLogger::logInfo(
  nrow(pairs), " TEST_NAME + MEASUREMENT_UNIT pairs, ", sum(hasDeciles), " with harmonised deciles, ",
  sum(isReference), " approved reference pairs"
)
ParallelLogger::logInfo(
  sum(!is.na(ks)), " pairs tested, ", sum(hasDeciles) - sum(!is.na(ks)),
  " with harmonised deciles not tested (not APPROVED, no HARMONISED_UNIT, or no LOINC Group or concept with at least ",
  minReferencePairs, " other approved pairs)"
)
ParallelLogger::logInfo(
  sum(referenceType %in% "LOINC Group"), " pairs with the LOINC Group as reference, ",
  sum(referenceType %in% "concept_id"), " with the concept_id (the concept is in no LOINC Group)"
)

# 4. The deciles as text, e.g. [ 1.08, 1.11, 1.13, 1.14, 1.16, 1.17, 1.19, 1.2, 1.23 ] (3
#    significant digits); empty when the pair has no complete deciles.
decilesToString <- function(m) {
  apply(m, 1, function(v) {
    if (anyNA(v)) NA_character_ else paste0("[ ", paste(signif(v, 3), collapse = ", "), " ]")
  })
}

evaluated <- pairs |>
  dplyr::mutate(
    decile_value = decilesToString(deciles),
    decile_value_harmonised = decilesToString(decilesHarmonised),
    reference_decile_value_harmonised = decilesToString(referenceDeciles),
    .after = value_source_extracted_qcout_na_p
  ) |>
  dplyr::mutate(
    KS = round(ks, 3),
    KS_mlp = round(-log10(pmax(pValue, 1e-300)), 2),
    log10_D5 = round(log10D5, 3),
    in_reference = isReference,
    reference_type = referenceType,
    reference_group_concept_id = referenceGroup,
    n_reference_pairs = nReferencePairs
  ) |>
  dplyr::arrange(dplyr::desc(n), TEST_NAME, MEASUREMENT_UNIT, UNIT)

# 5. harmonisation_values_status: the row of the Harmonised Values table of the dashboard each pair
#    falls in, the first that applies. Only APPROVED pairs are compared. A pair with fewer than
#    minValues values or fewer than minSubjects subjects has no value whatever its status. An approved pair that is not compared has no
#    UNIT (an error), has incomplete deciles, is
#    qualitative or a panel (target_unit_source), or has too few other approved pairs in its Group
#    (or concept).
isApprovedPair <- evaluated$mapping_status %in% "APPROVED"
evaluated <- evaluated |>
  dplyr::mutate(
    harmonisation_values_status = dplyr::case_when(
      n * (1 - dplyr::coalesce(value_missing_p, 0) / 100) < minValues | dplyr::coalesce(n_subjects, 0) < minSubjects ~
        paste0("No value: fewer than ", minValues, " values or ", minSubjects, " subjects"),
      !is.na(KS) & KS < ksAgree ~ "AGREE",
      !is.na(KS) & KS <= ksDisagree ~ "WARNING",
      !is.na(KS) ~ "DISAGREE",
      !isApprovedPair ~ "Not mapped (NOT-APPROVED, IGNORE, MISSING or ERROR)",
      target_unit_source %in% c("isQualitative", "panel") ~ "No value: value ignored, is qualitative or panel",
      is.na(UNIT) ~ "Error: values with missing units",
      is.na(target_unit) | is.na(CONVERSION) ~ "unexpected: approved pair with a UNIT but no conversion",
      is.na(decile_value_harmonised) ~ "unexpected: pair with enough values but no deciles",
      TRUE ~ "Not compared: only one pair per group"
    )
  ) |>
  dplyr::relocate(mapping_status, harmonisation_values_status)
ParallelLogger::logInfo(
  paste(names(table(evaluated$harmonisation_values_status)), table(evaluated$harmonisation_values_status), collapse = ", "),
  " (harmonisation_values_status)"
)
# An approved pair with a UNIT always has a CONVERSION to a target unit: otherwise
# 4_BuildHarmonisationTable gives it ERROR:MissingConversion (or another error), so it is not approved.
# A pair with enough values and subjects always has its deciles: 1_BuildKantaAgregatedTable stops otherwise.
nUnexpected <- sum(startsWith(evaluated$harmonisation_values_status, "unexpected"))
if (nUnexpected > 0) {
  stop(nUnexpected, " pairs have an unexpected status (no CONVERSION, or no deciles); see harmonisation_values_status")
}

# 6. ks_test_warning.tsv: one row per pair whose values are a WARNING or DISAGREE with its reference, with
#    an `ignore` flag set to TRUE by hand when the difference was reviewed and accepted. The file is
#    brought up to date, not rewritten: a new warning is added (ignore FALSE), a warning that is gone is
#    removed, and a warning already there keeps its `ignore`. A warning is the pair plus its status, so a
#    pair that goes from WARNING to DISAGREE (or back) is a new warning; its KS and log10_D5 are updated.
ksWarnings <- evaluated |>
  dplyr::filter(harmonisation_values_status %in% c("WARNING", "DISAGREE")) |>
  dplyr::transmute(
    TEST_NAME, MEASUREMENT_UNIT, harmonisation_values_status, KS, log10_D5,
    reference = dplyr::if_else(reference_type %in% "LOINC Group", reference_group_concept_id, "concept_id"),
    ignore = FALSE
  ) |>
  dplyr::arrange(TEST_NAME, MEASUREMENT_UNIT)
ksKey <- c("TEST_NAME", "MEASUREMENT_UNIT", "harmonisation_values_status")
if (file.exists(pathToKsWarningTSV)) {
  previous <- readr::read_tsv(
    pathToKsWarningTSV,
    col_types = readr::cols(.default = readr::col_character(), ignore = readr::col_logical()), na = ""
  )
  ksWarnings <- ksWarnings |>
    dplyr::left_join(dplyr::select(previous, dplyr::all_of(ksKey), previous_ignore = ignore), by = ksKey) |>
    dplyr::mutate(ignore = dplyr::coalesce(previous_ignore, FALSE), previous_ignore = NULL)
  ParallelLogger::logInfo(
    nrow(dplyr::anti_join(ksWarnings, previous, by = ksKey)), " KS warnings added, ",
    nrow(dplyr::anti_join(previous, ksWarnings, by = ksKey)), " removed"
  )
}
ParallelLogger::logWarn(nrow(ksWarnings), " pairs with a KS WARNING or DISAGREE (", sum(ksWarnings$ignore), " ignored)")

#
# --- Output -------------------------------------------------------------
#
readr::write_tsv(evaluated, pathToEvaluatedTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(evaluated), " rows to ", pathToEvaluatedTSV)
readr::write_tsv(ksWarnings, pathToKsWarningTSV, na = "")
ParallelLogger::logInfo("Wrote ", nrow(ksWarnings), " rows to ", pathToKsWarningTSV)
