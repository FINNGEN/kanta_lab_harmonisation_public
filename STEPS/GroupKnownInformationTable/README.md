# GroupKnownInformationTable

## Inputs

- `DATA/BuildKnownInformationTable/knownInformation.tsv` — one row per
  `TEST_NAME`/`UNIT`, with `n`, `p_missing`, `deciles`, `LongName`,
  `prefix_meaning`, `suffix_meaning`.

## Outputs

- `DATA/GroupKnownInformationTable/knownInformationGrouped.tsv` —
  `knownInformation.tsv` filtered and grouped:
  - Dropped before grouping: `TEST_NAME` that are purely numeric (stray
    codes, never a real test abbreviation), and `TEST_NAME` whose total `n`
    (summed across its `UNIT` rows) does not exceed `--min-n` (default 100).
  - The surviving distinct `TEST_NAME`s are clustered by string similarity
    (see Action below) into groups of at most `--group-size` (default 100)
    names each.
  - Same columns as `knownInformation.tsv`, with two columns added: `group_id`
    at the front (a plain sequential number, one per group, in `group_path`'s
    own sort order) and `group_path` at the end (the root-to-branch path,
    e.g. `1.2.1`, of the dendrogram branch that became that group -- see
    Action). Rows for a dropped `TEST_NAME` are absent entirely. Sorted by
    `group_id`, then `TEST_NAME`, then `UNIT`.
- `DATA/GroupKnownInformationTable/knownInformationGroupedStats.md` — n
  groups; a mean/min/max table of group size measured two ways (distinct
  `TEST_NAME` per group, and `TEST_NAME`+`UNIT` rows per group); and an
  ASCII dendrogram of the groups, reconstructed purely from the
  `group_path` values (every leaf path's prefixes recreate the original
  branching exactly, since every split produced exactly two children -- no
  need to re-read the clustering itself). Each leaf is one group, labelled
  with its `group_id` and its size (`n=` distinct `TEST_NAME`s); unlabelled
  branch points are splits that were still above `--group-size` and so got
  divided further.
- `DATA/GroupKnownInformationTable/log.txt` — run log (written by `run.sh`'s
  `tee`; both R scripts log through `ParallelLogger::logInfo()` with no
  logger registered, per `development/STYLE.md`).

## Action

Two scripts, run in order:

1. `scripts/groupKnownInformationTable.R` — adapted from
   `EXPERIMENTS/stringdist_grouping/group_codes_by_stringdist.R`: computes
   all pairwise OSA (optimal string alignment) edit distances between the
   surviving `TEST_NAME`s and hierarchically clusters them (Ward's method)
   into one dendrogram, then walks it top-down from the root: at each
   branch, if its subtree has at most `--group-size` names it stops and
   calls it a group, otherwise it descends into the branch's two children
   and repeats. Different branches get cut at different heights this way --
   a branch that's already a tight, genuinely similar family of names is
   kept whole high up in the tree, while a branch dominated by the "every
   short string looks like every other short string" chaining effect keeps
   splitting until its pieces are small too. This guarantees every group has
   at most `--group-size` names; a name unlike anything else can still end
   up alone, as a singleton branch. A group's `group_path` is the
   root-to-branch path of child choices (`1`/`2` at each split) that reaches
   it -- e.g. `1.2.1` means: at the root took the 1st child, then the 2nd,
   then the 1st -- so its number of `.`-separated segments is the group's
   depth in the tree; `group_id` is then just a sequential number over the
   sorted `group_path`s. As a sanity check, logs the mean within-group
   pairwise distance of the resulting groups against naive alphabetical-order
   chunking of the same names.
2. `scripts/summariseKnownInformationGroupedStats.R` reads
   `knownInformationGrouped.tsv` and writes
   `knownInformationGroupedStats.md`.

## Env vars

None required.

## How to run

```
./STEPS/GroupKnownInformationTable/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> [--min-n <N>] [--group-size <N>]
```

- `--min-n <N>` — drop `TEST_NAME`s whose total `n` does not exceed `N`.
  Default 100.
- `--group-size <N>` — maximum number of distinct `TEST_NAME`s per group.
  Default 100.
