# 4_BuildHarmonisationTable

Validates the harmonisation tables and joins them into one table: one row per source lab test and
unit, resolved to its OMOP concept, the concept's Group, its harmonised unit and the conversion to
it, so the harmonise scripts only have to join it.

## Inputs

From `DATA/`:

- `2_Harmonisation/unitFix.tsv` — `TEST_NAME`, `PREPROCESED_UNIT`, `UNIT`,
  `unit_fix_reasoning`, `INJECTION_NOTES`. The known unit fixes.
- `2_Harmonisation/mapping.tsv` — `TEST_NAME`, `UNIT`, `concept_id`,
  `ignore_mapping_reason`, `APPROVED`. The base of the table.
- `2_Harmonisation/unitHarmonisation.tsv` — `context`, `UNIT`,
  `HARMONISED_UNIT`, `CONVERSION`. The conversion per property or concept, source unit and
  harmonised unit (a unit of lab2clean or of the unit overwrite table).
- `3_Target/2a_GetHarmonisedUnitFromLab2Clean/harmonisedUnit_lab2clean.tsv` and
  `3_Target/2b_HarmonisedUnitOverwrite/harmonisedUnitOverwrite.tsv` — only to validate the units.
- `3_Target/4_BuildTargetTable/targetTable.tsv` — the concept, its LOINC axes, its Groups and
  its harmonised unit (`harmonised_unit`), joined on the concept id.

## Outputs

In `DATA/4_BuildHarmonisationTable/`:

- `harmonisationTable.tsv`:

| Column | Type | Description | Comes from |
|---|---|---|---|
| **mapping_status** | Character | First column. `IGNORE` if there is an `ignore_mapping_reason`; `ERROR` if the mapping is `APPROVED` and has a warning not marked `ignore` (in either warning table); `APPROVED` if `APPROVED` is `TRUE`; `NOT-APPROVED` if it is `FALSE` | `mapping.tsv` and the warning tables |
| **TEST_NAME** | Character | Source lab test name (join key) | `mapping.tsv` |
| PREPROCESED_UNIT | Character | Unit as it arrives after preprocessing. The `UNIT` when the pair is not in `unitFix.tsv` | `unitFix.tsv` |
| **UNIT** | Character | Unit after the fix (join key). Empty for qualitative tests | `mapping.tsv` |
| unit_fix_reasoning | Character | Why the unit was fixed | `unitFix.tsv` |
| concept_id | Integer | Target OMOP measurement `concept_id` (`0` when unmapped) | `mapping.tsv` |
| ignore_mapping_reason | Character | Why the test is not mapped | `mapping.tsv` |
| concept_code, concept_name, vocabulary_id, is_panel, has_component, has_property |  | The concept itself; `has_property` (the kind of quantity) is what decides the unit conversion | `targetTable.tsv` |
| group_concept_id, group_concept_code, group_concept_name | Character | The LOINC Groups the concept belongs to, joined with `;` (same order in the three columns, by group code) | `targetTable.tsv` |
| HARMONISED_UNIT | Character | Unit the value is converted to. Empty when there is no `CONVERSION` | `targetTable.tsv` (`harmonised_unit`) |
| CONVERSION | Character | Factor, or a formula in `X`, so that `value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION` | `unitHarmonisation.tsv` |
| mapping_warning_messages | Character | Last column. Every message of the two warning tables that joins to the row (ignored or not), each starting with its type, `WrongProperty:` (property mismatch) or `SharedProperty:` (shared property), separated by ` \| `. Empty when there is none | the warning tables |

  Of the concept's six LOINC axes only `has_component` and `has_property` are in the table.

- `testname_unit_property_missmatch_warning.tsv` — one row per `TEST_NAME` + `UNIT` whose
  `has_property` + `UNIT` has no rule in `unitHarmonisation.tsv` (neither a rule of the property nor a rule of the
  concept itself): the property of the concept does not agree with the unit. Joins to `harmonisationTable.tsv` on `TEST_NAME` + `UNIT`.
- `testname_property_shared_warning.tsv` — one row per `TEST_NAME` + `has_property` where the
  `TEST_NAME` maps to more than one `concept_id` with that `has_property` (e.g. Leukocytes in Blood and
  in Urine); the message lists the ids. Ignored rows are not checked.

| Column | Type | Description |
|---|---|---|
| TEST_NAME, UNIT (first table) or TEST_NAME, has_property (second) | Character | The key of the warning |
| message | Character | The detail of the warning |
| ignore | Logical | `FALSE`, or `TRUE` when the warning was accepted by hand |

  The warnings are not columns of `harmonisationTable.tsv`. The warning tables are only edited when a
  change appears: a warning that is not in the file yet is added (`ignore` `FALSE`), a warning that is
  gone is removed, and a warning already in the file is left as it is, with its hand-set `ignore`. A
  warning is its key plus its `message`, so a changed message is a new warning. If nothing changed the
  file is not written. They are the same tables as in the earlier version of the project (with the file
  name in the message updated), so the `ignore` flags carry over.

- `harmonisationTableValidation.md` — the validation report: a validation summary table (`table`,
  `SUCCESS`, `WARNING`, `ERROR`, with a row per table and an `ALL` row), then a table with a row per
  test and the columns `table`, `result` (`SUCCESS`, `WARNING` or `ERROR`), `test`, `n rows` (how many
  rows failed; for the warning tables, how many warnings not marked `ignore`) and `message` (empty on
  success; on failure, the detail with a few examples).
- `harmonisationTable.md` — a summary of `harmonisationTable.tsv`: the mapping status (approved / not
  approved / ignored, with `n` and `%` of the rows and how many have a warning or an error that is not
  marked `ignore`), and for the approved rows how many distinct `concept_id`s, how many rows have a group,
  how many distinct groups and how many rows have a conversion.
- `log.txt` — run log.

A concept can be in several LOINC Groups; they are joined with `;` into one value, so the Groups add no
rows. A pair has more than one row only when `unitFix.tsv` and `mapping.tsv` give the same
`PREPROCESED_UNIT` two `UNIT`s.

## Action

Every table is read with `readr::read_tsv()` and an explicit `col_types` for each column (in
`scripts/readTables.R`); `""` is read as missing.

`scripts/buildHarmonisationTable.R`, with every join a left join so no pair is lost:

1. Starts from `mapping.tsv` and puts `unitFix.tsv` in front of it, joined on `TEST_NAME` + `UNIT`.
   `PREPROCESED_UNIT` and `unit_fix_reasoning` come from the fix; a pair that is not in `unitFix.tsv`
   copies its `UNIT` into `PREPROCESED_UNIT`.
2. Appends the concept columns and `harmonised_unit` of `targetTable.tsv` (a row per concept and Group,
   so one row per concept is taken) on `concept_id`; `harmonised_unit` becomes `HARMONISED_UNIT`.
3. Appends the Groups of the concept from `targetTable.tsv`, joined with `;`.
4. Appends `CONVERSION` from `unitHarmonisation.tsv` on `context` + `UNIT` + `HARMONISED_UNIT`. A rule
   whose `context` is a LOINC property applies to every concept with that `has_property`; a rule whose
   `context` is a concept id applies only to that concept and wins over the rule of the property with the
   same units.
5. Writes the two warning tables (see above) and sets `mapping_status` and `mapping_warning_messages`.

A `HARMONISED_UNIT` without a `CONVERSION` cannot be applied, so it is set to empty. The step logs how
many pairs had a `HARMONISED_UNIT` cleared for lack of a `CONVERSION` and how many pairs end with none.

The `HARMONISED_UNIT` of `targetTable.tsv` (lab2clean's notation, e.g. `g/L`) must match the
`HARMONISED_UNIT` of `unitHarmonisation.tsv` exactly to find a `CONVERSION`; the validation fails if it does not.

## Validation

`scripts/validateHarmonisationTable.R` runs after the build and checks every input table and the output.
A failed test does not stop the step: it is an `ERROR` (or, for a finding that does not break the table, a
`WARNING`) row in the report and a warning in the log. Tests, per table:

| Table | Tests |
|---|---|
| all tables | The columns match their declared types |
| `unitFix.tsv` | `TEST_NAME` has a value; `TEST_NAME` + `PREPROCESED_UNIT` are unique; `UNIT` differs from `PREPROCESED_UNIT`; `TEST_NAME` + `PREPROCESED_UNIT` must not appear in `mapping.tsv`; WARNING if a `TEST_NAME` + `UNIT` is not in `mapping.tsv`, so the fix is not used |
| `mapping.tsv` | `TEST_NAME` and `concept_id` have a value; `TEST_NAME` + `UNIT` are unique; `APPROVED` is `TRUE` or `FALSE`; `concept_id` is not 0, unless there is an `ignore_mapping_reason`; `concept_id` is in `targetTable.tsv`, unless there is an `ignore_mapping_reason` |
| `unitHarmonisation.tsv` | `context`, `UNIT` and `CONVERSION` have a value (an empty `HARMONISED_UNIT` is a unit that maps to no unit, e.g. `estimate`); `context` + `UNIT` + `HARMONISED_UNIT` are unique; `CONVERSION` is a number or a formula in `X`; `context` is a `has_property` or a `concept_id` of `targetTable.tsv`; `HARMONISED_UNIT` is a unit of lab2clean or of the unit overwrite table; the target unit of every approved concept (`targetTable.tsv`) has a rule for its `has_property` |
| `targetTable.tsv` | `concept_id`, `concept_code`, `concept_name`, `vocabulary_id` and `is_panel` have a value; `concept_id` + `group_concept_id` are unique |
| `harmonisationTable.tsv` | The table has as many rows as `mapping.tsv` joined with `unitFix.tsv`; `TEST_NAME` + `PREPROCESED_UNIT` are unique; every `TEST_NAME` + `UNIT` of `mapping.tsv` is kept; `concept_id` has its attributes, unless there is an `ignore_mapping_reason`; `mapping_status` is one of the four values, and `IGNORE` if and only if there is an `ignore_mapping_reason`; a row with `ERROR` has `mapping_warning_messages`; a row with a `HARMONISED_UNIT` has a `CONVERSION`; an approved pair with a `UNIT` whose concept has a target unit has a `CONVERSION` to it (ERROR), and one with no `UNIT` is a WARNING, since no table can convert it; each warning not marked `ignore` is an `ERROR` if it affects an `APPROVED` mapping, a `WARNING` otherwise |
| the two warning tables | The columns match their declared types; `TEST_NAME`, `message` and `ignore` have a value; the key (`TEST_NAME` + `UNIT`, or `TEST_NAME` + `has_property`) is unique |

The earlier version also checked that a unit is a valid unit of `UNITSfi.tsv`; that table is not in this
project, so no unit validation is run.

## Env vars

None required.

## How to run

```
./SCRIPTS/4_BuildHarmonisationTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
