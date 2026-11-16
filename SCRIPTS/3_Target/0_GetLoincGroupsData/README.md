# 0_GetLoincGroupsData

Pulls the LOINC Groups of the standard OMOP `Measurement` concepts, SI units
only, and gives each Group its harmonised unit from lab2clean. It also saves the
conventional-to-SI conversion table of lab2clean.

## Inputs

From `DATA/3_Target/`, only for the report: `0_GetMeasurementOmopData/measurementOmopData.tsv`
(run that step first). The step also reads:

- the FinnGen OMOP vocabulary (`concept`, `concept_ancestor`) through
  `FinnGenUtilsR`;
- the `loinc_reference_unit_v1` table of the `lab2clean` 2.0.0 source package,
  downloaded from CRAN (Zayed et al., *Int J Med Inform* 205 (2026) 106131).

## Outputs

In `DATA/3_Target/0_GetLoincGroupsData/`:

- `loincGroups.tsv` — one row per LOINC Group:

| Column | Description |
|---|---|
| group_concept_id | OMOP concept id of the Group |
| group_concept_code | The `LG...` code of the Group |
| group_concept_name | Name of the Group |
| group_harmonised_unit | UCUM SI unit every concept of the Group is harmonised to; empty when lab2clean has no unit for the Group |

- `loincGroupMembership.tsv` — one row per (concept, Group): `concept_id`,
  `group_concept_id`. A concept can be in several Groups. A panel is in none, and a
  conventional concept is listed under the Groups of its SI partner (see Action).
- `loincSiConventionalConversion.tsv` — lab2clean's mass-molar pairs, one row per
  conventional LOINC code with its SI partner, for the step that converts the values:

| Column | Description |
|---|---|
| concept_id, concept_code | The conventional concept |
| conventional_unit | Its UCUM unit (mass, e.g. `ug/L`) |
| si_concept_id, si_concept_code | The SI partner concept (`mass_molar_loinc`) |
| si_unit | Its UCUM unit (molar, e.g. `nmol/L`; `mass_molar_unit`) |
| molecular_weight | g/mol, to convert between the two |
- `loincGroups.md` — a markdown report on the Groups: how many Groups there are,
  how many have and have no harmonised unit, and a table per `has_property`
  with `n groups`, `% groups`, `n also PS` and `n with no unit`. The property of a
  Group is the `has_property` of its concepts (from `measurementOmopData.tsv`)
  leaving out the conventional concepts mapped from their SI partner (they are
  converted, not a property of their own) and `Presence or Threshold`,
  `(several)` when the rest differ and
  `(none)` when none has one; `n also PS` counts the Groups that also hold
  `Presence or Threshold` concepts next to that property; the Group name is not used,
  because some names leave the property out.
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
     they put a mass concept and a substance concept in one Group, mixing the
     two unit systems.
3. Downloads the lab2clean source package and reads `loinc_reference_unit_v1`.
   lab2clean's `property_group_id` is `<ParentGroupId>/<GroupId>`; the `GroupId`
   is the Group's `LG` code. lab2clean chooses its `reference_unit` per Group,
   so every code of a Group and unit system has the same unit.
4. Keeps the Groups SI only. A concept whose lab2clean `unit_system` is
   `conventional` (the mass side of a mass-molar pair) is moved to the Groups of
   its SI partner (`mass_molar_loinc`), replacing its own; one whose partner is
   in no Group is in no Group. The conventional-to-SI table is written as
   `loincSiConventionalConversion.tsv`.
5. Sets `group_harmonised_unit` to the SI `reference_unit` of the Group's codes.
   A Group lab2clean does not have gets no unit.

## Env vars

- `FG_DATABASE_ENV` — the FinnGenUtilsR database environment (e.g. `build`),
  set in the `ENVIRONMENTS/<ENV_NAME>.env` selected by `--env`.

## How to run

Needs network access to CRAN.

```
./SCRIPTS/3_Target/0_GetLoincGroupsData/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
