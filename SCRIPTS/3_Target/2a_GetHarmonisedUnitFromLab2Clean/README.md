# 2a_GetHarmonisedUnitFromLab2Clean

Gets the harmonised unit lab2clean gives to every OMOP concept it has, every concept in an
SI unit.

## Inputs

None from `DATA/`. The step reads:

- the FinnGen OMOP vocabulary (`concept`) through `FinnGenUtilsR`, for the LOINC
  code of each standard `Measurement` concept;
- the `loinc_reference_unit_v1` table of the `lab2clean` 2.0.0 source package,
  downloaded from CRAN (Zayed et al., *Int J Med Inform* 205 (2026) 106131).

## Outputs

In `DATA/3_Target/2a_GetHarmonisedUnitFromLab2Clean/`:

- `harmonisedUnit_lab2clean.tsv` — one row per lab2clean code that is a standard
  `Measurement` concept of the vocabulary:

| Column | Description |
|---|---|
| concept_id | OMOP concept id |
| harmonised_unit | UCUM SI unit lab2clean harmonises the concept to |

- `loincSiConventionalConversion.tsv` — lab2clean's mass-molar pairs, one row per
  conventional LOINC code with its SI partner, for the steps that remove the conventional
  concepts, move them to the Groups of their partner and convert the values:

| Column | Description |
|---|---|
| concept_id, concept_code | The conventional concept |
| conventional_unit | Its UCUM unit (mass, e.g. `ug/L`) |
| si_concept_id, si_concept_code | The SI partner concept (`mass_molar_loinc`) |
| si_unit | Its UCUM unit (molar, e.g. `nmol/L`; `mass_molar_unit`) |
| molecular_weight | g/mol, to convert between the two |

- `harmonisedGroup_lab2clean.tsv` — the LOINC Group lab2clean gives to a code (the `property_group_id`,
  `ParentGroup/Group`, without the ParentGroup): `concept_id`, `group_concept_code`. At most one per concept.
- `harmonisedUnit_lab2clean.md` — a markdown report on the table: how many concepts per
  `harmonised_unit`, with `n concepts`, `% concepts` and a total row.
- `log.txt` — run log.

## Action

`scripts/getHarmonisedUnitFromLab2Clean.R`:

1. Downloads the lab2clean source package and reads `loinc_reference_unit_v1`
   (one row per LOINC code: UCUM `reference_unit`, `unit_system`, and for the
   mass-molar pairs `mass_molar_loinc`, `mass_molar_unit`, `molecular_weight`).
2. Reads the LOINC code and concept id of every standard `Measurement` concept.
3. Sets the unit of a concept to the code's `reference_unit`, except for a
   `conventional` code, which takes the SI unit of its partner (`mass_molar_unit`).
   Every unit is thus SI.
4. Saves the Group lab2clean gives to each concept.
5. Saves the conventional-to-SI conversion table: every `conventional` code with its SI
   partner (`mass_molar_loinc`), the units, the molecular weight and the concept ids of both sides.
`scripts/summariseHarmonisedUnitFromLab2Clean.R` reads the unit table back and writes `harmonisedUnit_lab2clean.md`.

lab2clean's unit is the unit it aims for, not what the Kanta data report. Concepts it has no
unit for, or whose unit is wrong for the data, are set by hand in `2b_HarmonisedUnitOverwrite`.

## Env vars

- `FG_DATABASE_ENV` — the FinnGenUtilsR database environment (e.g. `build`),
  set in the `ENVIRONMENTS/<ENV_NAME>.env` selected by `--env`.

## How to run

Needs network access to CRAN.

```
./SCRIPTS/3_Target/2a_GetHarmonisedUnitFromLab2Clean/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
