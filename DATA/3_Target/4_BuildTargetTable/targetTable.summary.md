# targetTable stats

Summary of `targetTable.tsv`: 103,541 rows, one per concept and Group, for 102,825 concepts.

# Concepts

Where the `harmonised_unit` of each concept came from (`harmonised_unit_source`).

| step | n concepts | % concepts in the table |
| --- | --- | --- |
| concepts in `measurementOmopData.tsv` | 102,825 |  |
| concepts in the table | 102,825 | 100.0% |
| panel (no unit) | 2,377 | 2.3% |
| isQualitative (no unit) | 15,603 | 15.2% |
| unit from lab2clean | 33,154 | 32.2% |
| no unit (not in lab2clean) | 51,691 | 50.3% |

# Groups

| item | n |
| --- | --- |
| Groups | 3,025 |
| concepts in a Group | 7,231 |
| concepts in no Group | 95,594 |
| concepts in more than one Group | 596 |

Where the Group of a concept came from (`group_source`): `lab2clean` when lab2clean gives the concept that Group, `LOINC` for the other memberships.

| group_source | n concept-Group rows | n Groups | n concepts |
| --- | --- | --- | --- |
| LOINC | 4,066 | 1,245 | 3,698 |
| lab2clean | 3,881 | 1,823 | 3,881 |

# Validations

| result | test | message |
| --- | --- | --- |
| SUCCESS | concept_id and Group are unique | 0 duplicated (concept_id, Group) rows |
| WARNING | concept_id is unique | 596 concepts have one row per Group (in several Groups) |
| SUCCESS | all concepts of a lab2clean Group have the same harmonised_unit | 0 of 1,823 lab2clean Groups have more than one unit |
| WARNING | all concepts of a Group (lab2clean or LOINC) have the same harmonised_unit | 103 of 3,025 Groups have more than one unit |

Groups with more than one `harmonised_unit` (units of the concepts that have one):

| group | n concepts | units |
| --- | --- | --- |
| LG50937-8 | 27 | /10*3, /10*6, 1, g/(24.h), h, mg/L, mL, nmol/(24.h) |
| LG51671-2 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51679-5 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51678-7 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51681-1 | 2 | [arb'U]/L, [iU]/L |
| LG50125-0 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG50130-0 | 51 | /10*6, mg/L, ug/L, umol/L |
| LG50120-1 | 14 | /10*3, mmol/(24.h), mmol/L, umol/(24.h) |
| LG51600-1 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.U/L |
| LG51732-2 | 2 | [iU]/L, ug/L |
| LG51738-9 | 2 | g/L, mg/L |
| LG51739-7 | 2 | g/L, mg/L |
| LG51079-8 | 2 | /10*3, /10*6 |
| LG51080-6 | 2 | /10*3, 1 |
| LG51390-9 | 3 | mg/L, ng/L |
| LG51391-7 | 3 | mg/L, ng/L |
| LG51037-6 | 2 | [iU]/L, 10*3.[arb'U]/L |
| LG51032-7 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG51063-2 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.[iU]/L |
| LG51052-5 | 23 | /10*6, ug/(24.h), ug/L |
| LG51055-8 | 9 | /10*6, h, mg/(24.h), mg/L, mL, ug/L |
| LG51054-1 | 2 | mg/L, ug/L |
| LG50984-0 | 26 | /10*6, ug/(24.h), ug/L |
| LG51435-2 | 6 | /10*6, h, mL, ug/(24.h) |
| LG51472-5 | 2 | mmol/L, umol/L |
| LG51450-1 | 21 | /10*3, 1, g/(24.h), g/L, h, mg/(24.h), mg/L, mL |
| LG51466-7 | 54 | [pH], /10*3, /10*6, /10*9, g/(24.h), h, kJ/mol, mg/(24.h), mg/L, mL, mmol/(24.h), mmol/kg, mmol/L, ug/(24.h), umol/(24.h), umol/L |
| LG27509-5 | 2 | 10*3.[iU]/L, 10*6.[iU]/L |
| LG14125-5 | 2 | mg/L, ug/L |
| LG5680-6 | 2 | 10*3.U/L, U/L |
| LG2364-0 | 2 | %, 1 |
| LG5669-9 | 2 | U/L, umol/h/L |
| LG6138-4 | 2 | mg/L, ug/L |
| LG9023-5 | 2 | nmol/L, umol/L |
| LG13820-2 | 2 | mg/L, ug/L |
| LG3200-5 | 2 | nmol/L, umol/L |
| LG10543-3 | 2 | [iU]/L, 10*3.[arb'U]/L |
| LG24468-7 | 2 | mmol/L, umol/L |
| LG12480-6 | 2 | %, 10*3.[arb'U]/L |
| LG14767-4 | 6 | mmol/L, nmol/L |
| LG11276-9 | 2 | [iU]/L, 10*3.[iU]/L |
| LG10964-1 | 2 | /[HPF], /[LPF] |
| LG14187-5 | 2 | nmol/L, umol/L |
| LG13706-3 | 2 | mg/L, ug/L |
| LG5571-7 | 2 | 1, 10*3.[arb'U]/L |
| LG2967-0 | 3 | nmol/L, umol/L |
| LG29228-0 | 2 | nmol/L, umol/L |
| LG32754-0 | 3 | 1, mg/L, U/L |
| LG32976-9 | 2 | 10*6/L, 10*9/L |
| LG33002-3 | 2 | 10*6/L, 10*9/L |
| LG32875-3 | 2 | 10*12/L, 10*6/L |
| LG32990-0 | 2 | 10*6/L, 10*9/L |
| LG32978-5 | 2 | 10*6/L, 10*9/L |
| LG32980-1 | 2 | 10*6/L, 10*9/L |
| LG32903-3 | 2 | 10*6/L, 10*9/L |
| LG32833-2 | 2 | 10*6/L, 10*9/L |
| LG32988-4 | 2 | 10*6/L, 10*9/L |
| LG33047-8 | 2 | 10*6/L, 10*9/L |
| LG32820-9 | 2 | 10*6/L, 10*9/L |
| LG32815-9 | 2 | 10*6/L, 10*9/L |
| LG32819-1 | 2 | 10*6/L, 10*9/L |
| LG32810-0 | 2 | 10*3/L, 10*9/L |
| LG35535-0 | 2 | nmol/L, umol/L |
| LG36509-4 | 2 | /10*3, /10*6 |
| LG35538-4 | 2 | nmol/L, umol/L |
| LG35054-2 | 5 | g/L, mg/L |
| LG35244-9 | 4 | g/L, mg/L |
| LG35743-0 | 2 | /10*3, /10*6 |
| LG34859-5 | 2 | nmol/L, umol/L |
| LG35429-6 | 2 | mmol/L, nmol/L |
| LG36540-9 | 2 | ng/L, ug/L |
| LG35809-9 | 2 | /10*3, /10*6 |
| LG35176-3 | 3 | mg/L, ug/L |
| LG34933-8 | 7 | mmol/L, umol/L |
| LG37282-7 | 6 | /10*3, /10*6, mmol/L, umol/L |
| LG35440-3 | 2 | /10*3, /10*6 |
| LG35257-1 | 4 | mg/L, ug/L |
| LG35255-5 | 6 | mmol/(24.h), mmol/L |
| LG35513-7 | 3 | [iU]/L, 10*3.[arb'U]/L |
| LG34684-7 | 3 | g/L, mg/L |
| LG35785-1 | 18 | %, g/(24.h), g/L, h, mg/L, mL |
| LG36305-7 | 8 | 1, g/(24.h), mg/(24.h), mg/L, mL |
| LG36185-3 | 2 | /10*3, /10*6 |
| LG35461-9 | 2 | mmol/L, umol/L |
| LG34882-7 | 4 | [iU]/L, 10*3.[iU]/L |
| LG36059-0 | 2 | /10*3, 1 |
| LG37118-3 | 12 | /10*3, /10*6, mg/L, mmol/(24.h), umol/(24.h), umol/L |
| LG37123-3 | 12 | /10*3, /10*6, mg/L, umol/(24.h), umol/L |
| LG36111-9 | 8 | /10*3, g/(24.h), h, mg/(24.h), mg/L, mL |
| LG36189-5 | 2 | /10*3, /10*6 |
| LG36192-9 | 2 | /10*3, /10*6 |
| LG35882-6 | 3 | g/(24.h), mg/(24.h) |
| LG34832-2 | 2 | nmol/L, umol/L |
| LG36112-7 | 27 | %, g/(24.h), g/L, h, mg/(24.h), mg/L, mL |
| LG36067-3 | 4 | g/L, mg/L |
| LG36066-5 | 4 | g/L, mg/L |
| LG37310-6 | 100 | /10*3, /10*6, 1, g/mol, nmol/(24.h), nmol/L, umol/(24.h), umol/L |
| LG34834-8 | 2 | nmol/L, umol/L |
| LG35998-0 | 2 | mmol/L, umol/L |
| LG35480-9 | 2 | /10*3, 1 |
| LG37542-4 | 9 | g/L, mg/L |
| LG37570-5 | 3 | mg/L, ug/L |
| LG41057-7 | 2 | mg/L, mm |
