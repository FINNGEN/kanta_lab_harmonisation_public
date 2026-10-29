# 3_EvaluateHarmonisedData

Tests whether the harmonised values of each `TEST_NAME` + `PREPROCESED_UNIT` pair agree
with the other pairs of the same LOINC Group, comparing their deciles.

## Inputs

- `DATA_SUMMARY/2_HarmonizeKantaSummaryData/harmonizedKantaSummaryData.tsv` — one row per
  pair and decile, with the concept, its LOINC Groups and `decile_value_harmonised`.

## Outputs

In `DATA_SUMMARY/3_EvaluateHarmonisedData/`:

- `evaluatedHarmonisedKantaSummaryData.tsv` — one row per `TEST_NAME` +
  `PREPROCESED_UNIT` + `UNIT`, with the columns of `harmonizedKantaSummaryData.tsv`
  except `decile`, and:
  - `decile_value`, `decile_value_harmonised` — the 9 deciles as text, e.g.
    `[ 1.08, 1.11, 1.13, 1.14, 1.16, 1.17, 1.19, 1.2, 1.23 ]` (3 significant digits;
    empty if the pair has no complete deciles).
  - `KS` — the Kolmogorov-Smirnov statistic between the pair and its reference.
  - `KS_mlp` — `-log10` of the KS p-value (capped at 300).
  - `log10_D5` — `log10(decile 5 of the pair / decile 5 of the reference)`; positive
    when the pair is higher. Empty if either median is not above 0.
  - `reference_group_concept_id`, `n_reference_pairs` — the LOINC Group the reference
    came from and how many pairs it has.
- `log.txt` — run log.

## Action

`scripts/evaluateHarmonisedKantaSummaryData.R`:

1. Collapses the table to one row per pair, with the deciles of `decile_value` and
   `decile_value_harmonised` as columns.
2. Builds the reference of each pair that has the 9 harmonised deciles and at least 2
   values (`n` times the share of records with a value). The pair's LOINC Groups are
   tried in the order of `group_concept_id` (the most specific first). The first Group
   with at least 2 **other** pairs whose mapping is `APPROVED` and not ignored is the
   reference group. The pair itself is never in its reference, so a large pair cannot
   agree with itself. Approved pairs are tested against the others; pairs that are not
   approved are tested against the approved ones. For each decile the reference is the
   median of the harmonised deciles of those pairs, weighted by `sqrt(n values)`.
3. `KS`: each set of deciles is a step CDF (at a value, the highest decile level at or
   below it; 0 below the lowest decile). `KS` is the largest gap between the CDFs over
   the decile values of both, as in the archived `labDataSummary.R`. As the levels stop
   at 0.9, `KS` is at most 0.9. The p-value is the asymptotic KS one, with the pair's
   n values and the sum of the reference pairs'. `log10_D5` is the shift of the median.
4. A pair with no harmonised deciles (no `CONVERSION`), no LOINC Group, or no Group
   with enough approved pairs is not tested: `KS`, `KS_mlp` and `log10_D5` are empty.
   The log counts the pairs tested and not tested.

A pair is only tested if its `TEST_NAME` + `PREPROCESED_UNIT` is in the harmonization
table (see `2_HarmonizeKantaSummaryData`).

## Env vars

None required.

## How to run

```
./STEPS/SUMMARY/3_EvaluateHarmonisedData/run.sh <PATH_TO_DATA_SUMMARY> --env <ENV_NAME>
```
