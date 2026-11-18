# 2_Harmonisation

The tables that map the input onto the target: the unit fixes, the mapping of each source lab
test and unit to an OMOP concept, and the conversion of each source unit to the harmonised unit.
They are plain files under `DATA/2_Harmonisation/`, edited by hand, so every change to a mapping is
a reviewable diff. The step `4_BuildHarmonisationTable` (next to the blocks, in `SCRIPTS/`) validates them and joins them with `3_Target` into the harmonisation table.

| Table | Purpose |
|---|---|
| `1_UnitFixTable` | The known fixes of a source unit, per test name. |
| `2_MappingTable` | The mapping of each test name and unit to an OMOP `concept_id`. |
| `3_UnitHarmonisationTable` | The conversion of each source unit to the harmonised unit, per LOINC property or concept. |

They are tables copied in from the earlier version, not steps: there is no `run.sh` or
`scripts/` in their folders.
