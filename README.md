# Kanta lab harmonisation

# Overview

## Problem

Each `TEST_NAME [PREPROCESED_UNIT]` pair of the Kanta lab data has to be mapped to an existing
`concept_id [harmonised_unit]` of the OMOP vocabulary, such that:

- the `TEST_NAME` has the same meaning as the `concept_name` (the same LOINC axes: component, property,
  system, ...);
- the `UNIT` is compatible with the `harmonised_unit`, so the values can be converted;
- the Kanta values, once converted, are in the same distribution as the other values of the
  `concept_id [harmonised_unit]` (and of its LOINC Group).

## Process

`TEST_NAME` is mapped to `concept_id` with `mapping.tsv`, and the `UNIT` is converted to the
`harmonised_unit`, when they differ, with `unitHarmonisation.tsv`:

```mermaid
flowchart LR
    S["TEST_NAME<br>[PREPROCESED_UNIT]<br>(value)"] -- unitFix.tsv --> F["TEST_NAME<br>[UNIT]<br>(value)"]
    F -- mapping.tsv --> C["concept_id"]
    C -- unitHarmonisation.tsv --> D["concept_id<br>[harmonised_unit]<br>f_convesion(value)<br>LOINCgroup"]
    D --harmonisedUnitOverwrite.tsv--- E[OMOP<br>lab2loinc<br>rules]
```

However, the `PREPROCESED_UNIT` on the left may be wrong, and so may the `harmonised_unit` on the right.
`unitFix.tsv` fixes the first and `harmonisedUnitOverwrite.tsv` the second.

## Fixing rules

When a pair does not meet the three conditions, the cause is one of these:

| Symptom | Cause | Fix in |
|---|---|---|
| `UNIT` is empty, or the values look like another unit | the `PREPROCESED_UNIT` is wrong or missing | `unitFix.tsv` |
| `UNIT` and `harmonised_unit` cannot be converted (other property or dimension) | the mapping is wrong: the test is not that concept | `mapping.tsv` |
| `UNIT` and `harmonised_unit` can be converted, but no rule does it, or the values are off by a factor | the conversion is missing or wrong | `unitHarmonisation.tsv` |
| The values agree with no pair, or the unit is not what the labs report | the `harmonised_unit` of the concept is wrong | `harmonisedUnitOverwrite.tsv` |
| Units convert, but the values still disagree (e.g. other specimen) | the mapping is to a wrong but compatible concept | `mapping.tsv` |
| The pair is `NOT-FOUND` | the pair is not in `mapping.tsv` yet | `mapping.tsv` |

Some pairs cannot be judged by their values:

- a qualitative concept (`Presence or Threshold`) or a panel has no unit and no distribution to compare;
- a pair alone in its Group and concept has no reference;
- a LOINC Group can hold concepts that are not the same quantity (e.g. `/[HPF]` with `10*6/L`); only the
  Groups lab2clean assigns are known to share one unit, so a disagreement with a `LOINC` Group is a hint,
  not proof.

# Repo

The repository is split in `SCRIPTS/` (the code, one folder per step, each with a README) and
`DATA/` (the result of each step, in a folder of the same name). Every step runs as
`./SCRIPTS/<step>/run.sh <PATH_TO_DATA> --env <ENV_NAME>`.

## 1_Input

The source values to map: one row per `TEST_NAME [PREPROCESED_UNIT]` pair of Kanta, with the number of
records, where the unit and the value came from, the reference ranges and the deciles of the values.

## 2_Harmonisation

Hand-edited tables, the only place where the mapping is decided:

- `unitFix.tsv` — the `PREPROCESED_UNIT` may be wrong or missing; this table gives the corrected `UNIT`
  of a `TEST_NAME [PREPROCESED_UNIT]` pair.
- `mapping.tsv` — maps each `TEST_NAME [UNIT]` to a `concept_id`, with `APPROVED` and, for a pair that is
  not mapped on purpose, an `ignore_mapping_reason`.
- `unitHarmonisation.tsv` — how a `UNIT` converts to the `harmonised_unit` (`CONVERSION`, a factor or a
  formula in `X`). A rule holds for a LOINC property (`context` = `has_property`) or for one concept
  (`context` = `concept_id`, which wins).

## 3_Target

`concept_id [harmonised_unit]`: every standard OMOP `Measurement` concept with its LOINC axes, its LOINC
Groups and the unit its values are harmonised to. It is built from:

- the OMOP vocabulary (concepts, LOINC axes, LOINC Groups);
- lab2clean (the SI unit of each LOINC code, the LOINC Group it assigns, and the conventional-to-SI
  pairs; a conventional concept with an SI partner is removed);
- our rules: a panel and a `Presence or Threshold` (qualitative) concept have no unit;
- `harmonisedUnitOverwrite.tsv`, to change a unit that is wrong, missing or not wanted.

## 4_BuildHarmonisationTable

Validates the `2_Harmonisation` tables against the target and joins them into one table, one row per
`TEST_NAME [PREPROCESED_UNIT]`, with a `mapping_status` (`APPROVED`, `NOT-APPROVED`, `ERROR`, `IGNORE`)
and the warnings of each pair.

## 5_EvaluateHarmonisedData

Applies the conversion to the Kanta deciles and compares each pair with the other pairs of its LOINC
Group (or concept) in the same unit (Kolmogorov-Smirnov, ratio of medians).

## 6_BuildDashboard

Shows the result as an HTML page to review the pairs.
