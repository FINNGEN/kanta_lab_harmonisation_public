# 0_GetMeasurementOmopData

Pulls the OMOP reference data the mappings are checked against: every standard
`Measurement`-domain concept's LOINC axes (component, property, method, scale
type, system, time aspect), whether it is a panel, and which LOINC Groups it
belongs to. Independent of every other
step, which is why it runs first.

## Inputs

None from `DATA_MAPPINGS/`. This step pulls directly from the FinnGen OMOP CDM
vocabulary tables (`concept`, `concept_relationship`) via `FinnGenUtilsR`.

## Outputs

In `DATA_MAPPINGS/0_GetMeasurementOmopData/`:

- `measurement_concept_attributes.tsv` — one row per standard
  `Measurement`-domain concept:

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id |
| concept_code | Character | Concept code in its vocabulary |
| concept_name | Character | Concept name |
| vocabulary_id | Character | Vocabulary of the concept (e.g. `LOINC`, `SNOMED`) |
| is_panel | Logical | `TRUE` if the concept has any outgoing `Panel contains` relationship (it bundles several component tests, e.g. a metabolic panel) |
| has_component | Character | Analyte or substance measured (e.g. Glucose) |
| has_property | Character | Kind of quantity reported (e.g. Mass Concentration, Presence) |
| has_method | Character | Analytical method (e.g. Test strip, Immunoassay) |
| has_scale_type | Character | Result scale (`Qn`, `Ord`, `Nom`, `Nar`, `Doc`) |
| has_system | Character | Specimen or body system (e.g. Serum or Plasma, Urine) |
| has_time_aspect | Character | Timing of the collection (e.g. Point in time (spot), 24 hours) |

- `flowsheet_loinc_groups.tsv` — one row per (standard `Measurement` concept, LOINC
  Group it belongs to), for the concepts that are in a `Flowsheet` ParentGroup
  (`Flowsheet - laboratory`, `Flowsheet - vital signs`, `Flowsheet - weight, height,
  and head circumference`). The Flowsheet ParentGroups only select the concepts;
  the Groups listed are the real LOINC Groups, the value sets of tests that differ
  only in an axis such as the method. ParentGroups are never listed. A concept can
  be in several Groups and appears once for each (`concept_id` + `group_concept_id`
  is unique, `concept_id` is not).

| Column | Type | Description |
|---|---|---|
| concept_id | Integer | OMOP concept id, joins to `measurement_concept_attributes.tsv` |
| group_concept_id | Integer | OMOP concept id of the LOINC Group |
| group_concept_code | Character | The `LG...` code of the Group |
| group_concept_name | Character | Name of the Group |
| n_descendants | Integer | How many standard `Measurement` concepts the Group holds |

- `log.txt` — run log.

The six `has_*` columns are LOINC's 6 core axes, the same attributes Athena
(athena.ohdsi.org) shows on a concept's page. They let later steps check that a
mapped `concept_id` matches the intended analyte, specimen and result type.

## Action

`scripts/pullMeasurementConceptAttributes.R` queries the vocabulary schema for
every standard concept in the `Measurement` domain (any vocabulary except
`OMOP Genomic`, whose gene-variant concepts never carry the 6 core attributes):

1. Pulls the 6 core LOINC attribute relationships (`Has component`, `Has method`,
   `Has property`, `Has scale type`, `Has system`, `Has time aspect`) for every
   concept and pivots them into one column per relationship, using the *name* of
   the related concept, not its id.
2. Flags concepts with an outgoing `Panel contains` relationship as `is_panel`.
3. Joins these onto the base concept table and writes the result.

`scripts/pullLoincGroupMembership.R` queries the same schema for LOINC Group
membership: `concept_ancestor` rows whose ancestor is a
`concept_class_id = 'LOINC Group'` concept, scoped to the same domain, standard
flag and vocabulary exclusion, so both outputs join on `concept_id` without a
gap. It computes each Group's descendant count and flags the ParentGroups in the
same query. The query keeps every Group; the script then keeps the concepts that
are in a Group whose name starts with `Flowsheet` (`groupNamePrefix`), and for those
concepts only the Groups that are not ParentGroups (a ParentGroup subsumes other
Groups: it is a grouping rule, not a set of equivalent tests). All the Groups of a
concept are kept, with no precedence rule, as `6_EvaluateMapping` used them: two
concepts are in the same test if they share a Group. The script logs how many rows
each step leaves.

Taken from the CDM rather than from LOINC's GroupFile distribution because the
ancestor model answers the question *do these two concepts share a Group* as a
set intersection, needs no precedence rule, keys on `concept_id`, drops a
licensed file from the inputs, and stays on the same vocabulary release as every
other concept this step pulls. See `RESEARCH/UnderstandingGroups.md`.

## References

- `RESEARCH/UnderstandingGroups.md` — the full analysis: the Group file
  structure, Category vs ParentGroup (section 2), which Categories overlap
  (section 4), why LOINC Groups cannot be the grouping backbone
  (section 5, only 49% of the approved codes are in any Group), and why the
  pipeline uses the CDM and not the GroupFile (section 9).
- `ARCHIVE/STEPS/0_GetMeasurementOmopData/README.md` — the earlier version of
  this step, with the reasons for taking the Groups from the CDM's
  `concept_ancestor`.
- `ARCHIVE/STEPS/6_EvaluateMapping/README.md` and
  `ARCHIVE/DATA_v4/6_EvaluateMapping/loincToOmopMappingStats.md` — how the Groups
  were used to score the mapping, and the earlier rule of reporting the most
  specific shared Group (fewest descendants).

## Env vars

- `FG_DATABASE_ENV` — which FinnGenUtilsR/database environment to connect to
  (e.g. `build`, `preview`); passed to `FinnGenUtilsR::fg_getDatabaseConnector()`.
  Set in the `ENVIRONMENTS/<ENV_NAME>.env` file selected by `--env`. That file's
  GCP variables are consumed internally by `FinnGenUtilsR` when it opens the
  connection.

## How to run

```
./STEPS/MAPPING/0_GetMeasurementOmopData/run.sh <PATH_TO_DATA_MAPPINGS> --env <ENV_NAME>
```
