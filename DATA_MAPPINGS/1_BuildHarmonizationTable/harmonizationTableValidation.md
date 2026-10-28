# harmonizationTable validation

Validation of the input and output tables of `1_BuildHarmonizationTable`.

## Validation summary

| table | SUCCESS | WARNING | ERROR |
| --- | --- | --- | --- |
| unit_fix.tsv | 5 | 1 | 0 |
| UNITSfi.tsv | 3 | 0 | 0 |
| testname_unit_to_conceptid.tsv | 6 | 0 | 0 |
| measurement_concept_attributes.tsv | 3 | 0 | 0 |
| flowsheet_loinc_groups.tsv | 4 | 0 | 0 |
| conceptid_target_unit.tsv | 5 | 0 | 0 |
| quantity_source_unit_conversion.tsv | 8 | 0 | 0 |
| harmonizationTable.tsv | 6 | 0 | 0 |
| ALL | 40 | 1 | 0 |

## Tests

| table | result | test | message |
| --- | --- | --- | --- |
| unit_fix.tsv | SUCCESS | columns match their declared types |  |
| unit_fix.tsv | SUCCESS | TEST_NAME must have a value |  |
| unit_fix.tsv | SUCCESS | UNIT must be a valid unit in UNITSfi.tsv (or empty) |  |
| unit_fix.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT are unique |  |
| unit_fix.tsv | WARNING | TEST_NAME + UNIT is used downstream (it is in testname_unit_to_conceptid.tsv) | 2 rows (not used downstream), e.g. s-apob/apoa1-suhde[->ratio]; u-hb-o[form->estimate] |
| unit_fix.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT must not appear in testname_unit_to_conceptid.tsv |  |
| UNITSfi.tsv | SUCCESS | columns match their declared types |  |
| UNITSfi.tsv | SUCCESS | UNIT, concept_id, UNIQUE_FOR_LAB must have a value |  |
| UNITSfi.tsv | SUCCESS | UNIT are unique |  |
| testname_unit_to_conceptid.tsv | SUCCESS | columns match their declared types |  |
| testname_unit_to_conceptid.tsv | SUCCESS | TEST_NAME, concept_id must have a value |  |
| testname_unit_to_conceptid.tsv | SUCCESS | UNIT must be a valid unit in UNITSfi.tsv (or empty) |  |
| testname_unit_to_conceptid.tsv | SUCCESS | TEST_NAME + UNIT are unique |  |
| testname_unit_to_conceptid.tsv | SUCCESS | concept_id must not be 0, unless there is an ignore_mapping_reason |  |
| testname_unit_to_conceptid.tsv | SUCCESS | concept_id is in measurement_concept_attributes.tsv, unless there is an ignore_mapping_reason |  |
| measurement_concept_attributes.tsv | SUCCESS | columns match their declared types |  |
| measurement_concept_attributes.tsv | SUCCESS | concept_id, concept_code, concept_name, vocabulary_id, is_panel must have a value |  |
| measurement_concept_attributes.tsv | SUCCESS | concept_id are unique |  |
| flowsheet_loinc_groups.tsv | SUCCESS | columns match their declared types |  |
| flowsheet_loinc_groups.tsv | SUCCESS | concept_id, group_concept_id, group_concept_code, group_concept_name must have a value |  |
| flowsheet_loinc_groups.tsv | SUCCESS | concept_id are unique |  |
| flowsheet_loinc_groups.tsv | SUCCESS | concept_id is in measurement_concept_attributes.tsv |  |
| conceptid_target_unit.tsv | SUCCESS | columns match their declared types |  |
| conceptid_target_unit.tsv | SUCCESS | concept_id, HARMONISED_UNIT must have a value |  |
| conceptid_target_unit.tsv | SUCCESS | HARMONISED_UNIT must be a valid unit in UNITSfi.tsv |  |
| conceptid_target_unit.tsv | SUCCESS | concept_id are unique |  |
| conceptid_target_unit.tsv | SUCCESS | concept_id is in measurement_concept_attributes.tsv |  |
| quantity_source_unit_conversion.tsv | SUCCESS | columns match their declared types |  |
| quantity_source_unit_conversion.tsv | SUCCESS | has_property, UNIT, HARMONISED_UNIT, CONVERSION must have a value |  |
| quantity_source_unit_conversion.tsv | SUCCESS | UNIT must be a valid unit in UNITSfi.tsv |  |
| quantity_source_unit_conversion.tsv | SUCCESS | HARMONISED_UNIT must be a valid unit in UNITSfi.tsv |  |
| quantity_source_unit_conversion.tsv | SUCCESS | has_property + UNIT + HARMONISED_UNIT + ONLY_TO_OMOP_CONCEPTS are unique |  |
| quantity_source_unit_conversion.tsv | SUCCESS | CONVERSION is a number or a formula in X |  |
| quantity_source_unit_conversion.tsv | SUCCESS | has_property is a has_property of measurement_concept_attributes.tsv |  |
| quantity_source_unit_conversion.tsv | SUCCESS | ONLY_TO_OMOP_CONCEPTS are concept ids in measurement_concept_attributes.tsv |  |
| harmonizationTable.tsv | SUCCESS | columns match their declared types |  |
| harmonizationTable.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT are unique |  |
| harmonizationTable.tsv | SUCCESS | has as many rows as testname_unit_to_conceptid.tsv joined with unit_fix.tsv |  |
| harmonizationTable.tsv | SUCCESS | every TEST_NAME + UNIT of testname_unit_to_conceptid.tsv is kept |  |
| harmonizationTable.tsv | SUCCESS | concept_id has its attributes, unless there is an ignore_mapping_reason |  |
| harmonizationTable.tsv | SUCCESS | a row with a HARMONISED_UNIT has a CONVERSION |  |
