# 3_UnitHarmonisationTable

A hand-edited table of the block, not a step: there is no `run.sh` or `scripts/` here.

`DATA/2_Harmonisation/3_UnitHarmonisationTable/unitHarmonisation.tsv` gives the conversion of
each source unit to the harmonised unit, per LOINC property or per concept, copied in from the earlier version of this
project (181 rows).

| Column | Description |
|---|---|
| context | What the conversion applies to: a LOINC property (e.g. `Arbitrary Concentration`) for every concept of that property, or an OMOP `concept_id` for that concept only |
| UNIT | The source unit |
| HARMONISED_UNIT | The unit it is harmonised to, or empty for a unit with no unit (a qualitative result, `estimate`): a unit of lab2clean (`3_Target/2a_GetHarmonisedUnitFromLab2Clean`) or of the unit overwrite table (`3_Target/2b_HarmonisedUnitOverwrite`), as in `targetTable.tsv` (e.g. `g/L`, `10*3.[iU]/L`). `UNIT` is the source unit, in the notation of the Kanta data (e.g. `g/l`) |
| CONVERSION | A factor, or a formula in `X`, so that `value in HARMONISED_UNIT = value in UNIT * CONVERSION` |
| VALIDATION_MESSAGES | Warnings from the check of the conversion; empty in every row now |

The harmonised unit of a concept comes from `3_Target` (`harmonised_unit` in `4_BuildTargetTable`); this table gives the
conversion of a source unit to it, so the `HARMONISED_UNIT` of a row must be a target unit of `3_Target`.

The table was rebuilt for lab2clean's units. Its rows are the conversions from every source `UNIT` of the mapping
(`2_MappingTable`, after the fixes of `1_UnitFixTable`) to the target unit of the concept, for the concepts that have one:
- **Notation only:** the factor is 1 (e.g. `titre` to `1`, `ratio` to `1`, `ph` to `[pH]`, `u/field` to `/[HPF]`, `mg/24h` to `mg/(24.h)`).
- **A qualitative result:** `estimate` (the unit the preprocessing gives a text result) maps to an empty `HARMONISED_UNIT`
  for `Presence or Threshold`, whose concepts have no unit (`isQualitative` in `3_Target/4_BuildTargetTable`).
- **A factor:** the ratio of the magnitudes of the two UCUM units (e.g. `g/l` to `mg/L` is 1000), from lab2clean's unit data.
- **Arbitrary units:** a unit of the family `u`, `iu`, `au`, `eliau` per volume converts to `[iU]` or `[arb'U]` per litre by the prefix and
  volume only, taking a generic `u` as an international unit, as the earlier table did.
- **Concepts with a formula:** `3004410` (HbA1c), `mmol/mol` and `%` to `mmol/mol` (`10.93*X-23.50`), because its target unit is
  `mmol/mol` (see `3_Target/2b_HarmonisedUnitOverwrite`); and `44816559`, `mg/l` to `ug/L` with `703*X+0` (the earlier `0.703*X+0`,
  in mg/L, times 1000).

A source unit that cannot be converted to the target of its concept has no row: a different dimension (e.g. `%` to a concentration), an
arbitrary unit to a unit that is not (e.g. `u/ml` to `1`), or a unit lab2clean does not read (`index`, `eiu`, `ml/min/173m2`). The
validation of `4_BuildHarmonisationTable` lists them.
