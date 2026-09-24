# GetMeasurementOmopData

## Inputs

None from `DATA/`. This step pulls directly from the FinnGen OMOP CDM vocabulary
tables (`concept`, `concept_relationship`) via `FinnGenUtilsR`.

## Outputs

- `DATA/GetMeasurementOmopData/measurement_concept_attributes.tsv` — one row per
  standard `Measurement`-domain concept, with columns:
  - `concept_id`, `concept_code`, `concept_name`, `vocabulary_id` — the concept itself.
  - `is_panel` — `TRUE` if the concept has any outgoing `Panel contains` relationship
    (it bundles several component tests, e.g. a metabolic panel) rather than
    representing one reportable result itself.
  - `has_component` — the analyte/substance measured (e.g. Glucose, Hemoglobin).
  - `has_property` — the kind of quantity reported (e.g. Mass Concentration, Presence, Titer).
  - `has_method` — the analytical method or instrument principle (e.g. Test strip, Immunoassay).
  - `has_scale_type` — the result scale (`Qn` quantitative, `Ord` ordinal, `Nom` nominal,
    `Nar` narrative, `Doc` document).
  - `has_system` — the specimen/body system the sample was taken from (e.g. Serum or Plasma, Urine).
  - `has_time_aspect` — timing of the collection (e.g. Point in time (spot), 24 hours).

  These are LOINC's 6 core axes — the same attributes Athena
  (athena.ohdsi.org) shows on a concept's page — kept because they let
  harmonisation code check that a mapped `concept_id` really matches the
  intended analyte, specimen, and result type before accepting it into
  `LABfi.tsv`. `EXPERIMENTS/measurement_attributes/ATTRIBUTES.md` has the full
  write-up (all discovered attribute relationships, including the rarer SNOMED
  CT clinical ones, with worked examples).
- `DATA/GetMeasurementOmopData/measurement_attribute_relationships.tsv` — every
  `concept_relationship_id` type found on standard `Measurement` concepts, with a row count
  each. Diagnostic output of the discovery step; shows what was available to choose the 6
  core columns above from.
- `DATA/GetMeasurementOmopData/measurement_concept_attributes_summary.md` — a markdown
  report over `measurement_concept_attributes.tsv`: overall row/column counts, missingness
  per column, how many concepts are missing all 6 core attributes (by vocabulary), and per
  column the top 10 most used values.
- `DATA/GetMeasurementOmopData/log.txt` — run log: `run.sh`'s `tee` capturing both its own
  output and both R scripts' `ParallelLogger` console output, per `development/STYLE.md`.

## Action

`scripts/pullMeasurementConceptAttributes.R` queries the vocabulary schema for every
standard concept in the `Measurement` domain (any vocabulary except `OMOP Genomic`, whose
~205k gene-variant concepts never carry the 6 core attributes and only add noise):

1. Discovers which `concept_relationship_id` types occur on those concepts, and writes the
   full list with row counts.
2. Keeps only the 6 core LOINC attribute relationships (`Has component`, `Has method`,
   `Has property`, `Has scale type`, `Has system`, `Has time aspect`), pulls them for every
   concept, and pivots them into one column per relationship (using the *name* of the
   related concept, not its id).
3. Flags concepts with an outgoing `Panel contains` relationship as `is_panel`.
4. Joins these onto the base concept table (`concept_id`, `concept_code`, `concept_name`,
   `vocabulary_id`) and writes the result.

`scripts/summariseMeasurementConceptAttributes.R` reads that output and writes the markdown
summary described above.

This step adapts the code in `EXPERIMENTS/measurement_attributes/` (kept there as the
original prototype) to the step structure and logging conventions.

## Env vars

- `FG_DATABASE_ENV` — which FinnGenUtilsR/database environment to connect to (e.g. `build`,
  `preview`); passed to `FinnGenUtilsR::fg_getDatabaseConnector()`. Set in the
  `ENVIRONMENTS/<ENV_NAME>.env` file selected by `--env`. The same file's GCP variables
  (`GOOGLE_CLOUD_PROJECT`, `GOOGLE_APPLICATION_CREDENTIALS`, ...) are consumed internally by
  `FinnGenUtilsR` when it opens the connection.

## How to run

```
./STEPS/GetMeasurementOmopData/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
