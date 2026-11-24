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

