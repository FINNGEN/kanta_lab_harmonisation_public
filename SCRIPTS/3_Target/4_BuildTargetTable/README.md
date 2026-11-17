# 4_BuildTargetTable

Builds the target table: every standard `Measurement` concept with its LOINC
axes, its LOINC Group and its harmonised unit.

## Inputs

From `DATA/3_Target/`:

- `1_GetMeasurementOmopData/measurementOmopData.tsv` — the concepts and axes.
- `3_GetLoincGroupsData/loincGroups.tsv` — the Groups.
- `3_GetLoincGroupsData/loincGroupMembership.tsv` — which concept is in which Group.
- `2a_GetHarmonisedUnitFromLab2Clean/harmonisedUnit_lab2clean.tsv` — the lab2clean unit of each concept.
- `2b_HarmonisedUnitFixes/harmonisedUnitFixes.tsv` — the units set by hand.

## Outputs

In `DATA/3_Target/4_BuildTargetTable/`:

- `targetTable.tsv` — one row per concept and Group it belongs to:
  `concept_id`, `concept_code`, `concept_name`, `vocabulary_id`, `is_panel`,
  `has_component`, `has_property`, `has_method`, `has_scale_type`, `has_system`,
  `has_time_aspect` (as in `measurementOmopData.tsv`), then `group_concept_id`,
  `group_concept_code`, `group_concept_name` (as in `loincGroups.tsv`), then
  `harmonised_unit` and `harmonised_unit_source` (`fix` or `lab2clean`; empty for a
  concept with no unit). A concept in several Groups has several rows; a concept in
  no Group has one row with the `group_*` columns empty.
- `log.txt` — run log.

## Action

`scripts/buildTargetTable.R` left-joins the concepts to the membership by
`concept_id`, then to the Groups by `group_concept_id` and to the units by
`concept_id` (the unit of a concept is its fix when it has one, else its lab2clean unit), keeps the columns above
and sorts by `concept_id` and Group code. It logs how many concepts are in a
Group and how many have a harmonised unit.

## Env vars

None required.

## How to run

```
./SCRIPTS/3_Target/4_BuildTargetTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
