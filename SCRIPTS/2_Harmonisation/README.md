# 2_Harmonisation

The hand-edited tables that map the input onto the target: the unit fixes, the mapping of each source
lab test and unit to an OMOP concept, the conversion of each source unit to the harmonised unit, and the
fixes of the target unit of a concept. Every table edited by hand is here; `3_Target` is built only from
the source data (OMOP, lab2clean) and is not edited. They are not
steps (there is no `run.sh` or `scripts/`): they are plain files in `DATA/2_Harmonisation/`, copied in from
the earlier version of the project and edited by hand, so every change to a mapping is a reviewable diff.

The step `4_BuildHarmonisationTable` (in `SCRIPTS/`, next to the blocks) validates the four tables and joins them with
`3_Target` into the harmonisation table.

| Table | Purpose |
|---|---|
| `unitFix.tsv` | The known fixes of a source unit, per test name. |
| `mapping.tsv` | The mapping of each test name and unit to an OMOP `concept_id`. |
| `unitHarmonisation.tsv` | The conversion of each source unit to the harmonised unit, per LOINC property or concept. |
| `harmonisedUnitOverwrite.tsv` | The target unit of a concept, where the one of `3_Target` is missing or wrong. |

## unitFix.tsv

`DATA/2_Harmonisation/unitFix.tsv` holds the known fixes of a source unit, copied in from
the earlier version of this project (78 rows).

| Column | Description |
|---|---|
| TEST_NAME | Source lab test name |
| MEASUREMENT_UNIT | The unit as it arrives after the preprocessing (`MEASUREMENT_UNIT` in `1_Input`) |
| UNIT | The unit after the fix |
| unit_fix_reasoning | Why the unit was fixed, e.g. `injection_script`, `No harmonized reference data`; empty for most rows |
| INJECTION_NOTES | The result of the check of the injected unit: `VALID` (56 rows), a `PASS`/`FAIL` triple, or `OBVIOUS (OMOP quantity allows only unit '...')` |

The unit column of the input is now called `MEASUREMENT_UNIT`; this table still uses the earlier
name `MEASUREMENT_UNIT`.

## mapping.tsv

`DATA/2_Harmonisation/mapping.tsv` maps each source test name and unit to an
OMOP `concept_id`, copied in from the earlier version of this project (7,756 rows).

| Column | Description |
|---|---|
| TEST_NAME | Source lab test name |
| UNIT | The source unit (after the fix in `unitFix.tsv`); empty for a test with no unit |
| concept_id | The OMOP `Measurement` concept it is mapped to |
| ignore_mapping_reason | Why the test is not mapped (e.g. `Histology/pathology procedure`); empty when it is mapped |
| APPROVED | `TRUE` when the mapping is approved, `FALSE` when it is not |

## unitHarmonisation.tsv

`DATA/2_Harmonisation/unitHarmonisation.tsv` gives the conversion of
each source unit to the harmonised unit, per LOINC property or per concept, copied in from the earlier version of this
project (181 rows).

| Column | Description |
|---|---|
| context | What the conversion applies to: a LOINC property (e.g. `Arbitrary Concentration`) for every concept of that property, or an OMOP `concept_id` for that concept only |
| UNIT | The source unit |
| HARMONISED_UNIT | The unit it is harmonised to, or empty for a unit with no unit (a qualitative result, `estimate`): a unit of lab2clean (`3_Target/2_GetHarmonisedUnitFromLab2Clean`) or of `harmonisedUnitOverwrite.tsv` (e.g. `g/L`, `10*3.[iU]/L`). `UNIT` is the source unit, in the notation of the Kanta data (e.g. `g/l`) |
| CONVERSION | A factor, or a formula in `X`, so that `value in HARMONISED_UNIT = value in UNIT * CONVERSION` |
| VALIDATION_MESSAGES | Warnings from the check of the conversion; empty in every row now |

The harmonised unit of a concept comes from `3_Target` (`harmonised_unit` in `4_BuildTargetTable`), or from
`harmonisedUnitOverwrite.tsv` when the concept has a row there; this table gives the conversion of a source unit to it,
so the `HARMONISED_UNIT` of a row must be one of those units.

The table was rebuilt for lab2clean's units. Its rows are the conversions from every source `UNIT` of the mapping
(`mapping.tsv`, after the fixes of `unitFix.tsv`) to the target unit of the concept, for the concepts that have one:
- **Notation only:** the factor is 1 (e.g. `titre` to `1`, `ratio` to `1`, `ph` to `[pH]`, `u/field` to `/[HPF]`, `mg/24h` to `mg/(24.h)`).
- **A qualitative result:** `estimate` (the unit the preprocessing gives a text result) maps to an empty `HARMONISED_UNIT`
  for `Presence or Threshold`, whose concepts have no unit (`isQualitative` in `3_Target/4_BuildTargetTable`).
- **A factor:** the ratio of the magnitudes of the two UCUM units (e.g. `g/l` to `mg/L` is 1000), from lab2clean's unit data.
- **Arbitrary units:** a unit of the family `u`, `iu`, `au`, `eliau` per volume converts to `[iU]` or `[arb'U]` per litre by the prefix and
  volume only, taking a generic `u` as an international unit, as the earlier table did.
- **Concepts with a formula:** `3004410` (HbA1c), `mmol/mol` and `%` to `mmol/mol` (`10.93*X-23.50`), because its target unit is
  `mmol/mol`; and `44816559`, `mg/l` to `ug/L` with `703*X+0` (the earlier `0.703*X+0`,
  in mg/L, times 1000).

A source unit that cannot be converted to the target of its concept has no row: a different dimension (e.g. `%` to a concentration), an
arbitrary unit to a unit that is not (e.g. `u/ml` to `1`), or a unit lab2clean does not read (`index`, `eiu`, `ml/min/173m2`). The
validation of `4_BuildHarmonisationTable` lists them.

## harmonisedUnitOverwrite.tsv

`DATA/2_Harmonisation/harmonisedUnitOverwrite.tsv` sets the target unit of a concept by hand, where the
`harmonised_unit` of `3_Target/4_BuildTargetTable/targetTable.tsv` is missing or wrong for the data (e.g. lab2clean has
no unit for it). `4_BuildHarmonisationTable` applies it: a concept with a row here takes this unit, whatever
`targetTable.tsv` says (also a qualitative concept or a panel), and its source is the `note`.

| Column | Description |
|---|---|
| concept_id | OMOP concept id |
| harmonised_unit | The target unit of the concept |
| note | Why the unit is set by hand; it becomes the `target_unit_source` of the harmonisation table |

For now it has one row: concept 3020891 (body temperature), `°c`, because lab2clean does not have it.
