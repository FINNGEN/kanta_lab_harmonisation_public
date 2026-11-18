# 2_MappingTable

A hand-edited table of the block, not a step: there is no `run.sh` or `scripts/` here.

`DATA/2_Harmonisation/2_MappingTable/mapping.tsv` maps each source test name and unit to an
OMOP `concept_id`, copied in from the earlier version of this project (7,756 rows).

| Column | Description |
|---|---|
| TEST_NAME | Source lab test name |
| UNIT | The source unit (after the fix in `1_UnitFixTable`); empty for a test with no unit |
| concept_id | The OMOP `Measurement` concept it is mapped to |
| ignore_mapping_reason | Why the test is not mapped (e.g. `Histology/pathology procedure`); empty when it is mapped |
| APPROVED | `TRUE` when the mapping is approved, `FALSE` when it is not |
