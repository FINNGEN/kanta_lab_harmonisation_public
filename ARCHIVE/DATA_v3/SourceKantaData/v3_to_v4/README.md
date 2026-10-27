# v3_to_v4

A one-off conversion, not a pipeline step: `../source/*.tsv` are the old
(v3) `SourceKantaData` extract, in a different schema than the current
(v4) one `1_GetSummaryData` reads. `convertV3ToV4.R` converts them into v4's
schema and writes them as `../summaryTest.tsv`, `../summaryValuesSource.tsv`,
`../summaryValues.tsv`, `../summaryOutcomes.tsv` — i.e. directly into
`SourceKantaData/`, alongside `source/`, so `1_GetSummaryData` can run
against `DATA_v3` the same way it runs against `DATA_v4`.

## Run

```
Rscript DATA_v3/SourceKantaData/v3_to_v4/convertV3ToV4.R
```

Reads from `../source/`, writes into `..` — both resolved relative to this
script's own location, no arguments.

## v3 -> v4 per table

v3 keys every row by `OMOP_CONCEPT_ID` (and, for `summaryTest`/`summaryValues`/
`summaryOutcomes`, an `IS_EXTRACTED` TRUE/FALSE split) that v4 does not carry.
So converting means grouping by v4's key and collapsing whatever v3 rows land
in the same group — which is a plain sum for the three count tables, and one
extra decision for the one non-count table:

- **summaryTest**: group by `TEST_NAME` + `MEASUREMENT_UNIT_PREFIX` (renamed
  `MEASUREMENT_UNIT`); `n_records`/`n_subjects` summed. `MEASUREMENT_UNIT`
  (the non-prefix column), `OMOP_CONCEPT_ID`, `IS_EXTRACTED`,
  `MEASUREMENT_UNIT_HARMONIZED`, `omopQuantity`, `CONVERSION_FACTOR` are
  dropped.
- **summaryValuesSource**: same grouping, with `MEASUREMENT_VALUE_TYPE`
  (renamed `value_source`) added to the key; `n_records`/`n_subjects` summed.
- **summaryOutcomes**: same grouping, with `TEST_OUTCOME` added to the key;
  `n_TEST_OUTCOME`/`n_subjects` summed.
- **summaryValues**: `decile_MEASUREMENT_VALUE` is a quantile, not a count —
  it cannot be summed across colliding v3 rows the way the above can. Where a
  `TEST_NAME`/`UNIT` pair has more than one v3 subgroup (different
  `OMOP_CONCEPT_ID` and/or `IS_EXTRACTED`), the subgroup with the larger
  `n_records` is kept whole (all 9 of its deciles, plus its own
  `n_subjects`/`n_records`) and the other subgroup's deciles are discarded —
  chosen once per pair (a subgroup's `n_records` is constant across its own 9
  decile rows), not independently per decile, so deciles from different
  subgroups never get mixed into one pair's distribution.
  `decile_MEASUREMENT_VALUE_HARMONIZED` is dropped.

`summaryUnitSource` has no v3 equivalent at all and is not produced here —
`1_GetSummaryData` treats a missing `summaryUnitSource.tsv` as "no unit-source
data available" (see its own README).
