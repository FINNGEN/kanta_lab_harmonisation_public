# 1_BuildHarmonizationTable

Builds the harmonization table: one row per source lab test and unit, resolved
to its OMOP concept, the concept's attributes, its LOINC Group, its target unit
and the conversion to it, so the harmonize scripts only have to join it.

## Inputs

From `DATA_MAPPINGS/`:

- `0_MappingTables/unit_fix.tsv` — `TEST_NAME`, `PREPROCESED_UNIT`, `UNIT`,
  `unit_fix_reasoning`, `INJECTION_NOTES`. The known unit fixes.
- `0_MappingTables/testname_unit_to_conceptid.tsv` — `TEST_NAME`, `UNIT`,
  `concept_id`, `ignore_mapping_reason`, `APPROVED`. The base of the table.
- `0_GetMeasurementOmopData/measurement_concept_attributes.tsv` — the concept
  attributes, joined on the concept id.
- `0_GetMeasurementOmopData/flowsheet_loinc_groups.tsv` — the LOINC Groups of a
  concept, joined on the concept id.
- `0_MappingTables/conceptid_target_unit.tsv` — `OMOP_ID`, `HARMONISED_UNIT`. The target unit of each concept.
- `0_MappingTables/UNITSfi.tsv` — the valid units, used only by the validation.
- `0_MappingTables/quantity_source_unit_conversion.tsv` — the conversion per
  quantity, source unit and target unit.

## Outputs

In `DATA_MAPPINGS/1_BuildHarmonizationTable/`:

- `harmonizationTable.tsv`:

| Column | Type | Description | Comes from |
|---|---|---|---|
| **TEST_NAME** | Character | Source lab test name (join key) | `testname_unit_to_conceptid.tsv` |
| PREPROCESED_UNIT | Character | Unit as it arrives after preprocessing. The `UNIT` when the pair is not in `unit_fix.tsv` | `unit_fix.tsv` |
| **UNIT** | Character | Unit after the fix (join key). Empty for qualitative tests | `testname_unit_to_conceptid.tsv` |
| unit_fix_reasoning | Character | Why the unit was fixed | `unit_fix.tsv` |
| concept_id | Integer | Target OMOP measurement `concept_id` (`0` when unmapped) | `testname_unit_to_conceptid.tsv` |
| ignore_mapping_reason | Character | Why the test is not mapped | `testname_unit_to_conceptid.tsv` |
| APPROVED | Logical | `TRUE` if the mapping was approved | `testname_unit_to_conceptid.tsv` |
| concept_code, concept_name, vocabulary_id, is_panel |  | The concept itself | `measurement_concept_attributes.tsv` |
| has_component, has_property, has_method, has_scale_type, has_system, has_time_aspect | Character | The 6 LOINC axes | `measurement_concept_attributes.tsv` |
| group_concept_id, group_concept_code, group_concept_name | Character | LOINC Groups the concept belongs to, joined with `;` (same order in the three columns) | `flowsheet_loinc_groups.tsv` |
| HARMONISED_UNIT | Character | Unit the value is converted to. Empty when there is no `CONVERSION` | `conceptid_target_unit.tsv` |
| CONVERSION | Character | Factor, or a formula in `X`, so that `value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION` | `quantity_source_unit_conversion.tsv` |
| Message | Character | Explains the error or warning of the row, starting with `ERROR:` or `WARNING:`; empty if none | Built by the step |

- `harmonizationTableValidation.md` — the validation report: a validation
  summary table (`table`, `SUCCESS`, `WARNING`, `ERROR`, with a row per table and
  an `ALL` row), then a table with a row per test and the columns `table` (an input or output table),
  `result` (`SUCCESS`, `WARNING` or `ERROR`), `test` (a short description), `n rows` (how many rows failed) and
  `message` (empty on success; on failure, the detail with a few examples).
- `harmonizationTable.md` — a summary of `harmonizationTable.tsv`. A table of the
  mapping status (approved / not approved / ignored, with `n` and `%` of the rows,
  and how many rows of each have a WARNING or an ERROR `Message`), and for the
  approved rows how many distinct `concept_id`s, how many rows have a group (`n`,
  `%`), how many distinct groups, and how many rows have a conversion (`n`, `%`). A
  row is a `TEST_NAME` + `PREPROCESED_UNIT` pair; a row with an
  `ignore_mapping_reason` is ignored, otherwise `APPROVED` decides.
- `log.txt` — run log.

A concept can be in several LOINC Groups; they are joined with `;` into one value, so the Groups add no rows. A pair has more than
one row only when `unit_fix.tsv` and the base table give the same
`PREPROCESED_UNIT` two `UNIT`s.

## Action

Every table is read with `readr::read_tsv()` and an explicit `col_types` for each
column; `""` is read as missing. Ids are integers (except the group columns of the output, which can hold several), `is_panel` is logical, and everything else is character (`CONVERSION`
stays character because it can be a formula in `X`).

`scripts/buildHarmonizationTable.R`, with every join a left join so no pair is
lost:

1. Starts from `testname_unit_to_conceptid.tsv` and puts `unit_fix.tsv` in front
   of it, joined on `TEST_NAME` + `UNIT`. `PREPROCESED_UNIT` and
   `unit_fix_reasoning` come from the fix; a pair that is not in `unit_fix.tsv`
   copies its `UNIT` into `PREPROCESED_UNIT`. A `UNIT` fixed from several
   `PREPROCESED_UNIT`s takes one row for each.
2. Appends `measurement_concept_attributes.tsv` on `concept_id`.
3. Appends `flowsheet_loinc_groups.tsv` on `concept_id`, keeping only
   `group_concept_id`, `group_concept_code` and `group_concept_name`, each joined
   with `;` over the Groups of the concept (fewest descendants first).
4. Appends `conceptid_target_unit.tsv` on `concept_id` to get `HARMONISED_UNIT`.
5. Appends `quantity_source_unit_conversion.tsv` on `has_property` + `UNIT` +
   `HARMONISED_UNIT`, keeping only `CONVERSION`. A rule with an empty
   `ONLY_TO_OMOP_CONCEPTS` applies to any concept. A rule with concept ids there
   applies only to those concepts, and wins over the general rule with the same
   keys.

A `HARMONISED_UNIT` without a `CONVERSION` cannot be applied, so after the join it
is set to empty (the conversion is looked up with it, so it is cleared last). It
warns about `unit_fix.tsv` rows whose `TEST_NAME` + `UNIT` is not in the
base table, and logs how many pairs had a `HARMONISED_UNIT` cleared for lack of a
`CONVERSION` and how many pairs end with no `HARMONISED_UNIT`.

## Validation

`scripts/summariseHarmonizationTable.R` runs last and writes `harmonizationTable.md`
from the table (see Outputs).

`scripts/validateHarmonizationTable.R` runs after the build and checks every input
table and the output, with the column types read from `scripts/readTables.R`, the
same specs the build reads with. A failed test does not stop the step: it is an
`ERROR` (or, for a finding that does not break the table, a `WARNING`) row in the
report and a warning in the log. Tests, per table:

| Table | Tests |
|---|---|
| all tables | The columns match their declared types |
| `unit_fix.tsv` | `TEST_NAME` has a value; `UNIT` is a valid unit; `TEST_NAME` + `PREPROCESED_UNIT` are unique; `TEST_NAME` + `PREPROCESED_UNIT` must not appear in `testname_unit_to_conceptid.tsv`; WARNING if a `TEST_NAME` + `UNIT` is not in `testname_unit_to_conceptid.tsv`, so the fix is not used downstream |
| `UNITSfi.tsv` | Every column has a value; `UNIT` is unique |
| `testname_unit_to_conceptid.tsv` | `TEST_NAME` and `concept_id` have a value; `concept_id` is not 0, unless there is an `ignore_mapping_reason`; `UNIT` is a valid unit; `TEST_NAME` + `UNIT` are unique; `APPROVED` is `TRUE` or `FALSE`; `concept_id` is in `measurement_concept_attributes.tsv`, unless there is an `ignore_mapping_reason` |
| `measurement_concept_attributes.tsv` | `concept_id`, `concept_code`, `concept_name`, `vocabulary_id` and `is_panel` have a value; `concept_id` is unique |
| `flowsheet_loinc_groups.tsv` | The four columns have a value; `concept_id` + `group_concept_id` are unique; `concept_id` is in `measurement_concept_attributes.tsv` |
| `conceptid_target_unit.tsv` | `concept_id` and `HARMONISED_UNIT` have a value (no empty units); `HARMONISED_UNIT` is a valid unit; `concept_id` is unique and in `measurement_concept_attributes.tsv` |
| `quantity_source_unit_conversion.tsv` | `has_property`, `UNIT`, `HARMONISED_UNIT` and `CONVERSION` have a value (no empty units); `UNIT` and `HARMONISED_UNIT` are valid units; `has_property` + `UNIT` + `HARMONISED_UNIT` + `ONLY_TO_OMOP_CONCEPTS` are unique; `CONVERSION` is a number or a formula in `X`; `has_property` is a property of the attributes; `ONLY_TO_OMOP_CONCEPTS` are concept ids of the attributes |
| `harmonizationTable.tsv` | The table has as many rows as `testname_unit_to_conceptid.tsv` joined with `unit_fix.tsv`; `TEST_NAME` + `PREPROCESED_UNIT` are unique; every `TEST_NAME` + `UNIT` of the base table is kept; `concept_id` has its attributes, unless there is an `ignore_mapping_reason`; a row with a `HARMONISED_UNIT` has a `CONVERSION`; `has_property` + `UNIT` is in `quantity_source_unit_conversion.tsv` (otherwise the property of the concept does not agree with the unit): an ERROR if the mapping is `APPROVED`, a WARNING if not; WARNING: a `TEST_NAME` with the same `has_property` maps to more than one `concept_id` (ignored rows are not checked) |

A valid unit is a unit in `UNITSfi.tsv`, or an empty one (a qualitative test),
except in `conceptid_target_unit.tsv` and `quantity_source_unit_conversion.tsv`,
where a unit can never be empty.

## Env vars

None required.

## How to run

```
./STEPS/MAPPING/1_BuildHarmonizationTable/run.sh <PATH_TO_DATA_MAPPINGS> --env <ENV_NAME>
```
