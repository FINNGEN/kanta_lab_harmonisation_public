#
# --- Libraries -------------------------------------------------------------
#
library(dplyr)

#
# --- Configuration -------------------------------------------------------------
#
args <- commandArgs(trailingOnly = TRUE)
knownInformationGroupedFile <- args[1]
outDir <- args[2]

ParallelLogger::clearLoggers()
ParallelLogger::logInfo("Configuration:")
ParallelLogger::logInfo("  knownInformationGroupedFile = ", knownInformationGroupedFile)
ParallelLogger::logInfo("  outDir = ", outDir)

#
# --- Input -------------------------------------------------------------
#
# na = "" (not readr's default c("", "NA")): some TEST_NAME values are
# literally the text "NA" -- a real abbreviation, not a missing value -- and
# knownInformationGroupedFile itself only ever writes "" for a genuine missing value.
knownInformationGrouped <- readr::read_tsv(knownInformationGroupedFile, show_col_types = FALSE, na = "")
ParallelLogger::logInfo("Read ", nrow(knownInformationGrouped), " rows from ", knownInformationGroupedFile)

#
# --- Action -------------------------------------------------------------
#
perGroup <- knownInformationGrouped |>
  dplyr::summarise(
    nTestNames = dplyr::n_distinct(TEST_NAME),
    nTestNameUnit = dplyr::n(),
    .by = c(group_id, group_path)
  )

nGroups <- nrow(perGroup)

groupSizeStats <- tibble::tibble(
  metric = c("distinct TEST_NAME per group", "TEST_NAME+UNIT rows per group"),
  mean = c(mean(perGroup$nTestNames), mean(perGroup$nTestNameUnit)),
  min = c(min(perGroup$nTestNames), min(perGroup$nTestNameUnit)),
  max = c(max(perGroup$nTestNames), max(perGroup$nTestNameUnit))
) |>
  dplyr::mutate(mean = round(mean, 1))

ParallelLogger::logInfo("Computed group-size stats for ", nGroups, " groups")

# Reconstruct the dendrogram of groups from the group_path values alone
# (e.g. "1.2.1" implies ancestor branches "1" and "1.2") -- every branch
# that was split during grouping produced exactly two children, so the set
# of every leaf path's prefixes recreates that branching exactly, with no
# need for the original hclust object. Internal (non-group) nodes are shown
# bare; each group's own line gets its group_id and distinct-TEST_NAME size.
groupPaths <- perGroup$group_path
segsByGroup <- strsplit(groupPaths, ".", fixed = TRUE)
allNodes <- unique(unlist(lapply(segsByGroup, function(segs) {
  vapply(seq_along(segs), function(i) paste(segs[seq_len(i)], collapse = "."), character(1))
})))
rootKey <- "<ROOT>" # split()/`[[` treat "" as no-match even when it IS a valid list name, so a
                     # real top-level node's parent needs a non-empty sentinel key instead of ""
parentOf <- vapply(strsplit(allNodes, ".", fixed = TRUE), function(segs) {
  if (length(segs) == 1) rootKey else paste(segs[-length(segs)], collapse = ".")
}, character(1))
childrenByParent <- split(allNodes, parentOf)
childrenByParent <- lapply(childrenByParent, sort)
# Lists, not vectors: `[[` on a named vector errors on a missing name
# instead of returning NULL like it does on a list.
sizeByGroup <- stats::setNames(as.list(perGroup$nTestNames), perGroup$group_path)
idByGroup <- stats::setNames(as.list(perGroup$group_id), perGroup$group_path)

renderNode <- function(nodePath, prefix, isLast, isRoot) {
  label <- if (isRoot) "groups" else utils::tail(strsplit(nodePath, ".", fixed = TRUE)[[1]], 1)
  size <- sizeByGroup[[nodePath]]
  if (!is.null(size)) {
    label <- paste0(label, " (group_id=", idByGroup[[nodePath]], ", n=", size, ")")
  }
  line <- if (isRoot) label else paste0(prefix, if (isLast) "└── " else "├── ", label)
  childPrefix <- if (isRoot) "" else paste0(prefix, if (isLast) "    " else "│   ")
  kids <- childrenByParent[[nodePath]]
  childLines <- unlist(lapply(seq_along(kids), function(i) {
    renderNode(kids[i], childPrefix, isLast = (i == length(kids)), isRoot = FALSE)
  }))
  c(line, childLines)
}
dendrogramLines <- renderNode(rootKey, "", isLast = TRUE, isRoot = TRUE)
ParallelLogger::logInfo("Rendered a ", length(allNodes) + 1, "-node dendrogram (", nGroups, " group leaves)")

#
# --- Output -------------------------------------------------------------
#
md <- c(
  "# Known Information Grouped -- Stats",
  "",
  paste0("Source: `", knownInformationGroupedFile, "`"),
  "",
  "Group sizes measured two ways: how many distinct `TEST_NAME`s landed in a",
  "group, and how many `TEST_NAME`+`UNIT` rows that pulled in (a `TEST_NAME`",
  "with several units counts once in the first, several times in the",
  "second).",
  "",
  paste0("n groups: ", nGroups),
  "",
  "| metric | mean | min | max |",
  "|---|---|---|---|",
  sprintf("| %s | %s | %d | %d |", groupSizeStats$metric, groupSizeStats$mean, groupSizeStats$min, groupSizeStats$max),
  "",
  "## Dendrogram",
  "",
  "The tree of splits that produced the groups, reconstructed from every",
  "group's `group_path`. Each leaf is a final group, labelled with its",
  "`group_id` and its number of distinct `TEST_NAME`s (`n=`); unlabelled",
  "branch points are splits that were still above `--group-size` and so got",
  "divided further.",
  "",
  "```",
  dendrogramLines,
  "```"
)

outFile <- file.path(outDir, "knownInformationGroupedStats.md")
writeLines(md, outFile)
ParallelLogger::logInfo("Wrote stats report to ", outFile)
