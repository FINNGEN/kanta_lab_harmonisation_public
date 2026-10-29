# 0_GetMeasurementOmopData

Pulls the OMOP reference data the rest of the pipeline checks its mappings
against: every standard `Measurement`-domain concept's LOINC axes
(component, property, method, scale type, system, time aspect) and whether
it is a panel. Independent of every other step, which is why it runs first.

## Inputs

None from `DATA/`. This step pulls directly from the FinnGen OMOP CDM vocabulary
tables (`concept`, `concept_relationship`) via `FinnGenUtilsR`.

## Outputs

- `DATA/0_GetMeasurementOmopData/measurement_concept_attributes.tsv` — one row per
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
- `DATA/0_GetMeasurementOmopData/measurement_attribute_relationships.tsv` — every
  `concept_relationship_id` type found on standard `Measurement` concepts, with a row count
  each. Diagnostic output of the discovery step; shows what was available to choose the 6
  core columns above from.
- `DATA/0_GetMeasurementOmopData/loinc_group_membership.tsv` — one row per (standard
  Measurement concept, LOINC Group it belongs to), with `concept_id`,
  `group_concept_id`, `group_concept_code` (the `LG...` code), `group_concept_name`,
  `n_descendants` (how many standard Measurement concepts the Group holds) and
  `is_parent_group`. A concept belongs to several Groups, so this is deliberately
  many-to-many: the question it is written to answer is *do these two concepts share a
  Group*, which is a set intersection.
  - `is_parent_group` marks a Group that subsumes other Groups — a grouping *rule*, not a
    value set. OMOP models those as `LOINC Group` concepts too, so `LG100-4` is a concept
    named "Flowsheet - laboratory" with 3,538 descendants and `LG55-6` is "Mass-Molar
    conversion" with 4,296; two concepts "sharing" one of those share only a category.
    31 of the Groups in scope are ParentGroups. The flag is structural rather than a size
    threshold on purpose — a threshold would also discard genuine large value sets such as
    `LG32757-3` "Influenza virus" (460 descendants).
  - Nothing is filtered here. The flag and the count are carried so the policy lives at the
    point of use.
- `DATA/0_GetMeasurementOmopData/measurement_concept_attributes_summary.md` — a markdown
  report over `measurement_concept_attributes.tsv`: overall row/column counts, missingness
  per column, how many concepts are missing all 6 core attributes (by vocabulary), and per
  column the top 10 most used values.
- `DATA/0_GetMeasurementOmopData/log.txt` — run log: `run.sh`'s `tee` capturing both its own
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

`scripts/pullLoincGroupMembership.R` queries the same schema for LOINC Group membership —
`concept_ancestor` rows whose ancestor is a `concept_class_id = 'LOINC Group'` concept —
scoped to the same domain, standard flag and vocabulary exclusion, so the two outputs join
on `concept_id` without a gap. It computes each Group's descendant count and flags the
ParentGroups (Groups that subsume other Groups) in the same query.

Taken from the CDM rather than from LOINC's GroupFile distribution because the ancestor
model answers the question `6_EvaluateMapping` actually asks — *do these two concepts share
a Group* — as a set intersection. The GroupFile answers *which Group is this code in*, and
since its ParentGroups overlap each other (334 of 8,551 codes in the Flowsheet categories
sit in two Groups at once) using it meant inventing a precedence rule to force one Group
per code and then comparing the forced assignments. The intersection needs no precedence,
uses every ParentGroup at once, keys on `concept_id` instead of routing through a LOINC
number, drops a licensed file from the pipeline's inputs, and keeps the Groups on the same
vocabulary release as every other concept this step pulls. See
`RESEARCH/UnderstandingGroups.md`.

`scripts/summariseMeasurementConceptAttributes.R` reads the attributes output and writes the
markdown summary described above.

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
./STEPS/0_GetMeasurementOmopData/run.sh <PATH_TO_DATA_FOLDER> --env <ENV_NAME>
```
