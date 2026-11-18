# 2b_HarmonisedUnitOverwrite

A hand-edited input of the block, not a step: there is no `run.sh` or `scripts/` here.

`DATA/3_Target/2b_HarmonisedUnitOverwrite/harmonisedUnitOverwrite.tsv` lists the concepts whose
harmonised unit overwrites the one of lab2clean, because lab2clean (`2a_GetHarmonisedUnitFromLab2Clean`) has no
unit for them or its unit is wrong for the data. `4_BuildTargetTable` takes the unit of
a concept from this table when it has a row, and from lab2clean otherwise.

| Column | Description |
|---|---|
| concept_id | OMOP concept id |
| harmonised_unit | The unit the concept is harmonised to |
| note | Why the unit is overwritten; it becomes `harmonised_unit_source` in the target table |

For now it has one row: concept 3020891 (body temperature), `°c`, because lab2clean does not
have it.
