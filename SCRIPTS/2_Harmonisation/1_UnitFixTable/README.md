# 1_UnitFixTable

A hand-edited table of the block, not a step: there is no `run.sh` or `scripts/` here.

`DATA/2_Harmonisation/1_UnitFixTable/unitFix.tsv` holds the known fixes of a source unit, copied in from
the earlier version of this project (78 rows).

| Column | Description |
|---|---|
| TEST_NAME | Source lab test name |
| PREPROCESED_UNIT | The unit as it arrives after the preprocessing (`MEASUREMENT_UNIT` in `1_Input`) |
| UNIT | The unit after the fix |
| unit_fix_reasoning | Why the unit was fixed, e.g. `injection_script`, `No harmonized reference data`; empty for most rows |
| INJECTION_NOTES | The result of the check of the injected unit: `VALID` (56 rows), a `PASS`/`FAIL` triple, or `OBVIOUS (OMOP quantity allows only unit '...')` |

The unit column of the input is now called `MEASUREMENT_UNIT`; this table still uses the earlier
name `PREPROCESED_UNIT`.
