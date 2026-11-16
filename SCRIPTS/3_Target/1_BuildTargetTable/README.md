# 1_BuildTargetTable

Builds the target table: every standard `Measurement` concept with its LOINC
axes, its LOINC Group and the harmonised unit of that Group.

## Inputs

From `DATA/3_Target/`:

- `0_GetMeasurementOmopData/measurementOmopData.tsv` — the concepts and axes.
- `0_GetLoincGroupsData/loincGroups.tsv` — the Groups and their harmonised unit.
- `0_GetLoincGroupsData/loincGroupMembership.tsv` — which concept is in which Group.

## Outputs

In `DATA/3_Target/1_BuildTargetTable/`:

- `targetTable.tsv` — one row per concept and Group it belongs to:
  `concept_id`, `concept_code`, `concept_name`, `vocabulary_id`, `is_panel`,
  `has_component`, `has_property`, `has_method`, `has_scale_type`, `has_system`,
  `has_time_aspect` (as in `measurementOmopData.tsv`), then `group_concept_id`,
  `group_concept_code`, `group_concept_name`, `group_harmonised_unit` (as in
  `loincGroups.tsv`). A concept in several Groups has several rows; a concept in
  no Group has one row with the `group_*` columns empty.
- `log.txt` — run log.

## Action

`scripts/buildTargetTable.R` left-joins the concepts to the membership by
`concept_id`, then to the Groups by `group_concept_id`, keeps the columns above
and sorts by `concept_id` and Group code. It logs how many concepts are in a
Group and how many have a harmonised unit.

## Env vars

None required.

## How to run

```
./SCRIPTS/3_Target/1_BuildTargetTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
