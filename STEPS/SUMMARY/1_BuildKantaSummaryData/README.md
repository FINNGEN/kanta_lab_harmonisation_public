# 1_BuildKantaSummaryData

Combines the Kanta summary tables (`0_KantaSummaryTables`) into one table,
`KantaSummaryData`: one row per `TEST_NAME` + `UNIT` pair and decile, with the
share of records by unit source and value source.

## Inputs

From `DATA_SUMMARY/0_KantaSummaryTables/` (produced outside this repo by
`summarizePreprocessKantaData`, each keyed by `TEST_NAME` + `MEASUREMENT_UNIT`):

- `summaryTest.tsv` — `n_records` per pair.
- `summaryUnitSource.tsv` — `n_records` per pair and `unit_source` (`Source` /
  `PrimaryInjection` / `SecondaryCorrection`).
- `summaryValuesSource.tsv` — `n_records` per pair and `value_source`
  (`Source` / `Extracted` / `QCOut`).
- `summaryValues.tsv` — `decile_MEASUREMENT_VALUE` per pair and `decile`
  (0.1 to 0.9).

`summaryOutcomes.tsv` is not used.

## Outputs

In `DATA_SUMMARY/1_BuildKantaSummaryData/`:

- `kantaSummaryData.tsv` — one row per `TEST_NAME` + `UNIT` pair and decile:
  - `TEST_NAME`, `UNIT` (empty when no unit is recorded).
  - `n` — total records of the pair, repeated on every decile row.
  - `unit_source_injection_correction_na_p` — `[source%,injection%,correction%,na%]`.
  - `value_missing_p` — percent of the pair's records with no value.
  - `value_source_extracted_qcout_na_p` — `[source%,extracted%,qcout%,na%]`.
  - `decile` — 0.1 to 0.9; empty for pairs with no deciles.
  - `decile_value` — the value at that decile; empty for pairs with no deciles.
- `log.txt` — run log.

## Action

`scripts/buildKantaSummaryData.R`:

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

## Env vars

None required.

## How to run

```
./STEPS/SUMMARY/1_BuildKantaSummaryData/run.sh <PATH_TO_DATA_SUMMARY> --env <ENV_NAME>
```
