# 3_GetLoincGroupsData

Pulls the LOINC Groups of the standard OMOP `Measurement` concepts and which
concepts are in each. Every concept keeps its own Groups, a conventional concept (the mass side of a
mass-molar pair) as well as its SI partner.

## Inputs

From `DATA/3_Target/`:

- `1_GetMeasurementOmopData/measurementOmopData.tsv` — only for the report.

Run that step first.

The step also reads:

- the FinnGen OMOP vocabulary (`concept`, `concept_ancestor`, `concept_relationship`) through `FinnGenUtilsR`.

## Outputs

In `DATA/3_Target/3_GetLoincGroupsData/`:

- `loincGroups.tsv` — one row per LOINC Group:

| Column | Description |
|---|---|
| group_concept_id | OMOP concept id of the Group |
| group_concept_code | The `LG...` code of the Group |
| group_concept_name | Name of the Group |

- `loincGroupMembership.tsv` — one row per (concept, Group): `concept_id`,
  `group_concept_id`. A concept can be in several Groups. A panel is in none.
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
     they put a mass concept and a substance concept in one Group;
   - the child Groups of the **UrineAndSed** ParentGroup (`LG97-8`): they keep only the
     component and roll up the property, so they mix counts per field (`/[HPF]`), per volume
     (`10*6/L`), mass and presence. lab2clean does not use them either.
   - the **panel Groups**: a Group whose direct children (`min_levels_of_separation` = 1) are panel
     concepts. It holds the members of the panel, tests ordered together with different properties
     (e.g. "Supersaturation panel|-|Urine": pH, osmolality, volume, 24 h rates), not the same test. The
     log lists them, says how many are not named with `|-|` as property (Groups by component with a panel
     among their children, e.g. "Hepatitis C virus"), and warns about a Group named with `|-|` that is
     kept.
3. Writes the Groups and the membership.

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
