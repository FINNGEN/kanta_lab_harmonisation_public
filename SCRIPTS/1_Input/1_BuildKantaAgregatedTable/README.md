# 1_BuildKantaAgregatedTable

Combines the Kanta summary tables (`0_KantaAgregatedData`) into one table,
`KantaAgregatedTable`: one row per `TEST_NAME` + `MEASUREMENT_UNIT` pair and decile, with the
share of records by unit source and value source.

## Inputs

From `DATA/1_Input/0_KantaAgregatedData/` (produced outside this repo by
`summarizePreprocessKantaData`, each keyed by `TEST_NAME` + `MEASUREMENT_UNIT`):

- `summaryTest.tsv` — `n_records` per pair.
- `summaryUnitSource.tsv` — `n_records` per pair and `unit_source` (`Source` /
  `PrimaryInjection` / `SecondaryCorrection`).
- `summaryValuesSource.tsv` — `n_records` per pair and `value_source`
  (`Source` / `Extracted` / `QCOut`).
- `summaryValues.tsv` — `decile_MEASUREMENT_VALUE` per pair and `decile`
  (0.1 to 0.9).

- `summaryReference.tsv` — `REFERENCE_RANGE_LOW_MEAN` and
  `REFERENCE_RANGE_HIGH_MEAN` per pair and `DEMOGRAPHICS_BIN`.

`summaryOutcomes.tsv` — `n_TEST_OUTCOME` per pair and `TEST_OUTCOME`; only validated, not used in the table.

`DATA/settings.yaml` (section `1_Input`) — `n_records_no_value_threshold` and `n_subjects_no_value_threshold`, the numbers of values and of subjects from which a pair must have its deciles.

## Outputs

In `DATA/1_Input/1_BuildKantaAgregatedTable/`:

- `kantaAgregatedTable.tsv` — one row per `TEST_NAME` + `MEASUREMENT_UNIT` pair and decile:
  - `TEST_NAME`, `MEASUREMENT_UNIT` (empty when no unit is recorded).
  - `n` — total records of the pair, repeated on every decile row.
  - `n_subjects` — subjects of the pair (`summaryTest.tsv`), repeated on every decile row.
  - `unit_source_injection_correction_na_p` — `[source%,injection%,correction%,na%]`.
  - `reference_range` — the reference range of each demographic bin,
    `<bin>[low,high]`, joined with `;` and sorted by bin (e.g.
    `AF[0,1.09];AM[0,1.09]`). Bins are abbreviated: `Adult-Female` AF,
    `Adult-Male` AM, `Minor-Female` MF, `Minor-Male` MM. An unknown bound is left
    empty (`[,21]`); empty when the pair has no reference range.
  - `value_missing_p` — percent of the pair's records with no value.
  - `value_source_extracted_qcout_na_p` — `[source%,extracted%,qcout%,na%]`.
  - `decile` — 0.1 to 0.9; empty for pairs with no deciles.
  - `decile_value` — the value at that decile; empty for pairs with no deciles.
- `kantaAgregatedTable.validation.md` — the validation of the input tables: a summary per table
  (`SUCCESS`, `WARNING`, `ERROR`, and an `ALL` row) and one row per test with its result, the number of
  failing rows and examples.
- `kantaAgregatedTable.summary.md` — a markdown report on `kantaAgregatedTable.tsv`, one
  row per `TEST_NAME` + `MEASUREMENT_UNIT` pair, with `n rows`, `% rows`,
  `n records` and `% rec` in every table and a total row. Four sections:
  - `# Name Unit Value combinations` — one row per combination of the three
    facts about a pair (has a name, has a recorded unit, has a value). Name is
    always `X`, because the step drops the pairs whose `TEST_NAME` is the text
    `NA`. A pair has a value when `value_missing_p` is under 100.
  - `# Units` — one row per unit source (`Source`, `PrimaryInjection`,
    `SecondaryCorrection`, and an empty source for the rest).
  - `# Reference Ranges` — one row per combination of bins (`AF`, `AM`, `MF`,
    `MM`) present in `reference_range`; the row with no bin has no range.
  - `# Values` — one row per value source (`Source`, `Extracted`, `QCOut`, and an empty source for the rest).

  In the source tables a pair counts as a row of a source when some of its
  records come from it, so `% rows` does not add up to 100%; `n records` is
  `n` times the share, summed over pairs, and is approximate (shares are
  rounded to 2 decimals).
- `kantaAgregatedTable.log.txt` — run log.

## Action

`scripts/validateKantaAgregatedData.R` runs first and validates the six input tables. A failing test is an
ERROR, or a WARNING when it does not break the table; the step stops (and does not build the table) when
any test is an ERROR.

| Table | Tests |
|---|---|
| all six | The columns are the expected ones, in order; `TEST_NAME` has a value; the key (`TEST_NAME` + `MEASUREMENT_UNIT`, plus `unit_source`, `value_source`, `decile`, `DEMOGRAPHICS_BIN` or `TEST_OUTCOME`) is unique; the counts (`n_records`, `n_subjects`, `n_TEST_OUTCOME`) are whole numbers above 0; `n_subjects` is above 5 (small counts are removed upstream); `n_records` (or `n_TEST_OUTCOME`) is at least `n_subjects`; every pair is in `summaryTest.tsv` |
| `summaryUnitSource.tsv` | `unit_source` is `Source` or `PrimaryInjection`; the `n_records` of a pair add up to no more than its `n_records` in `summaryTest.tsv` (rows with few subjects are removed, so they can add up to less) |
| `summaryValuesSource.tsv` | `value_source` is `Source`, `Extracted` or `QCOut`; the same sum test |
| `summaryValues.tsv` | `decile_MEASUREMENT_VALUE` is a number; `decile` is 0.1 to 0.9; every pair has the 9 deciles; the deciles of a pair do not decrease; every pair with at least `n_records_no_value_threshold` values (the records of `summaryValuesSource.tsv`) and `n_subjects_no_value_threshold` subjects (`summaryTest.tsv`) has its deciles |
| `summaryReference.tsv` | `REFERENCE_RANGE_LOW_MEAN` and `REFERENCE_RANGE_HIGH_MEAN` are numbers; `DEMOGRAPHICS_BIN` is `Adult-Female`, `Adult-Male`, `Minor-Female` or `Minor-Male`; WARNING if the low limit is above the high one |

`scripts/buildKantaAgregatedTable.R`:

1. Drops pairs whose `TEST_NAME` is the literal text `NA` (the upstream's
   stringified missing value; lowercase `na` is a real code and is kept) and
   logs how many.
2. Takes `n` from `summaryTest.tsv`, the denominator of every percentage.
3. Widens `summaryUnitSource.tsv` and `summaryValuesSource.tsv` to one column
   per label. The `na` share is `n` minus every labeled count, so a pair absent
   from a table reads 100% `na`.
4. Percentages are `100 * records / n`, rounded to 2 decimals without trailing
   zeros.
5. Collapses `summaryReference.tsv` to one `reference_range` string per pair
   (bounds rounded like the percentages).
6. Left-joins the long `summaryValues.tsv` deciles. Pairs with no deciles keep
   one row with empty `decile` and `decile_value`.

`scripts/summariseKantaAgregatedTable.R` reads `kantaAgregatedTable.tsv` back, takes
one row per pair (the file has one row per decile, with the pair's `n`
repeated), and writes `kantaAgregatedTable.summary.md`.

## Env vars

None required.

## How to run

```
./SCRIPTS/1_Input/1_BuildKantaAgregatedTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
