#
# group_codes_by_stringdist.R
#
# Experiment: group the local test-code names in CODE_COUNTS/test_unit_counts.txt
# (NAME column) into similarity-based clusters averaging TARGET_AVG_GROUP_SIZE
# codes each, using only string-edit distance between the names (no OMOP
# concept, no units).
#
# Filters applied before grouping:
#   - drop any NAME that is purely numerical (e.g. "247") - these are not real
#     test abbreviations, just stray numeric codes.
#   - keep only names whose total COUNT (summed across all of that name's
#     unit rows) exceeds MIN_COUNT - drops the long tail of rare/noise codes.
#
# Approach:
#   1. Take the filtered, unique NAME values.
#   2. Compute all pairwise OSA (optimal string alignment) edit distances once.
#   3. Hierarchical-cluster (Ward's method - average linkage produced one
#      giant ~8600-code cluster instead of real groups) and cut the tree with
#      cutree(k = nCodes / GROUP_SIZE) so the *average* cluster size equals
#      GROUP_SIZE. Sizes are otherwise free to vary.
#   4. Ward's method alone still leaves one oversized cluster (raw edit
#      distance makes all short strings mutually "close" regardless of
#      meaning), so any resulting group more than OVERSIZED_FACTOR times the
#      target size is recursively re-clustered on its own (reusing the
#      already-computed distance submatrix, no new stringdist calls) until it
#      breaks up or a recursion-depth limit is hit.
#   5. As a sanity check, compare the average within-group pairwise distance
#      of the final stringdist-based groups against groups formed by naive
#      alphabetical-order chunking of the same codes into equal-size blocks.
#
# Run from the repo root:
#   Rscript EXPERIMENTS/stringdist_grouping/group_codes_by_stringdist.R
#

#
# --- Libraries --------------------------------------------------------------
#
library(readr)
library(dplyr)
library(stringdist)
library(purrr)

#
# --- Configuration -----------------------------------------------------------
#
pathToInputTXT  <- "CODE_COUNTS/test_unit_counts.txt"
pathToOutputTSV <- "EXPERIMENTS/stringdist_grouping/output/code_stringdist_groups.tsv"
targetAvgGroupSize <- 100 # groups vary in size; number of groups is chosen so the AVERAGE size is this
minCount <- 100 # keep names whose total COUNT (summed across units) exceeds this
distMethod <- "osa" # optimal string alignment (Damerau-Levenshtein-like)
linkageMethod <- "ward.D2" # minimizes within-cluster variance; average linkage produced one
                            # giant ~8600-code cluster plus mostly singletons (chaining effect)
oversizedFactor <- 2 # re-cluster any group bigger than this many times targetAvgGroupSize, on its own
maxRecursionDepth <- 6 # safety cap on how many times a group can be recursively re-split

#
# --- Read data ----------------------------------------------------------------
#
rawData <- readr::read_tsv(
    pathToInputTXT,
    col_types = readr::cols(NAME = readr::col_character(), UNIT = readr::col_character(),
                             COUNT = readr::col_double(), `%MISSING` = readr::col_double())
)
nRawNames <- dplyr::n_distinct(rawData$NAME)

nameTotals <- rawData |>
    dplyr::summarise(total_count = sum(COUNT), .by = NAME)

isPurelyNumeric <- grepl("^[0-9]+(\\.[0-9]+)?$", nameTotals$NAME)

codes <- nameTotals |>
    dplyr::filter(!isPurelyNumeric, total_count > minCount) |>
    dplyr::pull(NAME) |>
    sort()
nCodes <- length(codes)

message(
    "Names in input: ", nRawNames, "\n",
    "  - dropped (purely numerical): ", sum(isPurelyNumeric), "\n",
    "  - dropped (total COUNT <= ", minCount, "): ",
    sum(!isPurelyNumeric & nameTotals$total_count <= minCount), "\n",
    "  -> remaining names to group: ", nCodes
)

#
# --- Pairwise string distance (computed once, reused for every recursive split) -
#
message("Computing pairwise ", distMethod, " distance matrix (", nCodes, " codes)...")
t0 <- Sys.time()
d <- stringdist::stringdistmatrix(codes, method = distMethod, nthread = parallel::detectCores())
distMat <- as.matrix(d)
message("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), "s")

#
# --- Cluster, then recursively re-cluster any oversized group on its own --------
#
# Operates on indices into `codes`/`distMat` throughout, so a recursive call
# just subsets the already-computed distance matrix - no new stringdist calls.
clusterRecursively <- function(idx, depth = 0) {
    n <- length(idx)
    k <- max(1, round(n / targetAvgGroupSize))
    if (n <= 1 || k <= 1) {
        return(list(idx))
    }

    hcSub <- hclust(as.dist(distMat[idx, idx]), method = linkageMethod)
    subGroupsIdx <- split(idx, cutree(hcSub, k = k))

    purrr::flatten(lapply(subGroupsIdx, function(g) {
        isOversized <- length(g) > oversizedFactor * targetAvgGroupSize
        canRecurse <- depth < maxRecursionDepth && length(g) < n # must shrink, or we'd loop forever
        if (isOversized && canRecurse) {
            message("  [depth ", depth + 1, "] re-clustering an oversized group of ", length(g), " codes on its own...")
            clusterRecursively(g, depth + 1)
        } else {
            list(g)
        }
    }))
}

message("Clustering (", linkageMethod, " linkage; re-splitting any group > ", oversizedFactor, "x target size, up to depth ", maxRecursionDepth, ")...")
t0 <- Sys.time()
finalGroupsIdx <- unname(clusterRecursively(seq_len(nCodes))) # strip split()-inherited names:
# imap() below uses names(.x) as the id whenever present, and split() labels
# ("1", "2", ...) collide across different recursive branches, which would
# silently merge unrelated clusters under the same stringdist_group_id.
message("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), "s")

groups <- purrr::imap_dfr(finalGroupsIdx, function(idx, groupId) {
    tibble::tibble(TEST_NAME_ABBREVIATION = codes[idx], stringdist_group_id = as.integer(groupId))
}) |>
    dplyr::arrange(stringdist_group_id, TEST_NAME_ABBREVIATION) |>
    dplyr::mutate(
        position_in_group = dplyr::row_number(),
        group_size = dplyr::n(),
        .by = stringdist_group_id
    )

nGroups <- length(finalGroupsIdx)
groupSizes <- purrr::map_int(finalGroupsIdx, length)
message(
    "Formed ", nGroups, " groups (target average size ", targetAvgGroupSize, "); ",
    "actual sizes: mean=", round(mean(groupSizes), 1),
    ", median=", median(groupSizes),
    ", min=", min(groupSizes),
    ", max=", max(groupSizes)
)

#
# --- Sanity check: stringdist-order groups vs. naive alphabetical groups --------
#
# Mean within-group pairwise distance, sampling a handful of groups (computing
# it for every group over the full distance object is unnecessary to make the
# point). Reuses `distMat` computed above.
set.seed(1) # nolint: seed only used to pick which groups to sample for the sanity check, not for the grouping itself
sampleGroupIds <- sample(seq_len(nGroups), min(20, nGroups))

stringdistGroupsList <- split(groups$TEST_NAME_ABBREVIATION, groups$stringdist_group_id)[as.character(sampleGroupIds)]

alphabeticalOrder <- codes # already sorted alphabetically from `sort(unique(...))`
alphabeticalGroupId <- ceiling(seq_along(alphabeticalOrder) / targetAvgGroupSize)
alphabeticalGroupsAll <- split(alphabeticalOrder, alphabeticalGroupId)
alphabeticalGroupsList <- alphabeticalGroupsAll[as.character(sampleGroupIds[sampleGroupIds <= length(alphabeticalGroupsAll)])]

meanWithin <- function(grpCodes) {
    i <- match(grpCodes, codes)
    if (length(i) < 2) {
        return(NA_real_)
    }
    sub <- distMat[i, i]
    mean(sub[upper.tri(sub)])
}

stringdistMeans <- purrr::map_dbl(stringdistGroupsList, meanWithin)
alphabeticalMeans <- purrr::map_dbl(alphabeticalGroupsList, meanWithin)

message(
    "\nSanity check (mean within-group pairwise ", distMethod, " distance, ",
    length(sampleGroupIds), " sampled groups):\n",
    "  stringdist-order groups: mean = ", round(mean(stringdistMeans, na.rm = TRUE), 2),
    " (lower = more similar within group)\n",
    "  alphabetical-order groups: mean = ", round(mean(alphabeticalMeans, na.rm = TRUE), 2)
)

#
# --- A few example groups, printed for a quick eyeball check --------------------
#
message("\nExample groups:")
for (gid in head(sampleGroupIds, 3)) {
    exampleCodes <- groups |> dplyr::filter(stringdist_group_id == gid) |> dplyr::pull(TEST_NAME_ABBREVIATION)
    message("Group ", gid, " (n=", length(exampleCodes), "): ", paste(head(exampleCodes, 15), collapse = ", "), " ...")
}

#
# --- Write output ----------------------------------------------------------------
#
readr::write_tsv(groups, pathToOutputTSV)
message("\nWrote ", nrow(groups), " codes in ", nGroups, " groups to: ", pathToOutputTSV)
