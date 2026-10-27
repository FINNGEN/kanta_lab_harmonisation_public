#
# Adapted from EXPERIMENTS/stringdist_grouping/group_codes_by_stringdist.R:
# group TEST_NAME values into similarity-based clusters of at most
# targetGroupSize names each, using only string-edit distance between the
# names (no OMOP concept, no units).
#
# Approach:
#   1. Take the filtered, unique TEST_NAME values.
#   2. Compute all pairwise OSA (optimal string alignment) edit distances once.
#   3. Hierarchical-cluster (Ward's method -- average linkage produced one
#      giant cluster instead of real groups) into a single dendrogram over all
#      names.
#   4. Walk the dendrogram top-down from the root. At each branch, if its
#      subtree has at most targetGroupSize names, stop and call it a group;
#      otherwise descend into its two children and repeat. This cuts
#      different branches at different heights -- a branch that is already
#      small (a tight, genuinely similar family of names) is kept whole high
#      up in the tree, while a branch dominated by the "everything short is
#      mutually close" chaining effect keeps getting split until its pieces
#      are small too. Every group is guaranteed to be at most
#      targetGroupSize; a name that is unlike anything else can still end up
#      alone, as a singleton branch.
#   5. Each group's id is the root-to-branch path taken to reach it (e.g.
#      "1.2.1": at the root took the 1st child, then the 2nd, then the 1st)
#      -- it falls directly out of the walk, and its number of segments is
#      the group's depth in the tree.
#   6. As a sanity check, compare the average within-group pairwise distance
#      of the final stringdist-based groups against groups formed by naive
#      alphabetical-order chunking of the same names into equal-size blocks.
#

#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
knownInformationFile <- args[1]
outDir <- args[2]
minN <- as.numeric(args[3])
targetGroupSize <- as.numeric(args[4])

distMethod <- "osa" # optimal string alignment (Damerau-Levenshtein-like)
linkageMethod <- "ward.D2" # minimizes within-cluster variance; average linkage produced one
                            # giant cluster plus mostly singletons (chaining effect)

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  knownInformationFile = ", knownInformationFile)
ParallelLogger::logInfo("  outDir = ", outDir)
ParallelLogger::logInfo("  minN = ", minN)
ParallelLogger::logInfo("  targetGroupSize = ", targetGroupSize)
ParallelLogger::logInfo("  distMethod = ", distMethod)
ParallelLogger::logInfo("  linkageMethod = ", linkageMethod)

#
# --- Input -------------------------------------------------------------
#
# na = "" (not readr's default c("", "NA")): some TEST_NAME values are
# literally the text "NA" -- a real abbreviation, not a missing value -- and
# knownInformationFile itself only ever writes "" for a genuine missing value.
knownInformation <- readr::read_tsv(knownInformationFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(knownInformation), " rows from ", knownInformationFile)

#
# --- Action -------------------------------------------------------------
#

# Filters: drop TEST_NAME that are purely numeric (stray codes, never a real
# test abbreviation), and TEST_NAME whose total n (summed across its UNIT
# rows) does not exceed minN (drops the long tail of rare/noise codes).
nameTotals <- knownInformation |>
  dplyr::summarise(totalN = sum(n, na.rm = TRUE), .by = TEST_NAME)
isPurelyNumeric <- grepl("^[0-9]+(\\.[0-9]+)?$", nameTotals$TEST_NAME)
isLowVolume <- nameTotals$totalN <= minN

names <- nameTotals |>
  dplyr::filter(!isPurelyNumeric, !isLowVolume) |>
  dplyr::pull(TEST_NAME) |>
  sort()
nNames <- length(names)

ParallelLogger::logInfo("Distinct TEST_NAME in input: ", nrow(nameTotals))
ParallelLogger::logInfo("  dropped (purely numeric): ", sum(isPurelyNumeric))
ParallelLogger::logInfo("  dropped (total n <= ", minN, "): ", sum(!isPurelyNumeric & isLowVolume))
ParallelLogger::logInfo("  -> remaining TEST_NAME to group: ", nNames)

# Pairwise string distance, computed once for the whole dendrogram.
ParallelLogger::logInfo("Computing pairwise ", distMethod, " distance matrix (", nNames, " names)...")
t0 <- Sys.time()
distMat <- as.matrix(stringdist::stringdistmatrix(names, method = distMethod, nthread = parallel::detectCores()))
ParallelLogger::logInfo("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), "s")

ParallelLogger::logInfo("Clustering (", linkageMethod, " linkage)...")
t0 <- Sys.time()
hc <- hclust(as.dist(distMat), method = linkageMethod)
ParallelLogger::logInfo("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), "s")

# hc$merge[p, ] holds the two children combined at merge step p: a negative
# value -j is leaf j (an original name), a positive value q < p is the
# cluster formed at (earlier) merge step q. Merge steps are indexed so a
# child's step index is always smaller than its parent's, so subtree sizes
# can be filled in with one forward pass.
subtreeSize <- integer(nNames - 1)
childSize <- function(node) if (node < 0) 1L else subtreeSize[node]
for (p in seq_len(nNames - 1)) {
  subtreeSize[p] <- childSize(hc$merge[p, 1]) + childSize(hc$merge[p, 2])
}

# All leaf indices under a node, for a node small enough to finalize as a group.
leavesUnder <- function(node) {
  stack <- node
  leaves <- integer(0)
  while (length(stack) > 0) {
    top <- stack[length(stack)]
    stack <- stack[-length(stack)]
    if (top < 0) {
      leaves <- c(leaves, -top)
    } else {
      stack <- c(stack, hc$merge[top, 1], hc$merge[top, 2])
    }
  }
  leaves
}

# Walk the dendrogram top-down from the root (the last merge step), cutting
# each branch at the height its own subtree first drops to at most
# targetGroupSize -- different branches get cut at different heights. A
# group's id is the root-to-branch path of child choices ("1"/"2" at each
# split) that reaches it; its number of "."-separated segments is its depth.
ParallelLogger::logInfo("Walking the dendrogram (cutting each branch at <= ", targetGroupSize, " names)...")
t0 <- Sys.time()
rootNode <- nNames - 1
stack <- list(list(node = rootNode, path = ""))
finalGroups <- list()
while (length(stack) > 0) {
  top <- stack[[length(stack)]]
  stack[[length(stack)]] <- NULL
  node <- top$node
  path <- top$path
  size <- if (node < 0) 1L else subtreeSize[node]
  if (node < 0 || size <= targetGroupSize) {
    finalGroups[[length(finalGroups) + 1]] <- list(idx = leavesUnder(node), path = if (nzchar(path)) path else "1")
  } else {
    prefix <- if (nzchar(path)) paste0(path, ".") else ""
    stack[[length(stack) + 1]] <- list(node = hc$merge[node, 1], path = paste0(prefix, "1"))
    stack[[length(stack) + 1]] <- list(node = hc$merge[node, 2], path = paste0(prefix, "2"))
  }
}
ParallelLogger::logInfo("  done in ", round(difftime(Sys.time(), t0, units = "secs"), 1), "s")

nGroups <- length(finalGroups)
groupSizes <- purrr::map_int(finalGroups, ~ length(.x$idx))
groupDepths <- purrr::map_int(finalGroups, ~ lengths(strsplit(.x$path, ".", fixed = TRUE)))
ParallelLogger::logInfo(
  "Formed ", nGroups, " groups (each at most ", targetGroupSize, " names); ",
  "sizes: mean=", round(mean(groupSizes), 1),
  ", median=", stats::median(groupSizes),
  ", min=", min(groupSizes),
  ", max=", max(groupSizes), "; ",
  "depths: mean=", round(mean(groupDepths), 1),
  ", min=", min(groupDepths),
  ", max=", max(groupDepths)
)

nameGroups <- purrr::map_dfr(finalGroups, function(g) {
  tibble::tibble(TEST_NAME = names[g$idx], group_path = g$path)
})

# group_id is a plain sequential number, one per distinct group_path, in
# group_path's own (tree-traversal) sort order -- the two always agree on
# row order, but group_id is far easier to reference/sort/join on than a
# dotted path string.
groupIdLookup <- nameGroups |>
  dplyr::distinct(group_path) |>
  dplyr::arrange(group_path) |>
  dplyr::mutate(group_id = dplyr::row_number())
nameGroups <- nameGroups |>
  dplyr::left_join(groupIdLookup, by = "group_path")

# Sanity check: mean within-group pairwise distance of the stringdist-based
# groups vs. groups formed by naive alphabetical-order chunking of the same
# names, sampling a handful of groups on each side (reuses distMat above).
set.seed(1) # nolint: seed only used to pick which groups to sample for the sanity check, not for the grouping itself
allGroupPaths <- unique(nameGroups$group_path)
sampleGroupIds <- sample(allGroupPaths, min(20, length(allGroupPaths)))

meanWithin <- function(grpNames) {
  i <- match(grpNames, names)
  if (length(i) < 2) {
    return(NA_real_)
  }
  sub <- distMat[i, i]
  mean(sub[upper.tri(sub)])
}

stringdistGroupsList <- split(nameGroups$TEST_NAME, nameGroups$group_path)[sampleGroupIds]
alphabeticalGroupId <- ceiling(seq_along(names) / targetGroupSize)
alphabeticalGroupsAll <- split(names, alphabeticalGroupId)
sampleAlphabeticalIds <- sample(seq_along(alphabeticalGroupsAll), min(20, length(alphabeticalGroupsAll)))
alphabeticalGroupsList <- alphabeticalGroupsAll[sampleAlphabeticalIds]

stringdistMeans <- purrr::map_dbl(stringdistGroupsList, meanWithin)
alphabeticalMeans <- purrr::map_dbl(alphabeticalGroupsList, meanWithin)
ParallelLogger::logInfo(
  "Sanity check (mean within-group pairwise ", distMethod, " distance, ",
  length(sampleGroupIds), " sampled groups): stringdist-order groups mean = ",
  round(mean(stringdistMeans, na.rm = TRUE), 2),
  " vs. alphabetical-order groups mean = ",
  round(mean(alphabeticalMeans, na.rm = TRUE), 2),
  " (lower = more similar within group)"
)

result <- knownInformation |>
  dplyr::inner_join(nameGroups, by = "TEST_NAME") |>
  dplyr::relocate(group_id) |>
  dplyr::relocate(group_path, .after = dplyr::last_col()) |>
  dplyr::arrange(group_id, TEST_NAME, UNIT)

#
# --- Output -------------------------------------------------------------
#
outFile <- file.path(outDir, "knownInformationGrouped.tsv")
readr::write_tsv(result, outFile, na = "")
ParallelLogger::logInfo("Wrote ", nrow(result), " rows (", nNames, " TEST_NAME, ", nGroups, " groups) to ", outFile)
