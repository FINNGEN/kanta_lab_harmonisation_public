# 3_GetLoincGroupsData

Pulls the LOINC Groups of the standard OMOP `Measurement` concepts and which
concepts are in each, SI only: a conventional concept is put in the Groups of its
SI partner. 

## Inputs

From `DATA/3_Target/`:

- `2a_GetHarmonisedUnitFromLab2Clean/loincSiConventionalConversion.tsv` — the conventional
  concepts and their SI partner, to give the conventional concepts the Groups of their partner.
- `1_GetMeasurementOmopData/measurementOmopData.tsv` — only for the report.

Run those steps first.

The step also reads:

- the FinnGen OMOP vocabulary (`concept`, `concept_ancestor`) through `FinnGenUtilsR`.

## Outputs

In `DATA/3_Target/3_GetLoincGroupsData/`:

- `loincGroups.tsv` — one row per LOINC Group:

| Column | Description |
|---|---|
| group_concept_id | OMOP concept id of the Group |
| group_concept_code | The `LG...` code of the Group |
| group_concept_name | Name of the Group |

- `loincGroupMembership.tsv` — one row per (concept, Group): `concept_id`,
  `group_concept_id`. A concept can be in several Groups. A panel is in none, and a
  conventional concept is listed under the Groups of its SI partner (see Action).
- `log.txt` — run log.

## Action

`scripts/getLoincGroupsData.R`:

1. Queries every `LOINC Group` ancestor (`concept_ancestor`) of the standard
   `Measurement` concepts, and flags the ParentGroups (a Group that subsumes
   other Groups: a grouping rule, not a set of equivalent tests).
2. Keeps the concepts that are in a Group whose name starts with `Flowsheet`
   (lab tests, vital signs, weight and height), and for those concepts all the
   Groups that are not ParentGroups. Two concepts are the same test when they
   share a Group; no precedence rule is needed. It leaves out:
   - **panels** (a concept with a `Panel contains` relationship): in no Group;
   - the child Groups of the **Mass-Molar conversion** ParentGroup (`LG55-6`):
     they put a mass concept and a substance concept in one Group.
3. Keeps the Groups SI only. A concept in the conversion table is moved to the Groups
   of its SI partner, replacing its own; one whose partner is in no Group is in no Group.
4. Writes the Groups and the membership.

`scripts/summariseLoincGroupsData.R` reads the two tables back and the measurement
table, and writes `loincGroups.md`.

## Env vars

- `FG_DATABASE_ENV` — the FinnGenUtilsR database environment (e.g. `build`),
  set in the `ENVIRONMENTS/<ENV_NAME>.env` selected by `--env`.

## How to run

Needs network access to CRAN.

```
./SCRIPTS/3_Target/3_GetLoincGroupsData/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
