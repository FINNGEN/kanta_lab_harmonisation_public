# 0_GetMeasurementOmopData

Pulls every standard OMOP `Measurement`-domain concept with its six LOINC axes
and whether it is a panel, straight from the FinnGen OMOP CDM.

## Inputs

None from `DATA/`. The step queries the FinnGen OMOP vocabulary tables
(`concept`, `concept_relationship`) through `FinnGenUtilsR`.

## Outputs

In `DATA/3_Target/0_GetMeasurementOmopData/`:

- `measurementOmopData.tsv` — one row per standard `Measurement`-domain concept:

| Column | Description |
|---|---|
| concept_id | OMOP concept id |
| concept_code | Concept code in its vocabulary |
| concept_name | Concept name |
| vocabulary_id | Vocabulary of the concept (e.g. `LOINC`, `SNOMED`) |
| is_panel | `TRUE` if the concept has an outgoing `Panel contains` relationship |
| has_component | Analyte or substance measured |
| has_property | Kind of quantity reported |
| has_method | Analytical method |
| has_scale_type | Result scale (`Qn`, `Ord`, `Nom`, `Nar`, `Doc`) |
| has_system | Specimen or body system |
| has_time_aspect | Timing of the collection |

  The six `has_*` columns are LOINC's core axes, the attributes Athena shows on a
  concept's page; empty when the concept has none.
- `measurementOmopData.md` — a markdown report on the table: how many concepts
  per `vocabulary_id`, per `is_panel` value and per `has_property` value (most
  frequent first, `(none)` for a missing value), with `n concepts`,
  `% concepts` and a total row.
- `log.txt` — run log.

## Action

`scripts/getMeasurementOmopData.R` queries every standard concept in the
`Measurement` domain (any vocabulary except `OMOP Genomic`, whose gene-variant
concepts never carry the six axes):

1. Pulls the six `Has ...` relationships and pivots them into one column each,
   using the *name* of the related concept.
2. Flags the concepts with a `Panel contains` relationship as `is_panel`.
3. Joins both onto the concept table and writes it.

`scripts/summariseMeasurementOmopData.R` reads `measurementOmopData.tsv` back
and writes `measurementOmopData.md`.

## Env vars

- `FG_DATABASE_ENV` — the FinnGenUtilsR database environment (e.g. `build`),
  set in the `ENVIRONMENTS/<ENV_NAME>.env` selected by `--env`.

## How to run

```
./SCRIPTS/3_Target/0_GetMeasurementOmopData/run.sh <PATH_TO_DATA> --env <ENV_NAME>
```
