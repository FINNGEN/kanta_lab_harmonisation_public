# 2_HarmonizeKantaSummaryData

Harmonizes the Kanta summary data: joins `harmonizationTable.tsv` to
`KantaSummaryData` on `TEST_NAME` + `UNIT` and converts each decile value to the
harmonised unit with the table's `CONVERSION`.

## Inputs

- `DATA_SUMMARY/1_BuildKantaSummaryData/kantaSummaryData.tsv` — one row per
  `TEST_NAME` + `UNIT` pair and decile (see `1_BuildKantaSummaryData`).
- `DATA_MAPPINGS/1_BuildHarmonizationTable/harmonizationTable.tsv` — read-only,
  built by the MAPPING step `1_BuildHarmonizationTable`. Its path is given with
  `--mappings`.

## Outputs

In `DATA_SUMMARY/2_HarmonizeKantaSummaryData/`:

- `harmonizedKantaSummaryData.tsv` — `kantaSummaryData.tsv` (same rows, same
  columns) followed by the columns of the harmonization table, except
  `PREPROCESED_UNIT` and `unit_fix_reasoning`: `ignore_mapping_reason`, `APPROVED`,
  `concept_id`, the concept attributes, the LOINC Groups, `HARMONISED_UNIT`,
  and `CONVERSION`. The new column `decile_value_harmonised` sits right
  after `decile_value`. A pair that is not in the harmonization table keeps its
  rows with the harmonization columns empty.
- `log.txt` — run log.

## Action

`scripts/harmonizeKantaSummaryData.R`:

1. Left-joins the harmonization table to `kantaSummaryData.tsv` on `TEST_NAME` +
   `UNIT`. The `UNIT` of the summary data is the unit after the fix, the `UNIT` of
   the harmonization table, not its `PREPROCESED_UNIT`. A `UNIT` fixed from several
   `PREPROCESED_UNIT`s has several rows in the table that differ only in the two
   dropped columns, so every pair joins once. Logs how many pairs are not in the
   table.
2. Sets `decile_value_harmonised` to `decile_value` with the `CONVERSION` applied: a
   factor is multiplied, a formula in `X` (e.g. `0.703*X+0`) is evaluated with `X`
   the value. Only numbers, `X` and `+ - * / ( )` are evaluated. Without a
   `CONVERSION`, or without a `decile_value`, it is empty. The log counts the
   decile values harmonised and those left without a `CONVERSION`.

## Env vars

None required.

## How to run

```
./STEPS/SUMMARY/2_HarmonizeKantaSummaryData/run.sh <PATH_TO_DATA_SUMMARY> --env <ENV_NAME> --mappings <PATH_TO_DATA_MAPPINGS>
```
