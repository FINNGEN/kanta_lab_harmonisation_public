# harmonisationTable validation

Validation of the input and output tables of `4_BuildHarmonisationTable`.

## Validation summary

| table | SUCCESS | WARNING | ERROR |
| --- | --- | --- | --- |
| unitFix.tsv | 5 | 1 | 0 |
| mapping.tsv | 5 | 0 | 1 |
| unitHarmonisation.tsv | 6 | 0 | 1 |
| targetTable.tsv | 3 | 0 | 0 |
| harmonisationTable.tsv | 9 | 2 | 3 |
| testname_unit_property_missmatch_warning.tsv | 3 | 0 | 0 |
| testname_property_shared_warning.tsv | 3 | 0 | 0 |
| ALL | 34 | 3 | 5 |

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
| mapping.tsv | ERROR | concept_id is in targetTable.tsv, unless there is an ignore_mapping_reason | 113 | e.g. s-iga[g/l] concept_id=3007164; p-iga[g/l] concept_id=3007164; p-igg[g/l] concept_id=3005719 |
| unitHarmonisation.tsv | SUCCESS | columns match their declared types |  |  |
| unitHarmonisation.tsv | SUCCESS | context, UNIT, CONVERSION must have a value |  |  |
| unitHarmonisation.tsv | SUCCESS | context + UNIT + HARMONISED_UNIT are unique |  |  |
| unitHarmonisation.tsv | SUCCESS | CONVERSION is a number or a formula in X |  |  |
| unitHarmonisation.tsv | SUCCESS | context is a has_property or a concept_id of targetTable.tsv |  |  |
| unitHarmonisation.tsv | SUCCESS | HARMONISED_UNIT is a lab2clean unit (or a unit of the unit overwrite table) |  |  |
| unitHarmonisation.tsv | ERROR | the target unit of an approved concept (targetTable.tsv) has a rule for its has_property | 11 | 31 approved concepts, 11 has_property + unit, e.g. has_property=Arbitrary Concentration harmonised_unit=[arb'U]; has_property=Ratio harmonised_unit=mmol/kg; has_property=Substance Concentration harmonised_unit=mol/L |
| targetTable.tsv | SUCCESS | columns match their declared types |  |  |
| targetTable.tsv | SUCCESS | concept_id, concept_code, concept_name, vocabulary_id, is_panel must have a value |  |  |
| targetTable.tsv | SUCCESS | concept_id + group_concept_id are unique |  |  |
| harmonisationTable.tsv | SUCCESS | columns match their declared types |  |  |
| harmonisationTable.tsv | SUCCESS | TEST_NAME + PREPROCESED_UNIT are unique |  |  |
| harmonisationTable.tsv | SUCCESS | has as many rows as mapping.tsv joined with unitFix.tsv |  |  |
| harmonisationTable.tsv | SUCCESS | every TEST_NAME + UNIT of mapping.tsv is kept |  |  |
| harmonisationTable.tsv | ERROR | concept_id has its attributes, unless there is an ignore_mapping_reason | 113 | e.g. b-co[ug/l] concept_id=3026470; b-co[] concept_id=3026470; b-cr[ug/l] concept_id=3025577 |
| harmonisationTable.tsv | SUCCESS | mapping_status is IGNORE, ERROR:<reason>, APPROVED or NOT-APPROVED |  |  |
| harmonisationTable.tsv | SUCCESS | mapping_status is IGNORE if and only if there is an ignore_mapping_reason |  |  |
| harmonisationTable.tsv | SUCCESS | a row with mapping_status ERROR:PropertyUnitMismatch or ERROR:SharedProperty has mapping_warning_messages |  |  |
| harmonisationTable.tsv | SUCCESS | a row with a HARMONISED_UNIT has a CONVERSION |  |  |
| harmonisationTable.tsv | ERROR | an APPROVED pair with a UNIT whose concept has a target unit has a CONVERSION to it | 140 | 55 concepts, e.g. -baso[%->%] TARGET=10*9/L; -ca12-5[u/ml->u/ml] TARGET=[arb'U]; -ca15-3[u/ml->u/ml] TARGET=[arb'U] |
| testname_unit_property_missmatch_warning.tsv | SUCCESS | columns match their declared types |  |  |
| testname_unit_property_missmatch_warning.tsv | SUCCESS | TEST_NAME, message, ignore must have a value |  |  |
| testname_unit_property_missmatch_warning.tsv | SUCCESS | TEST_NAME + UNIT are unique |  |  |
| testname_property_shared_warning.tsv | SUCCESS | columns match their declared types |  |  |
| testname_property_shared_warning.tsv | SUCCESS | TEST_NAME, message, ignore must have a value |  |  |
| testname_property_shared_warning.tsv | SUCCESS | TEST_NAME + has_property are unique |  |  |
| harmonisationTable.tsv | ERROR | has_property + UNIT is in unitHarmonisation.tsv (the concept's property agrees with the unit), for an APPROVED mapping | 73 | e.g. -baso[%]; -eos[%]; -h-ind[index] |
| harmonisationTable.tsv | WARNING | has_property + UNIT is in unitHarmonisation.tsv (the concept's property agrees with the unit), for a mapping that is not APPROVED | 264 | e.g. -calpro[mg/l]; -ebvnh[iu/ml]; -tpoab[%] |
| harmonisationTable.tsv | SUCCESS | a TEST_NAME with the same has_property maps to one concept_id, for an APPROVED mapping |  |  |
| harmonisationTable.tsv | WARNING | a TEST_NAME with the same has_property maps to one concept_id, for a mapping that is not APPROVED | 1 | e.g. a TEST_NAME with the same has_property maps to one concept_id, but has_property 'Arbitrary Concentration' maps to different concept ids: 3017895 (Helicobacter pylori Ab [Units/volume] in Serum) \| 3047387 (IgG [Units/volume] in Serum) |
