# targetTable stats

Summary of `targetTable.tsv`: 101,924 rows, one per concept and Group, for 101,163 concepts.

# Concepts

Where the `harmonised_unit` of each concept came from (`harmonised_unit_source`).

| step | n concepts | % concepts in the table |
| --- | --- | --- |
| concepts in `measurementOmopData.tsv` | 102,825 |  |
| removed: conventional with an SI partner | 1,662 |  |
| concepts in the table | 101,163 | 100.0% |
| panel (no unit) | 2,377 | 2.3% |
| isQualitative (no unit) | 15,603 | 15.4% |
| unit from lab2clean | 31,492 | 31.1% |
| unit from the overwrite | 1 | 0.0% |
| no unit (not in lab2clean) | 51,690 | 51.1% |

# Groups

| item | n |
| --- | --- |
| Groups | 2,997 |
| concepts in a Group | 7,277 |
| concepts in no Group | 93,886 |
| concepts in more than one Group | 648 |

Where the Group of a concept came from (`group_source`): `lab2clean` when lab2clean gives the concept that Group, `LOINC` for the other memberships.

| group_source | n concept-Group rows | n Groups | n concepts |
| --- | --- | --- | --- |
| LOINC | 4,535 | 1,332 | 4,132 |
| lab2clean | 3,503 | 1,701 | 3,503 |

# Validations

| result | test | message |
| --- | --- | --- |
| SUCCESS | concept_id and Group are unique | 0 duplicated (concept_id, Group) rows |
| WARNING | concept_id is unique | 648 concepts have one row per Group (in several Groups) |
| SUCCESS | all concepts of a lab2clean Group have the same harmonised_unit | 0 of 1,701 lab2clean Groups have more than one unit |
| WARNING | all concepts of a Group (lab2clean or LOINC) have the same harmonised_unit | 179 of 2,997 Groups have more than one unit |

Groups with more than one `harmonised_unit` (units of the concepts that have one):

| group | n concepts | units |
| --- | --- | --- |
| LG50937-8 | 26 | /10*3, /10*6, 1, g/(24.h), h, mL, nmol/(24.h) |
| LG51671-2 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51679-5 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51678-7 | 2 | 10*3.[arb'U]/L, 10*3.U/L |
| LG51681-1 | 2 | [arb'U]/L, [iU]/L |
| LG50125-0 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG50130-0 | 49 | /10*6, mg/L, ug/L, umol/L |
| LG50120-1 | 14 | /10*3, mmol/(24.h), mmol/L, umol/(24.h) |
| LG50093-0 | 3 | mg/(24.h), mg/L |
| LG51600-1 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.U/L |
| LG51732-2 | 2 | [iU]/L, ug/L |
| LG51738-9 | 2 | g/L, mg/L |
| LG51739-7 | 2 | g/L, mg/L |
| LG51079-8 | 2 | /10*3, /10*6 |
| LG51080-6 | 2 | /10*3, 1 |
| LG51390-9 | 3 | mg/L, ng/L |
| LG51391-7 | 3 | mg/L, ng/L |
| LG51352-9 | 2 | /[HPF], 10*6/L |
| LG51351-1 | 2 | /[HPF], 10*6/L |
| LG51360-2 | 2 | /[HPF], 10*6/L |
| LG51361-0 | 2 | /[HPF], 10*6/L |
| LG51349-5 | 2 | /[HPF], 10*6/L |
| LG51358-6 | 2 | /[HPF], 10*6/L |
| LG51362-8 | 2 | /[HPF], 10*6/L |
| LG51350-3 | 2 | /[HPF], 10*6/L |
| LG51347-9 | 2 | /[HPF], 10*6/L |
| LG51346-1 | 2 | /[HPF], 10*6/L |
| LG51355-2 | 2 | /[HPF], 10*6/L |
| LG51356-0 | 2 | /[HPF], 10*6/L |
| LG51348-7 | 3 | /[HPF], 10*6/L |
| LG51357-8 | 2 | /[HPF], 10*6/L |
| LG51363-6 | 2 | /[HPF], 10*6/L |
| LG51354-5 | 2 | /[HPF], 10*6/L |
| LG51353-7 | 2 | /[HPF], 10*6/L |
| LG51037-6 | 2 | [iU]/L, 10*3.[arb'U]/L |
| LG51032-7 | 2 | [arb'U]/L, 10*3.[arb'U]/L |
| LG51063-2 | 3 | [arb'U]/L, 10*3.[arb'U]/L, 10*3.[iU]/L |
| LG51052-5 | 21 | /10*6, ug/(24.h), ug/L |
| LG51055-8 | 7 | /10*6, h, mg/(24.h), mg/L, mL, ug/L |
| LG51054-1 | 2 | mg/L, ug/L |
| LG51053-3 | 3 | /[HPF], 1, 10*6/L |
| LG50984-0 | 20 | /10*6, ug/(24.h) |
| LG51435-2 | 6 | /10*6, h, mL, ug/(24.h) |
| LG51472-5 | 2 | mmol/L, umol/L |
| LG51450-1 | 20 | /10*3, 1, g/(24.h), g/L, h, mg/(24.h), mg/L, mL |
| LG51466-7 | 44 | [pH], /10*3, /10*6, /10*9, g/(24.h), h, kJ/mol, mg/(24.h), mL, mmol/(24.h), mmol/kg, mmol/L, ug/(24.h), umol/(24.h), umol/L |
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
| LG32754-0 | 2 | 1, U/L |
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
| LG34933-8 | 7 | mmol/L, umol/L |
| LG37282-7 | 6 | /10*3, /10*6, mmol/L, umol/L |
| LG35440-3 | 2 | /10*3, /10*6 |
| LG35257-1 | 3 | mg/L, ug/L |
| LG35255-5 | 6 | mmol/(24.h), mmol/L |
| LG35513-7 | 3 | [iU]/L, 10*3.[arb'U]/L |
| LG34684-7 | 3 | g/L, mg/L |
| LG35785-1 | 18 | %, g/(24.h), g/L, h, mg/L, mL |
| LG36305-7 | 8 | 1, g/(24.h), mg/(24.h), mg/L, mL |
| LG36185-3 | 2 | /10*3, /10*6 |
| LG35461-9 | 2 | mmol/L, umol/L |
| LG34882-7 | 4 | [iU]/L, 10*3.[iU]/L |
| LG36059-0 | 2 | /10*3, 1 |
| LG37118-3 | 11 | /10*3, /10*6, mmol/(24.h), umol/(24.h), umol/L |
| LG37123-3 | 11 | /10*3, /10*6, umol/(24.h), umol/L |
| LG36111-9 | 7 | /10*3, g/(24.h), h, mg/(24.h), mg/L, mL |
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
| LG37570-5 | 2 | mg/L, ug/L |
| LG40874-6 | 2 | /[HPF], /[LPF] |
| LG40875-3 | 5 | /[HPF], 10*6/L |
| LG40876-1 | 2 | /[HPF], /[LPF] |
| LG40895-1 | 4 | /[LPF], 10*6/L |
| LG40877-9 | 4 | /[HPF], /[LPF], 10*6/L |
| LG40878-7 | 6 | /[HPF], /[LPF], 10*6/L |
| LG40879-5 | 4 | /[HPF], /[LPF], 10*6/L |
| LG40928-0 | 2 | /[HPF], 10*6/L |
| LG40873-8 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40881-1 | 4 | /[HPF], /[LPF], 10*6/L |
| LG40930-6 | 2 | /[HPF], 10*6/L |
| LG40959-5 | 4 | /[HPF], 10*6/L |
| LG40882-9 | 2 | /[HPF], /[LPF] |
| LG40926-4 | 4 | /[HPF], 10*6/L |
| LG40883-7 | 4 | /[HPF], /[LPF], 10*6/L |
| LG40885-2 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40929-8 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40860-5 | 6 | /[HPF], /[LPF], 10*3/L, 10*6/L |
| LG40856-3 | 7 | /[HPF], /[LPF], 10*3/L, 10*6/L |
| LG40869-6 | 7 | /[HPF], /[LPF], 10*6/L |
| LG40900-9 | 6 | /[HPF], /[LPF], /uL, 10*6/L |
| LG40961-1 | 4 | /[HPF], 10*6/L |
| LG40971-0 | 3 | /[HPF], 10*6/L |
| LG40868-8 | 12 | /[HPF], /min, 10*12/L, 10*3/L, 10*6/L |
| LG40960-3 | 3 | /[HPF], 10*6/L |
| LG40887-8 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40897-7 | 4 | /[HPF], /[LPF] |
| LG40898-5 | 4 | /[HPF], /[LPF] |
| LG40888-6 | 7 | /[HPF], /[LPF], /uL, 10*6/L |
| LG40889-4 | 2 | /[HPF], /[LPF] |
| LG40890-2 | 8 | /[HPF], /[LPF], 10*6/L |
| LG40908-2 | 5 | mg/L, mmol/L |
| LG40891-0 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40899-3 | 6 | /[HPF], /[LPF], /uL, 10*6/L |
| LG40917-3 | 5 | /[HPF], 10*6/L |
| LG40867-0 | 12 | /(24.h), /[HPF], /[LPF], /min, 10*6/L, 10*9/L |
| LG40922-3 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40937-1 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40886-0 | 4 | /[HPF], 10*6/L |
| LG40964-5 | 2 | /[HPF], 10*6/L |
| LG40861-3 | 5 | /[HPF], /[LPF], 10*3/L, 10*6/L |
| LG40870-4 | 7 | 10*3.[arb'U]/L, g, g/(24.h), mg/L |
| LG40914-0 | 2 | /[HPF], /[LPF] |
| LG40896-9 | 2 | 10*3.[arb'U]/L, mg/L |
| LG40916-5 | 2 | /[HPF], /[LPF] |
| LG40902-5 | 3 | /[HPF], 10*6/L |
| LG40904-1 | 2 | /[HPF], /[LPF] |
| LG40894-4 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40920-7 | 4 | /[HPF], /[LPF], 10*6/L |
| LG40905-8 | 6 | /[HPF], /[LPF], 10*6/L |
| LG40915-7 | 5 | /[HPF], /[LPF], 10*6/L |
| LG40862-1 | 5 | /[HPF], /[LPF], 10*3/L, 10*6/L |
| LG40903-3 | 6 | /[HPF], /[LPF], 10*6/L |
| LG40864-7 | 3 | [EU]/L, umol/L |
| LG40901-7 | 6 | /[HPF], /[LPF], 10*3/L, 10*6/L |
| LG40927-2 | 3 | /[HPF], 10*6/L |
| LG40923-1 | 2 | /[HPF], 10*6/L |
| LG40933-0 | 5 | /[HPF], /[LPF], 10*6/L |
| LG41057-7 | 2 | mg/L, mm |
