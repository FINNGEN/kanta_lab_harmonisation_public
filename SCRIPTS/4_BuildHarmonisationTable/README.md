# 4_BuildHarmonisationTable

Validates the harmonisation tables and joins them into one table: one row per source lab test and
unit, resolved to its OMOP concept, the concept's Group, its harmonised unit and the conversion to
it, so the harmonise scripts only have to join it.

## Inputs

From `DATA/`:

- `2_Harmonisation/unitFix.tsv` — `TEST_NAME`, `MEASUREMENT_UNIT`, `UNIT`,
  `unit_fix_reasoning`, `INJECTION_NOTES`. The known unit fixes.
- `2_Harmonisation/mapping.tsv` — `TEST_NAME`, `UNIT`, `concept_id`,
  `ignore_mapping_reason`, `APPROVED`. The base of the table.
- `2_Harmonisation/unitHarmonisation.tsv` — `context`, `UNIT`,
  `HARMONISED_UNIT`, `CONVERSION`. The conversion per property or concept, source unit and
  harmonised unit (a unit of lab2clean or of `harmonisedUnitOverwrite.tsv`).
- `2_Harmonisation/harmonisedUnitOverwrite.tsv` — `concept_id`, `harmonised_unit`, `note`. The target unit of a
  concept set by hand; it wins over the one of `targetTable.tsv`.
- `1_Input/1_BuildKantaAgregatedTable/kantaAgregatedTable.tsv` — only to validate: the pairs of the Kanta data, to
  tell the rows of `mapping.tsv` and `unitFix.tsv` that no pair uses.
- `3_Target/4_BuildTargetTable/targetTable.tsv` — the concept, its LOINC axes, its Groups and
  its harmonised unit (`harmonised_unit`), joined on the concept id.

## Outputs

In `DATA/4_BuildHarmonisationTable/`:

- `harmonisationTable.tsv`:

| Column | Type | Description | Comes from |
|---|---|---|---|
| **mapping_status** | Character | First column. `IGNORE` if there is an `ignore_mapping_reason`; `ERROR:<reason>` if the mapping is `APPROVED` and has an error, the first of `MissingConceptId` (the `concept_id` is not in `targetTable.tsv`), `PropertyUnitMismatch` and `SharedProperty` (a warning of that table not marked `ignore`), `MissingConversion` and `LoincGroupUnitsMissmatch` (a warning of `test_unit_context_unit_missing_warning.tsv` or `test_unit_loinc_group_unit_mismatch_warning.tsv` not marked `ignore`); `APPROVED` if `APPROVED` is `TRUE`; `NOT-APPROVED` if it is `FALSE` | `mapping.tsv` and the warning tables |
| **TEST_NAME** | Character | Source lab test name (join key) | `mapping.tsv` |
| MEASUREMENT_UNIT | Character | Unit as it arrives after preprocessing. The `UNIT` when the pair is not in `unitFix.tsv` | `unitFix.tsv` |
| **UNIT** | Character | Unit after the fix (join key). Empty for qualitative tests | `mapping.tsv` |
| unit_fix_reasoning | Character | Why the unit was fixed | `unitFix.tsv` |
| concept_id | Integer | Target OMOP measurement `concept_id` (`0` when unmapped) | `mapping.tsv` |
| ignore_mapping_reason | Character | Why the test is not mapped | `mapping.tsv` |
| concept_code, concept_name, vocabulary_id, is_panel, has_component, has_property |  | The concept itself; `has_property` (the kind of quantity) is what decides the unit conversion | `targetTable.tsv` |
| group_concept_id, group_concept_code, group_concept_name | Character | The LOINC Groups the concept belongs to, joined with `;` (same order in the three columns, by group code) | `targetTable.tsv` |
| target_unit | Character | The target unit of the concept: its row of `harmonisedUnitOverwrite.tsv`, else `harmonised_unit` of `targetTable.tsv`. Empty for a qualitative concept, a panel, or a concept with no unit | `harmonisedUnitOverwrite.tsv`, `targetTable.tsv` |
| target_unit_source | Character | Where `target_unit` came from: the `note` of the overwrite, else `harmonised_unit_source` of `targetTable.tsv` (`lab2clean`, `isQualitative`, `panel`) | `harmonisedUnitOverwrite.tsv`, `targetTable.tsv` |
| HARMONISED_UNIT | Character | Unit the value is converted to: `target_unit`, but empty when there is no `CONVERSION` | `target_unit` |
| CONVERSION | Character | Factor, or a formula in `X`, so that `value_in_HARMONISED_UNIT = value_in_UNIT * CONVERSION` | `unitHarmonisation.tsv` |
| mapping_warning_messages | Character | Last column. Every message of the four warning tables that joins to the row (ignored or not), each starting with its type, `WrongProperty:` (property mismatch), `SharedProperty:` (shared property), `MissingConversion:` (context unit missing) or `LoincGroupUnitsMismatch:` (LOINC Group unit mismatch), separated by ` \| `. Empty when there is none | the warning tables |

  Of the concept's six LOINC axes only `has_component` and `has_property` are in the table.

- `testname_unit_property_missmatch_warning.tsv` — one row per `TEST_NAME` + `UNIT` whose
  `has_property` + `UNIT` has no rule in `unitHarmonisation.tsv` (neither a rule of the property nor a rule of the
  concept itself): the property of the concept does not agree with the unit. Joins to `harmonisationTable.tsv` on `TEST_NAME` + `UNIT`.
- `testname_property_shared_warning.tsv` — one row per `TEST_NAME` + `has_property` where the
  `TEST_NAME` maps to more than one `concept_id` with that `has_property` (e.g. Leukocytes in Blood and
  in Urine); the message lists the ids. Ignored rows are not checked.
- `test_unit_context_unit_missing_warning.tsv` — one row per `TEST_NAME` + `UNIT` that has a `UNIT` and whose
  concept has a target unit, but `unitHarmonisation.tsv` has no rule (for the `has_property` or the `concept_id`)
  from that `UNIT` to the target unit: its values cannot be converted. Joins on `TEST_NAME` + `UNIT`.
- `test_unit_loinc_group_unit_mismatch_warning.tsv` — one row per `TEST_NAME` + `UNIT` with a target unit in a
  LOINC Group whose approved pairs have more than one target unit; the message lists the Groups and their
  units. Joins on `TEST_NAME` + `UNIT`.

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

- `harmonisationTable.validation.md` — the validation report of the input tables: a validation summary table (`table`,
  `SUCCESS`, `WARNING`, `ERROR`, with a row per table and an `ALL` row), then a table with a row per
  test and the columns `table`, `result` (`SUCCESS`, `WARNING` or `ERROR`), `test`, `n rows` (how many
  rows failed) and `message` (empty on
  success; on failure, the detail with a few examples).
- `harmonisationTable.log.txt` — run log.

A concept can be in several LOINC Groups; they are joined with `;` into one value, so the Groups add no
rows. A pair has more than one row only when `unitFix.tsv` and `mapping.tsv` give the same
`MEASUREMENT_UNIT` two `UNIT`s.

## Action

Every table is read with `readr::read_tsv()` and an explicit `col_types` for each column (in
`scripts/readTables.R`); `""` is read as missing.

`scripts/buildHarmonisationTable.R`, with every join a left join so no pair is lost:

1. Builds one row per `TEST_NAME` + `MEASUREMENT_UNIT`, the unit as it arrives in Kanta:
   - every row of `mapping.tsv` gives the pair that arrives already in its `UNIT` (`MEASUREMENT_UNIT` =
     `UNIT`);
   - every fix of `unitFix.tsv` whose `TEST_NAME` + `UNIT` is in `mapping.tsv` adds one more row, the pair
     that arrives in the wrong `MEASUREMENT_UNIT`, with the mapping of its fixed `UNIT` and the fix's
     `unit_fix_reasoning`.

   A fix adds a row next to the mapping row, it does not replace it: e.g. `p-krea [umol/l]` (from
   `mapping.tsv`) and `p-krea [mmol/l]` (fixed to `umol/l`) both get the creatinine mapping.
2. Appends the concept columns and `harmonised_unit` of `targetTable.tsv` (a row per concept and Group,
   so one row per concept is taken) on `concept_id`. The target unit of a concept in
   `harmonisedUnitOverwrite.tsv` is replaced by its row there (also for a qualitative concept or a panel),
   with the `note` as its source: this gives `target_unit` and `target_unit_source`, and `HARMONISED_UNIT`
   starts as `target_unit`.
3. Appends the Groups of the concept from `targetTable.tsv`, joined with `;`.
4. Appends `CONVERSION` from `unitHarmonisation.tsv` on `context` + `UNIT` + `HARMONISED_UNIT`. A rule
   whose `context` is a LOINC property applies to every concept with that `has_property`; a rule whose
   `context` is a concept id applies only to that concept and wins over the rule of the property with the
   same units.
5. Writes the four warning tables (see above) and sets `mapping_status` and `mapping_warning_messages`.

A `HARMONISED_UNIT` without a `CONVERSION` cannot be applied, so it is set to empty. The step logs how
many pairs had a `HARMONISED_UNIT` cleared for lack of a `CONVERSION` and how many pairs end with none.

The `HARMONISED_UNIT` of `targetTable.tsv` (lab2clean's notation, e.g. `g/L`) must match the
`HARMONISED_UNIT` of `unitHarmonisation.tsv` exactly to find a `CONVERSION`; the validation fails if it does not.

## Validation

`scripts/validateHarmonisationTable.R` runs before the build and checks only the input tables (the tables of
`2_Harmonisation` and `targetTable.tsv`). The problems of the mappings themselves (property mismatch, shared
property, missing conversion, ...) are not part of it: they are in the four warning tables and in
`mapping_status` (`ERROR:<reason>`).
A failed test is an `ERROR` (or, for a finding that does not break the table, a `WARNING`) row in the report
and a warning in the log. The step stops (and does not build the table) when any test is an `ERROR`. Tests,
per table:

| Table | Tests |
|---|---|
| all tables | The columns match their declared types |
| `unitFix.tsv` | `TEST_NAME` has a value; `TEST_NAME` + `MEASUREMENT_UNIT` are unique; `UNIT` differs from `MEASUREMENT_UNIT`; `TEST_NAME` + `MEASUREMENT_UNIT` must not appear in `mapping.tsv`; WARNING if a `TEST_NAME` + `UNIT` is not in `mapping.tsv`, so the fix is not used; WARNING if a `TEST_NAME` + `MEASUREMENT_UNIT` is not in the Kanta data (`kantaAgregatedTable.tsv`), so the fix fixes nothing |
| `mapping.tsv` | `TEST_NAME` and `concept_id` have a value; `TEST_NAME` + `UNIT` are unique; `APPROVED` is `TRUE` or `FALSE`; `concept_id` is not 0, unless there is an `ignore_mapping_reason`; `concept_id` is in `targetTable.tsv`, unless there is an `ignore_mapping_reason`; WARNING if a `TEST_NAME` + `UNIT` is not in the Kanta data, neither directly nor through a fix of `unitFix.tsv` (a test that no longer comes in, or an old unit) |
| `unitHarmonisation.tsv` | Only checks of the table itself, with no input or target data: `context`, `UNIT` and `CONVERSION` have a value (an empty `HARMONISED_UNIT` is a unit that maps to no unit, e.g. `estimate`); `context` + `UNIT` + `HARMONISED_UNIT` are unique; `CONVERSION` is a number or a formula in `X` |
| `harmonisedUnitOverwrite.tsv` | `concept_id`, `harmonised_unit` and `note` have a value; `concept_id` is unique; `concept_id` is in `targetTable.tsv`; WARNING if `harmonised_unit` is the one the concept already has in `targetTable.tsv` (the row is not needed); WARNING if `harmonised_unit` has no rule in `unitHarmonisation.tsv` for the `has_property` or the `concept_id` (nothing converts to it) |
| `targetTable.tsv` | `concept_id`, `concept_code`, `concept_name`, `vocabulary_id` and `is_panel` have a value; `concept_id` + `group_concept_id` are unique |

The earlier version also checked that a unit is a valid unit of `UNITSfi.tsv`; that table is not in this
project, so no unit validation is run.

## Env vars

None required.

## How to run

```
./SCRIPTS/4_BuildHarmonisationTable/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
