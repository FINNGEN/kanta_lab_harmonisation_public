# harmonisationTable validation

Validation of the input tables of `4_BuildHarmonisationTable`: the tables of `2_Harmonisation` and `targetTable.tsv`. The problems of the mappings themselves are in the two warning tables and in `mapping_status` (`ERROR:<reason>`).

## Validation summary

| table | SUCCESS | WARNING | ERROR |
| --- | --- | --- | --- |
| unitFix.tsv | 5 | 1 | 0 |
| mapping.tsv | 6 | 0 | 0 |
| unitHarmonisation.tsv | 4 | 0 | 0 |
| harmonisedUnitOverwrite.tsv | 6 | 0 | 0 |
| targetTable.tsv | 3 | 0 | 0 |
| ALL | 24 | 1 | 0 |

## Tests

| table | result | test | n rows | message |
| --- | --- | --- | ---: | --- |
| unitFix.tsv | SUCCESS | columns match their declared types |  |  |
| unitFix.tsv | SUCCESS | TEST_NAME must have a value |  |  |
| unitFix.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT are unique |  |  |
| unitFix.tsv | SUCCESS | UNIT differs from PREPROCESED_UNIT |  |  |
| unitFix.tsv | WARNING | TEST_NAME + UNIT is used downstream (it is in mapping.tsv) | 2 | not used downstream, e.g. s-apob/apoa1-suhde[->ratio]; u-hb-o[form->estimate] |
| unitFix.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT must not appear in mapping.tsv |  |  |
| mapping.tsv | SUCCESS | columns match their declared types |  |  |
| mapping.tsv | SUCCESS | TEST_NAME, concept_id must have a value |  |  |
| mapping.tsv | SUCCESS | TEST_NAME + UNIT are unique |  |  |
| mapping.tsv | SUCCESS | APPROVED must be TRUE or FALSE |  |  |
| mapping.tsv | SUCCESS | concept_id must not be 0, unless there is an ignore_mapping_reason |  |  |
| mapping.tsv | SUCCESS | concept_id is in targetTable.tsv, unless there is an ignore_mapping_reason |  |  |
| unitHarmonisation.tsv | SUCCESS | columns match their declared types |  |  |
| unitHarmonisation.tsv | SUCCESS | context, UNIT, CONVERSION must have a value |  |  |
| unitHarmonisation.tsv | SUCCESS | context + UNIT + HARMONISED_UNIT are unique |  |  |
| unitHarmonisation.tsv | SUCCESS | CONVERSION is a number or a formula in X |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | columns match their declared types |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | concept_id, harmonised_unit, note must have a value |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | concept_id are unique |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | concept_id is in targetTable.tsv |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | harmonised_unit differs from the harmonised_unit of the concept in targetTable.tsv |  |  |
| harmonisedUnitOverwrite.tsv | SUCCESS | harmonised_unit has a rule in unitHarmonisation.tsv (for the has_property or the concept_id) |  |  |
| targetTable.tsv | SUCCESS | columns match their declared types |  |  |
| targetTable.tsv | SUCCESS | concept_id, concept_code, concept_name, vocabulary_id, is_panel must have a value |  |  |
| targetTable.tsv | SUCCESS | concept_id + group_concept_id are unique |  |  |
