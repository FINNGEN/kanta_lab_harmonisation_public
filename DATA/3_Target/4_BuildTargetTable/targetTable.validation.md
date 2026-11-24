# targetTable validation

Validation of the tables of `3_Target`: the inputs of `4_BuildTargetTable` and `targetTable.tsv`. 
The step stops when a test is an ERROR.

## Validation summary

| table | SUCCESS | WARNING | ERROR |
| --- | --- | --- | --- |
| measurementOmopData.tsv | 7 | 0 | 0 |
| harmonisedUnit_lab2clean.tsv | 5 | 0 | 0 |
| harmonisedGroup_lab2clean.tsv | 6 | 0 | 0 |
| loincGroups.tsv | 7 | 0 | 0 |
| loincGroupMembership.tsv | 7 | 0 | 0 |
| targetTable.tsv | 2 | 2 | 0 |
| ALL | 34 | 2 | 0 |

## Tests

| table | result | test | n rows | message |
| --- | --- | --- | ---: | --- |
| measurementOmopData.tsv | SUCCESS | has the columns concept_id, concept_code, concept_name, vocabulary_id, is_panel, has_property |  |  |
| measurementOmopData.tsv | SUCCESS | concept_id has a value |  |  |
| measurementOmopData.tsv | SUCCESS | concept_code has a value |  |  |
| measurementOmopData.tsv | SUCCESS | concept_name has a value |  |  |
| measurementOmopData.tsv | SUCCESS | vocabulary_id has a value |  |  |
| measurementOmopData.tsv | SUCCESS | concept_id are unique |  |  |
| measurementOmopData.tsv | SUCCESS | is_panel is TRUE or FALSE |  |  |
| harmonisedUnit_lab2clean.tsv | SUCCESS | has the columns concept_id, harmonised_unit |  |  |
| harmonisedUnit_lab2clean.tsv | SUCCESS | concept_id has a value |  |  |
| harmonisedUnit_lab2clean.tsv | SUCCESS | harmonised_unit has a value |  |  |
| harmonisedUnit_lab2clean.tsv | SUCCESS | concept_id are unique |  |  |
| harmonisedUnit_lab2clean.tsv | SUCCESS | concept_id is in measurementOmopData.tsv |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | has the columns concept_id, group_concept_code |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | concept_id has a value |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | group_concept_code has a value |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | concept_id are unique |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | concept_id is in measurementOmopData.tsv |  |  |
| harmonisedGroup_lab2clean.tsv | SUCCESS | every concept + Group is a membership of loincGroupMembership.tsv |  |  |
| loincGroups.tsv | SUCCESS | has the columns group_concept_id, group_concept_code, group_concept_name |  |  |
| loincGroups.tsv | SUCCESS | group_concept_id has a value |  |  |
| loincGroups.tsv | SUCCESS | group_concept_code has a value |  |  |
| loincGroups.tsv | SUCCESS | group_concept_name has a value |  |  |
| loincGroups.tsv | SUCCESS | group_concept_id are unique |  |  |
| loincGroups.tsv | SUCCESS | group_concept_code are unique |  |  |
| loincGroups.tsv | SUCCESS | every Group has a member in loincGroupMembership.tsv |  |  |
| loincGroupMembership.tsv | SUCCESS | has the columns concept_id, group_concept_id |  |  |
| loincGroupMembership.tsv | SUCCESS | concept_id has a value |  |  |
| loincGroupMembership.tsv | SUCCESS | group_concept_id has a value |  |  |
| loincGroupMembership.tsv | SUCCESS | concept_id + group_concept_id are unique |  |  |
| loincGroupMembership.tsv | SUCCESS | group_concept_id is in loincGroups.tsv |  |  |
| loincGroupMembership.tsv | SUCCESS | concept_id is in measurementOmopData.tsv |  |  |
| loincGroupMembership.tsv | SUCCESS | a panel is in no Group |  |  |
| targetTable.tsv | SUCCESS | concept_id + group_concept_id are unique |  |  |
| targetTable.tsv | WARNING | concept_id is unique (a concept in several Groups has one row per Group) | 1,312 | 596 concepts in several Groups |
| targetTable.tsv | SUCCESS | all concepts of a lab2clean Group have the same harmonised_unit |  |  |
| targetTable.tsv | WARNING | all concepts of a Group (lab2clean or LOINC) have the same harmonised_unit | 103 | e.g. group_concept_code=LG50937-8 units=/10*3, /10*6, 1, g/(24.h), h, mg/L, mL, nmol/(24.h); group_concept_code=LG51732-2 units=[iU]/L, ug/L; group_concept_code=LG51466-7 units=[pH], /10*3, /10*6, /10*9, g/(24.h), h, kJ/mol, mg/(24.h), mg/L, mL, mmol/(24.h), mmol/kg, mmol/L, ug/(24.h), umol/(24.h), umol/L |

## Groups with more than one harmonised_unit

| group | n concepts | units |
| --- | --- | --- |
| LG10543-3 | 2 | [iU]/L, 10*3.[arb'U]/L |
| LG10964-1 | 2 | /[HPF], /[LPF] |
| LG11276-9 | 2 | [iU]/L, 10*3.[iU]/L |
| LG12480-6 | 2 | %, 10*3.[arb'U]/L |
| LG13706-3 | 2 | mg/L, ug/L |
| LG13820-2 | 2 | mg/L, ug/L |
| LG14125-5 | 2 | mg/L, ug/L |
| LG14187-5 | 2 | nmol/L, umol/L |
| LG14767-4 | 6 | mmol/L, nmol/L |
| LG2364-0 | 2 | %, 1 |
| LG24468-7 | 2 | mmol/L, umol/L |
| LG27509-5 | 2 | 10*3.[iU]/L, 10*6.[iU]/L |
| LG29228-0 | 2 | nmol/L, umol/L |
| LG2967-0 | 3 | nmol/L, umol/L |
| LG3200-5 | 2 | nmol/L, umol/L |
| LG32754-0 | 3 | 1, mg/L, U/L |
| LG32810-0 | 2 | 10*3/L, 10*9/L |
| LG32815-9 | 2 | 10*6/L, 10*9/L |
| LG32819-1 | 2 | 10*6/L, 10*9/L |
| LG32820-9 | 2 | 10*6/L, 10*9/L |
| LG32833-2 | 2 | 10*6/L, 10*9/L |
| LG32875-3 | 2 | 10*12/L, 10*6/L |
| LG32903-3 | 2 | 10*6/L, 10*9/L |
| LG32976-9 | 2 | 10*6/L, 10*9/L |
| LG32978-5 | 2 | 10*6/L, 10*9/L |
| LG32980-1 | 2 | 10*6/L, 10*9/L |
| LG32988-4 | 2 | 10*6/L, 10*9/L |
| LG32990-0 | 2 | 10*6/L, 10*9/L |
| LG33002-3 | 2 | 10*6/L, 10*9/L |
| LG33047-8 | 2 | 10*6/L, 10*9/L |
| LG34684-7 | 3 | g/L, mg/L |
| LG34832-2 | 2 | nmol/L, umol/L |
| LG34834-8 | 2 | nmol/L, umol/L |
| LG34859-5 | 2 | nmol/L, umol/L |
| LG34882-7 | 4 | [iU]/L, 10*3.[iU]/L |
| LG34933-8 | 7 | mmol/L, umol/L |
| LG35054-2 | 5 | g/L, mg/L |
| LG35176-3 | 3 | mg/L, ug/L |
| LG35244-9 | 4 | g/L, mg/L |
| LG35255-5 | 6 | mmol/(24.h), mmol/L |
| LG35257-1 | 4 | mg/L, ug/L |
| LG35429-6 | 2 | mmol/L, nmol/L |
| LG35440-3 | 2 | /10*3, /10*6 |
| LG35461-9 | 2 | mmol/L, umol/L |
| LG35480-9 | 2 | /10*3, 1 |
| LG35513-7 | 3 | [iU]/L, 10*3.[arb'U]/L |
| LG35535-0 | 2 | nmol/L, umol/L |
| LG35538-4 | 2 | nmol/L, umol/L |
| LG35743-0 | 2 | /10*3, /10*6 |
| LG35785-1 | 18 | %, g/(24.h), g/L, h, mg/L, mL |
| LG35809-9 | 2 | /10*3, /10*6 |
| LG35882-6 | 3 | g/(24.h), mg/(24.h) |
| LG35998-0 | 2 | mmol/L, umol/L |
| LG36059-0 | 2 | /10*3, 1 |
| LG36066-5 | 4 | g/L, mg/L |
| LG36067-3 | 4 | g/L, mg/L |
| LG36111-9 | 8 | /10*3, g/(24.h), h, mg/(24.h), mg/L, mL |
| LG36112-7 | 27 | %, g/(24.h), g/L, h, mg/(24.h), mg/L, mL |
| LG36185-3 | 2 | /10*3, /10*6 |
| LG36189-5 | 2 | /10*3, /10*6 |
| LG36192-9 | 2 | /10*3, /10*6 |
| LG36305-7 | 8 | 1, g/(24.h), mg/(24.h), mg/L, mL |
| LG36509-4 | 2 | /10*3, /10*6 |
| LG36540-9 | 2 | ng/L, ug/L |
| LG37118-3 | 12 | /10*3, /10*6, mg/L, mmol/(24.h), umol/(24.h), umol/L |
| LG37123-3 | 12 | /10*3, /10*6, mg/L, umol/(24.h), umol/L |
| LG37282-7 | 6 | /10*3, /10*6, mmol/L, umol/L |
| LG37310-6 | 100 | /10*3, /10*6, 1, g/mol, nmol/(24.h), nmol/L, umol/(24.h), umol/L |
| LG37542-4 | 9 | g/L, mg/L |
| LG37570-5 | 3 | mg/L, ug/L |
| LG41057-7 | 2 | mg/L, mm |
| LG50120-1 | 14 | /10*3, mmol/(24.h), mmol/L, umol/(24.h) |
| LG50125-0 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG50130-0 | 51 | /10*6, mg/L, ug/L, umol/L |
| LG50937-8 | 27 | /10*3, /10*6, 1, g/(24.h), h, mg/L, mL, nmol/(24.h) |
| LG50984-0 | 26 | /10*6, ug/(24.h), ug/L |
| LG51032-7 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG51037-6 | 2 | [iU]/L, 10*3.[arb'U]/L |
| LG51052-5 | 23 | /10*6, ug/(24.h), ug/L |
| LG51054-1 | 2 | mg/L, ug/L |
| LG51055-8 | 9 | /10*6, h, mg/(24.h), mg/L, mL, ug/L |
| LG51063-2 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.[iU]/L |
| LG51079-8 | 2 | /10*3, /10*6 |
| LG51080-6 | 2 | /10*3, 1 |
| LG51390-9 | 3 | mg/L, ng/L |
| LG51391-7 | 3 | mg/L, ng/L |
| LG51435-2 | 6 | /10*6, h, mL, ug/(24.h) |
| LG51450-1 | 21 | /10*3, 1, g/(24.h), g/L, h, mg/(24.h), mg/L, mL |
| LG51466-7 | 54 | [pH], /10*3, /10*6, /10*9, g/(24.h), h, kJ/mol, mg/(24.h), mg/L, mL, mmol/(24.h), mmol/kg, mmol/L, ug/(24.h), umol/(24.h), umol/L |
| LG51472-5 | 2 | mmol/L, umol/L |
| LG51600-1 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.U/L |
| LG51671-2 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51678-7 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51679-5 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51681-1 | 2 | [arb'U]/L, [iU]/L |
| LG51732-2 | 2 | [iU]/L, ug/L |
| LG51738-9 | 2 | g/L, mg/L |
| LG51739-7 | 2 | g/L, mg/L |
| LG5571-7 | 2 | 1, 10*3.[arb'U]/L |
| LG5669-9 | 2 | U/L, umol/h/L |
| LG5680-6 | 2 | 10*3.U/L, U/L |
| LG6138-4 | 2 | mg/L, ug/L |
| LG9023-5 | 2 | nmol/L, umol/L |
