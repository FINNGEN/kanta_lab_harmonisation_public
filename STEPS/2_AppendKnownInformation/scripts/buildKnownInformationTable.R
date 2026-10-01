#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
labSummaryFile <- args[1]
labCodesFile <- args[2]
prefixesFile <- args[3]
suffixesFile <- args[4]
outDir <- args[5]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  labSummaryFile = ", labSummaryFile)
ParallelLogger::logInfo("  labCodesFile = ", labCodesFile)
ParallelLogger::logInfo("  prefixesFile = ", prefixesFile)
ParallelLogger::logInfo("  suffixesFile = ", suffixesFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
# na = "" (not readr's default c("", "NA")): the TEST_NAME "na" is a real
# abbreviation, not a missing value, and labSummaryFile itself only ever
# writes "" for a genuine missing value.
labSummary <- readr::read_tsv(labSummaryFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(labSummary), " rows from ", labSummaryFile)

# Drop the upstream's stringified missing test name. The source extract
# (test_unit_counts.txt) was written by something that renders a missing value
# as the text "NA" (R's write.table default), so records with no test name at
# all arrived as a TEST_NAME of literally "NA" -- one row per UNIT they were
# grouped into. They are not a test: the 31 rows span 31 unrelated units
# (mmol/l, e9/l, fl, mm/h, ml/min/173m2, ...) that belong to completely
# different assays, and none of them carries deciles.
#
# The match is case-sensitive and exact on purpose. Uppercase "NA" is the only
# uppercase TEST_NAME in the whole dataset -- every real code is lowercased --
# whereas lowercase "na" IS a real code (24 records with a genuine decile
# distribution) and must survive. Matching case-insensitively here would
# silently delete it.
isMissingTestName <- labSummary$TEST_NAME == "NA" & !is.na(labSummary$TEST_NAME)
if (any(isMissingTestName)) {
  ParallelLogger::logWarn(
    "Dropping ", sum(isMissingTestName), " row(s) whose TEST_NAME is the literal text \"NA\" ",
    "(the upstream extract's stringified missing value), covering ",
    format(sum(as.numeric(labSummary$n[isMissingTestName]), na.rm = TRUE), big.mark = ","),
    " records with no recorded test name"
  )
  labSummary <- labSummary[!isMissingTestName, ]
}

labCodes <- readr::read_tsv(labCodesFile, show_col_types = FALSE)
ParallelLogger::logInfo("Read ", nrow(labCodes), " rows from ", labCodesFile)

prefixes <- readr::read_tsv(prefixesFile, show_col_types = FALSE)
ParallelLogger::logInfo("Read ", nrow(prefixes), " rows from ", prefixesFile)

suffixes <- readr::read_tsv(suffixesFile, show_col_types = FALSE)
ParallelLogger::logInfo("Read ", nrow(suffixes), " rows from ", suffixesFile)

#
# --- Action -------------------------------------------------------------
#

# LongName: join on TEST_NAME = lowercase(Abbreviation) with spaces removed.
# A handful of normalized abbreviations map to more than one LongName in the
# source table (genuine duplicates, e.g. superseded codes) -- keep every
# distinct LongName, joined with "; ".
longNames <- labCodes |>
  dplyr::mutate(abrvNorm = tolower(gsub(" ", "", Abbreviation, fixed = TRUE))) |>
  dplyr::filter(!is.na(abrvNorm), abrvNorm != "") |>
  dplyr::group_by(abrvNorm) |>
  dplyr::summarise(LongName = paste(unique(LongName), collapse = "; "), .groups = "drop")
ParallelLogger::logInfo("Built ", nrow(longNames), " distinct normalized abbreviations with a LongName")

# prefix_meaning: TEST_NAME is "<prefix>-<rest>", prefix is 1 or 2 letters
# (per DATA/SourceLabelingData/README.md). A 2-letter prefix match wins over
# a 1-letter one when both would apply. code_prefixes.tsv has two rows for
# id "fb" (fB = fasting blood, Fb = foreign body, a genuine collision in the
# source) -- both meanings are kept, joined with "; ".
prefixMeanings <- prefixes |>
  dplyr::group_by(id) |>
  dplyr::summarise(prefix_meaning = paste(unique(prefix_meaning), collapse = "; "), .groups = "drop")
prefixMeanings1 <- prefixMeanings |> dplyr::filter(nchar(id) == 1)
prefixMeanings2 <- prefixMeanings |> dplyr::filter(nchar(id) == 2)

# suffix_meaning: TEST_NAME optionally ends in "-<suffix>"; suffix ids in
# code_suffixes.tsv already include the leading hyphen. Longest matching id
# wins.
suffixMeanings <- suffixes |>
  dplyr::group_by(id) |>
  dplyr::summarise(suffix_meaning = paste(unique(suffix_meaning), collapse = "; "), .groups = "drop")

result <- labSummary |>
  dplyr::left_join(longNames, by = c("TEST_NAME" = "abrvNorm")) |>
  dplyr::mutate(
    .cand2 = ifelse(substr(TEST_NAME, 3, 3) == "-", substr(TEST_NAME, 1, 2), NA_character_),
    .cand1 = ifelse(substr(TEST_NAME, 2, 2) == "-", substr(TEST_NAME, 1, 1), NA_character_),
    prefix_meaning = dplyr::coalesce(
      prefixMeanings2$prefix_meaning[match(.cand2, prefixMeanings2$id)],
      prefixMeanings1$prefix_meaning[match(.cand1, prefixMeanings1$id)]
    )
  )

suffixMeaning <- rep(NA_character_, nrow(result))
nch <- nchar(result$TEST_NAME)
for (suffixLength in sort(unique(nchar(suffixMeanings$id)), decreasing = TRUE)) {
  idsAtLength <- suffixMeanings$id[nchar(suffixMeanings$id) == suffixLength]
  meaningsAtLength <- suffixMeanings$suffix_meaning[nchar(suffixMeanings$id) == suffixLength]
  candidate <- ifelse(nch >= suffixLength, substr(result$TEST_NAME, nch - suffixLength + 1, nch), NA_character_)
  matched <- meaningsAtLength[match(candidate, idsAtLength)]
  suffixMeaning <- dplyr::coalesce(suffixMeaning, matched)
}

result <- result |>
  dplyr::mutate(suffix_meaning = suffixMeaning) |>
  dplyr::select(-.cand1, -.cand2) |>
  dplyr::arrange(TEST_NAME)

nMatchedLongName <- sum(!is.na(result$LongName))
nMatchedPrefix <- sum(!is.na(result$prefix_meaning))
nMatchedSuffix <- sum(!is.na(result$suffix_meaning))
ParallelLogger::logInfo(nMatchedLongName, " / ", nrow(result), " rows matched a LongName")
ParallelLogger::logInfo(nMatchedPrefix, " / ", nrow(result), " rows matched a prefix_meaning")
ParallelLogger::logInfo(nMatchedSuffix, " / ", nrow(result), " rows matched a suffix_meaning")

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "knownInformation.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows to ", outFile)
