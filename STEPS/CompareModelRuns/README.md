# CompareModelRuns

Compares two or more runs of this pipeline's LLM steps — the same input, the
same prompts, a different **model** — against each other and against the
curated reference mapping.

## Inputs

One or more **run folders**, each named on the command line as
`--run <LABEL>=<PATH>`. A run folder is an ordinary data folder that
`FindLOINCDimensions`, `FixLOINCDimensions` and `MapLOINCToOmop` have already
been run into:

- `<run>/MapLOINCToOmop/codesWithOMOP.tsv` — the run's final mapping. This is
  the only table the comparison reads: it already carries the guessed name, the
  evidence level, the chosen concept and the record count.
- `<run>/FindLOINCDimensions/log.txt`, `<run>/FixLOINCDimensions/log.txt` —
  read only for the `LLM cost USD` line each step logs, so the report can put
  money next to agreement.
- `<first run>/ReferenceMappings/lab_data_summary.csv` — the separately curated
  Finnish-code → OMOP mapping. Taken from the **first** run folder: every run
  reads the same upstream data (in this repo the other folders symlink to
  `DATA/`), and the comparison is meaningless if they do not.

The first `--run` is the **baseline** — it is listed first in every table and
is the run the others are read as alternatives to.

## Outputs

- `DATA/CompareModelRuns/modelComparisonStats.md` — the report:
  - **Coverage and cost** — rows named, rows mapped, distinct concepts used,
    and what the two LLM steps cost for that run.
  - **Agreement with the reference** — agreement over the whole overlap, over
    the rows the run actually answered, over the rows carrying real evidence,
    and over the high-volume codes the reference was really curated for.
  - **Outcomes** — the same four buckets `MapLOINCToOmop` reports (not in
    reference / not automapped / disagreement / agreement), one column per run.
  - **Agreement by evidence level** — where a run is entitled to differ.
  - **Run against run** — how often two runs chose the same concept on the rows
    they share, which needs no reference and so also covers the majority of
    rows the reference has no `APPROVED` answer for.
  - **Where the runs split on the reference** — the individual rows where one
    run matched the reference and another did not, listed rather than counted.
- `DATA/CompareModelRuns/perRowComparison.tsv` — the table behind the report:
  one row per local `TEST_NAME`+`UNIT`, with the reference concept and, per
  run, the chosen concept id, its name, the guessed LOINC name and the stated
  certainty. This is what to re-cut the comparison from without re-deriving it.
- `DATA/CompareModelRuns/log.txt` — run log.

## Action

`scripts/compareModelRuns.R` reads each run's final table, stacks them, and
answers two questions that are deliberately kept apart:

1. **Against the reference.** Each run on its own is scored the way
   `MapLOINCToOmop` already scores one: joined to the reference's `APPROVED`
   rows on `TEST_NAME` + `UNIT` (an empty `UNIT` counting as a unit value in
   its own right), and classified into the same four outcomes. Repeating that
   step's logic rather than reading its report means every run is measured
   identically and a figure here can be checked against that run's own report.

   This is **agreement, not correctness**. The reference is the best mapping
   available, not ground truth; it carries errors and internal inconsistencies
   of its own, and the pipeline maps `(TEST_NAME, UNIT)` where the reference is
   in practice a `TEST_NAME` → concept mapping. Coverage is also easy to
   inflate by never declining, so agreement is always reported next to how many
   rows the run answered at all.

2. **Against each other.** On the rows all runs cover, how often do two runs
   choose the same concept? This needs no reference, so unlike (1) it covers
   the ~60% of rows the reference has no `APPROVED` answer for. Two models
   independently landing on the same concept is weak evidence it is right; the
   rows where they split are the ones worth putting in front of a human, and
   the report lists them.

No LLM is called: the runs have already been made, and this step only reads
them. It is therefore cheap to re-run, and re-running it after adding a fourth
model costs nothing.

## Env vars

- `VOLUME_THRESHOLD` — records above which a code counts as high-volume,
  default `500`. Same meaning and default as in `MapLOINCToOmop`: the reference
  was curated mostly for the codes that carry the data volume, so a single
  agreement figure over the whole overlap mixes the codes it was written for
  with ones it barely touches.

## How to run

```
./STEPS/CompareModelRuns/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME> \
    --run <LABEL>=<PATH> --run <LABEL>=<PATH> [--run ...]
```

At least two `--run` arguments are required — there is nothing to compare
otherwise. The report is written into `<PATH_TO_DATA_FOLDER>/CompareModelRuns/`,
which need not be one of the runs being compared.

```
./STEPS/CompareModelRuns/run.sh DATA --env build \
    --run "gemini-2.5-pro=DATA" \
    --run "claude-sonnet-5=DATA_sonnet" \
    --run "claude-opus-5=DATA_opus"
```
