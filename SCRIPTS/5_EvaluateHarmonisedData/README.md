# 5_EvaluateHarmonisedData

Harmonises the Kanta aggregated table, then tests whether the harmonised values of each
`TEST_NAME` + `PREPROCESED_UNIT` pair agree with the other pairs of the same LOINC Group, comparing
their deciles. Two scripts, run one after the other: first the harmonisation, then the evaluation.

## Inputs

From `DATA/`:

- `1_Input/1_BuildKantaAgregatedTable/kantaAgregatedTable.tsv` — one row per `TEST_NAME` +
  `MEASUREMENT_UNIT` pair and decile (see `1_Input/1_BuildKantaAgregatedTable`). Its `MEASUREMENT_UNIT` is
  read as the `PREPROCESED_UNIT` of the harmonisation table.
- `4_BuildHarmonisationTable/harmonisationTable.tsv` — see `4_BuildHarmonisationTable`.
- `1_Input/0_KantaAgregatedData/upstreamSettings.yaml` — `n_records_no_value_threshold` (1000) or `n_subjects_no_value_threshold` (60), under which a pair has no values.

## Outputs

In `DATA/5_EvaluateHarmonisedData/`:

- `harmonisedKantaAgregatedTable.tsv` — `kantaAgregatedTable.tsv` (same rows, same columns, with
  `MEASUREMENT_UNIT` called `PREPROCESED_UNIT`) followed by the columns of the harmonisation table.
  `mapping_status` is the first column. The others: `UNIT` (the unit after the fix, right after
  `PREPROCESED_UNIT`), `unit_fix_reasoning`, `ignore_mapping_reason`, `concept_id`, the concept columns
  (`concept_code`, `concept_name`, `vocabulary_id`, `is_panel`, `has_component`, `has_property`), the LOINC
  Groups, `HARMONISED_UNIT`, `CONVERSION` and `mapping_warning_messages`. The new column
  `decile_value_harmonised` sits right after `decile_value`. A pair that is not in the harmonisation table
  keeps its rows with `mapping_status` `MISSING` and the other harmonisation columns empty.
- The rows are sorted by `n` from largest to smallest (then `TEST_NAME`, `PREPROCESED_UNIT` and
  `decile`, so the rows of a pair stay together).

- `evaluatedHarmonisedKantaAgregatedTable.tsv` — one row per `TEST_NAME` +
  `PREPROCESED_UNIT` + `UNIT`, with the columns of `harmonisedKantaAgregatedTable.tsv`
  except `decile`, with `mapping_status` as the first column (`MISSING` for a pair that is not in the
  harmonisation table), and:
  - `decile_value`, `decile_value_harmonised` — the 9 deciles as text, e.g.
    `[ 1.08, 1.11, 1.13, 1.14, 1.16, 1.17, 1.19, 1.2, 1.23 ]` (3 significant digits;
    empty if the pair has no complete deciles).
  - `reference_decile_value_harmonised` — the deciles of the reference (see Action), in the
    same text format, right after `decile_value_harmonised`; empty if the pair is not tested.
  - `harmonisation_values_status` — second column, right after `mapping_status`: the row of the Harmonised
    Values table of the dashboard the pair falls in, the first that applies: `AGREE` (KS under 0.5),
    `WARNING` (0.5 to 0.8), `DISAGREE` (over 0.8), `Error: values with missing units` (no `UNIT`), `Not compared: only one pair per group`, `No value: value ignored, is qualitative or
    panel` (`target_unit_source` is `isQualitative` or `panel`), `No value: fewer than 1000
    values or 60 subjects` (checked first, whatever the status) and `Not mapped (NOT-APPROVED, IGNORE, MISSING or ERROR)`
    (any pair that is not `APPROVED`). An approved pair with a `UNIT` always has a `CONVERSION` (otherwise step 4 makes it `ERROR:MissingConversion`); and a pair with enough values and subjects always has its deciles (`1_BuildKantaAgregatedTable` stops otherwise); the step stops if either does not. The errors and the not-compared rows apply to approved pairs only.
  - `KS` — the Kolmogorov-Smirnov statistic between the pair and its reference.
  - `KS_mlp` — `-log10` of the KS p-value (capped at 300).
  - `log10_D5` — `log10(decile 5 of the pair / decile 5 of the reference)`; positive
    when the pair is higher. Empty if either median is not above 0.
  - `in_reference` — `TRUE` if the pair is approved and has harmonised deciles, so it is part
    of the reference of the other pairs of its Groups (or concept) with the same
    `HARMONISED_UNIT`.
  - `reference_type` (`LOINC Group` or `concept_id`), `reference_group_concept_id` (empty
    for `concept_id`) and `n_reference_pairs` — where the reference came from and how many
    pairs it has.
- The rows are sorted by `n` from largest to smallest.
- `log.txt` — run log.

## Action

### 1. Harmonise: `scripts/harmoniseKantaAgregatedTable.R`

`scripts/harmoniseKantaAgregatedTable.R`:

1. Renames `MEASUREMENT_UNIT` to `PREPROCESED_UNIT` and left-joins the harmonisation table on
   `TEST_NAME` + `PREPROCESED_UNIT`, the key of both tables (unique in the harmonisation table, so every
   pair joins once). Logs how many pairs are not in the table.
2. Sets `decile_value_harmonised` to `decile_value` with the `CONVERSION` applied: a factor is multiplied, a
   formula in `X` (e.g. `0.703*X+0`) is evaluated with `X` the value. Only numbers, `X` and `+ - * / ( )`
   are evaluated. Without a `CONVERSION`, or without a `decile_value`, it is empty. The log counts the
   decile values harmonised and those left without a `CONVERSION`.

A pair is joined on the unit as it arrives, `PREPROCESED_UNIT`, not on the fixed `UNIT`; a Kanta pair whose
unit was already fixed upstream is not in the table by that key.

### 2. Evaluate: `scripts/evaluateHarmonisedKantaAgregatedTable.R`

The evaluation reads `harmonisedKantaAgregatedTable.tsv`, written by the first script, and writes
`evaluatedHarmonisedKantaAgregatedTable.tsv`.

`scripts/evaluateHarmonisedKantaAgregatedTable.R`:

1. Collapses the table to one row per pair, with the deciles of `decile_value` and
   `decile_value_harmonised` as columns.
2. Builds the reference of each pair that has the 9 harmonised deciles and at least
   `n_records_no_value_threshold` values (`n` times the share of records with a value) and
   `n_subjects_no_value_threshold` subjects (`upstreamSettings.yaml`). A pair with fewer values or subjects
   counts as having no values: it is neither tested nor part of a reference. The reference is the LOINC
   Group of the concept: all the pairs in it. A concept can be in several Groups, tried
   in the order of `group_concept_id` (the most specific first): the first Group with at
   least 2 **other** pairs whose `mapping_status` is `APPROVED` (not `ERROR:<reason>`, `IGNORE` or
   `NOT-APPROVED`) is the reference. If the concept is in no LOINC Group, the reference
   is the concept: all the pairs with the same `concept_id`, with the same condition.
   Only the pairs with the same `HARMONISED_UNIT` as the tested pair are in the reference.
   The pair itself is never in its reference, so a large pair cannot
   agree with itself. Only the approved pairs are tested, each against the other approved
   pairs; a pair that is not `APPROVED` (`NOT-APPROVED`, `ERROR:<reason>`, `IGNORE`, `MISSING`) is not
   tested. For each decile the reference is the
   median of the harmonised deciles of those pairs, weighted by `sqrt(n values)`.
3. `KS`: each set of deciles is a step CDF (at a value, the highest decile level at or
   below it; 0 below the lowest decile). `KS` is the largest gap between the CDFs over
   the decile values of both, as in the earlier `labDataSummary.R`. As the levels stop
   at 0.9, `KS` is at most 0.9. The p-value is the asymptotic KS one, with the pair's
   n values and the sum of the reference pairs'. `log10_D5` is the shift of the median.
4. A pair with no `HARMONISED_UNIT` (a qualitative concept, a panel, or a concept with no target
   unit) is neither tested nor part of a reference.
5. A pair with no harmonised deciles (no `CONVERSION`), or whose Groups (or concept, when
   there is no Group) have fewer than 2 other approved pairs, is not tested: `KS`, `KS_mlp` and `log10_D5` are empty.
   The log counts the pairs tested, by type of reference, and not tested.

A pair is only tested if its `TEST_NAME` + `PREPROCESED_UNIT` is in the harmonisation
table (the first script of this step).

## Env vars

None required.

## How to run

```
./SCRIPTS/5_EvaluateHarmonisedData/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
