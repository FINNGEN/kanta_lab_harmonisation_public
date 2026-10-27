# 1_BuildHarmonizationTable

Builds the harmonization table: one row per source lab test and unit, resolved
to its OMOP concept, the concept's attributes, its LOINC Group, its target unit
and the conversion to it, so the harmonize scripts only have to join it.

## Inputs

From `DATA_MAPPINGS/`:

- `0_MappingTables/testname_unit_to_conceptid.tsv` — `TEST_NAME`,
  `MEASUREMENT_UNIT`, `OMOP_ID`. The base of the table.
- `0_GetMeasurementOmopData/measurement_concept_attributes.tsv` — the concept
  attributes, joined on the concept id.
- `0_GetMeasurementOmopData/loinc_group_membership.tsv` — the LOINC Groups of a
  concept, joined on the concept id.
- `0_MappingTables/conceptid_target_unit.tsv` — `OMOP_ID`, `TARGET_UNIT`. The target unit of each concept.
- `0_MappingTables/quantity_source_unit_conversion.tsv` — the conversion per
  quantity, source unit and target unit.

## Outputs

In `DATA_MAPPINGS/1_BuildHarmonizationTable/`:

- `harmonizationTable.tsv`:

| Column | Type | Description | Comes from |
|---|---|---|---|
| **TEST_NAME** | Character | Source lab test name (join key) | `testname_unit_to_conceptid.tsv` |
| **MEASUREMENT_UNIT** | Character | Source unit (join key). Empty for qualitative tests | `testname_unit_to_conceptid.tsv` |
| concept_id | Integer | Target OMOP measurement concept (`0` when unmapped) | `testname_unit_to_conceptid.tsv` (`OMOP_ID`) |
| concept_code, concept_name, vocabulary_id, is_panel | | The concept itself | `measurement_concept_attributes.tsv` |
| has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect | Character | The 6 LOINC axes; `has_property` is the OMOP quantity | `measurement_concept_attributes.tsv` |
| group_concept_id | Integer | LOINC Group the concept belongs to | `loinc_group_membership.tsv` |
| TARGET_UNIT | Character | Unit the value is converted to | `conceptid_target_unit.tsv` |
| CONVERSION | Character | Factor, or a formula in `X`, so that `value_in_TARGET_UNIT = value_in_MEASUREMENT_UNIT * CONVERSION` | `quantity_source_unit_conversion.tsv` |

- `log.txt` — run log.

A concept belongs to several LOINC Groups, so a pair with several Groups takes
one row per Group; every other column repeats.

## Action

`scripts/buildHarmonizationTable.R`, with every join a left join so no pair is
lost:

1. Starts from `testname_unit_to_conceptid.tsv`, renaming `OMOP_ID` to
   `concept_id`.
2. Appends `measurement_concept_attributes.tsv` on `concept_id`.
3. Appends `loinc_group_membership.tsv` on `concept_id`, keeping only
   `group_concept_id`.
4. Renames `conceptid_target_unit.tsv`'s `OMOP_ID` to `concept_id` and appends it
   on `concept_id` to get `TARGET_UNIT`.
5. Renames `quantity_source_unit_conversion.tsv`'s
   `harmonization_omop::OMOP_QUANTITY` to `has_property` and
   `TO_MEASUREMENT_UNIT` to `TARGET_UNIT`, and appends it on `has_property` +
   `MEASUREMENT_UNIT` + `TARGET_UNIT`, keeping only `CONVERSION`. A rule with
   `ONLY_TO_OMOP_CONCEPTS` applies only to rows with that `concept_id`, and wins
   over the general rule with the same keys.

It logs how many pairs have no `TARGET_UNIT` and how many have a `TARGET_UNIT`
but no `CONVERSION`. `unit_fix.tsv` is not used yet.

## Env vars

None required.

## How to run

```
./STEPS/MAPPING/1_BuildHarmonizationTable/run.sh <PATH_TO_DATA_MAPPINGS> --env <ENV_NAME>
```
