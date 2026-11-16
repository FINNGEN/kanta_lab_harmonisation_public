# 1_BuildKantaAgregatedTable

Combines the Kanta summary tables (`0_KantaAgregatedData`) into one table,
`KantaAgregatedTable`: one row per `TEST_NAME` + `PREPROCESED_UNIT` pair and decile, with the
share of records by unit source and value source.

## Inputs

From `DATA/1_Input/0_KantaAgregatedData/` (produced outside this repo by
`summarizePreprocessKantaData`, each keyed by `TEST_NAME` + `PREPROCESED_UNIT`):

- `summaryTest.tsv` — `n_records` per pair.
- `summaryUnitSource.tsv` — `n_records` per pair and `unit_source` (`Source` /
  `PrimaryInjection` / `SecondaryCorrection`).
- `summaryValuesSource.tsv` — `n_records` per pair and `value_source`
  (`Source` / `Extracted` / `QCOut`).
- `summaryValues.tsv` — `decile_MEASUREMENT_VALUE` per pair and `decile`
  (0.1 to 0.9).

`summaryOutcomes.tsv` is not used.

## Outputs

In `DATA/1_Input/1_BuildKantaAgregatedTable/`:

- `kantaAgregatedTable.tsv` — one row per `TEST_NAME` + `PREPROCESED_UNIT` pair and decile:
  - `TEST_NAME`, `PREPROCESED_UNIT` (empty when no unit is recorded).
  - `n` — total records of the pair, repeated on every decile row.
  - `unit_source_injection_correction_na_p` — `[source%,injection%,correction%,na%]`.
  - `value_missing_p` — percent of the pair's records with no value.
  - `value_source_extracted_qcout_na_p` — `[source%,extracted%,qcout%,na%]`.
  - `decile` — 0.1 to 0.9; empty for pairs with no deciles.
  - `decile_value` — the value at that decile; empty for pairs with no deciles.
- `kantaAgregatedTable.md` — a markdown report on `kantaAgregatedTable.tsv`: the
  name / unit / value coverage table. One row per combination of the three
  facts about a `TEST_NAME` + `PREPROCESED_UNIT` pair (has a name, has a recorded unit, has
  a value), with `n rows`, `% rows`, `n records` and `% rec`, and a total row.
  Name is always `X`, because the step drops the pairs whose `TEST_NAME` is the
  text `NA`. A pair has a value when `value_missing_p` is under 100.
- `log.txt` — run log.

## Action

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
5. Left-joins the long `summaryValues.tsv` deciles. Pairs with no deciles keep
   one row with empty `decile` and `decile_value`.

`scripts/summariseKantaAgregatedTable.R` reads `kantaAgregatedTable.tsv` back, takes
one row per pair (the file has one row per decile, with the pair's `n`
repeated), and writes `kantaAgregatedTable.md`.

## Env vars

None required.

## How to run

```
./SCRIPTS/1_Input/1_BuildKantaAgregatedTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
